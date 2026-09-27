// EDSS Go 后端入口:slog → config → pg pool → router → listen → 优雅停机
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"regexp"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/config"
	"hospital-edss/internal/router"
)

// dsnSecret 匹配 DSN 里的 user:pass@,仅保留 user——启动错误日志脱敏用
var dsnSecret = regexp.MustCompile(`//([^:/@]+):[^@]+@`)

func main() {
	lvl := slog.LevelInfo
	switch os.Getenv("LOG_LEVEL") {
	case "debug":
		lvl = slog.LevelDebug
	case "warn":
		lvl = slog.LevelWarn
	case "error":
		lvl = slog.LevelError
	}
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: lvl})))

	cfg, err := config.Load()
	if err != nil {
		slog.Error("config load failed", "error", err)
		os.Exit(1)
	}
	// DisableAutomaticPing:启动不预连——DB 停机时进程仍起,/ready 报 503(不可服务),
	// 池惰性连接,DB 恢复后自愈不重启;若启动即 fail-fast,/ready 永远到不了 503 分支
	db, err := gorm.Open(postgres.Open(cfg.DatabaseURL), &gorm.Config{DisableAutomaticPing: true})
	if err != nil {
		// 畸形 DSN 的解析错误文本会回显原始串(含口令)——脱敏后落日志
		slog.Error("db open failed", "error", dsnSecret.ReplaceAllString(err.Error(), "://$1:***@"))
		os.Exit(1)
	}
	sqlDB, err := db.DB()
	if err != nil {
		slog.Error("db handle failed", "error", err)
		os.Exit(1)
	}
	sqlDB.SetMaxOpenConns(cfg.DBMaxOpen)
	sqlDB.SetMaxIdleConns(cfg.DBMaxIdle)
	sqlDB.SetConnMaxLifetime(time.Duration(cfg.DBMaxLifetimeMin) * time.Minute)

	srv := &http.Server{
		Addr: ":" + cfg.Port,
		Handler: router.Build(&router.Deps{
			DB:             db,
			Clock:          clock.New(db),
			SimEnabled:     cfg.SimEnabled,
			TrustedProxies: cfg.TrustedProxies,
			CookieSecure:   cfg.AuthCookieSecure,
		}),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      60 * time.Second,
		IdleTimeout:       90 * time.Second,
	}
	go func() {
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			slog.Error("server failed", "error", err)
			os.Exit(1)
		}
	}()
	slog.Info("edss listening", "port", cfg.Port, "db_pool", gin.H{
		"max_open":         cfg.DBMaxOpen,
		"max_idle":         cfg.DBMaxIdle,
		"max_lifetime_min": cfg.DBMaxLifetimeMin,
	}, "sim_enabled", cfg.SimEnabled)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	<-ctx.Done()

	sctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	slog.Info("shutdown: draining")
	if err := srv.Shutdown(sctx); err != nil {
		slog.Error("shutdown failed", "error", err)
	}
	sqlDB.Close()
	slog.Info("shutdown: complete")
}
