<template>
  <div class="wb-page">
    <WbPageHead title="综合概览" sub="全院运营全景 · 数据截至 2024-10-28">
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
          <span class="wb-panel-sub">门诊 + 住院合计当量</span>
        </div>
        <div class="wb-panel-body">
          <div class="share-list">
            <div v-for="it in deptShare" :key="it.name" class="share-row">
              <span class="share-name">{{ it.name }}</span>
              <div class="wb-bar">
                <div class="wb-bar-fill" :style="{ width: it.pct + '%' }"></div>
              </div>
              <span class="share-val wb-num">{{ it.value }}</span>
              <span class="share-pct wb-num">{{ it.pct }}%</span>
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
              <span class="wb-dot" :style="{ backgroundColor: it.color }"></span>
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
import { ref, computed } from 'vue'
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

const range = ref('本年')

const stats = [
  { label: '门急诊人次', value: '12,482', delta: '+3.6%', dir: 'up' as const },
  { label: '出院人数', value: '3,920', delta: '+5.1%', dir: 'up' as const },
  { label: '手术台次', value: '1,286', delta: '+4.8%', dir: 'up' as const },
  { label: '医疗收入', value: '23,560', unit: '万元', delta: '+2.9%', dir: 'up' as const },
  { label: '床位使用率', value: '92.1', unit: '%', delta: '+1.2%', dir: 'up' as const },
  { label: '平均住院日', value: '6.8', unit: '天', delta: '-0.3', dir: 'down' as const },
]

const months = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月']
const outpatient = [5400, 4600, 6800, 7000, 8500, 9000, 10800, 9700, 10500, 12300, 12200, 12000]
const revenue = [1420, 1280, 1720, 1850, 1980, 2060, 2210, 2150, 2080, 2356, 2260, 2180]

const trendOption = computed<EChartsOption>(() => ({
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
  xAxis: wbCategoryAxis(months),
  yAxis: [
    wbValueAxis({ name: '人次', nameTextStyle: { color: '#94a3b8', fontSize: 11 } }),
    wbValueAxis({
      name: '万元',
      nameTextStyle: { color: '#94a3b8', fontSize: 11 },
      splitLine: { show: false },
    }),
  ],
  series: [
    {
      name: '门诊人次',
      type: 'bar',
      data: outpatient,
      barWidth: 14,
      itemStyle: { color: wbPalette.primary, borderRadius: [3, 3, 0, 0] },
    },
    {
      name: '医疗收入',
      type: 'line',
      yAxisIndex: 1,
      data: revenue,
      smooth: 0.35,
      symbol: 'circle',
      symbolSize: 5,
      itemStyle: { color: wbPalette.teal },
      lineStyle: { color: wbPalette.teal, width: 2.5 },
    },
  ],
}))

const incomeData = [
  { name: '住院收入', value: 54 },
  { name: '门诊收入', value: 38 },
  { name: '其他收入', value: 8 },
]

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
      data: incomeData.map((d, i) => ({
        ...d,
        itemStyle: { color: wbDonutColors[i] },
      })),
    },
  ],
}))

const deptShare = [
  { name: '心血管内科', value: '1,860', pct: 92 },
  { name: '骨科', value: '1,724', pct: 85 },
  { name: '呼吸与危重症医学科', value: '1,615', pct: 80 },
  { name: '普通外科', value: '1,480', pct: 73 },
  { name: '神经内科', value: '1,342', pct: 66 },
  { name: '肿瘤科', value: '1,208', pct: 60 },
  { name: '妇产科', value: '1,126', pct: 56 },
  { name: '儿科', value: '1,045', pct: 52 },
]

const liveItems = [
  { label: '当前在院人数', value: '1,846', color: wbPalette.primary },
  { label: '今日入院', value: '162', color: wbPalette.teal },
  { label: '今日出院', value: '148', color: wbPalette.teal },
  { label: '急诊在观', value: '36', color: wbPalette.amber },
  { label: 'ICU 在科', value: '22', color: wbPalette.red },
  { label: '手术进行中', value: '9', color: wbPalette.primary },
]
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
