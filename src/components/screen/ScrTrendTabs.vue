<template>
  <ScrPanel title="业务趋势">
    <template v-if="tabs.length">
      <!-- REF nav-tabs 解剖：深色胶囊容器 + 选中态蓝渐变 -->
      <div class="trend-tabs">
        <button
          v-for="t in tabs"
          :key="t.code"
          type="button"
          class="trend-tab"
          :class="{ active: t.code === activeCode }"
          @click="activeCode = t.code"
        >
          {{ t.name }}
        </button>
      </div>
      <!-- REF patient-sub-bar 解剖：左 当前值徽标区，右 次级标注 -->
      <div class="trend-hero" v-if="active">
        <span class="hero-name">{{ active.name }}</span>
        <span class="hero-val scr-num">{{ fmtNum(active.kpi?.value ?? active.latest) }}</span>
        <span class="hero-unit">{{ active.unit }}</span>
        <span v-if="active.kpi" class="scr-badge" :class="dirBadge(active.kpi.direction)">
          {{ dirMark(active.kpi.direction) }}{{ fmtDelta(active.kpi.delta_pct) }}
        </span>
        <span v-if="active.kpi" class="hero-prev scr-num">前日 {{ fmtNum(active.kpi.prev_value) }}</span>
      </div>
      <ScrChart v-if="option" :option="option" class="trend-chart" />
      <div v-else class="scr-empty">该指标暂无趋势序列</div>
    </template>
    <div v-else class="scr-empty">暂无趋势数据</div>
  </ScrPanel>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import * as echarts from '../../charts'
import ScrPanel from './ScrPanel.vue'
import ScrChart from './ScrChart.vue'
import { readScrPalette } from './scrTokens'
import type { ScreenKpi, ScreenSnapshotResp } from '../../api/types'

const props = defineProps<{
  trends?: ScreenSnapshotResp['trends']
  kpis?: ScreenKpi[]
}>()


interface TrendTab {
  code: string
  name: string
  unit: string
  latest: number
  values: number[]
  kpi?: ScreenKpi
}

/* B11 修正：tab 顺序与 KPI 条一致（kpis[] 序优先，series 多出的键排尾） */
const tabs = computed<TrendTab[]>(() => {
  const t = props.trends
  if (!t) return []
  const series = t.series
  const codes = [
    ...(props.kpis?.map((k) => k.code).filter((c) => c in series) ?? []),
    ...Object.keys(series).filter((c) => !props.kpis?.some((k) => k.code === c)),
  ]
  return codes.map((code) => {
    const values = series[code] ?? []
    const kpi = props.kpis?.find((k) => k.code === code)
    return { code, name: kpi?.name ?? code, unit: kpi?.unit ?? '', latest: values[values.length - 1] ?? 0, values, kpi }
  })
})

const activeCode = ref('')
// 首屏/换数后校正选中项：当前 code 失效时落到首个 tab
watch(tabs, (ts) => {
  if (!ts.some((t) => t.code === activeCode.value)) activeCode.value = ts[0]?.code ?? ''
}, { immediate: true })

const active = computed(() => tabs.value.find((t) => t.code === activeCode.value))

const fmtNum = (v: number) => (Number.isInteger(v) ? v.toLocaleString('en-US') : v.toFixed(1))
const fmtDelta = (v: number) => `${v > 0 ? '+' : ''}${v}%`
const dirMark = (d: number) => (d > 0 ? '▲' : d < 0 ? '▼' : '—')
/* REF hero-metric-badge 语义：up=绿 / down=红 / flat=青（spec §5.3-1 裁决：直取信号原色） */
const dirBadge = (d: number) => (d > 0 ? 'is-up' : d < 0 ? 'is-down' : 'is-flat')

/* 单线平滑渐变面积折线（REF 患者图解剖：symbol:none、宽2、面积 .18→0） */
const option = computed<echarts.EChartsOption | undefined>(() => {
  const t = props.trends
  const cur = active.value
  if (!t || !cur || !cur.values.length) return undefined
  const p = readScrPalette()
  return {
    grid: { left: 44, right: 16, top: 14, bottom: 24 },
    tooltip: {
      trigger: 'axis',
      backgroundColor: p.tooltipBg,
      borderColor: p.border,
      textStyle: { color: p.text1, fontSize: p.fsXs },
    },
    xAxis: {
      type: 'category',
      data: t.dates,
      boundaryGap: false,
      axisLine: { lineStyle: { color: p.axisLine } },
      axisLabel: { color: p.text3, fontSize: p.fsAxis },
    },
    yAxis: {
      type: 'value',
      scale: true,
      axisLine: { lineStyle: { color: p.axisLine } },
      axisLabel: { color: p.text3, fontSize: p.fsAxis },
      splitLine: { lineStyle: { color: p.gridLine, type: 'dashed' } },
    },
    series: [
      {
        name: cur.name,
        type: 'line',
        data: cur.values,
        smooth: true,
        symbol: 'none',
        lineStyle: { color: p.accent, width: 2 },
        areaStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: p.areaTop },
            { offset: 1, color: p.areaBottom },
          ]),
        },
      },
    ],
  }
})
</script>

<style scoped>
.trend-tabs {
  display: flex;
  gap: var(--scr-space-3);
  padding: var(--scr-space-2);
  margin-bottom: var(--scr-space-5);
  background: var(--scr-bar-track);
  border: 1px solid var(--scr-inset-border);
  border-radius: var(--scr-radius-card);
  flex-shrink: 0;
}

.trend-tab {
  flex: 1;
  padding: var(--scr-space-2) var(--scr-space-3);
  border: 1px solid transparent;
  border-radius: var(--scr-radius-tag);
  background: transparent;
  font-size: var(--scr-fs-12);
  font-weight: var(--scr-fw-medium);
  color: var(--scr-text-3);
  cursor: pointer;
  white-space: nowrap;
  transition: all var(--scr-dur-normal) ease;
}

.trend-tab:hover {
  color: var(--scr-text-1);
  background: rgb(from var(--scr-royal) r g b / 0.15);
}

/* REF nav-tab.active：白字 600 + royal 纵向渐变 + 蓝边 + 发光 */
.trend-tab.active {
  color: var(--scr-text-1);
  font-weight: var(--scr-fw-semibold);
  background: linear-gradient(180deg, var(--scr-royal), var(--scr-royal-deep));
  border-color: var(--p-blue-600);
  box-shadow: 0 2px 8px rgb(from var(--scr-royal) r g b / 0.35);
}

.trend-hero {
  display: flex;
  align-items: baseline;
  gap: var(--scr-space-3);
  margin-bottom: var(--scr-space-3);
  flex-shrink: 0;
}

.hero-name {
  font-size: var(--scr-fs-sm);
  color: var(--scr-text-3);
}

.hero-val {
  font-size: var(--scr-fs-19);
  font-weight: var(--scr-fw-bold);
  color: var(--scr-text-1);
  line-height: var(--scr-lh-tight);
}

.hero-unit {
  font-size: var(--scr-fs-xs);
  color: var(--scr-text-4);
}

.hero-prev {
  margin-left: auto;
  font-size: var(--scr-fs-xs);
  color: var(--scr-text-4);
}

.trend-chart {
  flex: 1;
  min-height: 0;
}
</style>
