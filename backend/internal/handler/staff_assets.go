package handler

import (
	"fmt"
	"math"
	"sort"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

// 契约 §11.1 large_equipments 白名单(name 集,序=契约行序)
var largeEquipWhitelist = []string{
	"3.0T 核磁共振", "256 排 CT", "DSA 血管造影机", "直线加速器",
	"PET-CT", "高清电子胃肠镜", "体外冲击波碎石机",
}

// Assets §11.1 GET /workbench/assets——stats 6 项 + 能耗趋势 + 库存预警 + 大型设备台账
func (h *StaffHandler) Assets(c *gin.Context) {
	ctx := c.Request.Context()
	today, err := h.r.Today(ctx)
	if err != nil {
		fail(c)
		return
	}
	mStart := repo.PeriodStart(today, "month")

	// ---- stats(契约序;amt 元→亿元÷1e8、元→万元÷1e4) ----
	stats := make([]gin.H, 0, 6)
	for _, s := range []struct {
		label, code, unit string
		conv              func(float64) string
	}{
		{"固定资产总额", "FIXED_ASSET_AMT", "亿元", func(v float64) string { return fmtF(v/1e8, 1) }},
		{"设备开机率", "EQUIP_RUN_RATE", "%", func(v float64) string { return fmtF(v*100, 1) }},
		{"库存周转天数", "STOCK_TURN_DAYS", "天", fmtComma},
		{"本月能耗费用", "ENERGY_COST", "万元", func(v float64) string { return fmtComma(v / 1e4) }},
	} {
		it, err := h.patientStat(ctx, today, s.label, s.code, s.unit, s.conv)
		if err != nil {
			fail(c)
			return
		}
		stats = append(stats, it)
	}
	devCnt, _, _, _, err := h.statMetric(ctx, "LARGE_DEVICE_CNT", today)
	if err != nil {
		fail(c)
		return
	}
	woCnt, _, _, _, err := h.statMetric(ctx, "WORK_ORDER_CNT", today)
	if err != nil {
		fail(c)
		return
	}
	doneRate, _, err := h.r.MetricAt(ctx, "WORK_ORDER_DONE_RATE", 0, mStart)
	if err != nil {
		fail(c)
		return
	}
	// 两台数项契约无 delta,仅 note(§11.1 示例)
	stats = []gin.H{
		stats[0],
		statItem("大型设备", fmtComma(devCnt), "台", "", "", "", "单价 ≥100 万"),
		stats[1], stats[2], stats[3],
		statItem("后勤工单", fmtComma(woCnt), "单", "", "", "", fmt.Sprintf("完结率 %.0f%%", doneRate*100)),
	}

	// ---- energy_trend:近 6 月三分项,total=三分项Σ(不独查),元→万元 ----
	starts, months := repo.MonthAxis(today, 6)
	eRows, err := h.r.EnergyMonths(ctx, starts)
	if err != nil {
		fail(c)
		return
	}
	amt := make(map[string]map[string]float64, len(starts))
	for _, e := range eRows {
		k := e.PeriodStart.Format("2006-01-02")
		if amt[k] == nil {
			amt[k] = make(map[string]float64, 3)
		}
		amt[k][e.EnergyType] = e.EnergyAmt
	}
	electricity := make([]float64, len(starts))
	water := make([]float64, len(starts))
	gas := make([]float64, len(starts))
	total := make([]float64, len(starts))
	for i, s := range starts {
		m := amt[s.Format("2006-01-02")]
		electricity[i] = m["electricity"] / 1e4
		water[i] = m["water"] / 1e4
		gas[i] = m["gas"] / 1e4
		total[i] = electricity[i] + water[i] + gas[i]
	}

	// ---- stock_alerts:最近快照,days>warn_days 入选,days DESC ----
	sRows, err := h.r.StockAlerts(ctx, today)
	if err != nil {
		fail(c)
		return
	}
	alerts := make([]gin.H, 0, len(sRows))
	for _, s := range sRows {
		days := int64(math.Round(float64(s.OnhandQty) / s.AvgDailyUse))
		if days <= s.WarnDays {
			continue
		}
		level := "minor"
		if days >= 40 {
			level = "urgent"
		} else if days >= 28 {
			level = "major"
		}
		alerts = append(alerts, gin.H{"name": s.Name, "days": days, "level": level})
	}
	sort.Slice(alerts, func(i, j int) bool { return alerts[i]["days"].(int64) > alerts[j]["days"].(int64) })

	// ---- large_equipments:白名单 7 台,契约列;roi 阈值见 metric_def DEVICE_ROI ----
	agg, err := h.r.LargeEquipMonth(ctx, mStart, largeEquipWhitelist)
	if err != nil {
		fail(c)
		return
	}
	byName := make(map[string]repo.EquipAggRow, len(agg))
	for _, a := range agg {
		byName[a.Name] = a
	}
	roiDict, err := h.r.DictList(ctx, "roi_level")
	if err != nil {
		fail(c)
		return
	}
	roiLabel := make(map[string]string, len(roiDict))
	for _, d := range roiDict {
		roiLabel[d.Key] = d.Label
	}
	equipRows := make([]gin.H, 0, len(largeEquipWhitelist))
	for _, name := range largeEquipWhitelist {
		a, ok := byName[name]
		if !ok {
			continue
		}
		var openRate float64
		if a.PlanH > 0 {
			openRate = math.Round(a.RunH/a.PlanH*1000) / 10
		}
		incomeW := a.Income / 1e4
		roiKey := "normal"
		switch {
		case incomeW >= 250 && openRate >= 85:
			roiKey = "good"
		case incomeW < 200 || openRate < 75:
			roiKey = "low"
		}
		equipRows = append(equipRows, gin.H{
			"name":      a.Name,
			"dept":      a.Dept,
			"count":     a.Cnt,
			"open_rate": openRate,
			"monthly":   fmtComma(float64(a.Monthly)),
			"income":    fmtComma(incomeW),
			"roi":       roiLabel[roiKey],
		})
	}

	envelope.OK(c, gin.H{
		"stats": stats,
		"energy_trend": gin.H{
			"unit": "万元", "months": months, "total": total,
			"electricity": electricity, "water": water, "gas": gas,
		},
		"stock_alerts": alerts,
		"large_equipments": table([]gin.H{
			tableCol("name", "设备名称", "", false),
			tableCol("dept", "所属科室", "", false),
			tableCol("count", "台数", "right", true),
			tableCol("open_rate", "开机率", "right", false),
			tableCol("monthly", "月均检查/治疗人次", "right", true),
			tableCol("income", "月创收（万元）", "right", true),
			tableCol("roi", "效益评价", "center", false),
		}, equipRows),
	})
}
