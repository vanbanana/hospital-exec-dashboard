// §9.1 patient 端点数据访问——reg_channel_day 渠道月聚合 / feedback_event 台账。
// 渠道粒度超出 metric_value 键域(metric_def REG_CHANNEL_SHARE 注释),API 直读 dwd 聚合。
package repo

import (
	"context"
	"time"
)

// RegChannelMonth 自然月内各渠道挂号量合计(channel→Σreg_cnt)
func (r *StaffRepo) RegChannelMonth(ctx context.Context, monthStart time.Time) (map[string]int64, error) {
	type row struct {
		Channel string
		Cnt     int64
	}
	var rows []row
	err := r.DB.WithContext(ctx).
		Table("dwd.reg_channel_day").
		Select("channel, SUM(reg_cnt) AS cnt").
		Where("date >= ? AND date < ?", monthStart.Format("2006-01-02"), monthStart.AddDate(0, 1, 0).Format("2006-01-02")).
		Group("channel").
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	out := make(map[string]int64, len(rows))
	for _, rw := range rows {
		out[rw.Channel] = rw.Cnt
	}
	return out, nil
}

// FeedbackRow complaints_praises 行源(出参键名 date/type/dept/channel/content/status/score 在 handler 映射)
type FeedbackRow struct {
	ID        int64
	EventDate time.Time
	FbType    string
	Dept      string
	FbChannel string
	Content   string
	FbStatus  string
	VisitEval string
}

// FeedbackLatest 台账最近 N 行;event_date<=today 过滤未来播种行(契约只认已受理事件)
func (r *StaffRepo) FeedbackLatest(ctx context.Context, today time.Time, limit int) ([]FeedbackRow, error) {
	rows := make([]FeedbackRow, 0, limit)
	err := r.DB.WithContext(ctx).
		Table("dwd.feedback_event f").
		Select("f.id, f.event_date, f.fb_type, d.name AS dept, f.fb_channel, f.content, f.fb_status, f.visit_eval").
		Joins("JOIN dim.department d ON d.id = f.dept_id").
		Where("f.event_date <= ?", today.Format("2006-01-02")).
		Order("f.event_date DESC, f.id DESC").
		Limit(limit).
		Scan(&rows).Error
	return rows, err
}
