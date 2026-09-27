// Package repo — §5 医疗业务(medical)tab 专属查询;共享查询见 ops_common.go
package repo

import "context"

// DeptSurgItem 科室窗口手术聚合行(手术 tab 表用)
type DeptSurgItem struct {
	DeptID int64   `gorm:"column:dept_id"`
	Name   string  `gorm:"column:name"`
	Cnt    int64   `gorm:"column:cnt"`
	AvgMin float64 `gorm:"column:avg_min"` // 平均时长(分钟,actual_end−actual_start)
}

// DeptSurgWin 窗口内科室手术聚合;科室全集=level2 AND dept_domain IN (clinical,platform)
// ——与 DeptSums 同域口径,防全集外科室混入 share 分母/top8
func (r *Ops) DeptSurgWin(ctx context.Context, w RangeWin) ([]DeptSurgItem, error) {
	var rows []DeptSurgItem
	err := r.db.WithContext(ctx).Raw(
		`SELECT s.dept_id, d.name, COUNT(*) AS cnt,
			COALESCE(AVG(EXTRACT(EPOCH FROM (s.actual_end-s.actual_start))/60)
				FILTER (WHERE s.actual_end IS NOT NULL),0) AS avg_min
		 FROM dwd.surgery_case s
		 JOIN dim.department d ON d.id = s.dept_id
		 WHERE s.date >= ? AND s.date < ?
		   AND d.level = 2 AND d.dept_domain IN ('clinical','platform')
		 GROUP BY s.dept_id, d.name`, w.Start, w.End).Scan(&rows).Error
	return rows, err
}
