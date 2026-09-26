// 资产与后勤数据包 — api-contract §11.1 示例锚定
import type { AssetsResp } from '../api/types'

/** §11.1 GET /workbench/assets */
export const assetsData: AssetsResp = {
  stats: [
    { label: '固定资产总额', value: '12.6', unit: '亿元', delta: '+3.2%', dir: 'up' },
    { label: '大型设备', value: '68', unit: '台', note: '单价 ≥100 万' },
    { label: '设备开机率', value: '94.2', unit: '%', delta: '+1.2%', dir: 'up' },
    { label: '库存周转天数', value: '28', unit: '天', delta: '+3天', dir: 'up' },
    { label: '本月能耗费用', value: '186', unit: '万元', delta: '-2.4%', dir: 'down' },
    { label: '后勤工单', value: '156', unit: '单', note: '完结率 92%' },
  ],
  energy_trend: {
    unit: '万元',
    months: ['5月', '6月', '7月', '8月', '9月', '10月'],
    total: [182, 196, 214, 210, 192, 186],
    electricity: [112, 126, 142, 138, 120, 114],
    water: [38, 42, 46, 44, 40, 38],
    gas: [32, 28, 26, 28, 32, 34],
  },
  stock_alerts: [
    { name: '一次性使用输液器', days: 46, level: 'urgent' },
    { name: '骨科植入物（接骨板）', days: 42, level: 'urgent' },
    { name: '造影剂（碘海醇）', days: 36, level: 'major' },
    { name: '医用缝合线', days: 34, level: 'major' },
    { name: '中心静脉导管', days: 31, level: 'major' },
    { name: '无菌手术衣', days: 29, level: 'major' },
  ],
  large_equipments: {
    columns: [
      { key: 'name', title: '设备名称' },
      { key: 'dept', title: '所属科室' },
      { key: 'count', title: '台数', align: 'right', num: true },
      { key: 'open_rate', title: '开机率', align: 'right' },
      { key: 'monthly', title: '月均检查/治疗人次', align: 'right', num: true },
      { key: 'income', title: '月创收（万元）', align: 'right', num: true },
      { key: 'roi', title: '效益评价', align: 'center' },
    ],
    rows: [
      { name: '3.0T 核磁共振', dept: '放射科', count: 2, open_rate: 96.8, monthly: '2,860', income: '486', roi: '良好' },
      { name: '256 排 CT', dept: '放射科', count: 2, open_rate: 94.6, monthly: '4,120', income: '412', roi: '良好' },
      { name: 'DSA 血管造影机', dept: '介入中心', count: 1, open_rate: 88.4, monthly: '380', income: '296', roi: '良好' },
      { name: '直线加速器', dept: '放疗科', count: 1, open_rate: 91.2, monthly: '420', income: '268', roi: '良好' },
      { name: 'PET-CT', dept: '核医学科', count: 1, open_rate: 72.6, monthly: '186', income: '158', roi: '偏低' },
      { name: '高清电子胃肠镜', dept: '内镜中心', count: 6, open_rate: 89.8, monthly: '1,640', income: '226', roi: '一般' },
      { name: '体外冲击波碎石机', dept: '泌尿外科', count: 1, open_rate: 64.2, monthly: '92', income: '46', roi: '偏低' },
    ],
  },
}
