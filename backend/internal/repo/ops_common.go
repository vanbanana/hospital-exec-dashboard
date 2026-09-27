// Package repo 综合运营域(E2)共享数据访问——薄查询层。
// 口径对齐 docs/api-contract.md §4/§5/§6/§12 与 src/mock/*.ts(见 /tmp/backend-orch/e2-design.md)。
// 纪律:ads/dws 已预聚合,只加窗口条件不重造管线;level-3 医疗组行必须经 dept level 过滤防双算。
package repo

import (
	"context"
	"time"

	"gorm.io/gorm"

	"hospital-edss/internal/clock"
)

// Ops E2 四端点(overview/medical/operations/compare)共享 repo
type Ops struct {
	db *gorm.DB
	ck *clock.Source
}

func NewOps(db *gorm.DB, ck *clock.Source) *Ops { return &Ops{db: db, ck: ck} }

// Today 业务"今天"(sim.clock 唯一时间源)
/* ========== range 窗口(契约注 + mock rangeSlice 口径) ========== */

// RangeWin 月度窗口 [Start,End),Months 为窗口内月首序列
type RangeWin struct {
	Start  time.Time
	End    time.Time
	Months []time.Time
}

// WinForRange 本月=当月;本季=近 3 月(mock [7,10) 非日历 Q4);本年=当年 1 月至当月(契约 §4 注1)
func WinForRange(today time.Time, rk string) RangeWin {
	y, m, _ := today.Date()
	cur := time.Date(y, m, 1, 0, 0, 0, 0, today.Location())
	start := time.Date(y, 1, 1, 0, 0, 0, 0, today.Location())
	switch rk {
	case "本月":
		start = cur
	case "本季":
		start = cur.AddDate(0, -2, 0)
	}
	end := cur.AddDate(0, 1, 0)
	var months []time.Time
	for t := start; t.Before(end); t = t.AddDate(0, 1, 0) {
		months = append(months, t)
	}
	return RangeWin{Start: start, End: end, Months: months}
}

// LastYear 同比窗口:整体平移 −1 年(2025 数据齐)
func (w RangeWin) LastYear() RangeWin {
	ms := make([]time.Time, len(w.Months))
	for i, t := range w.Months {
		ms[i] = t.AddDate(-1, 0, 0)
	}
	return RangeWin{Start: w.Start.AddDate(-1, 0, 0), End: w.End.AddDate(-1, 0, 0), Months: ms}
}

/* ========== 院级聚合 dws.hospital_oper_day(单院区 main) ========== */

// HospAgg 院级聚合行;金额=元,比率已展开
type HospAgg struct {
	Month   time.Time `gorm:"column:month"`
	Outpt   int64     `gorm:"column:outpt"`
	Emerg   int64     `gorm:"column:emerg"`
	Disch   int64     `gorm:"column:disch"`
	Admit   int64     `gorm:"column:admit"`
	InHosp  int64     `gorm:"column:in_hosp"`
	BedDays int64     `gorm:"column:bed_days"` // Σbed_open(床日)
	UseDays int64     `gorm:"column:use_days"` // Σbed_used
	BedOpen float64   `gorm:"column:bed_open"` // 日均开放床位(周转分母)
	Alos    float64   `gorm:"column:alos"`     // 出院加权平均住院日
	Revenue float64   `gorm:"column:revenue"`
	Cost    float64   `gorm:"column:cost"`
	Profit  float64   `gorm:"column:profit"`
	DrugFee float64   `gorm:"column:drug_fee"`
	MatFee  float64   `gorm:"column:mat_fee"`
}

const hospAggCols = `
	COALESCE(SUM(outpt_cnt),0) AS outpt,
	COALESCE(SUM(emerg_cnt),0) AS emerg,
	COALESCE(SUM(discharge_cnt),0) AS disch,
	COALESCE(SUM(admit_cnt),0) AS admit,
	0 AS in_hosp,
	COALESCE(SUM(bed_open),0) AS bed_days,
	COALESCE(SUM(bed_used),0) AS use_days,
	COALESCE(AVG(bed_open),0) AS bed_open,
	COALESCE(SUM(alos*discharge_cnt)/NULLIF(SUM(discharge_cnt),0),0) AS alos,
	COALESCE(SUM(revenue),0) AS revenue,
	COALESCE(SUM(cost),0) AS cost,
	COALESCE(SUM(profit),0) AS profit,
	COALESCE(SUM(drug_fee),0) AS drug_fee,
	COALESCE(SUM(material_fee),0) AS mat_fee`

// HospMonthly 全年逐月聚合(trend 轴/累计双用)
func (r *Ops) HospMonthly(ctx context.Context, year int) ([]HospAgg, error) {
	var rows []HospAgg
	err := r.db.WithContext(ctx).Raw(
		`SELECT date_trunc('month',date)::date AS month,`+hospAggCols+`
		 FROM dws.hospital_oper_day
		 WHERE date >= ? AND date < ?
		 GROUP BY 1 ORDER BY 1`,
		time.Date(year, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(year+1, 1, 1, 0, 0, 0, 0, time.UTC)).Scan(&rows).Error
	return rows, err
}

// HospSum 窗口聚合(累计 stats)
func (r *Ops) HospSum(ctx context.Context, w RangeWin) (HospAgg, error) {
	var row HospAgg
	err := r.db.WithContext(ctx).Raw(
		`SELECT `+hospAggCols+` FROM dws.hospital_oper_day WHERE date >= ? AND date < ?`,
		w.Start, w.End).Scan(&row).Error
	return row, err
}

// HospDay 单日行(live_inpatient 在院/入院/出院)
func (r *Ops) HospDay(ctx context.Context, day time.Time) (HospAgg, error) {
	var row HospAgg
	err := r.db.WithContext(ctx).Raw(
		`SELECT outpt_cnt AS outpt, emerg_cnt AS emerg, discharge_cnt AS disch,
			admit_cnt AS admit, in_hosp_cnt AS in_hosp,
			bed_open AS bed_days, bed_used AS use_days, bed_open AS bed_open,
			alos, revenue, cost, profit, drug_fee, material_fee AS mat_fee
		 FROM dws.hospital_oper_day WHERE date = ?`, day).Scan(&row).Error
	return row, err
}

/* ========== 科室聚合 dws.dept_oper_day(level=2 防医疗组双算) ========== */

// DeptAgg 科室窗口聚合
type DeptAgg struct {
	DeptID  int64   `gorm:"column:dept_id"`
	Name    string  `gorm:"column:name"`
	Outpt   int64   `gorm:"column:outpt"`
	Disch   int64   `gorm:"column:disch"`
	Surg    int64   `gorm:"column:surg"`
	Revenue float64 `gorm:"column:revenue"`
	Cost    float64 `gorm:"column:cost"`
	Profit  float64 `gorm:"column:profit"`
	Alos    float64 `gorm:"column:alos"`
}

// DeptSums 窗口内 level-2 科室聚合;科室全集=dept_domain IN (clinical,platform)
func (r *Ops) DeptSums(ctx context.Context, w RangeWin) ([]DeptAgg, error) {
	var rows []DeptAgg
	err := r.db.WithContext(ctx).Raw(
		`SELECT o.dept_id, d.name,
			COALESCE(SUM(o.outpt_cnt),0) AS outpt,
			COALESCE(SUM(o.discharge_cnt),0) AS disch,
			COALESCE(SUM(o.surg_cnt),0) AS surg,
			COALESCE(SUM(o.revenue),0) AS revenue,
			COALESCE(SUM(o.cost),0) AS cost,
			COALESCE(SUM(o.profit),0) AS profit,
			COALESCE(SUM(o.alos*o.discharge_cnt)/NULLIF(SUM(o.discharge_cnt),0),0) AS alos
		 FROM dws.dept_oper_day o
		 JOIN dim.department d ON d.id = o.dept_id
		 WHERE o.date >= ? AND o.date < ?
		   AND d.level = 2 AND d.dept_domain IN ('clinical','platform')
		 GROUP BY o.dept_id, d.name`, w.Start, w.End).Scan(&rows).Error
	return rows, err
}

/* ========== 费用 dwd.charge_day(in/out 拆分 = 院级收入同源) ========== */

// ChargeSum 全院窗口费用拆分(元)
type ChargeSum struct {
	InFee  float64 `gorm:"column:in_fee"`
	OutFee float64 `gorm:"column:out_fee"`
}

func (r *Ops) ChargeTotals(ctx context.Context, w RangeWin) (ChargeSum, error) {
	var row ChargeSum
	err := r.db.WithContext(ctx).Raw(
		`SELECT COALESCE(SUM(in_fee),0) AS in_fee, COALESCE(SUM(out_fee),0) AS out_fee
		 FROM dwd.charge_day WHERE date >= ? AND date < ?`, w.Start, w.End).Scan(&row).Error
	return row, err
}

// DeptCharge 科室窗口费用拆分(药耗占比/次均/住院收入榜共用)
type DeptCharge struct {
	DeptID  int64   `gorm:"column:dept_id"`
	Name    string  `gorm:"column:name"`
	InFee   float64 `gorm:"column:in_fee"`
	OutFee  float64 `gorm:"column:out_fee"`
	InDrug  float64 `gorm:"column:in_drug"`
	OutDrug float64 `gorm:"column:out_drug"`
	Mat     float64 `gorm:"column:mat"`
}

func (r *Ops) DeptCharges(ctx context.Context, w RangeWin) ([]DeptCharge, error) {
	var rows []DeptCharge
	err := r.db.WithContext(ctx).Raw(
		`SELECT c.dept_id, d.name,
			COALESCE(SUM(c.in_fee),0) AS in_fee,
			COALESCE(SUM(c.out_fee),0) AS out_fee,
			COALESCE(SUM(c.in_fee) FILTER (WHERE c.fee_cat='drug'),0) AS in_drug,
			COALESCE(SUM(c.out_fee) FILTER (WHERE c.fee_cat='drug'),0) AS out_drug,
			COALESCE(SUM(c.in_fee+c.out_fee) FILTER (WHERE c.fee_cat='material'),0) AS mat
		 FROM dwd.charge_day c
		 JOIN dim.department d ON d.id = c.dept_id
		 WHERE c.date >= ? AND c.date < ?
		   AND d.level = 2 AND d.dept_domain IN ('clinical','platform')
		 GROUP BY c.dept_id, d.name`, w.Start, w.End).Scan(&rows).Error
	return rows, err
}

/* ========== 手术 dwd.surgery_case(月度序列与契约 §5 trend 同源) ========== */

// SurgMonthly 全年逐月台次
func (r *Ops) SurgMonthly(ctx context.Context, year int) (map[int]int64, error) {
	var rows []struct {
		M int   `gorm:"column:m"`
		C int64 `gorm:"column:c"`
	}
	err := r.db.WithContext(ctx).Raw(
		`SELECT EXTRACT(MONTH FROM date)::int AS m, COUNT(*) AS c
		 FROM dwd.surgery_case WHERE date >= ? AND date < ? GROUP BY 1`,
		time.Date(year, 1, 1, 0, 0, 0, 0, time.UTC),
		time.Date(year+1, 1, 1, 0, 0, 0, 0, time.UTC)).Scan(&rows).Error
	out := make(map[int]int64, len(rows))
	for _, x := range rows {
		out[x.M] = x.C
	}
	return out, err
}

// SurgAgg 窗口手术聚合(stats 六宫格/distribution 共用)
type SurgAgg struct {
	Total   int64   `gorm:"column:total"`
	Elect   int64   `gorm:"column:elect"`
	MinInv  int64   `gorm:"column:min_inv"`
	L1      int64   `gorm:"column:l1"`
	L2      int64   `gorm:"column:l2"`
	L3      int64   `gorm:"column:l3"`
	L4      int64   `gorm:"column:l4"`
	DoneCnt int64   `gorm:"column:done_cnt"`
	Minutes float64 `gorm:"column:minutes"`
	Rooms   int64   `gorm:"column:rooms"`
}

func (r *Ops) SurgAgg(ctx context.Context, w RangeWin) (SurgAgg, error) {
	var row SurgAgg
	err := r.db.WithContext(ctx).Raw(
		`SELECT COUNT(*) AS total,
			COUNT(*) FILTER (WHERE elective_flag) AS elect,
			COUNT(*) FILTER (WHERE min_invasive) AS min_inv,
			COUNT(*) FILTER (WHERE surg_level=1) AS l1,
			COUNT(*) FILTER (WHERE surg_level=2) AS l2,
			COUNT(*) FILTER (WHERE surg_level=3) AS l3,
			COUNT(*) FILTER (WHERE surg_level=4) AS l4,
			COUNT(*) FILTER (WHERE actual_end IS NOT NULL) AS done_cnt,
			COALESCE(SUM(EXTRACT(EPOCH FROM (actual_end-actual_start))/60),0) AS minutes,
			COUNT(DISTINCT room_no) AS rooms
		 FROM dwd.surgery_case WHERE date >= ? AND date < ?`, w.Start, w.End).Scan(&row).Error
	return row, err
}

// SurgDoing 当日进行中手术数(live_inpatient)
func (r *Ops) SurgDoing(ctx context.Context, day time.Time) (int64, error) {
	var n int64
	err := r.db.WithContext(ctx).Raw(
		`SELECT COUNT(*) FROM dwd.surgery_case WHERE date = ? AND surg_status = 'doing'`,
		day).Scan(&n).Error
	return n, err
}

/* ========== 门诊分时 dwd.outpatient_hourly ========== */

// HourlySum 窗口门诊聚合(次均费用/平均候诊/专家门诊)
type HourlySum struct {
	Visit      int64   `gorm:"column:visit"`
	Expert     int64   `gorm:"column:expert"`
	EmergVisit int64   `gorm:"column:emerg_visit"`
	WaitMinSum float64 `gorm:"column:wait_min_sum"`
	FeeTotal   float64 `gorm:"column:fee_total"`
}

func (r *Ops) HourlySum(ctx context.Context, w RangeWin) (HourlySum, error) {
	var row HourlySum
	err := r.db.WithContext(ctx).Raw(
		`SELECT COALESCE(SUM(visit_cnt),0) AS visit,
			COALESCE(SUM(expert_cnt),0) AS expert,
			COALESCE(SUM(visit_cnt) FILTER (WHERE emerg_flag),0) AS emerg_visit,
			COALESCE(SUM(wait_min_sum),0) AS wait_min_sum,
			COALESCE(SUM(fee_total),0) AS fee_total
		 FROM dwd.outpatient_hourly WHERE stat_time >= ? AND stat_time < ?`,
		w.Start, w.End).Scan(&row).Error
	return row, err
}

// HourlyByHour 近 N 日分时段人次(distribution)
func (r *Ops) HourlyByHour(ctx context.Context, start, end time.Time) (map[int]int64, error) {
	var rows []struct {
		H int   `gorm:"column:h"`
		V int64 `gorm:"column:v"`
	}
	err := r.db.WithContext(ctx).Raw(
		`SELECT EXTRACT(HOUR FROM stat_time)::int AS h, SUM(visit_cnt) AS v
		 FROM dwd.outpatient_hourly WHERE stat_time >= ? AND stat_time < ?
		 GROUP BY 1`, start, end).Scan(&rows).Error
	out := make(map[int]int64, len(rows))
	for _, x := range rows {
		out[x.H] = x.V
	}
	return out, err
}

/* ========== 床位/病区/急诊实况 ========== */

// WardGroup 病区床位占用分组行(住院 tab distribution)
type WardGroup struct {
	Grp  string `gorm:"column:grp"`
	Used int64  `gorm:"column:used"`
	Open int64  `gorm:"column:open"`
}

// WardOccupancy 当日病区占用率分组(general+icu;契约 7 组映射:ICU 优先按 ward_type,
// 妇产/儿科/肿瘤/康复按科室名,其余按 category med→内科/surg→外科;obs 留观病区不入组)
func (r *Ops) WardOccupancy(ctx context.Context, day time.Time) ([]WardGroup, error) {
	var rows []WardGroup
	err := r.db.WithContext(ctx).Raw(
		`SELECT grp, SUM(bed_used) AS used, SUM(bed_open) AS open FROM (
			SELECT CASE
				WHEN w.ward_type='icu' THEN 'ICU'
				WHEN d.name='妇产科' THEN '妇产'
				WHEN d.name='儿科' THEN '儿科'
				WHEN d.name='肿瘤科' THEN '肿瘤'
				WHEN d.name='康复医学科' THEN '康复'
				WHEN d.category='med' THEN '内科'
				WHEN d.category='surg' THEN '外科'
			END AS grp, b.bed_used, b.bed_open
			FROM dwd.bed_state_day b
			JOIN dim.ward w ON w.code = b.ward_code
			JOIN dim.department d ON d.id = b.dept_id
			WHERE b.date = ? AND w.ward_type IN ('general','icu')
		) t WHERE grp IS NOT NULL GROUP BY grp`, day).Scan(&rows).Error
	return rows, err
}

// DeptBeds 科室开放床位(dim.ward 挂接;compare 效率维床位周转分母)
func (r *Ops) DeptBeds(ctx context.Context) (map[int64]int64, error) {
	var rows []struct {
		DeptID int64 `gorm:"column:dept_id"`
		Beds   int64 `gorm:"column:beds"`
	}
	err := r.db.WithContext(ctx).Raw(
		`SELECT dept_id, SUM(bed_open) AS beds FROM dim.ward GROUP BY dept_id`).Scan(&rows).Error
	out := make(map[int64]int64, len(rows))
	for _, x := range rows {
		out[x.DeptID] = x.Beds
	}
	return out, err
}

// ObservingNow 急诊在观人数(live_inpatient)
func (r *Ops) ObservingNow(ctx context.Context) (int64, error) {
	var n int64
	err := r.db.WithContext(ctx).Raw(
		`SELECT COUNT(*) FROM dwd.emergency_stay WHERE obs_status = 'observing'`).Scan(&n).Error
	return n, err
}

// ICUBedUsed 当日 ICU 在床(live_inpatient 重症监护在科)
func (r *Ops) ICUBedUsed(ctx context.Context, day time.Time) (int64, error) {
	var n int64
	err := r.db.WithContext(ctx).Raw(
		`SELECT COALESCE(SUM(b.bed_used),0) FROM dwd.bed_state_day b
		 JOIN dim.ward w ON w.code = b.ward_code
		 WHERE b.date = ? AND w.ward_type = 'icu'`, day).Scan(&n).Error
	return n, err
}

/* ========== 指标值 dws.metric_value(dept_id=0 哨兵=院级) ========== */

// MetricSum 窗口内指标求和(dept_id=0 院级;OTHER_INCOME_AMT 等)
func (r *Ops) MetricSum(ctx context.Context, code string, deptID int64, w RangeWin) (float64, error) {
	var v float64
	err := r.db.WithContext(ctx).Raw(
		`SELECT COALESCE(SUM(value),0) FROM dws.metric_value
		 WHERE metric_code = ? AND dept_id = ? AND date >= ? AND date < ?`,
		code, deptID, w.Start, w.End).Scan(&v).Error
	return v, err
}

// MetricLatest 窗口内最新一月院级指标(ABX_DDD_IP/OP_INFUSION_RATE 等)
func (r *Ops) MetricLatest(ctx context.Context, code string, deptID int64, w RangeWin) (float64, bool, error) {
	var v float64
	res := r.db.WithContext(ctx).Raw(
		`SELECT value FROM dws.metric_value
		 WHERE metric_code = ? AND dept_id = ? AND date >= ? AND date < ?
		 ORDER BY date DESC LIMIT 1`, code, deptID, w.Start, w.End).Scan(&v)
	return v, res.RowsAffected > 0, res.Error
}

// DeptMetricAt 单月科室指标图(QUALITY_SCORE/SAT_IP_SCORE/DRUG_RATIO 等)
func (r *Ops) DeptMetricAt(ctx context.Context, code string, month time.Time) (map[int64]float64, error) {
	var rows []struct {
		DeptID int64   `gorm:"column:dept_id"`
		Value  float64 `gorm:"column:value"`
	}
	err := r.db.WithContext(ctx).Raw(
		`SELECT dept_id, value FROM dws.metric_value WHERE metric_code = ? AND date = ?`,
		code, month).Scan(&rows).Error
	out := make(map[int64]float64, len(rows))
	for _, x := range rows {
		out[x.DeptID] = x.Value
	}
	return out, err
}

// DeptMetricLatest 窗口内每科室最新月指标
func (r *Ops) DeptMetricLatest(ctx context.Context, code string, w RangeWin) (map[int64]float64, error) {
	var rows []struct {
		DeptID int64   `gorm:"column:dept_id"`
		Value  float64 `gorm:"column:value"`
	}
	err := r.db.WithContext(ctx).Raw(
		`SELECT DISTINCT ON (dept_id) dept_id, value FROM dws.metric_value
		 WHERE metric_code = ? AND dept_id > 0 AND date >= ? AND date < ?
		 ORDER BY dept_id, date DESC`, code, w.Start, w.End).Scan(&rows).Error
	out := make(map[int64]float64, len(rows))
	for _, x := range rows {
		out[x.DeptID] = x.Value
	}
	return out, err
}

/* ========== 雷达/对标 ========== */

// RadarRow ads.radar_score 单维行
type RadarRow struct {
	Dim    string  `gorm:"column:radar_dim"`
	Ours   float64 `gorm:"column:ours_score"`
	Region float64 `gorm:"column:region_score"`
}

// RadarLatest 最新一期六维雷达(库内仅 month/2026-10 一期)
func (r *Ops) RadarLatest(ctx context.Context) ([]RadarRow, error) {
	var rows []RadarRow
	err := r.db.WithContext(ctx).Raw(
		`SELECT radar_dim, ours_score, region_score FROM ads.radar_score
		 WHERE (period_type, period_start) = (
			SELECT period_type, period_start FROM ads.radar_score
			ORDER BY period_start DESC LIMIT 1)`).Scan(&rows).Error
	return rows, err
}

// BenchRow dws.benchmark_peer 对标行
type BenchRow struct {
	Code   string  `gorm:"column:metric_code"`
	Name   string  `gorm:"column:name"`
	Ours   float64 `gorm:"column:ours_val"`
	Region float64 `gorm:"column:region_avg"`
	Bench  float64 `gorm:"column:bench_val"`
}

// BenchmarksLatest 最新一期对标(库内仅 year/2026-01-01)
func (r *Ops) BenchmarksLatest(ctx context.Context) ([]BenchRow, error) {
	var rows []BenchRow
	err := r.db.WithContext(ctx).Raw(
		`SELECT metric_code, name, ours_val, region_avg, bench_val FROM dws.benchmark_peer
		 WHERE (period_type, period_start) = (
			SELECT period_type, period_start FROM dws.benchmark_peer
			ORDER BY period_start DESC LIMIT 1)`).Scan(&rows).Error
	return rows, err
}
