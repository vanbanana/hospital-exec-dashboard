package handler_test

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"testing"
)

func TestDepartmentReadScopeAndMask(t *testing.T) {
	r, tx := prodRouter(t)
	if err := tx.Exec(`INSERT INTO ads.todo_order(alert_id,alert_occurred_at,title,assignee_id,dispatcher_id,deadline,created_at,updated_at)
 SELECT e.id,e.occurred_at,'scope fixture',CASE WHEN e.id=96 THEN 806 ELSE 459 END,1,c.virtual_now+interval '1 day',c.virtual_now,c.virtual_now FROM ads.alert_event e CROSS JOIN sim.clock c WHERE e.id IN (96,97)`).Error; err != nil {
		t.Fatal(err)
	}
	// Even a stored preference disabling masking cannot relax a nonmanager's policy.
	if err := tx.Exec(`INSERT INTO sys.user_pref(user_id,pref_key,pref_val,updated_at) VALUES(3,'privacy_mask','false','2026-10-28 09:00:00+08') ON CONFLICT(user_id,pref_key) DO UPDATE SET pref_val='false'`).Error; err != nil {
		t.Fatal(err)
	}
	tok := prodSession(t, tx, 3)
	for _, path := range []string{"/api/v1/workbench/overview", "/api/v1/workbench/hr", "/api/v1/staff?dept_id=19"} {
		status, b := prodReq(t, r, http.MethodGet, path, tok, "")
		if status != 403 || b.Code != 20005 {
			t.Fatalf("%s status=%d code=%d", path, status, b.Code)
		}
	}
	status, b := prodReq(t, r, http.MethodGet, "/api/v1/staff", tok, "")
	if status != 200 || b.Code != 0 {
		t.Fatalf("staff status=%d code=%d", status, b.Code)
	}
	var staff struct {
		List []struct {
			Name   string `json:"name"`
			DeptID int64  `json:"dept_id"`
		}
	}
	if err := json.Unmarshal(b.Data, &staff); err != nil {
		t.Fatal(err)
	}
	if len(staff.List) == 0 {
		t.Fatal("no own-department staff returned")
	}
	for _, s := range staff.List {
		if s.DeptID != 1 || !strings.HasSuffix(s.Name, "**") {
			t.Fatalf("unauthorized staff: %+v", s)
		}
	}
	status, b = prodReq(t, r, http.MethodGet, "/api/v1/todos?size=100", tok, "")
	if status != 200 || b.Code != 0 {
		t.Fatalf("todos status=%d code=%d", status, b.Code)
	}
	var tasks struct {
		List []struct {
			Dept string `json:"dept_name"`
			Name string `json:"assignee_name"`
		}
		Total int64
	}
	if err := json.Unmarshal(b.Data, &tasks); err != nil {
		t.Fatal(err)
	}
	if len(tasks.List) != 1 {
		t.Fatalf("own-department fixture missing: %d rows", len(tasks.List))
	}
	for _, row := range tasks.List {
		if row.Dept != "骨科" || !strings.HasSuffix(row.Name, "**") {
			t.Fatalf("cross-department row: %+v", row)
		}
	}
	var count int64
	if err := tx.Raw(`SELECT count(*) FROM ads.todo_order t JOIN dim.staff s ON s.id=t.assignee_id WHERE s.dept_id=1`).Scan(&count).Error; err != nil {
		t.Fatal(err)
	}
	if tasks.Total != count {
		t.Fatalf("total=%d scoped SQL count=%d", tasks.Total, count)
	}
	status, b = prodReq(t, r, http.MethodPut, "/api/v1/workbench/settings/preferences", tok, `{"refresh_interval":"15 分钟"}`)
	if status != 200 || b.Code != 0 {
		t.Fatalf("own preferences denied: %d/%d", status, b.Code)
	}
	var denied int64
	if err := tx.Raw(`SELECT count(*) FROM sys.audit_log WHERE action='access_denied' AND user_id=3`).Scan(&denied).Error; err != nil {
		t.Fatal(err)
	}
	if denied < 3 {
		t.Fatalf("missing denial audit: %d", denied)
	}
}

func TestPrivateScreenRequiresIdentity(t *testing.T) {
	t.Setenv("SCREEN_PUBLIC", "0")
	r, tx := prodRouter(t)
	for _, tc := range []struct {
		token  string
		status int
	}{{"", 401}, {prodSession(t, tx, 3), 403}, {prodSession(t, tx, 1), 200}} {
		status, _ := prodReq(t, r, http.MethodGet, "/api/v1/screen/snapshot", tc.token, "")
		if status != tc.status {
			t.Fatalf("screen status=%d want %d", status, tc.status)
		}
	}
}

func TestDatabaseRejectsUnknownRole(t *testing.T) {
	_, tx := prodRouter(t)
	if err := tx.Exec(`UPDATE sys."user" SET role='unregistered_role' WHERE id=3`).Error; err == nil {
		t.Fatal("unknown role accepted by database")
	}
}

func TestAuthorizedWorkflow(t *testing.T) {
	r, tx := prodRouter(t)
	if err := tx.Exec(`UPDATE ads.alert_event SET dept_id=1 WHERE id=103`).Error; err != nil {
		t.Fatal(err)
	}
	president := prodSession(t, tx, 1)
	department := prodSession(t, tx, 3)
	status, b := prodReq(t, r, http.MethodPost, "/api/v1/alerts/103/dispatch", president, `{"assignee_id":459,"deadline":"2026-10-30T09:00:00+08:00","title":"完整闭环验证"}`)
	if status != 200 || b.Code != 0 {
		t.Fatalf("dispatch %d/%d", status, b.Code)
	}
	var dispatched struct {
		TodoID int64 `json:"todo_id"`
	}
	if err := json.Unmarshal(b.Data, &dispatched); err != nil {
		t.Fatal(err)
	}
	path := fmt.Sprintf("/api/v1/todos/%d/status", dispatched.TodoID)
	for _, body := range []string{`{"action":"accept"}`, `{"action":"report","result_note":"整改完成"}`} {
		status, b = prodReq(t, r, http.MethodPost, path, department, body)
		if status != 200 || b.Code != 0 {
			t.Fatalf("transition %d/%d", status, b.Code)
		}
	}
	status, b = prodReq(t, r, http.MethodPost, path, department, `{"action":"report","result_note":"重复办结"}`)
	if status != 409 || b.Code != 33104 {
		t.Fatalf("repeat transition %d/%d", status, b.Code)
	}
	var state string
	if err := tx.Raw(`SELECT alert_status FROM ads.alert_event WHERE id=103`).Scan(&state).Error; err != nil {
		t.Fatal(err)
	}
	if state != "done" {
		t.Fatalf("alert state=%s", state)
	}
	var audit int64
	if err := tx.Raw(`SELECT count(*) FROM sys.audit_log WHERE action='todo_status' AND user_id=3`).Scan(&audit).Error; err != nil {
		t.Fatal(err)
	}
	if audit != 2 {
		t.Fatalf("transition audits=%d want 2", audit)
	}
}
