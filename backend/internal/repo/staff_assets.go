// §11.1 assets 端点数据访问——energy_month 能耗/ material_stock_day 库存快照 /
// device_run_day+dim.device 大型设备当月聚合。度量一数一源同 staff.go 基座。
package repo

import (
	"context"
	"time"
)

// EnergyMonthRow dws.energy_month 单行(energy_amt 元,API 出参÷1e4 万元)
type EnergyMonthRow struct {
	PeriodStart time.Time
	EnergyType  string
	EnergyAmt   float64
}

// EnergyMonths 批量读指定月首序列的三分项能耗行
func (r *StaffRepo) EnergyMonths(ctx context.Context, starts []time.Time) ([]EnergyMonthRow, error) {
	ds := make([]string, len(starts))
	for i, d := range starts {
		ds[i] = d.Format("2006-01-02")
	}
	rows := make([]EnergyMonthRow, 0, len(ds)*3)
	err := r.DB.WithContext(ctx).
		Table("dws.energy_month").
		Select("period_start, energy_type, energy_amt").
		Where("period_type = 'month' AND period_start IN ?", ds).
		Scan(&rows).Error
	return rows, err
}

// StockAlertRow 最近快照日单条库存(可用天数=onhand/avg_daily_use 查询时派生,migration 0217)
type StockAlertRow struct {
	Name        string
	OnhandQty   int64
	AvgDailyUse float64
	WarnDays    int64
}

// StockAlerts 最近快照日(≤today)全量库存行;avg_daily_use<=0 行剔除(除零护栏)
func (r *StaffRepo) StockAlerts(ctx context.Context, today time.Time) ([]StockAlertRow, error) {
	var snap string
	err := r.DB.WithContext(ctx).
		Table("dwd.material_stock_day").
		Select("COALESCE(MAX(date)::text, '')").
		Where("date <= ?", today.Format("2006-01-02")).
		Scan(&snap).Error
	if err != nil || snap == "" {
		return nil, err
	}
	var rows []StockAlertRow
	err = r.DB.WithContext(ctx).
		Table("dwd.material_stock_day s").
		Select("m.name, s.onhand_qty, s.avg_daily_use, m.warn_days").
		Joins("JOIN dim.material m ON m.code = s.material_code").
		Where("s.date = ? AND s.avg_daily_use > 0", snap).
		Scan(&rows).Error
	return rows, err
}

// EquipAggRow 契约白名单设备 (name,dept) 当月聚合
type EquipAggRow struct {
	Name    string
	Dept    string
	Cnt     int64
	RunH    float64
	PlanH   float64
	Monthly int64
	Income  float64
}

// LargeEquipMonth dim.device+dwd.device_run_day 按 (name,dept) 聚合整月
func (r *StaffRepo) LargeEquipMonth(ctx context.Context, monthStart time.Time, names []string) ([]EquipAggRow, error) {
	var rows []EquipAggRow
	err := r.DB.WithContext(ctx).
		Table("dwd.device_run_day f").
		Select("d.name, dp.name AS dept, COUNT(DISTINCT d.code) AS cnt, "+
			"SUM(f.run_hours) AS run_h, SUM(f.plan_hours) AS plan_h, "+
			"SUM(f.exam_cnt) AS monthly, SUM(f.income_amt) AS income").
		Joins("JOIN dim.device d ON d.code = f.device_code").
		Joins("JOIN dim.department dp ON dp.id = d.dept_id").
		Where("f.date >= ? AND f.date < ? AND d.name IN ?",
			monthStart.Format("2006-01-02"), monthStart.AddDate(0, 1, 0).Format("2006-01-02"), names).
		Group("d.name, dp.name").
		Scan(&rows).Error
	return rows, err
}
