<template>
  <div class="wb-page">
    <WbPageHead title="科研教学" sub="课题 · 论文 · 重点学科 · 教学培训 · 数据截至 2024-10-28">
      <WbSeg v-model="range" :options="['本季', '本年', '近三年']" />
    </WbPageHead>

    <WbStatStrip :items="stats" />

    <div class="wb-grid wb-grid-2">
      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">立项课题与经费</h3>
          <span class="wb-panel-sub">立项数（柱） × 经费（线 · 万元）</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="projectOption" />
        </div>
      </div>

      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">论文发表</h3>
          <span class="wb-panel-sub">近五年 SCI / 核心 / 普刊</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="paperOption" />
        </div>
      </div>
    </div>

    <div class="wb-panel">
      <div class="wb-panel-head">
        <h3 class="wb-panel-title">重点学科建设</h3>
        <span class="wb-panel-sub">国家级 / 省级 / 市级梯队</span>
      </div>
      <div class="wb-panel-body">
        <WbTable :columns="cols" :rows="rows" row-key="name">
          <template #cell-level="{ value }">
            <span
              class="wb-tag"
              :class="value === '国家级' ? 'is-red' : value === '省级' ? 'is-blue' : 'is-gray'"
            >
              {{ value }}
            </span>
          </template>
          <template #cell-fund="{ value }">
            <span class="wb-num">{{ value }}</span>
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
  { label: '在研课题', value: '86', unit: '项', delta: '+8项', dir: 'up' as const },
  { label: '年度新立项', value: '24', unit: '项', delta: '+4项', dir: 'up' as const },
  { label: '科研经费', value: '1,280', unit: '万元', delta: '+16.4%', dir: 'up' as const },
  { label: 'SCI 论文', value: '68', unit: '篇', delta: '+12篇', dir: 'up' as const },
  { label: '住培学员', value: '152', unit: '人', note: '在培规模' },
  { label: '继教覆盖率', value: '96.2', unit: '%', delta: '+0.8%', dir: 'up' as const },
]

const years5 = ['2020', '2021', '2022', '2023', '2024']

const projectOption = computed<EChartsOption>(() => ({
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
  xAxis: wbCategoryAxis(years5),
  yAxis: [
    wbValueAxis({ name: '项', nameTextStyle: { color: '#94a3b8', fontSize: 11 } }),
    wbValueAxis({
      name: '万元',
      nameTextStyle: { color: '#94a3b8', fontSize: 11 },
      splitLine: { show: false },
    }),
  ],
  series: [
    {
      name: '立项课题数',
      type: 'bar',
      data: [12, 15, 18, 20, 24],
      barWidth: 22,
      itemStyle: { color: wbPalette.primary, borderRadius: [3, 3, 0, 0] },
    },
    {
      name: '科研经费',
      type: 'line',
      yAxisIndex: 1,
      data: [520, 680, 860, 1100, 1280],
      smooth: 0.35,
      symbol: 'circle',
      symbolSize: 5,
      itemStyle: { color: wbPalette.amber },
      lineStyle: { color: wbPalette.amber, width: 2.5 },
    },
  ],
}))

const paperOption = computed<EChartsOption>(() => ({
  animation: false,
  grid: wbGrid({ top: 34 }),
  tooltip: { ...wbTooltip('axis'), axisPointer: { type: 'shadow' } },
  legend: {
    top: 0,
    right: 0,
    itemWidth: 10,
    itemHeight: 10,
    textStyle: { fontSize: 12, color: '#475569' },
  },
  xAxis: wbCategoryAxis(years5),
  yAxis: wbValueAxis({ name: '篇', nameTextStyle: { color: '#94a3b8', fontSize: 11 } }),
  series: [
    { name: 'SCI', type: 'bar', stack: 'total', barWidth: 26, data: [32, 41, 48, 56, 68], itemStyle: { color: wbPalette.primary } },
    { name: '核心期刊', type: 'bar', stack: 'total', data: [86, 92, 98, 104, 112], itemStyle: { color: '#60a5fa' } },
    { name: '普通期刊', type: 'bar', stack: 'total', data: [124, 118, 108, 96, 88], itemStyle: { color: '#bfdbfe', borderRadius: [3, 3, 0, 0] } },
  ],
}))

const cols: WbTableColumn[] = [
  { key: 'name', title: '学科名称' },
  { key: 'leader', title: '学科带头人' },
  { key: 'level', title: '级别', align: 'center' },
  { key: 'projects', title: '在研课题', align: 'right', num: true },
  { key: 'fund', title: '年度经费（万元）', align: 'right' },
  { key: 'year', title: '建设周期', align: 'center' },
  { key: 'stage', title: '阶段', align: 'center' },
]

const rows = [
  { name: '心血管内科', leader: '陈国强', level: '国家级', projects: 12, fund: '286', year: '2022–2025', stage: '中期评估' },
  { name: '骨科', leader: '林志远', level: '省级', projects: 9, fund: '168', year: '2023–2026', stage: '建设中' },
  { name: '呼吸与危重症医学科', leader: '周明华', level: '省级', projects: 8, fund: '152', year: '2023–2026', stage: '建设中' },
  { name: '肿瘤科', leader: '吴雅琴', level: '省级', projects: 7, fund: '138', year: '2024–2027', stage: '启动' },
  { name: '神经内科', leader: '郑文博', level: '市级', projects: 5, fund: '86', year: '2024–2026', stage: '建设中' },
  { name: '重症医学科', leader: '徐立峰', level: '市级', projects: 4, fund: '64', year: '2024–2026', stage: '建设中' },
]
</script>
