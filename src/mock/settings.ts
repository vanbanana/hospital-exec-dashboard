// 系统设置数据包 — api-contract §13.2 示例锚定
import type { SettingsResp } from '../api/types'

/** §13.2 GET /workbench/settings/config */
export const settingsData: SettingsResp = {
  data_sources: [
    { name: 'HIS 门诊收费系统', type: '业务库 · 准实时', status: '已连接', sync: '2026-10-28 09:42' },
    { name: 'HIS 住院管理系统', type: '业务库 · 准实时', status: '已连接', sync: '2026-10-28 09:42' },
    { name: 'EMR 电子病历', type: '业务库 · 小时级', status: '已连接', sync: '2026-10-28 09:00' },
    { name: 'LIS 检验系统', type: '业务库 · 小时级', status: '已连接', sync: '2026-10-28 09:05' },
    { name: 'HRP 人财物系统', type: '业务库 · 日终批', status: '已连接', sync: '2026-10-28 06:30' },
    { name: '医保结算接口', type: '局端接口 · 日终批', status: '异常', sync: '2026-10-27 23:58' },
  ],
  thresholds: [
    { code: 'BED_OVER_95', name: '床位使用率', rule: '连续 3 日 > 95%', level: 'urgent', enabled: true },
    { code: 'DRUG_RATIO_WARN', name: '药占比', rule: '> 30%', level: 'major', enabled: true },
    { code: 'MAT_OVER_20', name: '耗占比', rule: '> 20%', level: 'major', enabled: true },
    { code: 'INPT_FEE_SURGE', name: '住院费用增幅', rule: '同比 > 8%', level: 'urgent', enabled: true },
    { code: 'STOCK_TURN_SLOW', name: '库存周转天数', rule: '> 35 天', level: 'minor', enabled: true },
    { code: 'CRIT_TIMEOUT_95', name: '危急值超时率', rule: '及时率 < 95%', level: 'urgent', enabled: true },
    { code: 'EQUIP_RUN_LOW', name: '设备开机率', rule: '< 60%', level: 'minor', enabled: false },
  ],
  users: [
    { name: 'system_admin', role: '管理员', scope: '全部', login: '2026-10-28 09:12', status: '启用' },
    { name: '院长', role: '院领导', scope: '全院', login: '2026-10-28 08:46', status: '启用' },
    { name: '分管副院长·医疗', role: '院领导', scope: '全院', login: '2026-10-27 17:32', status: '启用' },
    { name: '医务部主任', role: '部门负责人', scope: '医疗业务', login: '2026-10-28 08:58', status: '启用' },
    { name: '财务部主任', role: '部门负责人', scope: '运营财务', login: '2026-10-28 09:05', status: '启用' },
    { name: '骨科主任', role: '科室主任', scope: '骨科', login: '2026-10-28 08:30', status: '启用' },
  ],
  preferences: {
    default_range: '本月',
    refresh_interval: '5 分钟',
    alert_sound: true,
    unit_abbreviation: true,
    privacy_mask: true,
  },
}
