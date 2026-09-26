// 医疗业务数据包 — api-contract §5.1 三个 tab 示例锚定
import type { MedicalResp, MedicalTab, RangeKey } from '../api/types'

const MONTHS = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月']

const OUTPATIENT: Omit<MedicalResp, 'tab' | 'range'> = {
  stats: [
    { label: '门急诊总人次', value: '123,000', delta: '+3.6%', dir: 'up' },
    { label: '普通门诊', value: '81,900', delta: '+2.1%', dir: 'up' },
    { label: '专家门诊', value: '29,800', delta: '+6.4%', dir: 'up' },
    { label: '急诊人次', value: '11,300', delta: '+4.2%', dir: 'up' },
    { label: '次均费用', value: '300', unit: '元', delta: '+1.8%', dir: 'up' },
    { label: '平均候诊', value: '18', unit: '分钟', delta: '-3分钟', dir: 'down' },
  ],
  trend: {
    title: '门急诊人次趋势',
    name: '门急诊人次',
    unit: '人次',
    months: MONTHS,
    values: [54000, 46000, 68000, 70000, 85000, 90000, 108000, 97000, 105000, 123000, 122000, 120000],
  },
  distribution: {
    title: '就诊高峰时段分布',
    sub: '近 30 日分时段人次',
    type: 'bar',
    unit: '人次',
    categories: ['7时', '8时', '9时', '10时', '11时', '14时', '15时', '16时', '17时', '19时'],
    values: [6200, 14800, 19600, 17500, 11800, 13800, 12400, 9600, 5400, 3800],
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
      { dept: '心血管内科', cnt: '12,860', yoy: '+6.2%', share: '10.3%', avg: '352元', drug: '26.1%' },
      { dept: '呼吸与危重症医学科', cnt: '11,580', yoy: '+8.7%', share: '9.3%', avg: '318元', drug: '31.2%' },
      { dept: '消化内科', cnt: '10,420', yoy: '+4.1%', share: '8.4%', avg: '296元', drug: '33.5%' },
      { dept: '神经内科', cnt: '9,680', yoy: '+3.5%', share: '7.8%', avg: '342元', drug: '29.8%' },
      { dept: '内分泌科', cnt: '8,260', yoy: '+2.9%', share: '6.6%', avg: '274元', drug: '35.4%' },
      { dept: '儿科', cnt: '7,920', yoy: '-1.2%', share: '6.3%', avg: '198元', drug: '22.6%' },
      { dept: '骨科', cnt: '7,160', yoy: '+5.4%', share: '5.7%', avg: '412元', drug: '18.9%' },
      { dept: '皮肤科', cnt: '6,540', yoy: '+2.2%', share: '5.2%', avg: '186元', drug: '41.3%' },
    ],
  },
}

const INPATIENT: Omit<MedicalResp, 'tab' | 'range'> = {
  stats: [
    { label: '在院人数', value: '1,846', note: '当前实时' },
    { label: '本月出院', value: '8,120', delta: '+5.1%', dir: 'up' },
    { label: '床位使用率', value: '92.1', unit: '%', delta: '+1.2%', dir: 'up' },
    { label: '平均住院日', value: '6.8', unit: '天', delta: '-0.3', dir: 'down' },
    { label: '床位周转次数', value: '4.0', delta: '+0.2', dir: 'up' },
    { label: '次均住院费用', value: '13,000', unit: '元', delta: '+2.4%', dir: 'up' },
  ],
  trend: {
    title: '出院人数趋势',
    name: '出院人数',
    unit: '人次',
    months: MONTHS,
    values: [5900, 4970, 6410, 6820, 7240, 7450, 8070, 8480, 7850, 8120, 7650, 7450],
  },
  distribution: {
    title: '病区床位占用',
    sub: '各病区开放床位占用率',
    type: 'bar',
    unit: '%',
    categories: ['内科', '外科', '妇产', '儿科', 'ICU', '肿瘤', '康复'],
    values: [94, 96, 82, 78, 98, 91, 68],
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
      { dept: '心血管内科', cnt: '1,405', yoy: '+4.6%', share: '17.3%', avg: '12,400元', drug: '24.8%' },
      { dept: '骨科', cnt: '1,266', yoy: '+6.1%', share: '15.6%', avg: '15,860元', drug: '12.4%' },
      { dept: '呼吸与危重症医学科', cnt: '1,112', yoy: '+7.2%', share: '13.7%', avg: '11,280元', drug: '32.6%' },
      { dept: '普通外科', cnt: '1,032', yoy: '+3.8%', share: '12.7%', avg: '14,520元', drug: '18.2%' },
      { dept: '神经内科', cnt: '901', yoy: '+2.4%', share: '11.1%', avg: '9,680元', drug: '36.4%' },
      { dept: '肿瘤科', cnt: '829', yoy: '+5.9%', share: '10.2%', avg: '16,240元', drug: '42.8%' },
      { dept: '妇产科', cnt: '804', yoy: '-2.6%', share: '9.9%', avg: '7,460元', drug: '15.6%' },
      { dept: '儿科', cnt: '736', yoy: '+1.8%', share: '9.1%', avg: '4,280元', drug: '26.4%' },
    ],
  },
}

const SURGERY: Omit<MedicalResp, 'tab' | 'range'> = {
  stats: [
    { label: '本月手术台次', value: '1,286', delta: '+4.8%', dir: 'up' },
    { label: '三四级手术占比', value: '58.6', unit: '%', delta: '+2.2%', dir: 'up' },
    { label: '微创手术占比', value: '42.3', unit: '%', delta: '+3.1%', dir: 'up' },
    { label: '择期手术', value: '1,048', delta: '+5.2%', dir: 'up' },
    { label: '急诊手术', value: '238', delta: '+3.1%', dir: 'up' },
    { label: '手术间利用率', value: '86.4', unit: '%', delta: '+1.6%', dir: 'up' },
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
    values: [22, 37, 28, 13],
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
      { dept: '骨科', cnt: '286', yoy: '+6.8%', share: '22.2%', avg: '42分钟', drug: '8.6%' },
      { dept: '普通外科', cnt: '242', yoy: '+5.4%', share: '18.8%', avg: '56分钟', drug: '11.2%' },
      { dept: '妇产科', cnt: '186', yoy: '-1.8%', share: '14.5%', avg: '38分钟', drug: '9.4%' },
      { dept: '神经外科', cnt: '128', yoy: '+7.6%', share: '10.0%', avg: '128分钟', drug: '12.8%' },
      { dept: '泌尿外科', cnt: '116', yoy: '+4.2%', share: '9.0%', avg: '52分钟', drug: '10.6%' },
      { dept: '心胸外科', cnt: '98', yoy: '+9.1%', share: '7.6%', avg: '145分钟', drug: '14.2%' },
      { dept: '耳鼻喉科', cnt: '86', yoy: '+2.4%', share: '6.7%', avg: '34分钟', drug: '7.8%' },
      { dept: '眼科', cnt: '74', yoy: '+1.6%', share: '5.8%', avg: '22分钟', drug: '6.2%' },
    ],
  },
}

const BY_TAB: Record<MedicalTab, Omit<MedicalResp, 'tab' | 'range'>> = {
  门急诊: OUTPATIENT,
  住院: INPATIENT,
  手术: SURGERY,
}

/** §5.1 GET /workbench/medical；trend/distribution/table 契约仅锚定本年示例，mock 期各 range 共用 */
export function getMedicalMock(tab?: string, range?: string): MedicalResp {
  const t: MedicalTab = tab === '住院' || tab === '手术' ? tab : '门急诊'
  const r: RangeKey = range === '本月' || range === '本季' ? range : '本年'
  return { tab: t, range: r, ...BY_TAB[t] }
}
