package handler

import (
	"context"
	"math"
	"time"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

// patientStat 读月粒度院级指标组装 WbStatItem(label 按契约 §9.1,≠metric_def.name)
func (h *StaffHandler) patientStat(ctx context.Context, today time.Time, label, code, unit string, conv func(float64) string) (gin.H, error) {
	cur, def, delta, dir, err := h.statMetric(ctx, code, today)
	if err != nil {
		return nil, err
	}
	return statItem(label, conv(cur), unit, delta, deltaLabelOf(def.Period), dir, ""), nil
}

// Patient §9.1 GET /workbench/patient——stats 6 项 + 满意度趋势 + 渠道构成 + 投诉表扬台账
func (h *StaffHandler) Patient(c *gin.Context) {
	ctx := c.Request.Context()
	today, err := h.r.Today(ctx)
	if err != nil {
		envelope.FailInternal(c, err)
		return
	}
	mStart := repo.PeriodStart(today, "month")

	// ---- stats(契约序;score 直出、rate×100、cnt 千分位) ----
	stats := make([]gin.H, 0, 6)
	for _, s := range []struct {
		label, code, unit string
		conv              func(float64) string
	}{
		{"门诊满意度", "SAT_OP_SCORE", "%", func(v float64) string { return fmtF(v, 1) }},
		{"住院满意度", "SAT_IP_SCORE", "%", func(v float64) string { return fmtF(v, 1) }},
		{"本月投诉", "COMPLAINT_CNT", "件", fmtComma},
		{"本月表扬", "PRAISE_CNT", "件", fmtComma},
	} {
		it, err := h.patientStat(ctx, today, s.label, s.code, s.unit, s.conv)
		if err != nil {
			envelope.FailInternal(c, err)
			return
		}
		stats = append(stats, it)
	}
	// 平均候诊第 5 位:metric_def period=day 与 §9.1"本月"口径冲突,
	// metric_value 仅落月行(3001_dws_agg),直读月粒度,e3-design §9.1 锚 17.46→"17"持平
	waitCur, _, err := h.r.MetricAt(ctx, "AVG_WAIT_MIN", 0, mStart)
	if err != nil {
		envelope.FailInternal(c, err)
		return
	}
	waitPrev, waitOk, err := h.r.MetricAt(ctx, "AVG_WAIT_MIN", 0, repo.PrevPeriodStart(today, "month"))
	if err != nil {
		envelope.FailInternal(c, err)
		return
	}
	waitDelta, waitDir := deltaAbs(waitCur, waitPrev, waitOk, "分钟")
	stats = append(stats, statItem("平均候诊", fmtComma(waitCur), "分钟", waitDelta, "较上月", waitDir, ""))
	online, err := h.patientStat(ctx, today, "网约挂号率", "ONLINE_REG_RATE", "%", func(v float64) string { return fmtF(v*100, 1) })
	if err != nil {
		envelope.FailInternal(c, err)
		return
	}
	stats = append(stats, online)

	// ---- satisfaction_trend:近 6 月 score 直出 ----
	starts, months := repo.MonthAxis(today, 6)
	opSer, err := h.r.MetricSeries(ctx, "SAT_OP_SCORE", 0, starts)
	if err != nil {
		envelope.FailInternal(c, err)
		return
	}
	ipSer, err := h.r.MetricSeries(ctx, "SAT_IP_SCORE", 0, starts)
	if err != nil {
		envelope.FailInternal(c, err)
		return
	}
	outpatient := make([]float64, len(starts))
	inpatient := make([]float64, len(starts))
	for i, s := range starts {
		k := s.Format("2006-01-02")
		outpatient[i] = opSer[k]
		inpatient[i] = ipSer[k]
	}

	// ---- channel_distribution:dict 序,share=round(cnt/Σ*100),和可不为 100 ----
	sums, err := h.r.RegChannelMonth(ctx, mStart)
	if err != nil {
		envelope.FailInternal(c, err)
		return
	}
	var total int64
	for _, v := range sums {
		total += v
	}
	channels, err := h.r.DictList(ctx, "reg_channel")
	if err != nil {
		envelope.FailInternal(c, err)
		return
	}
	list := make([]gin.H, 0, len(channels))
	for _, ch := range channels {
		var share int64
		if total > 0 {
			share = int64(math.Round(float64(sums[ch.Key]) * 100 / float64(total)))
		}
		list = append(list, gin.H{"name": ch.Label, "value": share})
	}

	// ---- complaints_praises:6 行,枚举全走 dict ----
	dicts := make(map[string]map[string]string, 4)
	for _, dt := range []string{"feedback_type", "feedback_channel", "feedback_status", "feedback_score"} {
		rows, err := h.r.DictList(ctx, dt)
		if err != nil {
			envelope.FailInternal(c, err)
			return
		}
		m := make(map[string]string, len(rows))
		for _, d := range rows {
			m[d.Key] = d.Label
		}
		dicts[dt] = m
	}
	fbs, err := h.r.FeedbackLatest(ctx, today, 6)
	if err != nil {
		envelope.FailInternal(c, err)
		return
	}
	fbRows := make([]gin.H, 0, len(fbs))
	for _, f := range fbs {
		fbRows = append(fbRows, gin.H{
			"date":    f.EventDate.Format("2006-01-02"),
			"type":    dicts["feedback_type"][f.FbType],
			"dept":    f.Dept,
			"channel": dicts["feedback_channel"][f.FbChannel],
			"content": f.Content,
			"status":  dicts["feedback_status"][f.FbStatus],
			"score":   dicts["feedback_score"][f.VisitEval],
		})
	}

	envelope.OK(c, gin.H{
		"stats": stats,
		"satisfaction_trend": gin.H{
			"unit": "%", "months": months,
			"outpatient": outpatient, "inpatient": inpatient,
		},
		"channel_distribution": gin.H{"unit": "%", "list": list},
		"complaints_praises": table([]gin.H{
			tableCol("date", "日期", "center", false),
			tableCol("type", "类型", "center", false),
			tableCol("dept", "涉及科室", "", false),
			tableCol("channel", "渠道", "", false),
			tableCol("content", "反映内容", "", false),
			tableCol("status", "处理状态", "center", false),
			tableCol("score", "回访评价", "center", false),
		}, fbRows),
	})
}
