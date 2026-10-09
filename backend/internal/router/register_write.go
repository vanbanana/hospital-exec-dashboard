// P3-EW 端点注册(契约 §15):alerts 生命周期×3 · todos 列表+状态 · staff 选择器 · settings 写×2——EW epic 属主文件
package router

import (
	"github.com/gin-gonic/gin"

	"hospital-edss/internal/handler"
	"hospital-edss/internal/repo"
)

func registerWrite(v1 *gin.RouterGroup, d *Deps) {
	h := handler.NewWriteHandler(repo.NewWriteRepo(d.DB, d.Clock))
	v1.POST("/alerts/:id/ack", h.AlertAck)                   // §15.1 R04
	v1.POST("/alerts/:id/dispatch", h.AlertDispatch)         // §15.2 R05
	v1.POST("/alerts/:id/close", h.AlertClose)               // §15.3 R06
	v1.GET("/todos", h.TodoList)                             // §15.4 R07
	v1.POST("/todos/:id/status", h.TodoStatus)               // §15.5 R08
	v1.GET("/staff", h.StaffList)                            // §15.6 R10
	v1.POST("/workbench/settings/rules/:code", h.RuleToggle) // §15.7 R15
	v1.GET("/workbench/settings/preferences", h.PrefsGet)
	v1.PUT("/workbench/settings/preferences", h.PrefsSave) // §15.8 R16
}
