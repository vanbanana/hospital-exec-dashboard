// Package repo E3 §8.1 research 端点数据访问——事实表年度聚合与重点学科行。
// 院级指标当期/前期读数走 StaffRepo 基座 MetricAt;project/paper 前期值与
// trend/分布同源取自事实表(e3-design §8.1 "与 trend 同源" 口径)。
package repo

import (
	"context"
	"time"
)

// ProjectYearAgg 课题年度聚合(dwd.research_project,status≠'applying')
type ProjectYearAgg struct {
	Total      int     // 全级别立项数(含 hospital/other,RESEARCH_NEW_CNT 口径)
	National   int     // project_level='national'
	Provincial int     // project_level='provincial'
	FundsAmt   float64 // Σfunds_amt·元(全级别)
}

// ResearchProjectYears 按 apply_year 分组聚合给定年份;trend 序列与
// RESEARCH_NEW_CNT/RESEARCH_FUND 前期值共用本查询
func (r *StaffRepo) ResearchProjectYears(ctx context.Context, years []int) (map[int]ProjectYearAgg, error) {
	type row struct {
		ApplyYear int
		Level     string
		Cnt       int
		Funds     float64
	}
	var rows []row
	err := r.db.WithContext(ctx).
		Table("dwd.research_project").
		Select("apply_year, project_level AS level, COUNT(*) AS cnt, COALESCE(SUM(funds_amt),0) AS funds").
		Where("project_status <> 'applying' AND apply_year IN ?", years).
		Group("apply_year, project_level").
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	out := make(map[int]ProjectYearAgg, len(years))
	for _, rw := range rows {
		a := out[rw.ApplyYear]
		a.Total += rw.Cnt
		switch rw.Level {
		case "national":
			a.National += rw.Cnt
		case "provincial":
			a.Provincial += rw.Cnt
		}
		a.FundsAmt += rw.Funds
		out[rw.ApplyYear] = a
	}
	return out, nil
}

// ResearchPaperYear 指定年(period_start=年首日)论文分区聚合:quartile→篇数,
// 全学科行 Σ(discipline_id 含哨兵 0);SCI 口径=Σq1..q4
func (r *StaffRepo) ResearchPaperYear(ctx context.Context, yearStart time.Time) (map[string]int, error) {
	type row struct {
		Quartile string
		Cnt      int
	}
	var rows []row
	err := r.db.WithContext(ctx).
		Table("dws.research_paper_period").
		Select("quartile, SUM(paper_cnt) AS cnt").
		Where("period_type = 'year' AND period_start = ?", yearStart.Format("2006-01-02")).
		Group("quartile").
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	out := make(map[string]int, len(rows))
	for _, rw := range rows {
		out[rw.Quartile] = rw.Cnt
	}
	return out, nil
}

// DisciplineRow 重点学科行(disciplines 表 name/level/leader 源;id>0 哨兵除外)
type DisciplineRow struct {
	Name     string
	LevelKey string // dict discipline_level key,标签由 DictList 解析
	DeptID   int64  // 依托科室:projects/funds/papers/transfer 经此读 metric_value dept 行
	Leader   string // staff.name+" "+staff.title(契约 §8.1 拼接口径);未配置→""
}

func (r *StaffRepo) DisciplineList(ctx context.Context) ([]DisciplineRow, error) {
	rows := make([]DisciplineRow, 0, 4)
	err := r.db.WithContext(ctx).
		Table("dim.discipline AS d").
		Select("d.name, d.discipline_level AS level_key, d.dept_id, TRIM(CONCAT_WS(' ', s.name, s.title)) AS leader").
		Joins("LEFT JOIN dim.staff s ON s.id = d.leader_id").
		Where("d.id > 0 AND d.active").
		Order("d.sort").
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	return rows, nil
}
