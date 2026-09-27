// 专题分析数据包 — api-contract §13.1 四个 topic 示例锚定（range=本年）
import type { RangeKey, TopicKey, TopicsResp } from '../api/types'

// range 缩放系数 — backend 实测「当月/当季 ÷ 本年」逐族校准（锚月 2026-10）：
// cnt=人次/例数族，money=金额族；比率/指数/得分、近 6 月窗口图、drg 表 cmi/profit 冻结列（§14.1 注10）不缩放
const RANGE_SCALE = {
  本月: { drg: 0.089, ins_cnt: 0.094, ins_money: 0.1, of_cnt: 0.102, of_money: 0.102 },
  本季: { drg: 0.26, ins_cnt: 0.269, ins_money: 0.288, of_cnt: 0.308, of_money: 0.309 },
} as const

const num = (v: string | number) => Number(String(v).replace(/,/g, ''))
const fmt = (n: number) => n.toLocaleString('en-US')
// 保形缩放：整数千分位 / 一位小数两种形态
const scaleInt = (v: string | number, f: number) => fmt(Math.round(num(v) * f))
const scaleDec = (v: string | number, f: number) => (num(v) * f).toFixed(1)

const BY_TOPIC: Record<TopicKey, Omit<TopicsResp, 'topic' | 'range'>> = {
  drg: {
    stats: [
      { label: 'CMI 值', value: '1.09', delta: '持平', dir: 'flat', delta_label: '较上月' },
      { label: '入组率', value: '98.5', unit: '%', delta: '+0.3%', dir: 'up', delta_label: '较上月' },
      { label: '费用消耗指数', value: '0.66', delta: '+0.01', dir: 'up', delta_label: '较上月' },
      { label: '时间消耗指数', value: '0.97', delta: '-0.01', dir: 'down', delta_label: '较上月' },
      { label: 'RW≥2 占比', value: '10.0', unit: '%', delta: '+0.1%', dir: 'up', delta_label: '较上月' },
      { label: '低风险组死亡率', value: '0.03', unit: '%', delta: '持平', dir: 'flat', delta_label: '较上月' },
    ],
    chart: {
      title: '病组权重（RW）分布',
      sub: '本年出院病例按 RW 分段（仅已入组病例）',
      type: 'bar',
      unit: '例',
      categories: ['<0.5', '0.5-1', '1-2', '2-5', '5-10', '≥10'],
      values: [9927, 38841, 31037, 6995, 1413, 418],
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
        { dept: '神经外科', cmi: '1.68', cases: '3,133', cost_idx: '0.65', time_idx: '1.50', rw2: '20.4%', profit: '-12.8' },
        { dept: '心血管内科', cmi: '1.42', cases: '14,447', cost_idx: '0.59', time_idx: '0.96', rw2: '12.5%', profit: '+86.4' },
        { dept: '骨科', cmi: '1.36', cases: '13,059', cost_idx: '0.73', time_idx: '1.13', rw2: '15.1%', profit: '+124.6' },
        { dept: '肿瘤科', cmi: '1.24', cases: '8,611', cost_idx: '0.74', time_idx: '1.19', rw2: '12.3%', profit: '-34.6' },
        { dept: '普通外科', cmi: '1.18', cases: '10,659', cost_idx: '0.74', time_idx: '0.92', rw2: '11.7%', profit: '+98.2' },
        { dept: '呼吸与危重症医学科', cmi: '1.12', cases: '11,491', cost_idx: '0.64', time_idx: '1.07', rw2: '10.6%', profit: '+42.8' },
        { dept: '神经内科', cmi: '0.94', cases: '9,387', cost_idx: '0.64', time_idx: '1.15', rw2: '6.2%', profit: '+38.2' },
        { dept: '儿科', cmi: '0.68', cases: '7,513', cost_idx: '0.40', time_idx: '0.60', rw2: '2.1%', profit: '+28.4' },
      ],
    },
  },
  insurance: {
    stats: [
      { label: '医保结算人次', value: '90,155', delta: '+32.9%', dir: 'up', delta_label: '较上年' },
      { label: '医保基金支付', value: '98,756', unit: '万元', delta: '+46.1%', dir: 'up', delta_label: '较上年' },
      { label: '基金结余率', value: '6.8', unit: '%', delta: '+0.4%', dir: 'up', delta_label: '较上年' },
      { label: '拒付/扣款率', value: '0.8', unit: '%', delta: '持平', dir: 'flat', delta_label: '较上年' },
      { label: '次均医保费用', value: '10,954', unit: '元', delta: '+10.0%', dir: 'up', delta_label: '较上年' },
      { label: '异地就医结算', value: '5,175', unit: '人次', delta: '+33.1%', dir: 'up', delta_label: '较上年' },
    ],
    chart: {
      title: '医保基金月度支付',
      sub: '近 6 个月（万元）',
      type: 'line',
      unit: '万元',
      months: ['5月', '6月', '7月', '8月', '9月', '10月'],
      values: [8295, 8648, 9288, 9028, 8715, 9861],
    },
    table: {
      title: '分险种结算情况',
      sub: '本年',
      columns: [
        { key: 'type', title: '险种' },
        { key: 'cases', title: '结算人次', align: 'right', num: true },
        { key: 'fund', title: '基金支付（万元）', align: 'right', num: true },
        { key: 'self', title: '个人自付（万元）', align: 'right', num: true },
        { key: 'ratio', title: '报销比例', align: 'right', num: true },
        { key: 'status', title: '运行状态', align: 'center' },
      ],
      rows: [
        { type: '职工医保', cases: '45,653', fund: '56,888', self: '14,224', ratio: '80.0%', status: '平稳' },
        { type: '居民医保', cases: '34,580', fund: '34,255', self: '14,886', ratio: '69.7%', status: '平稳' },
        { type: '生育保险', cases: '5,185', fund: '4,207', self: '1,283', ratio: '76.6%', status: '平稳' },
        { type: '大病保险', cases: '3,053', fund: '2,864', self: '863', ratio: '76.8%', status: '关注' },
        { type: '医疗救助', cases: '1,684', fund: '543', self: '119', ratio: '82.0%', status: '平稳' },
      ],
    },
  },
  exam: {
    stats: [
      { label: '国考预估得分', value: '786', unit: '分', delta: '+18分', dir: 'up', delta_label: '较上年' },
      { label: '指标达标率', value: '82.4', unit: '%', delta: '+3.6%', dir: 'up', delta_label: '较上年' },
      { label: '医疗质量得分率', value: '86.2', unit: '%', delta: '+2.4%', dir: 'up', delta_label: '较上年' },
      { label: '运营效率得分率', value: '78.6', unit: '%', delta: '+4.2%', dir: 'up', delta_label: '较上年' },
      { label: '持续发展得分率', value: '74.8', unit: '%', delta: '+1.8%', dir: 'up', delta_label: '较上年' },
      { label: '满意度得分率', value: '91.2', unit: '%', delta: '+0.6%', dir: 'up', delta_label: '较上年' },
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
        { name: '人员支出占业务支出比重', full: 30, score: '64%', trend: '→', owner: '人力资源部' },
        { name: '每床日收入（剔除药耗）', full: 30, score: '72%', trend: '↑', owner: '财务部' },
        { name: '万元收入能耗支出', full: 20, score: '76%', trend: '↑', owner: '后勤保障部' },
        { name: '医护比', full: 20, score: '82%', trend: '↑', owner: '人力资源部' },
        { name: '住院患者满意度', full: 20, score: '95%', trend: '→', owner: '护理部' },
      ],
    },
  },
  outp_fund: {
    stats: [
      { label: '门诊统筹结算人次', value: '61,644', delta: '+22.0%', dir: 'up', delta_label: '较上年' },
      { label: '统筹基金支付', value: '4,783', unit: '万元', delta: '+22.6%', dir: 'up', delta_label: '较上年' },
      { label: '人均统筹费用', value: '776', unit: '元', delta: '+0.5%', dir: 'up', delta_label: '较上年' },
      { label: '个人账户支出', value: '3,210', unit: '万元', delta: '+22.5%', dir: 'up', delta_label: '较上年' },
      { label: '慢特病结算', value: '18,080', unit: '人次', delta: '+27.6%', dir: 'up', delta_label: '较上年' },
      { label: '处方外流率', value: '12.4', unit: '%', delta: '+2.8%', dir: 'up', delta_label: '较上年' },
    ],
    chart: {
      title: '门诊统筹基金月度支出',
      sub: '近 6 个月（万元）',
      type: 'line',
      unit: '万元',
      months: ['5月', '6月', '7月', '8月', '9月', '10月'],
      values: [342, 387, 412, 438, 456, 488],
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
        { dept: '内分泌科', cases: '10,304', fund: '804.1', avg: '780', chronic: '49.9%' },
        { dept: '心血管内科', cases: '9,579', fund: '745.7', avg: '778', chronic: '45.7%' },
        { dept: '神经内科', cases: '7,157', fund: '556.8', avg: '778', chronic: '37.0%' },
        { dept: '呼吸与危重症医学科', cases: '6,236', fund: '486.4', avg: '780', chronic: '28.1%' },
        { dept: '消化内科', cases: '5,354', fund: '417.9', avg: '780', chronic: '22.9%' },
        { dept: '中医科', cases: '4,893', fund: '381.4', avg: '780', chronic: '32.6%' },
      ],
    },
  },
}

/**
 * §13.1 GET /workbench/topics — range 语义实算：
 * 累计量字段（结算人次/基金支付/入组病例/RW 分段例数）以契约示例（range=本年）为锚，
 * 按 RANGE_SCALE 校准系数缩放；drg 表 cmi/profit 为 §14.1 注10 冻结列不缩放；
 * 比率/指数/得分字段、近 6 个月窗口图不随 range 变；exam 全为比率得分恒等返回。
 */
export function getTopicsMock(topic?: string, range?: string): TopicsResp {
  const t: TopicKey =
    topic === 'insurance' || topic === 'exam' || topic === 'outp_fund' ? topic : 'drg'
  const r: RangeKey = range === '本月' || range === '本季' ? range : '本年'
  const base = BY_TOPIC[t]
  if (r === '本年' || t === 'exam') return { topic: t, range: r, ...base }

  const f = RANGE_SCALE[r]
  if (t === 'drg') {
    return {
      topic: t,
      range: r,
      stats: base.stats,
      // sub 随 range 实写：值缩放后仍写"本年"会撒谎
      chart: {
        ...base.chart,
        sub: `${r}出院病例按 RW 分段（仅已入组病例）`,
        values: base.chart.values.map((v) => Math.round(v * f.drg)),
      },
      table: {
        ...base.table,
        rows: base.table.rows.map((row) => ({ ...row, cases: scaleInt(row.cases, f.drg) })),
      },
    }
  }
  if (t === 'insurance') {
    return {
      topic: t,
      range: r,
      stats: base.stats.map((s) =>
        s.label === '医保基金支付'
          ? { ...s, value: scaleInt(s.value, f.ins_money) }
          : s.label === '医保结算人次' || s.label === '异地就医结算'
            ? { ...s, value: scaleInt(s.value, f.ins_cnt) }
            : s,
      ),
      chart: base.chart,
      table: {
        ...base.table,
        sub: r,
        rows: base.table.rows.map((row) => ({
          ...row,
          cases: scaleInt(row.cases, f.ins_cnt),
          fund: scaleInt(row.fund, f.ins_money),
          self: scaleInt(row.self, f.ins_money),
        })),
      },
    }
  }
  return {
    topic: t,
    range: r,
    stats: base.stats.map((s) =>
      s.label === '门诊统筹结算人次' || s.label === '慢特病结算'
        ? { ...s, value: scaleInt(s.value, f.of_cnt) }
        : s.label === '统筹基金支付' || s.label === '个人账户支出'
          ? { ...s, value: scaleInt(s.value, f.of_money) }
          : s,
    ),
    chart: base.chart,
    table: {
      ...base.table,
      rows: base.table.rows.map((row) => ({
        ...row,
        cases: scaleInt(row.cases, f.of_cnt),
        fund: scaleDec(row.fund, f.of_money),
      })),
    },
  }
}
