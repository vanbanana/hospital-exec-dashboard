// Package config 启动期 fail-fast 加载环境配置(AGENTS §3.3:配置缺失启动即报)
package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

type Config struct {
	DatabaseURL string // postgres DSN,默认本地演示库
	Port        string // 监听端口
	// P3 新增——默认值即演示环境可跑;prod 由 .env/compose 覆写
	AuthCookieSecure bool // HTTPS 部署置 1:edss_sid 追加 Secure
	SimEnabled       bool // /sim/* 路由开关;0=不注册(撞 NoRoute 10003)
	// DemoRoleSwitch DEMO_ROLE_SWITCH(默认 1=演示态;生产置 0)——演示角色切换总闸:
	// ?role= 切换力、available_roles 名录、写侧异名拒答,语义见契约 §2.1 演进注(生产形态)
	DemoRoleSwitch   bool
	DBMaxOpen        int    // 连接池上限
	DBMaxIdle        int    // 空闲连接
	DBMaxLifetimeMin int    // 连接最大存活(分钟)
	LogLevel         string // slog 级别:debug|info|warn|error
	// TrustedProxies X-Forwarded-For 可信代理 CIDR 集——默认仅本机回环;
	// 反代(nginx 等)与后端不同机/不同容器时以 TRUSTED_PROXY_CIDRS 放开,
	// 否则 audit_log/user_session 的 ip 列记成代理地址
	TrustedProxies []string
}

func Load() (*Config, error) {
	for _, key := range []string{"SIM_ENABLED", "DEMO_ROLE_SWITCH", "AUTH_COOKIE_SECURE", "SCREEN_PUBLIC"} {
		if v, ok := os.LookupEnv(key); ok && v != "" && v != "0" && v != "1" {
			return nil, fmt.Errorf("%s must be 0 or 1", key)
		}
	}
	for _, key := range []string{"DB_MAX_OPEN", "DB_MAX_IDLE", "DB_MAX_LIFETIME_MIN", "PORT"} {
		if v := os.Getenv(key); v != "" {
			n, e := strconv.Atoi(v)
			if e != nil || n < 1 || (key == "PORT" && n > 65535) {
				return nil, fmt.Errorf("%s must be a valid positive integer", key)
			}
		}
	}
	switch envOr("LOG_LEVEL", "info") {
	case "debug", "info", "warn", "error":
	default:
		return nil, fmt.Errorf("LOG_LEVEL is invalid")
	}

	cfg := &Config{
		DatabaseURL:      envOr("DATABASE_URL", "postgres://localhost/hospital_edss?sslmode=disable"),
		Port:             envOr("PORT", "8080"),
		AuthCookieSecure: envOr("AUTH_COOKIE_SECURE", "") == "1",
		SimEnabled:       envOr("SIM_ENABLED", "1") != "0",
		DemoRoleSwitch:   DemoRoleSwitchOn(),
		DBMaxOpen:        envInt("DB_MAX_OPEN", 25),
		DBMaxIdle:        envInt("DB_MAX_IDLE", 5),
		DBMaxLifetimeMin: envInt("DB_MAX_LIFETIME_MIN", 30),
		LogLevel:         envOr("LOG_LEVEL", "info"),
		TrustedProxies:   envList("TRUSTED_PROXY_CIDRS", "127.0.0.1,::1"),
	}
	if cfg.DBMaxIdle > cfg.DBMaxOpen {
		return nil, fmt.Errorf("DB_MAX_IDLE must not exceed DB_MAX_OPEN")
	}
	return cfg, nil
}

// DemoRoleSwitchOn 与 Load 同判据的独立读取口——cmd/server 装配缝(main.go)不在
// P1 lane 白名单内,Deps 暂不能携此 flag;router.Build 经此直读 env,字段留作接线面
func DemoRoleSwitchOn() bool {
	return envOr("DEMO_ROLE_SWITCH", "1") != "0"
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

// envList 逗号分隔列表 env(空白项丢弃):未设回退默认串;显式置空串→空列表
// (TRUSTED_PROXY_CIDRS="" 语义=不信任任何代理,区别于未设=回环默认)
func envList(key, fallback string) []string {
	v, set := os.LookupEnv(key)
	if !set {
		v = fallback
	}
	var out []string
	for _, s := range strings.Split(v, ",") {
		if s = strings.TrimSpace(s); s != "" {
			out = append(out, s)
		}
	}
	return out
}
