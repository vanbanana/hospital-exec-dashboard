// screen/snapshot 全部查询(契约 §14.1)——只读 SQL;时间边界由 handler 用 clock 算好传入
package repo

import (
	"context"
	"time"

	"gorm.io/gorm"
)

// ScreenAlertLevelCount 打开态(pending+processing)告警按级计数(§14.1 status.alert_open)
type ScreenAlertLevelCount struct {
	AlertLevel string
	Cnt        int
}

func ScreenOpenAlertCounts(ctx context.Context, db *gorm.DB) ([]ScreenAlertLevelCount, error) {
	var rows []ScreenAlertLevelCount
	err := db.WithContext(ctx).Raw(`
		SELECT alert_level, count(*) AS cnt FROM ads.alert_event
		WHERE alert_status IN ('pending','processing')
		GROUP BY alert_level`).Scan(&rows).Error
	return rows, err
}

// ScreenKpiRow ads.today_kpi × sys.metric_def 院级(dept_id=0)行;
// spark 为 jsonb 原值,量纲随 value_kind(rate 存 0~1),换算出参在 handler
type ScreenKpiRow struct {
	MetricCode string
	Name       string
	DispUnit   string
	ValueKind  string
	Value      float64
	PrevValue  *float64 // yesterday_same_time,NULL=昨日无同时刻切面
	DeltaPct   *float64 // 已是百分数语义(-10.2=-10.2%),不再 ×100
	Direction  int
	KpiStatus  string
	Spark      []byte
}

// ScreenTodayKpis 契约固定 4 指标一次拉回;下发序由 handler 按契约固定序重排
func ScreenTodayKpis(ctx context.Context, db *gorm.DB) ([]ScreenKpiRow, error) {
	var rows []ScreenKpiRow
	err := db.WithContext(ctx).Raw(`
		SELECT k.metric_code, m.name, m.disp_unit, m.value_kind,
		       k.value, k.yesterday_same_time AS prev_value, k.delta_pct,
		       k.direction, k.kpi_status, k.spark
		FROM ads.today_kpi k JOIN sys.metric_def m ON m.code=k.metric_code
		WHERE k.dept_id=0
		  AND k.metric_code IN ('OP_DAILY_VISITS','IP_IN_HOSP','BED_USE_RATE','SURG_DAILY_CNT')`).
		Scan(&rows).Error
	return rows, err
}

// ScreenDrgPointRow d30 窗口科室级聚合(cmi=Σrw/Σcase、profit 元→万元);
// 覆盖科室 cmi/profit 冻结值覆写在 handler(§14.1 注10)
type ScreenDrgPointRow struct {
	DeptID   int64
	Name     string
	Category string
	Cmi      *float64
	ProfitW  *float64
	CaseCnt  int64
}

func ScreenDrgPoints(ctx context.Context, db *gorm.DB) ([]ScreenDrgPointRow, error) {
	var rows []ScreenDrgPointRow
	// period_start 取最新 d30 窗口:演示库仅 2026-09-29 一期,多期并存时语义=最近快照
	err := db.WithContext(ctx).Raw(`
		SELECT d.dept_id, dep.name, dep.category,
		       ROUND(SUM(d.rw_avg*d.case_cnt)/NULLIF(SUM(d.case_cnt),0),4) AS cmi,
		       ROUND(SUM(d.total_profit)/10000,1) AS profit_w,
		       SUM(d.case_cnt) AS case_cnt
		FROM dws.drg_dept_period d JOIN dim.department dep ON dep.id=d.dept_id
		WHERE d.period_type='d30' AND d.dept_id<>0
		  AND d.period_start=(SELECT MAX(period_start) FROM dws.drg_dept_period WHERE period_type='d30')
		GROUP BY d.dept_id, dep.name, dep.category, dep.sort
		ORDER BY dep.sort`).Scan(&rows).Error
	return rows, err
}

// ScreenCampusRow 楼宇浮标快照;metrics 为 jsonb 原值(率键 0~1 存储,×100 在 handler)
type ScreenCampusRow struct {
	BuildingCode string
	Name         string
	RunStatus    string
	BadgeText    string
	BadgeLevel   string
	Metrics      []byte
}

func ScreenCampus(ctx context.Context, db *gorm.DB) ([]ScreenCampusRow, error) {
	var rows []ScreenCampusRow
	err := db.WithContext(ctx).Raw(`
		SELECT c.building_code, b.name, c.run_status, c.badge_text, c.badge_level, c.metrics
		FROM ads.campus_status c JOIN dim.building b ON b.code=c.building_code
		WHERE c.building_code IN ('mz','wk','jz','yj')`).Scan(&rows).Error
	return rows, err
}

// ScreenDeptRankRow dept_ranking 行;cmi/alos/profit/eff_score 可 NULL(types 要 number,handler 归 0)
type ScreenDeptRankRow struct {
	RankNo   int
	DeptID   int64
	Name     string
	Category string
	Cmi      *float64
	SurgCnt  int64
	Alos     *float64
	ProfitW  *float64 // 元→万元已在 SQL ROUND(/10000,1)
	EffScore *float64
}

// ScreenDeptRanking 取 ≤today 最近可得快照(契约 §16 档 A 冻结语义:跨日后不重跑派生,回看最近切面)
func ScreenDeptRanking(ctx context.Context, db *gorm.DB, date time.Time) ([]ScreenDeptRankRow, error) {
	var rows []ScreenDeptRankRow
	err := db.WithContext(ctx).Raw(`
		SELECT r.rank_no, r.dept_id, dep.name, dep.category, r.cmi, r.surg_cnt, r.alos,
		       ROUND(r.profit/10000,1) AS profit_w, r.eff_score
		FROM ads.dept_rank_day r JOIN dim.department dep ON dep.id=r.dept_id
		WHERE r.date=(SELECT MAX(date) FROM ads.dept_rank_day WHERE date <= ?) AND r.period='d30'
		ORDER BY r.rank_no`, date).Scan(&rows).Error
	return rows, err
}

// ScreenAlertListRow 打开态告警清单(§14.1 alerts.list);dept NULL→'全院'已在 SQL 兜
type ScreenAlertListRow struct {
	ID         int64
	AlertLevel string
	Title      string
	Dept       string
	OccurredAt time.Time
}

func ScreenOpenAlerts(ctx context.Context, db *gorm.DB) ([]ScreenAlertListRow, error) {
	var rows []ScreenAlertListRow
	err := db.WithContext(ctx).Raw(`
		SELECT e.id, e.alert_level, e.title,
		       COALESCE(dep.name,'全院') AS dept, e.occurred_at
		FROM ads.alert_event e LEFT JOIN dim.department dep ON dep.id=e.dept_id
		WHERE e.alert_status IN ('pending','processing')
		ORDER BY e.occurred_at DESC`).Scan(&rows).Error
	return rows, err
}
