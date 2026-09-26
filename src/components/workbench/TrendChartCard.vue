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
import { ref, computed } from 'vue'
import type { EChartsOption } from 'echarts'
import WbChart from './WbChart.vue'
import {
  wbPalette,
  wbCategoryAxis,
  wbValueAxis,
  wbTooltip,
  wbGrid,
  wbAreaGradient,
} from './chartPresets'

const tabs = ['门急诊人次', '住院人次', '手术台次', '医疗收入']
const currentTab = ref(0)

const months = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月']

const datasets = [
  {
    current: [5400, 4600, 6800, 7000, 8500, 9000, 10800, 9700, 10500, 12300, 12200, 12000],
    last: [4600, 3900, 5200, 5200, 6800, 7200, 9000, 9200, 8700, 10200, 10100, 9900],
  },
  {
    current: [2850, 2400, 3100, 3300, 3500, 3600, 3900, 4100, 3800, 3920, 3700, 3600],
    last: [2500, 2100, 2700, 2900, 3100, 3200, 3400, 3500, 3300, 3600, 3400, 3300],
  },
  {
    current: [860, 720, 980, 1020, 1080, 1120, 1180, 1210, 1150, 1286, 1200, 1160],
    last: [760, 680, 850, 890, 940, 980, 1030, 1060, 1010, 1120, 1080, 1040],
  },
  {
    current: [1420, 1280, 1720, 1850, 1980, 2060, 2210, 2150, 2080, 2356, 2260, 2180],
    last: [1280, 1100, 1450, 1580, 1720, 1800, 1950, 1920, 1850, 2100, 2020, 1950],
  },
]

const chartOption = computed<EChartsOption>(() => {
  const ds = datasets[currentTab.value]
  return {
    animation: false,
    grid: wbGrid({ top: 16, bottom: 8 }),
    tooltip: wbTooltip('axis'),
    xAxis: wbCategoryAxis(months, {
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
