// Package repo E3 staff 域数据访问——表→契约出参的唯一入口(AGENTS §2.6 数据纪律)。
// 度量读数一律经 dws.metric_value 一数一源(公约 §3.1);业务时间经 clock.Source(禁取真实时钟)。
package repo

import (
	"context"
	"strconv"
	"time"

	"gorm.io/gorm"

	"hospital-edss/internal/clock"
)

// StaffRepo E3 六端点(hr/research/patient/quality/assets/settings)共享数据基座
type StaffRepo struct {
	db *gorm.DB
	ck *clock.Source
}

func NewStaffRepo(db *gorm.DB, clk *clock.Source) *StaffRepo {
	return &StaffRepo{db: db, ck: clk}
}

// Today 业务当天(虚拟时钟),各端点"本月/当日"口径唯一定位点
func (r *StaffRepo) Today(ctx context.Context) (time.Time, error) {
	return r.ck.Today(ctx)
}

// ---- 指标字典与值行 -------------------------------------------------------

// MetricDef 指标字典行;量纲(value_kind)/周期(period)/阈值由字典钉死,代码不复制口径
type MetricDef struct {
	Code      string
	Name      string
	DispUnit  string
	ValueKind string
	Period    string
	WarnLow   *float64
	WarnHigh  *float64
}

func (r *StaffRepo) MetricDef(ctx context.Context, code string) (*MetricDef, error) {
	var m MetricDef
	err := r.db.WithContext(ctx).
		Table("sys.metric_def").
		Select("code", "name", "disp_unit", "value_kind", "period", "warn_low", "warn_high").
		Where("code = ?", code).
		Take(&m).Error
	if err != nil {
		return nil, err
	}
	return &m, nil
}

// PeriodStart 给定日期所在指标周期首日(year→1月1日;day/realtime→当日;其余→月初)。
// metric_value.date 恒为周期首日(0300_dws_agg 注释),月粒度全按月初落。
func PeriodStart(t time.Time, period string) time.Time {
	switch period {
	case "year":
		return time.Date(t.Year(), 1, 1, 0, 0, 0, 0, time.UTC)
	case "day", "realtime":
		return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
	default:
		return time.Date(t.Year(), t.Month(), 1, 0, 0, 0, 0, time.UTC)
	}
}

// PrevPeriodStart 上一周期首日(月指标→上月;年指标→去年;日→昨日)
func PrevPeriodStart(t time.Time, period string) time.Time {
	p := PeriodStart(t, period)
	switch period {
	case "year":
		return p.AddDate(-1, 0, 0)
	case "day", "realtime":
		return p.AddDate(0, 0, -1)
	default:
		return p.AddDate(0, -1, 0)
	}
}

// MetricAt 读 metric_value 单点值;无行→ok=false(非错误,由 handler 决定省略或置零)
func (r *StaffRepo) MetricAt(ctx context.Context, code string, deptID int64, date time.Time) (float64, bool, error) {
	var vals []float64
	err := r.db.WithContext(ctx).
		Table("dws.metric_value").
		Where("metric_code = ? AND dept_id = ? AND group_id = 0 AND date = ?", code, deptID, date.Format("2006-01-02")).
		Limit(1).
		Pluck("value", &vals).Error
	if err != nil {
		return 0, false, err
	}
	if len(vals) == 0 {
		return 0, false, nil
	}
	return vals[0], true, nil
}

// MetricSeries 按周期首日序列批量读值,返回 "2006-01-02"→value;缺日期的键缺席
func (r *StaffRepo) MetricSeries(ctx context.Context, code string, deptID int64, dates []time.Time) (map[string]float64, error) {
	ds := make([]string, len(dates))
	for i, d := range dates {
		ds[i] = d.Format("2006-01-02")
	}
	type row struct {
		Date  time.Time
		Value float64
	}
	var rows []row
	err := r.db.WithContext(ctx).
		Table("dws.metric_value").
		Select("date, value").
		Where("metric_code = ? AND dept_id = ? AND group_id = 0 AND date IN ?", code, deptID, ds).
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	out := make(map[string]float64, len(rows))
	for _, rw := range rows {
		out[rw.Date.Format("2006-01-02")] = rw.Value
	}
	return out, nil
}

// DictRow 字典行(sort 序即契约展示序)
type DictRow struct {
	Key   string
	Label string
}

func (r *StaffRepo) DictList(ctx context.Context, dictType string) ([]DictRow, error) {
	var rows []DictRow
	err := r.db.WithContext(ctx).
		Table("sys.dict").
		Select("dict_key AS key, dict_label AS label").
		Where("dict_type = ?", dictType).
		Order("sort").
		Scan(&rows).Error
	return rows, err
}

// ---- 时间轴 --------------------------------------------------------------

// MonthAxis 近 n 个自然月:返回月首日序列与契约 "N月" 标签(t 所在月为末点)
func MonthAxis(t time.Time, n int) ([]time.Time, []string) {
	starts := make([]time.Time, n)
	labels := make([]string, n)
	cur := time.Date(t.Year(), t.Month(), 1, 0, 0, 0, 0, time.UTC)
	for i := 0; i < n; i++ {
		m := cur.AddDate(0, -(n - 1 - i), 0)
		starts[i] = m
		labels[i] = strconv.Itoa(int(m.Month())) + "月"
	}
	return starts, labels
}

// YearAxis 近 n 个自然年标签("2022" 样,4 位字符串契约出参)
func YearAxis(t time.Time, n int) []string {
	out := make([]string, n)
	for i := 0; i < n; i++ {
		out[i] = strconv.Itoa(t.Year() - (n - 1 - i))
	}
	return out
}
