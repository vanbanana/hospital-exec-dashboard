<template>
  <div class="wb-page">
    <WbPageHead title="资产与后勤" sub="设备效益 · 物资库存 · 能耗工单 · 数据截至 2026-10-28">
      <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
    </WbPageHead>

    <WbStatStrip :items="stats" />

    <div class="wb-grid wb-grid-2-1">
      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">月度能耗费用</h3>
          <span class="wb-panel-sub">水电气合计（万元）</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="energyOption" />
        </div>
      </div>

      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">物资库存预警</h3>
          <span class="wb-panel-sub">周转天数超阈值项</span>
        </div>
        <div class="wb-panel-body">
          <div class="wb-list stock-list">
            <div v-for="it in stockAlerts" :key="it.name" class="wb-list-row">
              <span class="stock-name">{{ it.name }}</span>
              <span class="stock-days wb-num">{{ it.days }}天</span>
              <span
                class="wb-tag"
                :class="it.level === 'urgent' ? 'is-red' : 'is-amber'"
              >{{ it.level === 'urgent' ? '紧急补货' : '关注' }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="wb-panel">
      <div class="wb-panel-head">
        <h3 class="wb-panel-title">大型设备使用效益</h3>
        <span class="wb-panel-sub">单价 ≥500 万元设备</span>
      </div>
      <div class="wb-panel-body">
        <WbTable :columns="equip.columns" :rows="equip.rows" row-key="name">
          <template #cell-open_rate="{ value }">
            <span class="wb-num" :class="{ 'rate-low': Number(value) < 85 }">{{ value }}%</span>
          </template>
          <template #cell-roi="{ value }">
            <span
              class="wb-tag"
              :class="value === '良好' ? 'is-green' : value === '一般' ? 'is-blue' : 'is-amber'"
            >{{ value }}</span>
          </template>
        </WbTable>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import type { EChartsOption } from 'echarts'
import WbPageHead from '../../components/workbench/WbPageHead.vue'
import WbSeg from '../../components/workbench/WbSeg.vue'
import WbStatStrip from '../../components/workbench/WbStatStrip.vue'
import WbChart from '../../components/workbench/WbChart.vue'
import WbTable from '../../components/workbench/WbTable.vue'
import {
  wbPalette,
  wbCategoryAxis,
  wbValueAxis,
  wbTooltip,
  wbGrid,
} from '../../components/workbench/chartPresets'
import { getAssets } from '../../api/workbench'
import type { AssetsResp, StockAlertItem, WbStatItem } from '../../api/types'

const range = ref('本年')

const stats = ref<WbStatItem[]>([])
const energy = ref<AssetsResp['energy_trend'] | null>(null)
const stockAlerts = ref<StockAlertItem[]>([])
const equip = ref<AssetsResp['large_equipments']>({ columns: [], rows: [] })

// §11.1 暂无 range 参数，切换仍重取一次，端点补 range 时视图零改动
const load = async () => {
  const d = await getAssets()
  stats.value = d.stats
  energy.value = d.energy_trend
  stockAlerts.value = d.stock_alerts
  equip.value = d.large_equipments
}
onMounted(load)
watch(range, load)

const energyOption = computed<EChartsOption>(() => ({
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
  xAxis: wbCategoryAxis(energy.value?.months ?? [], { boundaryGap: false }),
  yAxis: wbValueAxis({
    name: energy.value?.unit ?? '万元',
    nameTextStyle: { color: '#94a3b8', fontSize: 11 },
  }),
  series: [
    {
      name: '能耗费用',
      type: 'line',
      smooth: 0.35,
      data: energy.value?.total ?? [],
      symbol: 'circle',
      symbolSize: 5,
      itemStyle: { color: wbPalette.teal },
      lineStyle: { color: wbPalette.teal, width: 2.5 },
      areaStyle: {
        color: {
          type: 'linear',
          x: 0, y: 0, x2: 0, y2: 1,
          colorStops: [
            { offset: 0, color: 'rgba(13,148,136,0.15)' },
            { offset: 1, color: 'rgba(13,148,136,0.02)' },
          ],
        },
      },
    },
  ],
}))
</script>

<style scoped>
.stock-list {
  height: 100%;
  justify-content: space-evenly;
}

.stock-name {
  flex: 1;
  min-width: 0;
  font-size: 13px;
  color: var(--wb-text-1);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.stock-days {
  font-size: 13px;
  font-weight: 600;
  color: var(--wb-navy);
  width: 52px;
  text-align: right;
  flex-shrink: 0;
}

.rate-low {
  color: var(--wb-amber);
  font-weight: 700;
}
</style>
