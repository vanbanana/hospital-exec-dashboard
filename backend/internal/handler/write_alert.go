// Package handler P3-EW 写侧 handler——契约 §15.1~15.8。
// 操作人一律经 ?role= 演示账号传输(契约 §15 头部约定);出参字段名照抄契约 snake_case。
// 本文件:WriteHandler 基座 + 操作人解析 + 任意 data 错误包络 + R04/R05/R06 告警生命周期 + R10 人员选择器。
package handler

import (
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

// WriteHandler P3-EW 八端点共享 handler 基座(业务时钟在 repo 层,handler 不直接持有)
type WriteHandler struct {
	r *repo.WriteRepo
}

func NewWriteHandler(r *repo.WriteRepo) *WriteHandler {
	return &WriteHandler{r: r}
}

// operator 契约 §15 头部——?role= 出席=演示切换(白名单只管这个入参:须为演示账号,非法→10001);
// 缺席=当前会话用户(任何已认证账号直查 FindOperator,不走演示白名单;测试直挂路径兜底 president)
func (h *WriteHandler) operator(c *gin.Context) (*repo.Operator, bool) {
	username := "president"
	if v, present := c.GetQuery("role"); present {
		// 域=§2.1 演示账号全集(3 角色);admin 不入——admin 会话经下方会话分支直查
		switch v {
		case "president", "ops_director", "dept_leader":
			username = v
		default:
			envelope.InvalidArg(c, "role", "非法角色")
			return nil, false
		}
	} else if su, ok := sessionUser(c); ok {
		username = su.Username
	}
	op, err := h.r.FindOperator(c.Request.Context(), username)
	if err != nil || op == nil { // 0 行=账号被清,数据异常同 context.go
		fail(c, err)
		return nil, false
	}
	// ?role= 演示切换与会话用户不一致时,审计 detail 同记双身份(谁登的、以谁名义办的)
	if su, ok := sessionUser(c); ok && su.Username != op.Username {
		op.SessionUser = su.Username
	}
	return op, true
}

// failData 任意 data 载荷错误包络——契约 33002/33104 需回传 data.current_status(+todo_id),
// envelope.Fail 的 data 恒为 {fields} 且包已冻结,故本地实现;
// ts 为传输墙钟字段,豁免业务时钟纪律(同 envelope.go 语义;envelope 冻结故本地实现)
func failData(c *gin.Context, httpStatus, code int, message string, data any) {
	tid := ""
	if v, ok := c.Get("trace_id"); ok {
		if s, ok := v.(string); ok {
			tid = s
		}
	}
	c.JSON(httpStatus, gin.H{
		"code": code, "message": message, "data": data, "trace_id": tid, "ts": time.Now().Unix()})
}

// pathID 路径 int 参数——非数/非正→10001
func pathID(c *gin.Context) (int64, bool) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil || id <= 0 {
		envelope.InvalidArg(c, "id", "非法 id")
		return 0, false
	}
	return id, true
}

// alertErr R04~R06 告警写侧哨兵→契约码;StatusConflict→33002(data.current_status[+todo_id])
func (h *WriteHandler) alertErr(c *gin.Context, err error) {
	var sc *repo.StatusConflict
	switch {
	case errors.Is(err, repo.ErrAlertNotFound):
		envelope.Fail(c, http.StatusNotFound, envelope.CodeAlertNotFound, "告警事件不存在", nil)
	case errors.As(err, &sc):
		data := gin.H{"current_status": sc.Current}
		if sc.TodoID != 0 {
			data["todo_id"] = sc.TodoID
		}
		failData(c, http.StatusConflict, envelope.CodeAlertConflict, "告警已被处理/状态已变更", data)
	case errors.Is(err, repo.ErrAssigneeBad):
		envelope.Fail(c, http.StatusBadRequest, envelope.CodeAssigneeBad, "指派人非法", nil)
	case errors.Is(err, repo.ErrDeadlineBad):
		envelope.Fail(c, http.StatusBadRequest, envelope.CodeDeadlineBad, "截止时间非法", nil)
	default:
		fail(c, err)
	}
}

// AlertAck R04 POST /alerts/:id/ack——pending→processing 认领(契约 §15.1);body 无字段不强解析
func (h *WriteHandler) AlertAck(c *gin.Context) {
	id, ok := pathID(c)
	if !ok {
		return
	}
	op, ok := h.operator(c)
	if !ok {
		return
	}
	res, err := h.r.AlertAck(c.Request.Context(), *op, id, c.ClientIP())
	if err != nil {
		h.alertErr(c, err)
		return
	}
	envelope.OK(c, gin.H{
		"id": res.ID, "alert_status": "processing",
		"ack_at": res.AckAt.Format(time.RFC3339), "ack_by": res.AckBy,
	})
}

// AlertDispatch R05 POST /alerts/:id/dispatch——一键开督办工单(契约 §15.2)
func (h *WriteHandler) AlertDispatch(c *gin.Context) {
	id, ok := pathID(c)
	if !ok {
		return
	}
	op, ok := h.operator(c)
	if !ok {
		return
	}
	var b struct {
		AssigneeID *int64  `json:"assignee_id"`
		Deadline   *string `json:"deadline"`
		Title      string  `json:"title"`
		Note       string  `json:"note"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		envelope.Fail(c, http.StatusBadRequest, envelope.CodeBadJSON, "请求体格式非法", nil)
		return
	}
	fields := envelope.Fields{}
	if b.AssigneeID == nil {
		fields["assignee_id"] = "必填"
	}
	var deadline time.Time
	if b.Deadline == nil {
		fields["deadline"] = "必填"
	} else if t, err := time.Parse(time.RFC3339, *b.Deadline); err != nil {
		fields["deadline"] = "ISO 8601 格式非法"
	} else {
		deadline = t
	}
	if len(fields) > 0 {
		envelope.Fail(c, http.StatusBadRequest, envelope.CodeFieldErr, "参数校验失败", fields)
		return
	}
	res, err := h.r.AlertDispatch(c.Request.Context(), *op, id, *b.AssigneeID, deadline, b.Title, b.Note, c.ClientIP())
	if err != nil {
		h.alertErr(c, err)
		return
	}
	envelope.OK(c, gin.H{
		"todo_id": res.TodoID, "alert_id": res.AlertID, "alert_status": "processing",
		"assignee_id": *b.AssigneeID, "deadline": res.Deadline.Format(time.RFC3339),
	})
}

// AlertClose R06 POST /alerts/:id/close——不派单直接闭环,close_note 必填(契约 §15.3)
func (h *WriteHandler) AlertClose(c *gin.Context) {
	id, ok := pathID(c)
	if !ok {
		return
	}
	op, ok := h.operator(c)
	if !ok {
		return
	}
	var b struct {
		CloseNote string `json:"close_note"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		envelope.Fail(c, http.StatusBadRequest, envelope.CodeBadJSON, "请求体格式非法", nil)
		return
	}
	if strings.TrimSpace(b.CloseNote) == "" {
		envelope.Fail(c, http.StatusBadRequest, envelope.CodeFieldErr, "参数校验失败",
			envelope.Fields{"close_note": "必填"})
		return
	}
	res, err := h.r.AlertClose(c.Request.Context(), *op, id, b.CloseNote, c.ClientIP())
	if err != nil {
		h.alertErr(c, err)
		return
	}
	envelope.OK(c, gin.H{
		"id": res.ID, "alert_status": "closed", "closed_at": res.ClosedAt.Format(time.RFC3339),
	})
}

// StaffList R10 GET /staff——在职人员联想选择器,is_leader 优先(契约 §15.6);读端点不解析操作人
func (h *WriteHandler) StaffList(c *gin.Context) {
	var deptID *int64
	if v, present := c.GetQuery("dept_id"); present {
		n, err := strconv.ParseInt(v, 10, 64)
		if err != nil {
			envelope.InvalidArg(c, "dept_id", "非法科室 id")
			return
		}
		deptID = &n
	}
	rows, err := h.r.StaffOptions(c.Request.Context(), deptID)
	if err != nil {
		fail(c, err)
		return
	}
	list := make([]gin.H, 0, len(rows))
	for _, s := range rows {
		list = append(list, gin.H{
			"id": s.ID, "code": s.Code, "name": s.Name, "title": s.Title,
			"dept_id": s.DeptID, "dept_name": s.DeptName, "is_leader": s.IsLeader,
		})
	}
	envelope.OK(c, gin.H{"list": list})
}
