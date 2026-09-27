// §4 GET /workbench/overview——综合概览(E2-T1 属主文件)
// 口径:stats 全部由月度序列在窗口内聚合,保证 stats 值 ≡ trend 同窗切片求和(契约 §4 注1);
// live_inpatient 恒为 sim.clock 今日快照,不随 range 联动(契约 §4 注3);
// 手术台次取 dwd.surgery_case 计数,hospital_oper_day.surg_cnt 口径偏低勿用(设计 §1)
package handler

import (
	"math"
	"sort"
	"time"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

/* ---- 响应构件(types.ts OverviewResp 逐字段对齐) ---- */

type ovNameValue struct {
	Name  string  `json:"name"`
	Value float64 `json:"value"`
}

type ovDeptShare struct {
	Name   string `json:"name"`
	Value  int64  `json:"value"`
	BarPct int64  `json:"bar_pct"`
}

type ovLive struct {
	Label string `json:"label"`
	Value string `json:"value"`
	Tone  string `json:"tone"`
}

// ovWinAgg 窗口累计:量项整值,率项留加权原件(床日/出院加权 alos 分子)
type ovWinAgg struct {
	ope, disch, surg, revWan int64
	revYuan                  float64
	useDays, bedDays         int64
	alosXdisch               float64
}

// ovWinSum 月度序列按窗口月聚合;缺月按 0 处理(种子缺月不视为错误)
func ovWinSum(mon map[int]repo.HospAgg, surg map[int]int64, months []time.Time) (a ovWinAgg) {
	for _, t := range months {
		m := mon[int(t.Month())]
		a.ope += m.Outpt + m.Emerg
		a.disch += m.Disch
		a.surg += surg[int(t.Month())]
		a.revYuan += m.Revenue
		a.revWan += int64(math.Round(wan(m.Revenue)))
		a.useDays += m.UseDays
		a.bedDays += m.BedDays
		a.alosXdisch += m.Alos * float64(m.Disch)
	}
	return
}

func ovMonthMap(rows []repo.HospAgg) map[int]repo.HospAgg {
	out := make(map[int]repo.HospAgg, len(rows))
	for _, m := range rows {
		out[int(m.Month.Month())] = m
	}
	return out
}

// ovDPct/ovDNum delta 串:先按展示精度取整,0 归一 "+0.0%"/"+0.0"
// (signedPct/signedNum 对 0 不加号;raw −0.0x 直接格式会出 "-0.0%" 伪负号)
func ovDPct(x float64) string {
	if r := math.Round(x*10) / 10; r != 0 {
		return signedPctOps(r, 1)
	}
	return "+0.0%"
}

func ovDNum(x float64) string {
	if r := math.Round(x*10) / 10; r != 0 {
		return signedNum(r, 1)
	}
	return "+0.0"
}

func ovDiv(a, b float64) float64 {
	if b == 0 {
		return 0
	}
	return a / b
}

func ovRound1(x float64) float64 { return math.Round(x*10) / 10 }

func ovFirstErr(errs ...error) error {
	for _, e := range errs {
		if e != nil {
			return e
		}
	}
	return nil
}

func (h *OpsHandler) Overview(c *gin.Context) {
	rk, ok := rangeParam(c, "本年")
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

	mCur, e1 := h.ops.HospMonthly(ctx, today.Year())
	mPrev, e2 := h.ops.HospMonthly(ctx, today.Year()-1)
	sCur, e3 := h.ops.SurgMonthly(ctx, today.Year())
	sPrev, e4 := h.ops.SurgMonthly(ctx, today.Year()-1)
	chg, e5 := h.ops.ChargeTotals(ctx, win)
	other, e6 := h.ops.MetricSum(ctx, "OTHER_INCOME_AMT", 0, win)
	depts, e7 := h.ops.DeptCharges(ctx, win)
	day, e8 := h.ops.HospDay(ctx, today)
	obs, e9 := h.ops.ObservingNow(ctx)
	icu, e10 := h.ops.ICUBedUsed(ctx, today)
	doing, e11 := h.ops.SurgDoing(ctx, today)
	if ovFirstErr(e1, e2, e3, e4, e5, e6, e7, e8, e9, e10, e11) != nil {
		h.internalErr(c)
		return
	}

	cur := ovWinSum(ovMonthMap(mCur), sCur, win.Months)
	prv := ovWinSum(ovMonthMap(mPrev), sPrev, prev.Months)
	dl := deltaLabel(rk)

	// 量项 delta 统一走同比百分比;率项单独构造(床位=百分点差,alos=天数差)
	vol := func(label string, cur, prv int64, unit string) StatItem {
		d := yoyPct(float64(cur), float64(prv))
		return StatItem{Label: label, Value: fmtInt(cur), Unit: unit,
			Delta: ovDPct(d), Dir: dirOfEps(d, 0.05), DeltaLabel: dl}
	}
	bedPct, bedPctPrev := ovDiv(float64(cur.useDays), float64(cur.bedDays))*100,
		ovDiv(float64(prv.useDays), float64(prv.bedDays))*100
	alos, alosPrev := ovDiv(cur.alosXdisch, float64(cur.disch)),
		ovDiv(prv.alosXdisch, float64(prv.disch))
	dBed, dAlos := bedPct-bedPctPrev, alos-alosPrev
	stats := []StatItem{
		vol("门急诊人次", cur.ope, prv.ope, ""),
		vol("出院人数", cur.disch, prv.disch, ""),
		vol("手术台次", cur.surg, prv.surg, ""),
		vol("医疗收入", cur.revWan, prv.revWan, "万元"),
		{Label: "床位使用率", Value: fmtF(bedPct, 1), Unit: "%",
			Delta: ovDPct(dBed), Dir: dirOfEps(dBed, 0.05), DeltaLabel: dl},
		{Label: "平均住院日", Value: fmtF(alos, 1), Unit: "天",
			Delta: ovDNum(dAlos), Dir: dirOfEps(dAlos, 0.05), DeltaLabel: dl},
	}

	outp, revT := make([]int64, 12), make([]int64, 12)
	for _, m := range mCur {
		if mm := int(m.Month.Month()); mm >= 1 && mm <= 12 {
			outp[mm-1] = m.Outpt + m.Emerg
			revT[mm-1] = int64(math.Round(wan(m.Revenue)))
		}
	}

	// 收入构成:其他占比对院级 Σrevenue;住院/门诊按 charge 拆分比缩放(设计 §1 已验证恒等式)
	chgTot := chg.InFee + chg.OutFee
	o := ovDiv(other, cur.revYuan)
	inPct := ovRound1((1 - o) * ovDiv(chg.InFee, chgTot) * 100)
	outPct := ovRound1((1 - o) * ovDiv(chg.OutFee, chgTot) * 100)

	sort.Slice(depts, func(i, j int) bool { return depts[i].InFee > depts[j].InFee })
	if len(depts) > 8 {
		depts = depts[:8]
	}
	share := make([]ovDeptShare, 0, len(depts))
	var maxV int64
	for _, d := range depts {
		v := int64(math.Round(wan(d.InFee)))
		if maxV == 0 && v > 0 {
			maxV = v
		}
		share = append(share, ovDeptShare{Name: d.Name, Value: v,
			BarPct: int64(math.Round(ovDiv(float64(v), float64(maxV)) * 100))})
	}

	envelope.OK(c, gin.H{
		"range": rk,
		"stats": stats,
		"scale_revenue_trend": gin.H{
			"months":     months12(),
			"outpatient": outp,
			"revenue":    revT,
			"units":      gin.H{"outpatient": "人次", "revenue": "万元"},
		},
		"income_structure": gin.H{
			"unit": "%",
			"list": []ovNameValue{
				{Name: "住院收入", Value: inPct},
				{Name: "门诊收入", Value: outPct},
				{Name: "其他收入", Value: ovRound1(o * 100)},
			},
		},
		"dept_share_top8": gin.H{
			"metric": "住院收入（万元·" + rk + "）",
			"unit":   "万元",
			"list":   share,
		},
		"live_inpatient": []ovLive{
			{Label: "当前在院人数", Value: fmtInt(day.InHosp), Tone: "primary"},
			{Label: "今日入院人数", Value: fmtInt(day.Admit), Tone: "teal"},
			{Label: "今日出院核准", Value: fmtInt(day.Disch), Tone: "green"},
			{Label: "急诊在观人数", Value: fmtInt(obs), Tone: "amber"},
			{Label: "重症监护在科", Value: fmtInt(icu), Tone: "red"},
			{Label: "手术进行中", Value: fmtInt(doing), Tone: "navy"},
		},
	})
}
