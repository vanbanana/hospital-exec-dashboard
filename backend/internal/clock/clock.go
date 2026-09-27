// Package clock 唯一时间源(AGENTS §2-6):业务"今天"一律读 sim.clock.virtual_now,
// 禁止 time.Now 进业务逻辑——全库可复现靠这一条
package clock

import (
	"context"
	"time"

	"gorm.io/gorm"
)

type Source struct {
	db *gorm.DB
}

func New(db *gorm.DB) *Source {
	return &Source{db: db}
}

// Now 当前虚拟时刻;sim.clock 单行(id=1)由种子锚定 BASE_DATE=2026-10-28
func (s *Source) Now(ctx context.Context) (time.Time, error) {
	var t time.Time
	err := s.db.WithContext(ctx).
		Table("sim.clock").
		Select("virtual_now").
		Where("id = 1").
		Scan(&t).Error
	return t, err
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
