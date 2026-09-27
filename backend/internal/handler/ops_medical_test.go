// §5 GET /workbench/medical handler 测试:三 tab 200+字段断言、非法参数、缺省、trend 窗口
package handler

import (
	"encoding/json"
	"net/url"
	"testing"
)

// medTestResp 测试侧解码镜像(字段对齐 types.ts MedicalResp)
type medTestResp struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    struct {
		Tab   string `json:"tab"`
		Range string `json:"range"`
		Stats []struct {
			Label string `json:"label"`
			Value any    `json:"value"`
			Unit  string `json:"unit"`
			Delta string `json:"delta"`
			Dir   string `json:"dir"`
			Note  string `json:"note"`
		} `json:"stats"`
		Trend struct {
			Title  string   `json:"title"`
			Name   string   `json:"name"`
			Unit   string   `json:"unit"`
			Months []string `json:"months"`
			Values []int64  `json:"values"`
		} `json:"trend"`
		Distribution struct {
			Title      string   `json:"title"`
			Sub        string   `json:"sub"`
			Type       string   `json:"type"`
			Unit       string   `json:"unit"`
			Categories []string `json:"categories"`
			Values     []int64  `json:"values"`
		} `json:"distribution"`
		Table struct {
			Columns []struct {
				Key   string `json:"key"`
				Title string `json:"title"`
			} `json:"columns"`
			Rows []map[string]any `json:"rows"`
		} `json:"table"`
	} `json:"data"`
	TraceID string `json:"trace_id"`
}

type medErrResp struct {
	Code int `json:"code"`
	Data struct {
		Fields map[string]string `json:"fields"`
	} `json:"data"`
}

func medURL(tab, rng string) string {
	v := url.Values{}
	if tab != "" {
		v.Set("tab", tab)
	}
	if rng != "" {
		v.Set("range", rng)
	}
	if q := v.Encode(); q != "" {
		return "/api/v1/workbench/medical?" + q
	}
	return "/api/v1/workbench/medical"
}

func getMed(t *testing.T, tab, rng string) medTestResp {
	t.Helper()
	r := newTestEngine(t)
	body := get(t, r, medURL(tab, rng), 200)
	var resp medTestResp
	if err := json.Unmarshal([]byte(body), &resp); err != nil {
		t.Fatalf("decode: %v; body=%s", err, body)
	}
	return resp
}

func assertMedShape(t *testing.T, resp medTestResp, tab, rng string) {
	t.Helper()
	if resp.Code != 0 || resp.Message != "ok" {
		t.Fatalf("envelope: code=%d message=%q", resp.Code, resp.Message)
	}
	if resp.TraceID == "" {
		t.Fatal("envelope: trace_id empty")
	}
	if resp.Data.Tab != tab || resp.Data.Range != rng {
		t.Fatalf("echo: tab=%q range=%q, want %q/%q", resp.Data.Tab, resp.Data.Range, tab, rng)
	}
	if len(resp.Data.Stats) != 6 {
		t.Fatalf("stats: got %d items, want 6", len(resp.Data.Stats))
	}
	if len(resp.Data.Trend.Months) != len(resp.Data.Trend.Values) {
		t.Fatalf("trend: months=%d values=%d", len(resp.Data.Trend.Months), len(resp.Data.Trend.Values))
	}
	d := resp.Data.Distribution
	if len(d.Categories) != len(d.Values) {
		t.Fatalf("distribution: categories=%d values=%d", len(d.Categories), len(d.Values))
	}
	cols := resp.Data.Table.Columns
	if len(cols) != 6 || cols[0].Key != "dept" || cols[1].Key != "cnt" || cols[2].Key != "yoy" ||
		cols[3].Key != "share" || cols[4].Key != "avg" || cols[5].Key != "drug" {
		t.Fatalf("columns: %+v", cols)
	}
	if len(resp.Data.Table.Rows) != 8 {
		t.Fatalf("table rows: got %d, want 8", len(resp.Data.Table.Rows))
	}
	for _, row := range resp.Data.Table.Rows {
		for _, k := range []string{"dept", "cnt", "yoy", "share", "avg", "drug"} {
			if _, ok := row[k].(string); !ok {
				t.Fatalf("row[%s] not string: %v", k, row)
			}
		}
	}
}

func TestMedicalOutpatient(t *testing.T) {
	resp := getMed(t, "门急诊", "本年")
	assertMedShape(t, resp, "门急诊", "本年")
	d := resp.Data
	if d.Stats[0].Label != "门急诊总人次" || d.Stats[0].Value != "123,443" {
		t.Fatalf("stats[0]: %+v", d.Stats[0])
	}
	if d.Stats[1].Value != "82,286" || d.Stats[2].Value != "29,842" || d.Stats[3].Value != "11,315" {
		t.Fatalf("stats[1..3]: %+v", d.Stats[1:4])
	}
	if d.Stats[4].Value != "299" || d.Stats[4].Unit != "元" {
		t.Fatalf("stats[4]: %+v", d.Stats[4])
	}
	if d.Stats[5].Value != "17.5" || d.Stats[5].Unit != "分钟" {
		t.Fatalf("stats[5]: %+v", d.Stats[5])
	}
	if d.Trend.Title != "门急诊人次趋势" || d.Trend.Unit != "人次" {
		t.Fatalf("trend meta: %+v", d.Trend)
	}
	if len(d.Trend.Months) != 12 || d.Trend.Values[9] != 123443 {
		t.Fatalf("trend 本年: months=%v values=%v", d.Trend.Months, d.Trend.Values)
	}
	if len(d.Distribution.Categories) != 10 || d.Distribution.Type != "bar" {
		t.Fatalf("distribution: %+v", d.Distribution)
	}
	if d.Table.Columns[1].Title != "诊疗人次" || d.Table.Columns[4].Title != "次均费用" {
		t.Fatalf("col titles: %+v", d.Table.Columns)
	}
}

func TestMedicalInpatient(t *testing.T) {
	resp := getMed(t, "住院", "本年")
	assertMedShape(t, resp, "住院", "本年")
	d := resp.Data
	if d.Stats[0].Label != "在院人数" || d.Stats[0].Value != "1,846" || d.Stats[0].Note != "当前实时" {
		t.Fatalf("stats[0]: %+v", d.Stats[0])
	}
	if d.Stats[1].Value != "8,109" || d.Stats[2].Value != "92.1" || d.Stats[3].Value != "6.8" {
		t.Fatalf("stats[1..3]: %+v", d.Stats[1:4])
	}
	if d.Trend.Title != "出院人数趋势" || len(d.Trend.Months) != 12 || d.Trend.Values[9] != 8109 {
		t.Fatalf("trend 本年: %+v", d.Trend)
	}
	if len(d.Distribution.Categories) != 7 || d.Distribution.Categories[0] != "内科" || d.Distribution.Type != "bar" {
		t.Fatalf("distribution: %+v", d.Distribution)
	}
	if d.Table.Columns[1].Title != "出院人次" || d.Table.Columns[4].Title != "次均费用" {
		t.Fatalf("col titles: %+v", d.Table.Columns)
	}
}

func TestMedicalSurgery(t *testing.T) {
	resp := getMed(t, "手术", "本年")
	assertMedShape(t, resp, "手术", "本年")
	d := resp.Data
	if d.Stats[0].Label != "本月手术台次" || d.Stats[0].Value != "1,286" {
		t.Fatalf("stats[0]: %+v", d.Stats[0])
	}
	if d.Stats[1].Value != "58.2" || d.Stats[2].Value != "42.3" ||
		d.Stats[3].Value != "1,050" || d.Stats[4].Value != "236" {
		t.Fatalf("stats[1..4]: %+v", d.Stats[1:5])
	}
	if d.Trend.Title != "手术台次趋势" || d.Trend.Unit != "台" || d.Trend.Values[9] != 1286 {
		t.Fatalf("trend 本年: %+v", d.Trend)
	}
	if d.Distribution.Type != "pie" || len(d.Distribution.Categories) != 4 ||
		d.Distribution.Categories[0] != "四级手术" {
		t.Fatalf("distribution: %+v", d.Distribution)
	}
	if d.Table.Columns[1].Title != "手术台次" || d.Table.Columns[4].Title != "平均时长" {
		t.Fatalf("col titles: %+v", d.Table.Columns)
	}
}

func TestMedicalDefaults(t *testing.T) {
	resp := getMed(t, "", "")
	assertMedShape(t, resp, "门急诊", "本年")
	// 空串参数视同缺省
	resp2 := getMed(t, "", "本月")
	assertMedShape(t, resp2, "门急诊", "本月")
}

func TestMedicalInvalidParams(t *testing.T) {
	r := newTestEngine(t)
	var e medErrResp
	body := get(t, r, medURL("坏", "本年"), 400)
	if err := json.Unmarshal([]byte(body), &e); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if e.Code != 10001 || e.Data.Fields["tab"] == "" {
		t.Fatalf("invalid tab: %+v", e)
	}
	e = medErrResp{}
	body = get(t, r, medURL("门急诊", "坏"), 400)
	if err := json.Unmarshal([]byte(body), &e); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if e.Code != 10001 || e.Data.Fields["range"] == "" {
		t.Fatalf("invalid range: %+v", e)
	}
}

func TestMedicalTrendWindow(t *testing.T) {
	// trend 窗口随 range:本月=10月单月,本季=8~10月,本年=12月全轴(mock trendSlice)
	want := map[string]int{"本月": 1, "本季": 3, "本年": 12}
	for _, tab := range []string{"门急诊", "住院", "手术"} {
		for rng, n := range want {
			resp := getMed(t, tab, rng)
			if len(resp.Data.Trend.Months) != n {
				t.Fatalf("%s/%s: months=%v want %d", tab, rng, resp.Data.Trend.Months, n)
			}
		}
	}
}

func TestMedicalStatsRangeInvariant(t *testing.T) {
	// stats 恒当月口径不随 range(契约 §5 口径注)
	for _, rng := range []string{"本月", "本季", "本年"} {
		resp := getMed(t, "门急诊", rng)
		if resp.Data.Stats[0].Value != "123,443" {
			t.Fatalf("range=%s: stats[0]=%v", rng, resp.Data.Stats[0])
		}
	}
}
