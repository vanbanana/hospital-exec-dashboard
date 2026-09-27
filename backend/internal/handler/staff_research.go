package handler

import (
	"context"
	"fmt"
	"math"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

// Research §8.1 GET /workbench/research——科研教学(stats/project_trend/paper_distribution/disciplines)。
// 年指标 period_start=1月1日;PROJ_CNT/TRAINEE 无前期行 → 省略 delta(e3-design §8.1);
// 无声明查询参数,未知参数忽略(REST 惯例)。
func (h *StaffHandler) Research(c *gin.Context) {
	ctx := c.Request.Context()
	today, err := h.r.Today(ctx)
	if err != nil {
		fail(c)
		return
	}
	yearStart := repo.PeriodStart(today, "year")
	prevStart := repo.PrevPeriodStart(today, "year")
	dlbl := deltaLabelOf("year")

	// 课题年度聚合(dwd 事实):trend 三序列 + NEW_CNT/FUND 前期值(与 trend 同源)
	years := repo.YearAxis(today, 5)
	yearNums := make([]int, len(years))
	for i, y := range years {
		yearNums[i], _ = strconv.Atoi(y)
	}
	proj, err := h.r.ResearchProjectYears(ctx, yearNums)
	if err != nil {
		fail(c)
		return
	}
	prevProj, prevOK := proj[today.Year()-1]

	// 论文分区聚合(dws 事实):当年分布 + SCI_PAPER 前期(Σq1..q4)
	paperCur, err := h.r.ResearchPaperYear(ctx, yearStart)
	if err != nil {
		fail(c)
		return
	}
	paperPrev, err := h.r.ResearchPaperYear(ctx, prevStart)
	if err != nil {
		fail(c)
		return
	}
	sciPrev, sciOK := 0.0, false
	for q, n := range paperPrev {
		if q != "cn_core" {
			sciPrev += float64(n)
			sciOK = true
		}
	}

	// ---- stats(契约六枚)----
	stats := make([]gin.H, 0, 6)

	v, def, err := h.researchYearMetric(ctx, "RESEARCH_PROJ_CNT", yearStart)
	if err != nil {
		fail(c)
		return
	}
	stats = append(stats, statItem("在研课题", fmtComma(v), def.DispUnit, "", "", "", ""))

	v, def, err = h.researchYearMetric(ctx, "RESEARCH_NEW_CNT", yearStart)
	if err != nil {
		fail(c)
		return
	}
	d, dir := deltaAbs(v, float64(prevProj.Total), prevOK, def.DispUnit)
	stats = append(stats, statItem("年度新立项", fmtComma(v), def.DispUnit, d, dlbl, dir, ""))

	v, def, err = h.researchYearMetric(ctx, "RESEARCH_FUND", yearStart)
	if err != nil {
		fail(c)
		return
	}
	d, dir = deltaRel(v, prevProj.FundsAmt, prevOK)
	stats = append(stats, statItem("科研经费", fmtComma(v/1e4), def.DispUnit, d, dlbl, dir, ""))

	v, def, err = h.researchYearMetric(ctx, "SCI_PAPER_CNT", yearStart)
	if err != nil {
		fail(c)
		return
	}
	d, dir = deltaAbs(v, sciPrev, sciOK, def.DispUnit)
	stats = append(stats, statItem("SCI 论文", fmtComma(v), def.DispUnit, d, dlbl, dir, ""))

	v, def, err = h.researchYearMetric(ctx, "TRAINEE_CNT", yearStart)
	if err != nil {
		fail(c)
		return
	}
	pass, _, err := h.researchYearMetric(ctx, "TRAINEE_PASS_RATE", yearStart)
	if err != nil {
		fail(c)
		return
	}
	stats = append(stats, statItem("住培学员", fmtComma(v), def.DispUnit, "", "", "",
		fmt.Sprintf("首次结业率 %s%%", fmtTrim(pass*100, 1))))

	v, def, err = h.researchYearMetric(ctx, "CME_COVER_RATE", yearStart)
	if err != nil {
		fail(c)
		return
	}
	cmePrev, cmeOK, err := h.r.MetricAt(ctx, "CME_COVER_RATE", 0, prevStart)
	if err != nil {
		fail(c)
		return
	}
	d, dir = deltaRel(v, cmePrev, cmeOK)
	stats = append(stats, statItem("继教覆盖率", fmtTrim(v*100, 1), def.DispUnit, d, dlbl, dir, ""))

	// ---- project_trend:近5自然年,national/provincial 立项数 + funds Σ(元→万元取整)----
	nat := make([]int, len(yearNums))
	prov := make([]int, len(yearNums))
	funds := make([]int, len(yearNums))
	for i, y := range yearNums {
		a := proj[y]
		nat[i] = a.National
		prov[i] = a.Provincial
		funds[i] = int(math.Round(a.FundsAmt / 1e4))
	}

	// ---- paper_distribution:当年全学科 Σ,契约固定类目序 ----
	quartiles := []string{"q1", "q2", "q3", "q4", "cn_core"}
	paperVals := make([]int, len(quartiles))
	for i, q := range quartiles {
		paperVals[i] = paperCur[q]
	}

	// ---- disciplines:dim.discipline id>0 order by sort;指标=metric_value dept 级行 ----
	dis, err := h.r.DisciplineList(ctx)
	if err != nil {
		fail(c)
		return
	}
	lvlRows, err := h.r.DictList(ctx, "discipline_level")
	if err != nil {
		fail(c)
		return
	}
	lvlLabel := make(map[string]string, len(lvlRows))
	for _, dr := range lvlRows {
		lvlLabel[dr.Key] = dr.Label
	}
	discRows := make([]gin.H, 0, len(dis))
	for _, dc := range dis {
		row, err := h.researchDisciplineRow(ctx, dc, lvlLabel[dc.LevelKey], yearStart)
		if err != nil {
			fail(c)
			return
		}
		discRows = append(discRows, row)
	}

	envelope.OK(c, gin.H{
		"stats": stats,
		"project_trend": gin.H{
			"unit":       "万元",
			"years":      years,
			"national":   nat,
			"provincial": prov,
			"funds":      funds,
		},
		"paper_distribution": gin.H{
			"unit":       "篇",
			"categories": []string{"一区（Top）", "二区", "三区", "四区", "中文核心"},
			"values":     paperVals,
		},
		"disciplines": table([]gin.H{
			tableCol("name", "学科名称", "", false),
			tableCol("level", "级别", "center", false),
			tableCol("leader", "学科带头人", "", false),
			tableCol("projects", "在研课题", "right", true),
			tableCol("funds", "科研经费（万元）", "right", true),
			tableCol("papers", "年度论文", "right", true),
			tableCol("transfer", "成果转化（万元）", "right", true),
		}, discRows),
	})
}

// researchYearMetric 年指标当期值(dept0@年首日);§8.1 stats 全部为 year 粒度
func (h *StaffHandler) researchYearMetric(ctx context.Context, code string, yearStart time.Time) (float64, *repo.MetricDef, error) {
	def, err := h.r.MetricDef(ctx, code)
	if err != nil {
		return 0, nil, err
	}
	v, _, err := h.r.MetricAt(ctx, code, 0, yearStart)
	return v, def, err
}

// researchDisciplineRow 单学科行:projects/papers 出 int,funds/transfer 元→万元出 string(契约 "820"/"150")
func (h *StaffHandler) researchDisciplineRow(ctx context.Context, dc repo.DisciplineRow, level string, yearStart time.Time) (gin.H, error) {
	pj, _, err := h.r.MetricAt(ctx, "RESEARCH_PROJ_CNT", dc.DeptID, yearStart)
	if err != nil {
		return nil, err
	}
	fd, _, err := h.r.MetricAt(ctx, "RESEARCH_FUND", dc.DeptID, yearStart)
	if err != nil {
		return nil, err
	}
	pp, _, err := h.r.MetricAt(ctx, "SCI_PAPER_CNT", dc.DeptID, yearStart)
	if err != nil {
		return nil, err
	}
	tr, _, err := h.r.MetricAt(ctx, "TRANSFER_AMT", dc.DeptID, yearStart)
	if err != nil {
		return nil, err
	}
	return gin.H{
		"name":     dc.Name,
		"level":    level,
		"leader":   dc.Leader,
		"projects": int(math.Round(pj)),
		"funds":    fmtTrim(fd/1e4, 2),
		"papers":   int(math.Round(pp)),
		"transfer": fmtTrim(tr/1e4, 2),
	}, nil
}
