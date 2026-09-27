package middleware

import (
	"log/slog"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gin-gonic/gin"
)

// ReqStats 进程内请求计数快照——/stats 数据源(infra 口径,非业务数据)
type ReqStats struct {
	StartedAt time.Time
	InFlight  int64
	Total     int64
	ByStatus  map[int]int64
}

var (
	reqStartedAt = time.Now()
	reqInFlight  atomic.Int64
	reqTotal     atomic.Int64
	reqByStatus  = struct {
		sync.Mutex
		m map[int]int64
	}{m: make(map[int]int64)}
)

// RequestStats 计数快照(byStatus 拷出,调用方只读)
func RequestStats() ReqStats {
	reqByStatus.Lock()
	defer reqByStatus.Unlock()
	cp := make(map[int]int64, len(reqByStatus.m))
	for k, v := range reqByStatus.m {
		cp[k] = v
	}
	return ReqStats{
		StartedAt: reqStartedAt,
		InFlight:  reqInFlight.Load(),
		Total:     reqTotal.Load(),
		ByStatus:  cp,
	}
}

// RequestLog 请求日志 + 计数:c.Next() 后落一行 JSON,status≥500 升 Error;
// handler 挂上 c.Error 的内部 err 随 errors 字段落明细(明细不出包络,见 error-codes §3)
func RequestLog() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		reqInFlight.Add(1)
		defer reqInFlight.Add(-1)

		c.Next()

		status := c.Writer.Status()
		reqTotal.Add(1)
		reqByStatus.Lock()
		reqByStatus.m[status]++
		reqByStatus.Unlock()

		route := c.FullPath()
		if route == "" {
			route = "__unmatched__" // NoRoute 命中时归一,防扫描噪声撑高 route 基数
		}
		args := []any{
			"method", c.Request.Method,
			"route", route,
			"status", status,
			"latency_ms", time.Since(start).Milliseconds(),
			"trace_id", c.GetString("trace_id"),
		}
		if len(c.Errors) > 0 {
			args = append(args, "errors", c.Errors.String())
		}
		if status >= 500 {
			slog.ErrorContext(c.Request.Context(), "request", args...)
		} else {
			slog.InfoContext(c.Request.Context(), "request", args...)
		}
	}
}
