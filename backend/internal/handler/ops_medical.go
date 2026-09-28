// §5 GET /workbench/medical —— tab∈{门急诊,住院,手术} × range 两级维度。
// stats 恒当月/当前口径不随 range(契约 §5 stats 口径注);trend/distribution/table 随 range 切窗。
// stats delta=同比(同窗口 −1 年,即 2025-10),故 delta_label 统一"较去年"。
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

/* ===== 响应组件(对齐 src/api/types.ts MedicalResp/MedicalTrend/MedicalDistribution) ===== */

type medTrend struct {
	Title  string   `json:"title"`
	Name   string   `json:"name"`
	Unit   string   `json:"unit"`
	Months []string `json:"months"`
	Values []int64  `json:"values"`
}

type medDist struct {
	Title      string   `json:"title"`
	Sub        string   `json:"sub"`
	Type       string   `json:"type"`
	Unit       string   `json:"unit"`
	Categories []string `json:"categories"`
	Values     []int64  `json:"values"`
}

type medResp struct {
	Tab          string     `json:"tab"`
	Range        string     `json:"range"`
	Stats        []StatItem `json:"stats"`
	Trend        medTrend   `json:"trend"`
	Distribution medDist    `json:"distribution"`
	Table        Table      `json:"table"`
}

func (h *OpsHandler) Medical(c *gin.Context) {
	tab, ok := enumParam(c, "tab", "门急诊", "门急诊", "住院", "手术")
	if !ok {
		return
	}
	rk, ok := rangeParam(c, "本年")
	if !ok {
		return
	}
	ctx := c.Request.Context()
	today, ok := h.today(c)
	if !ok {
		return
	}
	win := repo.WinForRange(today, rk)
	sw := repo.WinForRange(today, "本月") // stats 固定当月窗口,不随 range(契约 §5 口径注)

	resp := medResp{Tab: tab, Range: rk}
	var err error
	switch tab {
	case "住院":
		err = h.fillInpatient(ctx, today, win, sw, &resp)
	case "手术":
		err = h.fillSurgery(ctx, today, win, sw, &resp)
	default:
		err = h.fillOutpatient(ctx, today, win, sw, &resp)
	}
	if err != nil {
		envelope.FailInternal(c, err)
		return
	}
	envelope.OK(c, resp)
}

/* ===== stats 装配:delta=同比(同窗口 −1 年),delta_label 统一"较去年" ===== */

// round1 1dp 取整并归一 −0.0(delta 与 dir 同用取整后值,符号一致)
func round1(x float64) float64 {
	r := math.Round(x*10) / 10
	if r == 0 {
		return 0
	}
	return r
}

// statYoy 量/费用项:delta=同比相对变化 "+x.x%"
func statYoy(label, unit, value string, cur, prev float64) StatItem {
	d := round1(yoyPct(cur, prev))
	return StatItem{Label: label, Value: value, Unit: unit, Delta: signedPctOps(d, 1), DeltaLabel: "较去年", Dir: dirOfEps(d, 0.05)}
}

// statPP 率项:delta=百分点差,展示仍为 "+x.x%"(契约示例 床位使用率 "+1.2%")
func statPP(label, unit, value string, cur, prev float64) StatItem {
	d := round1(cur - prev)
	return StatItem{Label: label, Value: value, Unit: unit, Delta: signedPctOps(d, 1), DeltaLabel: "较去年", Dir: dirOfEps(d, 0.05)}
}

// statAbs 均值/次数项:delta=绝对差 "+/-x.x"+du(契约示例 "-0.3"/"-3分钟")
func statAbs(label, unit, value string, cur, prev float64, du string) StatItem {
	d := round1(cur - prev)
	return StatItem{Label: label, Value: value, Unit: unit, Delta: signedNum(d, 1) + du, DeltaLabel: "较去年", Dir: dirOfEps(d, 0.05)}
}

/* ===== 共享小件 ===== */

// divf 安全除(分母 0 → 0)
func divf(a, b float64) float64 {
	if b == 0 {
		return 0
	}
	return a / b
}

// medTrendNums trend 月份轴:本年=1~12 月全轴(mock trendSlice 同),本月/本季=win.Months
func medTrendNums(win repo.RangeWin, rk string) ([]string, []int) {
	if rk == "本年" {
		return months12(), []int{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
	}
	nums := make([]int, len(win.Months))
	for i, t := range win.Months {
		nums[i] = int(t.Month())
	}
	return monthLabels(win.Months), nums
}

// pickMonthly 按月份序取月度序列值(缺月=0)
func pickMonthly(seq map[int]int64, nums []int) []int64 {
	out := make([]int64, len(nums))
	for i, m := range nums {
		out[i] = seq[m]
	}
	return out
}

// medRow 表行(table 三 tab 同构:dept/cnt/yoy/share/avg/drug,avg 已含单位词)
type medRow struct {
	id   int64
	name string
	cnt  int64
	avg  string
	drug float64 // 药占比(百分数刻度)
}

func medTableCols(cntTitle, avgTitle string) []Col {
	return []Col{
		{Key: "dept", Title: "科室"},
		{Key: "cnt", Title: cntTitle, Align: "right", Num: true},
		{Key: "yoy", Title: "同比", Align: "right", Num: true},
		{Key: "share", Title: "占比", Align: "right", Num: true},
		{Key: "avg", Title: avgTitle, Align: "right", Num: true},
		{Key: "drug", Title: "药占比", Align: "right", Num: true},
	}
}

// emitMedTable cnt 降序 top8;share 分母=Σ全部 level2 科室同口径(契约列序固定)
func emitMedTable(rows []medRow, lyCnt map[int64]float64, total int64, cntTitle, avgTitle string) Table {
	sort.Slice(rows, func(i, j int) bool {
		if rows[i].cnt == rows[j].cnt {
			return rows[i].name < rows[j].name
		}
		return rows[i].cnt > rows[j].cnt
	})
	if len(rows) > 8 {
		rows = rows[:8]
	}
	out := make([]map[string]any, 0, len(rows))
	for _, r := range rows {
		out = append(out, map[string]any{
			"dept":  r.name,
			"cnt":   fmtInt(r.cnt),
			"yoy":   signedPctOps(round1(yoyPct(float64(r.cnt), lyCnt[r.id])), 1),
			"share": pctStr(round1(divf(float64(r.cnt), float64(total))*100), 1),
			"avg":   r.avg,
			"drug":  pctStr(round1(r.drug), 1),
		})
	}
	return Table{Columns: medTableCols(cntTitle, avgTitle), Rows: out}
}

// deptChargeMap 科室费用 map(avg/drug 列查表)
func deptChargeMap(charges []repo.DeptCharge) map[int64]repo.DeptCharge {
	m := make(map[int64]repo.DeptCharge, len(charges))
	for _, x := range charges {
		m[x.DeptID] = x
	}
	return m
}

/* ===== tab=门急诊 ===== */

func (h *OpsHandler) fillOutpatient(ctx context.Context, today time.Time, win, sw repo.RangeWin, resp *medResp) error {
	ly := sw.LastYear()
	cur, err := h.ops.HospSum(ctx, sw)
	if err != nil {
		return err
	}
	prev, err := h.ops.HospSum(ctx, ly)
	if err != nil {
		return err
	}
	hc, err := h.ops.HourlySum(ctx, sw)
	if err != nil {
		return err
	}
	hp, err := h.ops.HourlySum(ctx, ly)
	if err != nil {
		return err
	}
	exp, expP := float64(hc.Expert), float64(hp.Expert)
	// 普通门诊 = 门诊人次 − 专家门诊(急诊单列,设计笔记 §2)
	nor, norP := float64(cur.Outpt)-exp, float64(prev.Outpt)-expP
	fee := divf(hc.FeeTotal, float64(hc.Visit))
	feeP := divf(hp.FeeTotal, float64(hp.Visit))
	wait := divf(hc.WaitMinSum, float64(hc.Visit))
	waitP := divf(hp.WaitMinSum, float64(hp.Visit))
	resp.Stats = []StatItem{
		statYoy("门急诊总人次", "", fmtInt(cur.Outpt+cur.Emerg), float64(cur.Outpt+cur.Emerg), float64(prev.Outpt+prev.Emerg)),
		statYoy("普通门诊", "", fmtInt(int64(nor)), nor, norP),
		statYoy("专家门诊", "", fmtInt(hc.Expert), exp, expP),
		statYoy("急诊人次", "", fmtInt(cur.Emerg), float64(cur.Emerg), float64(prev.Emerg)),
		statYoy("次均费用", "元", fmtInt(int64(math.Round(fee))), fee, feeP),
		statAbs("平均候诊", "分钟", fmtF(wait, 1), wait, waitP, "分钟"),
	}

	monthly, err := h.ops.HospMonthly(ctx, today.Year())
	if err != nil {
		return err
	}
	seq := make(map[int]int64, len(monthly))
	for _, a := range monthly {
		seq[int(a.Month.Month())] += a.Outpt + a.Emerg
	}
	labels, nums := medTrendNums(win, resp.Range)
	resp.Trend = medTrend{
		Title: "门急诊人次趋势", Name: "门急诊人次", Unit: "人次",
		Months: labels, Values: pickMonthly(seq, nums),
	}

	// 近 30 日(today−29d~today)分时段人次,契约固定 10 档小时
	hourly, err := h.ops.HourlyByHour(ctx, today.AddDate(0, 0, -29), today.AddDate(0, 0, 1))
	if err != nil {
		return err
	}
	hh := []int{7, 8, 9, 10, 11, 14, 15, 16, 17, 19}
	cats := make([]string, len(hh))
	vals := make([]int64, len(hh))
	for i, hr := range hh {
		cats[i] = fmt.Sprintf("%d时", hr)
		vals[i] = hourly[hr]
	}
	resp.Distribution = medDist{
		Title: "就诊高峰时段分布", Sub: "近 30 日分时段人次", Type: "bar", Unit: "人次",
		Categories: cats, Values: vals,
	}

	depts, err := h.ops.DeptSums(ctx, win)
	if err != nil {
		return err
	}
	deptsLY, err := h.ops.DeptSums(ctx, win.LastYear())
	if err != nil {
		return err
	}
	charges, err := h.ops.DeptCharges(ctx, win)
	if err != nil {
		return err
	}
	chg := deptChargeMap(charges)
	lyCnt := make(map[int64]float64, len(deptsLY))
	for _, x := range deptsLY {
		lyCnt[x.DeptID] = float64(x.Outpt)
	}
	var total int64
	for _, d := range depts {
		total += d.Outpt
	}
	rows := make([]medRow, 0, len(depts))
	for _, d := range depts {
		c := chg[d.DeptID]
		rows = append(rows, medRow{
			id: d.DeptID, name: d.Name, cnt: d.Outpt,
			avg:  fmtInt(int64(math.Round(divf(c.OutFee, float64(d.Outpt))))) + "元",
			drug: divf(c.OutDrug, c.OutFee) * 100,
		})
	}
	resp.Table = emitMedTable(rows, lyCnt, total, "诊疗人次", "次均费用")
	return nil
}

/* ===== tab=住院 ===== */

func (h *OpsHandler) fillInpatient(ctx context.Context, today time.Time, win, sw repo.RangeWin, resp *medResp) error {
	ly := sw.LastYear()
	cur, err := h.ops.HospSum(ctx, sw)
	if err != nil {
		return err
	}
	prev, err := h.ops.HospSum(ctx, ly)
	if err != nil {
		return err
	}
	// 在院人数/床位使用率=今日快照口径(契约示例锚 1,846/92.1 只对当日成立;月度聚合为 89.9%)
	day, err := h.ops.HospDay(ctx, today)
	if err != nil {
		return err
	}
	dayP, err := h.ops.HospDay(ctx, today.AddDate(-1, 0, 0))
	if err != nil {
		return err
	}
	fee, err := h.ops.ChargeTotals(ctx, sw)
	if err != nil {
		return err
	}
	feeP, err := h.ops.ChargeTotals(ctx, ly)
	if err != nil {
		return err
	}
	rate := divf(float64(day.UseDays), float64(day.BedDays)) * 100
	rateP := divf(float64(dayP.UseDays), float64(dayP.BedDays)) * 100
	avgFee := divf(fee.InFee, float64(cur.Disch))
	avgFeeP := divf(feeP.InFee, float64(prev.Disch))
	turn := divf(float64(cur.Disch), cur.BedOpen)
	turnP := divf(float64(prev.Disch), prev.BedOpen)
	resp.Stats = []StatItem{
		{Label: "在院人数", Value: fmtInt(day.InHosp), Note: "当前实时"},
		statYoy("本月出院", "", fmtInt(cur.Disch), float64(cur.Disch), float64(prev.Disch)),
		statPP("床位使用率", "%", fmtF(rate, 1), rate, rateP),
		statAbs("平均住院日", "天", fmtF(cur.Alos, 1), cur.Alos, prev.Alos, ""),
		statAbs("床位周转次数", "", fmtF(turn, 1), turn, turnP, ""),
		statYoy("次均住院费用", "元", fmtInt(int64(math.Round(avgFee))), avgFee, avgFeeP),
	}

	monthly, err := h.ops.HospMonthly(ctx, today.Year())
	if err != nil {
		return err
	}
	seq := make(map[int]int64, len(monthly))
	for _, a := range monthly {
		seq[int(a.Month.Month())] += a.Disch
	}
	labels, nums := medTrendNums(win, resp.Range)
	resp.Trend = medTrend{
		Title: "出院人数趋势", Name: "出院人数", Unit: "人次",
		Months: labels, Values: pickMonthly(seq, nums),
	}

	// 今日病区占用率快照,契约固定 7 组(repo.WardOccupancy 已按映射分组)
	wgs, err := h.ops.WardOccupancy(ctx, today)
	if err != nil {
		return err
	}
	gm := make(map[string]repo.WardGroup, len(wgs))
	for _, g := range wgs {
		gm[g.Grp] = g
	}
	gorder := []string{"内科", "外科", "妇产", "儿科", "ICU", "肿瘤", "康复"}
	vals := make([]int64, len(gorder))
	for i, g := range gorder {
		w := gm[g]
		vals[i] = int64(math.Round(divf(float64(w.Used), float64(w.Open)) * 100))
	}
	resp.Distribution = medDist{
		Title: "病区床位占用", Sub: "各病区开放床位占用率", Type: "bar", Unit: "%",
		Categories: gorder, Values: vals,
	}

	depts, err := h.ops.DeptSums(ctx, win)
	if err != nil {
		return err
	}
	deptsLY, err := h.ops.DeptSums(ctx, win.LastYear())
	if err != nil {
		return err
	}
	charges, err := h.ops.DeptCharges(ctx, win)
	if err != nil {
		return err
	}
	chg := deptChargeMap(charges)
	lyCnt := make(map[int64]float64, len(deptsLY))
	for _, x := range deptsLY {
		lyCnt[x.DeptID] = float64(x.Disch)
	}
	var total int64
	for _, d := range depts {
		total += d.Disch
	}
	rows := make([]medRow, 0, len(depts))
	for _, d := range depts {
		c := chg[d.DeptID]
		rows = append(rows, medRow{
			id: d.DeptID, name: d.Name, cnt: d.Disch,
			avg:  fmtInt(int64(math.Round(divf(c.InFee, float64(d.Disch))))) + "元",
			drug: divf(c.InDrug, c.InFee) * 100,
		})
	}
	resp.Table = emitMedTable(rows, lyCnt, total, "出院人次", "次均费用")
	return nil
}

/* ===== tab=手术 ===== */

func (h *OpsHandler) fillSurgery(ctx context.Context, today time.Time, win, sw repo.RangeWin, resp *medResp) error {
	ly := sw.LastYear()
	sa, err := h.ops.SurgAgg(ctx, sw)
	if err != nil {
		return err
	}
	saP, err := h.ops.SurgAgg(ctx, ly)
	if err != nil {
		return err
	}
	days := sw.End.Sub(sw.Start).Hours() / 24
	daysP := ly.End.Sub(ly.Start).Hours() / 24
	// 手术间利用率=Σ实际分钟/(间数×当月天数×480min);假定每日 8h 手术开放时长(设计笔记 §2)
	util := divf(sa.Minutes, float64(sa.Rooms)*days*480) * 100
	utilP := divf(saP.Minutes, float64(saP.Rooms)*daysP*480) * 100
	l34 := divf(float64(sa.L3+sa.L4), float64(sa.Total)) * 100
	l34P := divf(float64(saP.L3+saP.L4), float64(saP.Total)) * 100
	mi := divf(float64(sa.MinInv), float64(sa.Total)) * 100
	miP := divf(float64(saP.MinInv), float64(saP.Total)) * 100
	emg, emgP := float64(sa.Total-sa.Elect), float64(saP.Total-saP.Elect)
	resp.Stats = []StatItem{
		statYoy("本月手术台次", "", fmtInt(sa.Total), float64(sa.Total), float64(saP.Total)),
		statPP("三四级手术占比", "%", fmtF(l34, 1), l34, l34P),
		statPP("微创手术占比", "%", fmtF(mi, 1), mi, miP),
		statYoy("择期手术", "", fmtInt(sa.Elect), float64(sa.Elect), float64(saP.Elect)),
		statYoy("急诊手术", "", fmtInt(sa.Total-sa.Elect), emg, emgP),
		statPP("手术间利用率", "%", fmtF(util, 1), util, utilP),
	}

	seq, err := h.ops.SurgMonthly(ctx, today.Year())
	if err != nil {
		return err
	}
	labels, nums := medTrendNums(win, resp.Range)
	resp.Trend = medTrend{
		Title: "手术台次趋势", Name: "手术台次", Unit: "台",
		Months: labels, Values: pickMonthly(seq, nums),
	}

	// 分级构成 pie 随 range 窗口;sub 文案契约固定"本月手术级别分布"(契约 §5 示例)
	dsa, err := h.ops.SurgAgg(ctx, win)
	if err != nil {
		return err
	}
	lv := []int64{dsa.L4, dsa.L3, dsa.L2, dsa.L1}
	vals := make([]int64, len(lv))
	for i, n := range lv {
		vals[i] = int64(math.Round(divf(float64(n), float64(dsa.Total)) * 100))
	}
	resp.Distribution = medDist{
		Title: "手术分级构成", Sub: "本月手术级别分布", Type: "pie", Unit: "%",
		Categories: []string{"四级手术", "三级手术", "二级手术", "一级手术"}, Values: vals,
	}

	depts, err := h.ops.DeptSurgWin(ctx, win)
	if err != nil {
		return err
	}
	deptsLY, err := h.ops.DeptSurgWin(ctx, win.LastYear())
	if err != nil {
		return err
	}
	charges, err := h.ops.DeptCharges(ctx, win)
	if err != nil {
		return err
	}
	chg := deptChargeMap(charges)
	lyCnt := make(map[int64]float64, len(deptsLY))
	for _, x := range deptsLY {
		lyCnt[x.DeptID] = float64(x.Cnt)
	}
	var total int64
	for _, d := range depts {
		total += d.Cnt
	}
	rows := make([]medRow, 0, len(depts))
	for _, d := range depts {
		c := chg[d.DeptID]
		rows = append(rows, medRow{
			id: d.DeptID, name: d.Name, cnt: d.Cnt,
			avg:  fmtInt(int64(math.Round(d.AvgMin))) + "分钟",
			drug: divf(c.InDrug, c.InFee) * 100,
		})
	}
	resp.Table = emitMedTable(rows, lyCnt, total, "手术台次", "平均时长")
	return nil
}
