import * as echarts from 'echarts'

/**
 * 工作台 ECharts 取色唯一出口 —— design-tokens.md §6 R5
 * canvas 不解析 var()，以下为 src/styles/tokens.css 同源常量镜像；
 * 取值只允许落在文档登记的 --wb-chart-* / --p-*，调整先改 design-tokens.md
 */
export const wbChart = {
  /* --wb-chart-* 语义层(design-tokens §4) */
  text: '#64748b', // --wb-chart-text (--p-slate-500)
  axis: '#94a3b8', // --wb-chart-axis (--p-slate-400)
  grid: '#eef3f9', // --wb-chart-grid
  axisLine: '#d7e0ee', // --wb-chart-axis-line
  green: '#10b981', // --wb-chart-green (--p-green-500)
  amber: '#f59e0b', // --wb-chart-amber (--p-amber-500)
  blue1: '#1d4ed8', // --wb-chart-blue-1 (--p-blue-700)
  blue2: '#2563eb', // --wb-chart-blue-2 (--p-blue-600)
  blue3: '#3b82f6', // --wb-chart-blue-3 (--p-blue-500)
  blue4: '#93c5fd', // --wb-chart-blue-4 (--p-blue-300)
  /* --p-* 原色(无语义层挂点,画布直用) */
  white: '#ffffff', // --p-white
  slate50: '#f8fafd', // --p-slate-50
  slate200: '#e2e8f0', // --p-slate-200
  slate300: '#cbd5e1', // --p-slate-300
  slate800: '#1e293b', // --p-slate-800 (--wb-text-1)
  cyan: '#38bdf8', // --p-cyan-400
  teal: '#0d9488', // --p-teal-600 (--wb-teal)
  red: '#ef4444', // --p-red-500 (--wb-red)
} as const

/** 图表字号唯一出口（design-tokens §7）：取值为 --wb-fs-* 阶梯镜像，禁止消费侧写字面量 */
export const wbChartFs = {
  tick: 10, // --wb-fs-2xs
  axis: 11, // --wb-fs-xs
  label: 12, // --wb-fs-sm
} as const

/** 工作台图表统一色板：蓝主色 + 克制的同族辅助色 */
export const wbPalette = {
  primary: wbChart.blue2,
  primaryLight: wbChart.blue4,
  cyan: wbChart.cyan,
  teal: wbChart.teal,
  green: wbChart.green,
  amber: wbChart.amber,
  red: wbChart.red,
  gray: wbChart.axis,
  indigo: wbChart.blue3, // 无 indigo 原色,归并最近档 --p-blue-500(design-tokens §6 R4)
}

export const wbDonutColors = [
  wbPalette.primary,
  wbPalette.cyan,
  wbPalette.teal,
  wbPalette.amber,
  wbPalette.indigo,
  wbPalette.gray,
]

/** 环形/饼图类目取色：索引超过色板长度时循环复用,杜绝越界 undefined */
export const wbDonutColor = (i: number) => wbDonutColors[i % wbDonutColors.length]

/** 蓝阶 4 档(深→浅)：堆叠柱/层级序列用,消费侧 i % length 防越界 */
export const wbBlueScale = [wbChart.blue1, wbChart.blue2, wbChart.blue3, wbChart.blue4]

/** 同源色取透明度：'#rrggbb' × alpha(0~1) → '#rrggbbaa'(canvas 可解析) */
export const wbAlpha = (color: string, alpha: number) =>
  `${color}${Math.round(alpha * 255).toString(16).padStart(2, '0')}`

const axisLabel = {
  color: wbChart.text,
  fontSize: wbChartFs.axis,
}

export const wbCategoryAxis = (data: string[], extra: Record<string, unknown> = {}) => ({
  type: 'category' as const,
  data,
  axisLine: { lineStyle: { color: wbChart.axisLine } },
  axisTick: { show: false },
  axisLabel: { ...axisLabel, margin: 10 },
  ...extra,
})

export const wbValueAxis = (extra: Record<string, unknown> = {}) => ({
  type: 'value' as const,
  axisLine: { show: false },
  axisTick: { show: false },
  axisLabel,
  splitLine: { lineStyle: { color: wbChart.grid } },
  ...extra,
})

export const wbTooltip = (trigger: 'axis' | 'item' = 'axis') => ({
  trigger,
  backgroundColor: wbAlpha(wbChart.white, 0.96),
  borderColor: wbChart.slate200,
  borderWidth: 1,
  textStyle: { color: wbChart.slate800, fontSize: wbChartFs.label },
  axisPointer: { lineStyle: { color: wbChart.slate300 } },
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
    { offset: 0, color: wbAlpha(color, 0.15) },
    { offset: 1, color: wbAlpha(color, 0.02) },
  ])
