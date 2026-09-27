<template>
  <div class="wb-page">
    <WbPageHead title="医疗业务" sub="门急诊 · 住院 · 手术明细分析 · 数据截至 2026-10-28">
      <WbStaleTag v-if="stale" :loading="loading" @retry="reload" />
      <WbSeg v-model="bizTab" :options="['门急诊', '住院', '手术']" />
      <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
    </WbPageHead>

    <!-- 五态门：data 未落地时面板级 loading/error/empty（§10.1） -->
    <div v-if="data === null" class="wb-panel">
      <div class="wb-panel-body">
        <WbErrorPanel v-if="error" :error="error" :loading="loading" @retry="reload" />
        <WbSkeleton v-else-if="loading" :rows="8" />
        <WbEmpty v-else text="暂无医疗业务数据" />
      </div>
    </div>
    <template v-else>
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
    </template>
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
import WbSkeleton from '../../components/workbench/WbSkeleton.vue'
import WbErrorPanel from '../../components/workbench/WbErrorPanel.vue'
import WbEmpty from '../../components/workbench/WbEmpty.vue'
import WbStaleTag from '../../components/workbench/WbStaleTag.vue'
import {
  wbChart,
  wbPalette,
  wbDonutColor,
  wbCategoryAxis,
  wbValueAxis,
  wbTooltip,
  wbGrid,
  wbAreaGradient,
} from '../../components/workbench/chartPresets'
import { getMedical } from '../../api/workbench'
import { useAsyncData } from '../../api/useAsyncData'
import type { MedicalTab, RangeKey, WbTableData } from '../../api/types'

const bizTab = ref('门急诊')
const range = ref('本年')
// WbSeg 出参为中文标签,映射为契约 tab/range 枚举(§1.4-1,非法值后端回 10001)
const TAB_PARAM: Record<string, MedicalTab> = { 门急诊: '门急诊', 住院: '住院', 手术: '手术' }
const RANGE_PARAM: Record<string, RangeKey> = { 本月: '本月', 本季: '本季', 本年: '本年' }

// 五态取数经 useAsyncData（frontend-architecture §10.1）：watch(tab/range) 重取走 reload
const { data, loading, error, stale, reload } = useAsyncData(() =>
  getMedical(TAB_PARAM[bizTab.value] ?? '门急诊', RANGE_PARAM[range.value] ?? '本年'),
)
onMounted(reload)
watch([bizTab, range], reload)

const stats = computed(() => data.value?.stats ?? [])
const trend = computed(() => data.value?.trend ?? null)
const dist = computed(() => data.value?.distribution ?? null)
const table = computed((): WbTableData => data.value?.table ?? { columns: [], rows: [] })

const trendOption = computed<EChartsOption>(() => {
  const t = trend.value
  return {
    animation: false,
    grid: wbGrid({ top: 20 }),
    tooltip: wbTooltip('axis'),
    xAxis: wbCategoryAxis(t?.months ?? [], { boundaryGap: false }),
    yAxis: wbValueAxis({
      axisLabel: { color: wbChart.text, fontSize: 11, formatter: (v: number) => v.toLocaleString() },
    }),
    series: [
      {
        name: t?.name ?? '',
        type: 'line',
        smooth: 0.35,
        data: t?.values ?? [],
        symbol: 'circle',
        symbolSize: 5,
        itemStyle: { color: wbPalette.primary, borderColor: wbChart.white, borderWidth: 1.5 },
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
        textStyle: { fontSize: 12, color: wbChart.text },
      },
      series: [
        {
          type: 'pie',
          radius: ['50%', '72%'],
          center: ['50%', '46%'],
          itemStyle: { borderColor: wbChart.white, borderWidth: 2 },
          label: {
            show: true,
            formatter: '{d}%',
            fontSize: 11,
            color: wbChart.text,
          },
          data: d.categories.map((name, i) => ({
            name,
            value: d.values[i],
            itemStyle: { color: wbDonutColor(i) },
          })),
        },
      ],
    }
  }
  return {
    animation: false,
    grid: wbGrid({ top: 16 }),
    tooltip: wbTooltip('axis'),
    xAxis: wbCategoryAxis(d?.categories ?? [], { axisLabel: { color: wbChart.text, fontSize: 10, margin: 8 } }),
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
