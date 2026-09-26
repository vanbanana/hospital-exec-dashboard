<template>
  <div class="wb-page">
    <WbPageHead title="人力资源" sub="人员结构 · 职称梯队 · 科室配置 · 数据截至 2024-10-28">
      <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
    </WbPageHead>

    <WbStatStrip :items="stats" />

    <div class="wb-grid wb-grid-2">
      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">人员构成</h3>
          <span class="wb-panel-sub">按岗位类别</span>
        </div>
        <div class="wb-panel-body structure-body">
          <WbChart :option="structureOption" class="structure-donut" />
          <ul class="structure-legend">
            <li v-for="(it, i) in structureData" :key="it.name">
              <span class="wb-dot" :style="{ backgroundColor: wbDonutColors[i] }"></span>
              <span class="structure-name">{{ it.name }}</span>
              <span class="structure-cnt wb-num">{{ it.count }}</span>
              <span class="structure-pct wb-num">{{ it.value }}%</span>
            </li>
          </ul>
        </div>
      </div>

      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">职称结构</h3>
          <span class="wb-panel-sub">医师 / 护理 / 医技分段</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="titleOption" />
        </div>
      </div>
    </div>

    <div class="wb-panel">
      <div class="wb-panel-head">
        <h3 class="wb-panel-title">重点科室人员配置</h3>
        <span class="wb-panel-sub">编制 vs 在岗 · 缺口预警</span>
      </div>
      <div class="wb-panel-body">
        <WbTable :columns="cols" :rows="rows" row-key="dept">
          <template #cell-gap="{ value }">
            <span :class="{ 'gap-warn': Number(value) > 5 }" class="wb-num">{{ value }}</span>
          </template>
          <template #cell-status="{ value }">
            <span class="wb-tag" :class="value === '充足' ? 'is-green' : value === '紧张' ? 'is-amber' : 'is-red'">
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
  wbDonutColors,
  wbCategoryAxis,
  wbValueAxis,
  wbTooltip,
  wbGrid,
} from '../../components/workbench/chartPresets'

const range = ref('本年')

const stats = [
  { label: '在岗职工', value: '2,368', delta: '+0.4%', dir: 'up' as const },
  { label: '执业医师', value: '812', delta: '+1.8%', dir: 'up' as const },
  { label: '注册护士', value: '1,046', delta: '+2.2%', dir: 'up' as const },
  { label: '医护比', value: '1 : 1.29', note: '目标 ≥1:1.25' },
  { label: '高级职称占比', value: '18.2', unit: '%', delta: '+0.6%', dir: 'up' as const },
  { label: '人员经费占比', value: '32.5', unit: '%', delta: '+1.1%', dir: 'up' as const },
]

const structureData = [
  { name: '护理人员', value: 44, count: 1046 },
  { name: '执业医师', value: 34, count: 812 },
  { name: '行政后勤', value: 13, count: 308 },
  { name: '医技人员', value: 9, count: 202 },
]

const structureOption = computed<EChartsOption>(() => ({
  animation: false,
  tooltip: { ...wbTooltip('item'), formatter: '{b}：{c}%（{d}%）' },
  series: [
    {
      type: 'pie',
      radius: ['56%', '80%'],
      center: ['50%', '50%'],
      itemStyle: { borderColor: '#fff', borderWidth: 2 },
      label: { show: false },
      data: structureData.map((d, i) => ({
        name: d.name,
        value: d.value,
        itemStyle: { color: wbDonutColors[i] },
      })),
    },
  ],
}))

const titleOption = computed<EChartsOption>(() => ({
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
  xAxis: wbCategoryAxis(['医师', '护理', '医技', '行政后勤']),
  yAxis: wbValueAxis({ name: '人数', nameTextStyle: { color: '#94a3b8', fontSize: 11 } }),
  series: [
    { name: '正高', type: 'bar', stack: 'total', barWidth: 34, data: [42, 6, 4, 0], itemStyle: { color: '#1d4ed8' } },
    { name: '副高', type: 'bar', stack: 'total', data: [128, 68, 22, 14], itemStyle: { color: '#2563eb' } },
    { name: '中级', type: 'bar', stack: 'total', data: [312, 368, 84, 62], itemStyle: { color: '#60a5fa' } },
    { name: '初级及以下', type: 'bar', stack: 'total', data: [330, 604, 92, 232], itemStyle: { color: '#bfdbfe', borderRadius: [3, 3, 0, 0] } },
  ],
}))

const cols: WbTableColumn[] = [
  { key: 'dept', title: '科室' },
  { key: 'quota', title: '编制数', align: 'right', num: true },
  { key: 'actual', title: '在岗数', align: 'right', num: true },
  { key: 'doctor', title: '医师', align: 'right', num: true },
  { key: 'nurse', title: '护士', align: 'right', num: true },
  { key: 'ratio', title: '医护比', align: 'center' },
  { key: 'gap', title: '缺口', align: 'right' },
  { key: 'status', title: '配置状态', align: 'center' },
]

const rows = [
  { dept: '重症医学科', quota: 68, actual: 58, doctor: 16, nurse: 42, ratio: '1:2.63', gap: 10, status: '紧缺' },
  { dept: '急诊科', quota: 86, actual: 78, doctor: 24, nurse: 54, ratio: '1:2.25', gap: 8, status: '紧张' },
  { dept: '儿科', quota: 64, actual: 58, doctor: 20, nurse: 38, ratio: '1:1.90', gap: 6, status: '紧张' },
  { dept: '心血管内科', quota: 92, actual: 89, doctor: 32, nurse: 57, ratio: '1:1.78', gap: 3, status: '充足' },
  { dept: '骨科', quota: 84, actual: 81, doctor: 28, nurse: 53, ratio: '1:1.89', gap: 3, status: '充足' },
  { dept: '呼吸与危重症医学科', quota: 76, actual: 72, doctor: 24, nurse: 48, ratio: '1:2.00', gap: 4, status: '充足' },
  { dept: '麻醉科', quota: 42, actual: 36, doctor: 30, nurse: 6, ratio: '—', gap: 6, status: '紧张' },
  { dept: '康复医学科', quota: 38, actual: 34, doctor: 10, nurse: 24, ratio: '1:2.40', gap: 4, status: '充足' },
]
</script>

<style scoped>
.structure-body {
  flex-direction: row;
  align-items: center;
}

.structure-donut {
  width: 42%;
  min-height: 200px;
}

.structure-legend {
  list-style: none;
  margin: 0;
  padding: 0;
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.structure-legend li {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  padding: 7px 0;
  border-bottom: 1px solid var(--wb-hairline);
}
.structure-legend li:last-child {
  border-bottom: none;
}

.structure-name {
  color: var(--wb-text-1);
}

.structure-cnt {
  margin-left: auto;
  font-weight: 600;
  color: var(--wb-navy);
}

.structure-pct {
  width: 42px;
  text-align: right;
  font-size: 12px;
  color: var(--wb-text-3);
}

.gap-warn {
  color: var(--wb-red);
  font-weight: 700;
}
</style>
