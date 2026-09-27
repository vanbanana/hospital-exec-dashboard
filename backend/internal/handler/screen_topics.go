// GET /api/v1/workbench/topics — 契约 §13.1 四专题（drg/insurance/exam/outp_fund）
// 窗口/delta 口径（e4-design §3）：drg stats 恒虚拟月快照、delta 恒较上月（intensity 不随 range 累计）；
// insurance/outp_fund 按 range 窗实算、delta 对等长前窗；exam 年度口径 range 仅回显。
// 文件私有标识符一律 tp 前缀——与并行属主 screen.go 同包共存，防撞名
package handler

import (
	"context"
	"fmt"
	"math"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

// TopicsHandler §13.1 四专题；注册见 register_screen.go（签名已钉，勿改）
type TopicsHandler struct {
	repo  *repo.TopicsRepo
	clock *clock.Source
}

func NewTopicsHandler(db *gorm.DB, clk *clock.Source) *TopicsHandler {
	return &TopicsHandler{repo: repo.NewTopicsRepo(db), clock: clk}
}

// Topics GET /workbench/topics?topic=&range=
func (h *TopicsHandler) Topics(c *gin.Context) {
	topic := c.Query("topic")
	switch topic {
	case "drg", "insurance", "exam", "outp_fund":
	default:
		envelope.InvalidArg(c, "topic", "topic 必填或取值非法")
		return
	}
	rng := "本年" // 契约默认；显式出席（含空串）必须合法
	if v, ok := c.GetQuery("range"); ok {
		rng = v
	}
	switch rng {
	case "本月", "本季", "本年":
	default:
		envelope.InvalidArg(c, "range", "range 取值非法")
		return
	}

	ctx := c.Request.Context()
	today, err := h.clock.Today(ctx)
	if err != nil {
		envelope.Fail(c, http.StatusInternalServerError, envelope.CodeInternal, "系统繁忙，请稍后重试", nil)
		return
	}

	var data gin.H
	switch topic {
	case "drg":
		data, err = h.drgTopic(ctx, rng, today)
	case "insurance":
		data, err = h.insTopic(ctx, rng, today)
	case "exam":
		data, err = h.examTopic(ctx, rng, today)
	case "outp_fund":
		data, err = h.opfTopic(ctx, rng, today)
	}
	if err != nil {
		envelope.Fail(c, http.StatusInternalServerError, envelope.CodeInternal, "系统繁忙，请稍后重试", nil)
		return
	}
	data["topic"] = topic
	data["range"] = rng
	envelope.OK(c, data)
}

// ---------- 窗口与格式化（screen_util.go 之外的 topics 私件） ----------

func tpMonthStart(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), 1, 0, 0, 0, 0, t.Location())
}

func tpDstr(t time.Time) string { return t.Format("2006-01-02") }

// tpRngWindow range → [当前窗,等长对比窗] 日粒度闭区间（相对虚拟月，勿写死）
func tpRngWindow(today time.Time, rng string) (cur, prev [2]time.Time) {
	ms := tpMonthStart(today)
	switch rng {
	case "本月":
		cur = [2]time.Time{ms, ms.AddDate(0, 1, -1)}
		prev = [2]time.Time{ms.AddDate(0, -1, 0), ms.AddDate(0, 0, -1)}
	case "本季":
		qs := ms.AddDate(0, -(int(ms.Month())-1)%3, 0)
		cur = [2]time.Time{qs, qs.AddDate(0, 3, -1)}
		prev = [2]time.Time{qs.AddDate(0, -3, 0), qs.AddDate(0, 0, -1)}
	default: // 本年
		ys := time.Date(ms.Year(), time.January, 1, 0, 0, 0, 0, ms.Location())
		cur = [2]time.Time{ys, ys.AddDate(1, 0, -1)}
		prev = [2]time.Time{ys.AddDate(-1, 0, 0), ys.AddDate(0, 0, -1)}
	}
	return
}

// tpMonthsIn 日窗展开为 period_start 月集合（'YYYY-MM-DD'）
func tpMonthsIn(w [2]time.Time) []string {
	var out []string
	for m := tpMonthStart(w[0]); !m.After(w[1]); m = m.AddDate(0, 1, 0) {
		out = append(out, tpDstr(m))
	}
	return out
}

// tpDeltaLabel range→对比窗文案；drg 恒"较上月"、exam 恒"较上年"不走此表
var tpDeltaLabel = map[string]string{"本月": "较上月", "本季": "较上季", "本年": "较上年"}

// tpStat WbStatItem 组装；空 unit/delta 则键缺席（契约可选字段）。
// dir 由渲染后 delta 派生：格式化判"持平"→flat（契约 dir 与 delta 文案必须成对，禁 rawDelta>0 却发 flat 文案）
func tpStat(label, value, unit, delta, deltaLabel string, rawDelta float64) gin.H {
	s := gin.H{"label": label, "value": value}
	if unit != "" {
		s["unit"] = unit
	}
	if delta != "" {
		dir := dirOf(rawDelta)
		if delta == "持平" {
			dir = "flat"
		}
		s["delta"] = delta
		s["delta_label"] = deltaLabel
		s["dir"] = dir
	}
	return s
}

func tpF1(v float64) string { return strconv.FormatFloat(v, 'f', 1, 64) }
func tpF2(v float64) string { return strconv.FormatFloat(v, 'f', 2, 64) }
func tpPct1(v float64) string {
	return fmt.Sprintf("%.1f%%", roundN(v, 1))
}

// tpDiv 护栏除法（窗口空集→0，防除零）
func tpDiv(a, b float64) float64 {
	if b == 0 {
		return 0
	}
	return a / b
}

// tpPctDelta 等长窗环比百分变动（基期 0 → 0=持平，如实不发散）
func tpPctDelta(cur, prev float64) float64 {
	if prev == 0 {
		return 0
	}
	return (cur - prev) / prev * 100
}

// tpCommaDec 千分位小数字符串（outp_fund fund 万元 1 位小数可破千）
func tpCommaDec(v float64, n int) string {
	neg := v < 0
	if neg {
		v = -v
	}
	s := strconv.FormatFloat(roundN(v, n), 'f', n, 64)
	intPart, frac, _ := strings.Cut(s, ".")
	var b strings.Builder
	for i, r := range intPart {
		if i > 0 && (len(intPart)-i)%3 == 0 {
			b.WriteByte(',')
		}
		b.WriteRune(r)
	}
	if frac != "" {
		b.WriteByte('.')
		b.WriteString(frac)
	}
	if neg {
		return "-" + b.String()
	}
	return b.String()
}

// tpMonthlyFund 近 6 月基金支付轴（以虚拟月收尾、不随 range；§13.1 insurance/outp_fund chart）
func (h *TopicsHandler) tpMonthlyFund(ctx context.Context, biz string, today time.Time) ([]string, []int64, error) {
	ms := tpMonthStart(today)
	rows, err := h.repo.InsMonthlyFund(ctx, biz, tpDstr(ms.AddDate(0, -5, 0)), tpDstr(ms.AddDate(0, 1, -1)))
	if err != nil {
		return nil, nil, err
	}
	byM := make(map[string]float64, len(rows))
	for _, r := range rows {
		byM[r.Month.Format("2006-01")] = r.Fund
	}
	months := make([]string, 0, 6)
	values := make([]int64, 0, 6)
	for i := 5; i >= 0; i-- {
		m := ms.AddDate(0, -i, 0)
		months = append(months, monthLabel(m))
		values = append(values, int64(math.Round(byM[m.Format("2006-01")]/1e4)))
	}
	return months, values, nil
}

// ---------- topic=drg ----------

// tpDrgRoster 契约 §13.1 冻结名册：序=契约序；cmi/profit 为冻结表逐字值（注10，与 /screen 自洽）
var tpDrgRoster = []struct {
	name   string
	cmi    string
	profit string
}{
	{"神经外科", "1.68", "-12.8"},
	{"心血管内科", "1.42", "+86.4"},
	{"骨科", "1.36", "+124.6"},
	{"肿瘤科", "1.24", "-34.6"},
	{"普通外科", "1.18", "+98.2"},
	{"呼吸与危重症医学科", "1.12", "+42.8"},
	{"神经内科", "0.94", "+38.2"},
	{"儿科", "0.68", "+28.4"},
}

var tpDrgRWCats = []string{"<0.5", "0.5-1", "1-2", "2-5", "5-10", "≥10"}

var tpDrgCols = []gin.H{
	{"key": "dept", "title": "科室"},
	{"key": "cmi", "title": "CMI", "align": "right", "num": true},
	{"key": "cases", "title": "入组病例", "align": "right", "num": true},
	{"key": "cost_idx", "title": "费用消耗指数", "align": "right", "num": true},
	{"key": "time_idx", "title": "时间消耗指数", "align": "right", "num": true},
	{"key": "rw2", "title": "RW≥2 占比", "align": "right", "num": true},
	{"key": "profit", "title": "DRG 结余（万元）", "align": "right", "num": true},
}

func (h *TopicsHandler) drgTopic(ctx context.Context, rng string, today time.Time) (gin.H, error) {
	ms, pm := tpMonthStart(today), tpMonthStart(today).AddDate(0, -1, 0)
	cur, _ := tpRngWindow(today, rng)
	winM := tpMonthsIn(cur)

	statAgg, err := h.repo.DrgDeptAggs(ctx, []int64{0}, []string{tpDstr(ms)})
	if err != nil {
		return nil, err
	}
	prevAgg, err := h.repo.DrgDeptAggs(ctx, []int64{0}, []string{tpDstr(pm)})
	if err != nil {
		return nil, err
	}
	winAgg, err := h.repo.DrgDeptAggs(ctx, []int64{0}, winM)
	if err != nil {
		return nil, err
	}
	enr, _, err := h.repo.MetricVal(ctx, "DRG_ENROLL_RATE", tpDstr(ms))
	if err != nil {
		return nil, err
	}
	enrP, okEnrP, err := h.repo.MetricVal(ctx, "DRG_ENROLL_RATE", tpDstr(pm))
	if err != nil {
		return nil, err
	}
	if !okEnrP { // 基期缺行→delta 归持平,防全值当增量(review-B#1)
		enrP = enr
	}

	names := make([]string, 0, len(tpDrgRoster))
	for _, rd := range tpDrgRoster {
		names = append(names, rd.name)
	}
	ids, err := h.repo.DeptIDs(ctx, names)
	if err != nil {
		return nil, err
	}
	idList := make([]int64, 0, len(ids))
	for _, rd := range tpDrgRoster {
		if id, ok := ids[rd.name]; ok {
			idList = append(idList, id)
		}
	}
	var deptAgg map[int64]repo.DrgAgg
	if len(idList) > 0 {
		deptAgg, err = h.repo.DrgDeptAggs(ctx, idList, winM)
		if err != nil {
			return nil, err
		}
	}

	c, p := statAgg[0], prevAgg[0]
	if _, ok := prevAgg[0]; !ok { // 同上防御
		p = c
	}
	dEnr := enr - enrP
	const dl = "较上月" // drg stats 恒最新月快照，delta 恒对上月（e4-design §3.2）
	stats := []gin.H{
		tpStat("CMI 值", tpF2(c.CMI), "", signedDec(c.CMI-p.CMI, 2), dl, c.CMI-p.CMI),
		tpStat("入组率", tpF1(enr*100), "%", signedPct(dEnr*100), dl, dEnr),
		tpStat("费用消耗指数", tpF2(c.CostIdx), "", signedDec(c.CostIdx-p.CostIdx, 2), dl, c.CostIdx-p.CostIdx),
		tpStat("时间消耗指数", tpF2(c.TimeIdx), "", signedDec(c.TimeIdx-p.TimeIdx, 2), dl, c.TimeIdx-p.TimeIdx),
		tpStat("RW≥2 占比", tpF1(c.Rw2*100), "%", signedPct((c.Rw2-p.Rw2)*100), dl, c.Rw2-p.Rw2),
		tpStat("低风险组死亡率", tpF2(c.LowMort*100), "%", signedPct((c.LowMort-p.LowMort)*100), dl, c.LowMort-p.LowMort),
	}

	w := winAgg[0]
	chart := gin.H{
		"title":      "病组权重（RW）分布",
		"sub":        rng + "出院病例按 RW 分段（仅已入组病例）",
		"type":       "bar",
		"unit":       "例",
		"categories": tpDrgRWCats,
		"values":     []int64{int64(w.B0), int64(w.B1), int64(w.B2), int64(w.B3), int64(w.B4), int64(w.B5)},
	}

	rows := make([]gin.H, 0, len(tpDrgRoster))
	for _, rd := range tpDrgRoster {
		row := gin.H{"dept": rd.name, "cmi": rd.cmi, "profit": rd.profit}
		a, ok := deptAgg[ids[rd.name]]
		if !ok || a.Cases == 0 {
			// 窗口内无该科室病组行：cmi/profit 仍冻结值，库源列如实空（e4-design §3.2）
			row["cases"], row["cost_idx"], row["time_idx"], row["rw2"] = "0", "—", "—", "—"
		} else {
			row["cases"] = commaInt(a.Cases)
			row["cost_idx"] = tpF2(a.CostIdx)
			row["time_idx"] = tpF2(a.TimeIdx)
			row["rw2"] = tpPct1(a.Rw2 * 100)
		}
		rows = append(rows, row)
	}
	table := gin.H{"title": "科室 DRG 核心指标", "sub": "按 CMI 降序排列", "columns": tpDrgCols, "rows": rows}

	return gin.H{"stats": stats, "chart": chart, "table": table}, nil
}

// ---------- topic=insurance ----------

var tpInsTypes = []struct{ code, name string }{
	{"employee", "职工医保"},
	{"resident", "居民医保"},
	{"maternity", "生育保险"},
	{"severe", "大病保险"},
	{"relief", "医疗救助"},
}

var tpInsCols = []gin.H{
	{"key": "type", "title": "险种"},
	{"key": "cases", "title": "结算人次", "align": "right", "num": true},
	{"key": "fund", "title": "基金支付（万元）", "align": "right", "num": true},
	{"key": "self", "title": "个人自付（万元）", "align": "right", "num": true},
	{"key": "ratio", "title": "报销比例", "align": "right", "num": true},
	{"key": "status", "title": "运行状态", "align": "center"},
}

func (h *TopicsHandler) insTopic(ctx context.Context, rng string, today time.Time) (gin.H, error) {
	cur, prev := tpRngWindow(today, rng)
	c, err := h.repo.InsAggByWindow(ctx, "inp", tpDstr(cur[0]), tpDstr(cur[1]))
	if err != nil {
		return nil, err
	}
	p, err := h.repo.InsAggByWindow(ctx, "inp", tpDstr(prev[0]), tpDstr(prev[1]))
	if err != nil {
		return nil, err
	}
	months, values, err := h.tpMonthlyFund(ctx, "inp", today)
	if err != nil {
		return nil, err
	}
	tRows, err := h.repo.InsTypeRows(ctx, "inp", tpDstr(cur[0]), tpDstr(cur[1]))
	if err != nil {
		return nil, err
	}

	lbl := tpDeltaLabel[rng]
	dSt := tpPctDelta(c.Settle, p.Settle)
	dFd := tpPctDelta(c.Fund, p.Fund)
	cRej, pRej := tpDiv(c.Reject, c.Fund)*100, tpDiv(p.Reject, p.Fund)*100
	cAvg, pAvg := tpDiv(c.Fund, c.Settle), tpDiv(p.Fund, p.Settle)
	dAvg := tpPctDelta(cAvg, pAvg)
	dRm := tpPctDelta(c.Remote, p.Remote)
	stats := []gin.H{
		tpStat("医保结算人次", commaInt(c.Settle), "", signedPct(dSt), lbl, dSt),
		tpStat("医保基金支付", commaInt(c.Fund/1e4), "万元", signedPct(dFd), lbl, dFd),
		// 基金结余率库无收入侧事实源 → 契约示例值直发（e4-design §3.5）
		tpStat("基金结余率", "6.8", "%", "+0.4%", lbl, 0.4),
		tpStat("拒付/扣款率", tpF1(cRej), "%", signedPct(cRej-pRej), lbl, cRej-pRej),
		tpStat("次均医保费用", commaInt(cAvg), "元", signedPct(dAvg), lbl, dAvg),
		tpStat("异地就医结算", commaInt(c.Remote), "人次", signedPct(dRm), lbl, dRm),
	}

	byType := make(map[string]repo.InsTypeRow, len(tRows))
	for _, r := range tRows {
		byType[r.InsType] = r
	}
	rows := make([]gin.H, 0, len(tpInsTypes))
	for _, it := range tpInsTypes {
		r := byType[it.code]
		status := "平稳"
		if it.code == "severe" {
			status = "关注" // 契约锚定规则：大病→关注，其余→平稳（e4-design §3.3）
		}
		rows = append(rows, gin.H{
			"type": it.name, "cases": commaInt(r.Settle),
			"fund": commaInt(r.Fund / 1e4), "self": commaInt(r.Self / 1e4),
			"ratio": tpPct1(tpDiv(r.Fund, r.Fund+r.Self) * 100), "status": status,
		})
	}

	return gin.H{
		"stats": stats,
		"chart": gin.H{"title": "医保基金月度支付", "sub": "近 6 个月（万元）", "type": "line", "unit": "万元", "months": months, "values": values},
		"table": gin.H{"title": "分险种结算情况", "sub": rng, "columns": tpInsCols, "rows": rows},
	}, nil
}

// ---------- topic=exam ----------

var tpExamDims = []struct{ code, label string }{
	{"DIM_QUALITY", "医疗质量得分率"},
	{"DIM_EFFICIENCY", "运营效率得分率"},
	{"DIM_GROWTH", "持续发展得分率"},
	{"DIM_SATISFACTION", "满意度得分率"},
}

// tpExamAggCodes 年行中的聚合码——stats 供数、从 table 指标行中剔除（e4-design §3.4）
var tpExamAggCodes = map[string]bool{
	"TOTAL_SCORE": true, "TARGET_RATE": true,
	"DIM_QUALITY": true, "DIM_EFFICIENCY": true, "DIM_GROWTH": true, "DIM_SATISFACTION": true,
}

var tpExamCols = []gin.H{
	{"key": "name", "title": "指标名称"},
	{"key": "full", "title": "分值", "align": "right", "num": true},
	{"key": "score", "title": "得分率", "align": "right", "num": true},
	{"key": "trend", "title": "趋势", "align": "center"},
	{"key": "owner", "title": "责任部门"},
}

func (h *TopicsHandler) examTopic(ctx context.Context, rng string, today time.Time) (gin.H, error) {
	ys := time.Date(today.Year(), time.January, 1, 0, 0, 0, 0, today.Location())
	rows, err := h.repo.ExamRows(ctx, "year", tpDstr(ys))
	if err != nil {
		return nil, err
	}
	prevRows, err := h.repo.ExamRows(ctx, "year", tpDstr(ys.AddDate(-1, 0, 0)))
	if err != nil {
		return nil, err
	}
	rates, err := h.repo.ExamRateMonths(ctx, tpDstr(tpMonthStart(today)), 6)
	if err != nil {
		return nil, err
	}

	cur := make(map[string]repo.ExamRow, len(rows))
	for _, r := range rows {
		cur[r.Code] = r
	}
	prv := make(map[string]repo.ExamRow, len(prevRows))
	for _, r := range prevRows {
		prv[r.Code] = r
	}
	for k, v := range cur { // 上年行缺席→delta 持平,防全值当增量(review-B#1)
		if _, ok := prv[k]; !ok {
			prv[k] = v
		}
	}

	const dl = "较上年" // exam 全部 delta 口径为同比上年（range 仅回显）
	stats := make([]gin.H, 0, 6)

	// 国考预估得分=TOTAL_SCORE.score_rate×full_score；delta=(cur−prev)×full_score（0306 列注释口径）
	tot, totP := cur["TOTAL_SCORE"], prv["TOTAL_SCORE"]
	fs := float64(tot.FullScore.Int64)
	dScore := (tot.ScoreRate.Float64 - totP.ScoreRate.Float64) * fs
	stats = append(stats, tpStat("国考预估得分", commaInt(tot.ScoreRate.Float64*fs), "分",
		signedUnit(dScore, "分"), dl, dScore))

	// 指标达标率=最新月 TARGET_RATE；delta 对上年同月行
	var latest repo.RateMonth
	if len(rates) > 0 {
		latest = rates[0]
	}
	prevRate, okPR, err := h.repo.ExamRateAt(ctx, tpDstr(latest.Month.AddDate(-1, 0, 0)))
	if err != nil {
		return nil, err
	}
	if !okPR { // 上年同月行缺席→delta 持平
		prevRate = latest.Rate
	}
	dRate := (latest.Rate - prevRate) * 100
	stats = append(stats, tpStat("指标达标率", tpF1(latest.Rate*100), "%", signedPct(dRate), dl, dRate))

	for _, d := range tpExamDims {
		r, rp := cur[d.code], prv[d.code]
		dv := (r.ScoreRate.Float64 - rp.ScoreRate.Float64) * 100
		stats = append(stats, tpStat(d.label, tpF1(r.ScoreRate.Float64*100), "%", signedPct(dv), dl, dv))
	}

	months := make([]string, 0, len(rates))
	values := make([]float64, 0, len(rates))
	for i := len(rates) - 1; i >= 0; i-- {
		months = append(months, monthLabel(rates[i].Month))
		values = append(values, ratePct(rates[i].Rate))
	}
	chart := gin.H{"title": "近 6 个月指标达标率", "sub": "已监测指标达标占比",
		"type": "line", "unit": "%", "months": months, "values": values}

	ind := make([]repo.ExamRow, 0, len(rows))
	for _, r := range rows {
		if !tpExamAggCodes[r.Code] {
			ind = append(ind, r)
		}
	}
	sort.SliceStable(ind, func(i, j int) bool { // 契约序：full_score DESC, score_rate ASC
		fi, fj := ind[i].FullScore.Int64, ind[j].FullScore.Int64
		if fi != fj {
			return fi > fj
		}
		return ind[i].ScoreRate.Float64 < ind[j].ScoreRate.Float64
	})
	tRows := make([]gin.H, 0, len(ind))
	for _, r := range ind {
		tRows = append(tRows, gin.H{
			"name": r.Name, "full": r.FullScore.Int64,
			"score": fmt.Sprintf("%.0f%%", r.ScoreRate.Float64*100),
			"trend": trendArrow(r.Direction), "owner": r.OwnerName,
		})
	}
	table := gin.H{"title": "关键国考指标", "sub": "得分率偏低的重点项", "columns": tpExamCols, "rows": tRows}

	return gin.H{"stats": stats, "chart": chart, "table": table}, nil
}

// ---------- topic=outp_fund ----------

var tpOpfCols = []gin.H{
	{"key": "dept", "title": "科室"},
	{"key": "cases", "title": "结算人次", "align": "right", "num": true},
	{"key": "fund", "title": "统筹支付（万元）", "align": "right", "num": true},
	{"key": "avg", "title": "人均费用（元）", "align": "right", "num": true},
	{"key": "chronic", "title": "慢特病占比", "align": "right", "num": true},
}

func (h *TopicsHandler) opfTopic(ctx context.Context, rng string, today time.Time) (gin.H, error) {
	cur, prev := tpRngWindow(today, rng)
	c, err := h.repo.InsAggByWindow(ctx, "op_fund", tpDstr(cur[0]), tpDstr(cur[1]))
	if err != nil {
		return nil, err
	}
	p, err := h.repo.InsAggByWindow(ctx, "op_fund", tpDstr(prev[0]), tpDstr(prev[1]))
	if err != nil {
		return nil, err
	}
	months, values, err := h.tpMonthlyFund(ctx, "op_fund", today)
	if err != nil {
		return nil, err
	}
	deptRows, err := h.repo.OpFundDeptRows(ctx, tpDstr(cur[0]), tpDstr(cur[1]))
	if err != nil {
		return nil, err
	}

	lbl := tpDeltaLabel[rng]
	dSt := tpPctDelta(c.Settle, p.Settle)
	dFd := tpPctDelta(c.Fund, p.Fund)
	cAvg, pAvg := tpDiv(c.Fund, c.Settle), tpDiv(p.Fund, p.Settle)
	dAvg := tpPctDelta(cAvg, pAvg)
	dAc := tpPctDelta(c.Account, p.Account)
	dCh := tpPctDelta(c.Chronic, p.Chronic)
	stats := []gin.H{
		tpStat("门诊统筹结算人次", commaInt(c.Settle), "", signedPct(dSt), lbl, dSt),
		tpStat("统筹基金支付", commaInt(c.Fund/1e4), "万元", signedPct(dFd), lbl, dFd),
		tpStat("人均统筹费用", commaInt(cAvg), "元", signedPct(dAvg), lbl, dAvg),
		tpStat("个人账户支出", commaInt(c.Account/1e4), "万元", signedPct(dAc), lbl, dAc),
		tpStat("慢特病结算", commaInt(c.Chronic), "人次", signedPct(dCh), lbl, dCh),
		// 处方外流率库无处方域事实源 → 契约示例值直发（e4-design §3.5）
		tpStat("处方外流率", "12.4", "%", "+2.8%", lbl, 2.8),
	}

	rows := make([]gin.H, 0, len(deptRows))
	for _, r := range deptRows {
		rows = append(rows, gin.H{
			"dept": r.Name, "cases": commaInt(r.Settle),
			"fund": tpCommaDec(r.Fund/1e4, 1), "avg": commaInt(tpDiv(r.Fund, r.Settle)),
			"chronic": tpPct1(tpDiv(r.Chronic, r.Settle) * 100),
		})
	}
	table := gin.H{"title": "科室门诊统筹使用", "sub": "按统筹支付额排序", "columns": tpOpfCols, "rows": rows}

	return gin.H{
		"stats": stats,
		"chart": gin.H{"title": "门诊统筹基金月度支出", "sub": "近 6 个月（万元）", "type": "line", "unit": "万元", "months": months, "values": values},
		"table": table,
	}, nil
}
