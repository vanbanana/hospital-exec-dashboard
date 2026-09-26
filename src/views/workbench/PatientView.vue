<template>
  <div class="wb-page">
    <WbPageHead title="患者服务" sub="满意度 · 投诉表扬 · 就诊体验 · 数据截至 2026-10-28">
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
        <WbTable :columns="complaints.columns" :rows="complaints.rows">
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
import { ref, computed, onMounted } from 'vue'
import type { EChartsOption } from 'echarts'
import WbPageHead from '../../components/workbench/WbPageHead.vue'
import WbSeg from '../../components/workbench/WbSeg.vue'
import WbStatStrip from '../../components/workbench/WbStatStrip.vue'
import WbChart from '../../components/workbench/WbChart.vue'
import WbTable from '../../components/workbench/WbTable.vue'
import {
  wbPalette,
  wbDonutColors,
  wbCategoryAxis,
  wbValueAxis,
  wbTooltip,
  wbGrid,
} from '../../components/workbench/chartPresets'
import { getPatient } from '../../api/workbench'
import type { NameValue, PatientResp, WbStatItem, WbTableData } from '../../api/types'

// 契约 §9.1 无 range 参数 — WbSeg 仅保留视图交互状态，切换不触发取数
const range = ref('本月')

const stats = ref<WbStatItem[]>([])
const satTrend = ref<PatientResp['satisfaction_trend'] | null>(null)
const channelData = ref<NameValue[]>([])
const complaints = ref<WbTableData>({ columns: [], rows: [] })

const load = async () => {
  const d = await getPatient()
  stats.value = d.stats
  satTrend.value = d.satisfaction_trend
  channelData.value = d.channel_distribution.list
  complaints.value = d.complaints_praises
}
onMounted(load)

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
  xAxis: wbCategoryAxis(satTrend.value?.months ?? [], { boundaryGap: false }),
  yAxis: wbValueAxis({ min: 90, max: 100 }),
  series: [
    {
      name: '门诊满意度',
      type: 'line',
      smooth: 0.35,
      data: satTrend.value?.outpatient ?? [],
      symbol: 'circle',
      symbolSize: 5,
      itemStyle: { color: wbPalette.primary },
      lineStyle: { color: wbPalette.primary, width: 2.5 },
    },
    {
      name: '住院满意度',
      type: 'line',
      smooth: 0.35,
      data: satTrend.value?.inpatient ?? [],
      symbol: 'circle',
      symbolSize: 5,
      itemStyle: { color: wbPalette.teal },
      lineStyle: { color: wbPalette.teal, width: 2.5 },
    },
  ],
}))

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
      data: channelData.value.map((d, i) => ({ ...d, itemStyle: { color: wbDonutColors[i] } })),
    },
  ],
}))
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
