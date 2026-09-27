package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
)

func aggTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	return testDB(t)
}

func aggTestRouter(t *testing.T) *gin.Engine {
	db := aggTestDB(t)
	h := NewHome(db, clock.New(db))
	r := gin.New()
	r.GET("/api/v1/workbench/home/kpis", h.Kpis)
	r.GET("/api/v1/workbench/home/trends", h.Trends)
	r.GET("/api/v1/workbench/home/indicators", h.Indicators)
	return r
}

func aggGetData(t *testing.T, r *gin.Engine, path string) json.RawMessage {
	t.Helper()
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, path, nil)
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("%s http %d: %s", path, w.Code, w.Body.String())
	}
	var env struct {
		Code    int             `json:"code"`
		Data    json.RawMessage `json:"data"`
		TraceID string          `json:"trace_id"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &env); err != nil {
		t.Fatalf("%s 包络解析: %v", path, err)
	}
	if env.Code != 0 {
		t.Fatalf("%s code=%d, want 0", path, env.Code)
	}
	return env.Data
}

func TestHomeKpis(t *testing.T) {
	r := aggTestRouter(t)
	data := aggGetData(t, r, "/api/v1/workbench/home/kpis")

	var resp struct {
		Period string `json:"period"`
		List   []struct {
			Key   string `json:"key"`
			Label string `json:"label"`
			Value string `json:"value"`
			Unit  string `json:"unit"`
			Delta string `json:"delta"`
			Dir   string `json:"dir"`
		} `json:"list"`
	}
	if err := json.Unmarshal(data, &resp); err != nil {
		t.Fatalf("data 解析: %v", err)
	}
	if resp.Period != "本月" {
		t.Fatalf("period=%q, want 本月", resp.Period)
	}
	wantKeys := []string{"outpatient", "inpatient", "surgery", "revenue", "staff"}
	if len(resp.List) != len(wantKeys) {
		t.Fatalf("list len=%d, want %d", len(resp.List), len(wantKeys))
	}
	for i, k := range wantKeys {
		if resp.List[i].Key != k {
			t.Fatalf("list[%d].key=%q, want %q", i, resp.List[i].Key, k)
		}
		switch resp.List[i].Dir {
		case "up", "down", "flat":
		default:
			t.Fatalf("list[%d].dir=%q 非法", i, resp.List[i].Dir)
		}
	}
	// 锚点:2026-10 全月 Σrevenue/10000=14800.0 → 千分位 "14,800"
	if got := resp.List[3].Value; got != "14,800" {
		t.Fatalf("revenue value=%q, want %q", got, "14,800")
	}
}

func TestHomeTrends(t *testing.T) {
	r := aggTestRouter(t)
	data := aggGetData(t, r, "/api/v1/workbench/home/trends")

	var resp struct {
		Months []string `json:"months"`
		Series map[string]struct {
			Unit    string    `json:"unit"`
			Current []float64 `json:"current"`
			Last    []float64 `json:"last"`
		} `json:"series"`
	}
	if err := json.Unmarshal(data, &resp); err != nil {
		t.Fatalf("data 解析: %v", err)
	}
	if len(resp.Months) != 12 {
		t.Fatalf("months len=%d, want 12", len(resp.Months))
	}
	for _, name := range []string{"门急诊人次", "住院人次", "手术台次", "医疗收入"} {
		s, ok := resp.Series[name]
		if !ok {
			t.Fatalf("series 缺键 %q", name)
		}
		if len(s.Current) != 12 || len(s.Last) != 12 {
			t.Fatalf("series[%q] current/last len=%d/%d, want 12/12", name, len(s.Current), len(s.Last))
		}
	}
	// 锚点:kpis 当月门急诊 123443 须与 trends 10 月点自洽(契约 §3.1 字段注)
	if got := resp.Series["门急诊人次"].Current[9]; got != 123443 {
		t.Fatalf("门急诊人次 current[10月]=%v, want 123443", got)
	}
}

func TestHomeIndicators(t *testing.T) {
	r := aggTestRouter(t)
	data := aggGetData(t, r, "/api/v1/workbench/home/indicators")

	var resp struct {
		List []struct {
			Code  string `json:"code"`
			Value string `json:"value"`
			Unit  string `json:"unit"`
			Dir   string `json:"dir"`
		} `json:"list"`
	}
	if err := json.Unmarshal(data, &resp); err != nil {
		t.Fatalf("data 解析: %v", err)
	}
	wantCodes := []string{"ALOS", "BED_USE_RATE", "DRUG_RATIO", "MATERIAL_RATIO", "MED_SVC_RATIO"}
	if len(resp.List) != len(wantCodes) {
		t.Fatalf("list len=%d, want %d", len(resp.List), len(wantCodes))
	}
	for i, code := range wantCodes {
		if resp.List[i].Code != code {
			t.Fatalf("list[%d].code=%q, want %q", i, resp.List[i].Code, code)
		}
		switch resp.List[i].Dir {
		case "up", "down", "flat":
		default:
			t.Fatalf("list[%d].dir=%q 非法", i, resp.List[i].Dir)
		}
	}
	// 锚点:2026-10 ALOS=6.8 天
	if got := resp.List[0].Value; got != "6.8" {
		t.Fatalf("ALOS value=%q, want %q", got, "6.8")
	}
}
