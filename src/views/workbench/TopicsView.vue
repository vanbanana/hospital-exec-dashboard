<template>
  <div class="wb-page">
    <WbPageHead title="专题分析" sub="DRG 付费 · 医保基金 · 国考指标 · 门诊统筹">
      <WbStaleTag v-if="stale" :loading="loading" @retry="reload" />
      <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
    </WbPageHead>

    <div class="topics-layout">
      <!-- 页内专题子导航 -->
      <div class="wb-panel topics-nav-panel">
        <div class="wb-subnav">
          <div
            v-for="t in topicList"
            :key="t.key"
            class="wb-subnav-item"
            :class="{ active: topic === t.key }"
            @click="topic = t.key"
          >
            <component :is="t.icon" :size="15" :stroke-width="1.9" />
            <span>{{ t.name }}</span>
          </div>
        </div>
      </div>

      <!-- 专题内容 -->
      <div class="topics-content">
        <!-- 五态门：data 未落地时面板级 loading/error/empty（§10.1） -->
        <div v-if="data === null" class="wb-panel">
          <div class="wb-panel-body">
            <WbErrorPanel v-if="error" :error="error" :loading="loading" @retry="reload" />
            <WbSkeleton v-else-if="loading" :rows="8" />
            <WbEmpty v-else text="暂无专题数据" />
          </div>
        </div>
        <template v-else>
        <WbStatStrip :items="cur.stats" />

        <div v-if="cur.chart" class="wb-panel">
          <div class="wb-panel-head">
            <h3 class="wb-panel-title">{{ cur.chartTitle }}</h3>
            <span class="wb-panel-sub">{{ cur.chartSub }}</span>
          </div>
          <div class="wb-panel-body topics-chart-body">
            <WbChart :option="cur.chart" />
          </div>
        </div>

        <div class="wb-panel">
          <div class="wb-panel-head">
            <h3 class="wb-panel-title">{{ cur.tableTitle }}</h3>
            <span class="wb-panel-sub">{{ cur.tableSub }}</span>
          </div>
          <div class="wb-panel-body">
            <WbTable :columns="cur.cols" :rows="cur.rows" :row-key="cur.rowKey" />
          </div>
        </div>
        </template>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import type { Component } from 'vue'
import type { EChartsOption } from 'echarts'
import {
  FolderKanban,
  Landmark,
  Award,
  Store,
} from 'lucide-vue-next'
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
  wbCategoryAxis,
  wbValueAxis,
  wbTooltip,
  wbGrid,
  wbAreaGradient,
} from '../../components/workbench/chartPresets'
import { getTopics } from '../../api/workbench'
import { useAsyncData } from '../../api/useAsyncData'
import type { RangeKey, TopicKey } from '../../api/types'

const range = ref('本年')
// WbSeg 出参为中文标签,映射为契约 range 枚举(§1.4-1,非法值后端回 10001)
const RANGE_PARAM: Record<string, RangeKey> = { 本月: '本月', 本季: '本季', 本年: '本年' }
// key 即契约 §13.1 topic 枚举,ref 与列表同源枚举类型,无需断言
const topic = ref<TopicKey>('drg')

const topicList: { key: TopicKey; name: string; icon: Component }[] = [
  { key: 'drg', name: 'DRG 付费分析', icon: FolderKanban },
  { key: 'insurance', name: '医保基金运行', icon: Landmark },
  { key: 'exam', name: '三级公立医院国考', icon: Award },
  { key: 'outp_fund', name: '门诊统筹', icon: Store },
]

// 五态取数经 useAsyncData（frontend-architecture §10.1）：watch(topic/range) 重取走 reload
const { data, loading, error, stale, reload } = useAsyncData(() =>
  getTopics(topic.value, RANGE_PARAM[range.value] ?? '本年'),
)
onMounted(reload)
watch([topic, range], reload)

const lineChart = (name: string, months: string[], data: number[]): EChartsOption => ({
  animation: false,
  grid: wbGrid({ top: 20 }),
  tooltip: wbTooltip('axis'),
  xAxis: wbCategoryAxis(months, { boundaryGap: false }),
  yAxis: wbValueAxis(),
  series: [
    {
      name,
      type: 'line',
      smooth: 0.35,
      data,
      symbol: 'circle',
      symbolSize: 5,
      itemStyle: { color: wbPalette.primary, borderColor: wbChart.white, borderWidth: 1.5 },
      lineStyle: { color: wbPalette.primary, width: 2.5 },
      areaStyle: { color: wbAreaGradient(wbPalette.primary) },
    },
  ],
})

const barChart = (cats: string[], data: number[]): EChartsOption => ({
  animation: false,
  grid: wbGrid({ top: 20 }),
  tooltip: wbTooltip('axis'),
  xAxis: wbCategoryAxis(cats),
  yAxis: wbValueAxis(),
  series: [
    {
      type: 'bar',
      data,
      barWidth: 18,
      itemStyle: { color: wbPalette.primary, borderRadius: [3, 3, 0, 0] },
    },
  ],
})

// 契约 chart.type 决定渲染形态：bar 用 categories、line 用 months；表格列随服务端下发
const cur = computed(() => {
  const d = data.value
  const c = d?.chart
  return {
    stats: d?.stats ?? [],
    chartTitle: c?.title ?? '',
    chartSub: c?.sub ?? '',
    chart: c
      ? c.type === 'bar'
        ? barChart(c.categories ?? [], c.values)
        : lineChart(c.title, c.months ?? [], c.values)
      : null,
    tableTitle: d?.table.title ?? '',
    tableSub: d?.table.sub ?? '',
    rowKey: d?.table.columns[0]?.key ?? '',
    cols: d?.table.columns ?? [],
    rows: d?.table.rows ?? [],
  }
})
</script>

<style scoped>
.topics-layout {
  display: grid;
  grid-template-columns: 200px minmax(0, 1fr);
  gap: var(--wb-gap);
  align-items: start;
}

.topics-nav-panel {
  padding: var(--wb-space-2) 0;
  position: sticky;
  top: 0;
}

.topics-content {
  display: flex;
  flex-direction: column;
  gap: var(--wb-gap);
  min-width: 0;
}

.topics-chart-body {
  min-height: 220px;
}
</style>
