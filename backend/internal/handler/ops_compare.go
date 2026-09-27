// §12 GET /workbench/compare——对比分析(E2-T4 属主文件)
// 口径:radar/benchmarks 为最新期快照,不随 range(库仅 month/2026-10 与 year/2026 各一期,设计 §4);
// table top6 按 dim metric 降序;scale 当量= outp+inpt×10 服务端实算(契约 §12 注4,禁读 BIZ_EQUIV);
// sat 科室缺行回退 dept_id=0 院级值(种子=97.2);quality yoy 缺科出"持平"(契约 §1.4-3 delta 字面量)
package handler

import (
	"math"
	"sort"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

/* ---- 固定枚举映射(契约 §12.1 dim 枚举表 + radar 六维序) ---- */

var cpMetricTitle = map[string]string{
	"scale": "业务量当量", "benefit": "医疗收入", "efficiency": "床位周转次数", "quality": "质量综合评分",
}

var cpRadarDims = []struct{ dim, name string }{
	{"scale", "业务规模"}, {"revenue", "收入能力"}, {"efficiency", "运营效率"},
	{"quality", "医疗质量"}, {"satisfaction", "患者满意"}, {"research", "科研教学"},
}

// benchmarks 显示变换:OP_VISIT/DISCH → 万人次/万人;比率 ×100;其余原值(契约 §12.1 示例)
var cpBenchOrder = []struct {
	code string
	conv func(float64) float64
	prec int
}{
	{"OP_VISIT_CNT", func(v float64) float64 { return v / 1e4 }, 1},
	{"DISCH_CNT", func(v float64) float64 { return v / 1e4 }, 2},
	{"ALOS", func(v float64) float64 { return v }, 1},
	{"SURG_L34_RATIO", func(v float64) float64 { return v * 100 }, 1},
	{"DRUG_RATIO", func(v float64) float64 { return v * 100 }, 1},
	{"CMI", func(v float64) float64 { return v }, 2},
}

type cpRow struct {
	dept           string
	metric, prevM  float64
	yoy            string
	outp, inpt     int64
	days, sat      float64
	qualityHasPrev bool // quality dim:prev 窗无该科 → yoy 出"持平"
}

// cpRoundN 定点取整(gap 按显示精度先取整再求差,契约注2:gap=显示值差)
func cpRoundN(x float64, prec int) float64 {
	p := math.Pow(10, float64(prec))
	return math.Round(x*p) / p
}

func (h *OpsHandler) Compare(c *gin.Context) {
	dim, ok := enumParam(c, "dim", "scale", "scale", "benefit", "efficiency", "quality")
	if !ok {
		return
	}
	rk, ok := rangeParam(c, "本月")
	if !ok {
		return
	}
	today, ok := h.today(c)
	if !ok {
		return
	}
	ctx := c.Request.Context()
	win := repo.WinForRange(today, rk)
	prev := win.LastYear()

	radarRows, e1 := h.ops.RadarLatest(ctx)
	benchRows, e2 := h.ops.BenchmarksLatest(ctx)
	cur, e3 := h.ops.DeptSums(ctx, win)
	prv, e4 := h.ops.DeptSums(ctx, prev)
	beds, e5 := h.ops.DeptBeds(ctx)
	qual, e6 := h.ops.DeptMetricLatest(ctx, "QUALITY_SCORE", win)
	qualPrev, e7 := h.ops.DeptMetricLatest(ctx, "QUALITY_SCORE", prev)
	sat, e8 := h.ops.DeptMetricLatest(ctx, "SAT_IP_SCORE", win)
	sat0, sat0ok, e9 := h.ops.MetricLatestAt(ctx, "SAT_IP_SCORE", 0, win)
	if ovFirstErr(e1, e2, e3, e4, e5, e6, e7, e8, e9) != nil {
		h.internalErr(c)
		return
	}
	if !sat0ok {
		sat0 = 97.2 // 院级缺行时的契约兜底值(设计 §4)
	}

	/* ---- radar:固定六维序,缺维补 0 ---- */
	rm := make(map[string]repo.RadarRow, len(radarRows))
	for _, r := range radarRows {
		rm[r.Dim] = r
	}
	inds := make([]gin.H, 0, len(cpRadarDims))
	ours, region := make([]float64, 0, len(cpRadarDims)), make([]float64, 0, len(cpRadarDims))
	for _, d := range cpRadarDims {
		inds = append(inds, gin.H{"name": d.name, "max": 100})
		row := rm[d.dim]
		ours, region = append(ours, row.Ours), append(region, row.Region)
	}

	/* ---- benchmarks:固定 code 序,显示值按精度取整后求 gap ---- */
	bm := make(map[string]repo.BenchRow, len(benchRows))
	for _, b := range benchRows {
		bm[b.Code] = b
	}
	benches := make([]gin.H, 0, len(cpBenchOrder))
	for _, spec := range cpBenchOrder {
		row, ok := bm[spec.code]
		if !ok {
			continue
		}
		o, r, b := spec.conv(row.Ours), spec.conv(row.Region), spec.conv(row.Bench)
		benches = append(benches, gin.H{
			"name":   row.Name,
			"ours":   fmtF(o, spec.prec),
			"region": fmtF(r, spec.prec),
			"bench":  fmtF(b, spec.prec),
			"gap":    signedNum(cpRoundN(o, spec.prec)-cpRoundN(r, spec.prec), spec.prec),
		})
	}

	/* ---- table:dim metric 降序 top6 ---- */
	prvMap := make(map[int64]repo.DeptAgg, len(prv))
	for _, p := range prv {
		prvMap[p.DeptID] = p
	}
	rows := make([]cpRow, 0, len(cur))
	for _, d := range cur {
		p := prvMap[d.DeptID]
		r := cpRow{dept: d.Name, outp: d.Outpt, inpt: d.Disch,
			days: ovRound1(d.Alos)}
		if v, ok := sat[d.DeptID]; ok {
			r.sat = ovRound1(v)
		} else {
			r.sat = ovRound1(sat0)
		}
		switch dim {
		case "benefit":
			r.metric, r.prevM = wan(d.Revenue), wan(p.Revenue)
		case "efficiency":
			b := beds[d.DeptID]
			if b <= 0 {
				continue // 无开放床位科室剔除(规格:分母缺失不可排名)
			}
			fb := float64(b)
			r.metric, r.prevM = float64(d.Disch)/fb, float64(p.Disch)/fb
		case "quality":
			r.metric = qual[d.DeptID]
			v, has := qualPrev[d.DeptID]
			r.prevM, r.qualityHasPrev = v, has
		default: // scale:契约 §12 注4 冻结公式 outp+inpt×10
			r.metric = float64(d.Outpt + d.Disch*10)
			r.prevM = float64(p.Outpt + p.Disch*10)
		}
		rows = append(rows, r)
	}
	sort.Slice(rows, func(i, j int) bool { return rows[i].metric > rows[j].metric })
	if len(rows) > 6 {
		rows = rows[:6]
	}
	maxM := 0.0
	if len(rows) > 0 {
		maxM = rows[0].metric
	}
	out := make([]map[string]any, 0, len(rows))
	for i, r := range rows {
		yoy := ovDPct(yoyPct(r.metric, r.prevM))
		if dim == "quality" && !r.qualityHasPrev {
			yoy = "持平"
		}
		metric := fmtF(r.metric, 1)
		if dim == "scale" || dim == "benefit" {
			metric = fmtInt(int64(math.Round(r.metric)))
		}
		out = append(out, map[string]any{
			"rank":    i + 1,
			"dept":    r.dept,
			"metric":  metric,
			"bar_pct": int64(math.Round(ovDiv(r.metric, maxM) * 100)),
			"yoy":     yoy,
			"outp":    r.outp,
			"inpt":    r.inpt,
			"days":    r.days,
			"sat":     r.sat,
		})
	}

	envelope.OK(c, gin.H{
		"dimension": dim,
		"range":     rk,
		"radar": gin.H{
			"indicators": inds,
			"series": []gin.H{
				{"name": "本院", "value": ours},
				{"name": "区域同级均值", "value": region},
			},
		},
		"benchmarks": benches,
		"table": Table{
			Columns: []Col{
				{Key: "rank", Title: "排名", Align: "center"},
				{Key: "dept", Title: "科室"},
				{Key: "metric", Title: cpMetricTitle[dim]},
				{Key: "yoy", Title: "同比", Align: "right", Num: true},
				{Key: "outp", Title: "门诊人次", Align: "right", Num: true},
				{Key: "inpt", Title: "出院人次", Align: "right", Num: true},
				{Key: "days", Title: "平均住院日", Align: "right", Num: true},
				{Key: "sat", Title: "满意度", Align: "right", Num: true},
			},
			Rows: out,
		},
	})
}
