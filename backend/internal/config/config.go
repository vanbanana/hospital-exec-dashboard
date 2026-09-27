// Package config 启动期 fail-fast 加载环境配置(AGENTS §3.3:配置缺失启动即报)
package config

import (
	"fmt"
	"os"
)

type Config struct {
	DatabaseURL string // postgres DSN,默认本地演示库
	Port        string // 监听端口
}

func Load() (*Config, error) {
	c := &Config{
		DatabaseURL: envOr("DATABASE_URL", "postgres://localhost/hospital_edss?sslmode=disable"),
		Port:        envOr("PORT", "8080"),
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
