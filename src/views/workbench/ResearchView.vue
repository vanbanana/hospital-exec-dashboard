<template>
  <div class="wb-page">
    <WbPageHead title="科研教学" :sub="`课题 · 论文 · 重点学科 · 教学培训 · 固定统计口径 · 数据截至 ${systemDate}`">
      <WbStaleTag v-if="stale" :loading="loading" @retry="reload" />
    </WbPageHead>

    <!-- 五态门：data 未落地时面板级 loading/error/empty（§10.1） -->
    <div v-if="data === null" class="wb-panel">
      <div class="wb-panel-body">
        <WbErrorPanel v-if="error" :error="error" :loading="loading" @retry="reload" />
        <WbSkeleton v-else-if="loading" :rows="8" />
        <WbEmpty v-else text="暂无科研教学数据" />
      </div>
    </div>
    <template v-else>
    <WbStatStrip :items="stats" />

    <div class="wb-grid wb-grid-2">
      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">立项课题与经费</h3>
          <span class="wb-panel-sub">课题立项（国家级/省级堆叠柱） × 经费（线 · {{ projectTrend?.unit ?? '万元' }}）</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="projectOption" />
        </div>
      </div>

      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">论文发表</h3>
          <span class="wb-panel-sub">分区构成 · {{ (paperDist?.categories ?? []).join(' / ') }}</span>
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
              :class="value === '国家临床重点' ? 'is-red' : value === '省级重点专科' ? 'is-blue' : 'is-gray'"
            >
              {{ value }}
            </span>
          </template>
        </WbTable>
      </div>
    </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import type { EChartsOption } from 'echarts'
import WbPageHead from '../../components/workbench/WbPageHead.vue'
import WbStatStrip from '../../components/workbench/WbStatStrip.vue'
import WbChart from '../../components/workbench/WbChart.vue'
import WbTable from '../../components/workbench/WbTable.vue'
import WbSkeleton from '../../components/workbench/WbSkeleton.vue'
import WbErrorPanel from '../../components/workbench/WbErrorPanel.vue'
import WbEmpty from '../../components/workbench/WbEmpty.vue'
import WbStaleTag from '../../components/workbench/WbStaleTag.vue'
import {
  wbChart,
  wbChartFs,
  wbPalette,
  wbCategoryAxis,
  wbValueAxis,
  wbTooltip,
  wbGrid,
} from '../../components/workbench/chartPresets'
import { getResearch } from '../../api/workbench'
import { useAsyncData } from '../../api/useAsyncData'
import { useSystemDate } from '../../api/useSystemDate'
import type { WbTableData } from '../../api/types'

const systemDate = useSystemDate()

// 五态取数经 useAsyncData（frontend-architecture §10.1）
const { data, loading, error, stale, reload } = useAsyncData(getResearch)
onMounted(reload)

const stats = computed(() => data.value?.stats ?? [])
const projectTrend = computed(() => data.value?.project_trend ?? null)
const paperDist = computed(() => data.value?.paper_distribution ?? null)
const disciplines = computed((): WbTableData => data.value?.disciplines ?? { columns: [], rows: [] })

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
      textStyle: { fontSize: wbChartFs.label, color: wbChart.text },
    },
    xAxis: wbCategoryAxis(t?.years ?? []),
    yAxis: [
      wbValueAxis({ name: '项', nameTextStyle: { color: wbChart.axis, fontSize: wbChartFs.axis } }),
      wbValueAxis({
        name: t?.unit ?? '万元',
        nameTextStyle: { color: wbChart.axis, fontSize: wbChartFs.axis },
        splitLine: { show: false },
      }),
    ],
    series: [
      {
        name: '国家级课题',
        type: 'bar',
        stack: '课题',
        data: t?.national ?? [],
        barWidth: 22,
        itemStyle: { color: wbPalette.primary, borderRadius: [0, 0, 0, 0] },
      },
      {
        name: '省级课题',
        type: 'bar',
        stack: '课题',
        data: t?.provincial ?? [],
        itemStyle: { color: wbPalette.teal, borderRadius: [3, 3, 0, 0] },
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
    textStyle: { fontSize: wbChartFs.label, color: wbChart.text },
  },
  xAxis: wbCategoryAxis(paperDist.value?.categories ?? []),
  yAxis: wbValueAxis({ name: paperDist.value?.unit ?? '篇', nameTextStyle: { color: wbChart.axis, fontSize: wbChartFs.axis } }),
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
