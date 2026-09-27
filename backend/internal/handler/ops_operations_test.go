// §6 GET /workbench/operations handler 级测试——三 range/非法参数/结构/锚值(E2-T3 属主文件)
package handler

import (
	"encoding/json"
	"net/url"
	"testing"
)

type opEnvelope struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    struct {
		Stats []struct {
			Label string `json:"label"`
			Value any    `json:"value"`
			Unit  string `json:"unit"`
			Delta string `json:"delta"`
			Dir   string `json:"dir"`
		} `json:"stats"`
		RevenueTrend struct {
			Months  []string `json:"months"`
			Income  []int64  `json:"income"`
			Cost    []int64  `json:"cost"`
			Balance []int64  `json:"balance"`
		} `json:"revenue_trend"`
		CostControls []struct {
			Name    string `json:"name"`
			Value   string `json:"value"`
			Target  string `json:"target"`
			Status  string `json:"status"`
			Pct     int64  `json:"pct"`
			MarkPct int64  `json:"mark_pct"`
		} `json:"cost_controls"`
		DeptTable struct {
			Columns []struct {
				Key   string `json:"key"`
				Title string `json:"title"`
			} `json:"columns"`
			Rows []map[string]any `json:"rows"`
		} `json:"dept_table"`
	} `json:"data"`
	TraceID string `json:"trace_id"`
	TS      int64  `json:"ts"`
}

func decodeOp(t *testing.T, body string) opEnvelope {
	t.Helper()
	var e opEnvelope
	if err := json.Unmarshal([]byte(body), &e); err != nil {
		t.Fatalf("decode envelope: %v; body=%s", err, body)
	}
	return e
}

func opURL(range_ string) string {
	if range_ == "" {
		return "/api/v1/workbench/operations"
	}
	return "/api/v1/workbench/operations?range=" + url.QueryEscape(range_)
}

func assertOpShape(t *testing.T, e opEnvelope) {
	t.Helper()
	if e.Code != 0 || e.Message != "ok" {
		t.Fatalf("envelope code=%d message=%q, want 0/ok", e.Code, e.Message)
	}
	if e.TraceID == "" || e.TS == 0 {
		t.Fatalf("envelope missing trace_id/ts: %+v", e)
	}
	if len(e.Data.Stats) != 6 {
		t.Fatalf("stats len=%d, want 6", len(e.Data.Stats))
	}
	for _, s := range e.Data.Stats {
		if s.Label == "" || s.Value == nil || s.Value == "" {
			t.Fatalf("stat missing label/value: %+v", s)
		}
		if s.Dir != "" && s.Dir != "up" && s.Dir != "down" && s.Dir != "flat" {
			t.Fatalf("stat dir=%q not in {up,down,flat}", s.Dir)
		}
	}
	tr := e.Data.RevenueTrend
	if len(tr.Months) != 12 || len(tr.Income) != 12 || len(tr.Cost) != 12 || len(tr.Balance) != 12 {
		t.Fatalf("revenue_trend lens=%d/%d/%d/%d, want 12 each",
			len(tr.Months), len(tr.Income), len(tr.Cost), len(tr.Balance))
	}
	if len(e.Data.CostControls) != 6 {
		t.Fatalf("cost_controls len=%d, want 6", len(e.Data.CostControls))
	}
	for _, cc := range e.Data.CostControls {
		if cc.Name == "" || cc.Value == "" || cc.Target == "" {
			t.Fatalf("cost_control missing field: %+v", cc)
		}
		if cc.Status != "达标" && cc.Status != "超标" {
			t.Fatalf("cost_control %q status=%q not in {达标,超标}", cc.Name, cc.Status)
		}
	}
	if len(e.Data.DeptTable.Columns) != 7 {
		t.Fatalf("dept_table columns len=%d, want 7", len(e.Data.DeptTable.Columns))
	}
	if n := len(e.Data.DeptTable.Rows); n == 0 || n > 6 {
		t.Fatalf("dept_table rows len=%d, want 1..6", n)
	}
	for _, row := range e.Data.DeptTable.Rows {
		for _, k := range []string{"dept", "income", "cost", "balance", "margin", "drug_ratio", "mat_ratio"} {
			if _, ok := row[k]; !ok {
				t.Fatalf("dept_table row missing key %q: %v", k, row)
			}
		}
	}
}

// 三 range 均 200 + 全结构断言;空串 range 走缺省=本年
func TestOperationsRanges(t *testing.T) {
	r := newTestEngine(t)
	for _, rk := range []string{"本月", "本季", "本年", ""} {
		e := decodeOp(t, getOps(t, r, opURL(rk), 200))
		assertOpShape(t, e)
	}
}

// 契约 §6.1 响应不回显 range(OperationsResp 无该字段)
func TestOperationsNoRangeEcho(t *testing.T) {
	r := newTestEngine(t)
	body := getOps(t, r, opURL("本月"), 200)
	var m map[string]any
	if err := json.Unmarshal([]byte(body), &m); err != nil {
		t.Fatalf("decode: %v", err)
	}
	data, _ := m["data"].(map[string]any)
	if _, ok := data["range"]; ok {
		t.Fatalf("operations 响应回显了 range 字段,违反 types.ts OperationsResp")
	}
}

// 锚值:本年总收入 120,260 万;trend.income 前 10 月序列;门诊输液率超标
func TestOperationsAnchors(t *testing.T) {
	r := newTestEngine(t)
	e := decodeOp(t, getOps(t, r, opURL("本年"), 200))
	assertOpShape(t, e)
	if e.Data.Stats[0].Label != "医疗总收入" || e.Data.Stats[0].Value != "120,260" {
		t.Fatalf("stats[0]=%+v, want 医疗总收入 120,260", e.Data.Stats[0])
	}
	want := []int64{8950, 8060, 10800, 11650, 12450, 12980, 13940, 13550, 13080, 14800}
	for i, w := range want {
		if e.Data.RevenueTrend.Income[i] != w {
			t.Fatalf("income[%d]=%d, want %d", i, e.Data.RevenueTrend.Income[i], w)
		}
	}
	var infusion *struct{ Status string }
	for i := range e.Data.CostControls {
		if e.Data.CostControls[i].Name == "门诊输液率" {
			infusion = &struct{ Status string }{e.Data.CostControls[i].Status}
		}
	}
	if infusion == nil {
		t.Fatal("cost_controls 缺 门诊输液率 行")
	}
	if infusion.Status != "超标" {
		t.Fatalf("门诊输液率 status=%q, want 超标", infusion.Status)
	}
}

// 非法 range → 400 + code 10001 + data.fields.range
func TestOperationsBadRange(t *testing.T) {
	r := newTestEngine(t)
	body := getOps(t, r, opURL("bad"), 400)
	var e struct {
		Code int `json:"code"`
		Data struct {
			Fields map[string]string `json:"fields"`
		} `json:"data"`
	}
	if err := json.Unmarshal([]byte(body), &e); err != nil {
		t.Fatalf("decode: %v; body=%s", err, body)
	}
	if e.Code != 10001 {
		t.Fatalf("code=%d, want 10001", e.Code)
	}
	if e.Data.Fields["range"] == "" {
		t.Fatalf("data.fields.range 缺席: %v", e.Data.Fields)
	}
}
