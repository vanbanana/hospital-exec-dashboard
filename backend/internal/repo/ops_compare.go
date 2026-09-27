// §12 compare 端点专属查询(E2-T4 属主文件)
// MetricLatest 的 bool 只表达 err==nil,不区分"无行"与"值为0";
// SAT_IP_SCORE 院级回退需真实行存在性,故此处按 RowsAffected 重查一次
package repo

import (
	"context"
)

// MetricLatestAt 窗口内指标最新月单值;found 表示确有行(SAT dept0 回退判断用)
func (r *Ops) MetricLatestAt(ctx context.Context, code string, deptID int64, w RangeWin) (float64, bool, error) {
	var v float64
	res := r.db.WithContext(ctx).Raw(
		`SELECT value FROM dws.metric_value
		 WHERE metric_code = ? AND dept_id = ? AND date >= ? AND date < ?
		 ORDER BY date DESC LIMIT 1`, code, deptID, w.Start, w.End).Scan(&v)
	return v, res.RowsAffected > 0, res.Error
}
