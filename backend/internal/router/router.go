// Package router 引擎装配与端点注册清单——各 epic 只改自己的 register_eN.go
package router

import (
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/envelope"
	"hospital-edss/internal/middleware"
)

// Deps handler 层共享依赖(E0 注入,epic 注册的 handler 只取用不重建)
type Deps struct {
	DB    *gorm.DB
	Clock *clock.Source
}

func Build(d *Deps) *gin.Engine {
	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(middleware.TraceID(), middleware.Recovery())

	r.GET("/health", func(c *gin.Context) { envelope.OK(c, gin.H{"status": "up"}) })

	v1 := r.Group("/api/v1")
	registerContextHome(v1, d) // E1:auth/profile · hospital/profile · home/*
	registerOps(v1, d)         // E2:overview · medical · operations · compare
	registerStaff(v1, d)       // E3:hr · research · patient · quality · assets · settings/config
	registerScreen(v1, d)      // E4:screen/snapshot · topics

	return r
}
