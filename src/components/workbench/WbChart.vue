<template>
  <div ref="chartRef" class="wb-chart"></div>
</template>

<script setup lang="ts">
import { ref, watch, onMounted, onUnmounted } from 'vue'
import * as echarts from '../../charts'

const props = defineProps<{
  option: echarts.EChartsOption
}>()

const chartRef = ref<HTMLElement | null>(null)
let chart: echarts.ECharts | null = null
let observer: ResizeObserver | null = null
let resizeFrame = 0

onMounted(() => {
  if (!chartRef.value) return
  chart = echarts.init(chartRef.value)
  chart.setOption(props.option)
  observer = new ResizeObserver(() => {
    cancelAnimationFrame(resizeFrame)
    resizeFrame = requestAnimationFrame(() => chart?.resize())
  })
  observer.observe(chartRef.value)
})

watch(
  () => props.option,
  (opt) => {
    chart?.setOption(opt, { notMerge: true })
  },
  { deep: true }
)

onUnmounted(() => {
  observer?.disconnect()
  cancelAnimationFrame(resizeFrame)
  chart?.dispose()
})
</script>
