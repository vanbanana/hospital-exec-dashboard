// Package router 引擎装配与端点注册清单——各 epic 只改自己的 register_eN.go
package router

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/envelope"
	"hospital-edss/internal/middleware"
)

// Deps handler 层共享依赖(E0 注入,epic 注册的 handler 只取用不重建)
type Deps struct {
	DB             *gorm.DB
	Clock          *clock.Source
	SimEnabled     bool     // SIM_ENABLED=0 时 register_sim 不注册
	TrustedProxies []string // XFF 可信代理 CIDR;空=不信任任何代理(ClientIP=直连地址)
}

func Build(d *Deps) *gin.Engine {
	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	// X-Forwarded-For 仅信任 TRUSTED_PROXY_CIDRS(默认本机回环)——gin 默认信任全部
	// CIDR,公网直连伪造 XFF 可污染 audit_log/user_session 的 ip 列;
	// nginx 反代异机/异容器部署时经 env 放开(config.go)
	_ = r.SetTrustedProxies(d.TrustedProxies)
	r.Use(middleware.TraceID(), middleware.RequestLog(), middleware.Recovery(), middleware.Session(d.DB))

	r.GET("/health", func(c *gin.Context) { envelope.OK(c, gin.H{"status": "up"}) })

	v1 := r.Group("/api/v1")
	v1.Use(middleware.BodyLimit(1 << 20)) // JSON 写端点 1MiB 上限,超限走 10006 包络
	registerContextHome(v1, d)            // E1:auth/profile · hospital/profile · home/*
	registerOps(v1, d)                    // E2:overview · medical · operations · compare
	registerStaff(v1, d)                  // E3:hr · research · patient · quality · assets · settings/config
	registerScreen(v1, d)                 // E4:screen/snapshot · topics
	registerAuth(v1, d)                   // P3-EA:auth login/logout
	registerWrite(v1, d)                  // P3-EW:alerts/todos/settings 写
	registerSim(v1, d)                    // P3-ES:sim 控制面(SIM_ENABLED 门控)
	registerSystem(r, d)                  // P3-EO:ready/stats

	r.NoRoute(func(c *gin.Context) {
		envelope.Fail(c, http.StatusNotFound, envelope.CodeNotFound, "资源不存在", nil)
	})

	return r
}
