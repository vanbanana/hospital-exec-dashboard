// §9.1 patient 端点 httptest:实库只读;锚 sim.clock=2026-10-28(任务书 e3-task-patient)
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

type patientEnvelope struct {
	Code    int             `json:"code"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data"`
	TraceID string          `json:"trace_id"`
	Ts      int64           `json:"ts"`
}

type patientStatItem struct {
	Label      string `json:"label"`
	Value      string `json:"value"`
	Unit       string `json:"unit"`
	Delta      string `json:"delta"`
	DeltaLabel string `json:"delta_label"`
	Dir        string `json:"dir"`
}

type patientData struct {
	Stats             []patientStatItem `json:"stats"`
	SatisfactionTrend struct {
		Unit       string    `json:"unit"`
		Months     []string  `json:"months"`
		Outpatient []float64 `json:"outpatient"`
		Inpatient  []float64 `json:"inpatient"`
	} `json:"satisfaction_trend"`
	ChannelDistribution struct {
		Unit string `json:"unit"`
		List []struct {
			Name  string `json:"name"`
			Value int    `json:"value"`
		} `json:"list"`
	} `json:"channel_distribution"`
	ComplaintsPraises struct {
		Columns []struct {
			Key   string `json:"key"`
			Title string `json:"title"`
		} `json:"columns"`
		Rows []struct {
			Date    string `json:"date"`
			Type    string `json:"type"`
			Dept    string `json:"dept"`
			Channel string `json:"channel"`
			Content string `json:"content"`
			Status  string `json:"status"`
			Score   string `json:"score"`
		} `json:"rows"`
	} `json:"complaints_praises"`
}

func patientRouter(t *testing.T) *gin.Engine {
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
	r.GET("/api/v1/workbench/patient", h.Patient)
	return r
}

func getPatientData(t *testing.T, r *gin.Engine) patientData {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, "/api/v1/workbench/patient", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("HTTP status=%d body=%s", w.Code, w.Body.String())
	}
	var env patientEnvelope
	if err := json.Unmarshal(w.Body.Bytes(), &env); err != nil {
		t.Fatalf("包络反序列化: %v body=%s", err, w.Body.String())
	}
	var d patientData
	if err := json.Unmarshal(env.Data, &d); err != nil {
		t.Fatalf("data 反序列化: %v", err)
	}
	return d
}

func TestStaffPatientEnvelope(t *testing.T) {
	r := patientRouter(t)
	req := httptest.NewRequest(http.MethodGet, "/api/v1/workbench/patient", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("HTTP status=%d body=%s", w.Code, w.Body.String())
	}
	var env patientEnvelope
	if err := json.Unmarshal(w.Body.Bytes(), &env); err != nil {
		t.Fatalf("包络反序列化: %v", err)
	}
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

func TestStaffPatientStats(t *testing.T) {
	d := getPatientData(t, patientRouter(t))
	if len(d.Stats) != 6 {
		t.Fatalf("stats len=%d want 6", len(d.Stats))
	}
	// 锚 2026-10 当期值(e3-design §9.1 对照 96.4/97.2/24/86/17/88.6)
	want := []struct{ label, value, unit, delta, dir string }{
		{"门诊满意度", "96.4", "%", "", ""},
		{"住院满意度", "97.2", "%", "", ""},
		{"本月投诉", "24", "件", "-2件", "down"},
		{"本月表扬", "86", "件", "+6件", "up"},
		{"平均候诊", "17", "分钟", "持平", "flat"},
		{"网约挂号率", "88.6", "%", "", ""},
	}
	dirEnum := map[string]bool{"up": true, "down": true, "flat": true}
	for i, w := range want {
		s := d.Stats[i]
		if s.Label != w.label || s.Value != w.value || s.Unit != w.unit {
			t.Fatalf("stats[%d]=%+v want label=%q value=%q unit=%q", i, s, w.label, w.value, w.unit)
		}
		if s.Dir != "" && !dirEnum[s.Dir] {
			t.Fatalf("stats[%d].dir=%q 非三态", i, s.Dir)
		}
		if w.delta != "" && s.Delta != w.delta {
			t.Fatalf("stats[%d].delta=%q want %q", i, s.Delta, w.delta)
		}
		if w.dir != "" && s.Dir != w.dir {
			t.Fatalf("stats[%d].dir=%q want %q", i, s.Dir, w.dir)
		}
	}
}

func TestStaffPatientSatisfactionTrend(t *testing.T) {
	d := getPatientData(t, patientRouter(t))
	tr := d.SatisfactionTrend
	if tr.Unit != "%" {
		t.Fatalf("trend.unit=%q want %%", tr.Unit)
	}
	wantMonths := []string{"5月", "6月", "7月", "8月", "9月", "10月"}
	if len(tr.Months) != 6 || len(tr.Outpatient) != 6 || len(tr.Inpatient) != 6 {
		t.Fatalf("trend 长度 months=%d op=%d ip=%d want 6", len(tr.Months), len(tr.Outpatient), len(tr.Inpatient))
	}
	for i, m := range wantMonths {
		if tr.Months[i] != m {
			t.Fatalf("months[%d]=%q want %q", i, tr.Months[i], m)
		}
	}
	if tr.Outpatient[5] != 96.4 || tr.Inpatient[5] != 97.2 {
		t.Fatalf("trend 末点 op=%v ip=%v want 96.4/97.2", tr.Outpatient[5], tr.Inpatient[5])
	}
}

func TestStaffPatientChannel(t *testing.T) {
	d := getPatientData(t, patientRouter(t))
	cd := d.ChannelDistribution
	if cd.Unit != "%" {
		t.Fatalf("channel.unit=%q want %%", cd.Unit)
	}
	// dict reg_channel 序 + MTD 实测 [38,24,18,14,6]
	want := []struct {
		name  string
		value int
	}{
		{"微信小程序", 38}, {"自助机", 24}, {"人工窗口", 18}, {"官方APP", 14}, {"电话预约", 6},
	}
	if len(cd.List) != len(want) {
		t.Fatalf("channel list len=%d want %d", len(cd.List), len(want))
	}
	for i, w := range want {
		if cd.List[i].Name != w.name || cd.List[i].Value != w.value {
			t.Fatalf("channel[%d]=%+v want %+v", i, cd.List[i], w)
		}
	}
}

func TestStaffPatientComplaintsPraises(t *testing.T) {
	d := getPatientData(t, patientRouter(t))
	cp := d.ComplaintsPraises
	wantCols := []string{"date", "type", "dept", "channel", "content", "status", "score"}
	if len(cp.Columns) != len(wantCols) {
		t.Fatalf("columns len=%d want %d", len(cp.Columns), len(wantCols))
	}
	for i, k := range wantCols {
		if cp.Columns[i].Key != k {
			t.Fatalf("columns[%d].key=%q want %q", i, cp.Columns[i].Key, k)
		}
	}
	if len(cp.Rows) != 6 {
		t.Fatalf("rows len=%d want 6", len(cp.Rows))
	}
	statusEnum := map[string]bool{"待核实": true, "处理中": true, "已整改": true, "已办结": true, "已归档": true}
	typeEnum := map[string]bool{"投诉": true, "表扬": true}
	scoreEnum := map[string]bool{"非常满意": true, "满意": true, "基本满意": true, "待评价": true}
	dateRe := regexp.MustCompile(`^\d{4}-\d{2}-\d{2}$`)
	prev := ""
	for i, rw := range cp.Rows {
		if !dateRe.MatchString(rw.Date) {
			t.Fatalf("rows[%d].date=%q 非 YYYY-MM-DD", i, rw.Date)
		}
		// 未来行必须过滤(sim.clock=2026-10-28,库内含 242 行未来播种数据)
		if rw.Date > "2026-10-28" {
			t.Fatalf("rows[%d].date=%q 为未来行(>2026-10-28)", i, rw.Date)
		}
		if i > 0 && rw.Date > prev {
			t.Fatalf("rows[%d].date=%q 未按 DESC 排序", i, rw.Date)
		}
		prev = rw.Date
		if !statusEnum[rw.Status] {
			t.Fatalf("rows[%d].status=%q 非五态枚举", i, rw.Status)
		}
		if !typeEnum[rw.Type] {
			t.Fatalf("rows[%d].type=%q 非投诉/表扬", i, rw.Type)
		}
		if !scoreEnum[rw.Score] {
			t.Fatalf("rows[%d].score=%q 非回访评价枚举", i, rw.Score)
		}
		if rw.Dept == "" || rw.Channel == "" || rw.Content == "" {
			t.Fatalf("rows[%d] 存在空列: %+v", i, rw)
		}
	}
}
