package router

import "github.com/gin-gonic/gin"

// P3 epic 注册位——E0 stub,各 epic 在自己的 register_<epic>.go 填肉
// EA:auth login/logout · EW:alerts/todos/settings 写 · ES:sim 控制面 · EO:ready/stats
func registerAuth(v1 *gin.RouterGroup, d *Deps)   {}
func registerWrite(v1 *gin.RouterGroup, d *Deps)  {}
func registerSim(v1 *gin.RouterGroup, d *Deps)    {}
