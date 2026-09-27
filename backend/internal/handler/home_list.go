// 首页列表域端点:top10/progress/alerts/notices(契约 §3.3/§3.5/§3.6/§3.7)
// 空集一律 code=0 + {"list":[]}(error-codes §2;切片须非 nil,否则序列化成 null)
package handler

import (
	"time"

	"github.com/gin-gonic/gin"

	"hospital-edss/internal/envelope"
	"hospital-edss/internal/repo"
)

type homeTop10Item struct {
	Rank  int    `json:"rank"`
	Name  string `json:"name"`
	Value int64  `json:"value"`
}

type homeTop10Resp struct {
	MetricName string          `json:"metric_name"`
	MaxVal     int64           `json:"max_val"`
	List       []homeTop10Item `json:"list"`
}

type homeProgressItem struct {
	ID       int64  `json:"id"`
	Name     string `json:"name"`
	Progress int    `json:"progress"`
	Status   string `json:"status"`
}

type homeProgressResp struct {
	List []homeProgressItem `json:"list"`
}

type homeAlertItem struct {
	ID         int64  `json:"id"`
	Level      string `json:"level"`
	Title      string `json:"title"`
	OccurredAt string `json:"occurred_at"`
	RuleCode   string `json:"rule_code"`
	Status     string `json:"alert_status"`
}

type homeAlertsResp struct {
	List []homeAlertItem `json:"list"`
}

type homeNoticeItem struct {
	ID     int64  `json:"id"`
	Text   string `json:"text"`
	Date   string `json:"date"`
	Urgent bool   `json:"urgent"`
}

type homeNoticesResp struct {
	List []homeNoticeItem `json:"list"`
}

// Top10 GET /workbench/home/top10——当月所在自然月科室出院人次榜
func (h *Home) Top10(c *gin.Context) {
	today, err := h.clk.Today(c.Request.Context())
	if err != nil {
		failInternal(c, err)
		return
	}
	start := time.Date(today.Year(), today.Month(), 1, 0, 0, 0, 0, today.Location())
	end := start.AddDate(0, 1, 0)

	rows, err := repo.HomeTop10(c.Request.Context(), h.db, start, end)
	if err != nil {
		failInternal(c, err)
		return
	}
	list := make([]homeTop10Item, 0, len(rows))
	var maxVal int64
	for i, r := range rows {
		if i == 0 {
			maxVal = (r.Value + 99) / 100 * 100 // top1 向上取整到百(契约 §3.3);空集保持 0
		}
		list = append(list, homeTop10Item{Rank: i + 1, Name: r.Name, Value: r.Value})
	}
	envelope.OK(c, homeTop10Resp{MetricName: "住院人次", MaxVal: maxVal, List: list})
}

// Progress GET /workbench/home/progress——当月院级重点工作进度
func (h *Home) Progress(c *gin.Context) {
	today, err := h.clk.Today(c.Request.Context())
	if err != nil {
		failInternal(c, err)
		return
	}
	periodStart := time.Date(today.Year(), today.Month(), 1, 0, 0, 0, 0, today.Location())

	rows, err := repo.HomeProgress(c.Request.Context(), h.db, periodStart)
	if err != nil {
		failInternal(c, err)
		return
	}
	list := make([]homeProgressItem, 0, len(rows))
	for _, r := range rows {
		list = append(list, homeProgressItem{ID: r.ID, Name: r.Name, Progress: r.ProgressPct, Status: r.Status})
	}
	envelope.OK(c, homeProgressResp{List: list})
}

// Alerts GET /workbench/home/alerts——打开态告警近 5 条,occurred_at 只出日期
func (h *Home) Alerts(c *gin.Context) {
	rows, err := repo.HomeAlerts(c.Request.Context(), h.db)
	if err != nil {
		failInternal(c, err)
		return
	}
	list := make([]homeAlertItem, 0, len(rows))
	for _, r := range rows {
		list = append(list, homeAlertItem{
			ID:         r.ID,
			Level:      r.Level,
			Title:      r.Title,
			OccurredAt: r.OccurredAt.Format("2006-01-02"),
			RuleCode:   r.RuleCode,
			Status:     r.Status,
		})
	}
	envelope.OK(c, homeAlertsResp{List: list})
}

// Notices GET /workbench/home/notices——行政通知近 5 条
func (h *Home) Notices(c *gin.Context) {
	rows, err := repo.HomeNotices(c.Request.Context(), h.db)
	if err != nil {
		failInternal(c, err)
		return
	}
	list := make([]homeNoticeItem, 0, len(rows))
	for _, r := range rows {
		list = append(list, homeNoticeItem{
			ID:     r.ID,
			Text:   r.Title,
			Date:   r.PublishDate.Format("2006-01-02"),
			Urgent: r.IsUrgent,
		})
	}
	envelope.OK(c, homeNoticesResp{List: list})
}
