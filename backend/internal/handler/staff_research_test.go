// Package handler_test §8.1 research 端点 handler 级测试——直连演示库
// (种子锚定 sim.clock=2026-10-28;期望值见 e3-design §8.1 实测段)。
package handler_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/handler"
	"hospital-edss/internal/middleware"
	"hospital-edss/internal/repo"
)

func researchRouter(t *testing.T) *gin.Engine {
	t.Helper()
	db := snapDB(t)
	h := handler.NewStaffHandler(repo.NewStaffRepo(db, clock.New(db)))
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(middleware.TraceID())
	r.GET("/api/v1/workbench/research", h.Research)
	return r
}

func getJSON(t *testing.T, r *gin.Engine, path string) (int, map[string]any) {
	t.Helper()
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, path, nil)
	r.ServeHTTP(w, req)
	var body map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("json: %v body=%s", err, w.Body.String())
	}
	return w.Code, body
}

func dataOf(t *testing.T, body map[string]any) map[string]any {
	t.Helper()
	d, ok := body["data"].(map[string]any)
	if !ok || d == nil {
		t.Fatalf("data 缺失或类型错误: %v", body["data"])
	}
	return d
}

// 包络形态:{code:0,message:"ok",data,trace_id,ts}(error-codes §1)
func TestStaffResearchEnvelope(t *testing.T) {
	code, body := getJSON(t, researchRouter(t), "/api/v1/workbench/research")
	if code != http.StatusOK {
		t.Fatalf("status=%d body=%v", code, body)
	}
	if body["code"] != float64(0) {
		t.Fatalf("code=%v", body["code"])
	}
	if body["message"] != "ok" {
		t.Fatalf("message=%v", body["message"])
	}
	dataOf(t, body)
	if s, ok := body["trace_id"].(string); !ok || len(s) != 12 {
		t.Fatalf("trace_id=%v", body["trace_id"])
	}
	if _, ok := body["ts"].(float64); !ok {
		t.Fatal("ts 缺失")
	}
}

// §8.1 无声明参数:未知/非法查询参数忽略,照常 200(e3-design 边界纪律)
func TestStaffResearchUndeclaredParams(t *testing.T) {
	code, body := getJSON(t, researchRouter(t), "/api/v1/workbench/research?foo=bar&range=%E6%9C%AC%E5%B9%B4")
	if code != http.StatusOK || body["code"] != float64(0) {
		t.Fatalf("status=%d body=%v", code, body)
	}
}

// stats 六枚锚点 + 年指标 delta 口径(较去年;PROJ_CNT/TRAINEE 省略 delta)
func TestStaffResearchStats(t *testing.T) {
	code, body := getJSON(t, researchRouter(t), "/api/v1/workbench/research")
	if code != http.StatusOK {
		t.Fatalf("status=%d", code)
	}
	stats, ok := dataOf(t, body)["stats"].([]any)
	if !ok || len(stats) != 6 {
		t.Fatalf("stats=%v", dataOf(t, body)["stats"])
	}
	type want struct {
		label, value, unit, delta, dlbl, dir, note string
	}
	wants := []want{
		{"在研课题", "186", "项", "", "", "", ""},
		{"年度新立项", "42", "项", "+6项", "较去年", "up", ""},
		{"科研经费", "3,480", "万元", "+18.4%", "较去年", "up", ""},
		{"SCI 论文", "98", "篇", "+7篇", "较去年", "up", ""},
		{"住培学员", "312", "人", "", "", "", "首次结业率 96.2%"},
		{"继教覆盖率", "98.4", "%", "+1.7%", "较去年", "up", ""},
	}
	for i, w := range wants {
		it, ok := stats[i].(map[string]any)
		if !ok {
			t.Fatalf("stats[%d] 类型错误", i)
		}
		if it["label"] != w.label || it["value"] != w.value {
			t.Errorf("stats[%d]=%v,%v want %v,%v", i, it["label"], it["value"], w.label, w.value)
		}
		if it["unit"] != w.unit {
			t.Errorf("stats[%d] unit=%v want %v", i, it["unit"], w.unit)
		}
		if w.delta == "" {
			if _, has := it["delta"]; has {
				t.Errorf("stats[%d] %s 应省略 delta,实发 %v", i, w.label, it["delta"])
			}
		} else if it["delta"] != w.delta || it["delta_label"] != w.dlbl || it["dir"] != w.dir {
			t.Errorf("stats[%d] delta=%v/%v/%v want %v/%v/%v", i,
				it["delta"], it["delta_label"], it["dir"], w.delta, w.dlbl, w.dir)
		}
		if w.note != "" && it["note"] != w.note {
			t.Errorf("stats[%d] note=%v want %v", i, it["note"], w.note)
		}
	}
}

// project_trend 近5自然年轴(2022~2026)与三序列锚点
func TestStaffResearchTrend(t *testing.T) {
	code, body := getJSON(t, researchRouter(t), "/api/v1/workbench/research")
	if code != http.StatusOK {
		t.Fatalf("status=%d", code)
	}
	pt, ok := dataOf(t, body)["project_trend"].(map[string]any)
	if !ok {
		t.Fatal("project_trend 缺失")
	}
	if pt["unit"] != "万元" {
		t.Fatalf("unit=%v", pt["unit"])
	}
	nums := func(key string, want []float64) {
		t.Helper()
		arr, ok := pt[key].([]any)
		if !ok || len(arr) != len(want) {
			t.Fatalf("%s=%v", key, pt[key])
		}
		for i, w := range want {
			if arr[i] != w {
				t.Errorf("%s[%d]=%v want %v", key, i, arr[i], w)
			}
		}
	}
	years, ok := pt["years"].([]any)
	if !ok || len(years) != 5 {
		t.Fatalf("years=%v", pt["years"])
	}
	wantYears := []string{"2022", "2023", "2024", "2025", "2026"}
	for i, y := range wantYears {
		if years[i] != y {
			t.Fatalf("years[%d]=%v want %v(近5年轴)", i, years[i], y)
		}
	}
	nums("national", []float64{4, 6, 8, 9, 12})
	nums("provincial", []float64{12, 16, 20, 24, 30})
	nums("funds", []float64{1200, 1680, 2240, 2940, 3480})
}

// paper_distribution 固定类目 + 当年分区锚点
func TestStaffResearchPaperDistribution(t *testing.T) {
	code, body := getJSON(t, researchRouter(t), "/api/v1/workbench/research")
	if code != http.StatusOK {
		t.Fatalf("status=%d", code)
	}
	pd, ok := dataOf(t, body)["paper_distribution"].(map[string]any)
	if !ok {
		t.Fatal("paper_distribution 缺失")
	}
	if pd["unit"] != "篇" {
		t.Fatalf("unit=%v", pd["unit"])
	}
	wantCats := []string{"一区（Top）", "二区", "三区", "四区", "中文核心"}
	cats, ok := pd["categories"].([]any)
	if !ok || len(cats) != len(wantCats) {
		t.Fatalf("categories=%v", pd["categories"])
	}
	for i, c := range wantCats {
		if cats[i] != c {
			t.Fatalf("categories[%d]=%v want %v", i, cats[i], c)
		}
	}
	wantVals := []float64{14, 28, 36, 20, 68}
	vals, ok := pd["values"].([]any)
	if !ok || len(vals) != len(wantVals) {
		t.Fatalf("values=%v", pd["values"])
	}
	for i, v := range wantVals {
		if vals[i] != v {
			t.Errorf("values[%d]=%v want %v", i, vals[i], v)
		}
	}
}

// disciplines 三行契约形状:projects/papers 为 number,funds/transfer 为 string
func TestStaffResearchDisciplines(t *testing.T) {
	code, body := getJSON(t, researchRouter(t), "/api/v1/workbench/research")
	if code != http.StatusOK {
		t.Fatalf("status=%d", code)
	}
	disc, ok := dataOf(t, body)["disciplines"].(map[string]any)
	if !ok {
		t.Fatal("disciplines 缺失")
	}
	if _, ok := disc["columns"].([]any); !ok {
		t.Fatal("columns 缺失")
	}
	rows, ok := disc["rows"].([]any)
	if !ok || len(rows) != 3 {
		t.Fatalf("rows=%v", disc["rows"])
	}
	wantNames := []string{"心血管病学", "骨外科学", "呼吸病学"}
	wantLevels := []string{"国家临床重点", "省级重点专科", "省级重点专科"}
	for i, rw := range rows {
		row, ok := rw.(map[string]any)
		if !ok {
			t.Fatalf("rows[%d] 类型错误", i)
		}
		if row["name"] != wantNames[i] || row["level"] != wantLevels[i] {
			t.Errorf("rows[%d]=%v/%v want %v/%v", i, row["name"], row["level"], wantNames[i], wantLevels[i])
		}
		if _, ok := row["leader"].(string); !ok {
			t.Errorf("rows[%d] leader 非 string: %T", i, row["leader"])
		}
		// 契约类型钉死:projects/papers=int(JSON number),funds/transfer=string 万元
		if _, ok := row["projects"].(float64); !ok {
			t.Errorf("rows[%d] projects 非 number: %T", i, row["projects"])
		}
		if _, ok := row["papers"].(float64); !ok {
			t.Errorf("rows[%d] papers 非 number: %T", i, row["papers"])
		}
		if _, ok := row["funds"].(string); !ok {
			t.Errorf("rows[%d] funds 非 string: %T", i, row["funds"])
		}
		if _, ok := row["transfer"].(string); !ok {
			t.Errorf("rows[%d] transfer 非 string: %T", i, row["transfer"])
		}
	}
	first := rows[0].(map[string]any)
	if first["projects"] != float64(28) || first["funds"] != "820" ||
		first["papers"] != float64(22) || first["transfer"] != "150" {
		t.Errorf("心血管病学行=%v want 28/\"820\"/22/\"150\"", first)
	}
}
