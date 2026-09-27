package handler

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

// SettingsConfig §13.2 GET /workbench/settings/config——
// 设置聚合(data_sources/thresholds/users/preferences);无声明查询参数,未知参数忽略。
func (h *StaffHandler) SettingsConfig(c *gin.Context) {
	ctx := c.Request.Context()
	dict, err := h.settingsDicts(ctx)
	if err != nil {
		fail(c, err)
		return
	}

	// ---- data_sources:6 行契约序,type/status=dict 标签,sync=YYYY-MM-DD HH:mm ----
	srcs, err := h.r.SettingDataSources(ctx)
	if err != nil {
		fail(c, err)
		return
	}
	srcRows := make([]gin.H, 0, len(srcs))
	for _, s := range srcs {
		srcRows = append(srcRows, gin.H{
			"name":   s.Name,
			"type":   dict["datasource_type"][s.TypeKey],
			"status": dict["datasource_status"][s.StatusKey],
			"sync":   fmtMinute(s.LastSync),
		})
	}

	// ---- thresholds:白名单 7 行,name 取契约名映射,rule 文案=eval_json+op+threshold 拼装 ----
	rules, err := h.r.SettingRules(ctx)
	if err != nil {
		fail(c, err)
		return
	}
	thRows := make([]gin.H, 0, len(rules))
	for _, rr := range rules {
		thRows = append(thRows, gin.H{
			"name":    settingsRuleNames[rr.Code],
			"code":    rr.Code,
			"rule":    settingsRuleText(rr),
			"level":   rr.AlertLevel,
			"enabled": rr.Enabled,
		})
	}

	// ---- users:sys.user 全行,name=real_name,status=user_status dict ----
	us, err := h.r.SettingUsers(ctx)
	if err != nil {
		fail(c, err)
		return
	}
	userRows := make([]gin.H, 0, len(us))
	for _, u := range us {
		userRows = append(userRows, gin.H{
			"name":   u.RealName,
			"role":   dict["role_type"][u.RoleKey],
			"scope":  settingsScope(u),
			"login":  fmtMinute(u.LastLogin),
			"status": dict["user_status"][strconv.Itoa(u.UserStatus)],
		})
	}

	// ---- preferences:会话用户 id(P3 会话化,原 user_id=1 硬编码);缺键→契约默认(本月/5 分钟/true/true/true) ----
	su, ok := sessionUser(c)
	if !ok { // 中间件白名单外兜底;正常路由必有会话
		envelope.Fail(c, http.StatusUnauthorized, envelope.CodeUnauth, "未登录或凭证缺失", nil)
		return
	}
	pref, err := h.r.SettingPrefs(ctx, su.ID)
	if err != nil {
		fail(c, err)
		return
	}
	defaultRange := "本月"
	if raw, ok := pref["default_range"]; ok {
		var k string
		if json.Unmarshal(raw, &k) == nil {
			if l, ok := dict["range_type"][k]; ok {
				defaultRange = l
			}
		}
	}
	refresh := "5 分钟"
	if raw, ok := pref["refresh_interval"]; ok {
		var sec float64
		if json.Unmarshal(raw, &sec) == nil {
			refresh = fmtTrim(sec/60, 1) + " 分钟" // 库内存秒,契约出"N 分钟"文案
		}
	}
	prefBool := func(key string) bool {
		raw, ok := pref[key]
		if !ok {
			return true
		}
		var b bool
		if err := json.Unmarshal(raw, &b); err != nil {
			return true
		}
		return b
	}

	envelope.OK(c, gin.H{
		"data_sources": srcRows,
		"thresholds":   thRows,
		"users":        userRows,
		"preferences": gin.H{
			"default_range":     defaultRange,
			"refresh_interval":  refresh,
			"alert_sound":       prefBool("alert_sound"),
			"unit_abbreviation": prefBool("unit_abbreviation"),
			"privacy_mask":      prefBool("privacy_mask"),
		},
	})
}

// settingsRuleNames 阈值行契约名映射(契约名≠metric_def.name 两条——耗占比/危急值超时率——以契约为准)
var settingsRuleNames = map[string]string{
	"BED_OVER_95":     "床位使用率",
	"DRUG_RATIO_WARN": "药占比",
	"MAT_OVER_20":     "耗占比",
	"INPT_FEE_SURGE":  "住院费用增幅",
	"STOCK_TURN_SLOW": "库存周转天数",
	"CRIT_TIMEOUT_95": "危急值超时率",
	"EQUIP_RUN_LOW":   "设备开机率",
}

var settingsDomainScope = map[string]string{
	"medical":     "医疗业务",
	"finance":     "运营财务",
	"ops_quality": "运营质控",
}

// settingsRuleText 阈值文案=eval_json(window/agg) 前缀 + op + threshold×量纲(L7 README §2.3 拼装口径)
func settingsRuleText(rr repo.AlertRuleRow) string {
	var ev struct {
		Window string `json:"window"`
		Agg    string `json:"agg"`
	}
	_ = json.Unmarshal(rr.EvalJSON, &ev)

	scaled := fmtTrim(rr.Threshold, 2)
	switch rr.ValueKind {
	case "rate":
		scaled = fmtTrim(rr.Threshold*100, 2) + "%"
	case "days":
		scaled += " 天"
	}
	prefix := ""
	switch ev.Agg {
	case "consecutive_days":
		prefix = "连续 " + settingsWindowDays(ev.Window) + " 日"
	case "yoy":
		prefix = "同比"
	case "rate":
		prefix = "及时率"
	}
	return strings.TrimSpace(prefix + " " + rr.Op + " " + scaled)
}

// settingsWindowDays ISO8601 日窗"P3D"→"3";非预期形态原样回落
func settingsWindowDays(w string) string {
	if len(w) > 2 && w[0] == 'P' && w[len(w)-1] == 'D' {
		return w[1 : len(w)-1]
	}
	return w
}

// settingsScope 数据范围文案:admin→全部 / scope_type all→全院 / dept→科室名 / domain→域键映射
func settingsScope(u repo.UserRow) string {
	switch u.ScopeType {
	case "dept":
		if u.DeptName != nil {
			return *u.DeptName
		}
		return ""
	case "domain":
		if u.ScopeVal != nil {
			return settingsDomainScope[*u.ScopeVal]
		}
		return ""
	default: // all
		if u.RoleKey == "admin" {
			return "全部"
		}
		return "全院"
	}
}

// settingsDicts 四块渲染所需字典一次性装载(标签一数一源 sys.dict)
func (h *StaffHandler) settingsDicts(ctx context.Context) (map[string]map[string]string, error) {
	out := make(map[string]map[string]string, 5)
	for _, dt := range []string{"datasource_type", "datasource_status", "role_type", "user_status", "range_type"} {
		rows, err := h.r.DictList(ctx, dt)
		if err != nil {
			return nil, err
		}
		m := make(map[string]string, len(rows))
		for _, rw := range rows {
			m[rw.Key] = rw.Label
		}
		out[dt] = m
	}
	return out, nil
}

// fmtMinute "YYYY-MM-DD HH:mm" 截断序列化;NULL→""(契约 §13.2 注2)
func fmtMinute(t *time.Time) string {
	if t == nil {
		return ""
	}
	return t.Format("2006-01-02 15:04")
}
