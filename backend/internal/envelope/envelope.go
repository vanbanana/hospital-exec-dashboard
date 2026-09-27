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
	CodeFieldErr    = 10002 // 表单字段校验失败(data.fields 定位)
	CodeNotFound    = 10003 // 资源不存在
	CodeBadJSON     = 10006 // 请求体 JSON 解析失败
	CodeConflict    = 10007 // 资源状态冲突
	// 20xxx 认证授权
	CodeUnauth     = 20001 // 未认证/凭证缺失
	CodeSessExpire = 20002 // 会话过期
	CodeSessRevoke = 20003 // 会话已吊销
	CodeRoleDeny   = 20004 // 角色不符
	CodeScopeDeny  = 20005 // 数据域外访问
	// 201xx 登录子域
	CodeLoginFail  = 20101 // 账号或口令错误
	CodeUserBanned = 20102 // 账号停用
	CodeLoginLock  = 20104 // 登录失败锁定
	// 30xxx 资源域(预留端点引用)
	CodeResNotFound = 30001 // 资源不存在
	CodeResProtect  = 30002 // 资源受保护
	// 31xxx 指标域
	CodeNoData = 31004 // 指标口径正常但无数据(唯一 HTTP200 非0码)
	// 33xxx 告警督办
	CodeAlertNotFound = 33001 // 告警事件不存在
	CodeAlertConflict = 33002 // 告警已处理/状态冲突
	CodeAlertNoDrill  = 33003 // 告警不可下钻
	CodeTodoNotFound  = 33101 // 工单不存在
	CodeAssigneeBad   = 33102 // 指派人非法
	CodeDeadlineBad   = 33103 // 截止期非法
	CodeTodoClosed    = 33104 // 工单已关闭
	// 35xxx 仿真域
	CodeSimTierNA = 35002 // 该档位未开放
	// 42xxx 数据管道
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
