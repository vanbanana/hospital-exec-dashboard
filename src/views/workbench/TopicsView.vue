<template>
  <div class="wb-page">
    <WbPageHead title="专题分析" sub="DRG 付费 · 医保基金 · 国考指标 · 门诊统筹">
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
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
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
import {
  wbPalette,
  wbCategoryAxis,
  wbValueAxis,
  wbTooltip,
  wbGrid,
} from '../../components/workbench/chartPresets'
import { getTopics } from '../../api/workbench'
import type { RangeKey, TopicKey, TopicsResp } from '../../api/types'

const range = ref('本年')
// key 即契约 §13.1 topic 枚举
const topic = ref('drg')

const topicList = [
  { key: 'drg', name: 'DRG 付费分析', icon: FolderKanban },
  { key: 'insurance', name: '医保基金运行', icon: Landmark },
  { key: 'exam', name: '三级公立医院国考', icon: Award },
  { key: 'outp_fund', name: '门诊统筹', icon: Store },
]

const resp = ref<TopicsResp | null>(null)

const load = async () => {
  resp.value = await getTopics(topic.value as TopicKey, range.value as RangeKey)
}
onMounted(load)
watch([topic, range], load)

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
      itemStyle: { color: wbPalette.primary, borderColor: '#fff', borderWidth: 1.5 },
      lineStyle: { color: wbPalette.primary, width: 2.5 },
      areaStyle: {
        color: {
          type: 'linear', x: 0, y: 0, x2: 0, y2: 1,
          colorStops: [
            { offset: 0, color: 'rgba(37,99,235,0.12)' },
            { offset: 1, color: 'rgba(37,99,235,0.02)' },
          ],
        },
      },
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
  const d = resp.value
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
  padding: 8px 0;
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
