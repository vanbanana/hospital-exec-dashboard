// E2 端点注册(overview · medical · operations · compare)——E2 lead 属主文件,他人勿动
package router

import (
	"github.com/gin-gonic/gin"

	"hospital-edss/internal/handler"
)

func registerOps(v1 *gin.RouterGroup, d *Deps) {
	h := handler.NewOpsHandler(d.DB, d.Clock)
	wb := v1.Group("/workbench")
	wb.GET("/overview", h.Overview)     // 契约 §4
	wb.GET("/medical", h.Medical)       // 契约 §5
	wb.GET("/operations", h.Operations) // 契约 §6
	wb.GET("/compare", h.Compare)       // 契约 §12
}
