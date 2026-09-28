// Package clock 唯一时间源(AGENTS §2-6):业务"今天"一律读 sim.clock.virtual_now,
// 禁止 time.Now 进业务逻辑——全库可复现靠这一条
package clock

import (
	"context"
	"errors"
	"time"

	"gorm.io/gorm"
)

type Source struct {
	db *gorm.DB
}

func New(db *gorm.DB) *Source {
	return &Source{db: db}
}

// ErrNoClockRow sim.clock 锚定行(id=1)缺失——缺行时 Scan 出零值时刻不报错,
// 会让全部业务"今天"静默坍成 0001-01-01;repo 侧 sim 写事务的 FOR UPDATE/RETURNING
// 零行同判此错(单哨兵,handler 统一落 10000)
var ErrNoClockRow = errors.New("sim.clock 缺锚定行(id=1)")

// Now 当前虚拟时刻;sim.clock 单行(id=1)由种子锚定 BASE_DATE=2026-10-28
func (s *Source) Now(ctx context.Context) (time.Time, error) {
	var t time.Time
	tx := s.db.WithContext(ctx).
		Table("sim.clock").
		Select("virtual_now").
		Where("id = 1").
		Scan(&t)
	if tx.Error != nil {
		return t, tx.Error
	}
	if tx.RowsAffected == 0 {
		return t, ErrNoClockRow
	}
	return t, nil
}

// Today 虚拟日期(去掉时分秒)
func (s *Source) Today(ctx context.Context) (time.Time, error) {
	t, err := s.Now(ctx)
	if err != nil {
		return t, err
	}
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, t.Location()), nil
}

// WeekdayCN 中文星期文案(契约 system_date 伴生字段)
func WeekdayCN(t time.Time) string {
	names := []string{"星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"}
	return names[t.Weekday()]
}
