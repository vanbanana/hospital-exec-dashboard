<template>
  <div ref="chartRef" class="scr-chart"></div>
</template>

<script setup lang="ts">
import { ref, watch, onMounted, onUnmounted } from 'vue'
import * as echarts from 'echarts'

const props = defineProps<{
  option?: echarts.EChartsOption
}>()

const chartRef = ref<HTMLElement | null>(null)
let chart: echarts.ECharts | null = null
let observer: ResizeObserver | null = null

onMounted(() => {
  if (!chartRef.value) return
  chart = echarts.init(chartRef.value)
  if (props.option) chart.setOption(props.option)
  observer = new ResizeObserver(() => chart?.resize())
  observer.observe(chartRef.value)
})

watch(
  () => props.option,
  (opt) => {
    if (opt) chart?.setOption(opt, { notMerge: true })
  },
  { deep: true }
)

onUnmounted(() => {
  observer?.disconnect()
  chart?.dispose()
})
</script>

<style scoped>
.scr-chart {
  width: 100%;
  height: 100%;
  min-height: 0;
}
</style>
