// P3-EW 写侧端点测试——实库断言,默认指克隆库 hospital_edss_w(DATABASE_URL_W 可覆写,
// 共享库 hospital_edss 绝不写)。每用例 tx 包裹:Cleanup 统一 Rollback,零残留。
// 种子锚点:alert 101/103/104 pending · 96 done · 97 closed;staff 806=急诊科19 · 459=骨科1;
// dept_leader→dept_id=1;sim.clock=2026-10-28 09:00+08。
package handler

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"

	"github.com/gin-gonic/gin"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/repo"
)

var (
	writeDBOnce sync.Once
	writeDBPool *gorm.DB
	writeDBErr  error
)

// writeTestDB 写测试单池——独立 testDB 池(写域 DSN 必须指向克隆库)
func writeTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	writeDBOnce.Do(func() {
		dsn := envOr("DATABASE_URL_W", "postgres://localhost/hospital_edss_w?sslmode=disable")
		db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
		if err != nil {
			writeDBErr = err
			return
		}
		sqlDB, err := db.DB()
		if err != nil {
			writeDBErr = err
			return
		}
		sqlDB.SetMaxOpenConns(8)
		if err := sqlDB.Ping(); err != nil {
			writeDBErr = err
			return
		}
		writeDBPool = db
	})
	if writeDBErr != nil {
		t.Skipf("postgres 不可达: %v", writeDBErr)
	}
	return writeDBPool
}

// writeTx 每用例一 tx——handler/repo 建在其上(内部 Transaction 落 SAVEPOINT),
// trace_id 由测试中间件模拟注入;返回 (router, tx 断言句柄)
func writeTx(t *testing.T) (*gin.Engine, *gorm.DB) {
	t.Helper()
	db := writeTestDB(t)
	tx := db.Begin()
	if tx.Error != nil {
		t.Fatalf("begin tx: %v", tx.Error)
	}
	t.Cleanup(func() { tx.Rollback() })
	h := NewWriteHandler(repo.NewWriteRepo(tx, clock.New(tx)))
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(func(c *gin.Context) { c.Set("trace_id", "test-trace"); c.Next() })
	r.POST("/api/v1/alerts/:id/ack", h.AlertAck)
	r.POST("/api/v1/alerts/:id/dispatch", h.AlertDispatch)
	r.POST("/api/v1/alerts/:id/close", h.AlertClose)
	r.GET("/api/v1/todos", h.TodoList)
	r.POST("/api/v1/todos/:id/status", h.TodoStatus)
	r.GET("/api/v1/staff", h.StaffList)
	r.POST("/api/v1/workbench/settings/rules/:code", h.RuleToggle)
	r.PUT("/api/v1/workbench/settings/preferences", h.PrefsSave)
	return r, tx
}

func writeReq(t *testing.T, r *gin.Engine, method, path, body string) (int, envelopeBody) {
	t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var b envelopeBody
	if err := json.Unmarshal(w.Body.Bytes(), &b); err != nil {
		t.Fatalf("包络反序列化: %v body=%s", err, w.Body.String())
	}
	return w.Code, b
}

func postJSON(t *testing.T, r *gin.Engine, path, body string) (int, envelopeBody) {
	t.Helper()
	return writeReq(t, r, http.MethodPost, path, body)
}

func put(t *testing.T, r *gin.Engine, path, body string) (int, envelopeBody) {
	t.Helper()
	return writeReq(t, r, http.MethodPut, path, body)
}

func dataMap(t *testing.T, b envelopeBody) map[string]any {
	t.Helper()
	var m map[string]any
	if err := json.Unmarshal(b.Data, &m); err != nil {
		t.Fatalf("data 反序列化: %v raw=%s", err, string(b.Data))
	}
	return m
}

func qInt(t *testing.T, tx *gorm.DB, sql string, args ...any) int64 {
	t.Helper()
	var n int64
	if err := tx.Raw(sql, args...).Scan(&n).Error; err != nil {
		t.Fatalf("query: %v sql=%s", err, sql)
	}
	return n
}

func qStr(t *testing.T, tx *gorm.DB, sql string, args ...any) string {
	t.Helper()
	var s string
	if err := tx.Raw(sql, args...).Scan(&s).Error; err != nil {
		t.Fatalf("query: %v sql=%s", err, sql)
	}
	return s
}

func assertCode(t *testing.T, status, wantHTTP int, b envelopeBody, wantCode int) {
	t.Helper()
	if status != wantHTTP || b.Code != wantCode {
		t.Fatalf("status=%d code=%d want %d/%d body=%s", status, b.Code, wantHTTP, wantCode, string(b.Data))
	}
}

// dispatchOn 造一张打开工单——R05 成功路径复用件;返回 todo_id
func dispatchOn(t *testing.T, r *gin.Engine, alertID, assigneeID int64) int64 {
	t.Helper()
	status, b := postJSON(t, r, fmt.Sprintf("/api/v1/alerts/%d/dispatch", alertID),
		fmt.Sprintf(`{"assignee_id":%d,"deadline":"2026-11-30T17:00:00+08:00","note":"限期整改"}`, assigneeID))
	assertCode(t, status, http.StatusOK, b, 0)
	d := dataMap(t, b)
	id, ok := d["todo_id"].(float64)
	if !ok || id <= 0 {
		t.Fatalf("todo_id=%v", d["todo_id"])
	}
	return int64(id)
}

// ---- R04 ack -----------------------------------------------------------------

func TestWriteAlertAck(t *testing.T) {
	r, tx := writeTx(t)

	ackQ := `SELECT count(*) FROM sys.audit_log WHERE action='alert_ack' AND target_type='alert_event' AND target_id='101' AND username='president'`
	ackBefore := qInt(t, tx, ackQ)
	status, b := postJSON(t, r, "/api/v1/alerts/101/ack?role=president", "{}")
	assertCode(t, status, http.StatusOK, b, 0)
	d := dataMap(t, b)
	if d["alert_status"] != "processing" || d["ack_by"] != float64(1) || d["id"] != float64(101) {
		t.Fatalf("data=%v", d)
	}
	if s, ok := d["ack_at"].(string); !ok || s != "2026-10-28T09:00:00+08:00" {
		t.Fatalf("ack_at=%v want 2026-10-28T09:00:00+08:00(virtual_now)", d["ack_at"])
	}
	if got := qStr(t, tx, `SELECT alert_status FROM ads.alert_event WHERE id=101`); got != "processing" {
		t.Fatalf("alert_status=%q want processing", got)
	}
	if n := qInt(t, tx, ackQ); n != ackBefore+1 {
		t.Fatalf("audit alert_delta=%d want +1(克隆库基线残留行不在断言域)", n-ackBefore)
	}
	// 重复认领→33002 data.current_status(幂等语义)
	status, b = postJSON(t, r, "/api/v1/alerts/101/ack", "{}")
	assertCode(t, status, http.StatusConflict, b, 33002)
	if d := dataMap(t, b); d["current_status"] != "processing" {
		t.Fatalf("current_status=%v", d)
	}
}

func TestWriteAlertAckErrors(t *testing.T) {
	r, _ := writeTx(t)
	status, b := postJSON(t, r, "/api/v1/alerts/999/ack", "{}")
	assertCode(t, status, http.StatusNotFound, b, 33001)
	status, b = postJSON(t, r, "/api/v1/alerts/abc/ack", "{}")
	assertCode(t, status, http.StatusBadRequest, b, 10001)
	status, b = postJSON(t, r, "/api/v1/alerts/101/ack?role=bad", "{}")
	assertCode(t, status, http.StatusBadRequest, b, 10001)
}

// ---- R05 dispatch --------------------------------------------------------------

func TestWriteAlertDispatch(t *testing.T) {
	r, tx := writeTx(t)

	todoID := dispatchOn(t, r, 103, 459)
	// todo 行:三点锚点承接(baseline=payload.value 0.963,target=rule.threshold 0.95,metric=BED_USE_RATE)
	if n := qInt(t, tx, `SELECT count(*) FROM ads.todo_order
		WHERE id=$1 AND alert_id=103 AND assignee_id=459 AND dispatcher_id=1 AND todo_status='open'
		  AND baseline_value=0.963 AND target_value=0.95 AND metric_code='BED_USE_RATE'`, todoID); n != 1 {
		t.Fatalf("todo 行锚点不符 count=%d", n)
	}
	// pending 连带认领
	if got := qStr(t, tx, `SELECT alert_status FROM ads.alert_event WHERE id=103`); got != "processing" {
		t.Fatalf("alert_status=%q want processing", got)
	}
	if n := qInt(t, tx, `SELECT count(*) FROM ads.alert_event WHERE id=103 AND ack_at IS NOT NULL AND ack_by=1`); n != 1 {
		t.Fatalf("ack 回填缺失 count=%d", n)
	}
	if n := qInt(t, tx, `SELECT count(*) FROM sys.audit_log WHERE action='todo_dispatch' AND target_type='todo_order' AND target_id=$1`,
		fmt.Sprint(todoID)); n != 1 {
		t.Fatalf("audit todo_dispatch 行数=%d", n)
	}
	// 同告警重复派发→33002{current_status:'todo_open',todo_id}
	status, b := postJSON(t, r, "/api/v1/alerts/103/dispatch",
		`{"assignee_id":459,"deadline":"2026-11-30T17:00:00+08:00"}`)
	assertCode(t, status, http.StatusConflict, b, 33002)
	d := dataMap(t, b)
	if d["current_status"] != "todo_open" || d["todo_id"] != float64(todoID) {
		t.Fatalf("33002 data=%v want todo_open/todo_id=%d", d, todoID)
	}
}

func TestWriteAlertDispatchErrors(t *testing.T) {
	r, _ := writeTx(t)
	// 告警不存在
	status, b := postJSON(t, r, "/api/v1/alerts/999/dispatch",
		`{"assignee_id":459,"deadline":"2026-11-30T17:00:00+08:00"}`)
	assertCode(t, status, http.StatusNotFound, b, 33001)
	// 已 done
	status, b = postJSON(t, r, "/api/v1/alerts/96/dispatch",
		`{"assignee_id":459,"deadline":"2026-11-30T17:00:00+08:00"}`)
	assertCode(t, status, http.StatusConflict, b, 33002)
	if d := dataMap(t, b); d["current_status"] != "done" {
		t.Fatalf("current_status=%v", d)
	}
	// 承办人跨科(alert 104 dept=18,assignee 459 dept=1)
	status, b = postJSON(t, r, "/api/v1/alerts/104/dispatch",
		`{"assignee_id":459,"deadline":"2026-11-30T17:00:00+08:00"}`)
	assertCode(t, status, http.StatusBadRequest, b, 33102)
	// 承办人不存在
	status, b = postJSON(t, r, "/api/v1/alerts/104/dispatch",
		`{"assignee_id":999999,"deadline":"2026-11-30T17:00:00+08:00"}`)
	assertCode(t, status, http.StatusBadRequest, b, 33102)
	// deadline ≤ virtual_now(alert 101 dept=19,assignee 806 dept=19)
	status, b = postJSON(t, r, "/api/v1/alerts/101/dispatch",
		`{"assignee_id":806,"deadline":"2026-10-01T00:00:00+08:00"}`)
	assertCode(t, status, http.StatusBadRequest, b, 33103)
	// 缺字段→10002 fields 定位
	status, b = postJSON(t, r, "/api/v1/alerts/101/dispatch", `{}`)
	assertCode(t, status, http.StatusBadRequest, b, 10002)
	d := dataMap(t, b)
	f, ok := d["fields"].(map[string]any)
	if !ok || f["assignee_id"] == nil || f["deadline"] == nil {
		t.Fatalf("fields=%v", d["fields"])
	}
	// 坏 JSON→10006
	status, b = postJSON(t, r, "/api/v1/alerts/101/dispatch", `{`)
	assertCode(t, status, http.StatusBadRequest, b, 10006)
}

// ---- R06 close -----------------------------------------------------------------

func TestWriteAlertClose(t *testing.T) {
	r, tx := writeTx(t)

	// 空 note→10002 fields.close_note
	status, b := postJSON(t, r, "/api/v1/alerts/104/close", `{}`)
	assertCode(t, status, http.StatusBadRequest, b, 10002)
	if d := dataMap(t, b); d["fields"].(map[string]any)["close_note"] == nil {
		t.Fatalf("fields=%v", d["fields"])
	}
	// 成功闭环
	closeQ := `SELECT count(*) FROM sys.audit_log WHERE action='alert_close' AND target_id='104' AND username='ops_director'`
	closeBefore := qInt(t, tx, closeQ)
	status, b = postJSON(t, r, "/api/v1/alerts/104/close?role=ops_director", `{"close_note":"维保计划已排"}`)
	assertCode(t, status, http.StatusOK, b, 0)
	d := dataMap(t, b)
	if d["alert_status"] != "closed" || d["closed_at"] != "2026-10-28T09:00:00+08:00" {
		t.Fatalf("data=%v", d)
	}
	if n := qInt(t, tx, `SELECT count(*) FROM ads.alert_event
		WHERE id=104 AND alert_status='closed' AND closed_at IS NOT NULL AND close_note='维保计划已排'`); n != 1 {
		t.Fatalf("close 落库不符 count=%d", n)
	}
	if n := qInt(t, tx, closeQ); n != closeBefore+1 {
		t.Fatalf("audit alert_close delta=%d want +1", n-closeBefore)
	}
	// 重复关闭→33002 closed
	status, b = postJSON(t, r, "/api/v1/alerts/104/close", `{"close_note":"再关一次"}`)
	assertCode(t, status, http.StatusConflict, b, 33002)
	if d := dataMap(t, b); d["current_status"] != "closed" {
		t.Fatalf("current_status=%v", d)
	}
}

// 打开工单禁跨越关闭→33002{current_status:'todo_open'}
func TestWriteAlertCloseBlockedByOpenTodo(t *testing.T) {
	r, _ := writeTx(t)
	dispatchOn(t, r, 103, 459)
	status, b := postJSON(t, r, "/api/v1/alerts/103/close", `{"close_note":"想跨单关闭"}`)
	assertCode(t, status, http.StatusConflict, b, 33002)
	if d := dataMap(t, b); d["current_status"] != "todo_open" {
		t.Fatalf("current_status=%v want todo_open", d)
	}
}

// ---- R07 todos -----------------------------------------------------------------

func TestWriteTodoList(t *testing.T) {
	r, tx := writeTx(t)

	// 惰性过期锚:截止 2026-10-25 < virtual_now(2026-10-28) 的 open 单
	var staleID int64
	if err := tx.Raw(`INSERT INTO ads.todo_order
		(alert_id,alert_occurred_at,title,assignee_id,dispatcher_id,deadline,created_at,updated_at)
		VALUES(96,'2026-10-22 08:05:00+08','过期未办单',806,1,'2026-10-25 00:00:00+08','2026-10-22 09:00:00+08','2026-10-22 09:00:00+08')
		RETURNING id`).Scan(&staleID).Error; err != nil {
		t.Fatalf("造过期单: %v", err)
	}
	newID := dispatchOn(t, r, 103, 459)

	status, b := get(t, r, "/api/v1/todos?size=50")
	assertCode(t, status, http.StatusOK, b, 0)
	var page struct {
		List  []map[string]any `json:"list"`
		Page  int              `json:"page"`
		Size  int              `json:"size"`
		Total int              `json:"total"`
	}
	if err := json.Unmarshal(b.Data, &page); err != nil {
		t.Fatalf("分页 data: %v", err)
	}
	if page.Page != 1 || page.Size != 50 || page.Total < 2 {
		t.Fatalf("page=%+v", page)
	}
	byID := map[int64]map[string]any{}
	for _, row := range page.List {
		byID[int64(row["id"].(float64))] = row
	}
	// 惰性清扫已把过期单落库为 expired(存储值语义)
	stale := byID[staleID]
	if stale == nil || stale["todo_status"] != "expired" || stale["status_label"] != "已逾期" {
		t.Fatalf("过期单行=%v", stale)
	}
	if got := qStr(t, tx, `SELECT todo_status FROM ads.todo_order WHERE id=$1`, staleID); got != "expired" {
		t.Fatalf("库存态=%q want expired(清扫须落库)", got)
	}
	// 新开单:open + 三点锚点(current_value=BED_USE_RATE 院级实时值 0.9212)
	nw := byID[newID]
	if nw == nil || nw["todo_status"] != "open" || nw["status_label"] != "待处理" {
		t.Fatalf("新单行=%v", nw)
	}
	if nw["baseline_value"] != 0.963 || nw["target_value"] != 0.95 ||
		nw["current_value"] != 0.9212 || nw["metric_code"] != "BED_USE_RATE" {
		t.Fatalf("三点锚点=%v", nw)
	}
	if nw["assignee_name"] != "郑平泽" || nw["dept_name"] != "骨科" {
		t.Fatalf("承办人/科室=%v/%v", nw["assignee_name"], nw["dept_name"])
	}
	if s, ok := nw["created_at"].(string); !ok || s != "2026-10-28 09:00" {
		t.Fatalf("created_at=%v want 2026-10-28 09:00", nw["created_at"])
	}
}

func TestWriteTodoListFilters(t *testing.T) {
	r, _ := writeTx(t)
	// status 过滤
	status, b := get(t, r, "/api/v1/todos?status=expired")
	assertCode(t, status, http.StatusOK, b, 0)
	// 非法参数逐个→10001
	for _, p := range []string{
		"/api/v1/todos?page=0", "/api/v1/todos?page=x", "/api/v1/todos?size=101",
		"/api/v1/todos?status=bogus", "/api/v1/todos?assignee_id=x",
	} {
		status, b := get(t, r, p)
		assertCode(t, status, http.StatusBadRequest, b, 10001)
	}
}

// ---- R08 todo status ------------------------------------------------------------

func TestWriteTodoStatusFlow(t *testing.T) {
	r, tx := writeTx(t)
	todoID := dispatchOn(t, r, 103, 459)

	// open 直接 report→10002 fields.action(须先接单;33104 只用于 done/expired)
	status, b := postJSON(t, r, fmt.Sprintf("/api/v1/todos/%d/status", todoID),
		`{"action":"report","result_note":"跳步办结"}`)
	assertCode(t, status, http.StatusBadRequest, b, 10002)
	if d := dataMap(t, b); d["fields"].(map[string]any)["action"] == nil {
		t.Fatalf("fields=%v", d["fields"])
	}
	// accept:open→doing,alert_status 回当前态 processing
	status, b = postJSON(t, r, fmt.Sprintf("/api/v1/todos/%d/status?role=dept_leader", todoID), `{"action":"accept"}`)
	assertCode(t, status, http.StatusOK, b, 0)
	d := dataMap(t, b)
	if d["todo_status"] != "doing" || d["alert_status"] != "processing" || d["alert_id"] != float64(103) {
		t.Fatalf("accept data=%v", d)
	}
	// 重复 accept→33104{current_status:'doing'}
	status, b = postJSON(t, r, fmt.Sprintf("/api/v1/todos/%d/status", todoID), `{"action":"accept"}`)
	assertCode(t, status, http.StatusConflict, b, 33104)
	// report 缺 result_note→10002
	status, b = postJSON(t, r, fmt.Sprintf("/api/v1/todos/%d/status", todoID), `{"action":"report"}`)
	assertCode(t, status, http.StatusBadRequest, b, 10002)
	if d := dataMap(t, b); d["fields"].(map[string]any)["result_note"] == nil {
		t.Fatalf("fields=%v", d["fields"])
	}
	// report:doing→done,同事务回填源告警 done(双表断言)
	status, b = postJSON(t, r, fmt.Sprintf("/api/v1/todos/%d/status", todoID),
		`{"action":"report","result_note":"已加床并整改"}`)
	assertCode(t, status, http.StatusOK, b, 0)
	d = dataMap(t, b)
	if d["todo_status"] != "done" || d["alert_status"] != "done" {
		t.Fatalf("report data=%v", d)
	}
	if n := qInt(t, tx, `SELECT count(*) FROM ads.todo_order WHERE id=$1 AND todo_status='done' AND result_note='已加床并整改'`, todoID); n != 1 {
		t.Fatalf("todo done 落库不符 count=%d", n)
	}
	if n := qInt(t, tx, `SELECT count(*) FROM ads.alert_event WHERE id=103 AND alert_status='done' AND done_at IS NOT NULL`); n != 1 {
		t.Fatalf("alert done 回填不符 count=%d", n)
	}
	// done 后再变更→33104{current_status:'done'}
	status, b = postJSON(t, r, fmt.Sprintf("/api/v1/todos/%d/status", todoID), `{"action":"accept"}`)
	assertCode(t, status, http.StatusConflict, b, 33104)
	if d := dataMap(t, b); d["current_status"] != "done" {
		t.Fatalf("current_status=%v", d)
	}
	// 审计 from→to 两行
	if n := qInt(t, tx, `SELECT count(*) FROM sys.audit_log WHERE action='todo_status' AND target_type='todo_order' AND target_id=$1`,
		fmt.Sprint(todoID)); n != 2 {
		t.Fatalf("audit todo_status 行数=%d want 2", n)
	}
}

// dept_leader 仅本科室单:跨科→20005,本科室→放行
func TestWriteTodoStatusDeptScope(t *testing.T) {
	r, _ := writeTx(t)
	cross := dispatchOn(t, r, 101, 806) // alert 101 dept=19,承办人 dept=19;dept_leader 属 dept=1
	status, b := postJSON(t, r, fmt.Sprintf("/api/v1/todos/%d/status?role=dept_leader", cross), `{"action":"accept"}`)
	assertCode(t, status, http.StatusForbidden, b, 20005)

	own := dispatchOn(t, r, 103, 459) // dept=1 本科室单
	status, b = postJSON(t, r, fmt.Sprintf("/api/v1/todos/%d/status?role=dept_leader", own), `{"action":"accept"}`)
	assertCode(t, status, http.StatusOK, b, 0)
}

func TestWriteTodoStatusErrors(t *testing.T) {
	r, _ := writeTx(t)
	status, b := postJSON(t, r, "/api/v1/todos/999/status", `{"action":"accept"}`)
	assertCode(t, status, http.StatusNotFound, b, 33101)
	status, b = postJSON(t, r, "/api/v1/todos/1/status", `{"action":"bogus"}`)
	assertCode(t, status, http.StatusBadRequest, b, 10002)
}

// ---- R15 rule toggle ------------------------------------------------------------

func TestWriteRuleToggle(t *testing.T) {
	r, tx := writeTx(t)
	toggleQ := `SELECT count(*) FROM sys.audit_log WHERE action='rule_toggle' AND target_type='alert_rule' AND target_id='BED_OVER_95'`
	toggleBefore := qInt(t, tx, toggleQ)
	status, b := postJSON(t, r, "/api/v1/workbench/settings/rules/BED_OVER_95", `{"enabled":false}`)
	assertCode(t, status, http.StatusOK, b, 0)
	d := dataMap(t, b)
	if d["code"] != "BED_OVER_95" || d["enabled"] != false {
		t.Fatalf("data=%v", d)
	}
	if n := qInt(t, tx, `SELECT count(*) FROM ads.alert_rule WHERE code='BED_OVER_95' AND enabled=false`); n != 1 {
		t.Fatalf("enabled 未翻转 count=%d", n)
	}
	if n := qInt(t, tx, toggleQ); n != toggleBefore+1 {
		t.Fatalf("audit rule_toggle delta=%d want +1", n-toggleBefore)
	}
	// scenario 源行不可切(source='rule' 过滤)→10003;未知 code→10003
	for _, code := range []string{"DEVICE_MAINTAIN", "NO_SUCH"} {
		status, b = postJSON(t, r, "/api/v1/workbench/settings/rules/"+code, `{"enabled":false}`)
		assertCode(t, status, http.StatusNotFound, b, 10003)
	}
	// dept_leader 写阈值→20005(角色闸)
	status, b = postJSON(t, r, "/api/v1/workbench/settings/rules/BED_OVER_95?role=dept_leader", `{"enabled":true}`)
	assertCode(t, status, http.StatusForbidden, b, 20005)
	// enabled 缺→10002;坏 JSON→10006
	status, b = postJSON(t, r, "/api/v1/workbench/settings/rules/BED_OVER_95", `{}`)
	assertCode(t, status, http.StatusBadRequest, b, 10002)
	status, b = postJSON(t, r, "/api/v1/workbench/settings/rules/BED_OVER_95", `{`)
	assertCode(t, status, http.StatusBadRequest, b, 10006)
}

// ---- R16 preferences --------------------------------------------------------------

func TestWritePrefsSave(t *testing.T) {
	r, tx := writeTx(t)
	prefQ := `SELECT count(*) FROM sys.audit_log WHERE action='pref_save' AND target_type='user_pref' AND username='president'`
	prefBefore := qInt(t, tx, prefQ)
	status, b := put(t, r, "/api/v1/workbench/settings/preferences",
		`{"refresh_interval":"15 分钟","alert_sound":false}`)
	assertCode(t, status, http.StatusOK, b, 0)
	d := dataMap(t, b)
	// 回写后完整偏好集:写值生效 + 未写键落契约默认
	if d["refresh_interval"] != "15 分钟" || d["alert_sound"] != false ||
		d["default_range"] != "本月" || d["unit_abbreviation"] != true || d["privacy_mask"] != true {
		t.Fatalf("preferences=%v", d)
	}
	if n := qInt(t, tx, `SELECT count(*) FROM sys.user_pref WHERE user_id=1 AND pref_key='refresh_interval' AND pref_val='900'::jsonb`); n != 1 {
		t.Fatalf("refresh_interval 落库不符 count=%d", n)
	}
	if n := qInt(t, tx, `SELECT count(*) FROM sys.user_pref WHERE user_id=1 AND pref_key='alert_sound' AND pref_val='false'::jsonb`); n != 1 {
		t.Fatalf("alert_sound 落库不符 count=%d", n)
	}
	if n := qInt(t, tx, prefQ); n != prefBefore+1 {
		t.Fatalf("audit pref_save delta=%d want +1", n-prefBefore)
	}
	// upsert 覆写:900→1800
	status, b = put(t, r, "/api/v1/workbench/settings/preferences", `{"refresh_interval":"30 分钟","default_range":"本季"}`)
	assertCode(t, status, http.StatusOK, b, 0)
	d = dataMap(t, b)
	if d["refresh_interval"] != "30 分钟" || d["default_range"] != "本季" || d["alert_sound"] != false {
		t.Fatalf("覆写后 preferences=%v", d)
	}
	if n := qInt(t, tx, `SELECT count(*) FROM sys.user_pref WHERE user_id=1 AND pref_key='refresh_interval'`); n != 1 {
		t.Fatalf("upsert 应仍单行 count=%d", n)
	}
}

func TestWritePrefsErrors(t *testing.T) {
	r, _ := writeTx(t)
	status, b := put(t, r, "/api/v1/workbench/settings/preferences", `{}`)
	assertCode(t, status, http.StatusBadRequest, b, 10001)
	status, b = put(t, r, "/api/v1/workbench/settings/preferences", `{"foo":1}`)
	assertCode(t, status, http.StatusBadRequest, b, 10001)
	status, b = put(t, r, "/api/v1/workbench/settings/preferences", `{"default_range":"下周"}`)
	assertCode(t, status, http.StatusBadRequest, b, 10002)
	if d := dataMap(t, b); d["fields"].(map[string]any)["default_range"] == nil {
		t.Fatalf("fields=%v", d["fields"])
	}
	status, b = put(t, r, "/api/v1/workbench/settings/preferences", `{"alert_sound":"yes"}`)
	assertCode(t, status, http.StatusBadRequest, b, 10002)
	status, b = put(t, r, "/api/v1/workbench/settings/preferences", `{`)
	assertCode(t, status, http.StatusBadRequest, b, 10006)
}

// ---- R10 staff --------------------------------------------------------------------

func TestWriteStaffList(t *testing.T) {
	r, _ := writeTx(t)
	// 科室过滤 + 负责人优先(dept 1 leader_id=482)
	status, b := get(t, r, "/api/v1/staff?dept_id=1")
	assertCode(t, status, http.StatusOK, b, 0)
	var d struct {
		List []map[string]any `json:"list"`
	}
	if err := json.Unmarshal(b.Data, &d); err != nil {
		t.Fatalf("data: %v", err)
	}
	if len(d.List) == 0 {
		t.Fatal("dept_id=1 list 空")
	}
	for i, row := range d.List {
		if row["dept_id"] != float64(1) {
			t.Fatalf("list[%d].dept_id=%v want 1", i, row["dept_id"])
		}
	}
	first := d.List[0]
	if first["is_leader"] != true || first["id"] != float64(482) {
		t.Fatalf("首行=%v want leader 482", first)
	}
	// 不存在科室→空 list 不报错;dept_id 非数→10001
	status, b = get(t, r, "/api/v1/staff?dept_id=999")
	assertCode(t, status, http.StatusOK, b, 0)
	if err := json.Unmarshal(b.Data, &d); err != nil || len(d.List) != 0 {
		t.Fatalf("dept 999 应空 list: %v", string(b.Data))
	}
	status, b = get(t, r, "/api/v1/staff?dept_id=abc")
	assertCode(t, status, http.StatusBadRequest, b, 10001)
	// 缺席→全院在职(非空)
	status, b = get(t, r, "/api/v1/staff")
	assertCode(t, status, http.StatusOK, b, 0)
}
