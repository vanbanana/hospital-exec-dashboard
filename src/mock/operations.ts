// 运营管理数据包 — api-contract §6.1 示例锚定
import type { OperationsResp } from '../api/types'

/** §6.1 GET /workbench/operations；契约仅锚定单份示例，mock 期各 range 共用 */
export function getOperationsMock(_range?: string): OperationsResp {
  return {
    stats: [
      { label: '医疗总收入', value: '120,260', unit: '万元', delta: '+2.9%', dir: 'up' },
      { label: '门诊收入', value: '30,065', unit: '万元', delta: '+1.8%', dir: 'up' },
      { label: '住院收入', value: '85,385', unit: '万元', delta: '+3.6%', dir: 'up' },
      { label: '收支结余率', value: '4.2', unit: '%', delta: '+0.4%', dir: 'up' },
      { label: '次均门诊费用', value: '300', unit: '元', delta: '+1.8%', dir: 'up' },
      { label: '次均住院费用', value: '13,000', unit: '元', delta: '+2.4%', dir: 'up' },
    ],
    revenue_trend: {
      months: ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'],
      income: [8950, 8060, 10800, 11650, 12450, 12980, 13940, 13550, 13080, 14800, 14240, 13720],
      cost: [8574, 7721, 10346, 11161, 11927, 12435, 13359, 12981, 12531, 14178, 13642, 13144],
      balance: [376, 339, 454, 489, 523, 545, 581, 569, 549, 622, 598, 576],
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
      rows: [
        { dept: '心血管内科', income: '19,270', cost: '17,940', balance: '1,330', margin: '6.9%', drug_ratio: '24.8%', mat_ratio: '18.2%' },
        { dept: '骨科', income: '15,960', cost: '14,490', balance: '1,470', margin: '9.2%', drug_ratio: '12.4%', mat_ratio: '34.6%' },
        { dept: '呼吸与危重症医学科', income: '15,070', cost: '14,500', balance: '570', margin: '3.8%', drug_ratio: '32.6%', mat_ratio: '8.4%' },
        { dept: '神经内科', income: '13,270', cost: '12,900', balance: '370', margin: '2.8%', drug_ratio: '36.4%', mat_ratio: '6.2%' },
        { dept: '普通外科', income: '12,620', cost: '11,750', balance: '870', margin: '6.9%', drug_ratio: '18.2%', mat_ratio: '22.1%' },
        { dept: '肿瘤科', income: '11,680', cost: '11,190', balance: '490', margin: '4.2%', drug_ratio: '42.8%', mat_ratio: '9.1%' },
      ],
    },
  }
}
