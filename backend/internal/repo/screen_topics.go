// screen_topics.go — GET /workbench/topics 全部读查询（契约 §13.1 四专题）
// 事实源：dws.drg_dept_period（病组×科室×月）/ dws.metric_value（DRG_ENROLL_RATE）
//
//	dwd.insurance_settle_day（inp=住院医保 / op_fund=门诊统筹）/ dws.exam_indicator（国考集市）
package repo

import (
	"context"
	"database/sql"
	"time"

	"gorm.io/gorm"
)

// TopicsRepo §13.1 topics 查询仓储；*gorm.DB 由 handler 构造期注入
type TopicsRepo struct{ db *gorm.DB }

func NewTopicsRepo(db *gorm.DB) *TopicsRepo { return &TopicsRepo{db: db} }

func (r *TopicsRepo) raw(ctx context.Context, q string, args ...any) *gorm.DB {
	return r.db.WithContext(ctx).Raw(q, args...)
}

// DrgAgg drg_dept_period 月窗口聚合（dept_id=0 院级行与单科室行共用）；
// cmi/指数/rw2 均按 case_cnt 加权；b0..b5 为契约 §13.1 RW 六段分布底数
type DrgAgg struct {
	DeptID  int64   `gorm:"column:dept_id"`
	Cases   float64 `gorm:"column:cases"`
	CMI     float64 `gorm:"column:cmi"`
	CostIdx float64 `gorm:"column:cost_idx"`
	TimeIdx float64 `gorm:"column:time_idx"`
	Rw2     float64 `gorm:"column:rw2"`
	LowMort float64 `gorm:"column:low_mort"`
	B0      float64 `gorm:"column:b0"`
	B1      float64 `gorm:"column:b1"`
	B2      float64 `gorm:"column:b2"`
	B3      float64 `gorm:"column:b3"`
	B4      float64 `gorm:"column:b4"`
	B5      float64 `gorm:"column:b5"`
}

// DrgDeptAggs §13.1-drg stats/RW 分布/科室表共用聚合。
// months=period_start 'YYYY-MM-DD' 集合（range 窗展开）；低风险死亡率限 risk_level='low' 病组行（0303 列注释口径）
func (r *TopicsRepo) DrgDeptAggs(ctx context.Context, deptIDs []int64, months []string) (map[int64]DrgAgg, error) {
	var rows []DrgAgg
	err := r.raw(ctx, `SELECT d.dept_id,
		COALESCE(SUM(d.case_cnt),0) AS cases,
		COALESCE(SUM(d.rw_avg*d.case_cnt)/NULLIF(SUM(d.case_cnt),0),0) AS cmi,
		COALESCE(SUM(d.cost_idx*d.case_cnt)/NULLIF(SUM(d.case_cnt),0),0) AS cost_idx,
		COALESCE(SUM(d.time_idx*d.case_cnt)/NULLIF(SUM(d.case_cnt),0),0) AS time_idx,
		COALESCE(SUM(d.case_cnt) FILTER (WHERE d.rw_avg>=2)::numeric/NULLIF(SUM(d.case_cnt),0),0) AS rw2,
		COALESCE(SUM(d.lowrisk_mortality*d.case_cnt) FILTER (WHERE g.risk_level='low')
			/NULLIF(SUM(d.case_cnt) FILTER (WHERE g.risk_level='low'),0),0) AS low_mort,
		COALESCE(SUM(d.case_cnt) FILTER (WHERE d.rw_avg<0.5),0) AS b0,
		COALESCE(SUM(d.case_cnt) FILTER (WHERE d.rw_avg>=0.5 AND d.rw_avg<1),0) AS b1,
		COALESCE(SUM(d.case_cnt) FILTER (WHERE d.rw_avg>=1 AND d.rw_avg<2),0) AS b2,
		COALESCE(SUM(d.case_cnt) FILTER (WHERE d.rw_avg>=2 AND d.rw_avg<5),0) AS b3,
		COALESCE(SUM(d.case_cnt) FILTER (WHERE d.rw_avg>=5 AND d.rw_avg<10),0) AS b4,
		COALESCE(SUM(d.case_cnt) FILTER (WHERE d.rw_avg>=10),0) AS b5
		FROM dws.drg_dept_period d
		JOIN dim.drg_group g ON g.code=d.drg_code
		WHERE d.period_type='month' AND d.period_start IN ? AND d.dept_id IN ?
		GROUP BY d.dept_id`, months, deptIDs).Scan(&rows).Error
	out := make(map[int64]DrgAgg, len(rows))
	for _, row := range rows {
		out[row.DeptID] = row
	}
	return out, err
}

// MetricVal 院级长尾指标单值（dept_id=0/group_id=0）；无行 → (0,false,nil)
func (r *TopicsRepo) MetricVal(ctx context.Context, code, date string) (float64, bool, error) {
	var vals []float64
	err := r.raw(ctx, `SELECT value FROM dws.metric_value
		WHERE metric_code=? AND dept_id=0 AND group_id=0 AND date=?`, code, date).Scan(&vals).Error
	if len(vals) == 0 {
		return 0, false, err
	}
	return vals[0], true, err
}

// DeptIDs 科室名→id 映射（drg 名册按 name 匹配，冻结名册语义与 id 无关，e4-design §1）
func (r *TopicsRepo) DeptIDs(ctx context.Context, names []string) (map[string]int64, error) {
	type row struct {
		ID   int64  `gorm:"column:id"`
		Name string `gorm:"column:name"`
	}
	var rows []row
	err := r.raw(ctx, `SELECT id, name FROM dim.department WHERE name IN ?`, names).Scan(&rows).Error
	out := make(map[string]int64, len(rows))
	for _, x := range rows {
		out[x.Name] = x.ID
	}
	return out, err
}

// InsAgg insurance_settle_day 日窗汇总；biz 'inp'=住院医保结算 / 'op_fund'=门诊统筹
type InsAgg struct {
	Settle  float64 `gorm:"column:settle"`
	Fund    float64 `gorm:"column:fund"`
	Self    float64 `gorm:"column:self"`
	Account float64 `gorm:"column:account"`
	Reject  float64 `gorm:"column:reject"`
	Remote  float64 `gorm:"column:remote"`
	Chronic float64 `gorm:"column:chronic"`
}

// InsAggByWindow topics·insurance/outp_fund stats 与 delta 的窗内总量（金额单位元）
func (r *TopicsRepo) InsAggByWindow(ctx context.Context, biz, start, end string) (InsAgg, error) {
	var a InsAgg
	err := r.raw(ctx, `SELECT COALESCE(SUM(settle_cnt),0) AS settle,
		COALESCE(SUM(fund_amt),0) AS fund, COALESCE(SUM(self_amt),0) AS self,
		COALESCE(SUM(account_amt),0) AS account, COALESCE(SUM(reject_amt),0) AS reject,
		COALESCE(SUM(remote_cnt),0) AS remote, COALESCE(SUM(chronic_cnt),0) AS chronic
		FROM dwd.insurance_settle_day
		WHERE biz_type=? AND date BETWEEN ? AND ?`, biz, start, end).Scan(&a).Error
	return a, err
}

// MonthVal 月度基金支付点（topics chart 近 6 月序列）
type MonthVal struct {
	Month time.Time `gorm:"column:m"`
	Fund  float64   `gorm:"column:fund"`
}

// InsMonthlyFund 逐月 Σfund_amt（元）；[start,end] 日窗内按 date_trunc('month') 归并
func (r *TopicsRepo) InsMonthlyFund(ctx context.Context, biz, start, end string) ([]MonthVal, error) {
	var rows []MonthVal
	err := r.raw(ctx, `SELECT date_trunc('month', date)::date AS m, SUM(fund_amt) AS fund
		FROM dwd.insurance_settle_day
		WHERE biz_type=? AND date BETWEEN ? AND ?
		GROUP BY 1 ORDER BY 1`, biz, start, end).Scan(&rows).Error
	return rows, err
}

// InsTypeRow 分险种窗内汇总（insurance table 行底数）
type InsTypeRow struct {
	InsType string  `gorm:"column:ins_type"`
	Settle  float64 `gorm:"column:settle"`
	Fund    float64 `gorm:"column:fund"`
	Self    float64 `gorm:"column:self"`
}

// InsTypeRows §13.1-insurance table：窗口内按 ins_type 聚合；固定序/中文名在 handler 层钉
func (r *TopicsRepo) InsTypeRows(ctx context.Context, biz, start, end string) ([]InsTypeRow, error) {
	var rows []InsTypeRow
	err := r.raw(ctx, `SELECT ins_type,
		COALESCE(SUM(settle_cnt),0) AS settle, COALESCE(SUM(fund_amt),0) AS fund,
		COALESCE(SUM(self_amt),0) AS self
		FROM dwd.insurance_settle_day
		WHERE biz_type=? AND date BETWEEN ? AND ?
		GROUP BY ins_type`, biz, start, end).Scan(&rows).Error
	return rows, err
}

// OpFundDeptRow 门诊统筹按科室汇总行（outp_fund table；SQL 已按 fund DESC 截 6）
type OpFundDeptRow struct {
	DeptID  int64   `gorm:"column:dept_id"`
	Name    string  `gorm:"column:name"`
	Settle  float64 `gorm:"column:settle"`
	Fund    float64 `gorm:"column:fund"`
	Chronic float64 `gorm:"column:chronic"`
}

func (r *TopicsRepo) OpFundDeptRows(ctx context.Context, start, end string) ([]OpFundDeptRow, error) {
	var rows []OpFundDeptRow
	err := r.raw(ctx, `SELECT d.dept_id, dep.name,
		COALESCE(SUM(d.settle_cnt),0) AS settle, COALESCE(SUM(d.fund_amt),0) AS fund,
		COALESCE(SUM(d.chronic_cnt),0) AS chronic
		FROM dwd.insurance_settle_day d JOIN dim.department dep ON dep.id=d.dept_id
		WHERE d.biz_type='op_fund' AND d.date BETWEEN ? AND ?
		GROUP BY d.dept_id, dep.name ORDER BY fund DESC LIMIT 6`, start, end).Scan(&rows).Error
	return rows, err
}

// ExamRow exam_indicator 行（年聚合行+指标行共用）；owner_name 已 join 解出，NULL→”
type ExamRow struct {
	Code      string          `gorm:"column:code"`
	Name      string          `gorm:"column:name"`
	FullScore sql.NullInt64   `gorm:"column:full_score"`
	ScoreRate sql.NullFloat64 `gorm:"column:score_rate"`
	Direction int             `gorm:"column:direction"`
	OwnerName string          `gorm:"column:owner_name"`
}

func (r *TopicsRepo) ExamRows(ctx context.Context, periodType, periodStart string) ([]ExamRow, error) {
	var rows []ExamRow
	err := r.raw(ctx, `SELECT e.code, e.name, e.full_score, e.score_rate, e.direction,
		COALESCE(dep.name,'') AS owner_name
		FROM dws.exam_indicator e LEFT JOIN dim.department dep ON dep.id=e.owner_dept_id
		WHERE e.period_type=? AND e.period_start=?`, periodType, periodStart).Scan(&rows).Error
	return rows, err
}

// RateMonth 达标率月度序列点
type RateMonth struct {
	Month time.Time `gorm:"column:m"`
	Rate  float64   `gorm:"column:rate"`
}

// ExamRateMonths TARGET_RATE 最近 n 行（period_start<=before，DESC 返回，调用方倒序成轴）
func (r *TopicsRepo) ExamRateMonths(ctx context.Context, before string, n int) ([]RateMonth, error) {
	var rows []RateMonth
	err := r.raw(ctx, `SELECT period_start AS m, score_rate AS rate
		FROM dws.exam_indicator
		WHERE period_type='month' AND code='TARGET_RATE' AND period_start<=?
		ORDER BY period_start DESC LIMIT ?`, before, n).Scan(&rows).Error
	return rows, err
}

// ExamRateAt 单月 TARGET_RATE（指标达标率 delta 的上年同月锚）；无行 → (0,false,nil)
func (r *TopicsRepo) ExamRateAt(ctx context.Context, month string) (float64, bool, error) {
	var vals []float64
	err := r.raw(ctx, `SELECT score_rate FROM dws.exam_indicator
		WHERE period_type='month' AND code='TARGET_RATE' AND period_start=?`, month).Scan(&vals).Error
	if len(vals) == 0 {
		return 0, false, err
	}
	return vals[0], true, err
}
