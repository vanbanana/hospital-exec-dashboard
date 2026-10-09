// 演示模式保留原角色矩阵；生产模式显式授权端点并校验数据范围，未登记路由拒绝。
package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/envelope"
)

// rbacMatrix "METHOD path" → 允许角色集
var rbacMatrix = map[string]map[string]struct{}{
	"GET /api/v1/workbench/settings/config": {"admin": {}, "president": {}},
	// 契约 §16:sim 操作人校验 admin 限定,会话机制(§2.3)落地后生效——EA 落地故启用
	"GET /api/v1/sim/clock":  {"admin": {}},
	"POST /api/v1/sim/clock": {"admin": {}},
	"POST /api/v1/sim/tick":  {"admin": {}},
	"POST /api/v1/sim/reset": {"admin": {}},
	"GET /api/v1/sim/jobs":   {"admin": {}},
}

// rbacCheck 由 Session 在 c.Set("session_user") 后调用;false=已回 20004 并 Abort
func rbacCheck(c *gin.Context, u SessionUser) bool {
	if strict, _ := c.Get("demo_role_switch"); strict == false {
		if c.FullPath() != "" && !productionAllowed(c.Request.Method, c.FullPath(), u) {
			code := envelope.CodeRoleDeny
			if u.ScopeType != "all" {
				code = envelope.CodeScopeDeny
			}
			deny(c, http.StatusForbidden, code, "无权访问该数据范围")
			return false
		}
	}
	roles, ok := rbacMatrix[c.Request.Method+" "+c.Request.URL.Path]
	if !ok {
		return true
	}
	if _, ok := roles[u.Role]; ok {
		return true
	}
	deny(c, http.StatusForbidden, envelope.CodeRoleDeny, "无权访问该资源")
	return false
}

// A route absent from the production policy remains denied when new endpoints are registered.
func productionAllowed(method, path string, u SessionUser) bool {
	known := u.Role == "admin" || u.Role == "president" || u.Role == "ops_director" || u.Role == "dept_leader" || u.Role == "viewer"
	if !known {
		return false
	}
	if path == "/api/v1/auth/profile" {
		return method == "GET"
	}
	if path == "/api/v1/workbench/settings/preferences" {
		return method == "GET" || method == "PUT"
	}
	all := u.ScopeType == "all" && u.Role != "dept_leader"
	dept := u.ScopeType == "dept" && u.DeptID != nil && *u.DeptID > 0
	if path == "/api/v1/todos" || path == "/api/v1/staff" {
		return method == "GET" && (all || dept)
	}
	if path == "/api/v1/todos/:id/status" {
		return method == "POST" && (u.Role == "admin" || u.Role == "president" || u.Role == "ops_director" || u.Role == "dept_leader") && (all || dept)
	}
	if !all {
		return false
	}
	if path == "/api/v1/workbench/settings/config" {
		return method == "GET" && (u.Role == "admin" || u.Role == "president")
	}
	if path == "/api/v1/alerts/:id/ack" || path == "/api/v1/alerts/:id/dispatch" || path == "/api/v1/alerts/:id/close" || path == "/api/v1/workbench/settings/rules/:code" {
		return method == "POST" && u.Role != "viewer"
	}
	if _, exists := rbacMatrix[method+" "+path]; exists {
		return u.Role == "admin"
	}
	for _, p := range []string{"screen/snapshot", "workbench/home/kpis", "workbench/home/trends", "workbench/home/top10", "workbench/home/indicators", "workbench/home/progress", "workbench/home/alerts", "workbench/home/notices", "workbench/overview", "workbench/medical", "workbench/operations", "workbench/compare", "workbench/hr", "workbench/research", "workbench/patient", "workbench/quality", "workbench/assets", "workbench/topics"} {
		if path == "/api/v1/"+p {
			return method == "GET"
		}
	}
	return false
}

func AllowedPages(u SessionUser, demo bool) []string {
	pages := []string{}
	for _, p := range []string{"", "overview", "medical", "operations", "hr", "research", "patient", "quality", "assets", "compare", "topics", "settings"} {
		endpoint := p
		if p == "" {
			endpoint = "home/kpis"
		}
		if p == "settings" {
			endpoint = "settings/config"
		}
		if demo || productionAllowed("GET", "/api/v1/workbench/"+endpoint, u) {
			suffix := ""
			if p != "" {
				suffix = "/" + p
			}
			pages = append(pages, "/workbench"+suffix)
		}
	}
	if demo || productionAllowed("GET", "/api/v1/todos", u) {
		pages = append(pages, "/workbench/tasks")
	}
	if demo || productionAllowed("GET", "/api/v1/workbench/settings/preferences", u) {
		pages = append(pages, "/workbench/preferences")
	}
	return pages
}
