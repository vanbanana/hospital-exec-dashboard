<template>
  <div class="wb-page">
    <WbPageHead title="综合概览" :sub="`全院运营全景 · 数据截至 ${systemDate}`">
      <WbStaleTag v-if="stale" :loading="loading" @retry="reload" />
      <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
    </WbPageHead>

    <!-- 五态门：data 未落地时面板级 loading/error/empty（§10.1） -->
    <div v-if="data === null" class="wb-panel">
      <div class="wb-panel-body">
        <WbErrorPanel v-if="error" :error="error" :loading="loading" @retry="reload" />
        <WbSkeleton v-else-if="loading" :rows="8" />
        <WbEmpty v-else text="暂无概览数据" />
      </div>
    </div>
    <template v-else>
    <!-- 核心指标条 -->
    <WbStatStrip :items="stats" />

    <!-- 趋势 + 收入结构 -->
    <div class="wb-grid wb-grid-2-1">
      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">业务规模与收入趋势</h3>
          <span class="wb-panel-sub">门诊人次（柱） × 医疗收入（线 · {{ trend?.units?.revenue ?? '万元' }}）</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="trendOption" />
        </div>
      </div>

      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">收入结构</h3>
          <span class="wb-panel-sub">{{ data?.range ?? range }}累计</span>
        </div>
        <div class="wb-panel-body income-body">
          <WbEmpty v-if="!incomeData.length" text="暂无收入结构数据" />
          <template v-else>
            <WbChart :option="incomeOption" class="income-donut" />
            <ul class="income-legend">
              <li v-for="(it, i) in incomeData" :key="it.name">
                <span class="wb-dot" :style="{ backgroundColor: wbDonutColor(i) }"></span>
                <span class="income-name">{{ it.name }}</span>
                <span class="income-pct wb-num">{{ it.value }}{{ incomeUnit }}</span>
              </li>
            </ul>
          </template>
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
            <WbEmpty v-if="!deptShare.length" text="暂无科室构成数据" />
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
          <span class="wb-panel-sub">当前快照</span>
        </div>
        <div class="wb-panel-body">
          <div class="wb-list live-list">
            <WbEmpty v-if="!liveItems.length" text="暂无在院动态" />
            <div v-for="it in liveItems" :key="it.label" class="wb-list-row">
              <span class="wb-dot" :style="{ backgroundColor: TONE_COLOR[it.tone] }"></span>
              <span class="wb-list-main">{{ it.label }}</span>
              <span class="live-val wb-num">{{ it.value }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { useDefaultRange } from '../../api/preferences'
import { computed, onMounted, watch } from 'vue'
import type { EChartsOption } from 'echarts'
import WbPageHead from '../../components/workbench/WbPageHead.vue'
import WbSeg from '../../components/workbench/WbSeg.vue'
import WbStatStrip from '../../components/workbench/WbStatStrip.vue'
import WbChart from '../../components/workbench/WbChart.vue'
import WbSkeleton from '../../components/workbench/WbSkeleton.vue'
import WbErrorPanel from '../../components/workbench/WbErrorPanel.vue'
import WbEmpty from '../../components/workbench/WbEmpty.vue'
import WbStaleTag from '../../components/workbench/WbStaleTag.vue'
import {
  wbChart,
  wbChartFs,
  wbPalette,
  wbDonutColor,
  wbCategoryAxis,
  wbValueAxis,
  wbTooltip,
  wbGrid,
} from '../../components/workbench/chartPresets'
import { getOverview } from '../../api/workbench'
import { useAsyncData } from '../../api/useAsyncData'
import { useSystemDate } from '../../api/useSystemDate'
import type { RangeKey, ToneType } from '../../api/types'

const systemDate = useSystemDate()
const range = useDefaultRange()
// WbSeg 出参为中文标签,映射为契约 range 枚举(§1.4-1,非法值后端回 10001)
const RANGE_PARAM: Record<string, RangeKey> = { 本月: '本月', 本季: '本季', 本年: '本年' }

// 五态取数经 useAsyncData（frontend-architecture §10.1）：watch(range) 重取走 reload
const { data, loading, error, stale, reload } = useAsyncData(() =>
  getOverview(RANGE_PARAM[range.value] ?? '本年'),
)
onMounted(reload)
watch(range, reload)

const stats = computed(() => data.value?.stats ?? [])
const trend = computed(() => data.value?.scale_revenue_trend ?? null)
const incomeData = computed(() => data.value?.income_structure.list ?? [])
const incomeUnit = computed(() => data.value?.income_structure.unit ?? '%')
const shareMetric = computed(() => data.value?.dept_share_top8.metric ?? '')
const deptShare = computed(() => data.value?.dept_share_top8.list ?? [])
const liveItems = computed(() => data.value?.live_inpatient ?? [])

// tone 语义色 → 圆点实色；契约禁下十六进制（api-contract §1.4-6），DOM 侧直接挂 --wb-* token
const TONE_COLOR: Record<ToneType, string> = {
  primary: 'var(--wb-accent)',
  teal: 'var(--wb-teal)',
  green: 'var(--wb-green)',
  amber: 'var(--wb-amber)',
  red: 'var(--wb-red)',
  navy: 'var(--wb-navy)',
}

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
      textStyle: { fontSize: wbChartFs.label, color: wbChart.text },
    },
    xAxis: wbCategoryAxis(t?.months ?? []),
    yAxis: [
      wbValueAxis({ name: t?.units.outpatient, nameTextStyle: { color: wbChart.axis, fontSize: wbChartFs.axis } }),
      wbValueAxis({
        name: t?.units.revenue,
        nameTextStyle: { color: wbChart.axis, fontSize: wbChartFs.axis },
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
  tooltip: { ...wbTooltip('item'), formatter: (params) => { const p = Array.isArray(params) ? params[0] : params; return `${p?.name ?? ''}：${p?.value ?? ''}${incomeUnit.value}` } },
  series: [
    {
      type: 'pie',
      radius: ['58%', '82%'],
      center: ['50%', '50%'],
      itemStyle: { borderColor: wbChart.white, borderWidth: 2 },
      label: { show: false },
      data: incomeData.value.map((d, i) => ({
        ...d,
        itemStyle: { color: wbDonutColor(i) },
      })),
    },
  ],
}))
</script>

<style scoped>
.income-body {
  flex-direction: row;
  align-items: center;
  gap: var(--wb-space-2);
}

.income-donut {
  width: 46%;
  min-height: 190px;
}

.income-legend {
  list-style: none;
  margin: 0;
  padding-right: var(--wb-space-2);
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: var(--wb-space-3);
}

.income-legend li {
  display: flex;
  align-items: center;
  gap: var(--wb-space-2);
  font-size: var(--wb-fs-md);
}

.income-name {
  color: var(--wb-text-1);
}

.income-pct {
  margin-left: auto;
  font-weight: var(--wb-fw-semibold);
  color: var(--wb-navy);
}

.share-list {
  display: flex;
  flex-direction: column;
  justify-content: space-evenly;
  height: 100%;
  gap: var(--wb-space-1);
}

.share-row {
  display: flex;
  align-items: center;
  gap: var(--wb-space-2);
}

.share-name {
  width: 130px;
  font-size: var(--wb-fs-md);
  color: var(--wb-text-1);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  flex-shrink: 0;
}

.share-val {
  width: 52px;
  text-align: right;
  font-size: var(--wb-fs-md);
  font-weight: var(--wb-fw-semibold);
  color: var(--wb-navy);
  flex-shrink: 0;
}

.share-pct {
  width: 38px;
  text-align: right;
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-3);
  flex-shrink: 0;
}

.live-list {
  height: 100%;
  justify-content: space-evenly;
}

.live-val {
  font-size: var(--wb-fs-lg);
  font-weight: var(--wb-fw-bold);
  color: var(--wb-navy);
}
</style>
