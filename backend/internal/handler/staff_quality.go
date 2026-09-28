package handler

import (
	"context"
	"fmt"
	"math"
	"time"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

// qualityRuleOrder §10.1 rules_compliance 契约固定码序(8 项核心制度)
var qualityRuleOrder = []string{"first_visit", "ward_round", "consult", "crit_report", "surg_check", "mr_write", "abx_class", "shift_hand"}

// qualityPct 率×100 出参精度:<10 保 2dp(院感 1.25/切口 0.35),≥10 保 1dp(98.6/99.1)——§10.1 面板惯例
func qualityPct(v float64) string {
	if v*100 < 10 {
		return fmtF(v*100, 2)
	}
	return fmtF(v*100, 1)
}

// Quality §10.1 GET /workbench/quality——契约未声明查询参数,未知参数按 REST 惯例忽略
func (h *StaffHandler) Quality(c *gin.Context) {
	ctx := c.Request.Context()
	today, err := h.r.Today(ctx)
	if err != nil {
		envelope.FailInternal(c, err)
		return
	}
	monthStart := repo.PeriodStart(today, "month")

	stats, err := h.qualityStats(ctx, today)
	if err != nil {
		envelope.FailInternal(c, err)
		return
	}
	trend, err := h.qualityInfectionTrend(ctx, today)
	if err != nil {
		envelope.FailInternal(c, err)
		return
	}
	adverse, err := h.qualityAdverseEvents(ctx, monthStart)
	if err != nil {
		envelope.FailInternal(c, err)
		return
	}
	rules, err := h.qualityRules(ctx, monthStart)
	if err != nil {
		envelope.FailInternal(c, err)
		return
	}

	envelope.OK(c, gin.H{
		"stats":            stats,
		"infection_trend":  trend,
		"adverse_events":   adverse,
		"rules_compliance": rules,
	})
}

// qualityStats 契约 6 项:4 率×100(精度见 qualityPct)+不良事件 cnt(note 带百床率)+ABX_DDD idx
func (h *StaffHandler) qualityStats(ctx context.Context, today time.Time) ([]gin.H, error) {
	stats := make([]gin.H, 0, 6)
	for _, sp := range []struct{ code, label string }{
		{"EMR_GRADE_A_RATE", "甲级病案率"},
		{"HAI_RATE", "院感发生率"},
		{"CRIT_TIMELY_RATE", "危急值处理及时率"},
	} {
		v, def, delta, dir, err := h.statMetric(ctx, sp.code, today)
		if err != nil {
			return nil, err
		}
		stats = append(stats, statItem(sp.label, qualityPct(v), def.DispUnit, delta, deltaLabelOf(def.Period), dir, ""))
	}
	// 不良事件上报:cnt+单位"起"→绝对 delta("+3起");note 由同周期 ADVERSE_PER_100BED 渲染(无行则省略)
	v, def, delta, dir, err := h.statMetric(ctx, "ADVERSE_EVENT_CNT", today)
	if err != nil {
		return nil, err
	}
	note := ""
	pdef, err := h.r.MetricDef(ctx, "ADVERSE_PER_100BED")
	if err != nil {
		return nil, err
	}
	if per, ok, err := h.r.MetricAt(ctx, pdef.Code, 0, repo.PeriodStart(today, pdef.Period)); err != nil {
		return nil, err
	} else if ok {
		note = fmt.Sprintf("百床 %.2f 起", per)
	}
	stats = append(stats, statItem("不良事件上报", fmtComma(v), def.DispUnit, delta, deltaLabelOf(def.Period), dir, note))
	v, def, delta, dir, err = h.statMetric(ctx, "INCISION1_INF_RATE", today)
	if err != nil {
		return nil, err
	}
	stats = append(stats, statItem("I类切口感染率", qualityPct(v), def.DispUnit, delta, deltaLabelOf(def.Period), dir, ""))
	// ABX_DDD:idx 原值出参("36.2"),绝对 delta 无单位词("-0.4")
	v, def, delta, dir, err = h.statMetric(ctx, "ABX_DDD", today)
	if err != nil {
		return nil, err
	}
	stats = append(stats, statItem("抗菌药物使用强度", fmtF(v, 1), def.DispUnit, delta, deltaLabelOf(def.Period), dir, ""))
	return stats, nil
}

// qualityInfectionTrend 近 6 月 HAI_RATE×100(2dp);target=warn_high×100(0.02→2.0 控制线)
func (h *StaffHandler) qualityInfectionTrend(ctx context.Context, today time.Time) (gin.H, error) {
	def, err := h.r.MetricDef(ctx, "HAI_RATE")
	if err != nil {
		return nil, err
	}
	starts, labels := repo.MonthAxis(today, 6)
	series, err := h.r.MetricSeries(ctx, "HAI_RATE", 0, starts)
	if err != nil {
		return nil, err
	}
	rates := make([]float64, len(starts))
	for i, s := range starts {
		rates[i] = math.Round(series[s.Format("2006-01-02")]*10000) / 100 // 库内 0~1 → % 保 2dp,缺月 0
	}
	target := 0.0
	if def.WarnHigh != nil {
		target = *def.WarnHigh * 100
	}
	return gin.H{"unit": def.DispUnit, "target": target, "months": labels, "rates": rates}, nil
}

// qualityAdverseEvents 当月 dwd.adverse_event 按 adverse_cat dict 序展开(缺类补 0)
func (h *StaffHandler) qualityAdverseEvents(ctx context.Context, monthStart time.Time) (gin.H, error) {
	rows, err := h.r.AdverseEventCounts(ctx, monthStart, monthStart.AddDate(0, 1, 0))
	if err != nil {
		return nil, err
	}
	dict, err := h.r.DictList(ctx, "adverse_cat")
	if err != nil {
		return nil, err
	}
	cnt := make(map[string]int64, len(rows))
	for _, r := range rows {
		cnt[r.AdverseCat] = r.Cnt
	}
	categories := make([]string, 0, len(dict))
	values := make([]int64, 0, len(dict))
	for _, d := range dict {
		categories = append(categories, d.Label)
		values = append(values, cnt[d.Key])
	}
	return gin.H{"unit": "起", "categories": categories, "values": values}, nil
}

// qualityRules 当月 8 行制度抽检:rate=pass/sample*100 现算(契约注严格自洽,禁抄库),
// sample=0 出 "—";行序=契约固定码序
func (h *StaffHandler) qualityRules(ctx context.Context, monthStart time.Time) (gin.H, error) {
	rows, err := h.r.QualityRuleAudit(ctx, monthStart)
	if err != nil {
		return nil, err
	}
	byCode := make(map[string]repo.QualityRuleRow, len(rows))
	for _, r := range rows {
		byCode[r.RuleCode] = r
	}
	out := make([]gin.H, 0, len(qualityRuleOrder))
	for _, code := range qualityRuleOrder {
		r, ok := byCode[code]
		if !ok {
			return nil, fmt.Errorf("quality_rule_audit 当月缺 %s 行", code)
		}
		rate := "—"
		if r.SampleCnt > 0 {
			rate = fmt.Sprintf("%.1f%%", float64(r.PassCnt)*100/float64(r.SampleCnt))
		}
		issues := ""
		if r.Issues != nil {
			issues = *r.Issues
		}
		out = append(out, gin.H{
			"name": r.RuleName, "sample": r.SampleCnt, "pass": r.PassCnt,
			"rate": rate, "issues": issues,
		})
	}
	return table([]gin.H{
		tableCol("name", "制度名称", "", false),
		tableCol("sample", "抽检例数", "right", true),
		tableCol("pass", "合格例数", "right", true),
		tableCol("rate", "执行合规率", "right", true),
		tableCol("issues", "主要问题", "", false),
	}, out), nil
}
