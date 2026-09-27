package router

import (
	"github.com/gin-gonic/gin"

	"hospital-edss/internal/handler"
)

// P3 epic 注册位——E0 stub,各 epic 在自己的 register_<epic>.go 填肉
// EA:auth login/logout · EW:alerts/todos/settings 写 · ES:sim 控制面 · EO:ready/stats
func registerAuth(v1 *gin.RouterGroup, d *Deps) {
	a := handler.NewAuth(d.DB, d.Clock)
	v1.POST("/auth/login", a.Login)   // §2.3
	v1.POST("/auth/logout", a.Logout) // §2.4
}
func registerWrite(v1 *gin.RouterGroup, d *Deps) {}
func registerSim(v1 *gin.RouterGroup, d *Deps)   {}
