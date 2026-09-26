<template>
  <div class="wb-page">
    <WbPageHead title="质量与安全" sub="核心制度 · 院感监测 · 不良事件 · 数据截至 2024-10-28">
      <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
    </WbPageHead>

    <WbStatStrip :items="stats" />

    <div class="wb-grid wb-grid-2">
      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">院感发生率趋势</h3>
          <span class="wb-panel-sub">对照控制目标 2.0%</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="infectionOption" />
        </div>
      </div>

      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">不良事件类型分布</h3>
          <span class="wb-panel-sub">本年累计上报 42 件</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="eventOption" />
        </div>
      </div>
    </div>

    <div class="wb-panel">
      <div class="wb-panel-head">
        <h3 class="wb-panel-title">医疗核心制度执行监测</h3>
        <span class="wb-panel-sub">本月抽查结果</span>
      </div>
      <div class="wb-panel-body">
        <WbTable :columns="cols" :rows="rows" row-key="rule">
          <template #cell-rate="{ value }">
            <div class="rate-cell">
              <div class="wb-bar">
                <div class="wb-bar-fill" :style="{ width: String(value) }"></div>
              </div>
              <span class="wb-num rate-num">{{ value }}</span>
            </div>
          </template>
          <template #cell-mom="{ value }">
            <span
              class="wb-num"
              :class="String(value).startsWith('-') ? 'wb-delta-down' : 'wb-delta-up'"
            >{{ value }}</span>
          </template>
          <template #cell-status="{ value }">
            <span class="wb-tag" :class="value === '合格' ? 'is-green' : 'is-amber'">{{ value }}</span>
          </template>
        </WbTable>
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
import WbTable, { type WbTableColumn } from '../../components/workbench/WbTable.vue'
import {
  wbPalette,
  wbCategoryAxis,
  wbValueAxis,
  wbTooltip,
  wbGrid,
} from '../../components/workbench/chartPresets'

const range = ref('本年')

const stats = [
  { label: '甲级病案率', value: '92.3', unit: '%', delta: '+0.8%', dir: 'up' as const },
  { label: '院感发生率', value: '1.8', unit: '%', delta: '-0.2%', dir: 'down' as const },
  { label: '危急值处理及时率', value: '98.6', unit: '%', delta: '+0.4%', dir: 'up' as const },
  { label: '不良事件上报', value: '42', unit: '件', note: '本年累计' },
  { label: 'I类切口感染率', value: '0.3', unit: '%', delta: '-0.1%', dir: 'down' as const },
  { label: '抗菌药物使用强度', value: '38.2', unit: 'DDDs', delta: '-1.6', dir: 'down' as const },
]

const months = ['5月', '6月', '7月', '8月', '9月', '10月']

const infectionOption = computed<EChartsOption>(() => ({
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
  xAxis: wbCategoryAxis(months, { boundaryGap: false }),
  yAxis: wbValueAxis({ min: 0, max: 3, name: '%', nameTextStyle: { color: '#94a3b8', fontSize: 11 } }),
  series: [
    {
      name: '院感发生率',
      type: 'line',
      smooth: 0.3,
      data: [2.2, 2.0, 2.1, 1.9, 1.9, 1.8],
      symbol: 'circle',
      symbolSize: 5,
      itemStyle: { color: wbPalette.primary },
      lineStyle: { color: wbPalette.primary, width: 2.5 },
      markLine: {
        symbol: 'none',
        label: { formatter: '控制目标 2.0%', fontSize: 11, color: '#ef4444', position: 'insideEndTop' },
        lineStyle: { color: '#ef4444', type: 'dashed', width: 1.5 },
        data: [{ yAxis: 2.0 }],
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
    data: ['跌倒/坠床', '用药错误', '管路滑脱', '院内压疮', '手术相关', '输血相关', '其他'],
    axisLine: { show: false },
    axisTick: { show: false },
    axisLabel: { color: '#475569', fontSize: 12 },
  },
  series: [
    {
      type: 'bar',
      data: [12, 9, 7, 6, 4, 2, 2],
      barWidth: 12,
      itemStyle: { color: wbPalette.primary, borderRadius: [0, 3, 3, 0] },
      label: { show: true, position: 'right', fontSize: 11, color: '#475569' },
    },
  ],
}))

const cols: WbTableColumn[] = [
  { key: 'rule', title: '核心制度' },
  { key: 'sampled', title: '抽查科室数', align: 'right', num: true },
  { key: 'rate', title: '合格率', width: '220px' },
  { key: 'mom', title: '较上月', align: 'right' },
  { key: 'status', title: '判定', align: 'center' },
]

const rows = [
  { rule: '首诊负责制', sampled: 28, rate: '96.4%', mom: '+1.2%', status: '合格' },
  { rule: '三级查房制度', sampled: 26, rate: '92.3%', mom: '+0.8%', status: '合格' },
  { rule: '会诊制度', sampled: 24, rate: '95.8%', mom: '+2.1%', status: '合格' },
  { rule: '危急值报告制度', sampled: 28, rate: '98.6%', mom: '+0.4%', status: '合格' },
  { rule: '手术安全核查制度', sampled: 22, rate: '99.1%', mom: '+0.2%', status: '合格' },
  { rule: '病历书写规范', sampled: 30, rate: '88.6%', mom: '-1.4%', status: '关注' },
  { rule: '抗菌药物分级管理', sampled: 26, rate: '91.2%', mom: '-0.6%', status: '关注' },
  { rule: '值班交接班制度', sampled: 28, rate: '94.2%', mom: '+0.9%', status: '合格' },
]
</script>

<style scoped>
.rate-cell {
  display: flex;
  align-items: center;
  gap: 10px;
}

.rate-num {
  width: 46px;
  text-align: right;
  font-weight: 600;
  color: var(--wb-navy);
  flex-shrink: 0;
}
</style>
