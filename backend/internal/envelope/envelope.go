// Package envelope 统一响应包络——唯一出口(error-codes.md §1)
// 成功:{code:0,message:"ok",data,trace_id,ts};失败:{code:非0,message,data:null|{fields},trace_id,ts}
package envelope

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

// 错误码注册表子集——仅服务端实际会发出的码(error-codes.md §3)
const (
	CodeOK          = 0
	CodeInternal    = 10000 // 系统繁忙
	CodeInvalidArg  = 10001 // 请求参数错误(枚举外/必填缺席)
	CodeNotFound    = 10003 // 资源不存在
	CodeNoData      = 31004 // 指标口径正常但无数据(唯一 HTTP200 非0码)
	CodeUpstreamNil = 42001 // 数据管道无上游数据(预留)
)

// Fields 校验明细载体(error-codes §1 data.fields)
type Fields map[string]string

func traceID(c *gin.Context) string {
	if v, ok := c.Get("trace_id"); ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}

// OK 成功响应
func OK(c *gin.Context, data any) {
	c.JSON(http.StatusOK, gin.H{
		"code":     CodeOK,
		"message":  "ok",
		"data":     data,
		"trace_id": traceID(c),
		"ts":       time.Now().Unix(),
	})
}

// Fail 失败响应;fields 为 nil 时 data 输出 null
func Fail(c *gin.Context, httpStatus, code int, message string, fields Fields) {
	var data any
	if fields != nil {
		data = gin.H{"fields": fields}
	}
	c.JSON(httpStatus, gin.H{
		"code":     code,
		"message":  message,
		"data":     data,
		"trace_id": traceID(c),
		"ts":       time.Now().Unix(),
	})
}

// InvalidArg 参数校验失败的统一短路(handler 内 return 即停)
func InvalidArg(c *gin.Context, field, msg string) {
	Fail(c, http.StatusBadRequest, CodeInvalidArg, "请求参数错误", Fields{field: msg})
}
