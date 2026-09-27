// screen/snapshot 端点(契约 §14.1)——大屏一站式快照;字段级口径见 /tmp/backend-orch/e4-design.md §2
package handler

import (
	"encoding/json"
	"strings"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

type ScreenHandler struct {
	db  *gorm.DB
	clk *clock.Source
}

func NewScreenHandler(db *gorm.DB, clk *clock.Source) *ScreenHandler {
	return &ScreenHandler{db: db, clk: clk}
}

// 契约固定序(§14.1):KPI 四码与楼宇四码,下发顺序恒定
var screenKpiOrder = []string{"OP_DAILY_VISITS", "IP_IN_HOSP", "BED_USE_RATE", "SURG_DAILY_CNT"}
var screenBuildingOrder = []string{"mz", "wk", "jz", "yj"}

// screenFrozenCmiProfit §14.1 注10/§13.1 冻结表:8 科室 cmi/profit 钉契约字面,
// 按科室 name 匹配(dept_id 与其余列仍取库);dept_ranking 与 drg_quadrant.points 同一表覆写
var screenFrozenCmiProfit = map[string][2]float64{
	"神经外科":      {1.68, -12.8},
	"心血管内科":     {1.42, 86.4},
	"骨科":        {1.36, 124.6},
	"肿瘤科":       {1.24, -34.6},
	"普通外科":      {1.18, 98.2},
	"呼吸与危重症医学科": {1.12, 42.8},
	"神经内科":      {0.94, 38.2},
	"儿科":        {0.68, 28.4},
}

// 契约示例值直发(设计 §1 裁决):anchor=渲染后图像矩形百分比坐标(§14.1 注7),
// 库 dim.building.map_anchor 为旧校准值不读;primary_metric 展示元数据库无源(注8 演示期必发)
var screenAnchors = map[string][2]float64{
	"mz": {24.0, 36.2},
	"wk": {51.0, 23.7},
	"jz": {71.8, 42.4},
	"yj": {57.1, 39.1},
}

type screenPrimaryMetric struct {
	Key   string  `json:"key"`
	Label string  `json:"label"`
	Unit  string  `json:"unit"`
	Max   float64 `json:"max"`
}

var screenPrimaryMetrics = map[string]screenPrimaryMetric{
	"mz": {Key: "queue_avg_min", Label: "候诊均时", Unit: "分", Max: 60},
	"wk": {Key: "bed_use_rate", Label: "床位使用率", Unit: "%", Max: 100},
	"jz": {Key: "obs_over6h", Label: "留观超时", Unit: "起", Max: 10},
	"yj": {Key: "device_run", Label: "设备运行", Unit: "台", Max: 12},
}

// status.text/desc 无库源,按 level 文案映射(设计 §2.2 自配文)
var screenStatusText = map[string][2]string{
	"normal": {"运行平稳", "医院整体运行正常"},
	"busy":   {"负荷偏高", "部分业务接近饱和"},
	"alert":  {"运行告警", "存在未闭环告警，请关注"},
}

// period→period_label 文案映射(§14.1 注9)
var screenPeriodLabels = map[string]string{"d30": "近30日"}

type screenStatusJSON struct {
	Level     string `json:"level"`
	Text      string `json:"text"`
	Desc      string `json:"desc"`
	AlertOpen struct {
		Urgent int `json:"urgent"`
		Major  int `json:"major"`
		Minor  int `json:"minor"`
	} `json:"alert_open"`
}

type screenKpiJSON struct {
	Code      string    `json:"code"`
	Name      string    `json:"name"`
	Value     float64   `json:"value"`
	Unit      string    `json:"unit"`
	PrevValue float64   `json:"prev_value"`
	DeltaPct  float64   `json:"delta_pct"`
	Direction int       `json:"direction"`
	Spark     []float64 `json:"spark"`
	Status    string    `json:"status"`
}

type screenDrgPointJSON struct {
	DeptID   int64   `json:"dept_id"`
	Name     string  `json:"name"`
	Category string  `json:"category"`
	Cmi      float64 `json:"cmi"`
	Profit   float64 `json:"profit"`
	CaseCnt  int64   `json:"case_cnt"`
	Quadrant int     `json:"quadrant"`
}

type screenBuildingJSON struct {
	Code       string `json:"code"`
	Name       string `json:"name"`
	Status     string `json:"status"`
	Badge      string `json:"badge"`
	BadgeLevel string `json:"badge_level"`
	Anchor     struct {
		X float64 `json:"x"`
		Y float64 `json:"y"`
	} `json:"anchor"`
	Metrics       map[string]any      `json:"metrics"`
	PrimaryMetric screenPrimaryMetric `json:"primary_metric"`
}

type screenDeptRankJSON struct {
	Rank     int     `json:"rank"`
	DeptID   int64   `json:"dept_id"`
	Name     string  `json:"name"`
	Category string  `json:"category"`
	Cmi      float64 `json:"cmi"`
	SurgCnt  int64   `json:"surg_cnt"`
	Alos     float64 `json:"alos"`
	Profit   float64 `json:"profit"`
	EffScore float64 `json:"eff_score"`
}

type screenAlertJSON struct {
	ID         int64  `json:"id"`
	Level      string `json:"level"`
	Title      string `json:"title"`
	Dept       string `json:"dept"`
	OccurredAt string `json:"occurred_at"`
}

type screenSnapshotJSON struct {
	ServerTime  string           `json:"server_time"`
	Status      screenStatusJSON `json:"status"`
	Kpis        []screenKpiJSON  `json:"kpis"`
	DrgQuadrant struct {
		Period      string `json:"period"`
		PeriodLabel string `json:"period_label"`
		Axis        struct {
			X string `json:"x"`
			Y string `json:"y"`
		} `json:"axis"`
		Split struct {
			X float64 `json:"x"`
			Y float64 `json:"y"`
		} `json:"split"`
		Points []screenDrgPointJSON `json:"points"`
	} `json:"drg_quadrant"`
	Buildings   []screenBuildingJSON `json:"buildings"`
	DeptRanking []screenDeptRankJSON `json:"dept_ranking"`
	Alerts      struct {
		TotalOpen int               `json:"total_open"`
		List      []screenAlertJSON `json:"list"`
	} `json:"alerts"`
	Trends struct {
		Days   int                  `json:"days"`
		Dates  []string             `json:"dates"`
		Series map[string][]float64 `json:"series"`
	} `json:"trends"`
}

// screenKpiDisp 存储量纲→展示出参(契约 §1.3-2):率 0~1→×100 round1,cnt/mins→round0
func screenKpiDisp(kind string, v float64) float64 {
	if kind == "rate" {
		return ratePct(v)
	}
	return roundN(v, 0)
}

// screenQuadrantOf 科室级四象限(§14.1 注10 口径,对下发值实算;勿用库 quadrant 单元格列)
func screenQuadrantOf(cmi, profit float64) int {
	switch {
	case cmi >= 1 && profit >= 0:
		return 2
	case cmi >= 1 && profit < 0:
		return 1
	case cmi < 1 && profit >= 0:
		return 4
	default:
		return 3
	}
}

func (h *ScreenHandler) fail(c *gin.Context) {
	envelope.Fail(c, 500, envelope.CodeInternal, "系统繁忙,请稍后重试", nil)
}

func (h *ScreenHandler) Snapshot(c *gin.Context) {
	ctx := c.Request.Context()
	now, err := h.clk.Now(ctx)
	if err != nil {
		h.fail(c)
		return
	}
	today, err := h.clk.Today(ctx)
	if err != nil {
		h.fail(c)
		return
	}

	openCnts, err := repo.ScreenOpenAlertCounts(ctx, h.db)
	if err != nil {
		h.fail(c)
		return
	}
	kpiRows, err := repo.ScreenTodayKpis(ctx, h.db)
	if err != nil {
		h.fail(c)
		return
	}
	drgRows, err := repo.ScreenDrgPoints(ctx, h.db)
	if err != nil {
		h.fail(c)
		return
	}
	campusRows, err := repo.ScreenCampus(ctx, h.db)
	if err != nil {
		h.fail(c)
		return
	}
	rankRows, err := repo.ScreenDeptRanking(ctx, h.db, today)
	if err != nil {
		h.fail(c)
		return
	}
	alertRows, err := repo.ScreenOpenAlerts(ctx, h.db)
	if err != nil {
		h.fail(c)
		return
	}

	out := screenSnapshotJSON{ServerTime: rfc3339(now)}

	// status:alert_open 与 alerts.list 同一张打开态集合的两个查询面,恒相等
	for _, r := range openCnts {
		switch r.AlertLevel {
		case "urgent":
			out.Status.AlertOpen.Urgent = r.Cnt
		case "major":
			out.Status.AlertOpen.Major = r.Cnt
		case "minor":
			out.Status.AlertOpen.Minor = r.Cnt
		}
	}
	campusByCode := make(map[string]repo.ScreenCampusRow, len(campusRows))
	alertBuilding, busyBuilding := false, false
	for _, r := range campusRows {
		campusByCode[r.BuildingCode] = r
		switch r.RunStatus {
		case "alert":
			alertBuilding = true
		case "busy":
			busyBuilding = true
		}
	}
	// level 派生(设计 §2.2):任一楼 alert 或有 urgent 开告警→alert;busy 楼或 major 开告警→busy
	out.Status.Level = "normal"
	if alertBuilding || out.Status.AlertOpen.Urgent > 0 {
		out.Status.Level = "alert"
	} else if busyBuilding || out.Status.AlertOpen.Major > 0 {
		out.Status.Level = "busy"
	}
	out.Status.Text = screenStatusText[out.Status.Level][0]
	out.Status.Desc = screenStatusText[out.Status.Level][1]

	// kpis:契约固定序;value 恒等 spark 末点(同源值同式换算天然自洽,§14.1 注6)
	kpiByCode := make(map[string]repo.ScreenKpiRow, len(kpiRows))
	for _, r := range kpiRows {
		kpiByCode[r.MetricCode] = r
	}
	out.Kpis = []screenKpiJSON{}
	out.Trends.Series = map[string][]float64{}
	for _, code := range screenKpiOrder {
		r, ok := kpiByCode[code]
		if !ok {
			continue
		}
		var spark []float64
		if len(r.Spark) > 0 {
			if err := json.Unmarshal(r.Spark, &spark); err != nil {
				h.fail(c)
				return
			}
		}
		conv := make([]float64, len(spark))
		for i, v := range spark {
			conv[i] = screenKpiDisp(r.ValueKind, v)
		}
		var prev, delta float64
		if r.PrevValue != nil {
			prev = screenKpiDisp(r.ValueKind, *r.PrevValue)
		}
		if r.DeltaPct != nil {
			delta = roundN(*r.DeltaPct, 1)
		}
		out.Kpis = append(out.Kpis, screenKpiJSON{
			Code:      r.MetricCode,
			Name:      r.Name,
			Value:     screenKpiDisp(r.ValueKind, r.Value),
			Unit:      r.DispUnit,
			PrevValue: prev,
			DeltaPct:  delta,
			Direction: r.Direction,
			Spark:     conv,
			Status:    r.KpiStatus,
		})
		out.Trends.Series[code] = conv
	}

	// drg_quadrant:常量块+全量点;覆盖科室 cmi/profit 冻结表覆写后实算象限
	out.DrgQuadrant.Period = "d30"
	out.DrgQuadrant.PeriodLabel = screenPeriodLabels["d30"]
	out.DrgQuadrant.Axis.X = "DRG盈亏(万元)"
	out.DrgQuadrant.Axis.Y = "CMI"
	out.DrgQuadrant.Split.X = 0
	out.DrgQuadrant.Split.Y = 1.0
	out.DrgQuadrant.Points = []screenDrgPointJSON{}
	for _, r := range drgRows {
		cmi, profit := 0.0, 0.0
		if r.Cmi != nil {
			cmi = roundN(*r.Cmi, 2)
		}
		if r.ProfitW != nil {
			profit = roundN(*r.ProfitW, 1)
		}
		if fz, ok := screenFrozenCmiProfit[r.Name]; ok {
			cmi, profit = fz[0], fz[1]
		}
		out.DrgQuadrant.Points = append(out.DrgQuadrant.Points, screenDrgPointJSON{
			DeptID:   r.DeptID,
			Name:     r.Name,
			Category: r.Category,
			Cmi:      cmi,
			Profit:   profit,
			CaseCnt:  r.CaseCnt,
			Quadrant: screenQuadrantOf(cmi, profit),
		})
	}

	// buildings:固定序;缺楼不下发;metrics 仅 *_rate 键 ×100(migrations 0404 O5 冻结映射)
	out.Buildings = []screenBuildingJSON{}
	for _, code := range screenBuildingOrder {
		r, ok := campusByCode[code]
		if !ok {
			continue
		}
		metrics := map[string]any{}
		if len(r.Metrics) > 0 {
			if err := json.Unmarshal(r.Metrics, &metrics); err != nil {
				h.fail(c)
				return
			}
		}
		for k, v := range metrics {
			if f, ok := v.(float64); ok && strings.HasSuffix(k, "_rate") {
				metrics[k] = ratePct(f)
			}
		}
		b := screenBuildingJSON{
			Code:          r.BuildingCode,
			Name:          r.Name,
			Status:        r.RunStatus,
			Badge:         r.BadgeText,
			BadgeLevel:    r.BadgeLevel,
			Metrics:       metrics,
			PrimaryMetric: screenPrimaryMetrics[r.BuildingCode],
		}
		b.Anchor.X = screenAnchors[r.BuildingCode][0]
		b.Anchor.Y = screenAnchors[r.BuildingCode][1]
		out.Buildings = append(out.Buildings, b)
	}

	// dept_ranking:全量行;同一冻结表覆写 cmi/profit;NULL 数值列归 0(types 要 number)
	out.DeptRanking = []screenDeptRankJSON{}
	for _, r := range rankRows {
		item := screenDeptRankJSON{
			Rank:     r.RankNo,
			DeptID:   r.DeptID,
			Name:     r.Name,
			Category: r.Category,
			SurgCnt:  r.SurgCnt,
		}
		if r.Cmi != nil {
			item.Cmi = roundN(*r.Cmi, 2)
		}
		if r.Alos != nil {
			item.Alos = roundN(*r.Alos, 1)
		}
		if r.ProfitW != nil {
			item.Profit = roundN(*r.ProfitW, 1)
		}
		if r.EffScore != nil {
			item.EffScore = roundN(*r.EffScore, 1)
		}
		if fz, ok := screenFrozenCmiProfit[r.Name]; ok {
			item.Cmi, item.Profit = fz[0], fz[1]
		}
		out.DeptRanking = append(out.DeptRanking, item)
	}

	out.Alerts.List = []screenAlertJSON{}
	for _, r := range alertRows {
		out.Alerts.List = append(out.Alerts.List, screenAlertJSON{
			ID:         r.ID,
			Level:      r.AlertLevel,
			Title:      r.Title,
			Dept:       r.Dept,
			OccurredAt: rfc3339(r.OccurredAt),
		})
	}
	out.Alerts.TotalOpen = len(out.Alerts.List)

	// trends:dates=Today-6..Today MM-DD;series 与 kpis[].spark 同一数组引用(§2.8 同源自洽)
	out.Trends.Days = 7
	out.Trends.Dates = make([]string, 0, out.Trends.Days)
	for i := out.Trends.Days - 1; i >= 0; i-- {
		out.Trends.Dates = append(out.Trends.Dates, dayLabel(today.AddDate(0, 0, -i)))
	}

	envelope.OK(c, out)
}
