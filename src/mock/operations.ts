// 运营管理数据包 — api-contract §6.1 示例锚定（range=本年）
import type { OperationsResp, RangeKey } from '../api/types'
import { DELTA_LABEL } from './labels'

const MONTHS = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月']
const INCOME = [8950, 8060, 10800, 11650, 12450, 12980, 13940, 13550, 13080, 14800, 14240, 13720]
const COST = [8574, 7721, 10346, 11161, 11927, 12435, 13359, 12981, 12531, 14178, 13642, 13144]
const BALANCE = [376, 339, 454, 489, 523, 545, 581, 569, 549, 622, 598, 576]

// range 月度切片与 overview.ts 同规：本月=10月单月，本季=8~10月，本年=1~10月
const rangeSlice: Record<RangeKey, [number, number]> = { 本月: [9, 10], 本季: [7, 10], 本年: [0, 10] }
const sumRange = (arr: number[], r: RangeKey) => {
  const [a, b] = rangeSlice[r]
  return arr.slice(a, b).reduce((x, y) => x + y, 0)
}
const num = (v: string | number) => Number(String(v).replace(/,/g, ''))
const fmt = (n: number) => n.toLocaleString('en-US')
const scaleWan = (v: string, f: number) => fmt(Math.round(num(v) * f))

// dept_table 行锚定契约示例（本年累计口径，万元）；margin/药耗占比为比率列不缩放
const DEPT_ROWS = [
  { dept: '心血管内科', income: '19,270', cost: '17,940', balance: '1,330', margin: '6.9%', drug_ratio: '24.8%', mat_ratio: '18.2%' },
  { dept: '骨科', income: '15,960', cost: '14,490', balance: '1,470', margin: '9.2%', drug_ratio: '12.4%', mat_ratio: '34.6%' },
  { dept: '呼吸与危重症医学科', income: '15,070', cost: '14,500', balance: '570', margin: '3.8%', drug_ratio: '32.6%', mat_ratio: '8.4%' },
  { dept: '神经内科', income: '13,270', cost: '12,900', balance: '370', margin: '2.8%', drug_ratio: '36.4%', mat_ratio: '6.2%' },
  { dept: '普通外科', income: '12,620', cost: '11,750', balance: '870', margin: '6.9%', drug_ratio: '18.2%', mat_ratio: '22.1%' },
  { dept: '肿瘤科', income: '11,680', cost: '11,190', balance: '490', margin: '4.2%', drug_ratio: '42.8%', mat_ratio: '9.1%' },
]

/**
 * §6.1 GET /workbench/operations — range 语义实算：
 * 医疗总收入 = 月度收入序列切片求和（本年=1~10月累计 120,260 与契约示例自洽）；
 * 门诊/住院收入与 dept_table 金额列无月度拆分序列，按同一收入系数等比缩放；
 * 结余率/次均/控费为比率口径，revenue_trend 为 12 月定长轴——不随 range 累计。
 */
export function getOperationsMock(range?: string): OperationsResp {
  const r: RangeKey = range === '本月' || range === '本季' ? range : '本年'
  const f = sumRange(INCOME, r) / sumRange(INCOME, '本年')
  return {
    stats: [
      { label: '医疗总收入', value: fmt(sumRange(INCOME, r)), unit: '万元', delta: '+2.9%', dir: 'up', delta_label: DELTA_LABEL[r] },
      { label: '门诊收入', value: scaleWan('30,065', f), unit: '万元', delta: '+1.8%', dir: 'up', delta_label: DELTA_LABEL[r] },
      { label: '住院收入', value: scaleWan('85,385', f), unit: '万元', delta: '+3.6%', dir: 'up', delta_label: DELTA_LABEL[r] },
      { label: '收支结余率', value: '4.2', unit: '%', delta: '+0.4%', dir: 'up', delta_label: DELTA_LABEL[r] },
      { label: '次均门诊费用', value: '300', unit: '元', delta: '+1.8%', dir: 'up', delta_label: DELTA_LABEL[r] },
      { label: '次均住院费用', value: '13,000', unit: '元', delta: '+2.4%', dir: 'up', delta_label: DELTA_LABEL[r] },
    ],
    revenue_trend: {
      months: MONTHS,
      income: INCOME,
      cost: COST,
      balance: BALANCE,
    },
    cost_controls: [
      { name: '药占比', value: '28.4%', target: '≤30%', status: '达标', pct: 71, mark_pct: 75 },
      { name: '耗占比', value: '17.9%', target: '≤20%', status: '达标', pct: 67, mark_pct: 75 },
      { name: '次均费用增幅', value: '2.4%', target: '≤8%', status: '达标', pct: 30, mark_pct: 80 },
      { name: '百元医疗收入消耗卫生材料', value: '12.6元', target: '≤15元', status: '达标', pct: 63, mark_pct: 75 },
      { name: '住院抗菌药物使用强度', value: '38.2', target: '≤40', status: '达标', pct: 76, mark_pct: 80 },
      { name: '门诊输液率', value: '9.8%', target: '≤8%', status: '超标', pct: 86, mark_pct: 70 },
    ],
    dept_table: {
      columns: [
        { key: 'dept', title: '科室' },
        { key: 'income', title: '收入（万元）', align: 'right', num: true },
        { key: 'cost', title: '成本（万元）', align: 'right', num: true },
        { key: 'balance', title: '结余（万元）', align: 'right', num: true },
        { key: 'margin', title: '结余率', align: 'right', num: true },
        { key: 'drug_ratio', title: '药占比', align: 'right', num: true },
        { key: 'mat_ratio', title: '耗材比', align: 'right', num: true },
      ],
      rows: DEPT_ROWS.map((row) => ({
        ...row,
        income: scaleWan(row.income, f),
        cost: scaleWan(row.cost, f),
        balance: scaleWan(row.balance, f),
      })),
    },
  }
}
