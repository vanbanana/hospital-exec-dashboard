// §7.1 hr 端点数据访问——structure/titles 走 dim.staff 实算,dept_staffing 走
// dim.department.staff_quota × dim.staff 计数(种子锚定契约 8 行,见 1100_dim_public.sql D6)
package repo

import (
	"context"
)

// StaffTypeRow 岗位计数行(staff_type=dict staff_type 键)
type StaffTypeRow struct {
	StaffType string
	Cnt       int64
}

// StaffTypeCounts 在岗人员按 staff_type 计数(§7.1 structure 源;STAFF_STRUCT_SHARE 不落 metric_value,实时推导)
func (r *StaffRepo) StaffTypeCounts(ctx context.Context) ([]StaffTypeRow, error) {
	var rows []StaffTypeRow
	err := r.DB.WithContext(ctx).
		Table("dim.staff").
		Select("staff_type, count(*) AS cnt").
		Where("active = true").
		Group("staff_type").
		Scan(&rows).Error
	return rows, err
}

// StaffTitleRow 岗位×职称计数行
type StaffTitleRow struct {
	StaffType  string
	TitleLevel string
	Cnt        int64
}

// StaffTitleCounts 在岗人员按 (staff_type,title_level) 计数(§7.1 titles 矩阵源)
func (r *StaffRepo) StaffTitleCounts(ctx context.Context) ([]StaffTitleRow, error) {
	var rows []StaffTitleRow
	err := r.DB.WithContext(ctx).
		Table("dim.staff").
		Select("staff_type, title_level, count(*) AS cnt").
		Where("active = true").
		Group("staff_type, title_level").
		Scan(&rows).Error
	return rows, err
}

// DeptStaffingRow 白名单科室定编在岗行
type DeptStaffingRow struct {
	Code   string
	Name   string
	Quota  int64
	Actual int64
	Doctor int64
	Nurse  int64
}

// DeptStaffing 按契约白名单 code 集查定编/在岗/医护计数;出行序由 handler 按白名单重排
func (r *StaffRepo) DeptStaffing(ctx context.Context, codes []string) ([]DeptStaffingRow, error) {
	var rows []DeptStaffingRow
	err := r.DB.WithContext(ctx).
		Table("dim.department AS d").
		Select(`d.code, d.name, COALESCE(d.staff_quota, 0) AS quota,
			count(s.id) AS actual,
			count(*) FILTER (WHERE s.staff_type = 'doc') AS doctor,
			count(*) FILTER (WHERE s.staff_type = 'nur') AS nurse`).
		Joins("LEFT JOIN dim.staff s ON s.dept_id = d.id AND s.active = true").
		Where("d.code IN ?", codes).
		Group("d.code, d.name, d.staff_quota").
		Scan(&rows).Error
	return rows, err
}
