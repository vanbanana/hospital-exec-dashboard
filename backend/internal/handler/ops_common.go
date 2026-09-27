// Package handler 综合运营域(E2)共享件——响应组件类型、参数校验、格式化助手。
// 字段名/枚举/格式严格对齐 docs/api-contract.md §1.3/§1.4 与 src/api/types.ts。
package handler

import (
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

// OpsHandler E2 四端点共享 handler(方法按端点分文件:ops_overview/medical/operations/compare.go)
type OpsHandler struct {
	ops *repo.Ops
	ck  *clock.Source
}

func NewOpsHandler(db *gorm.DB, ck *clock.Source) *OpsHandler {
	return &OpsHandler{ops: repo.NewOps(db, ck), ck: ck}
}

// today 业务"今天";失败回 10000 并标记 ok=false
func (h *OpsHandler) today(c *gin.Context) (time.Time, bool) {
	t, err := h.ck.Today(c.Request.Context())
	if err != nil {
		envelope.Fail(c, 500, envelope.CodeInternal, "系统繁忙,请稍后重试", nil)
		return t, false
	}
	return t, true
}

func (h *OpsHandler) internalErr(c *gin.Context) {
	envelope.Fail(c, 500, envelope.CodeInternal, "系统繁忙,请稍后重试", nil)
}

/* ========== 响应组件(契约 §1.3-3 WbStatItem / §16-1 WbTableColumn) ========== */

// StatItem 指标条项;omitempty 与 types.ts 可选字段一一对应
type StatItem struct {
	Label      string `json:"label"`
	Value      any    `json:"value"`
	Unit       string `json:"unit,omitempty"`
	Delta      string `json:"delta,omitempty"`
	DeltaLabel string `json:"delta_label,omitempty"`
	Dir        string `json:"dir,omitempty"`
	Icon       string `json:"icon,omitempty"`
	Tone       string `json:"tone,omitempty"`
	Note       string `json:"note,omitempty"`
}

// Col 表格列元数据
type Col struct {
	Key   string `json:"key"`
	Title string `json:"title"`
	Width string `json:"width,omitempty"`
	Align string `json:"align,omitempty"`
	Num   bool   `json:"num,omitempty"`
}

// Table WbTableData
type Table struct {
	Columns []Col            `json:"columns"`
	Rows    []map[string]any `json:"rows"`
}

/* ========== 参数校验(非法枚举→10001,见 error-codes §3) ========== */

// enumParam 读枚举 query 参数;空串→缺省;非法→已回 10001,ok=false
func enumParam(c *gin.Context, name, def string, allowed ...string) (string, bool) {
	v := c.Query(name)
	if v == "" {
		return def, true
	}
	for _, a := range allowed {
		if v == a {
			return v, true
		}
	}
	envelope.InvalidArg(c, name, "取值须为 "+strings.Join(allowed, "/")+" 之一")
	return "", false
}

// rangeParam 三值 range;def 各端点不同(overview/medical/operations=本年,compare=本月)
func rangeParam(c *gin.Context, def string) (string, bool) {
	return enumParam(c, "range", def, "本月", "本季", "本年")
}

/* ========== 格式化(契约 §1.3/§1.4 钉死口径) ========== */

// fmtInt 千分位整串("123,443");stats.value/table.cnt/metric 用
func fmtInt(n int64) string {
	s := strconv.FormatInt(n, 10)
	neg := strings.HasPrefix(s, "-")
	if neg {
		s = s[1:]
	}
	var b strings.Builder
	if neg {
		b.WriteByte('-')
	}
	for i := 0; i < len(s); i++ {
		if i > 0 && (len(s)-i)%3 == 0 {
			b.WriteByte(',')
		}
		b.WriteByte(s[i])
	}
	return b.String()
}

// fmtF 定点小数字串("92.1"/"6.8")
func fmtF(x float64, prec int) string { return strconv.FormatFloat(x, 'f', prec, 64) }

// pctStr 比率展示串("28.4%");入参已是百分数刻度(28.4 非 0.284)
func pctStr(x float64, prec int) string { return fmtF(x, prec) + "%" }

// signedPct 带符号百分变动("+6.2%"/"-1.2%")
func signedPct(x float64, prec int) string {
	if x > 0 {
		return "+" + fmtF(x, prec) + "%"
	}
	return fmtF(x, prec) + "%"
}

// signedNum 带符号数值变动("+0.42"/"-0.3")
func signedNum(x float64, prec int) string {
	if x > 0 {
		return "+" + fmtF(x, prec)
	}
	return fmtF(x, prec)
}

// dirOf delta→dir 三态;eps 为 flat 死区(比率项用 0.05,量项 0)
func dirOf(d, eps float64) string {
	if d > eps {
		return "up"
	}
	if d < -eps {
		return "down"
	}
	return "flat"
}

// deltaLabel 变动口径文案(与 src/mock/labels.ts 同源)
func deltaLabel(rk string) string {
	switch rk {
	case "本月":
		return "较上月"
	case "本季":
		return "较上季"
	}
	return "较去年"
}

// yoyPct 同比变动百分比(cur/prev−1)×100;prev<=0 时返回 0(前端展示 "+0.0%")
func yoyPct(cur, prev float64) float64 {
	if prev <= 0 {
		return 0
	}
	return (cur/prev - 1) * 100
}

// monthLabels 月首序列→"N月"标签
func monthLabels(ms []time.Time) []string {
	out := make([]string, len(ms))
	for i, t := range ms {
		out[i] = fmt.Sprintf("%d月", t.Month())
	}
	return out
}

// months12 全年 12 月标签轴
func months12() []string {
	out := make([]string, 12)
	for i := range out {
		out[i] = fmt.Sprintf("%d月", i+1)
	}
	return out
}

// wan 元→万元
func wan(yuan float64) float64 { return yuan / 1e4 }
