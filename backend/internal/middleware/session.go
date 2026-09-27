// EA 会话认证——PG 会话表(sys.user_session)解析 + 端点白名单 + RBAC 矩阵。
// 凭证序:Cookie edss_sid → Authorization: Bearer(契约 §2.3 响应头注,Bearer 供 curl/断言)。
// 过期/续期判定全走 DB now() 传输层墙钟——文件内零 Go 墙钟调用(acceptance 机械自查纪律)。
package middleware

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

// SessionUser 会话解析出的当前身份,c.Set("session_user") 供 handler/RBAC 消费。
// dept_id/scope 数据域列留 P3.1 启用时再加(r-auth C3 分期)。
type SessionUser struct {
	ID       int64
	Username string
	Role     string
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
func Session(d *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		if _, ok := publicPaths[c.Request.Method+" "+c.Request.URL.Path]; ok {
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
		u := SessionUser{ID: sess.UserID, Username: sess.Username, Role: sess.Role}
		c.Set("session_user", u)
		if sess.Renew { // 剩余 <6h 滑动续期:异步写不阻塞响应,失败留给下次请求再试
			go func() {
				ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
				defer cancel()
				_ = repo.RenewSessionExpiry(ctx, d, tokenHash)
			}()
		}
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
