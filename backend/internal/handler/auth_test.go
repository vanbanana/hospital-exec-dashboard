// P3-EA 认证端点测试——实库断言,与 write_test.go 同基座(克隆库 hospital_edss_w,
// 每用例 tx 包裹 Rollback 零残留)。覆盖契约 §2.3/§2.4 全分支:
// 登录成功(会话行+审计+Cookie)、20101×2、20102 banned(审计 reason)、
// 20104 锁定(审计行不自我续锁)、logout 吊销+幂等、写侧 ?role= 越权闸。
package handler

import (
	"encoding/json"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"

	"gorm.io/gorm"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/middleware"
	"hospital-edss/internal/repo"
)

// authTx 每用例一 tx——同 writeTx 骨架,路由仅挂 auth 两端点
func authTx(t *testing.T) (*gin.Engine, *gorm.DB) {
	t.Helper()
	db := writeTestDB(t)
	tx := db.Begin()
	if tx.Error != nil {
		t.Fatalf("begin tx: %v", tx.Error)
	}
	t.Cleanup(func() { tx.Rollback() })
	h := NewAuth(tx, clock.New(tx))
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(func(c *gin.Context) { c.Set("trace_id", "test-trace"); c.Next() })
	r.POST("/api/v1/auth/login", h.Login)
	r.POST("/api/v1/auth/logout", h.Logout)
	return r, tx
}

// loginRaw 发登录请求,保留 recorder 以取 Set-Cookie
func loginRaw(t *testing.T, r *gin.Engine, body string) (*httptest.ResponseRecorder, envelopeBody) {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/login", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var b envelopeBody
	if err := json.Unmarshal(w.Body.Bytes(), &b); err != nil {
		t.Fatalf("包络反序列化: %v body=%s", err, w.Body.String())
	}
	return w, b
}

// cookieToken 从 Set-Cookie 头解析 edss_sid 值
func cookieToken(t *testing.T, w *httptest.ResponseRecorder) string {
	t.Helper()
	sc := w.Header().Get("Set-Cookie")
	if !strings.HasPrefix(sc, "edss_sid=") {
		t.Fatalf("Set-Cookie=%q 缺 edss_sid", sc)
	}
	tok := strings.SplitN(strings.TrimPrefix(sc, "edss_sid="), ";", 2)[0]
	if tok == "" {
		t.Fatalf("edss_sid 为空 Set-Cookie=%q", sc)
	}
	return tok
}

func TestLoginSuccess(t *testing.T) {
	r, tx := authTx(t)
	w, b := loginRaw(t, r, `{"username":"president","password":"Edss@2026"}`)
	assertCode(t, w.Code, http.StatusOK, b, 0)
	d := dataMap(t, b)
	u, _ := d["user"].(map[string]any)
	if u["username"] != "president" || d["system_date"] == "" {
		t.Fatalf("data=%v", d)
	}
	tok := cookieToken(t, w)
	// 会话行落库(sha256 散列非明文) + login 审计——断言锚本次会话行,不数全局(克隆库或带基线审计)
	sum := sha256.Sum256([]byte(tok))
	hash := hex.EncodeToString(sum[:])
	if n := qInt(t, tx, `SELECT count(*) FROM sys.user_session WHERE user_id=1 AND token_hash=$1 AND revoked_at IS NULL`, hash); n != 1 {
		t.Fatalf("本次会话行数=%d want 1", n)
	}
	if n := qInt(t, tx, `SELECT count(*) FROM sys.user_session WHERE token_hash=$1`, tok); n != 0 {
		t.Fatalf("token 明文落库——应为 sha256 散列")
	}
	if n := qInt(t, tx, `SELECT count(*) FROM sys.audit_log WHERE action='login' AND username='president' AND detail IS NULL`); n < 1 {
		t.Fatalf("audit login 行数=%d want >=1", n)
	}
	// HttpOnly 旗标必在
	if !strings.Contains(w.Header().Get("Set-Cookie"), "HttpOnly") {
		t.Fatalf("Set-Cookie 缺 HttpOnly: %q", w.Header().Get("Set-Cookie"))
	}
}

func TestLoginBadUserAndPassword(t *testing.T) {
	r, tx := authTx(t)
	// 未知用户名 → 20101,审计 reason=bad_user(user_id NULL)
	_, b := loginRaw(t, r, `{"username":"ghost","password":"x"}`)
	if b.Code != 20101 {
		t.Fatalf("code=%v want 20101", b.Code)
	}
	// 错密 → 20101,审计 reason=bad_password
	_, b = loginRaw(t, r, `{"username":"ops_director","password":"wrong"}`)
	if b.Code != 20101 {
		t.Fatalf("code=%v want 20101", b.Code)
	}
	if n := qInt(t, tx, `SELECT count(*) FROM sys.audit_log WHERE action='login_fail' AND username='ghost' AND detail->>'reason'='bad_user'`); n != 1 {
		t.Fatalf("bad_user 审计行数=%d want 1", n)
	}
	if n := qInt(t, tx, `SELECT count(*) FROM sys.audit_log WHERE action='login_fail' AND username='ops_director' AND detail->>'reason'='bad_password'`); n != 1 {
		t.Fatalf("bad_password 审计行数=%d want 1", n)
	}
}

func TestLoginBannedAudited(t *testing.T) {
	r, tx := authTx(t)
	if err := tx.Exec(`UPDATE sys."user" SET user_status=0 WHERE id=7`).Error; err != nil {
		t.Fatalf("停用夹具: %v", err)
	}
	_, b := loginRaw(t, r, `{"username":"fin_director","password":"Fin@123"}`)
	assertCode(t, http.StatusForbidden, http.StatusForbidden, b, 20102)
	if n := qInt(t, tx, `SELECT count(*) FROM sys.audit_log WHERE action='login_fail' AND username='fin_director' AND detail->>'reason'='banned' AND user_id=7`); n != 1 {
		t.Fatalf("banned 审计行数=%d want 1(契约 §2.3 成功/失败均写审计)", n)
	}
}

func TestLoginLockoutNoSelfPerpetuate(t *testing.T) {
	r, tx := authTx(t)
	for i := 0; i < 5; i++ {
		_, b := loginRaw(t, r, `{"username":"med_director","password":"wrong"}`)
		if b.Code != 20101 {
			t.Fatalf("第%d次 code=%v want 20101", i+1, b.Code)
		}
	}
	if n := qInt(t, tx, `SELECT count(*) FROM sys.audit_log WHERE action='login_fail' AND username='med_director'`); n != 5 {
		t.Fatalf("前置 login_fail=%d want 5", n)
	}
	// 第 6 次撞锁 → 20104 且审计行数不变(写入会喂计数源自我续锁——契约 §2.3 豁免注)
	_, b := loginRaw(t, r, `{"username":"med_director","password":"wrong"}`)
	assertCode(t, http.StatusTooManyRequests, http.StatusTooManyRequests, b, 20104)
	if n := qInt(t, tx, `SELECT count(*) FROM sys.audit_log WHERE action='login_fail' AND username='med_director'`); n != 5 {
		t.Fatalf("撞锁后 login_fail=%d want 5(不应新增)", n)
	}
	// 锁定态下正确口令同样 20104(锁定先于 bcrypt)
	_, b = loginRaw(t, r, `{"username":"med_director","password":"Med@123"}`)
	if b.Code != 20104 {
		t.Fatalf("锁定期正确口令 code=%v want 20104", b.Code)
	}
}

func TestLogoutRevokeAndIdempotent(t *testing.T) {
	r, tx := authTx(t)
	w, b := loginRaw(t, r, `{"username":"ops_director","password":"Edss@2026"}`)
	assertCode(t, w.Code, http.StatusOK, b, 0)
	tok := cookieToken(t, w)
	// Bearer 吊销
	req := httptest.NewRequest(http.MethodPost, "/api/v1/auth/logout", nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	w2 := httptest.NewRecorder()
	r.ServeHTTP(w2, req)
	sum := sha256.Sum256([]byte(tok))
	if n := qInt(t, tx, `SELECT count(*) FROM sys.user_session WHERE token_hash=$1 AND revoked_at IS NULL`, hex.EncodeToString(sum[:])); n != 0 {
		t.Fatalf("吊销后本次会话仍活 n=%d", n)
	}
	// 无凭证再调 → 幂等 code=0
	req = httptest.NewRequest(http.MethodPost, "/api/v1/auth/logout", nil)
	w3 := httptest.NewRecorder()
	r.ServeHTTP(w3, req)
	var b3 envelopeBody
	if err := json.Unmarshal(w3.Body.Bytes(), &b3); err != nil {
		t.Fatalf("logout 包络: %v", err)
	}
	assertCode(t, w3.Code, http.StatusOK, b3, 0)
}

// ---- ?role= 越权演示切换闸(契约 §15 头部:异名切换限 admin/president 会话) ----

func writeTxWithSession(t *testing.T, su middleware.SessionUser) (*gin.Engine, *gorm.DB) {
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
	r.Use(func(c *gin.Context) {
		c.Set("trace_id", "test-trace")
		c.Set("session_user", su)
		c.Next()
	})
	r.POST("/api/v1/alerts/:id/ack", h.AlertAck)
	return r, tx
}

func TestRoleSwitchGate(t *testing.T) {
	// dept_leader 会话 + ?role=president → 20005(异名演示切换限 admin/president)
	r, _ := writeTxWithSession(t, middleware.SessionUser{ID: 3, Username: "dept_leader", Role: "dept_leader"})
	status, b := postJSON(t, r, "/api/v1/alerts/101/ack?role=president", "{}")
	assertCode(t, status, http.StatusForbidden, b, 20005)
	// 同值自指 ?role=dept_leader → 放行(前端对演示账号恒传参)
	status, b = postJSON(t, r, "/api/v1/alerts/101/ack?role=dept_leader", "{}")
	assertCode(t, status, http.StatusOK, b, 0)
	// president 会话异名切换 → 放行
	r2, _ := writeTxWithSession(t, middleware.SessionUser{ID: 1, Username: "president", Role: "president"})
	status, b = postJSON(t, r2, "/api/v1/alerts/103/ack?role=dept_leader", "{}")
	assertCode(t, status, http.StatusOK, b, 0)
}
