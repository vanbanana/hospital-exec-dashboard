// EA 认证域端点(契约 §2.3/§2.4):login 签发 PG 会话 + logout 幂等吊销。
// 令牌=crypto/rand 32B hex 作 Cookie 值,库内只落其 sha256(泄库≠会话泄露,r-auth C2)。
// 会话过期走 DB now() 传输层墙钟;last_login_at 走 clk 虚拟时钟(业务展示字段)。
package handler

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/envelope"
	"hospital-edss/internal/middleware"
	"hospital-edss/internal/repo"
)

type Auth struct {
	db     *gorm.DB
	clk    *clock.Source
	secure bool // AUTH_COOKIE_SECURE → Cookie Secure 属性(TLS 部署置 1)
}

func NewAuth(db *gorm.DB, clk *clock.Source, secure bool) *Auth {
	return &Auth{db: db, clk: clk, secure: secure}
}

// dummyHash 未知用户名分支的占位 bcrypt 散列(bcrypt 官方测试向量,cost=10 与种子口令同档)——
// 让 bad_user 与 bad_password 耗时同阶,堵用户名枚举的计时 oracle
var dummyHash = []byte("$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy")

// Login POST /api/v1/auth/login(契约 §2.3);处理序:r-auth C2 登录处理序 verbatim
func (h *Auth) Login(c *gin.Context) {
	ctx := c.Request.Context()
	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(c.Request.Body).Decode(&req); err != nil {
		envelope.Fail(c, http.StatusBadRequest, envelope.CodeBadJSON, "请求体 JSON 解析失败", nil)
		return
	}
	fields := envelope.Fields{}
	if req.Username == "" {
		fields["username"] = "必填"
	}
	if req.Password == "" {
		fields["password"] = "必填"
	}
	if len(fields) > 0 {
		envelope.Fail(c, http.StatusBadRequest, envelope.CodeInvalidArg, "请求参数错误", fields)
		return
	}

	u, err := repo.FindAuthUser(ctx, h.db, req.Username)
	if err != nil {
		failInternal(c, err)
		return
	}
	ip := clientIPPtr(c)
	if u == nil {
		// 计时 oracle 封堵:未知用户名也跑一次同成本 bcrypt——否则按响应时长可枚举账号存在性
		_ = bcrypt.CompareHashAndPassword(dummyHash, []byte(req.Password))
		h.auditLoginFail(ctx, nil, req.Username, ip, "bad_user")
		envelope.Fail(c, http.StatusUnauthorized, envelope.CodeLoginFail, "用户名或密码错误", nil)
		return
	}
	if u.UserStatus != 1 {
		// 契约 §2.3"成功/失败均写 audit_log"——停用尝试入审计;该账号已禁,审计行不产副作用
		h.auditLoginFail(ctx, &u.ID, req.Username, ip, "banned")
		envelope.Fail(c, http.StatusForbidden, envelope.CodeUserBanned, "账号已停用", nil)
		return
	}
	// 锁定计数在 bcrypt 前判:防计时 oracle 且省 CPU(r-auth C2);计数源=audit_log 跨重启存活
	n, err := repo.CountRecentLoginFail(ctx, h.db, req.Username)
	if err != nil {
		failInternal(c, err)
		return
	}
	if n >= 5 {
		// 锁定分支有意不写 login_fail 审计——审计行会喂 CountRecentLoginFail 自我续锁;
		// 契约 §2.3"失败均写审计"对本分支显式豁免(撞锁事件本身已由先前 5 行 login_fail 记录)
		envelope.Fail(c, http.StatusTooManyRequests, envelope.CodeLoginLock, "登录失败次数过多,请15分钟后重试", nil)
		return
	}
	if err := bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(req.Password)); err != nil {
		h.auditLoginFail(ctx, &u.ID, req.Username, ip, "bad_password")
		envelope.Fail(c, http.StatusUnauthorized, envelope.CodeLoginFail, "用户名或密码错误", nil)
		return
	}

	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		failInternal(c, err)
		return
	}
	token := hex.EncodeToString(raw)
	sum := sha256.Sum256([]byte(token))
	tokenHash := hex.EncodeToString(sum[:])

	ts, err := h.clk.Now(ctx)
	if err != nil {
		failInternal(c, err)
		return
	}
	ua := c.Request.UserAgent()
	if len(ua) > 200 { // user_agent 列 varchar(200);按 rune 截断——字节截断会切裂多字节字符成 PG invalid byte
		r := []rune(ua)
		if len(r) > 200 {
			ua = string(r[:200])
		}
	}
	err = h.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := repo.InsertLoginSession(ctx, tx, u.ID, tokenHash, ip, ua); err != nil {
			return err
		}
		if err := repo.UpdateLastLogin(ctx, tx, u.ID, ts); err != nil {
			return err
		}
		return repo.InsertAudit(ctx, tx, repo.AuditRow{UserID: &u.ID, Username: u.Username, Action: "login", IP: ip})
	})
	if err != nil {
		failInternal(c, err)
		return
	}

	c.SetSameSite(http.SameSiteLaxMode)
	c.SetCookie("edss_sid", token, 43200, "/", "", h.secure, true)

	resp, err := buildAuthProfileResp(ctx, h.db, h.clk, u.ToContextUser())
	if err != nil {
		failInternal(c, err)
		return
	}
	envelope.OK(c, resp)
}

// Logout POST /api/v1/auth/logout(契约 §2.4)——幂等:有凭证吊销,无/失效凭证同样 code=0。
// 端点在会话中间件白名单内,此处自验凭证(取到则吊销,取不到不报错)。
func (h *Auth) Logout(c *gin.Context) {
	if token := authRequestToken(c); token != "" {
		sum := sha256.Sum256([]byte(token))
		// 吊销失败(如 DB 抖动)不翻改幂等响应;Cookie 照常清
		_ = repo.RevokeSession(c.Request.Context(), h.db, hex.EncodeToString(sum[:]))
	}
	c.SetSameSite(http.SameSiteLaxMode)
	c.SetCookie("edss_sid", "", -1, "/", "", h.secure, true)
	envelope.OK(c, nil)
}

// auditLoginFail 登录失败审计,best-effort——认证结论已判定,审计写失败不翻改响应
func (h *Auth) auditLoginFail(ctx context.Context, userID *int64, username string, ip *string, reason string) {
	detail, _ := json.Marshal(map[string]string{"reason": reason})
	_ = repo.InsertAudit(ctx, h.db, repo.AuditRow{
		UserID: userID, Username: username, Action: "login_fail", Detail: detail, IP: ip,
	})
}

// authRequestToken Cookie edss_sid → Authorization Bearer 序取凭证(middleware.requestToken 同式,
// 未导出故此处重复——两处以内不抽象)
func authRequestToken(c *gin.Context) string {
	if t, err := c.Cookie("edss_sid"); err == nil && t != "" {
		return t
	}
	if h := c.GetHeader("Authorization"); strings.HasPrefix(h, "Bearer ") {
		return strings.TrimPrefix(h, "Bearer ")
	}
	return ""
}

// clientIPPtr 客户端 IP;空值返 nil(audit_log.ip/user_session.ip inet 列 NULL=未知来源)
func clientIPPtr(c *gin.Context) *string {
	s := c.ClientIP()
	if s == "" {
		return nil
	}
	return &s
}

// sessionUser 会话中间件注入的身份;缺席=请求未经会话(白名单外/测试直挂路径)兜底 20001
func sessionUser(c *gin.Context) (middleware.SessionUser, bool) {
	v, ok := c.Get("session_user")
	if !ok {
		return middleware.SessionUser{}, false
	}
	u, ok := v.(middleware.SessionUser)
	return u, ok
}
