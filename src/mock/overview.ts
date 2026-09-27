// 综合概览数据包 — api-contract §4.1 示例锚定
import type { OverviewResp, RangeKey } from '../api/types'
import { DELTA_LABEL } from './labels'

const MONTHS = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月']
const OUTPATIENT = [54000, 46000, 68000, 70000, 85000, 90000, 108000, 97000, 105000, 123000, 122000, 120000]
const DISCHARGED = [5900, 4970, 6410, 6820, 7240, 7450, 8070, 8480, 7850, 8120, 7650, 7450]
const SURGERY = [860, 720, 980, 1020, 1080, 1120, 1180, 1210, 1150, 1286, 1200, 1160]
const REVENUE = [8950, 8060, 10800, 11650, 12450, 12980, 13940, 13550, 13080, 14800, 14240, 13720]

// 契约 §4.1 注1：range=本年 的累计指标 = 月度序列前 10 个月求和（846,000 / 71,310 / 10,606 / 120,260 已验证）；
// 本月=10月单月，本季=8~10月求和，推导保证三种 range 全部锚定契约序列而非另造数字
const rangeSlice: Record<RangeKey, [number, number]> = { 本月: [9, 10], 本季: [7, 10], 本年: [0, 10] }
const sumRange = (arr: number[], range: RangeKey) => {
  const [a, b] = rangeSlice[range]
  return arr.slice(a, b).reduce((x, y) => x + y, 0)
}
const fmt = (n: number) => n.toLocaleString('en-US')

/** §4.1 GET /workbench/overview（rate 类指标为时点口径，不随 range 累计） */
export function getOverviewMock(range?: string): OverviewResp {
  const r: RangeKey = range === '本月' || range === '本季' ? range : '本年'
  return {
    range: r,
    stats: [
      { label: '门急诊人次', value: fmt(sumRange(OUTPATIENT, r)), delta: '+3.6%', dir: 'up', delta_label: DELTA_LABEL[r] },
      { label: '出院人数', value: fmt(sumRange(DISCHARGED, r)), delta: '+5.1%', dir: 'up', delta_label: DELTA_LABEL[r] },
      { label: '手术台次', value: fmt(sumRange(SURGERY, r)), delta: '+4.8%', dir: 'up', delta_label: DELTA_LABEL[r] },
      { label: '医疗收入', value: fmt(sumRange(REVENUE, r)), unit: '万元', delta: '+2.9%', dir: 'up', delta_label: DELTA_LABEL[r] },
      { label: '床位使用率', value: '92.1', unit: '%', delta: '+1.2%', dir: 'up', delta_label: DELTA_LABEL[r] },
      { label: '平均住院日', value: '6.8', unit: '天', delta: '-0.3', dir: 'down', delta_label: DELTA_LABEL[r] },
    ],
    scale_revenue_trend: {
      months: MONTHS,
      outpatient: OUTPATIENT,
      revenue: REVENUE,
      units: { outpatient: '人次', revenue: '万元' },
    },
    income_structure: {
      unit: '%',
      list: [
        { name: '住院收入', value: 71 },
        { name: '门诊收入', value: 25 },
        { name: '其他收入', value: 4 },
      ],
    },
    dept_share_top8: {
      metric: '住院收入（万元·本月）',
      unit: '万元',
      list: [
        { name: '心血管内科', value: 1723, bar_pct: 100 },
        { name: '骨科', value: 1515, bar_pct: 88 },
        { name: '呼吸与危重症医学科', value: 1364, bar_pct: 79 },
        { name: '普通外科', value: 1220, bar_pct: 71 },
        { name: '神经内科', value: 1165, bar_pct: 68 },
        { name: '肿瘤科', value: 1128, bar_pct: 65 },
        { name: '妇产科', value: 976, bar_pct: 57 },
        { name: '儿科', value: 877, bar_pct: 51 },
      ],
    },
    live_inpatient: [
      { label: '当前在院人数', value: '1,846', tone: 'primary' },
      { label: '今日入院人数', value: '285', tone: 'teal' },
      { label: '今日出院核准', value: '272', tone: 'green' },
      { label: '急诊在观人数', value: '36', tone: 'amber' },
      { label: '重症监护在科', value: '22', tone: 'red' },
      { label: '手术进行中', value: '9', tone: 'navy' },
    ],
  }
}
