<template>
  <div class="wb-page">
    <WbPageHead title="质量与安全" :sub="`核心制度 · 院感监测 · 不良事件 · 数据截至 ${systemDate}`">
      <WbStaleTag v-if="stale" :loading="loading" @retry="reload" />
      <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
    </WbPageHead>

    <!-- 五态门：data 未落地时面板级 loading/error/empty（§10.1） -->
    <div v-if="data === null" class="wb-panel">
      <div class="wb-panel-body">
        <WbErrorPanel v-if="error" :error="error" :loading="loading" @retry="reload" />
        <WbSkeleton v-else-if="loading" :rows="8" />
        <WbEmpty v-else text="暂无质量安全数据" />
      </div>
    </div>
    <template v-else>
    <WbStatStrip :items="stats" />

    <div class="wb-grid wb-grid-2">
      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">院感发生率趋势</h3>
          <span class="wb-panel-sub">对照控制目标 {{ infection?.target }}{{ infection?.unit ?? '%' }}</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="infectionOption" />
        </div>
      </div>

      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">不良事件类型分布</h3>
          <span class="wb-panel-sub">{{ range }}累计上报 {{ adverseTotal }} {{ adverse?.unit ?? '起' }}</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="eventOption" />
        </div>
      </div>
    </div>

    <div class="wb-panel">
      <div class="wb-panel-head">
        <h3 class="wb-panel-title">医疗核心制度执行监测</h3>
        <span class="wb-panel-sub">{{ range }}抽查结果</span>
      </div>
      <div class="wb-panel-body">
        <WbTable :columns="rulesTable.columns" :rows="rulesTable.rows" row-key="name" />
      </div>
    </div>
    </template>
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
import { getQuality } from '../../api/workbench'
import { useAsyncData } from '../../api/useAsyncData'
import { useSystemDate } from '../../api/useSystemDate'
import type { QualityResp } from '../../api/types'

// 契约 §10.1 无 range 参数 — WbSeg 仅保留视图交互状态，切换不触发取数
const systemDate = useSystemDate()
const range = ref('本年')

// 五态取数经 useAsyncData（frontend-architecture §10.1）
const { data, loading, error, stale, reload } = useAsyncData(getQuality)
onMounted(reload)

const stats = computed(() => data.value?.stats ?? [])
const infection = computed(() => data.value?.infection_trend ?? null)
const adverse = computed(() => data.value?.adverse_events ?? null)
const rulesTable = computed(
  (): QualityResp['rules_compliance'] => data.value?.rules_compliance ?? { columns: [], rows: [] },
)

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
    textStyle: { fontSize: wbChartFs.label, color: wbChart.text },
  },
  xAxis: wbCategoryAxis(infection.value?.months ?? [], { boundaryGap: false }),
  yAxis: wbValueAxis({
    min: 0,
    max: 3,
    name: infection.value?.unit ?? '%',
    nameTextStyle: { color: wbChart.axis, fontSize: wbChartFs.axis },
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
          fontSize: wbChartFs.axis,
          color: wbPalette.red,
          position: 'insideEndTop',
        },
        lineStyle: { color: wbPalette.red, type: 'dashed', width: 1.5 },
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
    axisLabel: { color: wbChart.text, fontSize: wbChartFs.label },
  },
  series: [
    {
      type: 'bar',
      data: adverse.value?.values ?? [],
      barWidth: 12,
      itemStyle: { color: wbPalette.primary, borderRadius: [0, 3, 3, 0] },
      label: { show: true, position: 'right', fontSize: wbChartFs.axis, color: wbChart.text },
    },
  ],
}))
</script>

