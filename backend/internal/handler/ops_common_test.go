// E2 handler 测试基座:真实库集成测试(无 DATABASE_URL 时 Skip;库是本工程唯一事实源)
// 注:不引 router.Build 防 handler→router→handler 循环;此处逐路由复刻 register_ops.go 挂载
package handler

import (
	"net/http/httptest"
	"os"
	"testing"

	"github.com/gin-gonic/gin"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/middleware"
)

func newTestEngine(t *testing.T) *gin.Engine {
	t.Helper()
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://localhost/hospital_edss?sslmode=disable"
	}
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Skipf("db unavailable: %v", err)
	}
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(middleware.TraceID(), middleware.Recovery())
	h := NewOpsHandler(db, clock.New(db))
	r.GET("/api/v1/workbench/overview", h.Overview)
	r.GET("/api/v1/workbench/medical", h.Medical)
	r.GET("/api/v1/workbench/operations", h.Operations)
	r.GET("/api/v1/workbench/compare", h.Compare)
	return r
}

// get 发请求并断言 HTTP 状态码,返回原始 body
func getOps(t *testing.T, r *gin.Engine, path string, wantStatus int) string {
	t.Helper()
	w := httptest.NewRecorder()
	req := httptest.NewRequest("GET", path, nil)
	r.ServeHTTP(w, req)
	if w.Code != wantStatus {
		t.Fatalf("GET %s: status %d, want %d; body=%s", path, w.Code, wantStatus, w.Body.String())
	}
	return w.Body.String()
}
