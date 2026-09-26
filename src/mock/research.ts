// 科研教学数据包 — api-contract §8.1 示例锚定
import type { ResearchResp } from '../api/types'

/** §8.1 GET /workbench/research */
export const researchData: ResearchResp = {
  stats: [
    { label: '在研课题', value: '186', unit: '项', delta: '+12项', dir: 'up' },
    { label: '年度新立项', value: '42', unit: '项', delta: '+6项', dir: 'up' },
    { label: '科研经费', value: '3,480', unit: '万元', delta: '+18.2%', dir: 'up' },
    { label: 'SCI 论文', value: '98', unit: '篇', delta: '+14篇', dir: 'up' },
    { label: '住培学员', value: '312', unit: '人', note: '首次结业率 96.2%' },
    { label: '继教覆盖率', value: '98.4', unit: '%', delta: '+0.8%', dir: 'up' },
  ],
  project_trend: {
    unit: '万元',
    years: ['2021', '2022', '2023', '2024', '2025'],
    national: [4, 6, 8, 9, 12],
    provincial: [12, 16, 20, 24, 30],
    funds: [1200, 1680, 2240, 2940, 3480],
  },
  paper_distribution: {
    unit: '篇',
    categories: ['一区（Top）', '二区', '三区', '四区', '中文核心'],
    values: [14, 28, 36, 20, 68],
  },
  disciplines: {
    columns: [
      { key: 'name', title: '学科名称' },
      { key: 'level', title: '级别', align: 'center' },
      { key: 'leader', title: '学科带头人' },
      { key: 'projects', title: '在研课题', align: 'right', num: true },
      { key: 'funds', title: '科研经费（万元）', align: 'right', num: true },
      { key: 'papers', title: '年度论文', align: 'right', num: true },
      { key: 'transfer', title: '成果转化（万元）', align: 'right', num: true },
    ],
    rows: [
      { name: '心血管病学', level: '国家临床重点', leader: '张伟 教授', projects: 28, funds: '820', papers: 22, transfer: '150' },
      { name: '骨外科学', level: '省级重点专科', leader: '李强 教授', projects: 22, funds: '540', papers: 16, transfer: '80' },
      { name: '呼吸病学', level: '省级重点专科', leader: '王军 教授', projects: 18, funds: '460', papers: 14, transfer: '45' },
    ],
  },
}
