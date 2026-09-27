// §11.1 assets 端点 httptest:实库只读;锚 sim.clock=2026-10-28(任务书 e3-task-assets)
package handler

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"regexp"
	"testing"

	"github.com/gin-gonic/gin"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/repo"
)

type assetsEnvelope struct {
	Code    int             `json:"code"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data"`
	TraceID string          `json:"trace_id"`
	Ts      int64           `json:"ts"`
}

type assetsRespData struct {
	Stats []struct {
		Label      string `json:"label"`
		Value      string `json:"value"`
		Unit       string `json:"unit"`
		Delta      string `json:"delta"`
		DeltaLabel string `json:"delta_label"`
		Dir        string `json:"dir"`
		Note       string `json:"note"`
	} `json:"stats"`
	EnergyTrend struct {
		Unit        string    `json:"unit"`
		Months      []string  `json:"months"`
		Total       []float64 `json:"total"`
		Electricity []float64 `json:"electricity"`
		Water       []float64 `json:"water"`
		Gas         []float64 `json:"gas"`
	} `json:"energy_trend"`
	StockAlerts []struct {
		Name  string `json:"name"`
		Days  int    `json:"days"`
		Level string `json:"level"`
	} `json:"stock_alerts"`
	LargeEquipments struct {
		Columns []struct {
			Key string `json:"key"`
		} `json:"columns"`
		Rows []struct {
			Name     string  `json:"name"`
			Dept     string  `json:"dept"`
			Count    int     `json:"count"`
			OpenRate float64 `json:"open_rate"`
			Monthly  string  `json:"monthly"`
			Income   string  `json:"income"`
			Roi      string  `json:"roi"`
		} `json:"rows"`
	} `json:"large_equipments"`
}

func assetsRouter(t *testing.T) *gin.Engine {
	t.Helper()
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://localhost/hospital_edss?sslmode=disable"
	}
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatalf("gorm.Open: %v", err)
	}
	sqlDB, err := db.DB()
	if err != nil {
		t.Fatalf("db.DB: %v", err)
	}
	if err := sqlDB.Ping(); err != nil {
		t.Skipf("postgres 不可达(%s): %v", dsn, err)
	}
	h := NewStaffHandler(repo.NewStaffRepo(db, clock.New(db)))
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(func(c *gin.Context) { c.Set("trace_id", "test-trace"); c.Next() })
	r.GET("/api/v1/workbench/assets", h.Assets)
	return r
}

func getAssetsData(t *testing.T, r *gin.Engine) (assetsEnvelope, assetsRespData) {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/workbench/assets", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("HTTP status=%d body=%s", w.Code, w.Body.String())
	}
	var env assetsEnvelope
	if err := json.Unmarshal(w.Body.Bytes(), &env); err != nil {
		t.Fatalf("包络反序列化: %v body=%s", err, w.Body.String())
	}
	var d assetsRespData
	if err := json.Unmarshal(env.Data, &d); err != nil {
		t.Fatalf("data 反序列化: %v", err)
	}
	return env, d
}

func TestStaffAssetsEnvelope(t *testing.T) {
	env, _ := getAssetsData(t, assetsRouter(t))
	if env.Code != 0 || env.Message != "ok" {
		t.Fatalf("包络 code=%d message=%q want 0/ok", env.Code, env.Message)
	}
	if env.TraceID != "test-trace" {
		t.Fatalf("trace_id=%q want test-trace", env.TraceID)
	}
	if env.Ts <= 0 {
		t.Fatalf("ts=%d want >0", env.Ts)
	}
	if len(env.Data) == 0 || string(env.Data) == "null" {
		t.Fatal("data is null")
	}
}

func TestStaffAssetsStats(t *testing.T) {
	_, d := getAssetsData(t, assetsRouter(t))
	if len(d.Stats) != 6 {
		t.Fatalf("stats len=%d want 6", len(d.Stats))
	}
	// 锚 2026-10 当期值(e3-design §11.1 对照 "12.6"/68/"94.2"/"28"/"186"/156)
	want := []struct{ label, value, unit string }{
		{"固定资产总额", "12.6", "亿元"},
		{"大型设备", "68", "台"},
		{"设备开机率", "94.2", "%"},
		{"库存周转天数", "28", "天"},
		{"本月能耗费用", "186", "万元"},
		{"后勤工单", "156", "单"},
	}
	for i, w := range want {
		s := d.Stats[i]
		if s.Label != w.label || s.Value != w.value || s.Unit != w.unit {
			t.Fatalf("stats[%d]=%+v want label=%q value=%q unit=%q", i, s, w.label, w.value, w.unit)
		}
	}
	if d.Stats[1].Note != "单价 ≥100 万" {
		t.Fatalf("大型设备 note=%q want 单价 ≥100 万", d.Stats[1].Note)
	}
	if d.Stats[5].Note != "完结率 92%" {
		t.Fatalf("后勤工单 note=%q want 完结率 92%%", d.Stats[5].Note)
	}
	dirEnum := map[string]bool{"up": true, "down": true, "flat": true}
	for i, s := range d.Stats {
		if s.Dir != "" && !dirEnum[s.Dir] {
			t.Fatalf("stats[%d].dir=%q 非三态", i, s.Dir)
		}
	}
}

// 契约 §11.1 delta 纪律:两台数项(大型设备/后勤工单)无 delta/dir/delta_label;
// amt/rate 类→相对 ±x.x%、days 类→绝对 ±N天,月指标 delta_label=较上月
func TestStaffAssetsDeltaContract(t *testing.T) {
	_, d := getAssetsData(t, assetsRouter(t))
	if len(d.Stats) != 6 {
		t.Fatalf("stats len=%d want 6", len(d.Stats))
	}
	for _, i := range []int{1, 5} {
		s := d.Stats[i]
		if s.Delta != "" || s.Dir != "" || s.DeltaLabel != "" {
			t.Fatalf("stats[%d](%s) 契约无 delta,实得 delta=%q dir=%q delta_label=%q",
				i, s.Label, s.Delta, s.Dir, s.DeltaLabel)
		}
	}
	relRe := regexp.MustCompile(`^[+-]\d+\.\d%$`)
	for _, i := range []int{0, 2, 4} {
		s := d.Stats[i]
		if s.Delta == "持平" {
			continue
		}
		if !relRe.MatchString(s.Delta) {
			t.Fatalf("stats[%d](%s) delta=%q 非相对变动 ±x.x%%", i, s.Label, s.Delta)
		}
	}
	if d.Stats[3].Delta != "持平" && !regexp.MustCompile(`^[+-]\d+天$`).MatchString(d.Stats[3].Delta) {
		t.Fatalf("stats[3](库存周转天数) delta=%q 非绝对变动 ±N天", d.Stats[3].Delta)
	}
	for _, i := range []int{0, 2, 3, 4} {
		if d.Stats[i].DeltaLabel != "较上月" {
			t.Fatalf("stats[%d].delta_label=%q want 较上月", i, d.Stats[i].DeltaLabel)
		}
	}
}

func TestStaffAssetsEnergyTrend(t *testing.T) {
	_, d := getAssetsData(t, assetsRouter(t))
	tr := d.EnergyTrend
	if tr.Unit != "万元" {
		t.Fatalf("energy.unit=%q want 万元", tr.Unit)
	}
	wantMonths := []string{"5月", "6月", "7月", "8月", "9月", "10月"}
	for _, arr := range [][]float64{tr.Total, tr.Electricity, tr.Water, tr.Gas} {
		if len(arr) != 6 {
			t.Fatalf("energy 序列长度不齐: %+v", tr)
		}
	}
	for i, m := range wantMonths {
		if tr.Months[i] != m {
			t.Fatalf("months[%d]=%q want %q", i, tr.Months[i], m)
		}
	}
	// total 必须=三分项Σ(e3-design:不独查)
	for i := 0; i < 6; i++ {
		sum := tr.Electricity[i] + tr.Water[i] + tr.Gas[i]
		if tr.Total[i] != sum {
			t.Fatalf("total[%d]=%v ≠ 三分项Σ %v", i, tr.Total[i], sum)
		}
	}
	// 锚:10 月 total=186(=ENERGY_COST 186万 自洽)
	if tr.Total[5] != 186 {
		t.Fatalf("total[5]=%v want 186", tr.Total[5])
	}
}

func TestStaffAssetsStockAlerts(t *testing.T) {
	_, d := getAssetsData(t, assetsRouter(t))
	if len(d.StockAlerts) != 6 {
		t.Fatalf("stock_alerts len=%d want 6", len(d.StockAlerts))
	}
	levelEnum := map[string]bool{"urgent": true, "major": true, "minor": true}
	wantDays := []int{46, 42, 36, 34, 31, 29}
	wantLevel := []string{"urgent", "urgent", "major", "major", "major", "major"}
	for i, a := range d.StockAlerts {
		if !levelEnum[a.Level] {
			t.Fatalf("alerts[%d].level=%q 非枚举", i, a.Level)
		}
		if a.Days != wantDays[i] || a.Level != wantLevel[i] {
			t.Fatalf("alerts[%d]=%+v want days=%d level=%s", i, a, wantDays[i], wantLevel[i])
		}
		if i > 0 && a.Days > d.StockAlerts[i-1].Days {
			t.Fatalf("alerts 未按 days DESC")
		}
		if a.Name == "" {
			t.Fatalf("alerts[%d].name 空", i)
		}
	}
}

func TestStaffAssetsLargeEquipments(t *testing.T) {
	_, d := getAssetsData(t, assetsRouter(t))
	eq := d.LargeEquipments
	wantCols := []string{"name", "dept", "count", "open_rate", "monthly", "income", "roi"}
	if len(eq.Columns) != len(wantCols) {
		t.Fatalf("columns len=%d want %d", len(eq.Columns), len(wantCols))
	}
	for i, k := range wantCols {
		if eq.Columns[i].Key != k {
			t.Fatalf("columns[%d].key=%q want %q", i, eq.Columns[i].Key, k)
		}
	}
	// 契约白名单序 + 实测 income/roi(e3-design §11.1)
	want := []struct {
		name   string
		income string
		roi    string
	}{
		{"3.0T 核磁共振", "507", "良好"},
		{"256 排 CT", "409", "良好"},
		{"DSA 血管造影机", "304", "良好"},
		{"直线加速器", "273", "良好"},
		{"PET-CT", "162", "偏低"},
		{"高清电子胃肠镜", "225", "一般"},
		{"体外冲击波碎石机", "46", "偏低"},
	}
	if len(eq.Rows) != len(want) {
		t.Fatalf("rows len=%d want %d", len(eq.Rows), len(want))
	}
	roiEnum := map[string]bool{"良好": true, "一般": true, "偏低": true}
	for i, w := range want {
		rw := eq.Rows[i]
		if rw.Name != w.name || rw.Income != w.income || rw.Roi != w.roi {
			t.Fatalf("rows[%d]=%+v want name=%q income=%q roi=%q", i, rw, w.name, w.income, w.roi)
		}
		if !roiEnum[rw.Roi] {
			t.Fatalf("rows[%d].roi=%q 非 roi_level 枚举", i, rw.Roi)
		}
		if rw.OpenRate <= 0 || rw.OpenRate > 100 {
			t.Fatalf("rows[%d].open_rate=%v 越界", i, rw.OpenRate)
		}
		if rw.Count <= 0 || rw.Dept == "" || rw.Monthly == "" {
			t.Fatalf("rows[%d] 字段异常: %+v", i, rw)
		}
	}
}
