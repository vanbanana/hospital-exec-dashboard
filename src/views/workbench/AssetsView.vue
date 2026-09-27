<template>
  <div class="wb-page">
    <WbPageHead title="资产与后勤" :sub="`设备效益 · 物资库存 · 能耗工单 · 数据截至 ${systemDate}`">
      <WbStaleTag v-if="stale" :loading="loading" @retry="reload" />
      <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
    </WbPageHead>

    <!-- 五态门：data 未落地时面板级 loading/error/empty（§10.1） -->
    <div v-if="data === null" class="wb-panel">
      <div class="wb-panel-body">
        <WbErrorPanel v-if="error" :error="error" :loading="loading" @retry="reload" />
        <WbSkeleton v-else-if="loading" :rows="8" />
        <WbEmpty v-else text="暂无资产后勤数据" />
      </div>
    </div>
    <template v-else>
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
            <WbEmpty v-if="!stockAlerts.length" text="暂无库存预警" />
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
        <span class="wb-panel-sub">单价 ≥100 万元设备</span>
      </div>
      <div class="wb-panel-body">
        <WbTable :columns="equip.columns" :rows="equip.rows" row-key="name">
          <template #cell-open_rate="{ value, row }">
            <!-- 低开机率标色由契约 roi 枚举驱动,不自造阈值(§11.1) -->
            <span class="wb-num" :class="{ 'rate-low': row.roi === '偏低' }">{{ value }}%</span>
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
  wbCategoryAxis,
  wbValueAxis,
  wbTooltip,
  wbGrid,
  wbAreaGradient,
} from '../../components/workbench/chartPresets'
import { getAssets } from '../../api/workbench'
import { useAsyncData } from '../../api/useAsyncData'
import { useSystemDate } from '../../api/useSystemDate'
import type { AssetsResp } from '../../api/types'

// 契约 §11.1 无 range 参数 — WbSeg 仅保留视图交互状态，切换不触发取数
const systemDate = useSystemDate()
const range = ref('本年')

// 五态取数经 useAsyncData（frontend-architecture §10.1）
const { data, loading, error, stale, reload } = useAsyncData(getAssets)
onMounted(reload)

const stats = computed(() => data.value?.stats ?? [])
const energy = computed(() => data.value?.energy_trend ?? null)
const stockAlerts = computed(() => data.value?.stock_alerts ?? [])
const equip = computed(
  (): AssetsResp['large_equipments'] => data.value?.large_equipments ?? { columns: [], rows: [] },
)

const energyOption = computed<EChartsOption>(() => ({
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
  xAxis: wbCategoryAxis(energy.value?.months ?? [], { boundaryGap: false }),
  yAxis: wbValueAxis({
    name: energy.value?.unit ?? '万元',
    nameTextStyle: { color: wbChart.axis, fontSize: wbChartFs.axis },
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
      areaStyle: { color: wbAreaGradient(wbPalette.teal) },
    },
    // §11.1 契约下发电/水/气三分量,总量线下的构成明细同图呈现
    {
      name: '电',
      type: 'line',
      smooth: 0.35,
      data: energy.value?.electricity ?? [],
      symbol: 'circle',
      symbolSize: 3,
      itemStyle: { color: wbPalette.primary },
      lineStyle: { color: wbPalette.primary, width: 1.5, opacity: 0.7 },
    },
    {
      name: '水',
      type: 'line',
      smooth: 0.35,
      data: energy.value?.water ?? [],
      symbol: 'circle',
      symbolSize: 3,
      itemStyle: { color: wbPalette.amber },
      lineStyle: { color: wbPalette.amber, width: 1.5, opacity: 0.7 },
    },
    {
      name: '气',
      type: 'line',
      smooth: 0.35,
      data: energy.value?.gas ?? [],
      symbol: 'circle',
      symbolSize: 3,
      itemStyle: { color: wbPalette.green },
      lineStyle: { color: wbPalette.green, width: 1.5, opacity: 0.7 },
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
  font-size: var(--wb-fs-md);
  color: var(--wb-text-1);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.stock-days {
  font-size: var(--wb-fs-md);
  font-weight: var(--wb-fw-semibold);
  color: var(--wb-navy);
  width: 52px;
  text-align: right;
  flex-shrink: 0;
}

.rate-low {
  color: var(--wb-amber);
  font-weight: var(--wb-fw-bold);
}
</style>
