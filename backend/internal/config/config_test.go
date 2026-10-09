package config

import "testing"

func TestInvalidConfigFails(t *testing.T) {
	for _, item := range []struct{ k, v string }{{"SIM_ENABLED", "false"}, {"DEMO_ROLE_SWITCH", "yes"}, {"AUTH_COOKIE_SECURE", "2"}, {"DB_MAX_OPEN", "oops"}, {"PORT", "70000"}, {"LOG_LEVEL", "verbose"}} {
		t.Run(item.k, func(t *testing.T) {
			t.Setenv(item.k, item.v)
			if _, err := Load(); err == nil {
				t.Fatal("invalid config accepted")
			}
		})
	}
}

func TestPoolBounds(t *testing.T) {
	t.Setenv("DB_MAX_OPEN", "2")
	t.Setenv("DB_MAX_IDLE", "3")
	if _, err := Load(); err == nil {
		t.Fatal("invalid pool accepted")
	}
}
