// 对比分析数据包 — api-contract §12.1（dim=scale）示例锚定
import type { CompareDim, CompareResp, RangeKey } from '../api/types'

// §12.1 维度枚举 → metric 列名映射表
const DIM_METRIC: Record<CompareDim, string> = {
  scale: '业务量当量',
  benefit: '医疗收入',
  efficiency: '床位周转次数',
  quality: '质量综合评分',
}

const BASE: Pick<CompareResp, 'radar' | 'benchmarks'> = {
  radar: {
    indicators: [
      { name: '业务规模', max: 100 },
      { name: '收入能力', max: 100 },
      { name: '运营效率', max: 100 },
      { name: '医疗质量', max: 100 },
      { name: '患者满意', max: 100 },
      { name: '科研教学', max: 100 },
    ],
    series: [
      { name: '本院', value: [86, 82, 78, 88, 90, 74] },
      { name: '区域同级均值', value: [72, 70, 68, 76, 78, 58] },
    ],
  },
  benchmarks: [
    { name: '年门急诊量（万人次）', ours: '108.8', region: '90.0', bench: '128.0', gap: '+18.8' },
    { name: '年出院人数（万人）', ours: '8.64', region: '8.22', bench: '11.58', gap: '+0.42' },
    { name: '平均住院日（天）', ours: '6.8', region: '7.9', bench: '6.2', gap: '-1.1' },
    { name: '三四级手术占比（%）', ours: '58.6', region: '48.2', bench: '65.0', gap: '+10.4' },
    { name: '药占比（%）', ours: '28.4', region: '31.6', bench: '25.0', gap: '-3.2' },
    { name: 'CMI 值', ours: '1.08', region: '0.96', bench: '1.22', gap: '+0.12' },
  ],
}

const ROWS = [
  { rank: 1, dept: '心血管内科', metric: '25,360', bar_pct: 100, yoy: '+6.2%', outp: 12860, inpt: 1250, days: 9.2, sat: 96.2 },
  { rank: 2, dept: '呼吸与危重症医学科', metric: '21,480', bar_pct: 85, yoy: '+8.7%', outp: 11580, inpt: 990, days: 10.4, sat: 94.8 },
  { rank: 3, dept: '骨科', metric: '18,360', bar_pct: 72, yoy: '+5.8%', outp: 7160, inpt: 1120, days: 8.6, sat: 95.4 },
  { rank: 4, dept: '神经内科', metric: '17,680', bar_pct: 70, yoy: '+4.1%', outp: 9680, inpt: 800, days: 11.2, sat: 93.6 },
  { rank: 5, dept: '普通外科', metric: '15,280', bar_pct: 58, yoy: '+3.4%', outp: 6080, inpt: 920, days: 7.8, sat: 94.2 },
  { rank: 6, dept: '肿瘤科', metric: '11,800', bar_pct: 45, yoy: '+5.9%', outp: 4450, inpt: 735, days: 12.6, sat: 92.8 },
]

/** §12.1 GET /workbench/compare；契约仅锚定 dim=scale 行集，其余 dim 复用同口径行并换 metric 列名 */
export function getCompareMock(dim?: string, range?: string): CompareResp {
  const d: CompareDim =
    dim === 'benefit' || dim === 'efficiency' || dim === 'quality' ? dim : 'scale'
  const r: RangeKey = range === '本季' || range === '本年' ? range : '本月'
  return {
    dimension: d,
    range: r,
    ...BASE,
    table: {
      columns: [
        { key: 'rank', title: '排名', align: 'center' },
        { key: 'dept', title: '科室' },
        { key: 'metric', title: DIM_METRIC[d] },
        { key: 'yoy', title: '同比', align: 'right', num: true },
        { key: 'outp', title: '门诊人次', align: 'right', num: true },
        { key: 'inpt', title: '出院人次', align: 'right', num: true },
        { key: 'days', title: '平均住院日', align: 'right', num: true },
        { key: 'sat', title: '满意度', align: 'right', num: true },
      ],
      rows: ROWS,
    },
  }
}
