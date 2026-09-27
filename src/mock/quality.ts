// 质量与安全数据包 — api-contract §10.1 示例锚定
import type { QualityResp } from '../api/types'

/** §10.1 GET /workbench/quality */
export const qualityData: QualityResp = {
  stats: [
    { label: '甲级病案率', value: '98.6', unit: '%', delta: '+0.4%', dir: 'up', delta_label: '较上月' },
    { label: '院感发生率', value: '1.24', unit: '%', delta: '-0.18%', dir: 'down', delta_label: '较上月' },
    { label: '危急值处理及时率', value: '99.1', unit: '%', delta: '+0.3%', dir: 'up', delta_label: '较上月' },
    { label: '不良事件上报', value: '36', unit: '起', note: '百床 1.95 起' },
    { label: 'I类切口感染率', value: '0.38', unit: '%', delta: '-0.06%', dir: 'down', delta_label: '较上月' },
    { label: '抗菌药物使用强度', value: '36.2', unit: 'DDDs', delta: '-2.1', dir: 'down', delta_label: '较上月' },
  ],
  infection_trend: {
    unit: '%',
    target: 2.0,
    months: ['5月', '6月', '7月', '8月', '9月', '10月'],
    rates: [2.2, 2.0, 2.1, 1.9, 1.9, 1.8],
  },
  adverse_events: {
    unit: '起',
    categories: ['跌倒/坠床', '用药错误', '管路滑脱', '院内压疮', '手术相关', '输血相关', '其他'],
    values: [11, 8, 6, 5, 3, 2, 1],
  },
  rules_compliance: {
    columns: [
      { key: 'name', title: '制度名称' },
      { key: 'sample', title: '抽检例数', align: 'right', num: true },
      { key: 'pass', title: '合格例数', align: 'right', num: true },
      { key: 'rate', title: '执行合规率', align: 'right', num: true },
      { key: 'issues', title: '主要问题' },
    ],
    rows: [
      { name: '首诊负责制', sample: 280, pass: 270, rate: '96.4%', issues: '个别首诊病历书写延迟' },
      { name: '三级查房制度', sample: 260, pass: 240, rate: '92.3%', issues: '主任查房记录欠详实' },
      { name: '会诊制度', sample: 240, pass: 230, rate: '95.8%', issues: '常规会诊偶有超时' },
      { name: '危急值报告制度', sample: 280, pass: 276, rate: '98.6%', issues: '闭环确认偶有遗漏' },
      { name: '手术安全核查制度', sample: 220, pass: 218, rate: '99.1%', issues: '三方核查签字不全 2 例' },
      { name: '病历书写规范', sample: 300, pass: 266, rate: '88.6%', issues: '24小时出入院记录欠完整' },
      { name: '抗菌药物分级管理', sample: 260, pass: 237, rate: '91.2%', issues: '特殊级抗菌药越权使用 3 例' },
      { name: '值班交接班制度', sample: 280, pass: 264, rate: '94.2%', issues: '床旁交接偶无双人签字' },
    ],
  },
}
