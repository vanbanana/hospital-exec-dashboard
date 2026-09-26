<template>
  <div class="wb-page">
    <WbPageHead title="患者服务" sub="满意度 · 投诉表扬 · 就诊体验 · 数据截至 2024-10-28">
      <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
    </WbPageHead>

    <WbStatStrip :items="stats" />

    <div class="wb-grid wb-grid-2">
      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">满意度趋势</h3>
          <span class="wb-panel-sub">门诊 vs 住院（分）</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="satOption" />
        </div>
      </div>

      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">挂号渠道分布</h3>
          <span class="wb-panel-sub">本月各渠道占比</span>
        </div>
        <div class="wb-panel-body channel-body">
          <WbChart :option="channelOption" class="channel-donut" />
          <ul class="channel-legend">
            <li v-for="(it, i) in channelData" :key="it.name">
              <span class="wb-dot" :style="{ backgroundColor: wbDonutColors[i] }"></span>
              <span class="channel-name">{{ it.name }}</span>
              <span class="channel-pct wb-num">{{ it.value }}%</span>
            </li>
          </ul>
        </div>
      </div>
    </div>

    <div class="wb-panel">
      <div class="wb-panel-head">
        <h3 class="wb-panel-title">投诉与表扬记录</h3>
        <span class="wb-panel-sub">近 30 日 · 共 57 件</span>
      </div>
      <div class="wb-panel-body">
        <WbTable :columns="cols" :rows="rows" row-key="id">
          <template #cell-type="{ value }">
            <span class="wb-tag" :class="value === '投诉' ? 'is-red' : 'is-green'">{{ value }}</span>
          </template>
          <template #cell-status="{ value }">
            <span
              class="wb-tag"
              :class="value === '已办结' ? 'is-gray' : value === '处理中' ? 'is-amber' : 'is-blue'"
            >
              {{ value }}
            </span>
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
  wbDonutColors,
  wbCategoryAxis,
  wbValueAxis,
  wbTooltip,
  wbGrid,
} from '../../components/workbench/chartPresets'

const range = ref('本月')

const stats = [
  { label: '门诊满意度', value: '96.2', unit: '分', delta: '+0.4', dir: 'up' as const },
  { label: '住院满意度', value: '95.8', unit: '分', delta: '+0.6', dir: 'up' as const },
  { label: '本月投诉', value: '12', unit: '件', delta: '-3件', dir: 'down' as const },
  { label: '本月表扬', value: '45', unit: '件', delta: '+8件', dir: 'up' as const },
  { label: '平均候诊', value: '18', unit: '分钟', delta: '-3分钟', dir: 'down' as const },
  { label: '网约挂号率', value: '64.5', unit: '%', delta: '+5.2%', dir: 'up' as const },
]

const months = ['5月', '6月', '7月', '8月', '9月', '10月']

const satOption = computed<EChartsOption>(() => ({
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
  yAxis: wbValueAxis({ min: 90, max: 100 }),
  series: [
    {
      name: '门诊满意度',
      type: 'line',
      smooth: 0.35,
      data: [94.8, 95.2, 95.5, 95.6, 95.9, 96.2],
      symbol: 'circle',
      symbolSize: 5,
      itemStyle: { color: wbPalette.primary },
      lineStyle: { color: wbPalette.primary, width: 2.5 },
    },
    {
      name: '住院满意度',
      type: 'line',
      smooth: 0.35,
      data: [94.2, 94.6, 95.0, 95.2, 95.4, 95.8],
      symbol: 'circle',
      symbolSize: 5,
      itemStyle: { color: wbPalette.teal },
      lineStyle: { color: wbPalette.teal, width: 2.5 },
    },
  ],
}))

const channelData = [
  { name: '微信小程序', value: 38 },
  { name: '自助机', value: 24 },
  { name: '人工窗口', value: 18 },
  { name: '官方 APP', value: 14 },
  { name: '电话预约', value: 6 },
]

const channelOption = computed<EChartsOption>(() => ({
  animation: false,
  tooltip: { ...wbTooltip('item'), formatter: '{b}：{c}%' },
  series: [
    {
      type: 'pie',
      radius: ['54%', '78%'],
      center: ['50%', '50%'],
      itemStyle: { borderColor: '#fff', borderWidth: 2 },
      label: { show: false },
      data: channelData.map((d, i) => ({ ...d, itemStyle: { color: wbDonutColors[i] } })),
    },
  ],
}))

const cols: WbTableColumn[] = [
  { key: 'type', title: '类型', align: 'center', width: '64px' },
  { key: 'content', title: '内容摘要' },
  { key: 'dept', title: '涉及科室' },
  { key: 'channel', title: '渠道' },
  { key: 'date', title: '日期', align: 'center' },
  { key: 'status', title: '状态', align: 'center' },
]

const rows = [
  { id: 1, type: '表扬', content: '急诊科医护人员深夜救治及时，家属致谢', dept: '急诊科', channel: '12345热线', date: '10-27', status: '已办结' },
  { id: 2, type: '投诉', content: '门诊缴费窗口排队时间过长（高峰时段）', dept: '门诊部', channel: '现场意见箱', date: '10-26', status: '处理中' },
  { id: 3, type: '投诉', content: '住院部陪护床管理不规范', dept: '护理部', channel: '电话', date: '10-24', status: '已办结' },
  { id: 4, type: '表扬', content: '骨科王主任术后随访细致', dept: '骨科', channel: '小程序', date: '10-23', status: '已办结' },
  { id: 5, type: '投诉', content: '放射科取报告自助机故障', dept: '放射科', channel: '现场', date: '10-22', status: '已办结' },
  { id: 6, type: '表扬', content: '产科病房护理服务贴心', dept: '妇产科', channel: '满意度回访', date: '10-21', status: '已办结' },
  { id: 7, type: '投诉', content: '停车场出口排队拥堵', dept: '后勤保障部', channel: '电话', date: '10-20', status: '待核实' },
]
</script>

<style scoped>
.channel-body {
  flex-direction: row;
  align-items: center;
}

.channel-donut {
  width: 42%;
  min-height: 190px;
}

.channel-legend {
  list-style: none;
  margin: 0;
  padding: 0;
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.channel-legend li {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  padding: 6px 0;
  border-bottom: 1px solid var(--wb-hairline);
}
.channel-legend li:last-child {
  border-bottom: none;
}

.channel-name {
  color: var(--wb-text-1);
}

.channel-pct {
  margin-left: auto;
  font-weight: 600;
  color: var(--wb-navy);
}
</style>
