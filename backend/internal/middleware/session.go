// EA 会话认证——PG 会话表(sys.user_session)解析 + 端点白名单 + RBAC 矩阵。
// 凭证序:Cookie edss_sid → Authorization: Bearer(契约 §2.3 响应头注,Bearer 供 curl/断言)。
// 过期/续期判定全走 DB now() 传输层墙钟——文件内零 Go 墙钟调用(acceptance 机械自查纪律)。
package middleware

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

// SessionUser 会话解析出的当前身份,c.Set("session_user") 供 handler/RBAC 消费。
// dept_id/scope_type 随会话查询读取，生产策略用于按科室限制数据范围。
type SessionUser struct {
	ID        int64
	Username  string
	Role      string
	DeptID    *int64
	ScopeType string
}

// publicPaths 免会话端点(method+path 精确对)。
// logout 在白名单是幂等语义:无会话/失效会话调用同样 code=0,吊销由 Logout 内部自验凭证。
var publicPaths = map[string]struct{}{
	"GET /health":                  {},
	"GET /ready":                   {}, // compose healthcheck 探针,nginx 不透出(README §探针表)
	"GET /stats":                   {}, // 内部运维面,同上网络层隔离
	"POST /api/v1/auth/login":      {},
	"POST /api/v1/auth/logout":     {},
	"GET /api/v1/hospital/profile": {},
	"GET /api/v1/screen/snapshot":  {},
}

// Session 会话解析;凭证缺失→20001,非法/吊销/停用→20003,过期→20002
func Session(d *gorm.DB, cookieSecure bool) gin.HandlerFunc {
	return func(c *gin.Context) {
		_, public := publicPaths[c.Request.Method+" "+c.Request.URL.Path]
		if c.Request.URL.Path == "/api/v1/screen/snapshot" && os.Getenv("SCREEN_PUBLIC") == "0" {
			public = false
		}
		if public {
			c.Next()
			return
		}
		token := requestToken(c)
		if token == "" {
			deny(c, http.StatusUnauthorized, envelope.CodeUnauth, "未登录或凭证缺失")
			return
		}
		sum := sha256.Sum256([]byte(token))
		tokenHash := hex.EncodeToString(sum[:])
		sess, err := repo.ResolveSession(c.Request.Context(), d, tokenHash)
		if err != nil {
			deny(c, http.StatusInternalServerError, envelope.CodeInternal, "系统繁忙,请稍后重试")
			return
		}
		if sess == nil || sess.Revoked || sess.UserStatus != 1 {
			deny(c, http.StatusUnauthorized, envelope.CodeSessRevoke, "凭证非法/被吊销")
			return
		}
		if sess.Expired {
			deny(c, http.StatusUnauthorized, envelope.CodeSessExpire, "凭证已过期")
			return
		}
		u := SessionUser{ID: sess.UserID, Username: sess.Username, Role: sess.Role, DeptID: sess.DeptID, ScopeType: sess.ScopeType}
		c.Set("session_user", u)
		if sess.Renew { // 剩余 <6h 滑动续期:异步写不阻塞响应,失败留给下次请求再试
			go func() {
				ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
				defer cancel()
				// fire-and-forget 语义不变,但失败须可观测——静默吞错时 12h 到期丢会话无迹可查
				if err := repo.RenewSessionExpiry(ctx, d, tokenHash); err != nil {
					slog.Warn("session renew failed", "err", err)
				}
			}()
			// Cookie 轨同步重签——登录 Cookie Max-Age=43200 固定,不续签浏览器 12h 到期
			// 照样丢 edss_sid,服务端续期只对 Bearer 轨生效
			if _, err := c.Cookie("edss_sid"); err == nil {
				c.SetSameSite(http.SameSiteLaxMode)
				c.SetCookie("edss_sid", token, 43200, "/", "", cookieSecure, true)
			}
		}
		// Include data-scope denials raised inside handlers, not only route-policy denials.
		defer func() {
			if c.Writer.Status() == http.StatusForbidden {
				if err := repo.InsertAudit(c.Request.Context(), d, repo.AuditRow{UserID: &u.ID, Username: u.Username, Action: "access_denied", Detail: []byte(`{"reason":"role_or_scope"}`)}); err != nil {
					slog.Warn("access audit failed", "err", err)
				}
			}
		}()
		if !rbacCheck(c, u) {
			return
		}
		c.Next()
	}
}

// requestToken Cookie edss_sid → Authorization Bearer 序取凭证;皆无返空串
func requestToken(c *gin.Context) string {
	if t, err := c.Cookie("edss_sid"); err == nil && t != "" {
		return t
	}
	if h := c.GetHeader("Authorization"); strings.HasPrefix(h, "Bearer ") {
		return strings.TrimPrefix(h, "Bearer ")
	}
	return ""
}

func deny(c *gin.Context, status, code int, msg string) {
	envelope.Fail(c, status, code, msg, nil)
	c.Abort()
}
