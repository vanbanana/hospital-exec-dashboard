package middleware

import "github.com/gin-gonic/gin"

// RequestLog 请求日志——E0 noop stub,EO epic 填 slog 实现
func RequestLog() gin.HandlerFunc {
	return func(c *gin.Context) { c.Next() }
}
