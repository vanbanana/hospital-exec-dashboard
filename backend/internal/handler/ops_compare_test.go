// E2-T4 §12 compare handler 测试:4 dim×3 range 抽查 + 非法枚举 + 缺省参数 + metric 勾稽(真库)
package handler

import (
	"encoding/json"
	"net/url"
	"strconv"
	"strings"
	"testing"
)

type cpTestRow struct {
	Rank   int     `json:"rank"`
	Dept   string  `json:"dept"`
	Metric string  `json:"metric"`
	BarPct int64   `json:"bar_pct"`
	Yoy    string  `json:"yoy"`
	Outp   int64   `json:"outp"`
	Inpt   int64   `json:"inpt"`
	Days   float64 `json:"days"`
	Sat    float64 `json:"sat"`
}

type cpTestEnvelope struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    struct {
		Dimension string `json:"dimension"`
		Range     string `json:"range"`
		Radar     struct {
			Indicators []struct {
				Name string `json:"name"`
				Max  int    `json:"max"`
			} `json:"indicators"`
			Series []struct {
				Name  string    `json:"name"`
				Value []float64 `json:"value"`
			} `json:"series"`
		} `json:"radar"`
		Benchmarks []struct {
			Name   string `json:"name"`
			Ours   string `json:"ours"`
			Region string `json:"region"`
			Bench  string `json:"bench"`
			Gap    string `json:"gap"`
		} `json:"benchmarks"`
		Table struct {
			Columns []Col       `json:"columns"`
			Rows    []cpTestRow `json:"rows"`
		} `json:"table"`
	} `json:"data"`
	TraceID string `json:"trace_id"`
	Ts      int64  `json:"ts"`
}

var cpWantMetricTitle = map[string]string{
	"scale": "业务量当量", "benefit": "医疗收入", "efficiency": "床位周转次数", "quality": "质量综合评分",
}

func getCompare(t *testing.T, dim, rk string, wantStatus int) cpTestEnvelope {
	t.Helper()
	r := newTestEngine(t)
	var env cpTestEnvelope
	q := url.Values{}
	if dim != "" {
		q.Set("dim", dim)
	}
	if rk != "" {
		q.Set("range", rk)
	}
	body := getOps(t, r, "/api/v1/workbench/compare?"+q.Encode(), wantStatus)
	if wantStatus == 200 {
		if err := json.Unmarshal([]byte(body), &env); err != nil {
			t.Fatalf("dim=%s range=%s decode: %v; body=%s", dim, rk, err, body)
		}
	}
	return env
}

// cpDecomma 千分位串 → 数(metric 勾稽用)
func cpDecomma(t *testing.T, s string) int64 {
	t.Helper()
	n, err := strconv.ParseInt(strings.ReplaceAll(s, ",", ""), 10, 64)
	if err != nil {
		t.Fatalf("metric 非千分位整串: %q", s)
	}
	return n
}

func TestCompareDimRangeMatrix(t *testing.T) {
	for _, dim := range []string{"scale", "benefit", "efficiency", "quality"} {
		for _, rk := range []string{"本月", "本季", "本年"} {
			env := getCompare(t, dim, rk, 200)
			if env.Code != 0 || env.Message != "ok" || env.TraceID == "" || env.Ts <= 0 {
				t.Fatalf("dim=%s range=%s 包络残缺", dim, rk)
			}
			if env.Data.Dimension != dim || env.Data.Range != rk {
				t.Fatalf("echo 不符: %s/%s", env.Data.Dimension, env.Data.Range)
			}
			if len(env.Data.Radar.Indicators) != 6 || len(env.Data.Radar.Series) != 2 ||
				len(env.Data.Radar.Series[0].Value) != 6 {
				t.Fatalf("dim=%s radar 形状异常", dim)
			}
			if len(env.Data.Benchmarks) != 6 {
				t.Fatalf("dim=%s benchmarks=%d, want 6", dim, len(env.Data.Benchmarks))
			}
			if len(env.Data.Table.Columns) != 8 {
				t.Fatalf("dim=%s columns=%d, want 8", dim, len(env.Data.Table.Columns))
			}
			if env.Data.Table.Columns[2].Title != cpWantMetricTitle[dim] {
				t.Fatalf("dim=%s metric title=%q, want %q",
					dim, env.Data.Table.Columns[2].Title, cpWantMetricTitle[dim])
			}
			if len(env.Data.Table.Rows) != 6 {
				t.Fatalf("dim=%s range=%s rows=%d, want 6", dim, rk, len(env.Data.Table.Rows))
			}
		}
	}
}

// 锚值抽查(设计 §4 已用 psql 核对):radar 本院首维 86;benchmarks[0].ours="108.8";
// scale 本月 top1=心血管内科 24,722
func TestCompareAnchors(t *testing.T) {
	env := getCompare(t, "scale", "本月", 200)
	if env.Data.Radar.Series[0].Value[0] != 86 {
		t.Fatalf("radar 本院[0]=%v, want 86", env.Data.Radar.Series[0].Value[0])
	}
	if env.Data.Benchmarks[0].Ours != "108.8" {
		t.Fatalf("benchmarks[0].ours=%q, want 108.8", env.Data.Benchmarks[0].Ours)
	}
	top := env.Data.Table.Rows[0]
	if top.Dept != "心血管内科" || cpDecomma(t, top.Metric) != 24722 {
		t.Fatalf("scale top1=%s %s, want 心血管内科 24,722", top.Dept, top.Metric)
	}
}

// §12 注4 勾稽:scale 每行 metric == outp + inpt×10
func TestCompareScaleMetricReconcile(t *testing.T) {
	for _, rk := range []string{"本月", "本季", "本年"} {
		env := getCompare(t, "scale", rk, 200)
		for _, row := range env.Data.Table.Rows {
			if got, want := cpDecomma(t, row.Metric), row.Outp+row.Inpt*10; got != want {
				t.Fatalf("range=%s dept=%s metric=%d, outp+inpt×10=%d", rk, row.Dept, got, want)
			}
		}
	}
}

func TestCompareDefaults(t *testing.T) {
	env := getCompare(t, "", "", 200)
	if env.Data.Dimension != "scale" || env.Data.Range != "本月" {
		t.Fatalf("缺省 echo=%s/%s, want scale/本月", env.Data.Dimension, env.Data.Range)
	}
}

func TestCompareInvalidParams(t *testing.T) {
	r := newTestEngine(t)
	for _, q := range []string{"dim=bad", "range=bad"} {
		body := getOps(t, r, "/api/v1/workbench/compare?"+q, 400)
		var env struct {
			Code int `json:"code"`
			Data struct {
				Fields map[string]string `json:"fields"`
			} `json:"data"`
		}
		if err := json.Unmarshal([]byte(body), &env); err != nil {
			t.Fatalf("q=%s decode: %v", q, err)
		}
		if env.Code != 10001 {
			t.Fatalf("q=%s code=%d, want 10001", q, env.Code)
		}
		field := strings.SplitN(q, "=", 2)[0]
		if env.Data.Fields[field] == "" {
			t.Fatalf("q=%s data.fields.%s 缺失; body=%s", q, field, body)
		}
	}
}
