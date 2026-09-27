// Context 上下文域端点(契约 §2):auth/profile · hospital/profile
package handler

import (
	"encoding/json"
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

type Context struct {
	db  *gorm.DB
	clk *clock.Source
}

func NewContext(db *gorm.DB, clk *clock.Source) *Context {
	return &Context{db: db, clk: clk}
}

// §2.1 出参镜像 src/api/types.ts AuthProfileResp
type authUser struct {
	ID       int64  `json:"id"`
	Username string `json:"username"`
	RealName string `json:"real_name"`
	Title    string `json:"title"`
	DeptID   *int64 `json:"dept_id"`
	DeptName string `json:"dept_name"`
	Avatar   string `json:"avatar"`
	Role     string `json:"role"`
}

type roleOption struct {
	Role  string `json:"role"`
	Name  string `json:"name"`
	Scope string `json:"scope"`
}

type authProfileResp struct {
	User           authUser     `json:"user"`
	AvailableRoles []roleOption `json:"available_roles"`
	SystemDate     string       `json:"system_date"`
	Weekday        string       `json:"weekday"`
}

// §2.2 出参镜像 HospitalProfileResp;缺 dict 键给零值(空串/空数组),不报错
type hospitalProfileResp struct {
	Name        string   `json:"name"`
	EnglishName string   `json:"english_name"`
	Level       string   `json:"level"`
	Motto       []string `json:"motto"`
	Slogans     []string `json:"slogans"`
	Pillars     []string `json:"pillars"`
}

// AuthProfile GET /api/v1/auth/profile(契约 §2.1);?role= 值为演示账号 username
func (h *Context) AuthProfile(c *gin.Context) {
	role := c.Query("role")
	if role == "" { // 缺省与 ?role= 空值同按 president 处理(与 mock 行为一致)
		role = "president"
	}
	switch role {
	case "president", "ops_director", "dept_leader":
	default:
		envelope.InvalidArg(c, "role", "非法角色")
		return
	}

	ctx := c.Request.Context()
	u, err := repo.FindContextUser(ctx, h.db, role)
	if err != nil || u == nil { // 0 行=演示账号被清,属数据异常非参数错
		failInternal(c)
		return
	}
	demos, err := repo.ListDemoUsers(ctx, h.db)
	if err != nil {
		failInternal(c)
		return
	}
	today, err := h.clk.Today(ctx)
	if err != nil {
		failInternal(c)
		return
	}

	resp := authProfileResp{
		User: authUser{
			ID:       u.ID,
			Username: u.Username,
			RealName: u.RealName,
			Title:    u.JobTitle,
			DeptID:   jsonDeptID(u.DeptID),
			DeptName: u.DeptName,
			Avatar:   u.Avatar,
			Role:     u.Role,
		},
		AvailableRoles: make([]roleOption, 0, len(demos)),
		SystemDate:     today.Format("2006-01-02"),
		Weekday:        clock.WeekdayCN(today),
	}
	for _, d := range demos {
		resp.AvailableRoles = append(resp.AvailableRoles, roleOption{
			// role 键须可回喂 ?role= → 取 username(?role= 按 username 定位用户)
			Role:  d.Username,
			Name:  d.JobTitle + " (" + d.RealName + ")",
			Scope: scopeLabel(d.ScopeType, d.ScopeVal),
		})
	}
	envelope.OK(c, resp)
}

// HospitalProfile GET /api/v1/hospital/profile(契约 §2.2)
func (h *Context) HospitalProfile(c *gin.Context) {
	dict, err := repo.HospitalDict(c.Request.Context(), h.db)
	if err != nil {
		failInternal(c)
		return
	}

	resp := hospitalProfileResp{
		Name:        dict["name"].DictLabel,
		EnglishName: dict["english_name"].DictLabel,
		Level:       dict["level"].DictLabel,
		Motto:       []string{},
		Slogans:     []string{},
		Pillars:     []string{},
	}
	for key, dst := range map[string]*[]string{
		"motto": &resp.Motto, "slogans": &resp.Slogans, "pillars": &resp.Pillars,
	} {
		row, ok := dict[key]
		if !ok || len(row.Extra) == 0 {
			continue
		}
		if err := json.Unmarshal(row.Extra, dst); err != nil { // extra 非 JSON 数组=数据异常
			failInternal(c)
			return
		}
	}
	envelope.OK(c, resp)
}

// 院级哨兵:库内 NULL 或 0 一律对外序列化 null(契约 §2.1 字段注)
func jsonDeptID(id *int64) *int64 {
	if id == nil || *id == 0 {
		return nil
	}
	return id
}

// scope_type→文案:all 全院/dept 本科室/domain 按 scope_val 映射,未知域回退原值(设计 §1)
func scopeLabel(scopeType string, scopeVal *string) string {
	switch scopeType {
	case "all":
		return "全院"
	case "dept":
		return "本科室"
	case "domain":
		if scopeVal != nil {
			switch *scopeVal {
			case "ops_quality":
				return "全院运营/质控"
			case "medical":
				return "全院医疗"
			case "finance":
				return "全院财务"
			default:
				return *scopeVal
			}
		}
	}
	return ""
}

func failInternal(c *gin.Context) {
	envelope.Fail(c, http.StatusInternalServerError, envelope.CodeInternal, "系统繁忙,请稍后重试", nil)
}
