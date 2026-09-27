package middleware

import (
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// Session 会话解析——E0 noop stub,EA epic 填 PG 会话表实现
func Session(_ *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) { c.Next() }
}
