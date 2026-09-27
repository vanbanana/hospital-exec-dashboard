// screen/snapshot handler 级 httptest(任务书 task-e4-a)——实库只读,router.Build 全真装配;
// package handler_test 外部测试包方可 import router:package handler 内引 router 会成环
// (router→handler 反向依赖,E1 同约束——E1 用手工路由是本包内测的替代写法,本文件走外部包)
package handler_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"sync"
	"testing"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/router"
)

var (
	snapDBOnce sync.Once
	snapDBPool *gorm.DB
	snapDBErr  error
)

// 实库断言锚点:sim.clock BASE_DATE=2026-10-28;库不可达时 Skip(验收环境库必在)
// handler_test 外部包共享单池,理由同内部包 testDB(连接泄漏 B2)
func snapDB(t *testing.T) *gorm.DB {
	t.Helper()
	snapDBOnce.Do(func() {
		dsn := os.Getenv("DATABASE_URL")
		if dsn == "" {
			dsn = "postgres://localhost/hospital_edss?sslmode=disable"
		}
		db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
		if err != nil {
			snapDBErr = err
			return
		}
		sqlDB, err := db.DB()
		if err != nil {
			snapDBErr = err
			return
		}
		sqlDB.SetMaxOpenConns(8)
		if err := sqlDB.Ping(); err != nil {
			snapDBErr = err
			return
		}
		snapDBPool = db
	})
	if snapDBErr != nil {
		t.Skipf("postgres 不可达: %v", snapDBErr)
	}
	return snapDBPool
}

type snapEnvelope struct {
	Code    int             `json:"code"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data"`
	TraceID string          `json:"trace_id"`
	Ts      int64           `json:"ts"`
}

func snapGet(t *testing.T, path string) (int, snapEnvelope) {
	t.Helper()
	db := snapDB(t)
	r := router.Build(&router.Deps{DB: db, Clock: clock.New(db)})
	req := httptest.NewRequest(http.MethodGet, path, nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var body snapEnvelope
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("包络反序列化: %v body=%s", err, w.Body.String())
	}
	return w.Code, body
}

type snapData struct {
	ServerTime string `json:"server_time"`
	Status     struct {
		Level     string `json:"level"`
		Text      string `json:"text"`
		Desc      string `json:"desc"`
		AlertOpen struct {
			Urgent int `json:"urgent"`
			Major  int `json:"major"`
			Minor  int `json:"minor"`
		} `json:"alert_open"`
	} `json:"status"`
	Kpis []struct {
		Code      string    `json:"code"`
		Name      string    `json:"name"`
		Value     float64   `json:"value"`
		Unit      string    `json:"unit"`
		PrevValue float64   `json:"prev_value"`
		DeltaPct  float64   `json:"delta_pct"`
		Direction int       `json:"direction"`
		Spark     []float64 `json:"spark"`
		Status    string    `json:"status"`
	} `json:"kpis"`
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
		Points []struct {
			DeptID   int64   `json:"dept_id"`
			Name     string  `json:"name"`
			Category string  `json:"category"`
			Cmi      float64 `json:"cmi"`
			Profit   float64 `json:"profit"`
			CaseCnt  int64   `json:"case_cnt"`
			Quadrant int     `json:"quadrant"`
		} `json:"points"`
	} `json:"drg_quadrant"`
	Buildings []struct {
		Code       string `json:"code"`
		Name       string `json:"name"`
		Status     string `json:"status"`
		Badge      string `json:"badge"`
		BadgeLevel string `json:"badge_level"`
		Anchor     struct {
			X float64 `json:"x"`
			Y float64 `json:"y"`
		} `json:"anchor"`
		Metrics       map[string]float64 `json:"metrics"`
		PrimaryMetric struct {
			Key   string  `json:"key"`
			Label string  `json:"label"`
			Unit  string  `json:"unit"`
			Max   float64 `json:"max"`
		} `json:"primary_metric"`
	} `json:"buildings"`
	DeptRanking []struct {
		Rank     int     `json:"rank"`
		DeptID   int64   `json:"dept_id"`
		Name     string  `json:"name"`
		Category string  `json:"category"`
		Cmi      float64 `json:"cmi"`
		SurgCnt  int64   `json:"surg_cnt"`
		Alos     float64 `json:"alos"`
		Profit   float64 `json:"profit"`
		EffScore float64 `json:"eff_score"`
	} `json:"dept_ranking"`
	Alerts struct {
		TotalOpen int `json:"total_open"`
		List      []struct {
			ID         int64  `json:"id"`
			Level      string `json:"level"`
			Title      string `json:"title"`
			Dept       string `json:"dept"`
			OccurredAt string `json:"occurred_at"`
		} `json:"list"`
	} `json:"alerts"`
	Trends struct {
		Days   int                  `json:"days"`
		Dates  []string             `json:"dates"`
		Series map[string][]float64 `json:"series"`
	} `json:"trends"`
}

func decodeSnap(t *testing.T, b snapEnvelope) snapData {
	t.Helper()
	var d snapData
	if err := json.Unmarshal(b.Data, &d); err != nil {
		t.Fatalf("data 反序列化: %v raw=%s", err, string(b.Data))
	}
	return d
}

// §14.1 注10/§13.1 冻结表(与 handler 内常量逐字一致,测试独立再写一份防同步漂移漏检)
var snapWantFrozen = map[string][2]float64{
	"神经外科":      {1.68, -12.8},
	"心血管内科":     {1.42, 86.4},
	"骨科":        {1.36, 124.6},
	"肿瘤科":       {1.24, -34.6},
	"普通外科":      {1.18, 98.2},
	"呼吸与危重症医学科": {1.12, 42.8},
	"神经内科":      {0.94, 38.2},
	"儿科":        {0.68, 28.4},
}

func snapQuadrantOf(cmi, profit float64) int {
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

func TestScreenSnapshot(t *testing.T) {
	status, b := snapGet(t, "/api/v1/screen/snapshot")
	if status != http.StatusOK {
		t.Fatalf("HTTP status=%d want 200 body=%s", status, string(b.Data))
	}
	if b.Code != 0 || b.Message != "ok" {
		t.Fatalf("包络 code=%d message=%q want 0/ok", b.Code, b.Message)
	}
	if b.TraceID == "" || b.Ts <= 0 {
		t.Fatalf("包络五要素缺失: trace_id=%q ts=%d", b.TraceID, b.Ts)
	}

	// 顶层 8 键在(反序列化进 map 验键集)
	var keys map[string]json.RawMessage
	if err := json.Unmarshal(b.Data, &keys); err != nil {
		t.Fatalf("data 非对象: %v", err)
	}
	for _, k := range []string{"server_time", "status", "kpis", "drg_quadrant", "buildings", "dept_ranking", "alerts", "trends"} {
		if _, ok := keys[k]; !ok {
			t.Fatalf("data 缺顶层键 %q", k)
		}
	}

	d := decodeSnap(t, b)

	if d.ServerTime != "2026-10-28T09:00:00+08:00" {
		t.Fatalf("server_time=%q want 2026-10-28T09:00:00+08:00", d.ServerTime)
	}

	// status:urgent 开告警/jz 楼 alert → level=alert;text/desc 文案非空
	if d.Status.Level != "alert" {
		t.Fatalf("status.level=%q want alert(库内 urgent=1 + jz=alert)", d.Status.Level)
	}
	if d.Status.Text == "" || d.Status.Desc == "" {
		t.Fatalf("status text/desc 空: %+v", d.Status)
	}
	ao := d.Status.AlertOpen
	if ao.Urgent != 1 || ao.Major != 2 || ao.Minor != 2 {
		t.Fatalf("alert_open=%+v want {1,2,2}", ao)
	}

	// kpis:固定 4 项,value==spark 末点,trends.series 同源同值
	if len(d.Kpis) != 4 {
		t.Fatalf("kpis len=%d want 4", len(d.Kpis))
	}
	sparkByCode := map[string][]float64{}
	for _, k := range d.Kpis {
		if len(k.Spark) == 0 {
			t.Fatalf("kpi %s spark 空", k.Code)
		}
		if k.Value != k.Spark[len(k.Spark)-1] {
			t.Fatalf("kpi %s value=%v != spark末点=%v", k.Code, k.Value, k.Spark[len(k.Spark)-1])
		}
		sparkByCode[k.Code] = k.Spark
	}
	for _, code := range []string{"OP_DAILY_VISITS", "IP_IN_HOSP", "BED_USE_RATE", "SURG_DAILY_CNT"} {
		if _, ok := sparkByCode[code]; !ok {
			t.Fatalf("kpis 缺 code %s", code)
		}
		s := d.Trends.Series[code]
		if len(s) != len(sparkByCode[code]) {
			t.Fatalf("trends.series[%s] len=%d want %d", code, len(s), len(sparkByCode[code]))
		}
		for i := range s {
			if s[i] != sparkByCode[code][i] {
				t.Fatalf("trends.series[%s][%d]=%v != kpi spark %v", code, i, s[i], sparkByCode[code][i])
			}
		}
	}

	// drg_quadrant:常量块+冻结值+象限对下发值实算
	if d.DrgQuadrant.Period != "d30" || d.DrgQuadrant.PeriodLabel != "近30日" {
		t.Fatalf("drg period=%q label=%q want d30/近30日", d.DrgQuadrant.Period, d.DrgQuadrant.PeriodLabel)
	}
	if d.DrgQuadrant.Axis.X != "DRG盈亏(万元)" || d.DrgQuadrant.Axis.Y != "CMI" ||
		d.DrgQuadrant.Split.X != 0 || d.DrgQuadrant.Split.Y != 1.0 {
		t.Fatalf("drg axis/split 不符: %+v %+v", d.DrgQuadrant.Axis, d.DrgQuadrant.Split)
	}
	if len(d.DrgQuadrant.Points) == 0 {
		t.Fatal("drg_quadrant.points 空")
	}
	frozenHit := map[string]bool{}
	for _, p := range d.DrgQuadrant.Points {
		if fz, ok := snapWantFrozen[p.Name]; ok {
			frozenHit[p.Name] = true
			if p.Cmi != fz[0] || p.Profit != fz[1] {
				t.Fatalf("drg 冻结科室 %s cmi=%v profit=%v want %v/%v", p.Name, p.Cmi, p.Profit, fz[0], fz[1])
			}
		}
		if q := snapQuadrantOf(p.Cmi, p.Profit); p.Quadrant != q {
			t.Fatalf("drg %s quadrant=%d want %d(对下发值实算)", p.Name, p.Quadrant, q)
		}
	}
	if !frozenHit["神经内科"] {
		t.Fatal("drg_quadrant.points 未命中冻结科室 神经内科")
	}

	// buildings:四楼契约 anchor 直发+primary_metric.key ∈ metrics 键集
	wantAnchor := map[string][2]float64{"mz": {24.0, 36.2}, "wk": {51.0, 23.7}, "jz": {71.8, 42.4}, "yj": {57.1, 39.1}}
	if len(d.Buildings) != 4 {
		t.Fatalf("buildings len=%d want 4", len(d.Buildings))
	}
	for _, bd := range d.Buildings {
		a, ok := wantAnchor[bd.Code]
		if !ok {
			t.Fatalf("buildings 出现契约外 code %q", bd.Code)
		}
		if bd.Anchor.X != a[0] || bd.Anchor.Y != a[1] {
			t.Fatalf("%s anchor=%v/%v want %v/%v", bd.Code, bd.Anchor.X, bd.Anchor.Y, a[0], a[1])
		}
		if bd.Anchor.X < 0 || bd.Anchor.X > 100 || bd.Anchor.Y < 0 || bd.Anchor.Y > 100 {
			t.Fatalf("%s anchor 越界 0-100: %+v", bd.Code, bd.Anchor)
		}
		if _, ok := bd.Metrics[bd.PrimaryMetric.Key]; !ok {
			t.Fatalf("%s primary_metric.key=%q 不在 metrics 键集 %v", bd.Code, bd.PrimaryMetric.Key, bd.Metrics)
		}
	}
	// wk 楼 bed_use_rate ×100 口径(库 0.9333→93.3)
	for _, bd := range d.Buildings {
		if bd.Code == "wk" && bd.Metrics["bed_use_rate"] != 93.3 {
			t.Fatalf("wk bed_use_rate=%v want 93.3", bd.Metrics["bed_use_rate"])
		}
	}

	// dept_ranking:冻结科室逐字值(神经内科 0.94/38.2)
	if len(d.DeptRanking) == 0 {
		t.Fatal("dept_ranking 空")
	}
	foundSJNK := false
	for i, r := range d.DeptRanking {
		if r.Rank != i+1 {
			t.Fatalf("dept_ranking[%d].rank=%d 非升序名次", i, r.Rank)
		}
		if r.Name == "神经内科" {
			foundSJNK = true
			if r.Cmi != 0.94 || r.Profit != 38.2 {
				t.Fatalf("dept_ranking 神经内科 cmi=%v profit=%v want 0.94/38.2", r.Cmi, r.Profit)
			}
		}
		if fz, ok := snapWantFrozen[r.Name]; ok && (r.Cmi != fz[0] || r.Profit != fz[1]) {
			t.Fatalf("dept_ranking 冻结科室 %s cmi=%v profit=%v want %v/%v", r.Name, r.Cmi, r.Profit, fz[0], fz[1])
		}
	}
	if !foundSJNK {
		t.Fatal("dept_ranking 未命中 神经内科")
	}

	// alerts:total_open==len(list)==alert_open 三档合计;occurred_at 降序
	if d.Alerts.TotalOpen != len(d.Alerts.List) {
		t.Fatalf("alerts.total_open=%d != len(list)=%d", d.Alerts.TotalOpen, len(d.Alerts.List))
	}
	if d.Alerts.TotalOpen != ao.Urgent+ao.Major+ao.Minor {
		t.Fatalf("alerts.total_open=%d != alert_open 合计 %d", d.Alerts.TotalOpen, ao.Urgent+ao.Major+ao.Minor)
	}
	for i := 1; i < len(d.Alerts.List); i++ {
		if d.Alerts.List[i-1].OccurredAt < d.Alerts.List[i].OccurredAt {
			t.Fatalf("alerts.list 非 occurred_at 降序: [%d]=%s < [%d]=%s",
				i-1, d.Alerts.List[i-1].OccurredAt, i, d.Alerts.List[i].OccurredAt)
		}
	}

	// trends:末日=BASE_DATE MM-DD;days=7
	if d.Trends.Days != 7 || len(d.Trends.Dates) != 7 {
		t.Fatalf("trends.days=%d dates=%v want 7 天", d.Trends.Days, d.Trends.Dates)
	}
	if d.Trends.Dates[len(d.Trends.Dates)-1] != "10-28" {
		t.Fatalf("trends.dates 末日=%q want 10-28", d.Trends.Dates[len(d.Trends.Dates)-1])
	}
}
