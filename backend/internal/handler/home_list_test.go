// 首页列表域端点 httptest:gin.New() 手工注册 4 路由,实库只读(任务书 e1-task-C)
package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"regexp"
	"testing"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/clock"
)

func newHomeTestRouter(t *testing.T) *gin.Engine {
	t.Helper()
	db := testDB(t)
	h := NewHome(db, clock.New(db))
	r := gin.New()
	r.GET("/api/v1/workbench/home/top10", h.Top10)
	r.GET("/api/v1/workbench/home/progress", h.Progress)
	r.GET("/api/v1/workbench/home/alerts", h.Alerts)
	r.GET("/api/v1/workbench/home/notices", h.Notices)
	return r
}

type envBody struct {
	Code    int             `json:"code"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data"`
	TraceID string          `json:"trace_id"`
}

func getData(t *testing.T, r *gin.Engine, path string) json.RawMessage {
	t.Helper()
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, path, nil)
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("GET %s: http %d, body %s", path, w.Code, w.Body.String())
	}
	var env envBody
	if err := json.Unmarshal(w.Body.Bytes(), &env); err != nil {
		t.Fatalf("GET %s: decode envelope: %v", path, err)
	}
	if env.Code != 0 || env.Message != "ok" {
		t.Fatalf("GET %s: envelope code=%d message=%q", path, env.Code, env.Message)
	}
	if len(env.Data) == 0 || string(env.Data) == "null" {
		t.Fatalf("GET %s: data is null", path)
	}
	return env.Data
}

func TestHomeTop10(t *testing.T) {
	data := getData(t, newHomeTestRouter(t), "/api/v1/workbench/home/top10")
	var resp struct {
		MetricName string `json:"metric_name"`
		MaxVal     int64  `json:"max_val"`
		List       []struct {
			Rank  int    `json:"rank"`
			Name  string `json:"name"`
			Value int64  `json:"value"`
		} `json:"list"`
	}
	if err := json.Unmarshal(data, &resp); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if resp.MetricName != "住院人次" {
		t.Fatalf("metric_name=%q", resp.MetricName)
	}
	if len(resp.List) > 10 {
		t.Fatalf("list len=%d > 10", len(resp.List))
	}
	if resp.List == nil {
		t.Fatal("list serialized as null")
	}
	for i, it := range resp.List {
		if it.Rank != i+1 {
			t.Fatalf("rank[%d]=%d, want %d", i, it.Rank, i+1)
		}
		if i > 0 && it.Value > resp.List[i-1].Value {
			t.Fatalf("list not desc: [%d]=%d > [%d]=%d", i, it.Value, i-1, resp.List[i-1].Value)
		}
	}
	if len(resp.List) > 0 && resp.MaxVal < resp.List[0].Value {
		t.Fatalf("max_val=%d < top1=%d", resp.MaxVal, resp.List[0].Value)
	}
	// 锚点 BASE_DATE=2026-10:rank10=泌尿外科(level=2 科室口径,不含医疗组)
	if len(resp.List) != 10 {
		t.Fatalf("list len=%d, want 10", len(resp.List))
	}
	if got := resp.List[9].Name; got != "泌尿外科" {
		t.Fatalf("rank10=%q, want 泌尿外科", got)
	}
}

func TestHomeProgress(t *testing.T) {
	data := getData(t, newHomeTestRouter(t), "/api/v1/workbench/home/progress")
	var resp struct {
		List []struct {
			ID       int64  `json:"id"`
			Name     string `json:"name"`
			Progress int    `json:"progress"`
			Status   string `json:"status"`
		} `json:"list"`
	}
	if err := json.Unmarshal(data, &resp); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if resp.List == nil {
		t.Fatal("list serialized as null")
	}
	valid := map[string]bool{"进行中": true, "待启动": true, "已完成": true}
	for _, it := range resp.List {
		if !valid[it.Status] {
			t.Fatalf("status=%q not in {进行中,待启动,已完成}", it.Status)
		}
	}
}

func TestHomeAlerts(t *testing.T) {
	data := getData(t, newHomeTestRouter(t), "/api/v1/workbench/home/alerts")
	var resp struct {
		List []struct {
			ID         int64  `json:"id"`
			Level      string `json:"level"`
			Title      string `json:"title"`
			OccurredAt string `json:"occurred_at"`
			RuleCode   string `json:"rule_code"`
		} `json:"list"`
	}
	if err := json.Unmarshal(data, &resp); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if resp.List == nil {
		t.Fatal("list serialized as null")
	}
	valid := map[string]bool{"urgent": true, "major": true, "minor": true}
	dateRe := regexp.MustCompile(`^\d{4}-\d{2}-\d{2}$`)
	for _, it := range resp.List {
		if !valid[it.Level] {
			t.Fatalf("level=%q not in {urgent,major,minor}", it.Level)
		}
		if !dateRe.MatchString(it.OccurredAt) {
			t.Fatalf("occurred_at=%q not YYYY-MM-DD", it.OccurredAt)
		}
	}
}

func TestHomeNotices(t *testing.T) {
	data := getData(t, newHomeTestRouter(t), "/api/v1/workbench/home/notices")
	var resp struct {
		List []map[string]any `json:"list"`
	}
	if err := json.Unmarshal(data, &resp); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if resp.List == nil {
		t.Fatal("list serialized as null")
	}
	for _, it := range resp.List {
		if _, ok := it["urgent"].(bool); !ok {
			t.Fatalf("urgent=%v not bool", it["urgent"])
		}
	}
}
