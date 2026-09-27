package handler

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/middleware"
	"hospital-edss/internal/repo"
)

// qualityTestRouter 接真实库挂 Quality handler(集成测试;DB 缺席则 skip)
func qualityTestRouter(t *testing.T) *gin.Engine {
	t.Helper()
	db := testDB(t)
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(middleware.TraceID())
	h := NewStaffHandler(repo.NewStaffRepo(db, clock.New(db)))
	r.GET("/api/v1/workbench/quality", h.Quality)
	return r
}

func qualityGet(t *testing.T, r *gin.Engine, query string) (int, map[string]any) {
	t.Helper()
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/workbench/quality"+query, nil)
	r.ServeHTTP(w, req)
	var body map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("响应非 JSON: %v\n%s", err, w.Body.String())
	}
	return w.Code, body
}

// TestStaffQuality_EnvelopeShape 包络四要素+ts 齐备,未知参数按 REST 惯例忽略仍 200
func TestStaffQuality_EnvelopeShape(t *testing.T) {
	r := qualityTestRouter(t)
	code, body := qualityGet(t, r, "")
	if code != http.StatusOK || body["code"].(float64) != 0 {
		t.Fatalf("期望 200/code=0,实得 %d/%v", code, body["code"])
	}
	for _, k := range []string{"code", "message", "data", "trace_id", "ts"} {
		if _, ok := body[k]; !ok {
			t.Fatalf("包络缺键 %s: %v", k, body)
		}
	}
	if body["trace_id"] == "" {
		t.Fatal("trace_id 为空")
	}
	code2, body2 := qualityGet(t, r, "?foo=bar")
	if code2 != http.StatusOK || body2["code"].(float64) != 0 {
		t.Fatalf("未知参数应忽略仍 200,实得 %d/%v", code2, body2["code"])
	}
	if body2["trace_id"] == body["trace_id"] {
		t.Fatal("连发两请求 trace_id 相同")
	}
}

// TestStaffQuality_ContractValues 对照 §10.1 库实算锚点(mock 仅形态参照)
func TestStaffQuality_ContractValues(t *testing.T) {
	r := qualityTestRouter(t)
	_, body := qualityGet(t, r, "")
	data := body["data"].(map[string]any)

	stats := data["stats"].([]any)
	want := []struct {
		label, value, unit string
	}{
		{"甲级病案率", "98.6", "%"},
		{"院感发生率", "1.25", "%"},
		{"危急值处理及时率", "99.1", "%"},
		{"不良事件上报", "36", "起"},
		{"I类切口感染率", "0.35", "%"},
		{"抗菌药物使用强度", "36.2", "DDDs"},
	}
	if len(stats) != len(want) {
		t.Fatalf("stats 期望 %d 项,实得 %d", len(want), len(stats))
	}
	for i, w := range want {
		it := stats[i].(map[string]any)
		if it["label"] != w.label || it["value"] != w.value || it["unit"] != w.unit {
			t.Fatalf("stats[%d] 期望 %s=%s%s,实得 %v", i, w.label, w.value, w.unit, it)
		}
	}
	if stats[3].(map[string]any)["note"] != "百床 2.00 起" {
		t.Fatalf("不良事件 note 不符: %v", stats[3])
	}
	if stats[5].(map[string]any)["delta"] != "-0.4" {
		t.Fatalf("ABX_DDD delta 期望 -0.4,实得 %v", stats[5])
	}
	for i, it := range stats {
		m := it.(map[string]any)
		if d, ok := m["delta"]; ok && d != "" && m["delta_label"] != "较上月" {
			t.Fatalf("stats[%d] 带 delta 但 delta_label≠较上月: %v", i, m)
		}
	}

	trend := data["infection_trend"].(map[string]any)
	if trend["unit"] != "%" || trend["target"].(float64) != 2.0 {
		t.Fatalf("trend unit/target 不符: %v", trend)
	}
	months := trend["months"].([]any)
	if len(months) != 6 || months[0] != "5月" || months[5] != "10月" {
		t.Fatalf("trend months 不符: %v", months)
	}
	rates := trend["rates"].([]any)
	wantRates := []float64{2.19, 2.0, 2.1, 1.9, 1.9, 1.25}
	for i, v := range rates {
		if v.(float64) != wantRates[i] {
			t.Fatalf("rates[%d] 期望 %v,实得 %v", i, wantRates[i], v)
		}
	}

	adverse := data["adverse_events"].(map[string]any)
	cats := adverse["categories"].([]any)
	if len(cats) != 7 || cats[0] != "跌倒/坠床" || cats[3] != "院内压疮" {
		t.Fatalf("adverse categories 不符: %v", cats)
	}
	vals := adverse["values"].([]any)
	wantVals := []float64{10, 8, 6, 5, 3, 2, 2}
	var sum float64
	for i, v := range vals {
		if v.(float64) != wantVals[i] {
			t.Fatalf("adverse values[%d] 期望 %v,实得 %v", i, wantVals[i], v)
		}
		sum += v.(float64)
	}
	if sum != 36 {
		t.Fatalf("adverse Σ 期望 36 与 stats 自洽,实得 %v", sum)
	}
}

// TestStaffQuality_RulesRateSelfConsistent rules_compliance 8 行:码序固定,rate=pass/sample 现算自洽
func TestStaffQuality_RulesRateSelfConsistent(t *testing.T) {
	r := qualityTestRouter(t)
	_, body := qualityGet(t, r, "")
	rules := body["data"].(map[string]any)["rules_compliance"].(map[string]any)
	cols := rules["columns"].([]any)
	if len(cols) != 5 || cols[0].(map[string]any)["key"] != "name" {
		t.Fatalf("rules columns 不符: %v", cols)
	}
	rows := rules["rows"].([]any)
	if len(rows) != 8 {
		t.Fatalf("rules 期望 8 行,实得 %d", len(rows))
	}
	wantNames := []string{"首诊负责制", "三级查房制度", "会诊制度", "危急值报告制度", "手术安全核查制度", "病历书写规范", "抗菌药物分级管理", "值班交接班制度"}
	for i, wn := range wantNames {
		row := rows[i].(map[string]any)
		if row["name"] != wn {
			t.Fatalf("rules[%d] 期望 %s,实得 %v", i, wn, row["name"])
		}
		sample, pass := row["sample"].(float64), row["pass"].(float64)
		wantRate := fmt.Sprintf("%.1f%%", pass*100/sample)
		if row["rate"] != wantRate {
			t.Fatalf("rules[%d] rate 期望现算 %s,实得 %v", i, wantRate, row["rate"])
		}
		if _, ok := row["issues"]; !ok {
			t.Fatalf("rules[%d] 缺 issues 键", i)
		}
	}
}
