// 人力资源数据包 — api-contract §7.1 示例锚定
import type { HrResp } from '../api/types'

/** §7.1 GET /workbench/hr；契约仅锚定单份示例，mock 期各 range 共用 */
export function getHrMock(_range?: string): HrResp {
  return {
    stats: [
      { label: '在岗职工', value: '2,368', delta: '+0.4%', dir: 'up' },
      { label: '执业医师', value: '812', delta: '+1.8%', dir: 'up' },
      { label: '注册护士', value: '1,046', delta: '+2.2%', dir: 'up' },
      { label: '医护比', value: '1 : 1.29', note: '目标 ≥1:1.25' },
      { label: '高级职称占比', value: '12.0', unit: '%', delta: '+0.6%', dir: 'up' },
      { label: '人员经费占比', value: '32.5', unit: '%', delta: '+1.1%', dir: 'up' },
    ],
    structure: {
      unit: '%',
      list: [
        { name: '护理人员', value: 44, count: 1046 },
        { name: '执业医师', value: 34, count: 812 },
        { name: '行政后勤', value: 13, count: 308 },
        { name: '医技人员', value: 9, count: 202 },
      ],
    },
    titles: {
      unit: '人',
      categories: ['医师', '护理', '医技', '行政后勤'],
      series: [
        { name: '正高', values: [42, 6, 4, 0] },
        { name: '副高', values: [128, 68, 22, 14] },
        { name: '中级', values: [312, 368, 84, 62] },
        { name: '初级及以下', values: [330, 604, 92, 232] },
      ],
    },
    dept_staffing: {
      columns: [
        { key: 'dept', title: '科室' },
        { key: 'quota', title: '编制数', align: 'right', num: true },
        { key: 'actual', title: '在岗数', align: 'right', num: true },
        { key: 'doctor', title: '医师', align: 'right', num: true },
        { key: 'nurse', title: '护士', align: 'right', num: true },
        { key: 'ratio', title: '医护比', align: 'center' },
        { key: 'gap', title: '缺口', align: 'right', num: true },
        { key: 'status', title: '配置状态', align: 'center' },
      ],
      rows: [
        { dept: '重症医学科', quota: 68, actual: 58, doctor: 16, nurse: 42, ratio: '1:2.63', gap: 10, status: '紧缺' },
        { dept: '急诊科', quota: 86, actual: 78, doctor: 24, nurse: 54, ratio: '1:2.25', gap: 8, status: '紧张' },
        { dept: '儿科', quota: 64, actual: 58, doctor: 20, nurse: 38, ratio: '1:1.90', gap: 6, status: '紧张' },
        { dept: '心血管内科', quota: 92, actual: 89, doctor: 32, nurse: 57, ratio: '1:1.78', gap: 3, status: '充足' },
        { dept: '骨科', quota: 84, actual: 81, doctor: 28, nurse: 53, ratio: '1:1.89', gap: 3, status: '充足' },
        { dept: '呼吸与危重症医学科', quota: 76, actual: 72, doctor: 24, nurse: 48, ratio: '1:2.00', gap: 4, status: '充足' },
        { dept: '麻醉科', quota: 42, actual: 36, doctor: 30, nurse: 6, ratio: '—', gap: 6, status: '紧张' },
        { dept: '康复医学科', quota: 38, actual: 34, doctor: 10, nurse: 24, ratio: '1:2.40', gap: 4, status: '充足' },
      ],
    },
  }
}
