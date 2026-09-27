// E3 端点注册(hr · research · patient · quality · assets · settings/config)——E3 lead 属主文件,他人勿动
package router

import (
	"github.com/gin-gonic/gin"

	"hospital-edss/internal/handler"
	"hospital-edss/internal/repo"
)

func registerStaff(v1 *gin.RouterGroup, d *Deps) {
	h := handler.NewStaffHandler(repo.NewStaffRepo(d.DB, d.Clock))
	wb := v1.Group("/workbench")
	wb.GET("/hr", h.Hr)                          // §7.1
	wb.GET("/research", h.Research)              // §8.1
	wb.GET("/patient", h.Patient)                // §9.1
	wb.GET("/quality", h.Quality)                // §10.1
	wb.GET("/assets", h.Assets)                  // §11.1
	wb.GET("/settings/config", h.SettingsConfig) // §13.2
}
