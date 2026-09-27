// P3-EW 督办工单域 handler——R07 GET /todos(契约 §15.4) + R08 POST /todos/:id/status(§15.5)。
package handler

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

// TodoList R07 GET /todos——惰性过期清扫后分页列表(契约 §15.4)
func (h *WriteHandler) TodoList(c *gin.Context) {
	if _, ok := h.operator(c); !ok { // §15 头部:R04–R08 操作人经 ?role= 传输,出席须合法
		return
	}
	page, size := 1, 20
	if v, present := c.GetQuery("page"); present {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 {
			envelope.InvalidArg(c, "page", "≥1 的整数")
			return
		}
		page = n
	}
	if v, present := c.GetQuery("size"); present {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 || n > 100 {
			envelope.InvalidArg(c, "size", "1~100 的整数")
			return
		}
		size = n
	}
	var status *string
	if v, present := c.GetQuery("status"); present {
		switch v {
		case "open", "doing", "done", "expired":
			status = &v
		default:
			envelope.InvalidArg(c, "status", "open|doing|done|expired 之外")
			return
		}
	}
	var assigneeID *int64
	if v, present := c.GetQuery("assignee_id"); present {
		n, err := strconv.ParseInt(v, 10, 64)
		if err != nil {
			envelope.InvalidArg(c, "assignee_id", "非法承办人 id")
			return
		}
		assigneeID = &n
	}

	ctx := c.Request.Context()
	rows, total, err := h.r.TodoList(ctx, repo.TodoFilter{
		Status: status, AssigneeID: assigneeID, Offset: (page - 1) * size, Limit: size,
	})
	if err != nil {
		fail(c, err)
		return
	}
	list := make([]gin.H, 0, len(rows))
	for _, t := range rows {
		cur, err := h.r.TodoCurrentValue(ctx, t.MetricCode)
		if err != nil {
			fail(c, err)
			return
		}
		list = append(list, gin.H{
			"id": t.ID, "alert_id": t.AlertID, "title": t.Title,
			"assignee_id": t.AssigneeID, "assignee_name": t.AssigneeName, "dept_name": t.DeptName,
			"deadline":    t.Deadline.Format("2006-01-02 15:04"),
			"todo_status": t.TodoStatus, "status_label": t.StatusLabel,
			"baseline_value": t.BaselineValue, "current_value": cur, "target_value": t.TargetValue,
			"metric_code": t.MetricCode, "note": t.Note, "result_note": t.ResultNote,
			"created_at": t.CreatedAt.Format("2006-01-02 15:04"),
		})
	}
	envelope.OK(c, gin.H{"list": list, "page": page, "size": size, "total": total})
}

// TodoStatus R08 POST /todos/:id/status——accept 接单 / report 办结回填(契约 §15.5)
func (h *WriteHandler) TodoStatus(c *gin.Context) {
	id, ok := pathID(c)
	if !ok {
		return
	}
	op, ok := h.operator(c)
	if !ok {
		return
	}
	var b struct {
		Action     string `json:"action"`
		ResultNote string `json:"result_note"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		envelope.Fail(c, http.StatusBadRequest, envelope.CodeBadJSON, "请求体格式非法", nil)
		return
	}
	switch b.Action {
	case "accept":
	case "report":
		if strings.TrimSpace(b.ResultNote) == "" {
			envelope.Fail(c, http.StatusBadRequest, envelope.CodeFieldErr, "参数校验失败",
				envelope.Fields{"result_note": "report 必填"})
			return
		}
	default: // 契约 §15.5:action 非法→10002 fields 定位
		envelope.Fail(c, http.StatusBadRequest, envelope.CodeFieldErr, "参数校验失败",
			envelope.Fields{"action": "accept|report 之外"})
		return
	}
	res, err := h.r.TodoTransit(c.Request.Context(), *op, id, b.Action, b.ResultNote, c.ClientIP())
	if err != nil {
		var sc *repo.StatusConflict
		switch {
		case errors.Is(err, repo.ErrTodoNotFound):
			envelope.Fail(c, http.StatusNotFound, envelope.CodeTodoNotFound, "督办工单不存在", nil)
		case errors.Is(err, repo.ErrScopeDeny):
			envelope.Fail(c, http.StatusForbidden, envelope.CodeScopeDeny, "无权执行该操作（角色不足）", nil)
		case errors.Is(err, repo.ErrNeedAccept):
			envelope.Fail(c, http.StatusBadRequest, envelope.CodeFieldErr, "参数校验失败",
				envelope.Fields{"action": "须先接单"})
		case errors.As(err, &sc):
			failData(c, http.StatusConflict, envelope.CodeTodoClosed, "工单已关闭，禁止变更",
				gin.H{"current_status": sc.Current})
		default:
			fail(c, err)
		}
		return
	}
	envelope.OK(c, gin.H{
		"id": res.ID, "todo_status": res.TodoStatus,
		"alert_id": res.AlertID, "alert_status": res.AlertStatus,
	})
}
