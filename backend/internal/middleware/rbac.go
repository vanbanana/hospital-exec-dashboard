// EA RBAC 端点级角色矩阵(r-auth C3)——静态表不进库(21 端点入库管理属过度设计)。
// 默认放行;命中限制行且角色不在列 → 20004。唯一限制项=settings/config 管理面
// (全量用户/阈值/数据源下发,演示可讲的权限差异落点)。
package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/envelope"
)

// rbacMatrix "METHOD path" → 允许角色集
var rbacMatrix = map[string]map[string]struct{}{
	"GET /api/v1/workbench/settings/config": {"admin": {}, "president": {}},
}

// rbacCheck 由 Session 在 c.Set("session_user") 后调用;false=已回 20004 并 Abort
func rbacCheck(c *gin.Context, u SessionUser) bool {
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
