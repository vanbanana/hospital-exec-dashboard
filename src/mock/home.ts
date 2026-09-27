// 首页数据包 — api-contract §3.1~§3.7 示例锚定
import type {
  HomeAlertsResp,
  HomeIndicatorsResp,
  HomeKpisResp,
  HomeNoticesResp,
  HomeProgressResp,
  HomeTop10Resp,
  HomeTrendsResp,
} from '../api/types'

/** §3.1 GET /workbench/home/kpis */
export const homeKpis: HomeKpisResp = {
  period: '本月',
  list: [
    { key: 'outpatient', label: '门急诊人次', value: '123,000', unit: '', delta: '+3.6%', dir: 'up', delta_label: '较上月', icon: 'Stethoscope', tone: 'primary' },
    { key: 'inpatient', label: '住院人次', value: '8,120', unit: '', delta: '+5.1%', dir: 'up', delta_label: '较上月', icon: 'BedDouble', tone: 'primary' },
    { key: 'surgery', label: '手术台次', value: '1,286', unit: '', delta: '+4.8%', dir: 'up', delta_label: '较上月', icon: 'Scissors', tone: 'teal' },
    { key: 'revenue', label: '医疗总收入', value: '14,800', unit: '万元', delta: '+2.9%', dir: 'up', delta_label: '较上月', icon: 'Banknote', tone: 'green' },
    { key: 'staff', label: '在岗职工', value: '2,368', unit: '', delta: '+0.4%', dir: 'up', delta_label: '较上月', icon: 'Users', tone: 'navy' },
  ],
}

/** §3.2 GET /workbench/home/trends */
export const homeTrends: HomeTrendsResp = {
  months: ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'],
  series: {
    门急诊人次: {
      unit: '人次',
      current: [54000, 46000, 68000, 70000, 85000, 90000, 108000, 97000, 105000, 123000, 122000, 120000],
      last: [46000, 39000, 52000, 52000, 68000, 72000, 90000, 92000, 87000, 102000, 101000, 99000],
    },
    住院人次: {
      unit: '人次',
      current: [5900, 4970, 6410, 6820, 7240, 7450, 8070, 8480, 7850, 8120, 7650, 7450],
      last: [5380, 4340, 5800, 6000, 6410, 6620, 7030, 7240, 6820, 7030, 6620, 6410],
    },
    手术台次: {
      unit: '台',
      current: [860, 720, 980, 1020, 1080, 1120, 1180, 1210, 1150, 1286, 1200, 1160],
      last: [750, 650, 850, 900, 950, 980, 1020, 1050, 1000, 1100, 1050, 1000],
    },
    医疗收入: {
      unit: '万元',
      current: [8950, 8060, 10800, 11650, 12450, 12980, 13940, 13550, 13080, 14800, 14240, 13720],
      last: [7870, 6920, 9120, 9750, 10580, 11030, 11960, 11640, 11200, 12640, 12280, 11840],
    },
  },
}

/** §3.3 GET /workbench/home/top10 */
export const homeTop10: HomeTop10Resp = {
  metric_name: '住院人次',
  max_val: 1300,
  list: [
    { rank: 1, name: '心血管内科', value: 1250 },
    { rank: 2, name: '骨科', value: 1120 },
    { rank: 3, name: '呼吸与危重症医学科', value: 990 },
    { rank: 4, name: '普通外科', value: 920 },
    { rank: 5, name: '神经内科', value: 800 },
    { rank: 6, name: '肿瘤科', value: 735 },
    { rank: 7, name: '妇产科', value: 715 },
    { rank: 8, name: '儿科', value: 655 },
    { rank: 9, name: '消化内科', value: 380 },
    { rank: 10, name: '泌尿外科', value: 340 },
  ],
}

/** §3.4 GET /workbench/home/indicators */
export const homeIndicators: HomeIndicatorsResp = {
  list: [
    { code: 'ALOS', name: '平均住院日', value: '6.8', unit: '天', delta: '-0.3', dir: 'down', delta_label: '较上月', icon: 'CalendarDays', tone: 'primary' },
    { code: 'BED_USE_RATE', name: '床位使用率', value: '92.1', unit: '%', delta: '+1.2', dir: 'up', delta_label: '较上月', icon: 'BedDouble', tone: 'primary' },
    { code: 'DRUG_RATIO', name: '药占比', value: '28.4', unit: '%', delta: '-0.6', dir: 'down', delta_label: '较上月', icon: 'Pill', tone: 'primary' },
    { code: 'MATERIAL_RATIO', name: '耗材占比', value: '17.9', unit: '%', delta: '-0.4', dir: 'down', delta_label: '较上月', icon: 'Package', tone: 'teal' },
    { code: 'MED_SVC_RATIO', name: '医疗服务收入占比', value: '43.6', unit: '%', delta: '+0.8', dir: 'up', delta_label: '较上月', icon: 'HeartPulse', tone: 'green' },
  ],
}

/** §3.5 GET /workbench/home/progress */
export const homeProgress: HomeProgressResp = {
  list: [
    { id: 1, name: '三甲复评准备', progress: 75, status: '进行中' },
    { id: 2, name: 'DRG精细化管理', progress: 60, status: '进行中' },
    { id: 3, name: '智慧医院建设', progress: 40, status: '进行中' },
    { id: 4, name: '学科建设提升计划', progress: 90, status: '进行中' },
    { id: 5, name: 'DIP支付方式改革', progress: 30, status: '待启动' },
  ],
}

/** §3.6 GET /workbench/home/alerts */
export const homeAlerts: HomeAlertsResp = {
  list: [
    { id: 201, level: 'urgent', title: '住院费用增幅高于行业均值', occurred_at: '2026-10-28', rule_code: 'INPT_FEE_SURGE', alert_status: 'pending' },
    { id: 202, level: 'urgent', title: '部分科室床位使用率持续 > 95%', occurred_at: '2026-10-27', rule_code: 'BED_OVER_95', alert_status: 'processing' },
    { id: 203, level: 'major', title: '医疗耗材库存周转天数上升', occurred_at: '2026-10-26', rule_code: 'STOCK_TURN_SLOW', alert_status: 'pending' },
    { id: 204, level: 'major', title: '药品费用占比接近警戒阈值', occurred_at: '2026-10-25', rule_code: 'DRUG_RATIO_WARN', alert_status: 'pending' },
    { id: 205, level: 'minor', title: '个别设备维保到期', occurred_at: '2026-10-24', rule_code: 'DEVICE_MAINTAIN', alert_status: 'pending' },
  ],
}

/** §3.7 GET /workbench/home/notices */
export const homeNotices: HomeNoticesResp = {
  list: [
    { id: 201, text: '关于加强医疗质量安全管理的通知', date: '2026-10-28', urgent: true },
    { id: 202, text: '院务会会议材料（10月）', date: '2026-10-27', urgent: true },
    { id: 203, text: '请审阅2027年预算编制方案', date: '2026-10-26', urgent: true },
    { id: 204, text: '智慧医院二期建设进展汇报', date: '2026-10-25', urgent: false },
    { id: 205, text: '上级主管部门调研安排', date: '2026-10-24', urgent: false },
  ],
}
