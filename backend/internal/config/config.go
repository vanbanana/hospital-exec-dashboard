// Package config 启动期 fail-fast 加载环境配置(AGENTS §3.3:配置缺失启动即报)
package config

import (
	"fmt"
	"os"
	"strconv"
)

type Config struct {
	DatabaseURL string // postgres DSN,默认本地演示库
	Port        string // 监听端口
	// P3 新增——默认值即演示环境可跑;prod 由 .env/compose 覆写
	AuthCookieSecure bool   // HTTPS 部署置 1:edss_sid 追加 Secure
	SimEnabled       bool   // /sim/* 路由开关;0=不注册(撞 NoRoute 10003)
	DBMaxOpen        int    // 连接池上限
	DBMaxIdle        int    // 空闲连接
	DBMaxLifetimeMin int    // 连接最大存活(分钟)
	LogLevel         string // slog 级别:debug|info|warn|error
}

func Load() (*Config, error) {
	c := &Config{
		DatabaseURL:      envOr("DATABASE_URL", "postgres://localhost/hospital_edss?sslmode=disable"),
		Port:             envOr("PORT", "8080"),
		AuthCookieSecure: envOr("AUTH_COOKIE_SECURE", "") == "1",
		SimEnabled:       envOr("SIM_ENABLED", "1") != "0",
		DBMaxOpen:        envInt("DB_MAX_OPEN", 25),
		DBMaxIdle:        envInt("DB_MAX_IDLE", 5),
		DBMaxLifetimeMin: envInt("DB_MAX_LIFETIME_MIN", 30),
		LogLevel:         envOr("LOG_LEVEL", "info"),
	}
	if c.DatabaseURL == "" || c.Port == "" {
		return nil, fmt.Errorf("config: DATABASE_URL 与 PORT 均不可为空")
	}
	return c, nil
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func envInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			return n
		}
	}
	return fallback
}
