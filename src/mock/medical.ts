// 医疗业务数据包 — api-contract §5.1 三个 tab 示例锚定
import type { MedicalResp, MedicalTab, RangeKey } from '../api/types'

const MONTHS = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月']

const OUTPATIENT: Omit<MedicalResp, 'tab' | 'range'> = {
  stats: [
    { label: '门急诊总人次', value: '123,443', delta: '+20.5%', dir: 'up', delta_label: '较去年' },
    { label: '普通门诊', value: '82,286', delta: '+19.8%', dir: 'up', delta_label: '较去年' },
    { label: '专家门诊', value: '29,842', delta: '+22.5%', dir: 'up', delta_label: '较去年' },
    { label: '急诊人次', value: '11,315', delta: '+20.6%', dir: 'up', delta_label: '较去年' },
    { label: '次均费用', value: '299', unit: '元', delta: '+0.1%', dir: 'up', delta_label: '较去年' },
    { label: '平均候诊', value: '17.5', unit: '分钟', delta: '0.0分钟', dir: 'flat', delta_label: '较去年' },
  ],
  trend: {
    title: '门急诊人次趋势',
    name: '门急诊人次',
    unit: '人次',
    months: MONTHS,
    values: [53896, 46037, 67829, 69861, 85253, 89777, 107966, 96920, 104798, 123443, 122208, 119591],
  },
  distribution: {
    title: '就诊高峰时段分布',
    sub: '近 30 日分时段人次',
    type: 'bar',
    unit: '人次',
    categories: ['7时', '8时', '9时', '10时', '11时', '14时', '15时', '16时', '17时', '19时'],
    values: [4686, 11923, 18014, 15702, 8077, 11076, 12807, 8286, 3396, 5197],
  },
  table: {
    columns: [
      { key: 'dept', title: '科室' },
      { key: 'cnt', title: '诊疗人次', align: 'right', num: true },
      { key: 'yoy', title: '同比', align: 'right', num: true },
      { key: 'share', title: '占比', align: 'right', num: true },
      { key: 'avg', title: '次均费用', align: 'right', num: true },
      { key: 'drug', title: '药占比', align: 'right', num: true },
    ],
    rows: [
      { dept: '心血管内科', cnt: '86,714', yoy: '+19.7%', share: '10.3%', avg: '330元', drug: '35.4%' },
      { dept: '呼吸与危重症医学科', cnt: '78,706', yoy: '+20.9%', share: '9.3%', avg: '330元', drug: '39.9%' },
      { dept: '急诊科', cnt: '77,837', yoy: '+20.8%', share: '9.2%', avg: '0元', drug: '0.0%' },
      { dept: '消化内科', cnt: '70,533', yoy: '+20.0%', share: '8.3%', avg: '336元', drug: '41.7%' },
      { dept: '神经内科', cnt: '65,760', yoy: '+19.8%', share: '7.8%', avg: '327元', drug: '38.8%' },
      { dept: '内分泌科', cnt: '56,114', yoy: '+21.7%', share: '6.6%', avg: '333元', drug: '44.0%' },
      { dept: '儿科', cnt: '53,522', yoy: '+19.9%', share: '6.3%', avg: '317元', drug: '29.4%' },
      { dept: '骨科', cnt: '48,865', yoy: '+21.3%', share: '5.8%', avg: '327元', drug: '26.0%' },
    ],
  },
}

const INPATIENT: Omit<MedicalResp, 'tab' | 'range'> = {
  stats: [
    { label: '在院人数', value: '1,846', note: '当前实时' },
    { label: '本月出院', value: '8,109', delta: '+16.1%', dir: 'up', delta_label: '较去年' },
    { label: '床位使用率', value: '92.1', unit: '%', delta: '+1.6%', dir: 'up', delta_label: '较去年' },
    { label: '平均住院日', value: '6.8', unit: '天', delta: '0.0', dir: 'flat', delta_label: '较去年' },
    { label: '床位周转次数', value: '4.0', delta: '+0.6', dir: 'up', delta_label: '较去年' },
    { label: '次均住院费用', value: '13,701', unit: '元', delta: '0.0%', dir: 'flat', delta_label: '较去年' },
  ],
  trend: {
    title: '出院人数趋势',
    name: '出院人数',
    unit: '人次',
    months: MONTHS,
    values: [5975, 4981, 6300, 6863, 7200, 7515, 8135, 8403, 7892, 8109, 7647, 7395],
  },
  distribution: {
    title: '病区床位占用',
    sub: '各病区开放床位占用率',
    type: 'bar',
    unit: '%',
    categories: ['内科', '外科', '妇产', '儿科', 'ICU', '肿瘤', '康复'],
    values: [92, 92, 97, 86, 97, 93, 90],
  },
  table: {
    columns: [
      { key: 'dept', title: '科室' },
      { key: 'cnt', title: '出院人次', align: 'right', num: true },
      { key: 'yoy', title: '同比', align: 'right', num: true },
      { key: 'share', title: '占比', align: 'right', num: true },
      { key: 'avg', title: '次均费用', align: 'right', num: true },
      { key: 'drug', title: '药占比', align: 'right', num: true },
    ],
    rows: [
      { dept: '心血管内科', cnt: '11,097', yoy: '+15.2%', share: '15.5%', avg: '13,361元', drug: '27.3%' },
      { dept: '骨科', cnt: '9,645', yoy: '+10.6%', share: '13.5%', avg: '14,054元', drug: '13.1%' },
      { dept: '呼吸与危重症医学科', cnt: '8,662', yoy: '+13.0%', share: '12.1%', avg: '13,140元', drug: '32.4%' },
      { dept: '普通外科', cnt: '8,121', yoy: '+13.8%', share: '11.4%', avg: '13,098元', drug: '17.7%' },
      { dept: '神经内科', cnt: '7,074', yoy: '+15.3%', share: '9.9%', avg: '13,621元', drug: '36.7%' },
      { dept: '肿瘤科', cnt: '6,467', yoy: '+13.7%', share: '9.1%', avg: '14,781元', drug: '41.5%' },
      { dept: '妇产科', cnt: '6,287', yoy: '+15.2%', share: '8.8%', avg: '12,256元', drug: '19.6%' },
      { dept: '儿科', cnt: '5,791', yoy: '+14.7%', share: '8.1%', avg: '11,637元', drug: '22.9%' },
    ],
  },
}

const SURGERY: Omit<MedicalResp, 'tab' | 'range'> = {
  stats: [
    { label: '本月手术台次', value: '1,286', delta: '+16.9%', dir: 'up', delta_label: '较去年' },
    { label: '三四级手术占比', value: '58.2', unit: '%', delta: '-0.3%', dir: 'down', delta_label: '较去年' },
    { label: '微创手术占比', value: '42.3', unit: '%', delta: '-0.8%', dir: 'down', delta_label: '较去年' },
    { label: '择期手术', value: '1,050', delta: '+17.4%', dir: 'up', delta_label: '较去年' },
    { label: '急诊手术', value: '236', delta: '+14.6%', dir: 'up', delta_label: '较去年' },
    { label: '手术间利用率', value: '80.1', unit: '%', delta: '+5.4%', dir: 'up', delta_label: '较去年' },
  ],
  trend: {
    title: '手术台次趋势',
    name: '手术台次',
    unit: '台',
    months: MONTHS,
    values: [860, 720, 980, 1020, 1080, 1120, 1180, 1210, 1150, 1286, 1200, 1160],
  },
  distribution: {
    title: '手术分级构成',
    sub: '本月手术级别分布',
    type: 'pie',
    unit: '%',
    categories: ['四级手术', '三级手术', '二级手术', '一级手术'],
    values: [16, 40, 32, 12],
  },
  table: {
    columns: [
      { key: 'dept', title: '科室' },
      { key: 'cnt', title: '手术台次', align: 'right', num: true },
      { key: 'yoy', title: '同比', align: 'right', num: true },
      { key: 'share', title: '占比', align: 'right', num: true },
      { key: 'avg', title: '平均时长', align: 'right', num: true },
      { key: 'drug', title: '药占比', align: 'right', num: true },
    ],
    rows: [
      { dept: '骨科', cnt: '2,355', yoy: '+14.8%', share: '22.2%', avg: '41分钟', drug: '13.1%' },
      { dept: '普通外科', cnt: '1,995', yoy: '+14.7%', share: '18.8%', avg: '56分钟', drug: '17.7%' },
      { dept: '妇产科', cnt: '1,534', yoy: '+14.6%', share: '14.5%', avg: '38分钟', drug: '19.6%' },
      { dept: '神经外科', cnt: '1,056', yoy: '+14.5%', share: '10.0%', avg: '130分钟', drug: '14.9%' },
      { dept: '泌尿外科', cnt: '957', yoy: '+14.7%', share: '9.0%', avg: '52分钟', drug: '16.5%' },
      { dept: '心胸外科', cnt: '807', yoy: '+14.5%', share: '7.6%', avg: '145分钟', drug: '15.7%' },
      { dept: '耳鼻喉科', cnt: '710', yoy: '+14.7%', share: '6.7%', avg: '34分钟', drug: '15.7%' },
      { dept: '眼科', cnt: '611', yoy: '+14.8%', share: '5.8%', avg: '22分钟', drug: '13.7%' },
    ],
  },
}

const BY_TAB: Record<MedicalTab, Omit<MedicalResp, 'tab' | 'range'>> = {
  门急诊: OUTPATIENT,
  住院: INPATIENT,
  手术: SURGERY,
}

// range 月度切片与 overview.ts 同规：本月=10月单月，本季=8~10月，本年=1~10月累计
const rangeSlice: Record<RangeKey, [number, number]> = { 本月: [9, 10], 本季: [7, 10], 本年: [0, 10] }
// trend 展示窗口：本年沿用契约示例的 12 月定长轴（同 overview 先例），本月/本季切窗口
const trendSlice: Record<RangeKey, [number, number]> = { 本月: [9, 10], 本季: [7, 10], 本年: [0, 12] }
const sumRange = (arr: number[], r: RangeKey) => {
  const [a, b] = rangeSlice[r]
  return arr.slice(a, b).reduce((x, y) => x + y, 0)
}
const num = (v: string | number) => Number(String(v).replace(/,/g, ''))
const fmt = (n: number) => n.toLocaleString('en-US')

/**
 * §5.1 GET /workbench/medical — range 语义实算：
 * stats 恒为当月口径不动（契约注）；trend 按 range 切月份窗口；
 * table.cnt 以契约示例（range=本年）为锚，按趋势序列切片占比缩放累计人次；
 * distribution 为比率/时段构成形态，无月度锚序列可缩放，随锚定值下发。
 */
export function getMedicalMock(tab?: string, range?: string): MedicalResp {
  const t: MedicalTab = tab === '住院' || tab === '手术' ? tab : '门急诊'
  const r: RangeKey = range === '本月' || range === '本季' ? range : '本年'
  const base = BY_TAB[t]
  const [a, b] = trendSlice[r]
  const f = sumRange(base.trend.values, r) / sumRange(base.trend.values, '本年')
  return {
    tab: t,
    range: r,
    stats: base.stats,
    trend: {
      ...base.trend,
      months: base.trend.months.slice(a, b),
      values: base.trend.values.slice(a, b),
    },
    distribution: base.distribution,
    table: {
      ...base.table,
      rows:
        f === 1
          ? base.table.rows
          : base.table.rows.map((row) => ({ ...row, cnt: fmt(Math.round(num(row.cnt) * f)) })),
    },
  }
}
