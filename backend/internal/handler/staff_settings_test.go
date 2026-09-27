// Package handler_test §13.2 settings/config 端点 handler 级测试——直连演示库
// (种子锚定 sim.clock=2026-10-28;期望值见 e3-design §13.2 与契约 §13.2)。
package handler_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"regexp"
	"testing"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/handler"
	"hospital-edss/internal/middleware"
	"hospital-edss/internal/repo"
)

func settingsRouter(t *testing.T) *gin.Engine {
	t.Helper()
	db := snapDB(t)
	h := handler.NewStaffHandler(repo.NewStaffRepo(db, clock.New(db)))
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(middleware.TraceID())
	// §2.1 演进注:preferences 取会话用户 id——handler 直连测试注入会话替身(等价 Session 中间件产物)
	r.Use(func(c *gin.Context) {
		c.Set("session_user", middleware.SessionUser{ID: 1, Username: "president", Role: "president"})
		c.Next()
	})
	r.GET("/api/v1/workbench/settings/config", h.SettingsConfig)
	return r
}

func settingsData(t *testing.T, path string) map[string]any {
	t.Helper()
	r := settingsRouter(t)
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, path, nil)
	r.ServeHTTP(w, req)
	var body map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("json: %v body=%s", err, w.Body.String())
	}
	if w.Code != http.StatusOK || body["code"] != float64(0) {
		t.Fatalf("status=%d body=%v", w.Code, body)
	}
	d, ok := body["data"].(map[string]any)
	if !ok {
		t.Fatalf("data 缺失: %v", body["data"])
	}
	return d
}

// 包络形态 + 无声明参数照常 200(§13.2 无查询参数,未知参数忽略)
func TestStaffSettingsEnvelope(t *testing.T) {
	r := settingsRouter(t)
	for _, path := range []string{
		"/api/v1/workbench/settings/config",
		"/api/v1/workbench/settings/config?foo=bar&range=x",
	} {
		w := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, path, nil)
		r.ServeHTTP(w, req)
		var body map[string]any
		if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
			t.Fatalf("%s json: %v", path, err)
		}
		if w.Code != http.StatusOK || body["code"] != float64(0) {
			t.Fatalf("%s status=%d body=%v", path, w.Code, body)
		}
		if body["message"] != "ok" {
			t.Fatalf("message=%v", body["message"])
		}
		if s, ok := body["trace_id"].(string); !ok || len(s) != 12 {
			t.Fatalf("trace_id=%v", body["trace_id"])
		}
	}
}

// data_sources 6 行契约序 + dict 标签 + sync 时间格式
func TestStaffSettingsDataSources(t *testing.T) {
	srcs, ok := settingsData(t, "/api/v1/workbench/settings/config")["data_sources"].([]any)
	if !ok || len(srcs) != 6 {
		t.Fatalf("data_sources=%v", srcs)
	}
	type want struct{ name, typ, status, sync string }
	wants := []want{
		{"HIS 门诊收费系统", "业务库 · 准实时", "已连接", "2026-10-28 09:42"},
		{"HIS 住院管理系统", "业务库 · 准实时", "已连接", "2026-10-28 09:42"},
		{"EMR 电子病历", "业务库 · 小时级", "已连接", "2026-10-28 09:00"},
		{"LIS 检验系统", "业务库 · 小时级", "已连接", "2026-10-28 09:05"},
		{"HRP 人财物系统", "业务库 · 日终批", "已连接", "2026-10-28 06:30"},
		{"医保结算接口", "局端接口 · 日终批", "异常", "2026-10-27 23:58"},
	}
	for i, w := range wants {
		row := srcs[i].(map[string]any)
		if row["name"] != w.name || row["type"] != w.typ || row["status"] != w.status || row["sync"] != w.sync {
			t.Errorf("srcs[%d]=%v want %v", i, row, w)
		}
	}
}

// thresholds 7 行契约序:name 契约名映射 / rule 文案拼装 / level 英文原样 / enabled(EQUIP_RUN_LOW=false)
func TestStaffSettingsThresholds(t *testing.T) {
	ths, ok := settingsData(t, "/api/v1/workbench/settings/config")["thresholds"].([]any)
	if !ok || len(ths) != 7 {
		t.Fatalf("thresholds=%v", ths)
	}
	type want struct {
		name, rule, level string
		enabled           bool
	}
	wants := []want{
		{"床位使用率", "连续 3 日 > 95%", "urgent", true},
		{"药占比", "> 30%", "major", true},
		{"耗占比", "> 20%", "major", true},
		{"住院费用增幅", "同比 > 8%", "urgent", true},
		{"库存周转天数", "> 35 天", "minor", true},
		{"危急值超时率", "及时率 < 95%", "urgent", true},
		{"设备开机率", "< 60%", "minor", false},
	}
	for i, w := range wants {
		row := ths[i].(map[string]any)
		if row["name"] != w.name || row["rule"] != w.rule || row["level"] != w.level || row["enabled"] != w.enabled {
			t.Errorf("thresholds[%d]=%v want %v", i, row, w)
		}
	}
}

// users 7 行:role dict sort 序 + name=real_name + scope 映射 + status dict
func TestStaffSettingsUsers(t *testing.T) {
	us, ok := settingsData(t, "/api/v1/workbench/settings/config")["users"].([]any)
	if !ok || len(us) != 7 {
		t.Fatalf("users=%v", us)
	}
	// login 列随登录实时更新(P3 会话化,clk.Now 落库)——不再锚定种子值,只断言 §13.2 分钟格式
	loginFmt := regexp.MustCompile(`^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$`)
	type want struct{ name, role, scope, status string }
	wants := []want{
		{"系统管理员", "管理员", "全部", "启用"},
		{"王建国", "院领导", "全院", "启用"},
		{"陈国平", "院领导", "全院", "启用"},
		{"赵明诚", "部门负责人", "医疗业务", "启用"},
		{"孙雅琴", "部门负责人", "运营财务", "启用"},
		{"李明", "部门负责人", "运营质控", "启用"},
		{"刘志远", "科室主任", "骨科", "启用"},
	}
	for i, w := range wants {
		row := us[i].(map[string]any)
		if row["name"] != w.name || row["role"] != w.role || row["scope"] != w.scope ||
			row["status"] != w.status {
			t.Errorf("users[%d]=%v want %v", i, row, w)
		}
		if login, ok := row["login"].(string); !ok || !loginFmt.MatchString(login) {
			t.Errorf("users[%d].login=%v 不符 YYYY-MM-DD HH:mm", i, row["login"])
		}
	}
}

// 包络五字段齐(ts 正整数)+ 连发 trace_id 唯一 + preferences 恰五键(契约 §13.2 封闭键集)
func TestStaffSettingsTraceUnique(t *testing.T) {
	r := settingsRouter(t)
	var ids []string
	for i := 0; i < 2; i++ {
		w := httptest.NewRecorder()
		req := httptest.NewRequest(http.MethodGet, "/api/v1/workbench/settings/config", nil)
		r.ServeHTTP(w, req)
		var body map[string]any
		if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
			t.Fatalf("json: %v", err)
		}
		if ts, ok := body["ts"].(float64); !ok || ts <= 0 {
			t.Fatalf("ts=%v", body["ts"])
		}
		ids = append(ids, body["trace_id"].(string))
	}
	if ids[0] == "" || ids[0] == ids[1] {
		t.Fatalf("trace_id 非唯一: %v", ids)
	}
	p, ok := settingsData(t, "/api/v1/workbench/settings/config")["preferences"].(map[string]any)
	if !ok || len(p) != 5 {
		t.Fatalf("preferences 键集=%v", p)
	}
}

// preferences 五键:month→本月、300秒→5 分钟、三 bool 直出
func TestStaffSettingsPreferences(t *testing.T) {
	p, ok := settingsData(t, "/api/v1/workbench/settings/config")["preferences"].(map[string]any)
	if !ok {
		t.Fatal("preferences 缺失")
	}
	if p["default_range"] != "本月" {
		t.Errorf("default_range=%v", p["default_range"])
	}
	if p["refresh_interval"] != "5 分钟" {
		t.Errorf("refresh_interval=%v", p["refresh_interval"])
	}
	for _, k := range []string{"alert_sound", "unit_abbreviation", "privacy_mask"} {
		if v, ok := p[k].(bool); !ok || !v {
			t.Errorf("%s=%v 应为 bool true", k, p[k])
		}
	}
}
