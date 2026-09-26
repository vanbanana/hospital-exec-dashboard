<template>
  <div class="wb-page">
    <WbPageHead title="医疗业务" sub="门急诊 · 住院 · 手术明细分析 · 数据截至 2024-10-28">
      <WbSeg v-model="bizTab" :options="['门急诊', '住院', '手术']" />
      <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
    </WbPageHead>

    <WbStatStrip :items="cur.stats" />

    <div class="wb-grid wb-grid-2-1">
      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">{{ cur.trendTitle }}</h3>
          <span class="wb-panel-sub">近 12 个月</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="trendOption" />
        </div>
      </div>

      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">{{ cur.distTitle }}</h3>
          <span class="wb-panel-sub">{{ cur.distSub }}</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="distOption" />
        </div>
      </div>
    </div>

    <div class="wb-panel">
      <div class="wb-panel-head">
        <h3 class="wb-panel-title">科室明细</h3>
        <span class="wb-panel-sub">{{ bizTab }}口径 · 按业务量排序</span>
      </div>
      <div class="wb-panel-body">
        <WbTable :columns="tableCols" :rows="cur.table" row-key="dept" />
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import type { EChartsOption } from 'echarts'
import WbPageHead from '../../components/workbench/WbPageHead.vue'
import WbSeg from '../../components/workbench/WbSeg.vue'
import WbStatStrip, { type WbStatItem } from '../../components/workbench/WbStatStrip.vue'
import WbChart from '../../components/workbench/WbChart.vue'
import WbTable, { type WbTableColumn } from '../../components/workbench/WbTable.vue'
import {
  wbPalette,
  wbDonutColors,
  wbCategoryAxis,
  wbValueAxis,
  wbTooltip,
  wbGrid,
  wbAreaGradient,
} from '../../components/workbench/chartPresets'

const bizTab = ref('门急诊')
const range = ref('本年')

const months = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月']

interface BizData {
  stats: WbStatItem[]
  trendTitle: string
  trendName: string
  trend: number[]
  distTitle: string
  distSub: string
  distType: 'pie' | 'bar'
  distCats: string[]
  distVals: number[]
  table: Record<string, unknown>[]
}

const bizData: Record<string, BizData> = {
  '门急诊': {
    stats: [
      { label: '门急诊总人次', value: '12,482', delta: '+3.6%', dir: 'up' },
      { label: '普通门诊', value: '8,236', delta: '+2.1%', dir: 'up' },
      { label: '专家门诊', value: '3,114', delta: '+6.4%', dir: 'up' },
      { label: '急诊人次', value: '1,132', delta: '+4.2%', dir: 'up' },
      { label: '次均费用', value: '286', unit: '元', delta: '+1.8%', dir: 'up' },
      { label: '平均候诊', value: '18', unit: '分钟', delta: '-3分钟', dir: 'down' },
    ],
    trendTitle: '门急诊人次趋势',
    trendName: '门急诊人次',
    trend: [5400, 4600, 6800, 7000, 8500, 9000, 10800, 9700, 10500, 12300, 12200, 12000],
    distTitle: '就诊高峰时段分布',
    distSub: '近 30 日分时段人次',
    distType: 'bar',
    distCats: ['7时', '8时', '9时', '10时', '11时', '14时', '15时', '16时', '17时', '19时'],
    distVals: [620, 1480, 1960, 1750, 1180, 1380, 1240, 960, 540, 380],
    table: [
      { dept: '心血管内科', cnt: '1,286', yoy: '+6.2%', share: '10.3%', avg: '352元', drug: '26.1%' },
      { dept: '呼吸与危重症医学科', cnt: '1,158', yoy: '+8.7%', share: '9.3%', avg: '318元', drug: '31.2%' },
      { dept: '消化内科', cnt: '1,042', yoy: '+4.1%', share: '8.4%', avg: '296元', drug: '33.5%' },
      { dept: '神经内科', cnt: '968', yoy: '+3.5%', share: '7.8%', avg: '342元', drug: '29.8%' },
      { dept: '内分泌科', cnt: '826', yoy: '+2.9%', share: '6.6%', avg: '274元', drug: '35.4%' },
      { dept: '儿科', cnt: '792', yoy: '-1.2%', share: '6.3%', avg: '198元', drug: '22.6%' },
      { dept: '骨科', cnt: '716', yoy: '+5.4%', share: '5.7%', avg: '412元', drug: '18.9%' },
      { dept: '皮肤科', cnt: '654', yoy: '+2.2%', share: '5.2%', avg: '186元', drug: '41.3%' },
    ],
  },
  '住院': {
    stats: [
      { label: '在院人数', value: '1,846', note: '当前实时' },
      { label: '本月出院', value: '3,920', delta: '+5.1%', dir: 'up' },
      { label: '床位使用率', value: '92.1', unit: '%', delta: '+1.2%', dir: 'up' },
      { label: '平均住院日', value: '6.8', unit: '天', delta: '-0.3', dir: 'down' },
      { label: '床位周转次数', value: '3.4', delta: '+0.2', dir: 'up' },
      { label: '次均住院费用', value: '9,860', unit: '元', delta: '+2.4%', dir: 'up' },
    ],
    trendTitle: '出院人数趋势',
    trendName: '出院人数',
    trend: [2850, 2400, 3100, 3300, 3500, 3600, 3900, 4100, 3800, 3920, 3700, 3600],
    distTitle: '病区床位占用',
    distSub: '各病区开放床位占用率',
    distType: 'bar',
    distCats: ['内科', '外科', '妇产', '儿科', 'ICU', '肿瘤', '康复'],
    distVals: [94, 96, 82, 78, 98, 91, 68],
    table: [
      { dept: '心血管内科', cnt: '680', yoy: '+4.6%', share: '17.3%', avg: '12,400元', drug: '24.8%' },
      { dept: '骨科', cnt: '612', yoy: '+6.1%', share: '15.6%', avg: '15,860元', drug: '12.4%' },
      { dept: '呼吸与危重症医学科', cnt: '538', yoy: '+7.2%', share: '13.7%', avg: '11,280元', drug: '32.6%' },
      { dept: '普通外科', cnt: '499', yoy: '+3.8%', share: '12.7%', avg: '14,520元', drug: '18.2%' },
      { dept: '神经内科', cnt: '436', yoy: '+2.4%', share: '11.1%', avg: '9,680元', drug: '36.4%' },
      { dept: '肿瘤科', cnt: '401', yoy: '+5.9%', share: '10.2%', avg: '16,240元', drug: '42.8%' },
      { dept: '妇产科', cnt: '389', yoy: '-2.6%', share: '9.9%', avg: '7,460元', drug: '15.6%' },
      { dept: '儿科', cnt: '356', yoy: '+1.8%', share: '9.1%', avg: '4,280元', drug: '26.4%' },
    ],
  },
  '手术': {
    stats: [
      { label: '本月手术台次', value: '1,286', delta: '+4.8%', dir: 'up' },
      { label: '三四级手术占比', value: '58.6', unit: '%', delta: '+2.2%', dir: 'up' },
      { label: '微创手术占比', value: '42.3', unit: '%', delta: '+3.1%', dir: 'up' },
      { label: '择期手术', value: '1,048', delta: '+5.2%', dir: 'up' },
      { label: '急诊手术', value: '238', delta: '+3.1%', dir: 'up' },
      { label: '手术间利用率', value: '86.4', unit: '%', delta: '+1.6%', dir: 'up' },
    ],
    trendTitle: '手术台次趋势',
    trendName: '手术台次',
    trend: [860, 720, 980, 1020, 1080, 1120, 1180, 1210, 1150, 1286, 1200, 1160],
    distTitle: '手术分级构成',
    distSub: '本月手术级别分布',
    distType: 'pie',
    distCats: ['四级手术', '三级手术', '二级手术', '一级手术'],
    distVals: [22, 37, 28, 13],
    table: [
      { dept: '骨科', cnt: '286', yoy: '+6.8%', share: '22.2%', avg: '42分钟', drug: '8.6%' },
      { dept: '普通外科', cnt: '242', yoy: '+5.4%', share: '18.8%', avg: '56分钟', drug: '11.2%' },
      { dept: '妇产科', cnt: '186', yoy: '-1.8%', share: '14.5%', avg: '38分钟', drug: '9.4%' },
      { dept: '神经外科', cnt: '128', yoy: '+7.6%', share: '10.0%', avg: '128分钟', drug: '12.8%' },
      { dept: '泌尿外科', cnt: '116', yoy: '+4.2%', share: '9.0%', avg: '52分钟', drug: '10.6%' },
      { dept: '心胸外科', cnt: '98', yoy: '+9.1%', share: '7.6%', avg: '145分钟', drug: '14.2%' },
      { dept: '耳鼻喉科', cnt: '86', yoy: '+2.4%', share: '6.7%', avg: '34分钟', drug: '7.8%' },
      { dept: '眼科', cnt: '74', yoy: '+1.6%', share: '5.8%', avg: '22分钟', drug: '6.2%' },
    ],
  },
}

const cur = computed(() => bizData[bizTab.value])

const trendOption = computed<EChartsOption>(() => ({
  animation: false,
  grid: wbGrid({ top: 20 }),
  tooltip: wbTooltip('axis'),
  xAxis: wbCategoryAxis(months, { boundaryGap: false }),
  yAxis: wbValueAxis({
    axisLabel: { color: '#64748b', fontSize: 11, formatter: (v: number) => v.toLocaleString() },
  }),
  series: [
    {
      name: cur.value.trendName,
      type: 'line',
      smooth: 0.35,
      data: cur.value.trend,
      symbol: 'circle',
      symbolSize: 5,
      itemStyle: { color: wbPalette.primary, borderColor: '#fff', borderWidth: 1.5 },
      lineStyle: { color: wbPalette.primary, width: 2.5 },
      areaStyle: { color: wbAreaGradient(wbPalette.primary) },
    },
  ],
}))

const distOption = computed<EChartsOption>(() => {
  const d = cur.value
  if (d.distType === 'pie') {
    return {
      animation: false,
      tooltip: { ...wbTooltip('item'), formatter: '{b}：{c}%' },
      legend: {
        bottom: 0,
        itemWidth: 10,
        itemHeight: 10,
        textStyle: { fontSize: 12, color: '#475569' },
      },
      series: [
        {
          type: 'pie',
          radius: ['50%', '72%'],
          center: ['50%', '46%'],
          itemStyle: { borderColor: '#fff', borderWidth: 2 },
          label: {
            show: true,
            formatter: '{d}%',
            fontSize: 11,
            color: '#475569',
          },
          data: d.distCats.map((name, i) => ({
            name,
            value: d.distVals[i],
            itemStyle: { color: wbDonutColors[i] },
          })),
        },
      ],
    }
  }
  return {
    animation: false,
    grid: wbGrid({ top: 16 }),
    tooltip: wbTooltip('axis'),
    xAxis: wbCategoryAxis(d.distCats, { axisLabel: { color: '#64748b', fontSize: 10, margin: 8 } }),
    yAxis: wbValueAxis(),
    series: [
      {
        type: 'bar',
        data: d.distVals,
        barWidth: 16,
        itemStyle: { color: wbPalette.primary, borderRadius: [3, 3, 0, 0] },
      },
    ],
  }
})

const tableCols = computed<WbTableColumn[]>(() => [
  { key: 'dept', title: '科室' },
  { key: 'cnt', title: bizTab.value === '手术' ? '手术台次' : bizTab.value === '住院' ? '出院人次' : '诊疗人次', align: 'right', num: true },
  { key: 'yoy', title: '同比', align: 'right' },
  { key: 'share', title: '占比', align: 'right', num: true },
  { key: 'avg', title: bizTab.value === '手术' ? '平均时长' : '次均费用', align: 'right' },
  { key: 'drug', title: '药占比', align: 'right', num: true },
])
</script>
