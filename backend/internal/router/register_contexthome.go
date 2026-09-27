// E1 端点注册(auth/profile · hospital/profile · home/*)——E1 lead 属主文件,他人勿动
package router

import (
	"github.com/gin-gonic/gin"

	"hospital-edss/internal/handler"
)

func registerContextHome(v1 *gin.RouterGroup, d *Deps) {
	ch := handler.NewContext(d.DB, d.Clock)
	v1.GET("auth/profile", ch.AuthProfile)       // §2.1
	v1.GET("hospital/profile", ch.HospitalProfile) // §2.2

	hh := handler.NewHome(d.DB, d.Clock)
	home := v1.Group("workbench/home") // §3.1~§3.7
	home.GET("kpis", hh.Kpis)
	home.GET("trends", hh.Trends)
	home.GET("top10", hh.Top10)
	home.GET("indicators", hh.Indicators)
	home.GET("progress", hh.Progress)
	home.GET("alerts", hh.Alerts)
	home.GET("notices", hh.Notices)
}
