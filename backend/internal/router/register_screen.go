// E4 端点注册(screen/snapshot · topics)——E4 lead 属主文件,他人勿动
package router

import (
	"github.com/gin-gonic/gin"

	"hospital-edss/internal/handler"
)

func registerScreen(v1 *gin.RouterGroup, d *Deps) {
	sh := handler.NewScreenHandler(d.DB, d.Clock)
	th := handler.NewTopicsHandler(d.DB, d.Clock)
	v1.GET("/screen/snapshot", sh.Snapshot) // api-contract §14.1
	v1.GET("/workbench/topics", th.Topics)  // api-contract §13.1
}
