// ECharts/TS 侧取色：读 .screen-layout 作用域上已解析的 --scr-*/--p-* 令牌，
// 不维护第二份色值表（design-tokens R5 同源要求；TS 上下文无法写 var()，故读计算值）。

export interface ScrPalette {
  accent: string
  accentBright: string
  text1: string
  text2: string
  text3: string
  text4: string
  border: string
  up: string
  down: string
  warn: string
  blue: string
  red: string
  amber: string
  green: string
  // 图表语义槽（design-tokens §5：--scr-chart-* / --scr-tooltip-bg）
  tooltipBg: string
  axisLine: string
  gridLine: string
  quadrantBg: string
  areaTop: string
  areaBottom: string
  // 图表字号槽（design-tokens §5：--scr-fs-*；ECharts fontSize 唯一出口）
  fsXxs: number
  fsAxis: number
  fsXs: number
  fsSm: number
  fsMd: number
  // 图表透明度参数（数据可视参数归调色板，不散落）
  itemOpacity: number
  splitOpacity: number
}

export function readScrPalette(): ScrPalette {
  const el = document.querySelector('.screen-layout') ?? document.body
  const cs = getComputedStyle(el as Element)
  const v = (name: string) => cs.getPropertyValue(name).trim()
  const px = (name: string) => parseFloat(v(name))
  return {
    accent: v('--scr-accent'),
    accentBright: v('--scr-accent-bright'),
    text1: v('--scr-text-1'),
    text2: v('--scr-text-2'),
    text3: v('--scr-text-3'),
    text4: v('--scr-text-4'),
    border: v('--scr-border'),
    up: v('--scr-up'),
    down: v('--scr-down'),
    warn: v('--scr-warn'),
    blue: v('--scr-royal'), // REF 系列2 主蓝 #1e65eb（spec §5.2 拟档 --p-blue-650，勿归并 blue-500）
    red: v('--p-red-500'),
    amber: v('--p-amber-500'),
    green: v('--p-green-500'),
    tooltipBg: v('--scr-tooltip-bg'),
    axisLine: v('--scr-chart-axis'),
    gridLine: v('--scr-chart-grid'),
    quadrantBg: v('--scr-chart-mark'),
    areaTop: v('--scr-chart-area-top'),
    areaBottom: v('--scr-chart-area-bottom'),
    fsXxs: px('--scr-fs-xxs'),
    fsAxis: px('--scr-fs-axis'),
    fsXs: px('--scr-fs-xs'),
    fsSm: px('--scr-fs-sm'),
    fsMd: px('--scr-fs-md'),
    itemOpacity: 0.92,
    splitOpacity: 0.55,
  }
}

/* 画布基准尺寸唯一出处：--scr-canvas-w/h（design-tokens §5）——JS 侧禁写 1920/1080 */
export function readScrCanvas(): { w: number; h: number } {
  const el = document.querySelector('.screen-layout') ?? document.body
  const cs = getComputedStyle(el as Element)
  const w = parseFloat(cs.getPropertyValue('--scr-canvas-w')) || 1920
  const h = parseFloat(cs.getPropertyValue('--scr-canvas-h')) || 1080
  return { w, h }
}
