// infra 端点挂根不入契约(同 /health 先例),见 EO epic
package handler

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"hospital-edss/internal/envelope"
	"hospital-edss/internal/middleware"
)

// System infra 端点 handler:/ready /stats
type System struct {
	db *gorm.DB
}

func NewSystem(db *gorm.DB) *System {
	return &System{db: db}
}

// Ready GET /ready——依赖面探活:db ping + sim.clock / dws.hospital_oper_day 均须有行
func (s *System) Ready(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 500*time.Millisecond)
	defer cancel()

	sqlDB, err := s.db.DB()
	if err == nil {
		err = sqlDB.PingContext(ctx)
	}
	var clockRows, operDayRows int64
	if err == nil {
		err = s.db.WithContext(ctx).Table("sim.clock").Count(&clockRows).Error
	}
	if err == nil {
		err = s.db.WithContext(ctx).Table("dws.hospital_oper_day").Count(&operDayRows).Error
	}
	if err == nil && (clockRows < 1 || operDayRows < 1) {
		err = fmt.Errorf("ready: 关键表无行 clock_rows=%d oper_day_rows=%d", clockRows, operDayRows)
	}
	if err != nil {
		_ = c.Error(err)
		envelope.Fail(c, http.StatusServiceUnavailable, envelope.CodeInternal, "服务未就绪", nil)
		return
	}
	envelope.OK(c, gin.H{"db": "up", "clock_rows": clockRows, "oper_day_rows": operDayRows})
}

// Stats GET /stats——进程请求计数 + 连接池指标
// (uptime 为运维墙钟:infra 口径非业务时间,豁免 sim.clock 纪律)
func (s *System) Stats(c *gin.Context) {
	rs := middleware.RequestStats()
	sqlDB, err := s.db.DB()
	if err != nil {
		_ = c.Error(err)
		envelope.Fail(c, http.StatusInternalServerError, envelope.CodeInternal, "系统繁忙,请稍后重试", nil)
		return
	}
	dbs := sqlDB.Stats()
	envelope.OK(c, gin.H{
		"uptime_s":       int64(time.Since(rs.StartedAt).Seconds()),
		"requests_total": rs.Total,
		"in_flight":      rs.InFlight,
		"by_status":      rs.ByStatus,
		"db": gin.H{
			"max_open":             dbs.MaxOpenConnections,
			"open":                 dbs.OpenConnections,
			"in_use":               dbs.InUse,
			"idle":                 dbs.Idle,
			"wait_count":           dbs.WaitCount,
			"wait_duration_ms":     dbs.WaitDuration.Milliseconds(),
			"max_idle_closed":      dbs.MaxIdleClosed,
			"max_idle_time_closed": dbs.MaxIdleTimeClosed,
			"max_lifetime_closed":  dbs.MaxLifetimeClosed,
		},
	})
}
