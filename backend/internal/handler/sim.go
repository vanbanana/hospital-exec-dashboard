// 仿真控制面端点(契约 §16 档 A):GET/POST clock · tick · reset · jobs。
// SIM_ENABLED 门控在 register_sim.go(关闭→不注册→NoRoute 10003);写路径事务/行锁全部下沉 repo。
package handler

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

// 35003 仿真批次进行中(error-codes §3 注册);envelope 常量子集未含,本域自取
const codeSimBusy = 35003

// simTickMax lead 附加单次上限(契约 §16.2 minutes≥1 之外的部署侧护栏)
const simTickMax = 43200

type Sim struct {
	db  *gorm.DB
	clk *clock.Source
}

func NewSim(db *gorm.DB, clk *clock.Source) *Sim { return &Sim{db: db, clk: clk} }

// decodeBody 请求体→RawMessage map;逐字段二次 unmarshal 才能把类型错归位到
// data.fields(10001)而非整体 10006(契约 §16 各端点 fields 定位要求)
func decodeBody(c *gin.Context) (map[string]json.RawMessage, error) {
	var body map[string]json.RawMessage
	err := json.NewDecoder(c.Request.Body).Decode(&body)
	return body, err
}

// simFail 业务错误统一出口:35003→409 / 35002→400 / 其余 10000
func simFail(c *gin.Context, err error) {
	switch {
	case errors.Is(err, repo.ErrSimBusy):
		envelope.Fail(c, http.StatusConflict, codeSimBusy, "仿真批次进行中,请稍后", nil)
	case errors.Is(err, repo.ErrSimBound):
		envelope.Fail(c, http.StatusBadRequest, envelope.CodeSimTierNA, "越出仿真播种边界", nil)
	default:
		failInternal(c, err)
	}
}

// Clock GET /sim/clock(契约 §16.1):seed_end 缺省回退 MAX(charge_day) 在 repo
func (h *Sim) Clock(c *gin.Context) {
	row, seedEnd, err := repo.SimClock(c.Request.Context(), h.db)
	if err != nil {
		failInternal(c, err)
		return
	}
	envelope.OK(c, gin.H{
		"virtual_now": rfc3339(row.VirtualNow),
		"base_date":   row.BaseDate.Format("2006-01-02"),
		"seed_end":    seedEnd.Format("2006-01-02"),
		"speed":       row.Speed,
		"paused":      row.Paused,
		"weekday":     clock.WeekdayCN(row.VirtualNow),
		"updated_at":  rfc3339(row.UpdatedAt),
	})
}

// Tick POST /sim/tick(契约 §16.2):非幂等;paused 不阻塞手动 tick(auto-runner 预留标志)
func (h *Sim) Tick(c *gin.Context) {
	body, err := decodeBody(c)
	if err != nil { // 空 body/解析失败同归 10006(契约 §16.2)
		envelope.Fail(c, http.StatusBadRequest, envelope.CodeBadJSON, "请求体格式非法", nil)
		return
	}
	raw, present := body["minutes"]
	if !present {
		envelope.InvalidArg(c, "minutes", "必填")
		return
	}
	var minutes int
	if err := json.Unmarshal(raw, &minutes); err != nil {
		envelope.InvalidArg(c, "minutes", "须为整数")
		return
	}
	if minutes < 1 {
		envelope.InvalidArg(c, "minutes", "须 ≥1")
		return
	}
	if minutes > simTickMax {
		envelope.InvalidArg(c, "minutes", "超出单次上限 43200")
		return
	}

	before, after, jobID, err := repo.SimTick(c.Request.Context(), h.db, minutes)
	if err != nil {
		simFail(c, err)
		return
	}
	envelope.OK(c, gin.H{
		"virtual_now_before": rfc3339(before),
		"virtual_now":        rfc3339(after),
		"advanced_minutes":   minutes,
		"crossed_day":        before.Format("2006-01-02") != after.Format("2006-01-02"),
		"job_id":             jobID,
	})
}

// Reset POST /sim/reset(契约 §16.3):空 body 视作 {};scope 缺席="clock",
// "full" 档位未开放→35002,其他值→10001;幂等
func (h *Sim) Reset(c *gin.Context) {
	body, err := decodeBody(c)
	if err != nil && !errors.Is(err, io.EOF) { // EOF(Content-Length=0)容忍为空对象
		envelope.Fail(c, http.StatusBadRequest, envelope.CodeBadJSON, "请求体格式非法", nil)
		return
	}
	scope := "clock"
	if raw, present := body["scope"]; present {
		if err := json.Unmarshal(raw, &scope); err != nil {
			envelope.InvalidArg(c, "scope", "取值须为 clock/full 之一")
			return
		}
	}
	switch scope {
	case "clock":
	case "full":
		envelope.Fail(c, http.StatusBadRequest, envelope.CodeSimTierNA, "该档位未开放", nil)
		return
	default:
		envelope.InvalidArg(c, "scope", "取值须为 clock/full 之一")
		return
	}

	after, jobID, err := repo.SimReset(c.Request.Context(), h.db)
	if err != nil {
		simFail(c, err)
		return
	}
	envelope.OK(c, gin.H{"scope": scope, "virtual_now": rfc3339(after), "job_id": jobID})
}

// Jobs GET /sim/jobs(契约 §16.4):出席即须合法;空集 code=0+list=[]
func (h *Sim) Jobs(c *gin.Context) {
	page, ok := simIntParam(c, "page", 1, 1, 1<<31-1)
	if !ok {
		return
	}
	size, ok := simIntParam(c, "size", 20, 1, 100)
	if !ok {
		return
	}
	job, ok := simStrParam(c, "job")
	if !ok {
		return
	}
	status, ok := enumParam(c, "status", "", "running", "success", "failed")
	if !ok {
		return
	}

	rows, total, err := repo.SimJobs(c.Request.Context(), h.db, job, status, page, size)
	if err != nil {
		failInternal(c, err)
		return
	}
	list := make([]gin.H, 0, len(rows))
	for _, r := range rows {
		var finishedAt *string
		if r.FinishedAt != nil {
			s := rfc3339(*r.FinishedAt)
			finishedAt = &s
		}
		list = append(list, gin.H{
			"id":           r.ID,
			"job":          r.Job,
			"virtual_date": r.VirtualDate.Format("2006-01-02"),
			"started_at":   rfc3339(r.StartedAt),
			"finished_at":  finishedAt,
			"rows_cnt":     r.RowsCnt,
			"job_status":   r.JobStatus,
			"err":          r.Err,
		})
	}
	envelope.OK(c, gin.H{"list": list, "page": page, "size": size, "total": total})
}

// SetClock POST /sim/clock(契约 §16.5):字段全可选但至少一项;界校验同 tick 在 repo
func (h *Sim) SetClock(c *gin.Context) {
	body, err := decodeBody(c)
	if err != nil && !errors.Is(err, io.EOF) {
		envelope.Fail(c, http.StatusBadRequest, envelope.CodeBadJSON, "请求体格式非法", nil)
		return
	}
	var p repo.SimSetPatch
	for key := range body {
		switch key {
		case "virtual_now", "speed", "paused":
		default: // 未知键不计入"至少一项",也不报非法——契约只定义三键语义
			delete(body, key)
		}
	}
	if len(body) == 0 { // 全缺/空 body → 10001(契约 §16.5 可返回错误码)
		envelope.InvalidArg(c, "body", "至少须含 virtual_now/speed/paused 之一")
		return
	}
	if raw, present := body["virtual_now"]; present {
		var s string
		if err := json.Unmarshal(raw, &s); err != nil {
			envelope.InvalidArg(c, "virtual_now", "须为 ISO 8601 时刻串")
			return
		}
		t, err := time.Parse(time.RFC3339, s)
		if err != nil {
			envelope.InvalidArg(c, "virtual_now", "须为 ISO 8601 时刻串")
			return
		}
		p.VirtualNow = &t
	}
	if raw, present := body["speed"]; present {
		var v int
		if err := json.Unmarshal(raw, &v); err != nil || v < 1 || v > 1000 {
			envelope.InvalidArg(c, "speed", "取值须为 1..1000 整数")
			return
		}
		p.Speed = &v
	}
	if raw, present := body["paused"]; present {
		var v bool
		if err := json.Unmarshal(raw, &v); err != nil {
			envelope.InvalidArg(c, "paused", "须为布尔值")
			return
		}
		p.Paused = &v
	}

	after, jobID, err := repo.SimSetClock(c.Request.Context(), h.db, p)
	if err != nil {
		simFail(c, err)
		return
	}
	envelope.OK(c, gin.H{"virtual_now": rfc3339(after), "job_id": jobID})
}

// simIntParam 整数 query 参数;出席即须合法(空串/非数/越界→10001,契约 §16.4)
func simIntParam(c *gin.Context, name string, def, min, max int) (int, bool) {
	v, present := c.GetQuery(name)
	if !present {
		return def, true
	}
	n, err := strconv.Atoi(v)
	if err != nil || n < min || n > max {
		envelope.InvalidArg(c, name, "整数取值须为 "+strconv.Itoa(min)+".."+strconv.Itoa(max))
		return 0, false
	}
	return n, true
}

// simStrParam 自由文本 query 参数;出席空串→10001(精确匹配过滤器无"空串"语义)
func simStrParam(c *gin.Context, name string) (string, bool) {
	v, present := c.GetQuery(name)
	if !present {
		return "", true
	}
	if v == "" {
		envelope.InvalidArg(c, name, "不可为空串")
		return "", false
	}
	return v, true
}
