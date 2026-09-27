// Package repo P3-EW 写侧数据访问——契约 §15.1~15.8:
// alert_event 生命周期(ack/dispatch/close) · todo_order 开单/列表/状态机 ·
// alert_rule 启停 · user_pref upsert · sys.audit_log 审计。
// 业务时间戳一律取 clk.Now() 显式传参落库——不走墙钟、不依赖库列默认时刻(AGENTS §2-6)。
package repo

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgconn"
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
)

// WriteRepo P3-EW 八端点共享数据基座
type WriteRepo struct {
	db  *gorm.DB
	clk *clock.Source
}

func NewWriteRepo(db *gorm.DB, clk *clock.Source) *WriteRepo {
	return &WriteRepo{db: db, clk: clk}
}

// Operator §15 头部操作人——?role= 或会话用户解析出的 sys.user 行
type Operator struct {
	ID       int64
	Username string
	Role     string
	DeptID   *int64
	// SessionUser 演示切换双身份注记:?role= 与会话用户不一致时记实际登录人
	// (审计溯源用;handler 填充,不入 SQL 投影)
	SessionUser string
}

// FindOperator 按演示账号 username 查启用用户;0 行→(nil,nil) 由 handler 判数据异常
func (r *WriteRepo) FindOperator(ctx context.Context, username string) (*Operator, error) {
	var op Operator
	tx := r.db.WithContext(ctx).
		Raw(`SELECT id,username,role,dept_id FROM sys."user" WHERE username=$1 AND user_status=1`, username).
		Scan(&op)
	if tx.Error != nil {
		return nil, tx.Error
	}
	if tx.RowsAffected == 0 {
		return nil, nil
	}
	return &op, nil
}

// ---- 写侧哨兵错误——handler 一对一映射契约错误码(error-codes §3)-------------

var (
	ErrAlertNotFound = errors.New("alert event not found")               // →33001
	ErrTodoNotFound  = errors.New("todo order not found")                // →33101
	ErrAssigneeBad   = errors.New("assignee inactive or off-dept")       // →33102
	ErrDeadlineBad   = errors.New("deadline not after virtual now")      // →33103
	ErrRuleNotFound  = errors.New("alert rule code not found")           // →10003
	ErrScopeDeny     = errors.New("dept_leader outside own dept")        // →20005
	ErrNeedAccept    = errors.New("todo must be accepted before report") // →10002 fields.action
)

// StatusConflict 状态冲突——R04/R05/R06→33002 / R08→33104。
// Current=最新态;"todo_open"为虚拟态(存在打开工单,非 alert_status 值域);
// TodoID 仅 R05 派发冲突回传(契约 data.todo_id),其余场景 0。
type StatusConflict struct {
	Current string
	TodoID  int64
}

func (e *StatusConflict) Error() string { return "status conflict: " + e.Current }

// auditLog sys.audit_log 写入——created_at 显式传虚拟时钟覆写列默认(纪律同任务书);
// ip 空串→NULL(inet),detail nil→NULL;在事务内调用,失败回滚整个写
func auditLog(tx *gorm.DB, op Operator, action, targetType, targetID string, detail map[string]any, ip string, now time.Time) error {
	// 演示切换(?role= 与会话用户不一致)时 detail 同记双身份——行为人以 op.Username 计,
	// session_user 记实际登录账号,审计可还原"谁登的、以谁名义办的"
	if op.SessionUser != "" && op.SessionUser != op.Username {
		if detail == nil {
			detail = map[string]any{}
		}
		detail["session_user"] = op.SessionUser
	}
	var dj []byte
	if detail != nil {
		b, err := json.Marshal(detail)
		if err != nil {
			return err
		}
		dj = b
	}
	var ipArg any
	if ip != "" {
		ipArg = ip
	}
	return tx.Exec(
		`INSERT INTO sys.audit_log(user_id,username,action,target_type,target_id,detail,ip,created_at)
		 VALUES($1,$2,$3,$4,$5,$6::jsonb,$7::inet,$8)`,
		op.ID, op.Username, action, targetType, targetID, dj, ipArg, now).Error
}

// isUniqueViolation PG 23505 + 约束名判定(R05 UQ 兜底路径)
func isUniqueViolation(err error, constraint string) bool {
	var pe *pgconn.PgError
	return errors.As(err, &pe) && pe.Code == "23505" && pe.ConstraintName == constraint
}

// ---- R04 ack -----------------------------------------------------------------

// AckResult R04 出参
type AckResult struct {
	ID    int64
	AckAt time.Time
	AckBy int64
}

type alertLockRow struct {
	ID          int64
	OccurredAt  time.Time
	AlertStatus string
}

// lockAlert FOR UPDATE 锁告警行(ack/close 共用);0 行→ErrAlertNotFound
func lockAlert(tx *gorm.DB, alertID int64) (*alertLockRow, error) {
	var row alertLockRow
	q := tx.Raw(`SELECT id,occurred_at,alert_status FROM ads.alert_event WHERE id=$1 FOR UPDATE`, alertID).Scan(&row)
	if q.Error != nil {
		return nil, q.Error
	}
	if q.RowsAffected == 0 {
		return nil, ErrAlertNotFound
	}
	return &row, nil
}

// AlertAck 契约 §15.1——单事务:锁行→pending 校验→processing/ack_at/ack_by→审计 alert_ack
func (r *WriteRepo) AlertAck(ctx context.Context, op Operator, alertID int64, ip string) (*AckResult, error) {
	now, err := r.clk.Now(ctx)
	if err != nil {
		return nil, err
	}
	err = r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		row, err := lockAlert(tx, alertID)
		if err != nil {
			return err
		}
		if row.AlertStatus != "pending" {
			return &StatusConflict{Current: row.AlertStatus}
		}
		if err := tx.Exec(`UPDATE ads.alert_event SET alert_status='processing',ack_at=$1,ack_by=$2
			WHERE id=$3 AND occurred_at=$4`, now, op.ID, row.ID, row.OccurredAt).Error; err != nil {
			return err
		}
		return auditLog(tx, op, "alert_ack", "alert_event", strconv.FormatInt(alertID, 10),
			map[string]any{"alert_status": "processing"}, ip, now)
	})
	if err != nil {
		return nil, err
	}
	return &AckResult{ID: alertID, AckAt: now, AckBy: op.ID}, nil
}

// ---- R05 dispatch ------------------------------------------------------------

// DispatchResult R05 出参
type DispatchResult struct {
	TodoID   int64
	AlertID  int64
	Deadline time.Time
}

// AlertDispatch 契约 §15.2——单事务:锁告警(JOIN 规则取三点锚点)→打开工单判重→
// 承办人在职+本科室校验→deadline>virtual_now→INSERT todo→pending 连带认领→审计 todo_dispatch。
// "一告警一打开工单"=锁行下 SELECT 判重 + uq_todo_order_open_alert(23505) 双保险。
func (r *WriteRepo) AlertDispatch(ctx context.Context, op Operator, alertID, assigneeID int64,
	deadline time.Time, title, note string, ip string) (*DispatchResult, error) {
	now, err := r.clk.Now(ctx)
	if err != nil {
		return nil, err
	}
	var res DispatchResult
	err = r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var row struct {
			ID          int64
			OccurredAt  time.Time
			AlertStatus string
			DeptID      *int64
			Title       string
			RuleCode    string
			Baseline    *float64
			MetricCode  *string
			Threshold   *float64
		}
		// 告警与规则分两步:JOIN 缺规则行会把"告警存在"误判成 33001——
		// 规则缺失属数据完整性故障,走默认 10000 而非业务码
		q := tx.Raw(`SELECT e.id,e.occurred_at,e.alert_status,e.dept_id,e.title,
			e.rule_code,(e.payload->>'value')::numeric AS baseline
			FROM ads.alert_event e WHERE e.id=$1 FOR UPDATE OF e`, alertID).Scan(&row)
		if q.Error != nil {
			return q.Error
		}
		if q.RowsAffected == 0 {
			return ErrAlertNotFound
		}
		var rule struct {
			MetricCode *string
			Threshold  *float64
		}
		qr := tx.Raw(`SELECT metric_code,threshold FROM ads.alert_rule WHERE code=$1`, row.RuleCode).Scan(&rule)
		if qr.Error != nil {
			return qr.Error
		}
		if qr.RowsAffected == 0 {
			return fmt.Errorf("alert_rule 缺失: code=%s (alert_id=%d)", row.RuleCode, row.ID)
		}
		row.MetricCode, row.Threshold = rule.MetricCode, rule.Threshold
		if row.AlertStatus == "done" || row.AlertStatus == "closed" {
			return &StatusConflict{Current: row.AlertStatus}
		}
		var openID int64
		q2 := tx.Raw(`SELECT id FROM ads.todo_order
			WHERE alert_id=$1 AND alert_occurred_at=$2 AND todo_status IN ('open','doing') LIMIT 1`,
			row.ID, row.OccurredAt).Scan(&openID)
		if q2.Error != nil {
			return q2.Error
		}
		if q2.RowsAffected > 0 {
			return &StatusConflict{Current: "todo_open", TodoID: openID}
		}
		var st struct {
			DeptID int64
			Active bool
		}
		q3 := tx.Raw(`SELECT dept_id,active FROM dim.staff WHERE id=$1`, assigneeID).Scan(&st)
		if q3.Error != nil {
			return q3.Error
		}
		// 非在职 33102;院级事件(dept NULL)免科室比对,否则承办人须在涉事科室(契约 §15.2)
		if q3.RowsAffected == 0 || !st.Active || (row.DeptID != nil && st.DeptID != *row.DeptID) {
			return ErrAssigneeBad
		}
		if !deadline.After(now) {
			return ErrDeadlineBad
		}
		if title == "" {
			title = row.Title
		}
		var noteArg any
		if note != "" {
			noteArg = note
		}
		var todoID int64
		ins := tx.Raw(`INSERT INTO ads.todo_order
			(alert_id,alert_occurred_at,title,assignee_id,dispatcher_id,deadline,note,
			 baseline_value,target_value,metric_code,created_at,updated_at)
			VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$11) RETURNING id`,
			row.ID, row.OccurredAt, title, assigneeID, op.ID, deadline, noteArg,
			row.Baseline, row.Threshold, row.MetricCode, now).Scan(&todoID)
		if ins.Error != nil {
			if isUniqueViolation(ins.Error, "uq_todo_order_open_alert") {
				return &StatusConflict{Current: "todo_open"}
			}
			return ins.Error
		}
		// pending 连带认领(processing 已含 ack_at,不再回填;ck_alert_event_life 约束)
		if err := tx.Exec(`UPDATE ads.alert_event
			SET alert_status='processing',ack_at=COALESCE(ack_at,$1),ack_by=COALESCE(ack_by,$2)
			WHERE id=$3 AND occurred_at=$4 AND alert_status='pending'`,
			now, op.ID, row.ID, row.OccurredAt).Error; err != nil {
			return err
		}
		if err := auditLog(tx, op, "todo_dispatch", "todo_order", strconv.FormatInt(todoID, 10),
			map[string]any{"alert_id": row.ID, "assignee_id": assigneeID, "deadline": deadline}, ip, now); err != nil {
			return err
		}
		res = DispatchResult{TodoID: todoID, AlertID: row.ID, Deadline: deadline}
		return nil
	})
	if err != nil {
		// 23505 兜底路径无法在同事务取已有工单 id(事务已毁)——锁外补查回执载荷
		var sc *StatusConflict
		if errors.As(err, &sc) && sc.Current == "todo_open" && sc.TodoID == 0 {
			var openID int64
			if q := r.db.WithContext(ctx).Raw(`SELECT id FROM ads.todo_order
				WHERE alert_id=$1 AND todo_status IN ('open','doing') ORDER BY id LIMIT 1`, alertID).
				Scan(&openID); q.Error == nil && q.RowsAffected > 0 {
				sc.TodoID = openID
			}
		}
		return nil, err
	}
	return &res, nil
}

// ---- R06 close ---------------------------------------------------------------

// CloseResult R06 出参
type CloseResult struct {
	ID       int64
	ClosedAt time.Time
}

// AlertClose 契约 §15.3——单事务:锁行→closed/done/打开工单三态拒→closed 回填→审计 alert_close
func (r *WriteRepo) AlertClose(ctx context.Context, op Operator, alertID int64, closeNote, ip string) (*CloseResult, error) {
	now, err := r.clk.Now(ctx)
	if err != nil {
		return nil, err
	}
	err = r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		row, err := lockAlert(tx, alertID)
		if err != nil {
			return err
		}
		if row.AlertStatus == "closed" {
			return &StatusConflict{Current: "closed"}
		}
		// 打开工单须先办结,不得跨越关闭(契约 §15.3)
		var openID int64
		q := tx.Raw(`SELECT id FROM ads.todo_order
			WHERE alert_id=$1 AND alert_occurred_at=$2 AND todo_status IN ('open','doing') LIMIT 1`,
			row.ID, row.OccurredAt).Scan(&openID)
		if q.Error != nil {
			return q.Error
		}
		if q.RowsAffected > 0 {
			return &StatusConflict{Current: "todo_open"}
		}
		if row.AlertStatus == "done" {
			return &StatusConflict{Current: "done"}
		}
		if err := tx.Exec(`UPDATE ads.alert_event SET alert_status='closed',closed_at=$1,close_note=$2
			WHERE id=$3 AND occurred_at=$4`, now, closeNote, row.ID, row.OccurredAt).Error; err != nil {
			return err
		}
		return auditLog(tx, op, "alert_close", "alert_event", strconv.FormatInt(alertID, 10),
			map[string]any{"close_note": closeNote}, ip, now)
	})
	if err != nil {
		return nil, err
	}
	return &CloseResult{ID: alertID, ClosedAt: now}, nil
}

// ---- R07 todos ---------------------------------------------------------------

// TodoFilter R07 查询参数(Status/AssigneeID nil=不过滤)
type TodoFilter struct {
	Status     *string
	AssigneeID *int64
	Offset     int
	Limit      int
}

// TodoRow R07 列表行;锚点三值/备注可空,DeptName LEFT JOIN 故可空
type TodoRow struct {
	ID            int64
	AlertID       int64
	Title         string
	AssigneeID    int64
	AssigneeName  string
	DeptName      *string
	Deadline      time.Time
	TodoStatus    string
	StatusLabel   string
	BaselineValue *float64
	TargetValue   *float64
	MetricCode    *string
	Note          *string
	ResultNote    *string
	CreatedAt     time.Time
}

// TodoList 契约 §15.4——惰性过期清扫(deadline<virtual_now 的 open|doing→expired,存储值语义)
// 先行,再按过滤分页;返回 (rows,total)
func (r *WriteRepo) TodoList(ctx context.Context, f TodoFilter) ([]TodoRow, int64, error) {
	now, err := r.clk.Now(ctx)
	if err != nil {
		return nil, 0, err
	}
	if err := r.db.WithContext(ctx).Exec(`UPDATE ads.todo_order SET todo_status='expired',updated_at=$1
		WHERE todo_status IN ('open','doing') AND deadline<$1`, now).Error; err != nil {
		return nil, 0, err
	}
	filter := func(d *gorm.DB) *gorm.DB {
		if f.Status != nil {
			d = d.Where("t.todo_status = ?", *f.Status)
		}
		if f.AssigneeID != nil {
			d = d.Where("t.assignee_id = ?", *f.AssigneeID)
		}
		return d
	}
	var total int64
	if err := filter(r.db.WithContext(ctx).Table("ads.todo_order t")).Count(&total).Error; err != nil {
		return nil, 0, err
	}
	rows := make([]TodoRow, 0, f.Limit)
	err = filter(r.db.WithContext(ctx).Table("ads.todo_order t").
		Select(`t.id,t.alert_id,t.title,t.assignee_id,s.name AS assignee_name,dp.name AS dept_name,
			t.deadline,t.todo_status,d.dict_label AS status_label,t.baseline_value,t.target_value,
			t.metric_code,t.note,t.result_note,t.created_at`).
		Joins("JOIN dim.staff s ON s.id = t.assignee_id").
		Joins("LEFT JOIN dim.department dp ON dp.id = s.dept_id").
		Joins("JOIN sys.dict d ON d.dict_type = 'todo_status' AND d.dict_key = t.todo_status")).
		Order("t.id DESC").
		Limit(f.Limit).Offset(f.Offset).
		Scan(&rows).Error
	return rows, total, err
}

// TodoCurrentValues 三点锚点 current 批量版——单条 SQL 对本页全部 metric_code 一次取齐
// (AGENTS §4 列表一次取齐,消 N+1):today_kpi(院级实时)优先,缺位回落
// dws.metric_value 最新期值;两源皆 miss 的 code 不入 map→调用方置 nil(契约 §15.4 冻结口径)
func (r *WriteRepo) TodoCurrentValues(ctx context.Context, codes []string) (map[string]float64, error) {
	out := make(map[string]float64, len(codes))
	if len(codes) == 0 {
		return out, nil
	}
	var rows []struct {
		MetricCode string
		Value      float64
	}
	err := r.db.WithContext(ctx).Raw(
		`SELECT k.metric_code,COALESCE(t.value, mv.value) AS value
		 FROM unnest($1::text[]) k(metric_code)
		 LEFT JOIN ads.today_kpi t ON t.metric_code=k.metric_code AND t.dept_id=0
		 LEFT JOIN LATERAL (
		   SELECT value FROM dws.metric_value m
		   WHERE m.metric_code=k.metric_code AND m.dept_id=0 AND m.group_id=0
		   ORDER BY date DESC LIMIT 1
		 ) mv ON t.metric_code IS NULL`,
		"{"+strings.Join(codes, ",")+"}").Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	for _, r2 := range rows {
		out[r2.MetricCode] = r2.Value
	}
	return out, nil
}

// ---- R08 todo status ---------------------------------------------------------

// TodoTransitResult R08 出参(AlertStatus=回填后值;accept 不回填时回当前态)
type TodoTransitResult struct {
	ID          int64
	TodoStatus  string
	AlertID     int64
	AlertStatus string
}

// TodoTransit 契约 §15.5——单事务:锁工单(JOIN 承办人取科室)→dept_leader 域闸→
// 状态机(accept:open→doing;report:doing→done 双表回填 alert done)→审计 todo_status。
// expired 为存储值(R07 惰性清扫),本函数按库存态判定不另扫。
func (r *WriteRepo) TodoTransit(ctx context.Context, op Operator, todoID int64, action,
	resultNote, ip string) (*TodoTransitResult, error) {
	now, err := r.clk.Now(ctx)
	if err != nil {
		return nil, err
	}
	var res TodoTransitResult
	err = r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		var row struct {
			ID              int64
			TodoStatus      string
			AlertID         int64
			AlertOccurredAt time.Time
			AssigneeDeptID  int64
		}
		q := tx.Raw(`SELECT t.id,t.todo_status,t.alert_id,t.alert_occurred_at,s.dept_id AS assignee_dept_id
			FROM ads.todo_order t JOIN dim.staff s ON s.id=t.assignee_id
			WHERE t.id=$1 FOR UPDATE OF t`, todoID).Scan(&row)
		if q.Error != nil {
			return q.Error
		}
		if q.RowsAffected == 0 {
			return ErrTodoNotFound
		}
		// dept_leader 仅可办本科室单:sys.user.dept_id 比对承办人 staff.dept_id(§15.5 20005)
		if op.Role == "dept_leader" && (op.DeptID == nil || *op.DeptID != row.AssigneeDeptID) {
			return ErrScopeDeny
		}
		from := row.TodoStatus
		res.ID, res.AlertID = todoID, row.AlertID
		switch action {
		case "accept":
			if row.TodoStatus != "open" {
				return &StatusConflict{Current: row.TodoStatus}
			}
			if err := tx.Exec(`UPDATE ads.todo_order SET todo_status='doing',updated_at=$1 WHERE id=$2`,
				now, todoID).Error; err != nil {
				return err
			}
			res.TodoStatus = "doing"
			if err := tx.Raw(`SELECT alert_status FROM ads.alert_event WHERE id=$1 AND occurred_at=$2`,
				row.AlertID, row.AlertOccurredAt).Scan(&res.AlertStatus).Error; err != nil {
				return err
			}
		case "report":
			if row.TodoStatus == "open" {
				return ErrNeedAccept
			}
			if row.TodoStatus != "doing" { // done|expired→33104
				return &StatusConflict{Current: row.TodoStatus}
			}
			if err := tx.Exec(`UPDATE ads.todo_order SET todo_status='done',result_note=$1,updated_at=$2 WHERE id=$3`,
				resultNote, now, todoID).Error; err != nil {
				return err
			}
			if err := tx.Exec(`UPDATE ads.alert_event SET alert_status='done',done_at=$1
				WHERE id=$2 AND occurred_at=$3`, now, row.AlertID, row.AlertOccurredAt).Error; err != nil {
				return err
			}
			res.TodoStatus, res.AlertStatus = "done", "done"
		}
		return auditLog(tx, op, "todo_status", "todo_order", strconv.FormatInt(todoID, 10),
			map[string]any{"from": from, "to": res.TodoStatus}, ip, now)
	})
	if err != nil {
		return nil, err
	}
	return &res, nil
}

// ---- R10 staff ---------------------------------------------------------------

// StaffOption R10 出参行
type StaffOption struct {
	ID       int64
	Code     string
	Name     string
	Title    string
	DeptID   int64
	DeptName string
	IsLeader bool
}

// StaffOptions 契约 §15.6——在职人员联想,is_leader(department.leader_id=staff.id)优先
func (r *WriteRepo) StaffOptions(ctx context.Context, deptID *int64) ([]StaffOption, error) {
	rows := make([]StaffOption, 0, 32)
	q := r.db.WithContext(ctx).Table("dim.staff s").
		Select("s.id,s.code,s.name,s.title,s.dept_id,d.name AS dept_name,(d.leader_id = s.id) AS is_leader").
		Joins("JOIN dim.department d ON d.id = s.dept_id").
		Where("s.active")
	if deptID != nil {
		q = q.Where("s.dept_id = ?", *deptID)
	}
	err := q.Order("is_leader DESC, s.id").Scan(&rows).Error
	return rows, err
}

// ---- R15 rule toggle ---------------------------------------------------------

// RuleToggle 契约 §15.7——source='rule' 行 enabled 写回;0 行→ErrRuleNotFound(10003)
func (r *WriteRepo) RuleToggle(ctx context.Context, op Operator, code string, enabled bool, ip string) error {
	now, err := r.clk.Now(ctx)
	if err != nil {
		return err
	}
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		res := tx.Exec(`UPDATE ads.alert_rule SET enabled=$1,updated_at=$2 WHERE code=$3 AND source='rule'`,
			enabled, now, code)
		if res.Error != nil {
			return res.Error
		}
		if res.RowsAffected == 0 {
			return ErrRuleNotFound
		}
		return auditLog(tx, op, "rule_toggle", "alert_rule", code,
			map[string]any{"code": code, "enabled": enabled}, ip, now)
	})
}

// ---- R16 preferences ---------------------------------------------------------

// PrefInput R16 已校验入参(nil=该键未提交);库内换算由 PrefsSave 完成
type PrefInput struct {
	DefaultRange    *string // 本月/本季/本年
	RefreshInterval *string // "5 分钟"/"15 分钟"/"30 分钟"
	AlertSound      *bool
	UnitAbbrev      *bool
	PrivacyMask     *bool
}

// prefRangeKey 契约显示文案→库内键(§15.8 换算)
var prefRangeKey = map[string]string{"本月": "month", "本季": "quarter", "本年": "year"}

// prefRangeLabel 库内键→契约显示文案(回写后全量拼装用)
var prefRangeLabel = map[string]string{"month": "本月", "quarter": "本季", "year": "本年"}

// prefIntervalSec "N 分钟"→秒
var prefIntervalSec = map[string]int{"5 分钟": 300, "15 分钟": 900, "30 分钟": 1800}

// PrefKeyRange/PrefKeyInterval 供 handler 做枚举校验(值域唯一出处在本文件)
func PrefKeyRange(display string) bool    { _, ok := prefRangeKey[display]; return ok }
func PrefKeyInterval(display string) bool { _, ok := prefIntervalSec[display]; return ok }

// PrefRangeLabel 库内键→契约显示文案(R16 回写后全量拼装用)
func PrefRangeLabel(key string) (string, bool) { l, ok := prefRangeLabel[key]; return l, ok }

// PrefsSave 契约 §15.8——逐键 INSERT...ON CONFLICT(user_id,pref_key) upsert,
// updated_at 显式传虚拟时钟;审计 pref_save detail.keys=本次写入键集(稳定序)
func (r *WriteRepo) PrefsSave(ctx context.Context, op Operator, in PrefInput, ip string) error {
	now, err := r.clk.Now(ctx)
	if err != nil {
		return err
	}
	kv := map[string]any{}
	if in.DefaultRange != nil {
		kv["default_range"] = prefRangeKey[*in.DefaultRange]
	}
	if in.RefreshInterval != nil {
		kv["refresh_interval"] = prefIntervalSec[*in.RefreshInterval]
	}
	if in.AlertSound != nil {
		kv["alert_sound"] = *in.AlertSound
	}
	if in.UnitAbbrev != nil {
		kv["unit_abbreviation"] = *in.UnitAbbrev
	}
	if in.PrivacyMask != nil {
		kv["privacy_mask"] = *in.PrivacyMask
	}
	if len(kv) == 0 {
		return nil
	}
	// 审计 detail.keys 顺序稳定——按契约 5 键固定序收集
	keys := make([]string, 0, len(kv))
	for _, k := range []string{"default_range", "refresh_interval", "alert_sound", "unit_abbreviation", "privacy_mask"} {
		if _, ok := kv[k]; ok {
			keys = append(keys, k)
		}
	}
	return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		for _, k := range keys {
			b, err := json.Marshal(kv[k])
			if err != nil {
				return err
			}
			if err := tx.Exec(`INSERT INTO sys.user_pref(user_id,pref_key,pref_val,updated_at)
				VALUES($1,$2,$3::jsonb,$4)
				ON CONFLICT (user_id,pref_key) DO UPDATE
				SET pref_val=EXCLUDED.pref_val,updated_at=EXCLUDED.updated_at`,
				op.ID, k, string(b), now).Error; err != nil {
				return err
			}
		}
		return auditLog(tx, op, "pref_save", "user_pref", strconv.FormatInt(op.ID, 10),
			map[string]any{"keys": keys}, ip, now)
	})
}

// PrefsLoad 指定用户偏好 KV(pref_val jsonb 原文;与 SettingPrefs 同口径,R16 回写后拼装用)
func (r *WriteRepo) PrefsLoad(ctx context.Context, userID int64) (map[string][]byte, error) {
	type row struct {
		Key string
		Val []byte
	}
	var rows []row
	err := r.db.WithContext(ctx).
		Table("sys.user_pref").
		Select("pref_key AS key, pref_val AS val").
		Where("user_id = ?", userID).
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	out := make(map[string][]byte, len(rows))
	for _, rw := range rows {
		out[rw.Key] = rw.Val
	}
	return out, nil
}
