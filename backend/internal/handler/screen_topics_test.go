// handler 级测试：httptest 直挂 Topics，连真库断言契约 §13.1 形状与冻结值
// 库连接取 DATABASE_URL，缺省本地演示库；不可达时 Skip（helper 前缀 tps 防同包撞名）
package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"testing"

	"github.com/gin-gonic/gin"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
)

func tpsRouter(t *testing.T) *gin.Engine {
	t.Helper()
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://localhost/hospital_edss?sslmode=disable"
	}
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Skipf("测试库不可达: %v", err)
	}
	sqlDB, err := db.DB()
	if err != nil || sqlDB.Ping() != nil {
		t.Skipf("测试库 Ping 失败: %v", err)
	}
	gin.SetMode(gin.TestMode)
	r := gin.New()
	h := NewTopicsHandler(db, clock.New(db))
	r.GET("/api/v1/workbench/topics", h.Topics)
	return r
}

type tpsEnvelope struct {
	Code    int             `json:"code"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data"`
	TraceID string          `json:"trace_id"`
}

type tpsData struct {
	Topic string `json:"topic"`
	Range string `json:"range"`
	Stats []struct {
		Label string `json:"label"`
		Value any    `json:"value"`
	} `json:"stats"`
	Table struct {
		Columns []map[string]any `json:"columns"`
		Rows    []map[string]any `json:"rows"`
	} `json:"table"`
	Chart map[string]any `json:"chart"`
}

func tpsGet(t *testing.T, r *gin.Engine, query string) (int, tpsEnvelope) {
	t.Helper()
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/workbench/topics?"+query, nil)
	r.ServeHTTP(w, req)
	var body tpsEnvelope
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("包络解析失败: %v body=%s", err, w.Body.String())
	}
	return w.Code, body
}

func tpsDecode(t *testing.T, body tpsEnvelope) tpsData {
	t.Helper()
	var d tpsData
	if err := json.Unmarshal(body.Data, &d); err != nil {
		t.Fatalf("data 解析失败: %v", err)
	}
	return d
}

// 四 topic × 三 range：HTTP200+code0+topic/range 回显+stats len=6+table.columns 非空
func TestTopicsMatrix(t *testing.T) {
	r := tpsRouter(t)
	for _, tp := range []string{"drg", "insurance", "exam", "outp_fund"} {
		for _, rng := range []string{"本月", "本季", "本年"} {
			code, body := tpsGet(t, r, "topic="+tp+"&range="+url.QueryEscape(rng))
			if code != http.StatusOK || body.Code != 0 {
				t.Fatalf("topic=%s range=%s → HTTP%d code=%d", tp, rng, code, body.Code)
			}
			d := tpsDecode(t, body)
			if d.Topic != tp || d.Range != rng {
				t.Errorf("topic=%s range=%s 回显错误: %+v/%+v", tp, rng, d.Topic, d.Range)
			}
			if len(d.Stats) != 6 {
				t.Errorf("topic=%s range=%s stats len=%d, want 6", tp, rng, len(d.Stats))
			}
			if len(d.Table.Columns) == 0 {
				t.Errorf("topic=%s range=%s table.columns 为空", tp, rng)
			}
		}
	}
}

// 参数非法/缺席：HTTP400+code10001+data.fields 对应键
func TestTopicsInvalidArgs(t *testing.T) {
	r := tpsRouter(t)
	cases := []struct {
		name  string
		query string
		field string
	}{
		{"topic 空值", "topic=", "topic"},
		{"topic 非法", "topic=bad", "topic"},
		{"topic 缺席", "range=" + url.QueryEscape("本月"), "topic"},
		{"range 非法", "topic=drg&range=" + url.QueryEscape("坏"), "range"},
	}
	for _, tc := range cases {
		code, body := tpsGet(t, r, tc.query)
		if code != http.StatusBadRequest || body.Code != 10001 {
			t.Fatalf("%s(%s) → HTTP%d code=%d, want 400/10001", tc.name, tc.query, code, body.Code)
		}
		var d struct {
			Fields map[string]string `json:"fields"`
		}
		if err := json.Unmarshal(body.Data, &d); err != nil {
			t.Fatalf("%s data 解析失败: %v", tc.name, err)
		}
		if _, ok := d.Fields[tc.field]; !ok {
			t.Errorf("%s data.fields 缺键 %q: %+v", tc.name, tc.field, d.Fields)
		}
	}
}

// exam stats 含 "786"（TOTAL_SCORE 0.7860×1000）
func TestTopicsExamScore(t *testing.T) {
	r := tpsRouter(t)
	code, body := tpsGet(t, r, "topic=exam")
	if code != http.StatusOK {
		t.Fatalf("HTTP%d", code)
	}
	d := tpsDecode(t, body)
	found := false
	for _, s := range d.Stats {
		if s.Label == "国考预估得分" && s.Value == "786" {
			found = true
		}
	}
	if !found {
		t.Errorf("exam stats 未含 国考预估得分=786: %+v", d.Stats)
	}
}

// drg table=契约固定 8 科室名册；cmi/profit 冻结值逐字（神经内科 0.94/+38.2）
func TestTopicsDrgRoster(t *testing.T) {
	r := tpsRouter(t)
	code, body := tpsGet(t, r, "topic=drg&range="+url.QueryEscape("本年"))
	if code != http.StatusOK {
		t.Fatalf("HTTP%d", code)
	}
	d := tpsDecode(t, body)
	if len(d.Table.Rows) != 8 {
		t.Fatalf("drg table rows=%d, want 8", len(d.Table.Rows))
	}
	var tcm map[string]any
	for _, row := range d.Table.Rows {
		if row["dept"] == "神经内科" {
			tcm = row
		}
	}
	if tcm == nil {
		t.Fatalf("drg table 缺神经内科行: %+v", d.Table.Rows)
	}
	if tcm["cmi"] != "0.94" || tcm["profit"] != "+38.2" {
		t.Errorf("神经内科行冻结值偏离: cmi=%v profit=%v", tcm["cmi"], tcm["profit"])
	}
}
