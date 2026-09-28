// Package router 引擎装配与端点注册清单——各 epic 只改自己的 register_eN.go
package router

import (
	"log"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/config"
	"hospital-edss/internal/envelope"
	"hospital-edss/internal/middleware"
)

// Deps handler 层共享依赖(E0 注入,epic 注册的 handler 只取用不重建)
type Deps struct {
	DB             *gorm.DB
	Clock          *clock.Source
	SimEnabled     bool     // SIM_ENABLED=0 时 register_sim 不注册
	TrustedProxies []string // XFF 可信代理 CIDR;空=不信任任何代理(ClientIP=直连地址)
	CookieSecure   bool     // AUTH_COOKIE_SECURE:edss_sid 追加 Secure(TLS 部署置 1)
}

func Build(d *Deps) *gin.Engine {
	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	// X-Forwarded-For 仅信任 TRUSTED_PROXY_CIDRS(默认本机回环)——gin 默认信任全部
	// CIDR,公网直连伪造 XFF 可污染 audit_log/user_session 的 ip 列;
	// nginx 反代异机/异容器部署时经 env 放开(config.go)
	// 非法 CIDR 不可静默吞——吞错会让代理白名单部分生效(截断的 cidr 列表已装入),
	// 配置错必须启动即失败
	if err := r.SetTrustedProxies(d.TrustedProxies); err != nil {
		log.Fatalf("TRUSTED_PROXY_CIDRS 配置非法: %v", err)
	}
	// 已注册路径的错误方法→405+10004;不开此开关时 gin 落到 NoRoute 误报 10003
	r.HandleMethodNotAllowed = true
	// DEMO_ROLE_SWITCH(env,默认 1=演示态)——cmd/server 装配缝不在 P1 lane 白名单,
	// Build 经 config 直读 env;置 0=生产形态:?role= 失切换力/写侧异名 20004(契约 §2.1 演进注)
	demoSwitch := config.DemoRoleSwitchOn()
	r.Use(securityHeaders(), prodModeCtx(demoSwitch),
		middleware.TraceID(), middleware.RequestLog(), middleware.Recovery(), middleware.Session(d.DB, d.CookieSecure))

	r.GET("/health", func(c *gin.Context) { envelope.OK(c, gin.H{"status": "up"}) })

	v1 := r.Group("/api/v1")
	v1.Use(middleware.BodyLimit(1<<20), prodRoleGate(demoSwitch)) // JSON 写端点 1MiB 上限,超限走 10006 包络;生产态写侧 ?role= 异名 20004
	registerContextHome(v1, d)                                    // E1:auth/profile · hospital/profile · home/*
	registerOps(v1, d)                                            // E2:overview · medical · operations · compare
	registerStaff(v1, d)                                          // E3:hr · research · patient · quality · assets · settings/config
	registerScreen(v1, d)                                         // E4:screen/snapshot · topics
	registerAuth(v1, d)                                           // P3-EA:auth login/logout
	registerWrite(v1, d)                                          // P3-EW:alerts/todos/settings 写
	registerSim(v1, d)                                            // P3-ES:sim 控制面(SIM_ENABLED 门控)
	registerSystem(r, d)                                          // P3-EO:ready/stats

	r.NoRoute(func(c *gin.Context) {
		envelope.Fail(c, http.StatusNotFound, envelope.CodeNotFound, "资源不存在", nil)
	})
	// NoMethod 随全局中间件链执行(会话先决)——无凭证的错误方法请求仍先撞 20001
	r.NoMethod(func(c *gin.Context) {
		envelope.Fail(c, http.StatusMethodNotAllowed, envelope.CodeMethodNA, "请求方法不支持", nil)
	})

	return r
}

// securityHeaders 全局安全响应头(P1 安全加固,OWASP 基线)——挂链首,中间件拒答
// (20001/NoRoute/NoMethod)同样带头。Cache-Control no-store 仅 /api/ 面:
// API 响应禁缓存(防共享代理缓存个人上下文);静态资产缓存策略在 nginx 层。
// CSP 收敛自"ECharts canvas + Vue scoped、无 inline script"实测面——后端只出 JSON,
// CSP 对非渲染响应惰性生效;真正约束 SPA 的同源块在 deploy/nginx.conf
func securityHeaders() gin.HandlerFunc {
	return func(c *gin.Context) {
		h := c.Writer.Header()
		h.Set("X-Content-Type-Options", "nosniff")
		h.Set("X-Frame-Options", "DENY")
		h.Set("Referrer-Policy", "strict-origin-when-cross-origin")
		h.Set("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
		h.Set("Content-Security-Policy",
			"default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self'")
		if strings.HasPrefix(c.Request.URL.Path, "/api/") {
			h.Set("Cache-Control", "no-store")
		}
		c.Next()
	}
}

// prodModeCtx DEMO_ROLE_SWITCH 注入请求上下文——handler.AuthProfile/Login 经
// demoSwitchOn() 读取;键缺席(直挂测试)默认演示态
func prodModeCtx(demoSwitch bool) gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Set("demo_role_switch", demoSwitch)
		c.Next()
	}
}

// prodRoleGate 生产形态写侧闸(契约 §2.1 演进注:DEMO_ROLE_SWITCH=0 时写侧
// ?role= 异名一律 20004)——仅拦非读方法且 ?role= 出席:值≠会话 username→403/20004;
// 同值自指放行(handler operator() 同值路径不变)。会话缺席=?role= 所署身份
// 无从对证,同按异名拒(仅 publicPaths 写端点会走到此:login/logout 携参无义)
func prodRoleGate(demoSwitch bool) gin.HandlerFunc {
	return func(c *gin.Context) {
		if demoSwitch {
			c.Next()
			return
		}
		switch c.Request.Method {
		case http.MethodGet, http.MethodHead, http.MethodOptions:
			c.Next() // 读侧 ?role= 由端点内按忽略处理,闸只管写面
			return
		}
		if v, present := c.GetQuery("role"); present {
			if su, ok := c.Get("session_user"); ok {
				if u, ok := su.(middleware.SessionUser); ok && u.Username == v {
					c.Next()
					return
				}
			}
			envelope.Fail(c, http.StatusForbidden, envelope.CodeRoleDeny, "无权访问该资源", nil)
			c.Abort()
			return
		}
		c.Next()
	}
}
