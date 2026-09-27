<template>
  <ScrPanel title="DRG盈亏 × CMI 四象限">
    <!-- REF 惯例：图例 HTML 自制挪副栏（spec §3.3 patient-sub-bar / chart-legends），不用 ECharts legend -->
    <div v-if="option" class="scr-sub-bar">
      <span class="scr-sub">{{ subText }}</span>
      <div class="scr-legend">
        <span class="scr-legend-item"><i class="scr-dot dot-accent"></i>外科系</span>
        <span class="scr-legend-item"><i class="scr-dot dot-royal"></i>内科系</span>
      </div>
    </div>
    <ScrChart v-if="option" :option="option" class="drg-chart" />
    <div v-else class="scr-empty">暂无散点数据</div>
  </ScrPanel>
</template>

<script setup lang="ts">
import { ref, watch, onMounted, computed } from 'vue'
import * as echarts from 'echarts'
import ScrPanel from './ScrPanel.vue'
import ScrChart from './ScrChart.vue'
import { readScrPalette } from './scrTokens'
import type { DrgPoint, DrgQuadrant } from '../../api/types'

const props = defineProps<{ data?: DrgQuadrant }>()

const subText = computed(() =>
  props.data ? `近${props.data.period.slice(1)}日 · 气泡=病例数` : ''
)

const option = ref<echarts.EChartsOption>()

function build(): echarts.EChartsOption | undefined {
  const d = props.data
  if (!d || !d.points.length) return undefined
  const p = readScrPalette()

  const mkSeries = (cat: DrgPoint['category'], name: string, color: string): echarts.SeriesOption => ({
    name,
    type: 'scatter',
    data: d.points
      .filter((pt) => pt.category === cat)
      .map((pt) => ({
        value: [pt.profit, pt.cmi, pt.case_cnt],
        name: pt.name,
        dept: pt,
      })),
    symbolSize: (val: number[]) => 8 + Math.sqrt((val[2] as number) ?? 0) * 0.32,
    itemStyle: { color, borderColor: p.text1, borderWidth: 1, opacity: p.itemOpacity },
    emphasis: { itemStyle: { opacity: 1 } }, // 悬停恢复满透明（极值豁免）
  })

  return {
    grid: { left: 46, right: 20, top: 14, bottom: 34 },
    tooltip: {
      trigger: 'item',
      backgroundColor: p.tooltipBg,
      borderColor: p.border,
      textStyle: { color: p.text1, fontSize: p.fsSm },
      formatter: (param: unknown) => {
        const pt = (param as { data: { dept: DrgPoint } }).data.dept
        return `${pt.name} · Q${pt.quadrant}<br/>CMI ${pt.cmi}　盈亏 ${pt.profit} 万元<br/>病例数 ${pt.case_cnt}`
      },
    },
    xAxis: {
      type: 'value',
      name: d.axis.x,
      nameLocation: 'middle',
      nameGap: 24,
      nameTextStyle: { color: p.text4, fontSize: p.fsXs },
      axisLine: { lineStyle: { color: p.axisLine } },
      axisLabel: { color: p.text4, fontSize: p.fsAxis },
      splitLine: { lineStyle: { color: p.gridLine, type: 'dashed' } },
    },
    yAxis: {
      type: 'value',
      name: d.axis.y,
      nameTextStyle: { color: p.text4, fontSize: p.fsXs },
      axisLine: { lineStyle: { color: p.axisLine } },
      axisLabel: { color: p.text4, fontSize: p.fsAxis },
      splitLine: { lineStyle: { color: p.gridLine, type: 'dashed' } },
      scale: true,
    },
    series: [
      {
        type: 'scatter',
        data: [],
        markLine: {
          silent: true,
          symbol: 'none',
          lineStyle: { color: p.accentBright, type: 'dashed', width: 1, opacity: p.splitOpacity },
          label: { show: false },
          data: [{ xAxis: d.split.x }, { yAxis: d.split.y }],
        },
        markArea: {
          silent: true,
          itemStyle: { color: p.quadrantBg },
          data: [[{ xAxis: d.split.x, yAxis: d.split.y }, { xAxis: 'max', yAxis: 'max' }]],
        },
      },
      mkSeries('surg', '外科系', p.accentBright),
      mkSeries('med', '内科系', p.blue),
    ],
  }
}

onMounted(() => {
  option.value = build()
})
watch(
  () => props.data,
  () => {
    option.value = build()
  }
)
</script>

<style scoped>
.drg-chart {
  flex: 1;
}
</style>
