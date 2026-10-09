// Session/RBAC 中间件集成测试——全真 router.Build 装配(全局中间件链一并不缺),
// 挂写域克隆库 hospital_edss_w;会话行在测试 tx 内插入,Cleanup 回滚零残留
// (同 write_test.go 纪律:共享库 hospital_edss 绝不写)。
// 覆盖 error-codes §3:20001 无凭证 / 20003 伪造令牌 / 20002 过期会话 /
// 20004 RBAC 角色不符 / publicPaths 白名单放行 / 10004 NoMethod 端到端。
package router

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"sync"
	"testing"

	"github.com/gin-gonic/gin"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
)

var (
	rtDBOnce sync.Once
	rtDBPool *gorm.DB
	rtDBErr  error
)

// routerTestDB 写域克隆库单池(DATABASE_URL_W 可覆写;不可达时 Skip 同 handler 测试纪律)
func routerTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	rtDBOnce.Do(func() {
		dsn := os.Getenv("DATABASE_URL_W")
		if dsn == "" {
			dsn = "postgres://localhost/hospital_edss_w?sslmode=disable"
		}
		db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
		if err != nil {
			rtDBErr = err
			return
		}
		sqlDB, err := db.DB()
		if err != nil {
			rtDBErr = err
			return
		}
		sqlDB.SetMaxOpenConns(8)
		if err := sqlDB.Ping(); err != nil {
			rtDBErr = err
			return
		}
		rtDBPool = db
	})
	if rtDBErr != nil {
		t.Fatalf("postgres 不可达（集成测试必须执行）: %v", rtDBErr)
	}
	return rtDBPool
}

// routerTx 每用例一 tx——Deps.DB 直接挂 tx,中间件与 handler 同事务内可见
// 未提交的会话夹具行,Rollback 后零残留
func routerTx(t *testing.T) (*gin.Engine, *gorm.DB) {
	t.Helper()
	db := routerTestDB(t)
	tx := db.Begin()
	if tx.Error != nil {
		t.Fatalf("begin tx: %v", tx.Error)
	}
	t.Cleanup(func() { tx.Rollback() })
	return Build(&Deps{DB: tx, Clock: clock.New(tx)}), tx
}

// insertSession tx 内插会话行,expires_at=now()+exp(如 '+12 hours'/'-1 hours');
// 返回明文 token(库内只落 sha256——与 ResolveSession 查询同口径)
// 注意:勿造剩余 <6h 的有效会话——会触发滑动续期 goroutine 并发写本 tx(*sql.Tx 非并发安全)
func insertSession(t *testing.T, tx *gorm.DB, userID int64, tag, exp string) string {
	t.Helper()
	token := "rtest-" + tag
	sum := sha256.Sum256([]byte(token))
	if err := tx.Exec(
		`INSERT INTO sys.user_session(user_id,token_hash,expires_at,user_agent)
		 VALUES($1,$2,now()+($3)::interval,'rtest')`,
		userID, hex.EncodeToString(sum[:]), exp).Error; err != nil {
		t.Fatalf("插会话行: %v", err)
	}
	return token
}

type rtEnvelope struct {
	Code    int             `json:"code"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data"`
	TraceID string          `json:"trace_id"`
}

func rtReq(t *testing.T, r *gin.Engine, method, path, token string) (int, rtEnvelope) {
	t.Helper()
	req := httptest.NewRequest(method, path, nil)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var b rtEnvelope
	if err := json.Unmarshal(w.Body.Bytes(), &b); err != nil {
		t.Fatalf("包络反序列化: %v body=%s", err, w.Body.String())
	}
	return w.Code, b
}

func TestSessionMissingAndForged(t *testing.T) {
	r, _ := routerTx(t)
	status, b := rtReq(t, r, http.MethodGet, "/api/v1/todos", "")
	if status != http.StatusUnauthorized || b.Code != 20001 {
		t.Fatalf("无凭证 status=%d code=%d want 401/20001", status, b.Code)
	}
	if b.TraceID == "" {
		t.Fatal("trace_id 缺席(TraceID 中间件应已注入)")
	}
	// 伪造 token:hash 查无行→sess=nil→20003
	status, b = rtReq(t, r, http.MethodGet, "/api/v1/todos", "forged-token")
	if status != http.StatusUnauthorized || b.Code != 20003 {
		t.Fatalf("伪造 token status=%d code=%d want 401/20003", status, b.Code)
	}
}

// expires_at<now() 会话行→20002(tx 内插,Rollback 零残留)
func TestSessionExpired(t *testing.T) {
	r, tx := routerTx(t)
	tok := insertSession(t, tx, 1, "expired", "-1 hours")
	status, b := rtReq(t, r, http.MethodGet, "/api/v1/todos", tok)
	if status != http.StatusUnauthorized || b.Code != 20002 {
		t.Fatalf("过期会话 status=%d code=%d want 401/20002", status, b.Code)
	}
}

// dept_leader(种子 id=3)会话打 settings/config 管理面→20004;
// president(id=1)对照放行→200(证 403 是角色闸而非认证失败)
func TestSessionRBAC(t *testing.T) {
	r, tx := routerTx(t)
	dl := insertSession(t, tx, 3, "leader", "+12 hours")
	status, b := rtReq(t, r, http.MethodGet, "/api/v1/workbench/settings/config", dl)
	if status != http.StatusForbidden || b.Code != 20004 {
		t.Fatalf("dept_leader status=%d code=%d want 403/20004", status, b.Code)
	}
	pr := insertSession(t, tx, 1, "president", "+12 hours")
	status, b = rtReq(t, r, http.MethodGet, "/api/v1/workbench/settings/config", pr)
	if status != http.StatusOK || b.Code != 0 {
		t.Fatalf("president status=%d code=%d want 200/0", status, b.Code)
	}
}

// publicPaths 白名单:screen/snapshot 无会话→200;
// NoMethod 端到端:有效会话打已注册路径的错误方法→405+10004(HandleMethodNotAllowed)
func TestSessionWhitelistAndNoMethod(t *testing.T) {
	r, tx := routerTx(t)
	status, b := rtReq(t, r, http.MethodGet, "/api/v1/screen/snapshot", "")
	if status != http.StatusOK || b.Code != 0 {
		t.Fatalf("白名单端点 status=%d code=%d want 200/0", status, b.Code)
	}
	pr := insertSession(t, tx, 1, "president", "+12 hours")
	status, b = rtReq(t, r, http.MethodPost, "/api/v1/todos", pr)
	if status != http.StatusMethodNotAllowed || b.Code != 10004 {
		t.Fatalf("错误方法 status=%d code=%d want 405/10004", status, b.Code)
	}
}
