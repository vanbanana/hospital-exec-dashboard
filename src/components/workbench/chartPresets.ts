import * as echarts from 'echarts'

/** 工作台图表统一色板：蓝主色 + 克制的同族辅助色 */
export const wbPalette = {
  primary: '#2563eb',
  primaryLight: '#93c5fd',
  cyan: '#0ea5e9',
  teal: '#0d9488',
  green: '#10b981',
  amber: '#f59e0b',
  red: '#ef4444',
  gray: '#94a3b8',
  indigo: '#6366f1',
}

export const wbDonutColors = [
  wbPalette.primary,
  wbPalette.cyan,
  wbPalette.teal,
  wbPalette.amber,
  wbPalette.indigo,
  wbPalette.gray,
]

const axisLabel = {
  color: '#64748b',
  fontSize: 11,
}

export const wbCategoryAxis = (data: string[], extra: Record<string, unknown> = {}) => ({
  type: 'category' as const,
  data,
  axisLine: { lineStyle: { color: '#d7e0ee' } },
  axisTick: { show: false },
  axisLabel: { ...axisLabel, margin: 10 },
  ...extra,
})

export const wbValueAxis = (extra: Record<string, unknown> = {}) => ({
  type: 'value' as const,
  axisLine: { show: false },
  axisTick: { show: false },
  axisLabel,
  splitLine: { lineStyle: { color: '#eef3f9' } },
  ...extra,
})

export const wbTooltip = (trigger: 'axis' | 'item' = 'axis') => ({
  trigger,
  backgroundColor: 'rgba(255, 255, 255, 0.96)',
  borderColor: '#e2e8f0',
  borderWidth: 1,
  textStyle: { color: '#1e293b', fontSize: 12 },
  axisPointer: { lineStyle: { color: '#cbd5e1' } },
})

export const wbGrid = (extra: Record<string, unknown> = {}) => ({
  left: 8,
  right: 14,
  top: 30,
  bottom: 4,
  containLabel: true,
  ...extra,
})

export const wbAreaGradient = (color: string) =>
  new echarts.graphic.LinearGradient(0, 0, 0, 1, [
    { offset: 0, color: `${color}26` },
    { offset: 1, color: `${color}05` },
  ])
