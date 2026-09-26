<template>
  <div class="wb-page">
    <WbPageHead title="对比分析" sub="科室横向对比 · 区域对标 · 数据截至 2024-10-28">
      <WbSeg v-model="dim" :options="['业务量', '收入', '效率', '质量']" />
      <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
    </WbPageHead>

    <!-- 科室横向对比表：当前维度指标内嵌条形 -->
    <div class="wb-panel">
      <div class="wb-panel-head">
        <h3 class="wb-panel-title">科室横向对比</h3>
        <span class="wb-panel-sub">当前维度：{{ dim }} · 按月排序</span>
      </div>
      <div class="wb-panel-body">
        <WbTable :columns="cols" :rows="rows" row-key="dept">
          <template #cell-metric="{ row }">
            <div class="metric-cell">
              <div class="wb-bar">
                <div class="wb-bar-fill" :style="{ width: String(row.pct) + '%' }"></div>
              </div>
              <span class="wb-num metric-val">{{ row.metric }}</span>
            </div>
          </template>
          <template #cell-rank="{ value }">
            <span class="rank-no wb-num" :class="{ 'rank-hi': Number(value) <= 3 }">{{ value }}</span>
          </template>
        </WbTable>
      </div>
    </div>

    <div class="wb-grid wb-grid-2">
      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">与区域同级医院对标</h3>
          <span class="wb-panel-sub">本院 vs 区域均值（指数化）</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="radarOption" />
        </div>
      </div>

      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">核心指标对标明细</h3>
          <span class="wb-panel-sub">差距 = 本院 − 区域均值</span>
        </div>
        <div class="wb-panel-body">
          <WbTable :columns="benchCols" :rows="benchRows" row-key="name">
            <template #cell-gap="{ value }">
              <span
                class="wb-num"
                :class="String(value).startsWith('+') ? 'wb-delta-up' : 'wb-delta-down'"
              >{{ value }}</span>
            </template>
          </WbTable>
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
import WbChart from '../../components/workbench/WbChart.vue'
import WbTable, { type WbTableColumn } from '../../components/workbench/WbTable.vue'
import { wbPalette, wbTooltip } from '../../components/workbench/chartPresets'

const dim = ref('业务量')
const range = ref('本月')

const depts = [
  '心血管内科', '骨科', '呼吸与危重症医学科', '普通外科',
  '神经内科', '肿瘤科', '妇产科', '儿科', '消化内科', '泌尿外科',
]

// 各维度：{ 指标名, 单位, 每科数值, 同比 }
const dimData: Record<string, { name: string; vals: number[]; fmt: (v: number) => string; yoy: string[] }> = {
  '业务量': {
    name: '业务量当量',
    vals: [1860, 1724, 1615, 1480, 1342, 1208, 1126, 1045, 986, 872],
    fmt: (v) => v.toLocaleString(),
    yoy: ['+6.2%', '+5.8%', '+8.7%', '+3.4%', '+4.1%', '+5.9%', '-2.6%', '+1.8%', '+4.1%', '+2.2%'],
  },
  '收入': {
    name: '医疗收入（万元）',
    vals: [2846, 2412, 1986, 1842, 1486, 2186, 1246, 986, 1286, 1046],
    fmt: (v) => v.toLocaleString(),
    yoy: ['+5.2%', '+6.1%', '+4.8%', '+3.6%', '+2.4%', '+7.4%', '-2.6%', '+1.8%', '+3.2%', '+2.8%'],
  },
  '效率': {
    name: '床位周转次数',
    vals: [4.6, 4.2, 3.8, 4.4, 2.6, 2.2, 5.1, 4.8, 3.2, 3.9],
    fmt: (v) => v.toFixed(1),
    yoy: ['+0.4', '+0.3', '+0.5', '+0.2', '-0.1', '+0.2', '+0.6', '+0.4', '+0.3', '+0.2'],
  },
  '质量': {
    name: '质量综合评分',
    vals: [96.4, 94.2, 93.8, 92.6, 91.2, 90.8, 94.6, 93.2, 92.0, 90.4],
    fmt: (v) => v.toFixed(1),
    yoy: ['+1.2', '+0.8', '+1.4', '+0.6', '-0.4', '+0.9', '+1.1', '+0.7', '+0.5', '-0.2'],
  },
}

const cols = computed<WbTableColumn[]>(() => [
  { key: 'rank', title: '排名', align: 'center', width: '56px' },
  { key: 'dept', title: '科室' },
  { key: 'metric', title: dimData[dim.value].name, width: '260px' },
  { key: 'yoy', title: '同比', align: 'right' },
  { key: 'outp', title: '门诊人次', align: 'right', num: true },
  { key: 'inpt', title: '出院人次', align: 'right', num: true },
  { key: 'days', title: '平均住院日', align: 'right', num: true },
  { key: 'sat', title: '满意度', align: 'right', num: true },
])

const rows = computed(() => {
  const d = dimData[dim.value]
  const max = Math.max(...d.vals)
  // 按当前维度重新排名
  const merged = depts.map((dept, i) => ({
    dept,
    metric: d.fmt(d.vals[i]),
    pct: Math.round((d.vals[i] / max) * 100),
    raw: d.vals[i],
    yoy: d.yoy[i],
    outp: [1286, 716, 1158, 542, 968, 412, 486, 792, 1042, 368][i],
    inpt: [680, 612, 538, 499, 436, 401, 389, 356, 320, 298][i],
    days: [9.2, 8.6, 10.4, 7.8, 11.2, 12.6, 5.2, 4.8, 7.2, 8.4][i],
    sat: [96.2, 95.4, 94.8, 94.2, 93.6, 92.8, 96.8, 95.2, 94.6, 93.4][i],
  }))
  merged.sort((a, b) => b.raw - a.raw)
  return merged.map((r, i) => ({ ...r, rank: i + 1 }))
})

const radarOption = computed<EChartsOption>(() => ({
  animation: false,
  tooltip: { ...wbTooltip('item') },
  legend: {
    bottom: 0,
    itemWidth: 14,
    itemHeight: 8,
    textStyle: { fontSize: 12, color: '#475569' },
  },
  radar: {
    indicator: [
      { name: '业务规模', max: 100 },
      { name: '收入能力', max: 100 },
      { name: '运营效率', max: 100 },
      { name: '医疗质量', max: 100 },
      { name: '患者满意', max: 100 },
      { name: '科研教学', max: 100 },
    ],
    radius: '62%',
    center: ['50%', '48%'],
    axisName: { color: '#475569', fontSize: 12 },
    splitLine: { lineStyle: { color: '#e2eaf4' } },
    splitArea: { areaStyle: { color: ['#ffffff', '#f7fafd'] } },
    axisLine: { lineStyle: { color: '#dbe4ef' } },
  },
  series: [
    {
      type: 'radar',
      data: [
        {
          name: '本院',
          value: [86, 82, 78, 88, 90, 74],
          itemStyle: { color: wbPalette.primary },
          lineStyle: { width: 2 },
          areaStyle: { color: 'rgba(37,99,235,0.12)' },
          symbolSize: 4,
        },
        {
          name: '区域同级均值',
          value: [72, 70, 68, 76, 78, 58],
          itemStyle: { color: wbPalette.gray },
          lineStyle: { width: 1.5, type: 'dashed' },
          areaStyle: { color: 'rgba(148,163,184,0.08)' },
          symbolSize: 3,
        },
      ],
    },
  ],
}))

const benchCols: WbTableColumn[] = [
  { key: 'name', title: '指标' },
  { key: 'ours', title: '本院', align: 'right', num: true },
  { key: 'region', title: '区域均值', align: 'right', num: true },
  { key: 'bench', title: '标杆值', align: 'right', num: true },
  { key: 'gap', title: '差距', align: 'right' },
]

const benchRows = [
  { name: '年门急诊量（万人次）', ours: '142.6', region: '118.4', bench: '168.2', gap: '+24.2' },
  { name: '年出院人数（万人）', ours: '4.28', region: '3.62', bench: '5.10', gap: '+0.66' },
  { name: '平均住院日（天）', ours: '6.8', region: '7.9', bench: '6.2', gap: '-1.1' },
  { name: '三四级手术占比（%）', ours: '58.6', region: '48.2', bench: '65.0', gap: '+10.4' },
  { name: '药占比（%）', ours: '28.4', region: '31.6', bench: '25.0', gap: '-3.2' },
  { name: 'CMI 值', ours: '1.08', region: '0.96', bench: '1.22', gap: '+0.12' },
]
</script>

<style scoped>
.metric-cell {
  display: flex;
  align-items: center;
  gap: 12px;
}

.metric-val {
  width: 64px;
  text-align: right;
  font-weight: 600;
  color: var(--wb-navy);
  flex-shrink: 0;
}

.rank-no {
  font-weight: 700;
  color: var(--wb-text-3);
}
.rank-no.rank-hi {
  color: var(--wb-amber);
}
</style>
