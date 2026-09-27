package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/gin-gonic/gin"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
)

// 实库断言锚点:种子 1001_sys_defs.sql + 1150_sys_deferred.sql(dept_leader→骨科 id=1)
// + sim.clock BASE_DATE=2026-10-28 周三;不可达时 Skip(验收环境库必在)

type envelopeBody struct {
	Code    int             `json:"code"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data"`
	TraceID string          `json:"trace_id"`
	Ts      int64           `json:"ts"`
}

func testDB(t *testing.T) *gorm.DB {
	t.Helper()
	dsn := envOr("DATABASE_URL", "postgres://localhost/hospital_edss?sslmode=disable")
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatalf("gorm.Open: %v", err)
	}
	sqlDB, err := db.DB()
	if err != nil {
		t.Fatalf("db.DB: %v", err)
	}
	if err := sqlDB.Ping(); err != nil {
		t.Skipf("postgres 不可达(%s): %v", dsn, err)
	}
	return db
}

// 手工注册路由——internal/router 依赖 handler,反向 import 会成环;trace_id 由测试中间件模拟注入
func contextRouter(t *testing.T) *gin.Engine {
	t.Helper()
	db := testDB(t)
	h := NewContext(db, clock.New(db))
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(func(c *gin.Context) { c.Set("trace_id", "test-trace"); c.Next() })
	r.GET("/api/v1/auth/profile", h.AuthProfile)
	r.GET("/api/v1/hospital/profile", h.HospitalProfile)
	return r
}

func get(t *testing.T, r *gin.Engine, path string) (int, envelopeBody) {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, path, nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var body envelopeBody
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("包络反序列化: %v body=%s", err, w.Body.String())
	}
	return w.Code, body
}

func assertOK(t *testing.T, status int, b envelopeBody) {
	t.Helper()
	if status != http.StatusOK {
		t.Fatalf("HTTP status=%d want 200", status)
	}
	if b.Code != 0 || b.Message != "ok" {
		t.Fatalf("包络 code=%v message=%q want 0/ok", b.Code, b.Message)
	}
	if b.TraceID != "test-trace" {
		t.Fatalf("trace_id=%q want test-trace", b.TraceID)
	}
	if b.Ts <= 0 {
		t.Fatalf("ts=%d want >0", b.Ts)
	}
}

type authData struct {
	User struct {
		ID       int64  `json:"id"`
		Username string `json:"username"`
		RealName string `json:"real_name"`
		Title    string `json:"title"`
		DeptID   *int64 `json:"dept_id"`
		DeptName string `json:"dept_name"`
		Role     string `json:"role"`
	} `json:"user"`
	AvailableRoles []struct {
		Role  string `json:"role"`
		Name  string `json:"name"`
		Scope string `json:"scope"`
	} `json:"available_roles"`
	SystemDate string `json:"system_date"`
	Weekday    string `json:"weekday"`
}

func decodeAuth(t *testing.T, b envelopeBody) authData {
	t.Helper()
	var d authData
	if err := json.Unmarshal(b.Data, &d); err != nil {
		t.Fatalf("data 反序列化: %v", err)
	}
	return d
}

func assertDemoRoles(t *testing.T, d authData) {
	t.Helper()
	want := []struct{ role, name, scope string }{
		{"president", "院长 (王建国)", "全院"},
		{"ops_director", "运营办主任 (李明)", "全院运营/质控"},
		{"dept_leader", "骨科主任 (刘志远)", "本科室"},
	}
	if len(d.AvailableRoles) != len(want) {
		t.Fatalf("available_roles len=%d want %d", len(d.AvailableRoles), len(want))
	}
	for i, w := range want {
		got := d.AvailableRoles[i]
		if got.Role != w.role || got.Name != w.name || got.Scope != w.scope {
			t.Fatalf("available_roles[%d]=%+v want %+v", i, got, w)
		}
	}
}

func TestAuthProfileDefault(t *testing.T) {
	r := contextRouter(t)
	status, b := get(t, r, "/api/v1/auth/profile")
	assertOK(t, status, b)

	d := decodeAuth(t, b)
	if d.User.Username != "president" || d.User.RealName != "王建国" || d.User.Title != "院长" {
		t.Fatalf("user=%+v want president/王建国/院长", d.User)
	}
	if d.User.DeptID != nil {
		t.Fatalf("president dept_id=%v want null(院级哨兵)", *d.User.DeptID)
	}
	if d.User.DeptName != "全院" {
		t.Fatalf("dept_name=%q want 全院", d.User.DeptName)
	}
	if d.SystemDate != "2026-10-28" || d.Weekday != "星期三" {
		t.Fatalf("system_date=%q weekday=%q want 2026-10-28/星期三", d.SystemDate, d.Weekday)
	}
	assertDemoRoles(t, d)
}

func TestAuthProfileOpsDirector(t *testing.T) {
	r := contextRouter(t)
	status, b := get(t, r, "/api/v1/auth/profile?role=ops_director")
	assertOK(t, status, b)

	d := decodeAuth(t, b)
	if d.User.Username != "ops_director" || d.User.DeptID != nil || d.User.DeptName != "全院" {
		t.Fatalf("user=%+v want ops_director/dept_id null/dept_name 全院", d.User)
	}
}

func TestAuthProfileDeptLeader(t *testing.T) {
	r := contextRouter(t)
	status, b := get(t, r, "/api/v1/auth/profile?role=dept_leader")
	assertOK(t, status, b)

	d := decodeAuth(t, b)
	if d.User.Username != "dept_leader" || d.User.DeptName != "骨科" {
		t.Fatalf("user=%+v want dept_leader/骨科", d.User)
	}
	if d.User.DeptID == nil || *d.User.DeptID != 1 {
		t.Fatalf("dept_leader dept_id=%v want 1", d.User.DeptID)
	}
}

func TestAuthProfileEmptyRoleDefaultsPresident(t *testing.T) {
	r := contextRouter(t)
	status, b := get(t, r, "/api/v1/auth/profile?role=")
	assertOK(t, status, b)
	if d := decodeAuth(t, b); d.User.Username != "president" {
		t.Fatalf("username=%q want president", d.User.Username)
	}
}

func TestAuthProfileBadRole(t *testing.T) {
	r := contextRouter(t)
	status, b := get(t, r, "/api/v1/auth/profile?role=bad")
	if status != http.StatusBadRequest {
		t.Fatalf("HTTP status=%d want 400", status)
	}
	if b.Code != 10001 {
		t.Fatalf("code=%d want 10001", b.Code)
	}
	var data struct {
		Fields map[string]string `json:"fields"`
	}
	if err := json.Unmarshal(b.Data, &data); err != nil {
		t.Fatalf("data 反序列化: %v", err)
	}
	if _, ok := data.Fields["role"]; !ok {
		t.Fatalf("data.fields 缺 role 键: %s", string(b.Data))
	}
}

func TestHospitalProfile(t *testing.T) {
	r := contextRouter(t)
	status, b := get(t, r, "/api/v1/hospital/profile")
	assertOK(t, status, b)

	var d struct {
		Name        string   `json:"name"`
		EnglishName string   `json:"english_name"`
		Level       string   `json:"level"`
		Motto       []string `json:"motto"`
		Slogans     []string `json:"slogans"`
		Pillars     []string `json:"pillars"`
	}
	if err := json.Unmarshal(b.Data, &d); err != nil {
		t.Fatalf("data 反序列化: %v", err)
	}
	if d.Name != "XX市人民医院" || d.EnglishName != "PEOPLE'S HOSPITAL" || d.Level != "三级甲等综合医院" {
		t.Fatalf("标量字段不符: %+v", d)
	}
	if len(d.Motto) == 0 || len(d.Slogans) == 0 || len(d.Pillars) == 0 {
		t.Fatalf("数组字段应非空: motto=%v slogans=%v pillars=%v", d.Motto, d.Slogans, d.Pillars)
	}
	if d.Motto[0] != "厚德" || d.Pillars[0] != "人民至上" {
		t.Fatalf("数组首元素不符: motto[0]=%q pillars[0]=%q", d.Motto[0], d.Pillars[0])
	}
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
