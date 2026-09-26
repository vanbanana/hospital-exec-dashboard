<template>
  <div class="wb-page">
    <WbPageHead title="科研教学" sub="课题 · 论文 · 重点学科 · 教学培训 · 数据截至 2026-10-28">
      <WbSeg v-model="range" :options="['本季', '本年', '近三年']" />
    </WbPageHead>

    <WbStatStrip :items="stats" />

    <div class="wb-grid wb-grid-2">
      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">立项课题与经费</h3>
          <span class="wb-panel-sub">立项数（柱） × 经费（线 · 万元）</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="projectOption" />
        </div>
      </div>

      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">论文发表</h3>
          <span class="wb-panel-sub">近五年 SCI / 核心 / 普刊</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="paperOption" />
        </div>
      </div>
    </div>

    <div class="wb-panel">
      <div class="wb-panel-head">
        <h3 class="wb-panel-title">重点学科建设</h3>
        <span class="wb-panel-sub">国家级 / 省级 / 市级梯队</span>
      </div>
      <div class="wb-panel-body">
        <WbTable :columns="disciplines.columns" :rows="disciplines.rows" row-key="name">
          <template #cell-level="{ value }">
            <span
              class="wb-tag"
              :class="value === '国家级' ? 'is-red' : value === '省级' ? 'is-blue' : 'is-gray'"
            >
              {{ value }}
            </span>
          </template>
        </WbTable>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
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
import { getResearch } from '../../api/workbench'
import type { ResearchResp, WbStatItem, WbTableData } from '../../api/types'

// 契约 §8.1 无 range 参数 — WbSeg 仅保留视图交互状态，切换不触发取数
const range = ref('本年')

const stats = ref<WbStatItem[]>([])
const projectTrend = ref<ResearchResp['project_trend'] | null>(null)
const paperDist = ref<ResearchResp['paper_distribution'] | null>(null)
const disciplines = ref<WbTableData>({ columns: [], rows: [] })

const load = async () => {
  const d = await getResearch()
  stats.value = d.stats
  projectTrend.value = d.project_trend
  paperDist.value = d.paper_distribution
  disciplines.value = d.disciplines
}
onMounted(load)

const projectOption = computed<EChartsOption>(() => {
  const t = projectTrend.value
  return {
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
    xAxis: wbCategoryAxis(t?.years ?? []),
    yAxis: [
      wbValueAxis({ name: '项', nameTextStyle: { color: '#94a3b8', fontSize: 11 } }),
      wbValueAxis({
        name: t?.unit ?? '万元',
        nameTextStyle: { color: '#94a3b8', fontSize: 11 },
        splitLine: { show: false },
      }),
    ],
    series: [
      {
        name: '立项课题数',
        type: 'bar',
        // 契约按国家级/省级两序列下发，柱形合计还原"立项课题数"口径（§8.1 注：与 stats 年度新立项 42 自洽）
        data: t ? t.national.map((n, i) => n + (t.provincial[i] ?? 0)) : [],
        barWidth: 22,
        itemStyle: { color: wbPalette.primary, borderRadius: [3, 3, 0, 0] },
      },
      {
        name: '科研经费',
        type: 'line',
        yAxisIndex: 1,
        data: t?.funds ?? [],
        smooth: 0.35,
        symbol: 'circle',
        symbolSize: 5,
        itemStyle: { color: wbPalette.amber },
        lineStyle: { color: wbPalette.amber, width: 2.5 },
      },
    ],
  }
})

const paperOption = computed<EChartsOption>(() => ({
  animation: false,
  grid: wbGrid({ top: 34 }),
  tooltip: { ...wbTooltip('axis'), axisPointer: { type: 'shadow' } },
  legend: {
    top: 0,
    right: 0,
    itemWidth: 10,
    itemHeight: 10,
    textStyle: { fontSize: 12, color: '#475569' },
  },
  xAxis: wbCategoryAxis(paperDist.value?.categories ?? []),
  yAxis: wbValueAxis({ name: paperDist.value?.unit ?? '篇', nameTextStyle: { color: '#94a3b8', fontSize: 11 } }),
  series: [
    {
      name: '论文数',
      type: 'bar',
      barWidth: 26,
      data: paperDist.value?.values ?? [],
      itemStyle: { color: wbPalette.primary, borderRadius: [3, 3, 0, 0] },
    },
  ],
}))
</script>
