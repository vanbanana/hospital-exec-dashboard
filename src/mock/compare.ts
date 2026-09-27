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

// 契约示例锚定 range=本月；outp/inpt 为月量，随 range 按全院月度序列（§3.2 同源）累计放大
const OUTP_MONTHLY = [54000, 46000, 68000, 70000, 85000, 90000, 108000, 97000, 105000, 123000, 122000, 120000]
const INPT_MONTHLY = [5900, 4970, 6410, 6820, 7240, 7450, 8070, 8480, 7850, 8120, 7650, 7450]

const rangeSlice: Record<RangeKey, [number, number]> = { 本月: [9, 10], 本季: [7, 10], 本年: [0, 10] }
const sumRange = (arr: number[], r: RangeKey) => {
  const [a, b] = rangeSlice[r]
  return arr.slice(a, b).reduce((x, y) => x + y, 0)
}
const fmt = (n: number) => n.toLocaleString('en-US')

const ROWS = [
  { dept: '心血管内科', yoy: '+6.2%', outp: 12860, inpt: 1250, days: 9.2, sat: 96.2 },
  { dept: '呼吸与危重症医学科', yoy: '+8.7%', outp: 11580, inpt: 990, days: 10.4, sat: 94.8 },
  { dept: '骨科', yoy: '+5.8%', outp: 7160, inpt: 1120, days: 8.6, sat: 95.4 },
  { dept: '神经内科', yoy: '+4.1%', outp: 9680, inpt: 800, days: 11.2, sat: 93.6 },
  { dept: '普通外科', yoy: '+3.4%', outp: 6080, inpt: 920, days: 7.8, sat: 94.2 },
  { dept: '肿瘤科', yoy: '+5.9%', outp: 4450, inpt: 735, days: 12.6, sat: 92.8 },
]

/**
 * §12.1 GET /workbench/compare — range 语义实算：
 * outp/inpt 按各自全院月度序列累计系数缩放；metric 按契约冻结公式 outp + inpt×10 重算（§12.1 注4），
 * rank/bar_pct 随缩放后量值重排；days/sat/yoy/radar/benchmarks 为比率或年度对标值不随 range 变。
 */
export function getCompareMock(dim?: string, range?: string): CompareResp {
  const d: CompareDim =
    dim === 'benefit' || dim === 'efficiency' || dim === 'quality' ? dim : 'scale'
  const r: RangeKey = range === '本季' || range === '本年' ? range : '本月'
  const fOutp = sumRange(OUTP_MONTHLY, r) / OUTP_MONTHLY[9]
  const fInpt = sumRange(INPT_MONTHLY, r) / INPT_MONTHLY[9]
  const scaled = ROWS.map((row) => {
    const outp = Math.round(row.outp * fOutp)
    const inpt = Math.round(row.inpt * fInpt)
    return { ...row, outp, inpt, metric: outp + inpt * 10 }
  }).sort((x, y) => y.metric - x.metric)
  const maxMetric = scaled[0]?.metric ?? 1
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
      rows: scaled.map((row, i) => ({
        rank: i + 1,
        dept: row.dept,
        metric: fmt(row.metric),
        bar_pct: Math.round((row.metric / maxMetric) * 100),
        yoy: row.yoy,
        outp: row.outp,
        inpt: row.inpt,
        days: row.days,
        sat: row.sat,
      })),
    },
  }
}
