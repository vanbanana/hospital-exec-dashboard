// 患者服务数据包 — api-contract §9.1 示例锚定
import type { PatientResp } from '../api/types'

/** §9.1 GET /workbench/patient */
export const patientData: PatientResp = {
  stats: [
    { label: '门诊满意度', value: '96.4', unit: '%', delta: '+0.8%', dir: 'up', delta_label: '较上月' },
    { label: '住院满意度', value: '97.2', unit: '%', delta: '+0.4%', dir: 'up', delta_label: '较上月' },
    { label: '本月投诉', value: '24', unit: '件', delta: '-6件', dir: 'down', delta_label: '较上月' },
    { label: '本月表扬', value: '86', unit: '件', delta: '+12件', dir: 'up', delta_label: '较上月' },
    { label: '平均候诊', value: '18', unit: '分钟', delta: '-3分钟', dir: 'down', delta_label: '较上月' },
    { label: '网约挂号率', value: '82.0', unit: '%', delta: '+4.2%', dir: 'up', delta_label: '较上月' },
  ],
  satisfaction_trend: {
    unit: '%',
    months: ['5月', '6月', '7月', '8月', '9月', '10月'],
    outpatient: [94.8, 95.2, 95.6, 95.8, 96.1, 96.4],
    inpatient: [96.0, 96.2, 96.5, 96.8, 97.0, 97.2],
  },
  channel_distribution: {
    unit: '%',
    list: [
      { name: '微信小程序', value: 38 },
      { name: '自助机', value: 24 },
      { name: '人工窗口', value: 18 },
      { name: '官方APP', value: 14 },
      { name: '电话预约', value: 6 },
    ],
  },
  complaints_praises: {
    columns: [
      { key: 'date', title: '日期', align: 'center' },
      { key: 'type', title: '类型', align: 'center' },
      { key: 'dept', title: '涉及科室' },
      { key: 'channel', title: '渠道' },
      { key: 'content', title: '反映内容' },
      { key: 'status', title: '处理状态', align: 'center' },
      { key: 'score', title: '回访评价', align: 'center' },
    ],
    rows: [
      { date: '2026-10-27', type: '表扬', dept: '急诊科', channel: '12345热线', content: '急诊科医护人员深夜救治及时，家属致谢', status: '已办结', score: '非常满意' },
      { date: '2026-10-26', type: '投诉', dept: '门诊部', channel: '现场意见箱', content: '门诊缴费窗口排队时间过长（高峰时段）', status: '处理中', score: '待评价' },
      { date: '2026-10-24', type: '投诉', dept: '护理部', channel: '电话', content: '住院部陪护床管理不规范', status: '已整改', score: '基本满意' },
      { date: '2026-10-23', type: '表扬', dept: '骨科', channel: '小程序', content: '骨科王主任术后随访细致', status: '已归档', score: '非常满意' },
      { date: '2026-10-22', type: '投诉', dept: '放射科', channel: '现场', content: '放射科取报告自助机故障', status: '已办结', score: '满意' },
      { date: '2026-10-20', type: '投诉', dept: '后勤保障部', channel: '电话', content: '停车场出口排队拥堵', status: '待核实', score: '待评价' },
    ],
  },
}
