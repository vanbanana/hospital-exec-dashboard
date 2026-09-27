// E2-T1 §4 overview handler 测试:3 range 正常路径 + 缺省参数 + 非法枚举(真库,见 ops_common_test.go)
package handler

import (
	"encoding/json"
	"net/url"
	"testing"
)

type ovTestEnvelope struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    struct {
		Range             string     `json:"range"`
		Stats             []StatItem `json:"stats"`
		ScaleRevenueTrend struct {
			Months     []string `json:"months"`
			Outpatient []int64  `json:"outpatient"`
			Revenue    []int64  `json:"revenue"`
		} `json:"scale_revenue_trend"`
	} `json:"data"`
	TraceID string `json:"trace_id"`
	Ts      int64  `json:"ts"`
}

// 契约 §4 stats 六宫格固定行序
var ovWantLabels = []string{"门急诊人次", "出院人数", "手术台次", "医疗收入", "床位使用率", "平均住院日"}

func getOverview(t *testing.T, query string) ovTestEnvelope {
	t.Helper()
	r := newTestEngine(t)
	var env ovTestEnvelope
	body := getOps(t, r, "/api/v1/workbench/overview"+query, 200)
	if err := json.Unmarshal([]byte(body), &env); err != nil {
		t.Fatalf("decode: %v; body=%s", err, body)
	}
	return env
}

func assertOverviewOK(t *testing.T, env ovTestEnvelope, wantRange string) {
	t.Helper()
	if env.Code != 0 || env.Message != "ok" || env.TraceID == "" || env.Ts <= 0 {
		t.Fatalf("包络五要素残缺: %+v", env)
	}
	if env.Data.Range != wantRange {
		t.Fatalf("data.range=%q, want %q", env.Data.Range, wantRange)
	}
	if len(env.Data.Stats) != 6 {
		t.Fatalf("stats 项数=%d, want 6", len(env.Data.Stats))
	}
	for i, l := range ovWantLabels {
		if env.Data.Stats[i].Label != l {
			t.Fatalf("stats[%d].label=%q, want %q", i, env.Data.Stats[i].Label, l)
		}
	}
	tr := env.Data.ScaleRevenueTrend
	if len(tr.Months) != 12 || len(tr.Outpatient) != 12 || len(tr.Revenue) != 12 {
		t.Fatalf("trend 长度异常: months=%d outpatient=%d revenue=%d",
			len(tr.Months), len(tr.Outpatient), len(tr.Revenue))
	}
}

func TestOverviewRanges(t *testing.T) {
	r := newTestEngine(t)
	traces := map[string]bool{}
	for _, rk := range []string{"本月", "本季", "本年"} {
		var env ovTestEnvelope
		body := getOps(t, r, "/api/v1/workbench/overview?range="+url.QueryEscape(rk), 200)
		if err := json.Unmarshal([]byte(body), &env); err != nil {
			t.Fatalf("range=%s decode: %v; body=%s", rk, err, body)
		}
		assertOverviewOK(t, env, rk)
		if traces[env.TraceID] {
			t.Fatalf("trace_id 复用: %s", env.TraceID)
		}
		traces[env.TraceID] = true
	}
}

func TestOverviewDefaultRange(t *testing.T) {
	env := getOverview(t, "")
	assertOverviewOK(t, env, "本年")
}

func TestOverviewInvalidRange(t *testing.T) {
	r := newTestEngine(t)
	body := getOps(t, r, "/api/v1/workbench/overview?range=bad", 400)
	var env struct {
		Code int `json:"code"`
		Data struct {
			Fields map[string]string `json:"fields"`
		} `json:"data"`
	}
	if err := json.Unmarshal([]byte(body), &env); err != nil {
		t.Fatalf("decode: %v; body=%s", err, body)
	}
	if env.Code != 10001 {
		t.Fatalf("code=%d, want 10001; body=%s", env.Code, body)
	}
	if env.Data.Fields["range"] == "" {
		t.Fatalf("data.fields.range 缺失; body=%s", body)
	}
}
