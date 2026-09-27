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

    <!-- Chart / 五态 -->
    <WbErrorPanel v-if="error && data === null" :error="error" :loading="loading" @retry="reload" />
    <WbSkeleton v-else-if="data === null && loading" :rows="4" />
    <WbEmpty v-else-if="!tabs.length" text="暂无趋势数据" />
    <template v-else>
      <WbStaleTag v-if="stale" :loading="loading" @retry="reload" />
      <WbChart :option="chartOption" />
    </template>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import type { EChartsOption } from 'echarts'
import WbChart from './WbChart.vue'
import WbSkeleton from './WbSkeleton.vue'
import WbErrorPanel from './WbErrorPanel.vue'
import WbEmpty from './WbEmpty.vue'
import WbStaleTag from './WbStaleTag.vue'
import { getHomeTrend } from '../../api/workbench'
import { useAsyncData } from '../../api/useAsyncData'
import type { HomeTrendSeries } from '../../api/types'
import {
  wbChart,
  wbChartFs,
  wbPalette,
  wbCategoryAxis,
  wbValueAxis,
  wbTooltip,
  wbGrid,
  wbAreaGradient,
} from './chartPresets'

// 五态取数经 useAsyncData（frontend-architecture §10.1）
const { data, loading, error, stale, reload } = useAsyncData(getHomeTrend)
onMounted(reload)

const currentTab = ref(0)
const months = computed(() => data.value?.months ?? [])
const series = computed((): Record<string, HomeTrendSeries> => data.value?.series ?? {})
// series 键即 Tab 名，顺序与契约示例一致（api-contract §3.2）
const tabs = computed(() => Object.keys(series.value))

const chartOption = computed<EChartsOption>(() => {
  const ds = series.value[tabs.value[currentTab.value]]
  if (!ds) return { animation: false }
  return {
    animation: false,
    grid: wbGrid({ top: 16, bottom: 8 }),
    tooltip: wbTooltip('axis'),
    xAxis: wbCategoryAxis(months.value, {
      boundaryGap: false,
      splitLine: { show: true, lineStyle: { color: wbChart.grid } },
    }),
    yAxis: wbValueAxis({
      axisLabel: { color: wbChart.text, fontSize: wbChartFs.axis, formatter: (v: number) => v.toLocaleString() },
    }),
    series: [
      {
        name: '本期',
        type: 'line',
        smooth: 0.35,
        data: ds.current,
        symbol: 'circle',
        symbolSize: 6,
        itemStyle: { color: wbPalette.primary, borderColor: wbChart.white, borderWidth: 1.5 },
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
        itemStyle: { color: wbPalette.primaryLight, borderColor: wbChart.white, borderWidth: 1.5 },
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
  padding: var(--wb-pad-y) var(--wb-pad-x) var(--wb-space-2);
  display: flex;
  flex-direction: column;
  user-select: none;
  min-width: 0;
}

.card-title-row {
  margin-bottom: var(--wb-space-1);
}

.card-title {
  font-size: var(--wb-fs-lg);
  font-weight: var(--wb-fw-bold);
  color: var(--wb-navy);
  margin: 0;
  letter-spacing: var(--wb-ls-md);
}

.card-sub-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: var(--wb-space-1);
}

.tabs-row {
  display: flex;
  align-items: center;
  gap: var(--wb-space-5);
}

.tab-btn {
  background: none;
  border: none;
  outline: none;
  cursor: pointer;
  font-size: var(--wb-fs-md);
  font-weight: var(--wb-fw-medium);
  color: var(--wb-text-2);
  padding: var(--wb-space-1);
  position: relative;
  transition: color var(--wb-dur-fast);
  font-family: inherit;
}

.tab-btn:hover {
  color: var(--wb-primary);
}

.tab-btn.active {
  color: var(--wb-primary);
  font-weight: var(--wb-fw-semibold);
}

.tab-btn.active::after {
  content: '';
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  height: 2px;
  background-color: var(--wb-primary);
  border-radius: var(--wb-radius-sm);
}

.legend-row {
  display: flex;
  align-items: center;
  gap: var(--wb-space-3);
}

.legend-item {
  display: flex;
  align-items: center;
  gap: var(--wb-space-1);
}

.legend-dot {
  width: 18px;
  height: 2.5px;
  border-radius: var(--wb-radius-sm);
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
  border-radius: var(--wb-radius-pill);
}

.current-dot {
  background-color: var(--wb-accent);
}
.current-dot::after {
  background-color: var(--wb-accent);
}

.last-dot {
  background-color: var(--wb-chart-blue-4);
}
.last-dot::after {
  background-color: var(--wb-chart-blue-4);
}

.legend-label {
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-1);
  font-weight: var(--wb-fw-medium);
}

.wb-chart {
  min-height: 200px;
}
</style>
