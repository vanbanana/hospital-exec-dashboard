<template>
  <ScrPanel title="近7日业务趋势" :sub="subText">
    <div v-if="cells.length" class="trend-grid">
      <div v-for="c in cells" :key="c.code" class="trend-cell">
        <div class="trend-cell-head">
          <span class="trend-name">{{ c.name }}</span>
          <span class="trend-latest scr-num">{{ c.latest }}<em>{{ c.unit }}</em></span>
        </div>
        <ScrChart :option="c.option" class="trend-mini" />
      </div>
    </div>
    <div v-else class="scr-empty">暂无趋势数据</div>
  </ScrPanel>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import * as echarts from 'echarts'
import ScrPanel from './ScrPanel.vue'
import ScrChart from './ScrChart.vue'
import { readScrPalette } from './scrTokens'
import type { ScreenKpi, ScreenSnapshotResp } from '../../api/types'

const props = defineProps<{
  trends?: ScreenSnapshotResp['trends']
  kpis?: ScreenKpi[]
}>()

const subText = computed(() => (props.trends ? `${props.trends.days}日` : ''))

interface TrendCell {
  code: string
  name: string
  unit: string
  latest: string
  option: echarts.EChartsOption
}

const cells = computed<TrendCell[]>(() => {
  const t = props.trends
  if (!t) return []
  const p = readScrPalette()
  return Object.entries(t.series).map(([code, values]) => {
    const kpi = props.kpis?.find((k) => k.code === code)
    const last = values[values.length - 1] ?? 0
    return {
      code,
      name: kpi?.name ?? code,
      unit: kpi?.unit ?? '',
      latest: Number.isInteger(last) ? last.toLocaleString('en-US') : last.toFixed(1),
      option: {
        grid: { left: 4, right: 6, top: 8, bottom: 16, containLabel: false },
        xAxis: {
          type: 'category',
          data: t.dates,
          boundaryGap: false,
          axisLine: { show: false },
          axisTick: { show: false },
          axisLabel: { color: p.text4, fontSize: p.fsXxs, interval: 2 },
        },
        yAxis: { show: false, type: 'value', min: 'dataMin', max: 'dataMax' },
        tooltip: {
          trigger: 'axis',
          backgroundColor: p.tooltipBg,
          borderColor: p.border,
          textStyle: { color: p.text1, fontSize: p.fsXs },
        },
        series: [
          {
            type: 'line',
            data: values,
            smooth: true,
            symbol: 'none',
            lineStyle: { color: p.accentBright, width: 1.6 },
            areaStyle: {
              color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
                { offset: 0, color: p.areaTop },
                { offset: 1, color: p.areaBottom },
              ]),
            },
          },
        ],
      } satisfies echarts.EChartsOption,
    }
  })
})
</script>

<style scoped>
.trend-grid {
  flex: 1;
  min-height: 0;
  display: grid;
  grid-template-columns: 1fr 1fr;
  grid-template-rows: 1fr 1fr;
  gap: var(--scr-space-5);
}

.trend-cell {
  display: flex;
  flex-direction: column;
  min-height: 0;
  border: 1px solid var(--scr-border);
  border-radius: var(--scr-radius-card);
  padding: var(--scr-space-4) var(--scr-space-5) var(--scr-space-2);
  background: var(--scr-panel);
}

.trend-cell-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  margin-bottom: var(--scr-space-1);
}

.trend-name {
  font-size: var(--scr-fs-sm);
  color: var(--scr-text-3);
}

.trend-latest {
  font-size: var(--scr-fs-md);
  font-weight: var(--scr-fw-bold);
  color: var(--scr-accent-bright);
}

.trend-latest em {
  font-style: normal;
  font-size: var(--scr-fs-axis);
  color: var(--scr-text-4);
  margin-left: var(--scr-space-2);
}

.trend-mini {
  flex: 1;
  min-height: 0;
}
</style>
