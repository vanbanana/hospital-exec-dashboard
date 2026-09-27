// Package middleware 横切件:trace_id 生成 + panic 统一回收为 10000
package middleware

import (
	"crypto/rand"
	"encoding/hex"
	"net/http"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/envelope"
)

// TraceID 每请求生成 12 位 hex trace_id,注入 ctx 供包络回写
func TraceID() gin.HandlerFunc {
	return func(c *gin.Context) {
		b := make([]byte, 6)
		if _, err := rand.Read(b); err != nil {
			c.Set("trace_id", "nofallback")
		} else {
			c.Set("trace_id", hex.EncodeToString(b))
		}
		c.Next()
	}
}

// Recovery panic 回收为包络 10000,不裸吐堆栈给客户端(error-codes §3 10000)
func Recovery() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if rec := recover(); rec != nil {
				envelope.Fail(c, http.StatusInternalServerError, envelope.CodeInternal, "系统繁忙,请稍后重试", nil)
				c.Abort()
			}
		}()
		c.Next()
	}
}
