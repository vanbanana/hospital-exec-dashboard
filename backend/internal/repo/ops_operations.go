// §6 GET /workbench/operations 专属查询——科室经营表(dept_table)合并口径(E2-T3 属主文件)
package repo

import (
	"context"
	"sort"
)

// DeptEconRow 科室经营行:dept_oper_day 收入/成本/结余 + charge_day 费用拆分合并
type DeptEconRow struct {
	DeptID int64
	Name   string
	Rev    float64 // Σrevenue(元)
	Cost   float64 // Σcost(元)
	Prof   float64 // Σprofit(元)
	Fee    float64 // Σ(in_fee+out_fee)——药耗占比分母
	Drug   float64 // Σ(in_drug+out_drug)
	Mat    float64 // Σmaterial
}

// DeptEconTop 窗口内按 Σrevenue 降序取前 n 科室;收费拆分 LEFT 合并(无 charge 行科室费项为 0,
// 比率由调用方按除零保护处理),收入全集仍经 DeptSums 的 level=2 过滤防医疗组双算
func (r *Ops) DeptEconTop(ctx context.Context, w RangeWin, n int) ([]DeptEconRow, error) {
	sums, err := r.DeptSums(ctx, w)
	if err != nil {
		return nil, err
	}
	charges, err := r.DeptCharges(ctx, w)
	if err != nil {
		return nil, err
	}
	ch := make(map[int64]DeptCharge, len(charges))
	for _, x := range charges {
		ch[x.DeptID] = x
	}
	rows := make([]DeptEconRow, 0, len(sums))
	for _, s := range sums {
		row := DeptEconRow{DeptID: s.DeptID, Name: s.Name, Rev: s.Revenue, Cost: s.Cost, Prof: s.Profit}
		if c, ok := ch[s.DeptID]; ok {
			row.Fee = c.InFee + c.OutFee
			row.Drug = c.InDrug + c.OutDrug
			row.Mat = c.Mat
		}
		rows = append(rows, row)
	}
	sort.Slice(rows, func(i, j int) bool { return rows[i].Rev > rows[j].Rev })
	if len(rows) > n {
		rows = rows[:n]
	}
	return rows, nil
}
