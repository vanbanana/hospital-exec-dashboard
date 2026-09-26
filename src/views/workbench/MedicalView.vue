<template>
  <div class="wb-page">
    <WbPageHead title="医疗业务" sub="门急诊 · 住院 · 手术明细分析 · 数据截至 2026-10-28">
      <WbSeg v-model="bizTab" :options="['门急诊', '住院', '手术']" />
      <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
    </WbPageHead>

    <WbStatStrip :items="stats" />

    <div class="wb-grid wb-grid-2-1">
      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">{{ trend?.title }}</h3>
          <span class="wb-panel-sub">近 12 个月</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="trendOption" />
        </div>
      </div>

      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">{{ dist?.title }}</h3>
          <span class="wb-panel-sub">{{ dist?.sub }}</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="distOption" />
        </div>
      </div>
    </div>

    <div class="wb-panel">
      <div class="wb-panel-head">
        <h3 class="wb-panel-title">科室明细</h3>
        <span class="wb-panel-sub">{{ bizTab }}口径 · 按业务量排序</span>
      </div>
      <div class="wb-panel-body">
        <WbTable :columns="table.columns" :rows="table.rows" row-key="dept" />
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
  wbDonutColors,
  wbCategoryAxis,
  wbValueAxis,
  wbTooltip,
  wbGrid,
  wbAreaGradient,
} from '../../components/workbench/chartPresets'
import { getMedical } from '../../api/workbench'
import type { MedicalResp, MedicalTab, RangeKey, WbStatItem, WbTableData } from '../../api/types'

const bizTab = ref('门急诊')
const range = ref('本年')

const stats = ref<WbStatItem[]>([])
const trend = ref<MedicalResp['trend'] | null>(null)
const dist = ref<MedicalResp['distribution'] | null>(null)
const table = ref<WbTableData>({ columns: [], rows: [] })

const load = async () => {
  const d = await getMedical(bizTab.value as MedicalTab, range.value as RangeKey)
  stats.value = d.stats
  trend.value = d.trend
  dist.value = d.distribution
  table.value = d.table
}
onMounted(load)
watch([bizTab, range], load)

const trendOption = computed<EChartsOption>(() => {
  const t = trend.value
  return {
    animation: false,
    grid: wbGrid({ top: 20 }),
    tooltip: wbTooltip('axis'),
    xAxis: wbCategoryAxis(t?.months ?? [], { boundaryGap: false }),
    yAxis: wbValueAxis({
      axisLabel: { color: '#64748b', fontSize: 11, formatter: (v: number) => v.toLocaleString() },
    }),
    series: [
      {
        name: t?.name ?? '',
        type: 'line',
        smooth: 0.35,
        data: t?.values ?? [],
        symbol: 'circle',
        symbolSize: 5,
        itemStyle: { color: wbPalette.primary, borderColor: '#fff', borderWidth: 1.5 },
        lineStyle: { color: wbPalette.primary, width: 2.5 },
        areaStyle: { color: wbAreaGradient(wbPalette.primary) },
      },
    ],
  }
})

const distOption = computed<EChartsOption>(() => {
  const d = dist.value
  if (d?.type === 'pie') {
    return {
      animation: false,
      tooltip: { ...wbTooltip('item'), formatter: '{b}：{c}%' },
      legend: {
        bottom: 0,
        itemWidth: 10,
        itemHeight: 10,
        textStyle: { fontSize: 12, color: '#475569' },
      },
      series: [
        {
          type: 'pie',
          radius: ['50%', '72%'],
          center: ['50%', '46%'],
          itemStyle: { borderColor: '#fff', borderWidth: 2 },
          label: {
            show: true,
            formatter: '{d}%',
            fontSize: 11,
            color: '#475569',
          },
          data: d.categories.map((name, i) => ({
            name,
            value: d.values[i],
            itemStyle: { color: wbDonutColors[i] },
          })),
        },
      ],
    }
  }
  return {
    animation: false,
    grid: wbGrid({ top: 16 }),
    tooltip: wbTooltip('axis'),
    xAxis: wbCategoryAxis(d?.categories ?? [], { axisLabel: { color: '#64748b', fontSize: 10, margin: 8 } }),
    yAxis: wbValueAxis(),
    series: [
      {
        type: 'bar',
        data: d?.values ?? [],
        barWidth: 16,
        itemStyle: { color: wbPalette.primary, borderRadius: [3, 3, 0, 0] },
      },
    ],
  }
})
</script>
