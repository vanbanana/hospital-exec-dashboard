// EA 认证域数据访问——sys.user 登录行 / sys.user_session / sys.audit_log。
// 会话过期与失败窗口一律走 DB now() 墙钟(传输层);last_login_at 等业务字段由调用方传虚拟时钟。
package repo

import (
	"context"
	"time"

	"gorm.io/gorm"
)

// AuthUser sys."user" 登录校验行:contextUserSelect 同列 + password_hash/user_status。
// 不带 user_status=1 过滤——停用账号须命中行回 20102,而非当未知用户回 20101。
type AuthUser struct {
	ID           int64
	Username     string
	RealName     string
	JobTitle     string
	Avatar       string
	Role         string
	DeptID       *int64
	DeptName     string
	ScopeType    string
	ScopeVal     *string
	PasswordHash string
	UserStatus   int
}

// ToContextUser 转契约 §2.1 上下文行,登录成功响应复用 buildAuthProfileResp
func (a *AuthUser) ToContextUser() *ContextUser {
	return &ContextUser{
		ID: a.ID, Username: a.Username, RealName: a.RealName, JobTitle: a.JobTitle,
		Avatar: a.Avatar, Role: a.Role, DeptID: a.DeptID, DeptName: a.DeptName,
		ScopeType: a.ScopeType, ScopeVal: a.ScopeVal,
	}
}

// contextUserSelect 同列 + password_hash/user_status(顺序对齐便于肉眼同步)
const authUserSelect = `SELECT u.id,u.username,u.real_name,u.job_title,u.avatar,u.role,u.dept_id,COALESCE(d.name,'全院') AS dept_name,u.scope_type,u.scope_val,u.password_hash,u.user_status
FROM sys."user" u LEFT JOIN dim.department d ON d.id=u.dept_id`

// FindAuthUser 按 username 查登录行;0 行 → (nil,nil) 由 handler 回 20101
func FindAuthUser(ctx context.Context, db *gorm.DB, username string) (*AuthUser, error) {
	var u AuthUser
	tx := db.WithContext(ctx).
		Raw(authUserSelect+` WHERE u.username=$1`, username).
		Scan(&u)
	if tx.Error != nil {
		return nil, tx.Error
	}
	if tx.RowsAffected == 0 {
		return nil, nil
	}
	return &u, nil
}

// CountRecentLoginFail 近 15 分钟 login_fail 审计行数(DB now() 墙钟);≥5 → 20104
func CountRecentLoginFail(ctx context.Context, db *gorm.DB, username string) (int, error) {
	var n int
	err := db.WithContext(ctx).
		Raw(`SELECT COUNT(*) FROM sys.audit_log WHERE action='login_fail' AND username=$1 AND created_at > now() - interval '15 minutes'`, username).
		Scan(&n).Error
	return n, err
}

// SessionRow 会话单查询三态 + 用户快照;renew=剩余 <6h 滑动续期信号(SQL 判定,零 Go 墙钟)
type SessionRow struct {
	UserID     int64
	Revoked    bool
	Expired    bool
	Renew      bool
	UserStatus int
	Username   string
	Role       string
}

// ResolveSession tokenHash 查会话;0 行(令牌未知) → (nil,nil) 由中间件回 20003
func ResolveSession(ctx context.Context, db *gorm.DB, tokenHash string) (*SessionRow, error) {
	var s SessionRow
	tx := db.WithContext(ctx).
		Raw(`SELECT s.user_id,s.revoked_at IS NOT NULL AS revoked,s.expires_at <= now() AS expired,s.expires_at - now() < interval '6 hours' AS renew,u.user_status,u.username,u.role
FROM sys.user_session s JOIN sys."user" u ON u.id=s.user_id WHERE s.token_hash=$1`, tokenHash).
		Scan(&s)
	if tx.Error != nil {
		return nil, tx.Error
	}
	if tx.RowsAffected == 0 {
		return nil, nil
	}
	return &s, nil
}

// RenewSessionExpiry 滑动续期 12h;fire-and-forget 调用方忽略错误
func RenewSessionExpiry(ctx context.Context, db *gorm.DB, tokenHash string) error {
	return db.WithContext(ctx).
		Exec(`UPDATE sys.user_session SET expires_at=now()+interval '12 hours' WHERE token_hash=$1`, tokenHash).Error
}

// InsertLoginSession 登录事务内插会话行;ip NULL 时传 nil
func InsertLoginSession(ctx context.Context, tx *gorm.DB, userID int64, tokenHash string, ip *string, userAgent string) error {
	var ipArg any
	if ip != nil {
		ipArg = *ip
	}
	return tx.WithContext(ctx).
		Exec(`INSERT INTO sys.user_session(user_id,token_hash,expires_at,ip,user_agent) VALUES($1,$2,now()+interval '12 hours',$3,$4)`,
			userID, tokenHash, ipArg, userAgent).Error
}

// UpdateLastLogin last_login_at=ts(虚拟时钟——settings users.login 是业务展示字段)
func UpdateLastLogin(ctx context.Context, tx *gorm.DB, userID int64, ts time.Time) error {
	return tx.WithContext(ctx).
		Exec(`UPDATE sys."user" SET last_login_at=$2 WHERE id=$1`, userID, ts).Error
}

// AuditRow sys.audit_log 写入行;user_id 可空(登录失败未知用户/系统动作传 nil)
type AuditRow struct {
	UserID   *int64
	Username string
	Action   string
	Detail   []byte // jsonb 载荷原文,空=无 detail
	IP       *string
}

func InsertAudit(ctx context.Context, tx *gorm.DB, row AuditRow) error {
	var uid, ip, detail any
	if row.UserID != nil {
		uid = *row.UserID
	}
	if row.IP != nil {
		ip = *row.IP
	}
	if len(row.Detail) > 0 {
		detail = string(row.Detail) // jsonb 走文本编码,[]byte 会被当 bytea 拒
	}
	return tx.WithContext(ctx).
		Exec(`INSERT INTO sys.audit_log(user_id,username,action,detail,ip) VALUES($1,$2,$3,$4,$5)`,
			uid, row.Username, row.Action, detail, ip).Error
}

// RevokeSession logout 吊销;幂等——已吊销/未知令牌均为空 UPDATE
func RevokeSession(ctx context.Context, db *gorm.DB, tokenHash string) error {
	return db.WithContext(ctx).
		Exec(`UPDATE sys.user_session SET revoked_at=now() WHERE token_hash=$1 AND revoked_at IS NULL`, tokenHash).Error
}
