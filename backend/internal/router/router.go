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
	DB         *gorm.DB
	Clock      *clock.Source
	SimEnabled bool // SIM_ENABLED=0 时 register_sim 不注册
}

func Build(d *Deps) *gin.Engine {
	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	// 仅信任本机回环代理的 X-Forwarded-For——gin 默认信任全部 CIDR,
	// 公网直连时伪造 XFF 可污染 audit_log/user_session 的 ip 列;
	// vite/nginx 反代与客户端不同机部署时按部署文档另行放开
	_ = r.SetTrustedProxies([]string{"127.0.0.1", "::1"})
	r.Use(middleware.TraceID(), middleware.RequestLog(), middleware.Recovery(), middleware.Session(d.DB))

	r.GET("/health", func(c *gin.Context) { envelope.OK(c, gin.H{"status": "up"}) })

	v1 := r.Group("/api/v1")
	registerContextHome(v1, d) // E1:auth/profile · hospital/profile · home/*
	registerOps(v1, d)         // E2:overview · medical · operations · compare
	registerStaff(v1, d)       // E3:hr · research · patient · quality · assets · settings/config
	registerScreen(v1, d)      // E4:screen/snapshot · topics
	registerAuth(v1, d)        // P3-EA:auth login/logout
	registerWrite(v1, d)       // P3-EW:alerts/todos/settings 写
	registerSim(v1, d)         // P3-ES:sim 控制面(SIM_ENABLED 门控)
	registerSystem(r, d)       // P3-EO:ready/stats

	r.NoRoute(func(c *gin.Context) {
		envelope.Fail(c, http.StatusNotFound, envelope.CodeNotFound, "资源不存在", nil)
	})

	return r
}
