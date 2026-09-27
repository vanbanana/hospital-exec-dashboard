package handler

import (
	"context"
	"fmt"
	"math"
	"sort"
	"time"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

// deptStaffingWhitelist §7.1 dept_staffing 契约白名单 8 科室,序即契约序(open-items L8-#3 裁 a)
var deptStaffingWhitelist = []string{"ZZYXK", "JZK", "EK", "XNK", "GK", "HXWZK", "MZK", "KFK"}

// Hr §7.1 GET /workbench/hr——全字段时点/比率口径,range 三值返回同一快照
// (契约 §7.1 无随 range 累计的业务量字段;mock/hr.ts 恒等语义注释同源)
func (h *StaffHandler) Hr(c *gin.Context) {
	switch c.DefaultQuery("range", "本月") {
	case "本月", "本季", "本年":
	default:
		envelope.InvalidArg(c, "range", "取值仅限 本月/本季/本年")
		return
	}
	ctx := c.Request.Context()
	today, err := h.r.Today(ctx)
	if err != nil {
		fail(c, err)
		return
	}

	stats, err := h.hrStats(ctx, today)
	if err != nil {
		fail(c, err)
		return
	}
	structure, err := h.hrStructure(ctx)
	if err != nil {
		fail(c, err)
		return
	}
	titles, err := h.hrTitles(ctx)
	if err != nil {
		fail(c, err)
		return
	}
	staffing, err := h.hrDeptStaffing(ctx)
	if err != nil {
		fail(c, err)
		return
	}

	envelope.OK(c, gin.H{
		"stats":         stats,
		"structure":     structure,
		"titles":        titles,
		"dept_staffing": staffing,
	})
}

// hrStats 契约 6 项:3 项人员规模(cnt 走相对 delta)+医护比(idx,无 delta)+2 项占比(rate×100)
func (h *StaffHandler) hrStats(ctx context.Context, today time.Time) ([]gin.H, error) {
	stats := make([]gin.H, 0, 6)
	for _, sp := range []struct{ code, label string }{
		{"STAFF_CNT", "在岗职工"},
		{"DOCTOR_CNT", "执业医师"},
		{"NURSE_CNT", "注册护士"},
	} {
		v, def, delta, dir, err := h.statMetric(ctx, sp.code, today)
		if err != nil {
			return nil, err
		}
		stats = append(stats, statItem(sp.label, fmtComma(v), "", delta, deltaLabelOf(def.Period), dir, ""))
	}
	// 医护比:护/医比值出参 "1 : N.NN"(metric_def.DOC_NURSE_RATIO.formula),无 delta;note 由 warn_low 渲染
	v, def, _, _, err := h.statMetric(ctx, "DOC_NURSE_RATIO", today)
	if err != nil {
		return nil, err
	}
	note := ""
	if def.WarnLow != nil {
		note = "目标 ≥1:" + fmtTrim(*def.WarnLow, 2)
	}
	stats = append(stats, statItem("医护比", "1 : "+fmtF(v, 2), "", "", "", "", note))
	for _, sp := range []struct{ code, label string }{
		{"SENIOR_TITLE_RATIO", "高级职称占比"},
		{"STAFF_COST_RATIO", "人员经费占比"},
	} {
		v, def, delta, dir, err := h.statMetric(ctx, sp.code, today)
		if err != nil {
			return nil, err
		}
		stats = append(stats, statItem(sp.label, fmtF(v*100, 1), "%", delta, deltaLabelOf(def.Period), dir, ""))
	}
	return stats, nil
}

// hrStructure 在岗按 staff_type 计数+占比(占比如 round 后 int);name=dict 标签,list 按 count desc
func (h *StaffHandler) hrStructure(ctx context.Context) (gin.H, error) {
	rows, err := h.r.StaffTypeCounts(ctx)
	if err != nil {
		return nil, err
	}
	dict, err := h.r.DictList(ctx, "staff_type")
	if err != nil {
		return nil, err
	}
	label, order := make(map[string]string, len(dict)), make(map[string]int, len(dict))
	for i, d := range dict {
		label[d.Key] = d.Label
		order[d.Key] = i
	}
	sort.Slice(rows, func(i, j int) bool {
		if rows[i].Cnt != rows[j].Cnt {
			return rows[i].Cnt > rows[j].Cnt
		}
		return order[rows[i].StaffType] < order[rows[j].StaffType]
	})
	var total int64
	for _, r := range rows {
		total += r.Cnt
	}
	list := make([]gin.H, 0, len(rows))
	for _, r := range rows {
		var pct int64
		if total > 0 {
			pct = int64(math.Round(float64(r.Cnt) * 100 / float64(total)))
		}
		list = append(list, gin.H{"name": label[r.StaffType], "value": pct, "count": r.Cnt})
	}
	return gin.H{"unit": "%", "list": list}, nil
}

// hrTitles 岗位×职称矩阵;categories=契约固定短名(≠dict 标签,见 e3-design §7.1),
// series 按 title_level dict 序,缺档补 0(如 adm 无 senior_pos)
func (h *StaffHandler) hrTitles(ctx context.Context) (gin.H, error) {
	rows, err := h.r.StaffTitleCounts(ctx)
	if err != nil {
		return nil, err
	}
	dict, err := h.r.DictList(ctx, "title_level")
	if err != nil {
		return nil, err
	}
	mat := make(map[string]map[string]int64, len(rows))
	for _, r := range rows {
		if mat[r.TitleLevel] == nil {
			mat[r.TitleLevel] = make(map[string]int64, 4)
		}
		mat[r.TitleLevel][r.StaffType] = r.Cnt
	}
	catTypes := []string{"doc", "nur", "tec", "adm"}
	series := make([]gin.H, 0, len(dict))
	for _, d := range dict {
		values := make([]int64, len(catTypes))
		for j, t := range catTypes {
			values[j] = mat[d.Key][t]
		}
		series = append(series, gin.H{"name": d.Label, "values": values})
	}
	return gin.H{
		"unit":       "人",
		"categories": []string{"医师", "护理", "医技", "行政后勤"},
		"series":     series,
	}, nil
}

// hrDeptStaffing 白名单 8 行:ratio=护/医(nurse<10 或 doctor=0 出参 "—",O7 裁决);
// status=staffing_status dict(gap≥10 紧缺/5~9 紧张/<5 充足,open-items L8-#4)
func (h *StaffHandler) hrDeptStaffing(ctx context.Context) (gin.H, error) {
	rows, err := h.r.DeptStaffing(ctx, deptStaffingWhitelist)
	if err != nil {
		return nil, err
	}
	byCode := make(map[string]repo.DeptStaffingRow, len(rows))
	for _, r := range rows {
		byCode[r.Code] = r
	}
	dict, err := h.r.DictList(ctx, "staffing_status")
	if err != nil {
		return nil, err
	}
	statusLabel := make(map[string]string, len(dict))
	for _, d := range dict {
		statusLabel[d.Key] = d.Label
	}
	out := make([]gin.H, 0, len(deptStaffingWhitelist))
	for _, code := range deptStaffingWhitelist {
		r, ok := byCode[code]
		if !ok {
			return nil, fmt.Errorf("dept_staffing 白名单科室 %s 无库行", code)
		}
		gap := r.Quota - r.Actual
		ratio := "—"
		if r.Nurse >= 10 && r.Doctor > 0 {
			// 先 half-up 修约再格式化:%.2f 直接对 2.625 走 banker's rounding 会出 2.62,契约锚 2.63
			ratio = fmt.Sprintf("1:%.2f", math.Round(float64(r.Nurse)*100/float64(r.Doctor))/100)
		}
		status := "sufficient"
		if gap >= 10 {
			status = "shortage"
		} else if gap >= 5 {
			status = "tight"
		}
		out = append(out, gin.H{
			"dept": r.Name, "quota": r.Quota, "actual": r.Actual,
			"doctor": r.Doctor, "nurse": r.Nurse, "ratio": ratio,
			"gap": gap, "status": statusLabel[status],
		})
	}
	return table([]gin.H{
		tableCol("dept", "科室", "", false),
		tableCol("quota", "编制数", "right", true),
		tableCol("actual", "在岗数", "right", true),
		tableCol("doctor", "医师", "right", true),
		tableCol("nurse", "护士", "right", true),
		tableCol("ratio", "医护比", "center", false),
		tableCol("gap", "缺口", "right", true),
		tableCol("status", "配置状态", "center", false),
	}, out), nil
}
