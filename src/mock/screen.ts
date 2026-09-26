// 科技大屏快照数据包 — api-contract §14.1 示例锚定（BASE_DATE=2026-10-28）
import type { ScreenSnapshotResp } from '../api/types'

/** §14.1 GET /screen/snapshot */
export const screenSnapshot: ScreenSnapshotResp = {
  server_time: '2026-10-28T08:30:00+08:00',
  status: {
    level: 'normal',
    text: '运行平稳',
    desc: '医院整体运行正常',
    alert_open: { urgent: 1, major: 2, minor: 2 },
  },
  kpis: [
    { code: 'OP_DAILY_VISITS', name: '今日门急诊', value: 4200, unit: '人', prev_value: 3950, delta_pct: 6.3, direction: 1, spark: [3800, 3950, 4100, 3900, 4050, 3950, 4200], status: 'normal' },
    { code: 'IP_IN_HOSP', name: '在院患者', value: 1846, unit: '人', prev_value: 1820, delta_pct: 1.4, direction: 1, spark: [1780, 1800, 1810, 1825, 1830, 1820, 1846], status: 'normal' },
    { code: 'BED_USE_RATE', name: '床位使用率', value: 92.1, unit: '%', prev_value: 90.8, delta_pct: 1.4, direction: 1, spark: [88.5, 89.2, 90.1, 91.0, 91.5, 90.8, 92.1], status: 'warn' },
    { code: 'SURG_DAILY_CNT', name: '今日手术', value: 45, unit: '台', prev_value: 42, delta_pct: 7.1, direction: 1, spark: [38, 40, 42, 39, 41, 42, 45], status: 'normal' },
  ],
  drg_quadrant: {
    period: 'd30',
    axis: { x: 'DRG盈亏(万元)', y: 'CMI' },
    split: { x: 0, y: 1.0 },
    points: [
      { dept_id: 1, name: '骨科', category: 'surg', cmi: 1.36, profit: 124.6, case_cnt: 1232, quadrant: 2 },
      { dept_id: 2, name: '心血管内科', category: 'med', cmi: 1.42, profit: 86.4, case_cnt: 1360, quadrant: 2 },
      { dept_id: 3, name: '肿瘤科', category: 'med', cmi: 1.24, profit: -34.6, case_cnt: 810, quadrant: 1 },
      { dept_id: 4, name: '神经外科', category: 'surg', cmi: 1.68, profit: -12.8, case_cnt: 294, quadrant: 1 },
      { dept_id: 5, name: '儿科', category: 'med', cmi: 0.68, profit: 28.4, case_cnt: 707, quadrant: 4 },
    ],
  },
  buildings: [
    { code: 'mz', name: '门诊楼', status: 'normal', badge: '4,200 人', badge_level: 'info', anchor: { x: 32, y: 58 }, metrics: { today_visit: 4200, queue_avg_min: 18 } },
    { code: 'wk', name: '外科楼', status: 'busy', badge: '96% 负荷', badge_level: 'warn', anchor: { x: 50, y: 30 }, metrics: { bed_use_rate: 96.0, bed_used: 192, bed_open: 200 } },
    { code: 'jz', name: '急诊楼', status: 'alert', badge: '留观超时', badge_level: 'alert', anchor: { x: 66, y: 42 }, metrics: { obs_over6h: 3, obs_cnt: 11, obs_max_min: 560 } },
    { code: 'yj', name: '医技楼', status: 'normal', badge: '设备正常', badge_level: 'ok', anchor: { x: 60, y: 66 }, metrics: { device_run: 12, device_alert: 0 } },
  ],
  dept_ranking: [
    { rank: 1, dept_id: 1, name: '骨科', category: 'surg', cmi: 1.36, surg_cnt: 280, alos: 8.6, profit: 124.6, eff_score: 94.2 },
    { rank: 2, dept_id: 2, name: '心血管内科', category: 'med', cmi: 1.42, surg_cnt: 240, alos: 9.2, profit: 86.4, eff_score: 92.8 },
  ],
  alerts: {
    total_open: 5,
    list: [
      { id: 51, level: 'urgent', title: '急诊留观超时（>6h）', dept: '急诊科', occurred_at: '2026-10-28T08:12:00+08:00' },
      { id: 52, level: 'major', title: '外科楼重症监护床位达98%', dept: '重症医学科', occurred_at: '2026-10-28T08:20:00+08:00' },
    ],
  },
  trends: {
    days: 7,
    dates: ['10-22', '10-23', '10-24', '10-25', '10-26', '10-27', '10-28'],
    series: {
      OP_DAILY_VISITS: [3800, 3950, 4100, 3900, 4050, 3950, 4200],
      IP_IN_HOSP: [1780, 1800, 1810, 1825, 1830, 1820, 1846],
      SURG_DAILY_CNT: [38, 40, 42, 39, 41, 42, 45],
      BED_USE_RATE: [88.5, 89.2, 90.1, 91.0, 91.5, 90.8, 92.1],
    },
  },
}
