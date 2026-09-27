// ES 仿真控制面注册(契约 §16 档 A)——ES epic 属主文件
package router

import (
	"github.com/gin-gonic/gin"

	"hospital-edss/internal/handler"
)

func registerSim(v1 *gin.RouterGroup, d *Deps) {
	if !d.SimEnabled {
		return // SIM_ENABLED=0 → 不注册 → NoRoute 10003(契约 §16 环境门控)
	}
	h := handler.NewSim(d.DB, d.Clock)
	s := v1.Group("/sim")
	s.GET("/clock", h.Clock)
	s.POST("/clock", h.SetClock)
	s.POST("/tick", h.Tick)
	s.POST("/reset", h.Reset)
	s.GET("/jobs", h.Jobs)
}
