// 专题分析数据包 — api-contract §13.1 四个 topic 示例锚定
import type { RangeKey, TopicKey, TopicsResp } from '../api/types'

const BY_TOPIC: Record<TopicKey, Omit<TopicsResp, 'topic' | 'range'>> = {
  drg: {
    stats: [
      { label: 'CMI 值', value: '1.08', delta: '+0.04', dir: 'up' },
      { label: '入组率', value: '98.5', unit: '%', delta: '+0.6%', dir: 'up' },
      { label: '费用消耗指数', value: '0.92', delta: '-0.03', dir: 'down' },
      { label: '时间消耗指数', value: '0.95', delta: '-0.02', dir: 'down' },
      { label: 'RW≥2 占比', value: '10.2', unit: '%', delta: '+1.8%', dir: 'up' },
      { label: '低风险组死亡率', value: '0.02', unit: '%', delta: '持平', dir: 'flat' },
    ],
    chart: {
      title: '病组权重（RW）分布',
      sub: '本月出院病例按 RW 分段（仅已入组病例）',
      type: 'bar',
      unit: '例',
      categories: ['<0.5', '0.5-1', '1-2', '2-5', '5-10', '≥10'],
      values: [870, 3350, 3060, 662, 128, 37],
    },
    table: {
      title: '科室 DRG 核心指标',
      sub: '按 CMI 降序排列',
      columns: [
        { key: 'dept', title: '科室' },
        { key: 'cmi', title: 'CMI', align: 'right', num: true },
        { key: 'cases', title: '入组病例', align: 'right', num: true },
        { key: 'cost_idx', title: '费用消耗指数', align: 'right', num: true },
        { key: 'time_idx', title: '时间消耗指数', align: 'right', num: true },
        { key: 'rw2', title: 'RW≥2 占比', align: 'right', num: true },
        { key: 'profit', title: 'DRG 结余（万元）', align: 'right', num: true },
      ],
      rows: [
        { dept: '神经外科', cmi: '1.68', cases: '294', cost_idx: '1.02', time_idx: '1.06', rw2: '46.8%', profit: '-12.8' },
        { dept: '心血管内科', cmi: '1.42', cases: '1,360', cost_idx: '0.96', time_idx: '0.98', rw2: '28.6%', profit: '+86.4' },
        { dept: '骨科', cmi: '1.36', cases: '1,232', cost_idx: '0.88', time_idx: '0.94', rw2: '32.4%', profit: '+124.6' },
        { dept: '肿瘤科', cmi: '1.24', cases: '810', cost_idx: '1.08', time_idx: '1.02', rw2: '26.4%', profit: '-34.6' },
        { dept: '普通外科', cmi: '1.18', cases: '1,005', cost_idx: '0.86', time_idx: '0.92', rw2: '24.2%', profit: '+98.2' },
        { dept: '呼吸与危重症医学科', cmi: '1.12', cases: '1,083', cost_idx: '0.94', time_idx: '0.96', rw2: '22.8%', profit: '+42.8' },
        { dept: '神经内科', cmi: '0.94', cases: '885', cost_idx: '0.90', time_idx: '0.98', rw2: '12.6%', profit: '+38.2' },
        { dept: '儿科', cmi: '0.68', cases: '707', cost_idx: '0.84', time_idx: '0.88', rw2: '4.2%', profit: '+28.4' },
      ],
    },
  },
  insurance: {
    stats: [
      { label: '医保结算人次', value: '8,462', delta: '+4.2%', dir: 'up' },
      { label: '医保基金支付', value: '9,860', unit: '万元', delta: '+3.8%', dir: 'up' },
      { label: '基金结余率', value: '6.8', unit: '%', delta: '+0.4%', dir: 'up' },
      { label: '拒付/扣款率', value: '0.8', unit: '%', delta: '-0.2%', dir: 'down' },
      { label: '次均医保费用', value: '11,652', unit: '元', delta: '+1.6%', dir: 'up' },
      { label: '异地就医结算', value: '486', unit: '人次', delta: '+12.4%', dir: 'up' },
    ],
    chart: {
      title: '医保基金月度支付',
      sub: '近 6 个月（万元）',
      type: 'line',
      unit: '万元',
      months: ['5月', '6月', '7月', '8月', '9月', '10月'],
      values: [8860, 9150, 9620, 9840, 9560, 9860],
    },
    table: {
      title: '分险种结算情况',
      sub: '本月',
      columns: [
        { key: 'type', title: '险种' },
        { key: 'cases', title: '结算人次', align: 'right', num: true },
        { key: 'fund', title: '基金支付（万元）', align: 'right', num: true },
        { key: 'self', title: '个人自付（万元）', align: 'right', num: true },
        { key: 'ratio', title: '报销比例', align: 'right', num: true },
        { key: 'status', title: '运行状态', align: 'center' },
      ],
      rows: [
        { type: '职工医保', cases: '4,286', fund: '5,680', self: '1,420', ratio: '80.0%', status: '平稳' },
        { type: '居民医保', cases: '3,246', fund: '3,420', self: '1,486', ratio: '69.7%', status: '平稳' },
        { type: '生育保险', cases: '486', fund: '420', self: '128', ratio: '76.6%', status: '平稳' },
        { type: '大病保险', cases: '286', fund: '286', self: '86', ratio: '76.9%', status: '关注' },
        { type: '医疗救助', cases: '158', fund: '54', self: '12', ratio: '81.8%', status: '平稳' },
      ],
    },
  },
  exam: {
    stats: [
      { label: '国考预估得分', value: '786', unit: '分', delta: '+18分', dir: 'up' },
      { label: '指标达标率', value: '82.4', unit: '%', delta: '+3.6%', dir: 'up' },
      { label: '医疗质量得分率', value: '86.2', unit: '%', delta: '+2.4%', dir: 'up' },
      { label: '运营效率得分率', value: '78.6', unit: '%', delta: '+4.2%', dir: 'up' },
      { label: '持续发展得分率', value: '74.8', unit: '%', delta: '+1.8%', dir: 'up' },
      { label: '满意度得分率', value: '91.2', unit: '%', delta: '+0.6%', dir: 'up' },
    ],
    chart: {
      title: '近 6 个月指标达标率',
      sub: '已监测指标达标占比',
      type: 'line',
      unit: '%',
      months: ['5月', '6月', '7月', '8月', '9月', '10月'],
      values: [74.2, 76.8, 78.4, 79.6, 81.2, 82.4],
    },
    table: {
      title: '关键国考指标',
      sub: '得分率偏低的重点项',
      columns: [
        { key: 'name', title: '指标名称' },
        { key: 'full', title: '分值', align: 'right', num: true },
        { key: 'score', title: '得分率', align: 'right', num: true },
        { key: 'trend', title: '趋势', align: 'center' },
        { key: 'owner', title: '责任部门' },
      ],
      rows: [
        { name: '出院患者四级手术比例', full: 40, score: '68%', trend: '↑', owner: '医务部' },
        { name: '每床日收入（剔除药耗）', full: 30, score: '72%', trend: '↑', owner: '财务部' },
        { name: '人员支出占业务支出比重', full: 30, score: '64%', trend: '→', owner: '人力资源部' },
        { name: '万元收入能耗支出', full: 20, score: '76%', trend: '↑', owner: '后勤保障部' },
        { name: '医护比', full: 20, score: '82%', trend: '↑', owner: '人力资源部' },
        { name: '住院患者满意度', full: 20, score: '95%', trend: '→', owner: '护理部' },
      ],
    },
  },
  outp_fund: {
    stats: [
      { label: '门诊统筹结算人次', value: '6,248', delta: '+18.6%', dir: 'up' },
      { label: '统筹基金支付', value: '486', unit: '万元', delta: '+22.4%', dir: 'up' },
      { label: '人均统筹费用', value: '778', unit: '元', delta: '+3.2%', dir: 'up' },
      { label: '个人账户支出', value: '326', unit: '万元', delta: '-4.6%', dir: 'down' },
      { label: '慢特病结算', value: '1,846', unit: '人次', delta: '+8.4%', dir: 'up' },
      { label: '处方外流率', value: '12.4', unit: '%', delta: '+2.8%', dir: 'up' },
    ],
    chart: {
      title: '门诊统筹基金月度支出',
      sub: '近 6 个月（万元）',
      type: 'line',
      unit: '万元',
      months: ['5月', '6月', '7月', '8月', '9月', '10月'],
      values: [342, 386, 412, 438, 456, 486],
    },
    table: {
      title: '科室门诊统筹使用',
      sub: '按统筹支付额排序',
      columns: [
        { key: 'dept', title: '科室' },
        { key: 'cases', title: '结算人次', align: 'right', num: true },
        { key: 'fund', title: '统筹支付（万元）', align: 'right', num: true },
        { key: 'avg', title: '人均费用（元）', align: 'right', num: true },
        { key: 'chronic', title: '慢特病占比', align: 'right', num: true },
      ],
      rows: [
        { dept: '内分泌科', cases: '986', fund: '86.4', avg: '88', chronic: '68.4%' },
        { dept: '心血管内科', cases: '912', fund: '92.6', avg: '102', chronic: '62.8%' },
        { dept: '神经内科', cases: '684', fund: '62.8', avg: '92', chronic: '54.2%' },
        { dept: '呼吸与危重症医学科', cases: '596', fund: '58.4', avg: '98', chronic: '42.6%' },
        { dept: '消化内科', cases: '512', fund: '44.2', avg: '86', chronic: '38.4%' },
        { dept: '中医科', cases: '468', fund: '38.6', avg: '82', chronic: '46.8%' },
      ],
    },
  },
}

/** §13.1 GET /workbench/topics */
export function getTopicsMock(topic?: string, range?: string): TopicsResp {
  const t: TopicKey =
    topic === 'insurance' || topic === 'exam' || topic === 'outp_fund' ? topic : 'drg'
  const r: RangeKey = range === '本月' || range === '本季' ? range : '本年'
  return { topic: t, range: r, ...BY_TOPIC[t] }
}
