// Package handler E3 staff 域 handler——契约 §7~§11、§13.2。
// 视图数据一律经 repo.StaffRepo(AGENTS §2.6);出参字段名照抄契约 snake_case/types.ts。
package handler

import (
	"context"
	"fmt"
	"math"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

// StaffHandler E3 六端点共享 handler 基座
type StaffHandler struct {
	r *repo.StaffRepo
}

func NewStaffHandler(r *repo.StaffRepo) *StaffHandler {
	return &StaffHandler{r: r}
}

// fail 统一 500 短路(handler 内 return 即停;错误明细不外泄,error-codes §3 10000)
func fail(c *gin.Context) {
	envelope.Fail(c, 500, envelope.CodeInternal, "系统繁忙,请稍后重试", nil)
}

// ---- 契约零件构造 ---------------------------------------------------------

// statItem 契约 WbStatItem(§1.3-3);可选字段缺席即不下发
func statItem(label, value, unit, delta, deltaLabel, dir, note string) gin.H {
	h := gin.H{"label": label, "value": value}
	if unit != "" {
		h["unit"] = unit
	}
	if delta != "" {
		h["delta"] = delta
		if deltaLabel != "" {
			h["delta_label"] = deltaLabel
		}
		if dir != "" {
			h["dir"] = dir
		}
	}
	if note != "" {
		h["note"] = note
	}
	return h
}

// tableCol WbTable 列元数据(§16 服务端下发);align/num 缺席即不下发
func tableCol(key, title, align string, num bool) gin.H {
	h := gin.H{"key": key, "title": title}
	if align != "" {
		h["align"] = align
	}
	if num {
		h["num"] = true
	}
	return h
}

// table 契约 WbTableData{columns,rows}
func table(columns []gin.H, rows []gin.H) gin.H {
	return gin.H{"columns": columns, "rows": rows}
}

// ---- delta 口径(锚定复算契约 5 例全部命中,见 e3-design)---------------------

// deltaLabelOf 指标周期→变动文案(月→较上月;年→较去年;日→较昨日)
func deltaLabelOf(period string) string {
	switch period {
	case "year":
		return "较去年"
	case "day", "realtime":
		return "较昨日"
	default:
		return "较上月"
	}
}

func dirOf(d float64) string {
	if d > 0 {
		return "up"
	}
	if d < 0 {
		return "down"
	}
	return "flat"
}

// deltaRel 相对变动 ±x.x%(rate/score/amt 类);prev 缺失或 0→空串
func deltaRel(cur, prev float64, ok bool) (string, string) {
	if !ok || prev == 0 {
		return "", ""
	}
	d := (cur - prev) / prev * 100
	if math.Abs(d) < 0.05 {
		return "持平", "flat"
	}
	return fmt.Sprintf("%+.1f%%", d), dirOf(d)
}

// deltaAbs 绝对变动;suffix 非空 → "+6项" 整数+单位词;空 → "-0.4" 1 位小数无单位
func deltaAbs(cur, prev float64, ok bool, suffix string) (string, string) {
	if !ok {
		return "", ""
	}
	d := cur - prev
	if suffix != "" {
		n := math.Round(d)
		if n == 0 {
			return "持平", "flat"
		}
		return fmt.Sprintf("%+d%s", int(n), suffix), dirOf(d)
	}
	d = math.Round(d*10) / 10
	if d == 0 {
		return "持平", "flat"
	}
	return fmt.Sprintf("%+.1f", d), dirOf(d)
}

// statMetric 读院级指标当期/上期,按策略产出 (delta,dir);prev 无行则空
func (h *StaffHandler) statMetric(ctx context.Context, code string, today time.Time) (cur float64, def *repo.MetricDef, delta, dir string, err error) {
	def, err = h.r.MetricDef(ctx, code)
	if err != nil {
		return 0, nil, "", "", err
	}
	cur, _, err = h.r.MetricAt(ctx, code, 0, repo.PeriodStart(today, def.Period))
	if err != nil {
		return 0, nil, "", "", err
	}
	prev, ok, err := h.r.MetricAt(ctx, code, 0, repo.PrevPeriodStart(today, def.Period))
	if err != nil {
		return 0, nil, "", "", err
	}
	switch def.ValueKind {
	case "cnt":
		if def.DispUnit == "人" || def.DispUnit == "人次" {
			delta, dir = deltaRel(cur, prev, ok) // 人员规模契约 delta 为相对变动("+1.8%")
		} else {
			delta, dir = deltaAbs(cur, prev, ok, def.DispUnit) // "+6项"/"-2件"
		}
	case "mins", "days":
		delta, dir = deltaAbs(cur, prev, ok, def.DispUnit) // "-3分钟"/"+9天"
	case "idx":
		delta, dir = deltaAbs(cur, prev, ok, "") // "-0.4" DDDs 类
	default: // rate/score/amt → 相对变动 ±x.x%
		delta, dir = deltaRel(cur, prev, ok)
	}
	return cur, def, delta, dir, nil
}

// ---- 数值序列化 -----------------------------------------------------------

// fmtComma 千分位整数字符串("2,368");契约 stats/明细金额展示形态
func fmtComma(v float64) string {
	n := int64(math.Round(v))
	sign := ""
	if n < 0 {
		sign = "-"
		n = -n
	}
	s := strconv.FormatInt(n, 10)
	if len(s) <= 3 {
		return sign + s
	}
	var b strings.Builder
	b.WriteString(sign)
	rem := len(s) % 3
	for i, ch := range s {
		if i > 0 && (i-rem)%3 == 0 {
			b.WriteByte(',')
		}
		b.WriteRune(ch)
	}
	return b.String()
}

// fmtTrim 去尾零小数(1.25→"1.25",2.00→"2")
func fmtTrim(v float64, prec int) string {
	s := fmtF(v, prec)
	if strings.Contains(s, ".") {
		s = strings.TrimRight(s, "0")
		s = strings.TrimRight(s, ".")
	}
	return s
}
