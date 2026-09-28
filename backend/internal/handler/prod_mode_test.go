// PROD-P1 生产语义闸测试(DEMO_ROLE_SWITCH=0,契约 §2.1 演进注·生产形态)——
// package handler_test 外部包方可 import router(同 screen_test.go 约束):
// 写侧异名闸在 router 中间件层,本包内测直挂 handler 够不到,必须 Build 全真装配。
// 会话夹具=tx 内 sys.user_session 行,Cleanup Rollback 零残留;写域克隆库 hospital_edss_w。
package handler_test

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"testing"

	"github.com/gin-gonic/gin"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/router"
)

var (
	prodDBOnce sync.Once
	prodDBPool *gorm.DB
	prodDBErr  error
)

// prodTestDB 写域克隆库单池(同 router_test.go/write_test.go 纪律:共享库绝不写)
func prodTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	prodDBOnce.Do(func() {
		dsn := os.Getenv("DATABASE_URL_W")
		if dsn == "" {
			dsn = "postgres://localhost/hospital_edss_w?sslmode=disable"
		}
		db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
		if err != nil {
			prodDBErr = err
			return
		}
		sqlDB, err := db.DB()
		if err != nil {
			prodDBErr = err
			return
		}
		sqlDB.SetMaxOpenConns(8)
		if err := sqlDB.Ping(); err != nil {
			prodDBErr = err
			return
		}
		prodDBPool = db
	})
	if prodDBErr != nil {
		t.Skipf("postgres 不可达: %v", prodDBErr)
	}
	return prodDBPool
}

// prodRouter DEMO_ROLE_SWITCH=0 全真装配:t.Setenv 先于 Build(env 在装配时读取);
// 每用例一 tx,Rollback 零残留
func prodRouter(t *testing.T) (*gin.Engine, *gorm.DB) {
	t.Helper()
	t.Setenv("DEMO_ROLE_SWITCH", "0")
	db := prodTestDB(t)
	tx := db.Begin()
	if tx.Error != nil {
		t.Fatalf("begin tx: %v", tx.Error)
	}
	t.Cleanup(func() { tx.Rollback() })
	return router.Build(&router.Deps{DB: tx, Clock: clock.New(tx)}), tx
}

// prodSession tx 内插会话行(有效期 +12h——勿造 <6h 会话,会触发滑动续期
// goroutine 并发写本 tx,*sql.Tx 非并发安全);返回明文 token
func prodSession(t *testing.T, tx *gorm.DB, userID int64) string {
	t.Helper()
	token := "prod-" + strings.ReplaceAll(t.Name(), "/", "-")
	sum := sha256.Sum256([]byte(token))
	if err := tx.Exec(
		`INSERT INTO sys.user_session(user_id,token_hash,expires_at,user_agent)
		 VALUES($1,$2,now()+interval '12 hours','ptest')`,
		userID, hex.EncodeToString(sum[:])).Error; err != nil {
		t.Fatalf("插会话行: %v", err)
	}
	return token
}

type prodEnvelope struct {
	Code int             `json:"code"`
	Data json.RawMessage `json:"data"`
}

func prodReq(t *testing.T, r *gin.Engine, method, path, token, body string) (int, prodEnvelope) {
	t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var b prodEnvelope
	if err := json.Unmarshal(w.Body.Bytes(), &b); err != nil {
		t.Fatalf("包络反序列化: %v body=%s", err, w.Body.String())
	}
	return w.Code, b
}

type prodAuthData struct {
	User struct {
		Username string `json:"username"`
	} `json:"user"`
	AvailableRoles []struct {
		Role string `json:"role"`
	} `json:"available_roles"`
}

// §2.1 演进注 a/b:profile available_roles 收敛自身一档;?role= 异名按忽略(等效自回显)
func TestProdProfileRolesCollapsed(t *testing.T) {
	r, tx := prodRouter(t)
	tok := prodSession(t, tx, 1) // president(种子 id=1)

	status, b := prodReq(t, r, http.MethodGet, "/api/v1/auth/profile", tok, "")
	if status != http.StatusOK || b.Code != 0 {
		t.Fatalf("profile status=%d code=%d want 200/0", status, b.Code)
	}
	var d prodAuthData
	if err := json.Unmarshal(b.Data, &d); err != nil {
		t.Fatalf("data 反序列化: %v", err)
	}
	if d.User.Username != "president" {
		t.Fatalf("user.username=%q want president", d.User.Username)
	}
	if len(d.AvailableRoles) != 1 || d.AvailableRoles[0].Role != "president" {
		t.Fatalf("available_roles=%+v want 仅 president 一档", d.AvailableRoles)
	}

	// ?role=ops_director 异名→忽略:仍回显会话自身,名录仍一档
	status, b = prodReq(t, r, http.MethodGet, "/api/v1/auth/profile?role=ops_director", tok, "")
	if status != http.StatusOK || b.Code != 0 {
		t.Fatalf("profile?role= status=%d code=%d want 200/0", status, b.Code)
	}
	if err := json.Unmarshal(b.Data, &d); err != nil {
		t.Fatalf("data 反序列化: %v", err)
	}
	if d.User.Username != "president" || len(d.AvailableRoles) != 1 {
		t.Fatalf("异名 ?role= 未被忽略: user=%q roles=%+v", d.User.Username, d.AvailableRoles)
	}
}

// §2.1 演进注 c:写侧 ?role= 异名一律 403/20004(即便 president 会话——生产态关闭一切
// 演示切换);同值自指放行
func TestProdWriteRoleDeny(t *testing.T) {
	r, tx := prodRouter(t)
	tok := prodSession(t, tx, 1) // president

	status, b := prodReq(t, r, http.MethodPost, "/api/v1/alerts/101/ack?role=ops_director", tok, "{}")
	if status != http.StatusForbidden || b.Code != 20004 {
		t.Fatalf("异名写 status=%d code=%d want 403/20004", status, b.Code)
	}

	status, b = prodReq(t, r, http.MethodPost, "/api/v1/alerts/101/ack?role=president", tok, "{}")
	if status != http.StatusOK || b.Code != 0 {
		t.Fatalf("同值自指写 status=%d code=%d want 200/0", status, b.Code)
	}
}
