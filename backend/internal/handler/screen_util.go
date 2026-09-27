// E4 域共享格式化助手——契约 §1.3 数值/单位规范与 §1.4 delta 格式的唯一实现处,
// screen/topics 两 handler 共用;换算规则:率 0~1 存储 → 出参 ×100(契约 §1.3-2)
package handler

import (
	"fmt"
	"math"
	"time"
)

// roundN 四舍五入到 n 位小数
func roundN(v float64, n int) float64 {
	p := math.Pow10(n)
	return math.Round(v*p) / p
}

// ratePct 率值 0~1 → 展示百分数(契约:92.1 表 92.1%),round 1 位
func ratePct(v float64) float64 { return roundN(v*100, 1) }

// commaInt 千分位整数字符串(契约 stats.value 形态 "8,460")
func commaInt(v float64) string {
	i := int64(math.Round(v))
	sign := ""
	if i < 0 {
		sign = "-"
		i = -i
	}
	s := fmt.Sprintf("%d", i)
	if len(s) <= 3 {
		return sign + s
	}
	var out []byte
	for len(s) > 3 {
		out = append([]byte{','}, append(out, s[len(s)-3:]...)...)
		s = s[:len(s)-3]
	}
	return sign + s + string(out)
}

// signedPct 环比/同比百分变动文案(契约 §1.4-3:"+3.6%"/"-0.3%"/"持平")
func signedPct(deltaPctPoints float64) string {
	if math.Abs(deltaPctPoints) < 0.05 {
		return "持平"
	}
	return fmt.Sprintf("%+.1f%%", deltaPctPoints)
}

// signedDec 非率类变动文案(契约:"-0.3"/"+0.04"/"持平")
func signedDec(d float64, n int) string {
	if math.Abs(d) < math.Pow10(-n)/2 {
		return "持平"
	}
	return fmt.Sprintf("%+.*f", n, d)
}

// signedUnit 带单位变动文案(契约:"+18分"/"+12项")
func signedUnit(d float64, unit string) string {
	if math.Abs(d) < 0.5 {
		return "持平"
	}
	return fmt.Sprintf("%+.0f%s", d, unit)
}

// dirOf 变动方向三态(契约 dir 枚举)
func dirOf(d float64) string {
	switch {
	case d > 0:
		return "up"
	case d < 0:
		return "down"
	default:
		return "flat"
	}
}

// trendArrow 国考趋势渲染(exam table.trend;exam_indicator.direction 1/0/-1)
func trendArrow(dir int) string {
	switch dir {
	case 1:
		return "↑"
	case -1:
		return "↓"
	default:
		return "→"
	}
}

// rfc3339 ISO 时刻出参(契约 §1.4-4;timestamptz 自带 +08 偏移)
func rfc3339(t time.Time) string { return t.Format(time.RFC3339) }

// monthLabel 图表月份轴文案("10月")
func monthLabel(t time.Time) string { return fmt.Sprintf("%d月", t.Month()) }

// dayLabel trends.dates 短日期(§14.1 契约字面 MM-DD,此字段为 §1.4-4 例外)
func dayLabel(t time.Time) string { return t.Format("01-02") }
