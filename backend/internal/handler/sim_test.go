package handler

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
)

// 实库断言锚点:sim.clock BASE_DATE=2026-10-28 09:00+08 周三;
// sim.profile 当前无 seed_end 键 → 回退 MAX(dwd.charge_day.date)=2026-12-31。
// 库边界:写用例(tick/reset/set/jobs 自供行)走 DATABASE_URL_W 克隆库,纪律同 write_test.go;
// 纯读用例留共享库。入口复位 + defer 复位保留——克隆库不重建周期内自身也须零残留。

func simRouter(t *testing.T, db *gorm.DB) *gin.Engine {
	t.Helper()
	h := NewSim(db, clock.New(db))
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(func(c *gin.Context) { c.Set("trace_id", "test-trace"); c.Next() })
	s := r.Group("/api/v1/sim")
	s.GET("/clock", h.Clock)
	s.POST("/clock", h.SetClock)
	s.POST("/tick", h.Tick)
	s.POST("/reset", h.Reset)
	s.GET("/jobs", h.Jobs)
	return r
}

// post body=nil 表示零字节请求体(Content-Length=0 → EOF 路径)
func post(t *testing.T, r *gin.Engine, path string, body io.Reader) (int, envelopeBody) {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, path, body)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var b envelopeBody
	if err := json.Unmarshal(w.Body.Bytes(), &b); err != nil {
		t.Fatalf("包络反序列化: %v body=%s", err, w.Body.String())
	}
	return w.Code, b
}

// 复位=时钟归种子 + job_log 清回 SeedLoader 单行(用例产物不留给下一跑)
func resetSimClock(t *testing.T, db *gorm.DB) {
	t.Helper()
	if err := db.Exec(
		`UPDATE sim.clock SET virtual_now='2026-10-28 09:00:00+08', speed=1, paused=false WHERE id=1`,
	).Error; err != nil {
		t.Fatalf("sim.clock 复位: %v", err)
	}
	if err := db.Exec(`DELETE FROM sim.job_log WHERE job <> 'SeedLoader'`).Error; err != nil {
		t.Fatalf("sim.job_log 清场: %v", err)
	}
}

type simClockData struct {
	VirtualNow string  `json:"virtual_now"`
	BaseDate   string  `json:"base_date"`
	SeedEnd    string  `json:"seed_end"`
	Speed      float64 `json:"speed"`
	Paused     bool    `json:"paused"`
	Weekday    string  `json:"weekday"`
	UpdatedAt  string  `json:"updated_at"`
}

type simJobItem struct {
	ID          int64   `json:"id"`
	Job         string  `json:"job"`
	VirtualDate string  `json:"virtual_date"`
	StartedAt   string  `json:"started_at"`
	FinishedAt  *string `json:"finished_at"`
	RowsCnt     int     `json:"rows_cnt"`
	JobStatus   string  `json:"job_status"`
	Err         *string `json:"err"`
}

type simJobsData struct {
	List  []simJobItem `json:"list"`
	Page  int          `json:"page"`
	Size  int          `json:"size"`
	Total int64        `json:"total"`
}

// 最近一条指定作业台账行(断言 job_log 新增)
func lastJob(t *testing.T, db *gorm.DB, job string) simJobItem {
	t.Helper()
	var row simJobItem
	tx := db.Raw(`SELECT id, job, virtual_date::text, started_at::text, finished_at::text,
		rows_cnt, job_status, err FROM sim.job_log WHERE job=? ORDER BY id DESC LIMIT 1`, job).Scan(&row)
	if tx.Error != nil || tx.RowsAffected == 0 {
		t.Fatalf("job_log 缺 %s 行: err=%v rows=%d", job, tx.Error, tx.RowsAffected)
	}
	return row
}

func TestSimClockGet(t *testing.T) {
	r := simRouter(t, testDB(t)) // 纯读:共享库
	status, b := get(t, r, "/api/v1/sim/clock")
	assertOK(t, status, b)

	var d simClockData
	if err := json.Unmarshal(b.Data, &d); err != nil {
		t.Fatalf("data 反序列化: %v", err)
	}
	if d.VirtualNow == "" || d.BaseDate == "" || d.SeedEnd == "" || d.Weekday == "" || d.UpdatedAt == "" {
		t.Fatalf("六字段不齐: %+v", d)
	}
	if _, err := time.Parse(time.RFC3339, d.VirtualNow); err != nil {
		t.Fatalf("virtual_now 非 RFC3339: %q", d.VirtualNow)
	}
	if _, err := time.Parse(time.RFC3339, d.UpdatedAt); err != nil {
		t.Fatalf("updated_at 非 RFC3339: %q", d.UpdatedAt)
	}
	if d.BaseDate != "2026-10-28" || d.Weekday != "星期三" {
		t.Fatalf("base_date=%q weekday=%q want 2026-10-28/星期三", d.BaseDate, d.Weekday)
	}
	if d.Speed != 1 || d.Paused {
		t.Fatalf("speed=%v paused=%v want 1/false", d.Speed, d.Paused)
	}
	// seed_end 回退:profile 无该键 → MAX(dwd.charge_day.date)=2026-12-31(契约 §16.1 字段注)
	if d.SeedEnd != "2026-12-31" {
		t.Fatalf("seed_end=%q want 2026-12-31(MAX charge_day 回退)", d.SeedEnd)
	}
}

func TestSimTickAdvance(t *testing.T) {
	db := writeTestDB(t)
	resetSimClock(t, db) // 入口归一:跨用例脏时钟/台账不依赖执行序
	defer resetSimClock(t, db)
	r := simRouter(t, db)

	status, b := post(t, r, "/api/v1/sim/tick", strings.NewReader(`{"minutes":60}`))
	assertOK(t, status, b)

	var d struct {
		VirtualNowBefore string `json:"virtual_now_before"`
		VirtualNow       string `json:"virtual_now"`
		AdvancedMinutes  int    `json:"advanced_minutes"`
		CrossedDay       bool   `json:"crossed_day"`
		JobID            int64  `json:"job_id"`
	}
	if err := json.Unmarshal(b.Data, &d); err != nil {
		t.Fatalf("data 反序列化: %v", err)
	}
	if d.VirtualNowBefore != "2026-10-28T09:00:00+08:00" || d.VirtualNow != "2026-10-28T10:00:00+08:00" {
		t.Fatalf("before=%q after=%q want 09:00→10:00", d.VirtualNowBefore, d.VirtualNow)
	}
	if d.AdvancedMinutes != 60 || d.CrossedDay || d.JobID <= 0 {
		t.Fatalf("advanced=%d crossed=%v job_id=%d", d.AdvancedMinutes, d.CrossedDay, d.JobID)
	}
	j := lastJob(t, db, "SimTick")
	if j.ID != d.JobID || j.VirtualDate != "2026-10-28" || j.JobStatus != "success" || j.RowsCnt != 60 {
		t.Fatalf("job_log SimTick 行不符: %+v", j)
	}
}

// 契约 §16.2:minutes 缺/非整/<1/>43200 → 400/10001;空 body/非法 JSON → 10006
func TestSimTickBad(t *testing.T) {
	db := writeTestDB(t)
	defer resetSimClock(t, db) // {"minutes":60} 正常路径外的用例均不写库,保险起见仍复位
	r := simRouter(t, db)

	for _, body := range []string{`{}`, `{"minutes":0}`, `{"minutes":-5}`, `{"minutes":43201}`, `{"minutes":"x"}`, `{"minutes":1.5}`} {
		status, b := post(t, r, "/api/v1/sim/tick", strings.NewReader(body))
		if status != http.StatusBadRequest || b.Code != 10001 {
			t.Fatalf("body=%s → status=%d code=%d want 400/10001", body, status, b.Code)
		}
		var data struct {
			Fields map[string]string `json:"fields"`
		}
		if err := json.Unmarshal(b.Data, &data); err != nil || data.Fields["minutes"] == "" {
			t.Fatalf("body=%s data.fields 缺 minutes 定位: %s", body, string(b.Data))
		}
	}
	for _, body := range []string{`{`, `abc`} {
		status, b := post(t, r, "/api/v1/sim/tick", strings.NewReader(body))
		if status != http.StatusBadRequest || b.Code != 10006 {
			t.Fatalf("body=%s → status=%d code=%d want 400/10006", body, status, b.Code)
		}
	}
	status, b := post(t, r, "/api/v1/sim/tick", nil)
	if status != http.StatusBadRequest || b.Code != 10006 {
		t.Fatalf("空 body → status=%d code=%d want 400/10006", status, b.Code)
	}
}

// 越界构造:先定点跳到 seed_end 当夜,再 tick 越 2027-01-01 上界 → 35002(契约 §16.2)
func TestSimTickBound(t *testing.T) {
	db := writeTestDB(t)
	resetSimClock(t, db)
	defer resetSimClock(t, db)
	r := simRouter(t, db)

	status, b := post(t, r, "/api/v1/sim/clock", strings.NewReader(`{"virtual_now":"2026-12-31T23:30:00+08:00"}`))
	assertOK(t, status, b)

	status, b = post(t, r, "/api/v1/sim/tick", strings.NewReader(`{"minutes":60}`))
	if status != http.StatusBadRequest || b.Code != 35002 {
		t.Fatalf("越界 tick → status=%d code=%d want 400/35002", status, b.Code)
	}
}

func TestSimReset(t *testing.T) {
	db := writeTestDB(t)
	resetSimClock(t, db)
	defer resetSimClock(t, db)
	r := simRouter(t, db)

	if status, b := post(t, r, "/api/v1/sim/tick", strings.NewReader(`{"minutes":120}`)); status != http.StatusOK || b.Code != 0 {
		t.Fatalf("前置 tick: status=%d code=%d", status, b.Code)
	}
	status, b := post(t, r, "/api/v1/sim/reset", strings.NewReader(`{}`))
	assertOK(t, status, b)

	var d struct {
		Scope      string `json:"scope"`
		VirtualNow string `json:"virtual_now"`
		JobID      int64  `json:"job_id"`
	}
	if err := json.Unmarshal(b.Data, &d); err != nil {
		t.Fatalf("data 反序列化: %v", err)
	}
	if d.Scope != "clock" || d.VirtualNow != "2026-10-28T09:00:00+08:00" || d.JobID <= 0 {
		t.Fatalf("reset 响应不符: %+v", d)
	}
	j := lastJob(t, db, "SimReset")
	if j.ID != d.JobID || j.VirtualDate != "2026-10-28" || j.JobStatus != "success" {
		t.Fatalf("job_log SimReset 行不符: %+v", j)
	}
	// 幂等:再 reset 一次仍 200 且时钟同值;空 body(EOF)同效
	if status, b := post(t, r, "/api/v1/sim/reset", nil); status != http.StatusOK || b.Code != 0 {
		t.Fatalf("reset 空 body → status=%d code=%d want 200/0", status, b.Code)
	}
}

// 契约 §16.3:scope=full 未开放 → 35002;其他值 → 10001
func TestSimResetScopeFull(t *testing.T) {
	db := writeTestDB(t)
	defer resetSimClock(t, db)
	r := simRouter(t, db)

	status, b := post(t, r, "/api/v1/sim/reset", strings.NewReader(`{"scope":"full"}`))
	if status != http.StatusBadRequest || b.Code != 35002 {
		t.Fatalf("scope=full → status=%d code=%d want 400/35002", status, b.Code)
	}
	status, b = post(t, r, "/api/v1/sim/reset", strings.NewReader(`{"scope":"x"}`))
	if status != http.StatusBadRequest || b.Code != 10001 {
		t.Fatalf("scope=x → status=%d code=%d want 400/10001", status, b.Code)
	}
}

func TestSimJobs(t *testing.T) {
	db := writeTestDB(t)
	resetSimClock(t, db)
	defer resetSimClock(t, db)
	r := simRouter(t, db)

	// 自供数据:先各造一行 SimTick/SimReset,再断言列表形状
	post(t, r, "/api/v1/sim/tick", strings.NewReader(`{"minutes":30}`))
	post(t, r, "/api/v1/sim/reset", strings.NewReader(`{}`))

	status, b := get(t, r, "/api/v1/sim/jobs")
	assertOK(t, status, b)
	var d simJobsData
	if err := json.Unmarshal(b.Data, &d); err != nil {
		t.Fatalf("data 反序列化: %v", err)
	}
	if d.Page != 1 || d.Size != 20 || d.Total < 3 {
		t.Fatalf("分页形状不符: page=%d size=%d total=%d", d.Page, d.Size, d.Total)
	}
	seen := map[string]bool{}
	for i, it := range d.List {
		seen[it.Job] = true
		if i > 0 && it.StartedAt > d.List[i-1].StartedAt {
			t.Fatalf("list 非 started_at DESC: [%d]=%s 早于 [%d]=%s", i-1, d.List[i-1].StartedAt, i, it.StartedAt)
		}
	}
	for _, job := range []string{"SimTick", "SimReset", "SeedLoader"} {
		if !seen[job] {
			t.Fatalf("list 缺 %s 行: %+v", job, d.List)
		}
	}

	// status 过滤:全部命中行 job_status=success
	status, b = get(t, r, "/api/v1/sim/jobs?status=success")
	assertOK(t, status, b)
	d = simJobsData{}
	if err := json.Unmarshal(b.Data, &d); err != nil {
		t.Fatalf("data 反序列化: %v", err)
	}
	if d.Total == 0 {
		t.Fatalf("status=success 过滤后空集,预期含 SeedLoader/SimTick/SimReset")
	}
	for _, it := range d.List {
		if it.JobStatus != "success" {
			t.Fatalf("status=success 混入 %s: %+v", it.JobStatus, it)
		}
	}

	// 非法参数 → 10001
	for _, q := range []string{"?status=bad", "?status=", "?page=0", "?page=x", "?size=0", "?size=101", "?size=", "?job="} {
		status, b = get(t, r, "/api/v1/sim/jobs"+q)
		if status != http.StatusBadRequest || b.Code != 10001 {
			t.Fatalf("query=%s → status=%d code=%d want 400/10001", q, status, b.Code)
		}
	}

	// 分页形状:size=1&page=2 → 单行 + total 不变
	status, b = get(t, r, "/api/v1/sim/jobs?size=1&page=2")
	assertOK(t, status, b)
	if err := json.Unmarshal(b.Data, &d); err != nil {
		t.Fatalf("data 反序列化: %v", err)
	}
	if len(d.List) != 1 || d.Page != 2 || d.Size != 1 || d.Total < 3 {
		t.Fatalf("size=1&page=2 形状: list=%d page=%d size=%d total=%d", len(d.List), d.Page, d.Size, d.Total)
	}
}

func TestSimSetClock(t *testing.T) {
	db := writeTestDB(t)
	resetSimClock(t, db)
	defer resetSimClock(t, db)
	r := simRouter(t, db)

	status, b := post(t, r, "/api/v1/sim/clock", strings.NewReader(`{"virtual_now":"2026-10-28T07:55:00+08:00"}`))
	assertOK(t, status, b)
	var d struct {
		VirtualNow string `json:"virtual_now"`
		JobID      int64  `json:"job_id"`
	}
	if err := json.Unmarshal(b.Data, &d); err != nil {
		t.Fatalf("data 反序列化: %v", err)
	}
	if d.VirtualNow != "2026-10-28T07:55:00+08:00" || d.JobID <= 0 {
		t.Fatalf("set 响应不符: %+v", d)
	}
	if j := lastJob(t, db, "SimSet"); j.ID != d.JobID || j.VirtualDate != "2026-10-28" || j.JobStatus != "success" {
		t.Fatalf("job_log SimSet 行不符: %+v", j)
	}

	// speed/paused 出席字段写回(契约 §16.5 预留列);随后由复位恢复
	status, b = post(t, r, "/api/v1/sim/clock", strings.NewReader(`{"speed":5,"paused":true}`))
	assertOK(t, status, b)

	for _, tc := range []struct {
		body string
		code int
	}{
		{`{}`, 10001},          // 无有效字段
		{`{"speed":0}`, 35002}, // 字段级非法归 35002(error-codes §3 适用注)
		{`{"speed":1001}`, 35002},
		{`{"speed":"x"}`, 35002},
		{`{"virtual_now":123}`, 35002},
		{`{"virtual_now":"not-a-time"}`, 35002},
		{`{"paused":"x"}`, 35002},
		{`{"virtual_now":"2030-01-01T00:00:00+08:00"}`, 35002},
		{`{"virtual_now":"2026-10-27T00:00:00+08:00"}`, 35002}, // 越下界 base_date
	} {
		status, b := post(t, r, "/api/v1/sim/clock", strings.NewReader(tc.body))
		if status != http.StatusBadRequest || b.Code != tc.code {
			t.Fatalf("body=%s → status=%d code=%d want 400/%d", tc.body, status, b.Code, tc.code)
		}
	}
}
