// Home 聚合端点:kpis(§3.1)/trends(§3.2)/indicators(§3.4)
// 口径:"本月"=clock 今日所在自然月整月聚合,"上月"=前一自然月;delta 规则见设计笔记 §0
package handler

import (
	"fmt"
	"math"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

// kpi 项集 meta 常量(key/label/icon/tone 对齐 metric_def.api_key 与 mock homeKpis)
var aggKpiMeta = []struct {
	key, label, unit, icon, tone string
}{
	{"outpatient", "门急诊人次", "", "Stethoscope", "primary"},
	{"inpatient", "住院人次", "", "BedDouble", "primary"},
	{"surgery", "手术台次", "", "Scissors", "teal"},
	{"revenue", "医疗总收入", "万元", "Banknote", "green"},
	{"staff", "在岗职工", "", "Users", "navy"},
}

// indicator 项集 meta 常量(§3.4,code 对齐 metric_def)
var aggIndMeta = []struct {
	code, name, unit, icon, tone string
}{
	{"ALOS", "平均住院日", "天", "CalendarDays", "primary"},
	{"BED_USE_RATE", "床位使用率", "%", "BedDouble", "primary"},
	{"DRUG_RATIO", "药占比", "%", "Pill", "primary"},
	{"MATERIAL_RATIO", "耗材占比", "%", "Package", "teal"},
	{"MED_SVC_RATIO", "医疗服务收入占比", "%", "HeartPulse", "green"},
}

type aggKpiItem struct {
	Key        string `json:"key"`
	Label      string `json:"label"`
	Value      string `json:"value"`
	Unit       string `json:"unit"`
	Delta      string `json:"delta"`
	DeltaLabel string `json:"delta_label"`
	Dir        string `json:"dir"`
	Icon       string `json:"icon"`
	Tone       string `json:"tone"`
}

type aggTrendSeries struct {
	Unit    string    `json:"unit"`
	Current []float64 `json:"current"`
	Last    []float64 `json:"last"`
}

type aggIndicator struct {
	Code       string `json:"code"`
	Name       string `json:"name"`
	Value      string `json:"value"`
	Unit       string `json:"unit"`
	Delta      string `json:"delta"`
	DeltaLabel string `json:"delta_label"`
	Dir        string `json:"dir"`
	Icon       string `json:"icon"`
	Tone       string `json:"tone"`
}

// aggMonthSpan t 所在自然月 [first,next)
func aggMonthSpan(t time.Time) (first, next time.Time) {
	first = time.Date(t.Year(), t.Month(), 1, 0, 0, 0, 0, t.Location())
	return first, first.AddDate(0, 1, 0)
}

// aggThousands 千分位整型化展示;dp>0 时先保留 dp 位小数再抹掉尾部 0(14800.0→"14,800")
func aggThousands(v float64, dp int) string {
	s := strconv.FormatFloat(v, 'f', dp, 64)
	if strings.Contains(s, ".") {
		s = strings.TrimRight(strings.TrimRight(s, "0"), ".")
	}
	neg := strings.HasPrefix(s, "-")
	intPart, frac, _ := strings.Cut(strings.TrimPrefix(s, "-"), ".")
	var b strings.Builder
	if neg {
		b.WriteByte('-')
	}
	for i, r := range intPart {
		if i > 0 && (len(intPart)-i)%3 == 0 {
			b.WriteByte(',')
		}
		b.WriteRune(r)
	}
	if frac != "" {
		b.WriteByte('.')
		b.WriteString(frac)
	}
	return b.String()
}

// aggDeltaPct 环比百分比:"+3.6%"/"持平";prev=0 或四舍五入归 0 → "持平"/flat(设计 §0)
func aggDeltaPct(cur, prev float64) (string, string) {
	if prev == 0 {
		return "持平", "flat"
	}
	return aggSigned(math.Round((cur-prev)/prev*1000)/10, "%")
}

// aggDeltaAbs 差值环比:"+1.2"/"-0.3";率=百分点,ALOS=天
func aggDeltaAbs(cur, prev float64) (string, string) {
	return aggSigned(math.Round((cur-prev)*10)/10, "")
}

func aggSigned(v float64, suffix string) (string, string) {
	switch {
	case v > 0:
		return fmt.Sprintf("+%.1f%s", v, suffix), "up"
	case v < 0:
		return fmt.Sprintf("%.1f%s", v, suffix), "down"
	default:
		return "持平", "flat"
	}
}

// Kpis GET /workbench/home/kpis(契约 §3.1)
func (h *Home) Kpis(c *gin.Context) {
	ctx := c.Request.Context()
	today, err := h.clk.Today(ctx)
	if err != nil {
		failInternal(c)
		return
	}
	curFirst, curNext := aggMonthSpan(today)
	prevFirst := curFirst.AddDate(0, -1, 0)

	cur, err := repo.HomeMonthlyAgg(ctx, h.db, curFirst, curNext)
	if err != nil {
		failInternal(c)
		return
	}
	prev, err := repo.HomeMonthlyAgg(ctx, h.db, prevFirst, curFirst)
	if err != nil {
		failInternal(c)
		return
	}
	staffCur, err := repo.HomeMetricValue(ctx, h.db, "STAFF_CNT", curFirst)
	if err != nil {
		failInternal(c)
		return
	}
	staffPrev, err := repo.HomeMetricValue(ctx, h.db, "STAFF_CNT", prevFirst)
	if err != nil {
		failInternal(c)
		return
	}

	// 与 aggKpiMeta 行序一一对应:value 仅 revenue 走 1dp 千分位
	vals := [][2]float64{
		{float64(cur.OpEmerg), float64(prev.OpEmerg)},
		{float64(cur.Discharge), float64(prev.Discharge)},
		{float64(cur.Surg), float64(prev.Surg)},
		{cur.RevenueWan, prev.RevenueWan},
		{staffCur, staffPrev},
	}
	list := make([]aggKpiItem, len(aggKpiMeta))
	for i, m := range aggKpiMeta {
		dp := 0
		if m.key == "revenue" {
			dp = 1
		}
		delta, dir := aggDeltaPct(vals[i][0], vals[i][1])
		list[i] = aggKpiItem{
			Key:        m.key,
			Label:      m.label,
			Value:      aggThousands(vals[i][0], dp),
			Unit:       m.unit,
			Delta:      delta,
			DeltaLabel: "较上月",
			Dir:        dir,
			Icon:       m.icon,
			Tone:       m.tone,
		}
	}
	envelope.OK(c, gin.H{"period": "本月", "list": list})
}

// Trends GET /workbench/home/trends(契约 §3.2):当年与上年 1-12 逐月,缺月补 0
func (h *Home) Trends(c *gin.Context) {
	ctx := c.Request.Context()
	today, err := h.clk.Today(ctx)
	if err != nil {
		failInternal(c)
		return
	}
	yearFirst := time.Date(today.Year(), 1, 1, 0, 0, 0, 0, today.Location())
	yearNext := yearFirst.AddDate(1, 0, 0)
	lastFirst := yearFirst.AddDate(-1, 0, 0)

	curPts, err := repo.HomeYearMonths(ctx, h.db, yearFirst, yearNext)
	if err != nil {
		failInternal(c)
		return
	}
	lastPts, err := repo.HomeYearMonths(ctx, h.db, lastFirst, yearFirst)
	if err != nil {
		failInternal(c)
		return
	}

	curB, lastB := aggYearBuckets(curPts), aggYearBuckets(lastPts)
	// Tab 序四键;revenue 值保 1dp,余为整量
	fields := []struct {
		name, unit string
		pick       func(*repo.HomeMonthPoint) float64
	}{
		{"门急诊人次", "人次", func(p *repo.HomeMonthPoint) float64 { return float64(p.OpEmerg) }},
		{"住院人次", "人次", func(p *repo.HomeMonthPoint) float64 { return float64(p.Discharge) }},
		{"手术台次", "台", func(p *repo.HomeMonthPoint) float64 { return float64(p.Surg) }},
		{"医疗收入", "万元", func(p *repo.HomeMonthPoint) float64 { return math.Round(p.RevenueWan*10) / 10 }},
	}
	series := make(map[string]aggTrendSeries, len(fields))
	for _, f := range fields {
		cur, last := make([]float64, 12), make([]float64, 12)
		for i := 0; i < 12; i++ {
			cur[i], last[i] = f.pick(&curB[i]), f.pick(&lastB[i])
		}
		series[f.name] = aggTrendSeries{Unit: f.unit, Current: cur, Last: last}
	}

	months := make([]string, 12)
	for i := range months {
		months[i] = fmt.Sprintf("%d月", i+1)
	}
	envelope.OK(c, gin.H{"months": months, "series": series})
}

// aggYearBuckets 按月序拆入 12 桶,缺月零值
func aggYearBuckets(pts []repo.HomeMonthPoint) [12]repo.HomeMonthPoint {
	var b [12]repo.HomeMonthPoint
	for _, p := range pts {
		if m := int(p.Month.Month()); m >= 1 && m <= 12 {
			b[m-1] = p
		}
	}
	return b
}

// Indicators GET /workbench/home/indicators(契约 §3.4):value 1dp 字符串,delta=当期-上期
func (h *Home) Indicators(c *gin.Context) {
	ctx := c.Request.Context()
	today, err := h.clk.Today(ctx)
	if err != nil {
		failInternal(c)
		return
	}
	curFirst, curNext := aggMonthSpan(today)
	prevFirst := curFirst.AddDate(0, -1, 0)

	cur, err := repo.HomeMonthlyAgg(ctx, h.db, curFirst, curNext)
	if err != nil {
		failInternal(c)
		return
	}
	prev, err := repo.HomeMonthlyAgg(ctx, h.db, prevFirst, curFirst)
	if err != nil {
		failInternal(c)
		return
	}
	svcCur, err := repo.HomeMedSvcRatio(ctx, h.db, curFirst, curNext)
	if err != nil {
		failInternal(c)
		return
	}
	svcPrev, err := repo.HomeMedSvcRatio(ctx, h.db, prevFirst, curFirst)
	if err != nil {
		failInternal(c)
		return
	}

	// 与 aggIndMeta 行序一一对应:率值 ×100 出百分点
	vals := [][2]float64{
		{cur.Alos, prev.Alos},
		{cur.BedUse * 100, prev.BedUse * 100},
		{cur.DrugRatio * 100, prev.DrugRatio * 100},
		{cur.MatRatio * 100, prev.MatRatio * 100},
		{svcCur * 100, svcPrev * 100},
	}
	list := make([]aggIndicator, len(aggIndMeta))
	for i, m := range aggIndMeta {
		delta, dir := aggDeltaAbs(vals[i][0], vals[i][1])
		list[i] = aggIndicator{
			Code:       m.code,
			Name:       m.name,
			Value:      strconv.FormatFloat(vals[i][0], 'f', 1, 64),
			Unit:       m.unit,
			Delta:      delta,
			DeltaLabel: "较上月",
			Dir:        dir,
			Icon:       m.icon,
			Tone:       m.tone,
		}
	}
	envelope.OK(c, gin.H{"list": list})
}
