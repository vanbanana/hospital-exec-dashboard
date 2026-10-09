// PROD-B1 并发正确性实测——克隆库 hospital_edss_w,真实提交(不经回滚 tx,
// 池连接并发才有意义);每用例入场归一 + defer 清场,零残留纪律同 sim_test.go。
// 覆盖:sim/tick 八并发不丢批 · 会话 <6h 滑动续期重签 Cookie 边界 ·
// 同工单并发双 accept 恰一成功 · 登录锁定计数边界(契约 §2.3:15min≥5 次才锁)。
package handler

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/middleware"
	"hospital-edss/internal/repo"
)

// ---- sim/tick 并发 ---------------------------------------------------------

// TestSimTickConcurrent N=8 goroutine 同刻 tick:FOR UPDATE 行锁串行化下
// 推进总分钟数=Σ、job_log SimTick 净增 N 行、无 ErrSimBusy 丢批
// (checkRunning 先于锁——job_log 恒 success 直落,并发下彼此不可见 running)
func TestSimTickConcurrent(t *testing.T) {
	db := writeTestDB(t)
	resetSimClock(t, db) // 入场归一:时钟回 2026-10-28 09:00+08,台账清回 SeedLoader
	defer resetSimClock(t, db)
	r := simRouter(t, db)

	const n = 8
	minutes := []int{5, 10, 15, 20, 25, 30, 35, 40} // Σ=180
	sum := 0
	for _, m := range minutes {
		sum += m
	}
	jobsBefore := qInt(t, db, `SELECT count(*) FROM sim.job_log WHERE job='SimTick'`)
	rowsBefore := qInt(t, db, `SELECT COALESCE(SUM(rows_cnt),0) FROM sim.job_log WHERE job='SimTick'`)

	var wg sync.WaitGroup
	results := make([]envelopeBody, n)
	statuses := make([]int, n)
	start := make(chan struct{})
	for i := 0; i < n; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			<-start // 起跑闸:尽量同刻放行放大锁竞争
			req := httptest.NewRequest(http.MethodPost, "/api/v1/sim/tick",
				strings.NewReader(fmt.Sprintf(`{"minutes":%d}`, minutes[i])))
			w := httptest.NewRecorder()
			r.ServeHTTP(w, req)
			statuses[i] = w.Code
			if err := json.Unmarshal(w.Body.Bytes(), &results[i]); err != nil {
				results[i] = envelopeBody{Code: -1, Message: "unmarshal: " + err.Error()}
			}
		}(i)
	}
	close(start)
	wg.Wait()

	for i := 0; i < n; i++ {
		if statuses[i] != http.StatusOK || results[i].Code != 0 {
			t.Fatalf("tick[%d] status=%d code=%d msg=%q want 200/0(并发不应丢批)",
				i, statuses[i], results[i].Code, results[i].Message)
		}
	}
	// 推进总量 = Σminutes(行锁串行,无 lost update):09:00 + 180min = 12:00
	got := qInt(t, db, `SELECT CAST(EXTRACT(EPOCH FROM (virtual_now - '2026-10-28 09:00:00+08'::timestamptz))/60 AS bigint)
		FROM sim.clock WHERE id=1`)
	if got != int64(sum) {
		t.Fatalf("推进分钟数=%d want %d(Σ 不丢批)", got, sum)
	}
	// 台账:每批次一 job_log 行
	if delta := qInt(t, db, `SELECT count(*) FROM sim.job_log WHERE job='SimTick'`) - jobsBefore; delta != n {
		t.Fatalf("job_log SimTick 净增=%d want %d", delta, n)
	}
	// 各行 rows_cnt 净增=推进总量(批次↔分钟一一对应)
	if rc := qInt(t, db, `SELECT COALESCE(SUM(rows_cnt),0) FROM sim.job_log WHERE job='SimTick'`); rc-rowsBefore != int64(sum) {
		t.Fatalf("rows_cnt 净增=%d want %d", rc-rowsBefore, sum)
	}
}

// ---- 会话滑动续期边界 ---------------------------------------------------------

// concSessionRouter 挂真实 Session 中间件(池连接,续期异步写要能落库)
// + 受保护端点 auth/profile(非 publicPaths 白名单,必经会话解析)
func concSessionRouter(t *testing.T, db *gorm.DB) *gin.Engine {
	t.Helper()
	h := NewContext(db, clock.New(db))
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(func(c *gin.Context) { c.Set("trace_id", "test-trace"); c.Next() })
	r.Use(middleware.Session(db, false))
	r.GET("/api/v1/auth/profile", h.AuthProfile)
	return r
}

// concSessHash 测试令牌→库内 sha256 散列(与登录签发同式)
func concSessHash(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

// seedSession 直插会话行(真实提交——Session 中间件经池解析,回滚 tx 不可见);
// expiresExpr 用 SQL 墙钟表达式(会话过期判定时基=DB now(),repo/auth.go 注)
func seedSession(t *testing.T, db *gorm.DB, token, expiresExpr string) {
	t.Helper()
	err := db.Exec(`INSERT INTO sys.user_session(user_id,token_hash,expires_at)
		VALUES(1, $1, `+expiresExpr+`)`, concSessHash(token)).Error
	if err != nil {
		t.Fatalf("种会话行: %v", err)
	}
}

func delSessions(t *testing.T, db *gorm.DB, tokens ...string) {
	t.Helper()
	for _, tok := range tokens {
		if err := db.Exec(`DELETE FROM sys.user_session WHERE token_hash=$1`, concSessHash(tok)).Error; err != nil {
			t.Fatalf("清会话行: %v", err)
		}
	}
}

func reqWithCookie(t *testing.T, r *gin.Engine, token string) *httptest.ResponseRecorder {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/auth/profile", nil)
	req.AddCookie(&http.Cookie{Name: "edss_sid", Value: token})
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	return w
}

// TestSessionSlidingRenew 契约 §2.3 响应头注 + middleware.Session:
// 剩余 <6h → 重签 Set-Cookie(edss_sid,Max-Age=43200)且异步续期落库;
// ≥6h → 不重签;已过期 → 20002 不重签
func TestSessionSlidingRenew(t *testing.T) {
	db := writeTestDB(t)
	tokRenew, tokFresh, tokExpired := "conctest-renew-b1", "conctest-fresh-b1", "conctest-expired-b1"
	delSessions(t, db, tokRenew, tokFresh, tokExpired) // 防上跑残留
	defer delSessions(t, db, tokRenew, tokFresh, tokExpired)

	seedSession(t, db, tokRenew, `now() + interval '5 hours'`)  // 剩余5h<6h→续期
	seedSession(t, db, tokFresh, `now() + interval '7 hours'`)  // 剩余7h>6h→不续
	seedSession(t, db, tokExpired, `now() - interval '1 hour'`) // 已过期
	r := concSessionRouter(t, db)

	// <6h:放行 + 重签同名 Cookie
	w := reqWithCookie(t, r, tokRenew)
	if w.Code != http.StatusOK {
		t.Fatalf("续期侧 status=%d want 200 body=%s", w.Code, w.Body.String())
	}
	sc := w.Header().Get("Set-Cookie")
	if !strings.HasPrefix(sc, "edss_sid="+tokRenew) || !strings.Contains(sc, "Max-Age=43200") {
		t.Fatalf("Set-Cookie=%q want edss_sid=<同令牌> + Max-Age=43200", sc)
	}
	// 异步续期落库:expires_at → now()+12h(fire-and-forget,有界轮询等其生效)
	renewed := false
	for i := 0; i < 50; i++ {
		if qInt(t, db, `SELECT count(*) FROM sys.user_session
			WHERE token_hash=$1 AND expires_at > now() + interval '11 hours'`, concSessHash(tokRenew)) == 1 {
			renewed = true
			break
		}
		time.Sleep(100 * time.Millisecond)
	}
	if !renewed {
		t.Fatalf("5s 内异步续期未落库(expires_at 未推至 +12h 档)")
	}

	// ≥6h:放行但不重签
	w = reqWithCookie(t, r, tokFresh)
	if w.Code != http.StatusOK {
		t.Fatalf("未到期侧 status=%d want 200 body=%s", w.Code, w.Body.String())
	}
	if sc := w.Header().Get("Set-Cookie"); sc != "" {
		t.Fatalf("剩余≥6h 不应重签,got Set-Cookie=%q", sc)
	}

	// 已过期:20002 且不重签
	w = reqWithCookie(t, r, tokExpired)
	var b envelopeBody
	if err := json.Unmarshal(w.Body.Bytes(), &b); err != nil {
		t.Fatalf("包络反序列化: %v", err)
	}
	if w.Code != http.StatusUnauthorized || b.Code != 20002 {
		t.Fatalf("过期会话 status=%d code=%d want 401/20002", w.Code, b.Code)
	}
	if sc := w.Header().Get("Set-Cookie"); sc != "" {
		t.Fatalf("过期会话不应重签,got Set-Cookie=%q", sc)
	}
}

// ---- 同工单并发双写 accept ------------------------------------------------------

// TestTodoConcurrentAccept 契约 §15.5 状态机串行化断言:
// 对同一 open 工单并发两 accept——恰一 200/open→doing,另一 409/33104 current_status=doing;
// 审计 todo_status 恰一行(仅胜者写)
func TestTodoConcurrentAccept(t *testing.T) {
	db := writeTestDB(t)
	// 自供 open 单:alert 96(done)源单——FK 不校验告警存活态,避开其他用例
	// 活跃的 pending 告警(101/103/104);deadline 远在 virtual_now 之后防惰性清扫误伤
	var todoID int64
	err := db.Raw(`INSERT INTO ads.todo_order
		(alert_id,alert_occurred_at,title,assignee_id,dispatcher_id,deadline,created_at,updated_at)
		SELECT id, occurred_at, 'B1并发接单测试单', 806, 1,
		       '2026-11-30 17:00:00+08','2026-10-28 09:00:00+08','2026-10-28 09:00:00+08'
		FROM ads.alert_event WHERE id=96 RETURNING id`).Scan(&todoID).Error
	if err != nil || todoID <= 0 {
		t.Fatalf("造工单: err=%v id=%d", err, todoID)
	}
	t.Cleanup(func() {
		if err := db.Exec(`DELETE FROM sys.audit_log WHERE action='todo_status'
			AND target_type='todo_order' AND target_id=$1`, fmt.Sprint(todoID)).Error; err != nil {
			t.Errorf("清审计行: %v", err)
		}
		if err := db.Exec(`DELETE FROM ads.todo_order WHERE id=$1`, todoID).Error; err != nil {
			t.Errorf("清工单行: %v", err)
		}
	})

	h := NewWriteHandler(repo.NewWriteRepo(db, clock.New(db)))
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(func(c *gin.Context) {
		c.Set("trace_id", "test-trace")
		c.Set("session_user", middleware.SessionUser{ID: 1, Username: "president", Role: "president"})
		c.Next()
	})
	r.POST("/api/v1/todos/:id/status", h.TodoStatus)

	var wg sync.WaitGroup
	statuses := make([]int, 2)
	bodies := make([]envelopeBody, 2)
	start := make(chan struct{})
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			<-start
			req := httptest.NewRequest(http.MethodPost,
				fmt.Sprintf("/api/v1/todos/%d/status", todoID), strings.NewReader(`{"action":"accept"}`))
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()
			r.ServeHTTP(w, req)
			statuses[i] = w.Code
			if err := json.Unmarshal(w.Body.Bytes(), &bodies[i]); err != nil {
				bodies[i] = envelopeBody{Code: -1, Message: "unmarshal: " + err.Error()}
			}
		}(i)
	}
	close(start)
	wg.Wait()

	// 恰一胜一败:FOR UPDATE OF t 串行化下,后至者读到 doing → StatusConflict
	okN, conflictN := 0, 0
	for i := 0; i < 2; i++ {
		switch {
		case statuses[i] == http.StatusOK && bodies[i].Code == 0:
			okN++
			d := dataMap(t, bodies[i])
			if d["todo_status"] != "doing" {
				t.Fatalf("胜方 todo_status=%v want doing", d["todo_status"])
			}
		case statuses[i] == http.StatusConflict && bodies[i].Code == 33104:
			conflictN++
			d := dataMap(t, bodies[i])
			if d["current_status"] != "doing" {
				t.Fatalf("败方 current_status=%v want doing", d["current_status"])
			}
		default:
			t.Fatalf("req[%d] status=%d code=%d 非胜(200/0)非败(409/33104): %s",
				i, statuses[i], bodies[i].Code, string(bodies[i].Data))
		}
	}
	if okN != 1 || conflictN != 1 {
		t.Fatalf("胜=%d 败=%d want 各1", okN, conflictN)
	}
	if got := qStr(t, db, `SELECT todo_status FROM ads.todo_order WHERE id=$1`, todoID); got != "doing" {
		t.Fatalf("库存态=%q want doing", got)
	}
	if n := qInt(t, db, `SELECT count(*) FROM sys.audit_log
		WHERE action='todo_status' AND target_type='todo_order' AND target_id=$1`,
		fmt.Sprint(todoID)); n != 1 {
		t.Fatalf("audit todo_status 行数=%d want 1(仅胜者落审计)", n)
	}
}

// ---- 登录锁定计数边界 -----------------------------------------------------------

// TestLoginLockoutBoundary 契约 §2.3:15min 窗内 login_fail ≥5 → 下一次起 20104。
// 边界固化:恰 4 次失败时第 5 次仍走口令校验(20101,未锁);满 5 行后第 6 次撞锁 20104。
// (任务书"4 次错→第 5 次锁"与契约阈值差一——以契约为准:第 5 次失败写入第 5 行审计,
// 锁自第 6 次生效;既有 TestLoginLockoutNoSelfPerpetuate 同口径)
// 用 vp_medical 独立账号,in-tx 先清该账号历史 login_fail 行防克隆库残留污染计数窗。
func TestLoginLockoutBoundary(t *testing.T) {
	r, tx := authTx(t)
	if err := tx.Exec(`DELETE FROM sys.audit_log WHERE action='login_fail' AND username='vp_medical'`).Error; err != nil {
		t.Fatalf("清历史失败审计: %v", err)
	}
	for i := 1; i <= 5; i++ {
		_, b := loginRaw(t, r, `{"username":"vp_medical","password":"wrong"}`)
		if b.Code != 20101 {
			t.Fatalf("第%d次错口令 code=%d want 20101(≤4 行时不得提前锁,第5次仍落审计)", i, b.Code)
		}
	}
	if n := qInt(t, tx, `SELECT count(*) FROM sys.audit_log
		WHERE action='login_fail' AND username='vp_medical'`); n != 5 {
		t.Fatalf("login_fail 行数=%d want 5", n)
	}
	// 第 6 次撞锁:20104 且不新增审计(写行会喂计数源自我续锁——契约豁免注)
	_, b := loginRaw(t, r, `{"username":"vp_medical","password":"wrong"}`)
	assertCode(t, http.StatusTooManyRequests, http.StatusTooManyRequests, b, 20104)
	if n := qInt(t, tx, `SELECT count(*) FROM sys.audit_log
		WHERE action='login_fail' AND username='vp_medical'`); n != 5 {
		t.Fatalf("撞锁后 login_fail=%d want 5(不自我续锁)", n)
	}
}
