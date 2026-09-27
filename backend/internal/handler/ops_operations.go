// §6 GET /workbench/operations——运营管控(收入/结余/六项控费/科室经营)——E2-T3 属主文件
// 口径要点(/tmp/backend-orch/e2-design.md §3):
//   - 次均门诊费用用 outpatient_hourly 口径 Σfee_total/Σvisit(≈300 元);charge_day out_fee/outpt≈329 为另一口径,勿混
//   - OperationsResp 无 range 回显字段(types.ts);delta=同比 2025 同窗,|Δ|<0.05 → flat+持平(契约 §1.4-3)
//   - revenue_trend 恒 2026 全年 12 月不随 range;cost_controls 6 行定序,mark_pct 契约常量 [75,75,80,75,80,70]
//   - 百元医疗收入消耗卫生材料=metric_def COST_RATIO_MATERIAL 口径B剔药:Σmat/(Σrev−Σdrug)×100,
//     勿与耗占比(含药分母)混;锚点 12.6 元种子不可达(open-items #2),以库实算为准
package handler

import (
	"math"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

// CostControlItem cost_controls 行(契约 §6.1 注2:mark_pct=红线阈值在进度条 0-100 刻度上的相对位置)
type CostControlItem struct {
	Name    string `json:"name"`
	Value   string `json:"value"`
	Target  string `json:"target"`
	Status  string `json:"status"`
	Pct     int64  `json:"pct"`
	MarkPct int64  `json:"mark_pct"`
}

func (h *OpsHandler) Operations(c *gin.Context) {
	rk, ok := rangeParam(c, "本年")
	if !ok {
		return
	}
	today, ok := h.today(c)
	if !ok {
		return
	}
	ctx := c.Request.Context()
	win, prev := repo.WinForRange(today, rk), repo.WinForRange(today, rk).LastYear()

	cur, err := h.ops.HospSum(ctx, win)
	if err != nil {
		h.internalErr(c)
		return
	}
	prevSum, err := h.ops.HospSum(ctx, prev)
	if err != nil {
		h.internalErr(c)
		return
	}
	feeCur, err := h.ops.ChargeTotals(ctx, win)
	if err != nil {
		h.internalErr(c)
		return
	}
	feePrev, err := h.ops.ChargeTotals(ctx, prev)
	if err != nil {
		h.internalErr(c)
		return
	}
	hCur, err := h.ops.HourlySum(ctx, win)
	if err != nil {
		h.internalErr(c)
		return
	}
	hPrev, err := h.ops.HourlySum(ctx, prev)
	if err != nil {
		h.internalErr(c)
		return
	}
	monthly, err := h.ops.HospMonthly(ctx, today.Year())
	if err != nil {
		h.internalErr(c)
		return
	}
	abx, _, err := h.ops.MetricLatest(ctx, "ABX_DDD_IP", 0, win)
	if err != nil {
		h.internalErr(c)
		return
	}
	infusion, _, err := h.ops.MetricLatest(ctx, "OP_INFUSION_RATE", 0, win)
	if err != nil {
		h.internalErr(c)
		return
	}
	deptRows, err := h.ops.DeptEconTop(ctx, win, 6)
	if err != nil {
		h.internalErr(c)
		return
	}

	// ratio 比率百分数(除零→0);delta 量项=相对同比、率项=百分点差,flat(|Δ|≤0.05)发"持平"
	ratio := func(a, b float64) float64 {
		if b <= 0 {
			return 0
		}
		return a / b * 100
	}
	delta := func(d float64) (string, string) {
		dir := dirOfEps(d, 0.05)
		if dir == "flat" {
			return "持平", dir
		}
		return signedPctOps(d, 1), dir
	}
	qDelta := func(cur, prev float64) (string, string) { return delta(yoyPct(cur, prev)) }
	perVisit := func(fee float64, n int64) float64 {
		if n <= 0 {
			return 0
		}
		return fee / float64(n)
	}

	dl := deltaLabel(rk)
	opFee := perVisit(hCur.FeeTotal, hCur.Visit)
	ipFee := perVisit(feeCur.InFee, cur.Disch)
	dRev, dirRev := qDelta(cur.Revenue, prevSum.Revenue)
	dOut, dirOut := qDelta(feeCur.OutFee, feePrev.OutFee)
	dIn, dirIn := qDelta(feeCur.InFee, feePrev.InFee)
	dMargin, dirMargin := delta(ratio(cur.Profit, cur.Revenue) - ratio(prevSum.Profit, prevSum.Revenue))
	dOpFee, dirOpFee := qDelta(opFee, perVisit(hPrev.FeeTotal, hPrev.Visit))
	dIpFee, dirIpFee := qDelta(ipFee, perVisit(feePrev.InFee, prevSum.Disch))

	stats := []StatItem{
		{Label: "医疗总收入", Value: fmtInt(int64(math.Round(wan(cur.Revenue)))), Unit: "万元", Delta: dRev, Dir: dirRev, DeltaLabel: dl},
		{Label: "门诊收入", Value: fmtInt(int64(math.Round(wan(feeCur.OutFee)))), Unit: "万元", Delta: dOut, Dir: dirOut, DeltaLabel: dl},
		{Label: "住院收入", Value: fmtInt(int64(math.Round(wan(feeCur.InFee)))), Unit: "万元", Delta: dIn, Dir: dirIn, DeltaLabel: dl},
		{Label: "收支结余率", Value: fmtF(ratio(cur.Profit, cur.Revenue), 1), Unit: "%", Delta: dMargin, Dir: dirMargin, DeltaLabel: dl},
		{Label: "次均门诊费用", Value: fmtInt(int64(math.Round(opFee))), Unit: "元", Delta: dOpFee, Dir: dirOpFee, DeltaLabel: dl},
		{Label: "次均住院费用", Value: fmtInt(int64(math.Round(ipFee))), Unit: "元", Delta: dIpFee, Dir: dirIpFee, DeltaLabel: dl},
	}

	byMonth := make(map[int]repo.HospAgg, len(monthly))
	for _, m := range monthly {
		byMonth[int(m.Month.Month())] = m
	}
	income := make([]int64, 12)
	costArr := make([]int64, 12)
	balance := make([]int64, 12)
	for i := 1; i <= 12; i++ {
		m := byMonth[i]
		income[i-1] = int64(math.Round(wan(m.Revenue)))
		costArr[i-1] = int64(math.Round(wan(m.Cost)))
		balance[i-1] = int64(math.Round(wan(m.Profit)))
	}

	drugRatio := ratio(cur.DrugFee, cur.Revenue)
	matRatio := ratio(cur.MatFee, cur.Revenue)
	matPer100 := ratio(cur.MatFee, cur.Revenue-cur.DrugFee) // 口径B剔药,勿用 matRatio 顶替
	growth := yoyPct(opFee, perVisit(hPrev.FeeTotal, hPrev.Visit))
	infusionPct := infusion * 100
	ctl := func(name, val string, v, target float64, label string, mark int64) CostControlItem {
		status := "达标"
		if v > target {
			status = "超标"
		}
		return CostControlItem{Name: name, Value: val, Target: label, Status: status,
			Pct: int64(math.Round(v / target * float64(mark))), MarkPct: mark}
	}
	controls := []CostControlItem{
		ctl("药占比", pctStr(drugRatio, 1), drugRatio, 30, "≤30%", 75),
		ctl("耗占比", pctStr(matRatio, 1), matRatio, 20, "≤20%", 75),
		ctl("次均费用增幅", pctStr(growth, 1), growth, 8, "≤8%", 80),
		ctl("百元医疗收入消耗卫生材料", fmtF(matPer100, 1)+"元", matPer100, 15, "≤15元", 75),
		ctl("住院抗菌药物使用强度", fmtF(abx, 1), abx, 40, "≤40", 80),
		ctl("门诊输液率", pctStr(infusionPct, 1), infusionPct, 8, "≤8%", 70),
	}

	rows := make([]map[string]any, 0, len(deptRows))
	for _, r := range deptRows {
		rows = append(rows, map[string]any{
			"dept":       r.Name,
			"income":     fmtInt(int64(math.Round(wan(r.Rev)))),
			"cost":       fmtInt(int64(math.Round(wan(r.Cost)))),
			"balance":    fmtInt(int64(math.Round(wan(r.Prof)))),
			"margin":     pctStr(ratio(r.Prof, r.Rev), 1),
			"drug_ratio": pctStr(ratio(r.Drug, r.Fee), 1),
			"mat_ratio":  pctStr(ratio(r.Mat, r.Fee), 1),
		})
	}

	envelope.OK(c, gin.H{
		"stats": stats,
		"revenue_trend": gin.H{
			"months":  months12(),
			"income":  income,
			"cost":    costArr,
			"balance": balance,
		},
		"cost_controls": controls,
		"dept_table": Table{
			Columns: []Col{
				{Key: "dept", Title: "科室"},
				{Key: "income", Title: "收入（万元）", Align: "right", Num: true},
				{Key: "cost", Title: "成本（万元）", Align: "right", Num: true},
				{Key: "balance", Title: "结余（万元）", Align: "right", Num: true},
				{Key: "margin", Title: "结余率", Align: "right", Num: true},
				{Key: "drug_ratio", Title: "药占比", Align: "right", Num: true},
				{Key: "mat_ratio", Title: "耗材比", Align: "right", Num: true},
			},
			Rows: rows,
		},
	})
}
