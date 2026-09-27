// Package repo 查询层——只读 SQL;时间边界由 handler 用 clock 算好传入,repo 不碰时间源
package repo

import (
	"context"
	"time"

	"gorm.io/gorm"
)

// HomeMonthAgg dws.hospital_oper_day 单自然月聚合(契约 §3.1 kpis 与 §3.4 indicators 共用一行 SQL)
type HomeMonthAgg struct {
	OpEmerg    int64   // 门急诊人次 = Σ(outpt_cnt+emerg_cnt),口径钉死
	Discharge  int64   // 住院人次 = Σdischarge_cnt
	Surg       int64   // 手术台次 = Σsurg_cnt
	RevenueWan float64 // 医疗收入·万元 = Σrevenue/10000(库内单位元)
	Alos       float64 // 平均住院日·天 = AVG(alos)
	BedUse     float64 // 床位使用率 0~1 = AVG(bed_use_rate)
	DrugRatio  float64 // 药占比 0~1 = Σdrug_fee/Σrevenue
	MatRatio   float64 // 耗材占比 0~1 = Σmaterial_fee/Σrevenue
}

// HomeMonthlyAgg [first,last) 区间整月聚合;空区间各值归 0
func HomeMonthlyAgg(ctx context.Context, db *gorm.DB, first, last time.Time) (*HomeMonthAgg, error) {
	var a HomeMonthAgg
	err := db.WithContext(ctx).Raw(`
		SELECT COALESCE(SUM(outpt_cnt+emerg_cnt),0) AS op_emerg,
		       COALESCE(SUM(discharge_cnt),0)       AS discharge,
		       COALESCE(SUM(surg_cnt),0)            AS surg,
		       COALESCE(SUM(revenue),0)/10000       AS revenue_wan,
		       COALESCE(AVG(alos),0)                AS alos,
		       COALESCE(AVG(bed_use_rate),0)        AS bed_use,
		       CASE WHEN SUM(revenue)>0 THEN SUM(drug_fee)/SUM(revenue)     ELSE 0 END AS drug_ratio,
		       CASE WHEN SUM(revenue)>0 THEN SUM(material_fee)/SUM(revenue) ELSE 0 END AS mat_ratio
		FROM dws.hospital_oper_day
		WHERE date>=? AND date<?`, first, last).
		Scan(&a).Error
	return &a, err
}

// HomeMonthPoint 自然月聚合桶(契约 §3.2 trends;缺月由 handler 补 0)
type HomeMonthPoint struct {
	Month      time.Time `gorm:"column:m"`
	OpEmerg    int64
	Discharge  int64
	Surg       int64
	RevenueWan float64
}

// HomeYearMonths [first,last) 按月分组聚合——一年区间一次 SQL 拉回再拆
func HomeYearMonths(ctx context.Context, db *gorm.DB, first, last time.Time) ([]HomeMonthPoint, error) {
	var pts []HomeMonthPoint
	err := db.WithContext(ctx).Raw(`
		SELECT date_trunc('month',date)::date AS m,
		       SUM(outpt_cnt+emerg_cnt) AS op_emerg,
		       SUM(discharge_cnt)       AS discharge,
		       SUM(surg_cnt)            AS surg,
		       SUM(revenue)/10000       AS revenue_wan
		FROM dws.hospital_oper_day
		WHERE date>=? AND date<?
		GROUP BY 1 ORDER BY 1`, first, last).
		Scan(&pts).Error
	return pts, err
}

// HomeMetricValue 院级哨兵行(dept_id=0,group_id=0)单周期取值;无行返回 0(契约 §3.1 STAFF_CNT)
func HomeMetricValue(ctx context.Context, db *gorm.DB, code string, date time.Time) (float64, error) {
	var v float64
	err := db.WithContext(ctx).Raw(`
		SELECT value FROM dws.metric_value
		WHERE metric_code=? AND dept_id=0 AND group_id=0 AND date=?`, code, date).
		Scan(&v).Error
	return v, err
}

// HomeMedSvcRatio 医疗服务收入占比 0~1:剔除药品/耗材/检查化验(metric_def formula,契约 §3.4)
func HomeMedSvcRatio(ctx context.Context, db *gorm.DB, first, last time.Time) (float64, error) {
	var v float64
	err := db.WithContext(ctx).Raw(`
		SELECT CASE WHEN SUM(out_fee+in_fee)>0
		       THEN SUM(out_fee+in_fee) FILTER (WHERE fee_cat NOT IN ('drug','material','exam'))
		            /SUM(out_fee+in_fee)
		       ELSE 0 END
		FROM dwd.charge_day
		WHERE date>=? AND date<?`, first, last).
		Scan(&v).Error
	return v, err
}
