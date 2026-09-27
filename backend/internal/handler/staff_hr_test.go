package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/middleware"
	"hospital-edss/internal/repo"
)

// hrTestRouter 接真实库挂 Hr handler(集成测试;DB 缺席则 skip)
func hrTestRouter(t *testing.T) *gin.Engine {
	t.Helper()
	db := testDB(t)
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(middleware.TraceID())
	h := NewStaffHandler(repo.NewStaffRepo(db, clock.New(db)))
	r.GET("/api/v1/workbench/hr", h.Hr)
	return r
}

func hrGet(t *testing.T, r *gin.Engine, query string) (int, map[string]any) {
	t.Helper()
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/workbench/hr"+query, nil)
	r.ServeHTTP(w, req)
	var body map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("响应非 JSON: %v\n%s", err, w.Body.String())
	}
	return w.Code, body
}

// TestStaffHr_SnapshotRangeIdentical range 三合法值返回同一时点快照(§7.1 恒等语义)
func TestStaffHr_SnapshotRangeIdentical(t *testing.T) {
	r := hrTestRouter(t)
	var snap string
	for _, rg := range []string{"本月", "本季", "本年"} {
		code, body := hrGet(t, r, "?range="+rg)
		if code != http.StatusOK || body["code"].(float64) != 0 {
			t.Fatalf("range=%s 期望 200/code=0,实得 %d/%v", rg, code, body["code"])
		}
		data, _ := json.Marshal(body["data"])
		if snap == "" {
			snap = string(data)
		} else if string(data) != snap {
			t.Fatalf("range=%s 快照与首值不一致", rg)
		}
	}
	// 缺席 range 默认本月,亦同快照
	code, body := hrGet(t, r, "")
	if code != http.StatusOK {
		t.Fatalf("无 range 期望 200,实得 %d", code)
	}
	if data, _ := json.Marshal(body["data"]); string(data) != snap {
		t.Fatal("无 range 快照与本月不一致")
	}
}

// TestStaffHr_InvalidRange 非法 range → HTTP400 + code 10001 + data.fields.range
func TestStaffHr_InvalidRange(t *testing.T) {
	r := hrTestRouter(t)
	code, body := hrGet(t, r, "?range=烂值")
	if code != http.StatusBadRequest {
		t.Fatalf("期望 400,实得 %d", code)
	}
	if body["code"].(float64) != 10001 {
		t.Fatalf("期望 code=10001,实得 %v", body["code"])
	}
	data, ok := body["data"].(map[string]any)
	if !ok {
		t.Fatalf("期望 data.fields,实得 %v", body["data"])
	}
	fields, _ := data["fields"].(map[string]any)
	if _, ok := fields["range"]; !ok {
		t.Fatalf("期望 fields.range 键,实得 %v", data)
	}
}

// TestStaffHr_EnvelopeShape 包络四要素+ ts(code/message/data/trace_id/ts 齐备)
func TestStaffHr_EnvelopeShape(t *testing.T) {
	r := hrTestRouter(t)
	_, body := hrGet(t, r, "?range=本月")
	for _, k := range []string{"code", "message", "data", "trace_id", "ts"} {
		if _, ok := body[k]; !ok {
			t.Fatalf("包络缺键 %s: %v", k, body)
		}
	}
	if body["trace_id"] == "" {
		t.Fatal("trace_id 为空")
	}
}

// TestStaffHr_ContractValues 对照契约 §7.1 锚点值(mock 形态,数值以库为准)
func TestStaffHr_ContractValues(t *testing.T) {
	r := hrTestRouter(t)
	_, body := hrGet(t, r, "?range=本月")
	data := body["data"].(map[string]any)

	stats := data["stats"].([]any)
	want := []struct {
		label, value string
	}{
		{"在岗职工", "2,368"}, {"执业医师", "812"}, {"注册护士", "1,046"},
		{"医护比", "1 : 1.29"}, {"高级职称占比", "12.0"}, {"人员经费占比", "32.5"},
	}
	if len(stats) != len(want) {
		t.Fatalf("stats 期望 %d 项,实得 %d", len(want), len(stats))
	}
	for i, w := range want {
		it := stats[i].(map[string]any)
		if it["label"] != w.label || it["value"] != w.value {
			t.Fatalf("stats[%d] 期望 %s=%s,实得 %v=%v", i, w.label, w.value, it["label"], it["value"])
		}
	}
	if stats[3].(map[string]any)["note"] != "目标 ≥1:1.25" {
		t.Fatalf("医护比 note 不符: %v", stats[3])
	}

	structure := data["structure"].(map[string]any)
	list := structure["list"].([]any)
	if len(list) != 4 {
		t.Fatalf("structure 期望 4 行,实得 %d", len(list))
	}
	first := list[0].(map[string]any)
	if first["name"] != "护理人员" || first["count"].(float64) != 1046 {
		t.Fatalf("structure 首行期望 护理人员/1046,实得 %v", first)
	}

	titles := data["titles"].(map[string]any)
	cats := titles["categories"].([]any)
	if len(cats) != 4 || cats[0] != "医师" || cats[3] != "行政后勤" {
		t.Fatalf("titles.categories 不符: %v", cats)
	}
	series := titles["series"].([]any)
	if len(series) != 4 {
		t.Fatalf("titles.series 期望 4 行,实得 %d", len(series))
	}
	senior := series[0].(map[string]any)
	if senior["name"] != "正高" {
		t.Fatalf("series[0] 期望 正高,实得 %v", senior["name"])
	}
	vals := senior["values"].([]any)
	wantVals := []float64{42, 6, 4, 0}
	for i, v := range vals {
		if v.(float64) != wantVals[i] {
			t.Fatalf("正高 values[%d] 期望 %v,实得 %v", i, wantVals[i], v)
		}
	}

	staffing := data["dept_staffing"].(map[string]any)
	rows := staffing["rows"].([]any)
	if len(rows) != 8 {
		t.Fatalf("dept_staffing 期望 8 行,实得 %d", len(rows))
	}
	// 白名单全序钉死(open-items L8-#3 裁 a):ZZYXK,JZK,EK,XNK,GK,HXWZK,MZK,KFK
	wantOrder := []string{"重症医学科", "急诊科", "儿科", "心血管内科", "骨科", "呼吸与危重症医学科", "麻醉科", "康复医学科"}
	for i, w := range wantOrder {
		if d := rows[i].(map[string]any)["dept"]; d != w {
			t.Fatalf("dept_staffing 行序[%d] 期望 %s,实得 %v", i, w, d)
		}
	}
	icu := rows[0].(map[string]any)
	if icu["dept"] != "重症医学科" || icu["ratio"] != "1:2.63" || icu["status"] != "紧缺" {
		t.Fatalf("dept_staffing 首行不符: %v", icu)
	}
	mzk := rows[6].(map[string]any)
	if mzk["dept"] != "麻醉科" || mzk["ratio"] != "—" || mzk["status"] != "紧张" {
		t.Fatalf("麻醉科行 ratio 应为 —,实得 %v", mzk)
	}
}
