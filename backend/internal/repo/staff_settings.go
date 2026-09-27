// Package repo E3 §13.2 settings/config 端点数据访问——
// sys.data_source / ads.alert_rule(JOIN metric_def 取量纲) / sys.user(JOIN dict 排序) / sys.user_pref。
package repo

import (
	"context"
	"time"
)

// DataSourceRow sys.data_source 行;type/status 为 dict key,标签由 DictList 解析
type DataSourceRow struct {
	Name      string
	TypeKey   string
	StatusKey string
	LastSync  *time.Time
}

// SettingDataSources 数据源全行;CASE 序=契约 §13.2 固定行序(表无 sort 列)
func (r *StaffRepo) SettingDataSources(ctx context.Context) ([]DataSourceRow, error) {
	rows := make([]DataSourceRow, 0, 8)
	err := r.DB.WithContext(ctx).
		Table("sys.data_source").
		Select("name, ds_type AS type_key, ds_status AS status_key, last_sync_at AS last_sync").
		Order("CASE code WHEN 'HIS_OP' THEN 0 WHEN 'HIS_IP' THEN 1 WHEN 'EMR' THEN 2 " +
			"WHEN 'LIS' THEN 3 WHEN 'HRP' THEN 4 WHEN 'INS_API' THEN 5 ELSE 9 END").
		Scan(&rows).Error
	return rows, err
}

// AlertRuleRow settings 阈值行;value_kind 来自 metric_def(阈值量纲换算:rate→×100%,days→N 天)
type AlertRuleRow struct {
	Code       string
	AlertLevel string
	Op         string
	Threshold  float64
	EvalJSON   []byte
	Enabled    bool
	ValueKind  string
}

// SettingRules thresholds 白名单 7 行(source='rule'),行序=契约 §13.2 固定序
func (r *StaffRepo) SettingRules(ctx context.Context) ([]AlertRuleRow, error) {
	codes := []string{"BED_OVER_95", "DRUG_RATIO_WARN", "MAT_OVER_20", "INPT_FEE_SURGE",
		"STOCK_TURN_SLOW", "CRIT_TIMEOUT_95", "EQUIP_RUN_LOW"}
	rows := make([]AlertRuleRow, 0, len(codes))
	err := r.DB.WithContext(ctx).
		Table("ads.alert_rule AS ar").
		Select("ar.code, ar.alert_level, ar.op, ar.threshold, ar.eval_json, ar.enabled, md.value_kind").
		Joins("JOIN sys.metric_def md ON md.code = ar.metric_code").
		Where("ar.source = 'rule' AND ar.code IN ?", codes).
		Order("CASE ar.code WHEN 'BED_OVER_95' THEN 0 WHEN 'DRUG_RATIO_WARN' THEN 1 " +
			"WHEN 'MAT_OVER_20' THEN 2 WHEN 'INPT_FEE_SURGE' THEN 3 WHEN 'STOCK_TURN_SLOW' THEN 4 " +
			"WHEN 'CRIT_TIMEOUT_95' THEN 5 WHEN 'EQUIP_RUN_LOW' THEN 6 ELSE 9 END").
		Scan(&rows).Error
	return rows, err
}

// UserRow settings 用户行;role/status 为 dict key,dept_name 供 scope_type='dept' 渲染
type UserRow struct {
	RealName   string
	RoleKey    string
	ScopeType  string
	ScopeVal   *string
	DeptName   *string
	LastLogin  *time.Time
	UserStatus int
}

// SettingUsers sys.user 全行,排序=role dict sort → 科室归属账号在前(dept_id 升序)、
// 院级(NULL)殿后 → id(e3-design §13.2 实测序;与同角色内 user.id 序不一致处以实测为准)
func (r *StaffRepo) SettingUsers(ctx context.Context) ([]UserRow, error) {
	rows := make([]UserRow, 0, 8)
	err := r.DB.WithContext(ctx).
		Table("sys.user AS u").
		Select("u.real_name, u.role AS role_key, u.scope_type, u.scope_val, " +
			"dp.name AS dept_name, u.last_login_at AS last_login, u.user_status").
		Joins("JOIN sys.dict rd ON rd.dict_type = 'role_type' AND rd.dict_key = u.role").
		Joins("LEFT JOIN dim.department dp ON dp.id = u.dept_id").
		Order("rd.sort, (u.dept_id IS NULL), u.dept_id, u.id").
		Scan(&rows).Error
	return rows, err
}

// SettingPrefs 指定用户偏好 KV(pref_val jsonb 原文;缺键由 handler 落契约默认)
func (r *StaffRepo) SettingPrefs(ctx context.Context, userID int64) (map[string][]byte, error) {
	type row struct {
		Key string
		Val []byte
	}
	var rows []row
	err := r.DB.WithContext(ctx).
		Table("sys.user_pref").
		Select("pref_key AS key, pref_val AS val").
		Where("user_id = ?", userID).
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	out := make(map[string][]byte, len(rows))
	for _, rw := range rows {
		out[rw.Key] = rw.Val
	}
	return out, nil
}
