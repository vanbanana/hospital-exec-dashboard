// Package repo 数据访问层——只读查询,handler 不直接碰 SQL
package repo

import (
	"context"

	"gorm.io/gorm"
)

// ContextUser sys."user" LEFT JOIN dim.department 行(契约 §2.1 用户块)
type ContextUser struct {
	ID        int64
	Username  string
	RealName  string
	JobTitle  string
	Avatar    string
	Role      string
	DeptID    *int64 // 院级账号库内存 NULL/0,出参序列化为 null 由 handler 裁决
	DeptName  string // SQL 已 COALESCE(d.name,'全院')
	ScopeType string
	ScopeVal  *string
}

// 契约 §2.1 ?role= 的合法值即 3 个演示账号 username;排序键同上,防 IN 列表返回序漂移
const contextUserSelect = `SELECT u.id,u.username,u.real_name,u.job_title,u.avatar,u.role,u.dept_id,COALESCE(d.name,'全院') AS dept_name,u.scope_type,u.scope_val
FROM sys."user" u LEFT JOIN dim.department d ON d.id=u.dept_id`

// FindContextUser 按演示角色键(username)查启用用户;0 行 → (nil,nil) 由 handler 判数据异常
func FindContextUser(ctx context.Context, db *gorm.DB, username string) (*ContextUser, error) {
	var u ContextUser
	tx := db.WithContext(ctx).
		Raw(contextUserSelect+` WHERE u.username=$1 AND u.user_status=1`, username).
		Scan(&u)
	if tx.Error != nil {
		return nil, tx.Error
	}
	if tx.RowsAffected == 0 {
		return nil, nil
	}
	return &u, nil
}

// ListDemoUsers available_roles 数据源:3 个演示用户按 president→ops_director→dept_leader 固定序
func ListDemoUsers(ctx context.Context, db *gorm.DB) ([]ContextUser, error) {
	var us []ContextUser
	tx := db.WithContext(ctx).
		Raw(contextUserSelect + ` WHERE u.username IN ('president','ops_director','dept_leader') AND u.user_status=1
ORDER BY CASE u.username WHEN 'president' THEN 0 WHEN 'ops_director' THEN 1 ELSE 2 END`).
		Scan(&us)
	return us, tx.Error
}

// HospitalDictRow sys.dict dict_type='hospital' 单行(契约 §2.2)
type HospitalDictRow struct {
	DictKey   string
	DictLabel string
	Extra     []byte // jsonb;数组键(motto/slogans/pillars)为 JSON 数组,标量键为 NULL
}

// HospitalDict 读 hospital 字典全集按 dict_key 索引;缺键由调用方给零值,不视为错误
func HospitalDict(ctx context.Context, db *gorm.DB) (map[string]HospitalDictRow, error) {
	var rows []HospitalDictRow
	tx := db.WithContext(ctx).
		Raw(`SELECT dict_key,dict_label,extra FROM sys.dict WHERE dict_type=$1`, "hospital").
		Scan(&rows)
	if tx.Error != nil {
		return nil, tx.Error
	}
	m := make(map[string]HospitalDictRow, len(rows))
	for _, r := range rows {
		m[r.DictKey] = r
	}
	return m, nil
}
