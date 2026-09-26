<template>
  <div class="trend-card">
    <!-- Header Row 1: Title -->
    <div class="card-title-row">
      <h3 class="card-title">医疗业务趋势</h3>
    </div>

    <!-- Header Row 2: Tabs on Left, Legend on Right -->
    <div class="card-sub-header">
      <div class="tabs-row">
        <button
          v-for="(tab, idx) in tabs"
          :key="tab"
          class="tab-btn"
          :class="{ active: currentTab === idx }"
          @click="currentTab = idx"
        >
          {{ tab }}
        </button>
      </div>

      <div class="legend-row">
        <div class="legend-item">
          <span class="legend-dot current-dot"></span>
          <span class="legend-label">本期</span>
        </div>
        <div class="legend-item">
          <span class="legend-dot last-dot"></span>
          <span class="legend-label">上期</span>
        </div>
      </div>
    </div>

    <!-- Chart -->
    <WbChart :option="chartOption" />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import type { EChartsOption } from 'echarts'
import WbChart from './WbChart.vue'
import { getHomeTrend } from '../../api/workbench'
import type { HomeTrendSeries } from '../../api/types'
import {
  wbPalette,
  wbCategoryAxis,
  wbValueAxis,
  wbTooltip,
  wbGrid,
  wbAreaGradient,
} from './chartPresets'

const tabs = ref<string[]>([])
const currentTab = ref(0)
const months = ref<string[]>([])
const series = ref<Record<string, HomeTrendSeries>>({})

onMounted(async () => {
  const resp = await getHomeTrend()
  months.value = resp.months
  series.value = resp.series
  // series 键即 Tab 名，顺序与契约示例一致（api-contract §3.2）
  tabs.value = Object.keys(resp.series)
})

const chartOption = computed<EChartsOption>(() => {
  const ds = series.value[tabs.value[currentTab.value]]
  if (!ds) return { animation: false }
  return {
    animation: false,
    grid: wbGrid({ top: 16, bottom: 8 }),
    tooltip: wbTooltip('axis'),
    xAxis: wbCategoryAxis(months.value, {
      boundaryGap: false,
      splitLine: { show: true, lineStyle: { color: '#f4f7fb' } },
    }),
    yAxis: wbValueAxis({
      axisLabel: { color: '#64748b', fontSize: 11, formatter: (v: number) => v.toLocaleString() },
    }),
    series: [
      {
        name: '本期',
        type: 'line',
        smooth: 0.35,
        data: ds.current,
        symbol: 'circle',
        symbolSize: 6,
        itemStyle: { color: wbPalette.primary, borderColor: '#fff', borderWidth: 1.5 },
        lineStyle: { color: wbPalette.primary, width: 2.5 },
        areaStyle: { color: wbAreaGradient(wbPalette.primary) },
      },
      {
        name: '上期',
        type: 'line',
        smooth: 0.35,
        data: ds.last,
        symbol: 'circle',
        symbolSize: 5,
        itemStyle: { color: wbPalette.primaryLight, borderColor: '#fff', borderWidth: 1.5 },
        lineStyle: { color: wbPalette.primaryLight, width: 2 },
        areaStyle: { color: wbAreaGradient(wbPalette.primaryLight) },
      },
    ],
  }
})
</script>

<style scoped>
.trend-card {
  height: 100%;
  box-sizing: border-box;
  background: var(--wb-surface);
  border-radius: var(--wb-radius-card);
  border: 1px solid var(--wb-border);
  box-shadow: var(--wb-shadow-card);
  padding: 14px 16px 10px;
  display: flex;
  flex-direction: column;
  user-select: none;
  min-width: 0;
}

.card-title-row {
  margin-bottom: 6px;
}

.card-title {
  font-size: 15px;
  font-weight: 700;
  color: var(--wb-navy);
  margin: 0;
  letter-spacing: 0.3px;
}

.card-sub-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 4px;
}

.tabs-row {
  display: flex;
  align-items: center;
  gap: 18px;
}

.tab-btn {
  background: none;
  border: none;
  outline: none;
  cursor: pointer;
  font-size: 13px;
  font-weight: 500;
  color: var(--wb-text-2);
  padding: 3px 2px 5px;
  position: relative;
  transition: color 0.15s;
  font-family: inherit;
}

.tab-btn:hover {
  color: var(--wb-primary);
}

.tab-btn.active {
  color: var(--wb-primary);
  font-weight: 600;
}

.tab-btn.active::after {
  content: '';
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  height: 2px;
  background-color: var(--wb-primary);
  border-radius: 1px;
}

.legend-row {
  display: flex;
  align-items: center;
  gap: 14px;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 6px;
}

.legend-dot {
  width: 18px;
  height: 2.5px;
  border-radius: 2px;
  position: relative;
}

.legend-dot::after {
  content: '';
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 6px;
  height: 6px;
  border-radius: 50%;
}

.current-dot {
  background-color: var(--wb-accent);
}
.current-dot::after {
  background-color: var(--wb-accent);
}

.last-dot {
  background-color: #93c5fd;
}
.last-dot::after {
  background-color: #93c5fd;
}

.legend-label {
  font-size: 12px;
  color: var(--wb-text-1);
  font-weight: 500;
}

.wb-chart {
  min-height: 200px;
}
</style>
