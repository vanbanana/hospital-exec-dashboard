// Home 工作台首页端点集合(契约 §3)——struct 唯一声明处,方法由 home_agg.go/home_list.go 分挂
package handler

import (
	"gorm.io/gorm"

	"hospital-edss/internal/clock"
)

type Home struct {
	db  *gorm.DB
	clk *clock.Source
}

func NewHome(db *gorm.DB, clk *clock.Source) *Home {
	return &Home{db: db, clk: clk}
}
