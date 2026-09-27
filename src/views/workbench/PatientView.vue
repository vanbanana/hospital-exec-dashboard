<template>
  <div class="wb-page">
    <WbPageHead title="患者服务" :sub="`满意度 · 投诉表扬 · 就诊体验 · 数据截至 ${systemDate}`">
      <WbStaleTag v-if="stale" :loading="loading" @retry="reload" />
      <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
    </WbPageHead>

    <!-- 五态门：data 未落地时面板级 loading/error/empty（§10.1） -->
    <div v-if="data === null" class="wb-panel">
      <div class="wb-panel-body">
        <WbErrorPanel v-if="error" :error="error" :loading="loading" @retry="reload" />
        <WbSkeleton v-else-if="loading" :rows="8" />
        <WbEmpty v-else text="暂无患者服务数据" />
      </div>
    </div>
    <template v-else>
    <WbStatStrip :items="stats" />

    <div class="wb-grid wb-grid-2">
      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">满意度趋势</h3>
          <span class="wb-panel-sub">门诊 vs 住院（{{ satTrend?.unit ?? '%' }}）</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="satOption" />
        </div>
      </div>

      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">挂号渠道分布</h3>
          <span class="wb-panel-sub">各渠道占比</span>
        </div>
        <div class="wb-panel-body channel-body">
          <WbEmpty v-if="!channelData.length" text="暂无渠道数据" />
          <template v-else>
            <WbChart :option="channelOption" class="channel-donut" />
            <ul class="channel-legend">
              <li v-for="(it, i) in channelData" :key="it.name">
                <span class="wb-dot" :style="{ backgroundColor: wbDonutColor(i) }"></span>
                <span class="channel-name">{{ it.name }}</span>
                <span class="channel-pct wb-num">{{ it.value }}{{ channelUnit }}</span>
              </li>
            </ul>
          </template>
        </div>
      </div>
    </div>

    <div class="wb-panel">
      <div class="wb-panel-head">
        <h3 class="wb-panel-title">投诉与表扬记录</h3>
        <span class="wb-panel-sub">共 {{ complaints.rows.length }} 件</span>
      </div>
      <div class="wb-panel-body">
        <WbTable :columns="complaints.columns" :rows="complaints.rows" empty-text="本月无投诉表扬流水">
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
    </template>
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
import { getPatient } from '../../api/workbench'
import { useAsyncData } from '../../api/useAsyncData'
import { useSystemDate } from '../../api/useSystemDate'
import type { WbTableData } from '../../api/types'

// 契约 §9.1 无 range 参数 — WbSeg 仅保留视图交互状态，切换不触发取数
const systemDate = useSystemDate()
const range = ref('本月')

// 五态取数经 useAsyncData（frontend-architecture §10.1）
const { data, loading, error, stale, reload } = useAsyncData(getPatient)
onMounted(reload)

const stats = computed(() => data.value?.stats ?? [])
const satTrend = computed(() => data.value?.satisfaction_trend ?? null)
const channelData = computed(() => data.value?.channel_distribution.list ?? [])
const channelUnit = computed(() => data.value?.channel_distribution.unit ?? '%')
const complaints = computed((): WbTableData => data.value?.complaints_praises ?? { columns: [], rows: [] })

const satOption = computed<EChartsOption>(() => ({
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
  tooltip: { ...wbTooltip('item'), formatter: (params) => { const p = Array.isArray(params) ? params[0] : params; return `${p?.name ?? ''}：${p?.value ?? ''}${channelUnit.value}` } },
  series: [
    {
      type: 'pie',
      radius: ['54%', '78%'],
      center: ['50%', '50%'],
      itemStyle: { borderColor: wbChart.white, borderWidth: 2 },
      label: { show: false },
      data: channelData.value.map((d, i) => ({ ...d, itemStyle: { color: wbDonutColor(i) } })),
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
  gap: var(--wb-space-1);
}

.channel-legend li {
  display: flex;
  align-items: center;
  gap: var(--wb-space-2);
  font-size: var(--wb-fs-md);
  padding: var(--wb-space-1) 0;
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
  font-weight: var(--wb-fw-semibold);
  color: var(--wb-navy);
}
</style>
