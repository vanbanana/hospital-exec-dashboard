// sim 域全部 SQL(契约 §16 档 A)——clock/job_log/profile 三表。
// 时钟写操作(tick/reset/set)统一单事务骨架:running 检查 → FOR UPDATE → 界校验 → UPDATE → job_log;
// 界校验上界=播种末日+1 由应用层做(migration ck_clock_window 注),date 列扫回 UTC 零点,
// 比较前一律归一化到时钟行时区(+08),避免界点漂移 8h。
package repo

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

// 业务退出码载体——handler 按 errors.Is 映射 35003/35002(error-codes §3 35xxx)
var (
	ErrSimBusy  = errors.New("sim job running")
	ErrSimBound = errors.New("virtual time out of seed bounds")
)

// SimClockRow sim.clock 单行(id=1);BaseDate/SeedEnd 为 date 列(UTC 零点,出参取日历日)
type SimClockRow struct {
	VirtualNow time.Time
	Speed      float64
	Paused     bool
	BaseDate   time.Time
	UpdatedAt  time.Time
}

// SimJobRow sim.job_log 台账行;FinishedAt/Err 可 NULL
type SimJobRow struct {
	ID          int64
	Job         string
	VirtualDate time.Time
	StartedAt   time.Time
	FinishedAt  *time.Time
	RowsCnt     int
	JobStatus   string
	Err         *string
}

const simRunningExists = `SELECT EXISTS(SELECT 1 FROM sim.job_log WHERE job_status='running')`

// SimClock 时钟读面 + seed_end 解析(契约 §16.1)
func SimClock(ctx context.Context, db *gorm.DB) (SimClockRow, time.Time, error) {
	var row SimClockRow
	tx := db.WithContext(ctx).Raw(
		`SELECT virtual_now, speed, paused, base_date, updated_at FROM sim.clock WHERE id=1`).Scan(&row)
	if tx.Error != nil {
		return row, time.Time{}, tx.Error
	}
	seedEnd, err := simSeedEnd(ctx, db)
	return row, seedEnd, err
}

// simSeedEnd 解析序:sim.profile key='seed_end'(jsonb 字符串,#>> '{}' 取文本)
// → 缺省/解析失败回退 MAX(dwd.charge_day.date)(契约 §16.1 字段注)
func simSeedEnd(ctx context.Context, db *gorm.DB) (time.Time, error) {
	var s string
	tx := db.WithContext(ctx).Raw(
		`SELECT val #>> '{}' AS v FROM sim.profile WHERE key='seed_end'`).Scan(&s)
	if tx.Error != nil {
		return time.Time{}, tx.Error
	}
	if tx.RowsAffected > 0 {
		if d, err := time.Parse("2006-01-02", s); err == nil {
			return d, nil
		}
	}
	// 空 charge_day → MAX 为 NULL,指针接收防 Scan 报原生转换错;NULL 时给可读语义错
	var d *time.Time
	if err := db.WithContext(ctx).Raw(`SELECT MAX(date) FROM dwd.charge_day`).Scan(&d).Error; err != nil {
		return time.Time{}, err
	}
	if d == nil {
		return time.Time{}, errors.New("seed_end 无法解析:sim.profile 缺省且 dwd.charge_day 为空")
	}
	return *d, nil
}

// checkRunning 写事务第一步:任一 running 批次存在即 ErrSimBusy(契约 §16.2 语义注)
func checkRunning(tx *gorm.DB) error {
	var running bool
	if err := tx.Raw(simRunningExists).Scan(&running).Error; err != nil {
		return err
	}
	if running {
		return ErrSimBusy
	}
	return nil
}

// dayBound 把 date 列(扫回 UTC 零点)还原成 loc 时区的日历日,便于与时钟时刻比瞬时
func dayBound(d time.Time, loc *time.Location) time.Time {
	return time.Date(d.Year(), d.Month(), d.Day(), 0, 0, 0, 0, loc)
}

// insertJobLog 作业台账行;审计时刻走 DB statement_timestamp()(墙钟,与 clock.updated_at 同理)
func insertJobLog(tx *gorm.DB, job string, virtualDate time.Time, rowsCnt int) (int64, error) {
	var id int64
	err := tx.Raw(`INSERT INTO sim.job_log (job, virtual_date, started_at, finished_at, rows_cnt, job_status)
		VALUES (?, ?, statement_timestamp(), statement_timestamp(), ?, 'success') RETURNING id`,
		job, virtualDate, rowsCnt).Scan(&id).Error
	return id, err
}

// SimTick 时钟前移(契约 §16.2):virtual_now + minutes 不越 seed_end+1天,越界 ErrSimBound
func SimTick(ctx context.Context, db *gorm.DB, minutes int) (before, after time.Time, jobID int64, err error) {
	err = db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := checkRunning(tx); err != nil {
			return err
		}
		if err := tx.Raw(`SELECT virtual_now FROM sim.clock WHERE id=1 FOR UPDATE`).Scan(&before).Error; err != nil {
			return err
		}
		seedEnd, err := simSeedEnd(ctx, tx)
		if err != nil {
			return err
		}
		if before.Add(time.Duration(minutes) * time.Minute).After(dayBound(seedEnd, before.Location()).AddDate(0, 0, 1)) {
			return ErrSimBound
		}
		if err := tx.Raw(`UPDATE sim.clock
			SET virtual_now = virtual_now + (?::int || ' minutes')::interval, updated_at = statement_timestamp()
			WHERE id=1 RETURNING virtual_now`, minutes).Scan(&after).Error; err != nil {
			return err
		}
		jobID, err = insertJobLog(tx, "SimTick", after, minutes)
		return err
	})
	return before, after, jobID, err
}

// SimReset 时钟复位 base_date 09:00(契约 §16.3,幂等);
// base_date+9h 按 timestamptz 直接加,勿转 date 拼字符串(任务书 §16.3 时区语义)
func SimReset(ctx context.Context, db *gorm.DB) (after time.Time, jobID int64, err error) {
	err = db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := checkRunning(tx); err != nil {
			return err
		}
		var res struct {
			VirtualNow time.Time
			BaseDate   time.Time
		}
		if err := tx.Raw(`UPDATE sim.clock
			SET virtual_now = base_date::timestamptz + interval '9 hours',
			    speed = 1, paused = false, updated_at = statement_timestamp()
			WHERE id=1 RETURNING virtual_now, base_date`).Scan(&res).Error; err != nil {
			return err
		}
		after = res.VirtualNow
		jobID, err = insertJobLog(tx, "SimReset", res.BaseDate, 0)
		return err
	})
	return after, jobID, err
}

// SimSetPatch 定点跳转出席字段(契约 §16.5 全可选);nil=不写该列
type SimSetPatch struct {
	VirtualNow *time.Time
	Speed      *int
	Paused     *bool
}

// SimSetClock 定点设定(契约 §16.5):出席 virtual_now 时界校验 ∈[base_date, seed_end+1天];
// UPDATE 用 COALESCE 只写出席列,保持单条 SQL 零拼接
func SimSetClock(ctx context.Context, db *gorm.DB, p SimSetPatch) (after time.Time, jobID int64, err error) {
	err = db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		if err := checkRunning(tx); err != nil {
			return err
		}
		var row struct {
			VirtualNow time.Time
			BaseDate   time.Time
		}
		if err := tx.Raw(`SELECT virtual_now, base_date FROM sim.clock WHERE id=1 FOR UPDATE`).Scan(&row).Error; err != nil {
			return err
		}
		if p.VirtualNow != nil {
			seedEnd, err := simSeedEnd(ctx, tx)
			if err != nil {
				return err
			}
			loc := row.VirtualNow.Location()
			if p.VirtualNow.Before(dayBound(row.BaseDate, loc)) ||
				p.VirtualNow.After(dayBound(seedEnd, loc).AddDate(0, 0, 1)) {
				return ErrSimBound
			}
		}
		if err := tx.Raw(`UPDATE sim.clock
			SET virtual_now = COALESCE(?, virtual_now),
			    speed = COALESCE(?, speed),
			    paused = COALESCE(?, paused),
			    updated_at = statement_timestamp()
			WHERE id=1 RETURNING virtual_now`,
			p.VirtualNow, p.Speed, p.Paused).Scan(&after).Error; err != nil {
			return err
		}
		jobID, err = insertJobLog(tx, "SimSet", after, 0)
		return err
	})
	return after, jobID, err
}

// SimJobs 台账分页(契约 §16.4):job/status 空串=不过滤,排序 started_at DESC, id DESC
func SimJobs(ctx context.Context, db *gorm.DB, job, status string, page, size int) ([]SimJobRow, int64, error) {
	var total int64
	err := db.WithContext(ctx).Raw(`SELECT COUNT(*) FROM sim.job_log
		WHERE (job=? OR ?='') AND (job_status=? OR ?='')`,
		job, job, status, status).Scan(&total).Error
	if err != nil {
		return nil, 0, err
	}
	var rows []SimJobRow
	err = db.WithContext(ctx).Raw(`SELECT id, job, virtual_date, started_at, finished_at, rows_cnt, job_status, err
		FROM sim.job_log
		WHERE (job=? OR ?='') AND (job_status=? OR ?='')
		ORDER BY started_at DESC, id DESC LIMIT ? OFFSET ?`,
		job, job, status, status, size, (page-1)*size).Scan(&rows).Error
	return rows, total, err
}
