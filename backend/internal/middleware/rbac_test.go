package middleware

import "testing"

func TestProductionPolicy(t *testing.T) {
	dept := int64(1)
	for _, tc := range []struct {
		name, method, path string
		user               SessionUser
		allowed            bool
	}{
		{"new route denied", "GET", "/api/v1/new", SessionUser{Role: "admin", ScopeType: "all"}, false},
		{"new simulation route denied", "POST", "/api/v1/sim/new", SessionUser{Role: "admin", ScopeType: "all"}, false},
		{"profile cannot be written", "PUT", "/api/v1/auth/profile", SessionUser{Role: "admin", ScopeType: "all"}, false},
		{"unknown role denied", "GET", "/api/v1/auth/profile", SessionUser{Role: "alien", ScopeType: "all"}, false},
		{"department no hospital aggregates", "GET", "/api/v1/workbench/overview", SessionUser{Role: "dept_leader", ScopeType: "dept", DeptID: &dept}, false},
		{"department own tasks", "GET", "/api/v1/todos", SessionUser{Role: "dept_leader", ScopeType: "dept", DeptID: &dept}, true},
		{"department missing id denied", "GET", "/api/v1/todos", SessionUser{Role: "dept_leader", ScopeType: "dept"}, false},
		{"viewer no alert write", "POST", "/api/v1/alerts/:id/ack", SessionUser{Role: "viewer", ScopeType: "all"}, false},
		{"president alert write", "POST", "/api/v1/alerts/:id/ack", SessionUser{Role: "president", ScopeType: "all"}, true},
		{"ops no users", "GET", "/api/v1/workbench/settings/config", SessionUser{Role: "ops_director", ScopeType: "all"}, false},
		{"viewer own preferences", "PUT", "/api/v1/workbench/settings/preferences", SessionUser{Role: "viewer", ScopeType: "all"}, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if got := productionAllowed(tc.method, tc.path, tc.user); got != tc.allowed {
				t.Fatalf("allowed=%v want %v", got, tc.allowed)
			}
		})
	}
}
