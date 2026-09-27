// Package repo 首页列表域只读查询(契约 §3.3/§3.5/§3.6/§3.7)
// 时间窗口由 handler 用 clock.Source 计算后显式传入;repo 不碰时钟(AGENTS 唯一时间源)
package repo

import (
	"context"
	"time"

	"gorm.io/gorm"
)

type HomeTop10Row struct {
	Name  string `gorm:"column:name"`
	Value int64  `gorm:"column:v"`
}

// HomeTop10 当月临床科室出院人次降序前 10(契约 §3.3);
// 限 level=2 科室——dept_oper_day 同表含 level=3 医疗组行,组级名不入院级榜(lead 裁决)
func HomeTop10(ctx context.Context, db *gorm.DB, monthStart, monthEnd time.Time) ([]HomeTop10Row, error) {
	rows := make([]HomeTop10Row, 0, 10)
	err := db.WithContext(ctx).Raw(`
		SELECT d.name, COALESCE(SUM(o.discharge_cnt),0) v
		FROM dws.dept_oper_day o
		JOIN dim.department d ON d.id = o.dept_id
		WHERE o.date >= ? AND o.date < ? AND d.dept_domain = 'clinical' AND d.level = 2
		GROUP BY d.id, d.name
		ORDER BY v DESC, d.id
		LIMIT 10`, monthStart, monthEnd).Scan(&rows).Error
	return rows, err
}

type HomeProgressRow struct {
	ID          int64  `gorm:"column:id"`
	Name        string `gorm:"column:name"`
	ProgressPct int    `gorm:"column:progress_pct"`
	Status      string `gorm:"column:st"`
}

// HomeProgress 当月院级重点工作进度;status 经 sys.dict 转中文,无字典行回退英文键(契约 §3.5)
func HomeProgress(ctx context.Context, db *gorm.DB, periodStart time.Time) ([]HomeProgressRow, error) {
	rows := make([]HomeProgressRow, 0, 8)
	err := db.WithContext(ctx).Raw(`
		SELECT w.id, w.name, w.progress_pct,
		       COALESCE(dd.dict_label, w.workitem_status) st
		FROM ads.work_item w
		LEFT JOIN sys.dict dd
		  ON dd.dict_type = 'workitem_status' AND dd.dict_key = w.workitem_status
		WHERE w.period_type = 'month' AND w.period_start = ?
		ORDER BY w.id`, periodStart).Scan(&rows).Error
	return rows, err
}

type HomeAlertRow struct {
	ID         int64     `gorm:"column:id"`
	Level      string    `gorm:"column:alert_level"`
	Title      string    `gorm:"column:title"`
	OccurredAt time.Time `gorm:"column:occurred_at"`
	RuleCode   string    `gorm:"column:rule_code"`
	Status     string    `gorm:"column:alert_status"`
}

// HomeAlerts 打开态(pending/processing)告警近 5 条(契约 §3.6)
func HomeAlerts(ctx context.Context, db *gorm.DB) ([]HomeAlertRow, error) {
	rows := make([]HomeAlertRow, 0, 5)
	err := db.WithContext(ctx).Raw(`
		SELECT id, alert_level, title, occurred_at, rule_code, alert_status
		FROM ads.alert_event
		WHERE alert_status IN ('pending','processing')
		ORDER BY occurred_at DESC, id DESC
		LIMIT 5`).Scan(&rows).Error
	return rows, err
}

type HomeNoticeRow struct {
	ID          int64     `gorm:"column:id"`
	Title       string    `gorm:"column:title"`
	PublishDate time.Time `gorm:"column:publish_date"`
	IsUrgent    bool      `gorm:"column:is_urgent"`
}

// HomeNotices 行政通知近 5 条(契约 §3.7)
func HomeNotices(ctx context.Context, db *gorm.DB) ([]HomeNoticeRow, error) {
	rows := make([]HomeNoticeRow, 0, 5)
	err := db.WithContext(ctx).Raw(`
		SELECT id, title, publish_date, is_urgent
		FROM sys.notice
		ORDER BY publish_date DESC, id DESC
		LIMIT 5`).Scan(&rows).Error
	return rows, err
}
