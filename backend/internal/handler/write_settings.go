// P3-EW 设置写回 handler——R15 POST /workbench/settings/rules/:code(契约 §15.7)
// + R16 PUT /workbench/settings/preferences(§15.8)。
package handler

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

// RuleToggle R15——阈值启停写回;角色闸先查:写面限管理域 admin/president/ops_director(契约 §15.7)
func (h *WriteHandler) RuleToggle(c *gin.Context) {
	op, ok := h.operator(c)
	if !ok {
		return
	}
	switch op.Role {
	case "admin", "president", "ops_director":
	default:
		envelope.Fail(c, http.StatusForbidden, envelope.CodeScopeDeny, "无权执行该操作（角色不足）", nil)
		return
	}
	var b struct {
		Enabled *bool `json:"enabled"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		envelope.Fail(c, http.StatusBadRequest, envelope.CodeBadJSON, "请求体格式非法", nil)
		return
	}
	if b.Enabled == nil {
		envelope.Fail(c, http.StatusBadRequest, envelope.CodeFieldErr, "参数校验失败",
			envelope.Fields{"enabled": "必填"})
		return
	}
	code := c.Param("code")
	if err := h.r.RuleToggle(c.Request.Context(), *op, code, *b.Enabled, c.ClientIP()); err != nil {
		if errors.Is(err, repo.ErrRuleNotFound) {
			envelope.Fail(c, http.StatusNotFound, envelope.CodeNotFound, "资源不存在", nil)
			return
		}
		envelope.FailInternal(c, err)
		return
	}
	envelope.OK(c, gin.H{"code": code, "enabled": *b.Enabled})
}

// PrefsSave R16——五键偏好部分更新(sys.user_pref upsert);空对象/未知键→10001,枚举越界→10002
func (h *WriteHandler) PrefsSave(c *gin.Context) {
	op, ok := h.operator(c)
	if !ok {
		return
	}
	var raw map[string]json.RawMessage
	if err := c.ShouldBindJSON(&raw); err != nil {
		envelope.Fail(c, http.StatusBadRequest, envelope.CodeBadJSON, "请求体格式非法", nil)
		return
	}
	if len(raw) == 0 {
		envelope.InvalidArg(c, "preferences", "至少提交一项")
		return
	}
	var in repo.PrefInput
	fields := envelope.Fields{}
	for k, v := range raw {
		switch k {
		case "default_range":
			var s string
			if json.Unmarshal(v, &s) != nil || !repo.PrefKeyRange(s) {
				fields[k] = "本月/本季/本年 之外"
			} else {
				in.DefaultRange = &s
			}
		case "refresh_interval":
			var s string
			if json.Unmarshal(v, &s) != nil || !repo.PrefKeyInterval(s) {
				fields[k] = "5 分钟/15 分钟/30 分钟 之外"
			} else {
				in.RefreshInterval = &s
			}
		case "alert_sound", "unit_abbreviation", "privacy_mask":
			var bv bool
			if json.Unmarshal(v, &bv) != nil {
				fields[k] = "须为布尔"
			} else {
				switch k {
				case "alert_sound":
					in.AlertSound = &bv
				case "unit_abbreviation":
					in.UnitAbbrev = &bv
				case "privacy_mask":
					in.PrivacyMask = &bv
				}
			}
		default:
			envelope.InvalidArg(c, k, "未知偏好键")
			return
		}
	}
	if len(fields) > 0 {
		envelope.Fail(c, http.StatusBadRequest, envelope.CodeFieldErr, "参数校验失败", fields)
		return
	}
	ctx := c.Request.Context()
	if err := h.r.PrefsSave(ctx, *op, in, c.ClientIP()); err != nil {
		envelope.FailInternal(c, err)
		return
	}
	pref, err := h.r.PrefsLoad(ctx, op.ID)
	if err != nil {
		envelope.FailInternal(c, err)
		return
	}
	envelope.OK(c, prefsData(pref))
}

// prefsData 回写后完整偏好集——与 §13.2 preferences 同形;缺键落契约默认(本月/5 分钟/true×3)
func prefsData(pref map[string][]byte) gin.H {
	defaultRange := "本月"
	if raw, ok := pref["default_range"]; ok {
		var k string
		if json.Unmarshal(raw, &k) == nil {
			if l, ok := repo.PrefRangeLabel(k); ok {
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
	return gin.H{
		"default_range":     defaultRange,
		"refresh_interval":  refresh,
		"alert_sound":       prefBool("alert_sound"),
		"unit_abbreviation": prefBool("unit_abbreviation"),
		"privacy_mask":      prefBool("privacy_mask"),
	}
}
