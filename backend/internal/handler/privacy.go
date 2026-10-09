package handler

import (
	"encoding/json"
	"github.com/gin-gonic/gin"
	"hospital-edss/internal/envelope"
)

func scopedDept(c *gin.Context, dept *int64, scope string) *int64 {
	if !demoSwitchOn(c) && scope == "dept" {
		return dept
	}
	return nil
}

func privacyName(name string, mask bool) string {
	if !mask || name == "" {
		return name
	}
	runes := []rune(name)
	return string(runes[0]) + "**"
}

func (h *WriteHandler) maskNames(c *gin.Context) (bool, error) {
	su, ok := sessionUser(c)
	if !ok {
		return false, nil
	} // Direct handler fixtures have no identity; real routes require Session.
	if su.Role != "admin" && su.Role != "president" && su.Role != "ops_director" {
		return true, nil
	}
	p, err := h.r.PrefsLoad(c.Request.Context(), su.ID)
	if err != nil {
		return true, err
	}
	mask := true
	if raw, ok := p["privacy_mask"]; ok {
		if err := json.Unmarshal(raw, &mask); err != nil {
			return true, err
		}
	}
	return mask, nil
}

func (h *WriteHandler) PrefsGet(c *gin.Context) {
	su, ok := sessionUser(c)
	if !ok {
		envelope.Fail(c, 401, envelope.CodeUnauth, "未登录", nil)
		return
	}
	p, err := h.r.PrefsLoad(c.Request.Context(), su.ID)
	if err != nil {
		envelope.FailInternal(c, err)
		return
	}
	envelope.OK(c, prefsData(p))
}
