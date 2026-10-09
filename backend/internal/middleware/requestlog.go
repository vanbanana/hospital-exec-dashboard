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
	ByRoute   map[string]RouteStats
}

// Finite bounds plus an overflow bucket keep memory independent of traffic volume.
var LatencyBoundsMS = [...]float64{1, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000}

type RouteStats struct {
	Count          int64                           `json:"count"`
	Errors5xx      int64                           `json:"errors_5xx"`
	LatencySumMS   float64                         `json:"latency_sum_ms"`
	LatencyMaxMS   float64                         `json:"latency_max_ms"`
	LatencyBuckets [len(LatencyBoundsMS) + 1]int64 `json:"latency_buckets"`
}

var (
	reqStartedAt = time.Now()
	reqInFlight  atomic.Int64
	reqTotal     atomic.Int64
	reqByStatus  = struct {
		sync.Mutex
		m      map[int]int64
		routes map[string]RouteStats
	}{m: make(map[int]int64), routes: make(map[string]RouteStats)}
)

// RequestStats 计数快照(byStatus 拷出,调用方只读)
func RequestStats() ReqStats {
	reqByStatus.Lock()
	defer reqByStatus.Unlock()
	cp := make(map[int]int64, len(reqByStatus.m))
	for k, v := range reqByStatus.m {
		cp[k] = v
	}
	routes := make(map[string]RouteStats, len(reqByStatus.routes))
	for k, v := range reqByStatus.routes {
		routes[k] = v
	}
	return ReqStats{
		StartedAt: reqStartedAt,
		InFlight:  reqInFlight.Load(),
		Total:     reqTotal.Load(),
		ByStatus:  cp,
		ByRoute:   routes,
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
		route := c.FullPath()
		if route == "" {
			route = "__unmatched__" // NoRoute 命中时归一,防扫描噪声撑高 route 基数
		}
		method := c.Request.Method
		switch method {
		case "GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS", "CONNECT", "TRACE":
		default:
			method = "OTHER"
		}
		elapsed := time.Since(start)
		ms := float64(elapsed) / float64(time.Millisecond)
		key := method + " " + route
		reqByStatus.Lock()
		reqTotal.Add(1)
		reqByStatus.m[status]++
		if _, exists := reqByStatus.routes[key]; !exists && len(reqByStatus.routes) >= 255 {
			key = "OTHER __overflow__"
		}
		metric := reqByStatus.routes[key]
		metric.Count++
		if status >= 500 {
			metric.Errors5xx++
		}
		metric.LatencySumMS += ms
		if ms > metric.LatencyMaxMS {
			metric.LatencyMaxMS = ms
		}
		bucket := len(LatencyBoundsMS)
		for i, bound := range LatencyBoundsMS {
			if ms <= bound {
				bucket = i
				break
			}
		}
		metric.LatencyBuckets[bucket]++
		reqByStatus.routes[key] = metric
		reqByStatus.Unlock()
		args := []any{
			"method", c.Request.Method,
			"route", route,
			"status", status,
			"latency_ms", elapsed.Milliseconds(),
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
