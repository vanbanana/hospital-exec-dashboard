// P3-EO infra 端点:/ready /stats 挂根不进 /api/v1(契约冻结,同 /health 先例)
package router

import (
	"github.com/gin-gonic/gin"

	"hospital-edss/internal/handler"
)

func registerSystem(r *gin.Engine, d *Deps) {
	h := handler.NewSystem(d.DB)
	r.GET("/ready", h.Ready)
	r.GET("/stats", h.Stats)
}
