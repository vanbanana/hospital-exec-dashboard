package router

import (
	"github.com/gin-gonic/gin"

	"hospital-edss/internal/handler"
)

// P3 epic 注册位——E0 stub,各 epic 在自己的 register_<epic>.go 填肉
// EA:auth login/logout
// (EW 已迁 register_write.go · ES 已迁 register_sim.go · EO 已迁 register_system.go 根级)
func registerAuth(v1 *gin.RouterGroup, d *Deps) {
	a := handler.NewAuth(d.DB, d.Clock, d.CookieSecure)
	v1.POST("/auth/login", a.Login)   // §2.3
	v1.POST("/auth/logout", a.Logout) // §2.4
}
