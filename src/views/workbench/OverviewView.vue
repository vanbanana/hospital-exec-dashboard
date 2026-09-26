<template>
  <div class="wb-page">
    <WbPageHead title="综合概览" sub="全院运营全景 · 数据截至 2026-10-28">
      <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
    </WbPageHead>

    <!-- 核心指标条 -->
    <WbStatStrip :items="stats" />

    <!-- 趋势 + 收入结构 -->
    <div class="wb-grid wb-grid-2-1">
      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">业务规模与收入趋势</h3>
          <span class="wb-panel-sub">门诊人次（柱） × 医疗收入（线 · 万元）</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="trendOption" />
        </div>
      </div>

      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">收入结构</h3>
          <span class="wb-panel-sub">本年累计</span>
        </div>
        <div class="wb-panel-body income-body">
          <WbChart :option="incomeOption" class="income-donut" />
          <ul class="income-legend">
            <li v-for="(it, i) in incomeData" :key="it.name">
              <span class="wb-dot" :style="{ backgroundColor: wbDonutColors[i] }"></span>
              <span class="income-name">{{ it.name }}</span>
              <span class="income-pct wb-num">{{ it.value }}%</span>
            </li>
          </ul>
        </div>
      </div>
    </div>

    <!-- 科室构成 + 实时动态 -->
    <div class="wb-grid wb-grid-2-1">
      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">科室服务量构成 TOP8</h3>
          <span class="wb-panel-sub">{{ shareMetric }}</span>
        </div>
        <div class="wb-panel-body">
          <div class="share-list">
            <div v-for="it in deptShare" :key="it.name" class="share-row">
              <span class="share-name">{{ it.name }}</span>
              <div class="wb-bar">
                <div class="wb-bar-fill" :style="{ width: it.bar_pct + '%' }"></div>
              </div>
              <span class="share-val wb-num">{{ it.value.toLocaleString('en-US') }}</span>
              <span class="share-pct wb-num">{{ it.bar_pct }}%</span>
            </div>
          </div>
        </div>
      </div>

      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">实时在院动态</h3>
          <span class="wb-panel-sub">每 5 分钟刷新</span>
        </div>
        <div class="wb-panel-body">
          <div class="wb-list live-list">
            <div v-for="it in liveItems" :key="it.label" class="wb-list-row">
              <span class="wb-dot" :style="{ backgroundColor: toneColor[it.tone] }"></span>
              <span class="wb-list-main">{{ it.label }}</span>
              <span class="live-val wb-num">{{ it.value }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import type { EChartsOption } from 'echarts'
import WbPageHead from '../../components/workbench/WbPageHead.vue'
import WbSeg from '../../components/workbench/WbSeg.vue'
import WbStatStrip from '../../components/workbench/WbStatStrip.vue'
import WbChart from '../../components/workbench/WbChart.vue'
import {
  wbPalette,
  wbDonutColors,
  wbCategoryAxis,
  wbValueAxis,
  wbTooltip,
  wbGrid,
} from '../../components/workbench/chartPresets'
import { getOverview } from '../../api/workbench'
import type { NameValue, OverviewResp, RangeKey, ToneType, WbStatItem } from '../../api/types'

const range = ref('本年')

const stats = ref<WbStatItem[]>([])
const trend = ref<OverviewResp['scale_revenue_trend'] | null>(null)
const incomeData = ref<NameValue[]>([])
const shareMetric = ref('')
const deptShare = ref<OverviewResp['dept_share_top8']['list']>([])
const liveItems = ref<OverviewResp['live_inpatient']>([])

// tone 语义色 → 圆点实色；契约禁下十六进制（api-contract §1.4-6），由前端样式映射
const toneColor: Record<ToneType, string> = {
  primary: wbPalette.primary,
  teal: wbPalette.teal,
  green: wbPalette.green,
  amber: wbPalette.amber,
  red: wbPalette.red,
  navy: '#0b1f47', // 对齐 --wb-navy
}

const load = async () => {
  const d = await getOverview(range.value as RangeKey)
  stats.value = d.stats
  trend.value = d.scale_revenue_trend
  incomeData.value = d.income_structure.list
  shareMetric.value = d.dept_share_top8.metric
  deptShare.value = d.dept_share_top8.list
  liveItems.value = d.live_inpatient
}
onMounted(load)
watch(range, load)

const trendOption = computed<EChartsOption>(() => {
  const t = trend.value
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
    xAxis: wbCategoryAxis(t?.months ?? []),
    yAxis: [
      wbValueAxis({ name: t?.units.outpatient, nameTextStyle: { color: '#94a3b8', fontSize: 11 } }),
      wbValueAxis({
        name: t?.units.revenue,
        nameTextStyle: { color: '#94a3b8', fontSize: 11 },
        splitLine: { show: false },
      }),
    ],
    series: [
      {
        name: '门诊人次',
        type: 'bar',
        data: t?.outpatient ?? [],
        barWidth: 14,
        itemStyle: { color: wbPalette.primary, borderRadius: [3, 3, 0, 0] },
      },
      {
        name: '医疗收入',
        type: 'line',
        yAxisIndex: 1,
        data: t?.revenue ?? [],
        smooth: 0.35,
        symbol: 'circle',
        symbolSize: 5,
        itemStyle: { color: wbPalette.teal },
        lineStyle: { color: wbPalette.teal, width: 2.5 },
      },
    ],
  }
})

const incomeOption = computed<EChartsOption>(() => ({
  animation: false,
  tooltip: { ...wbTooltip('item'), formatter: '{b}：{c}%' },
  series: [
    {
      type: 'pie',
      radius: ['58%', '82%'],
      center: ['50%', '50%'],
      itemStyle: { borderColor: '#fff', borderWidth: 2 },
      label: { show: false },
      data: incomeData.value.map((d, i) => ({
        ...d,
        itemStyle: { color: wbDonutColors[i] },
      })),
    },
  ],
}))
</script>

<style scoped>
.income-body {
  flex-direction: row;
  align-items: center;
  gap: 8px;
}

.income-donut {
  width: 46%;
  min-height: 190px;
}

.income-legend {
  list-style: none;
  margin: 0;
  padding: 0 8px 0 0;
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.income-legend li {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
}

.income-name {
  color: var(--wb-text-1);
}

.income-pct {
  margin-left: auto;
  font-weight: 600;
  color: var(--wb-navy);
}

.share-list {
  display: flex;
  flex-direction: column;
  justify-content: space-evenly;
  height: 100%;
  gap: 4px;
}

.share-row {
  display: flex;
  align-items: center;
  gap: 10px;
}

.share-name {
  width: 130px;
  font-size: 13px;
  color: var(--wb-text-1);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  flex-shrink: 0;
}

.share-val {
  width: 52px;
  text-align: right;
  font-size: 13px;
  font-weight: 600;
  color: var(--wb-navy);
  flex-shrink: 0;
}

.share-pct {
  width: 38px;
  text-align: right;
  font-size: 12px;
  color: var(--wb-text-3);
  flex-shrink: 0;
}

.live-list {
  height: 100%;
  justify-content: space-evenly;
}

.live-val {
  font-size: 16px;
  font-weight: 700;
  color: var(--wb-navy);
}
</style>
