<template>
  <div class="wb-page">
    <WbPageHead title="质量与安全" sub="核心制度 · 院感监测 · 不良事件 · 数据截至 2026-10-28">
      <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
    </WbPageHead>

    <WbStatStrip :items="stats" />

    <div class="wb-grid wb-grid-2">
      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">院感发生率趋势</h3>
          <span class="wb-panel-sub">对照控制目标 2.0%</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="infectionOption" />
        </div>
      </div>

      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">不良事件类型分布</h3>
          <span class="wb-panel-sub">本年累计上报 {{ adverseTotal }} 起</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="eventOption" />
        </div>
      </div>
    </div>

    <div class="wb-panel">
      <div class="wb-panel-head">
        <h3 class="wb-panel-title">医疗核心制度执行监测</h3>
        <span class="wb-panel-sub">本月抽查结果</span>
      </div>
      <div class="wb-panel-body">
        <WbTable :columns="rulesTable.columns" :rows="rulesTable.rows" row-key="name" />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import type { EChartsOption } from 'echarts'
import WbPageHead from '../../components/workbench/WbPageHead.vue'
import WbSeg from '../../components/workbench/WbSeg.vue'
import WbStatStrip from '../../components/workbench/WbStatStrip.vue'
import WbChart from '../../components/workbench/WbChart.vue'
import WbTable from '../../components/workbench/WbTable.vue'
import {
  wbPalette,
  wbCategoryAxis,
  wbValueAxis,
  wbTooltip,
  wbGrid,
} from '../../components/workbench/chartPresets'
import { getQuality } from '../../api/workbench'
import type { QualityResp, WbStatItem } from '../../api/types'

const range = ref('本年')

const stats = ref<WbStatItem[]>([])
const infection = ref<QualityResp['infection_trend'] | null>(null)
const adverse = ref<QualityResp['adverse_events'] | null>(null)
const rulesTable = ref<QualityResp['rules_compliance']>({ columns: [], rows: [] })

// §10.1 暂无 range 参数，切换仍重取一次，端点补 range 时视图零改动
const load = async () => {
  const d = await getQuality()
  stats.value = d.stats
  infection.value = d.infection_trend
  adverse.value = d.adverse_events
  rulesTable.value = d.rules_compliance
}
onMounted(load)
watch(range, load)

const adverseTotal = computed(() => (adverse.value?.values ?? []).reduce((a, b) => a + b, 0))

const infectionOption = computed<EChartsOption>(() => ({
  animation: false,
  grid: wbGrid({ top: 34 }),
  tooltip: wbTooltip('axis'),
  legend: {
    top: 0,
    right: 0,
    itemWidth: 14,
    itemHeight: 8,
    textStyle: { fontSize: 12, color: '#475569' },
  },
  xAxis: wbCategoryAxis(infection.value?.months ?? [], { boundaryGap: false }),
  yAxis: wbValueAxis({
    min: 0,
    max: 3,
    name: infection.value?.unit ?? '%',
    nameTextStyle: { color: '#94a3b8', fontSize: 11 },
  }),
  series: [
    {
      name: '院感发生率',
      type: 'line',
      smooth: 0.3,
      data: infection.value?.rates ?? [],
      symbol: 'circle',
      symbolSize: 5,
      itemStyle: { color: wbPalette.primary },
      lineStyle: { color: wbPalette.primary, width: 2.5 },
      markLine: {
        symbol: 'none',
        label: {
          formatter: `控制目标 ${infection.value?.target ?? 0}%`,
          fontSize: 11,
          color: '#ef4444',
          position: 'insideEndTop',
        },
        lineStyle: { color: '#ef4444', type: 'dashed', width: 1.5 },
        data: [{ yAxis: infection.value?.target ?? 0 }],
      },
    },
  ],
}))

const eventOption = computed<EChartsOption>(() => ({
  animation: false,
  grid: wbGrid({ left: 8, top: 10, bottom: 4 }),
  tooltip: wbTooltip('axis'),
  xAxis: wbValueAxis(),
  yAxis: {
    type: 'category',
    inverse: true,
    data: adverse.value?.categories ?? [],
    axisLine: { show: false },
    axisTick: { show: false },
    axisLabel: { color: '#475569', fontSize: 12 },
  },
  series: [
    {
      type: 'bar',
      data: adverse.value?.values ?? [],
      barWidth: 12,
      itemStyle: { color: wbPalette.primary, borderRadius: [0, 3, 3, 0] },
      label: { show: true, position: 'right', fontSize: 11, color: '#475569' },
    },
  ],
}))
</script>

