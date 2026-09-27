// §10.1 quality 端点数据访问——adverse_events 走 dwd.adverse_event 当月计数,
// rules_compliance 走 dws.quality_rule_audit 当月快照(rate 不落列,由 handler pass/sample 现算)
package repo

import (
	"context"
	"time"
)

// AdverseCatRow 不良事件分类计数行
type AdverseCatRow struct {
	AdverseCat string
	Cnt        int64
}

// AdverseEventCounts [start,end) 内按 adverse_cat 计数(§10.1 adverse_events 源;Σ 与 ADVERSE_EVENT_CNT 自洽)
func (r *StaffRepo) AdverseEventCounts(ctx context.Context, start, end time.Time) ([]AdverseCatRow, error) {
	var rows []AdverseCatRow
	err := r.db.WithContext(ctx).
		Table("dwd.adverse_event").
		Select("adverse_cat, count(*) AS cnt").
		Where("event_date >= ? AND event_date < ?", start.Format("2006-01-02"), end.Format("2006-01-02")).
		Group("adverse_cat").
		Scan(&rows).Error
	return rows, err
}

// QualityRuleRow 核心制度抽检行;Issues NULL=本期无记录问题(契约出空串)
type QualityRuleRow struct {
	RuleCode  string
	RuleName  string
	SampleCnt int64
	PassCnt   int64
	Issues    *string
}

// QualityRuleAudit 当月(period_type='month')制度抽检行;出行序由 handler 按契约码序重排
func (r *StaffRepo) QualityRuleAudit(ctx context.Context, periodStart time.Time) ([]QualityRuleRow, error) {
	var rows []QualityRuleRow
	err := r.db.WithContext(ctx).
		Table("dws.quality_rule_audit").
		Select("rule_code, rule_name, sample_cnt, pass_cnt, issues").
		Where("period_type = 'month' AND period_start = ?", periodStart.Format("2006-01-02")).
		Scan(&rows).Error
	return rows, err
}
