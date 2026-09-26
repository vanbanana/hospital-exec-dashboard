<template>
  <div class="wb-page">
    <WbPageHead title="资产与后勤" sub="设备效益 · 物资库存 · 能耗工单 · 数据截至 2024-10-28">
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
                :class="it.level === '高' ? 'is-red' : 'is-amber'"
              >{{ it.level === '高' ? '紧急补货' : '关注' }}</span>
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
        <WbTable :columns="cols" :rows="rows" row-key="name">
          <template #cell-openRate="{ value }">
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
  { label: '固定资产总额', value: '12.6', unit: '亿元', delta: '+3.2%', dir: 'up' as const },
  { label: '大型设备', value: '68', unit: '台', note: '单价 ≥100 万' },
  { label: '设备开机率', value: '94.2', unit: '%', delta: '+1.2%', dir: 'up' as const },
  { label: '库存周转天数', value: '28', unit: '天', delta: '+3天', dir: 'up' as const },
  { label: '本月能耗费用', value: '186', unit: '万元', delta: '-2.4%', dir: 'down' as const },
  { label: '后勤工单', value: '156', unit: '单', note: '完结率 92%' },
]

const months = ['5月', '6月', '7月', '8月', '9月', '10月']

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
  xAxis: wbCategoryAxis(months, { boundaryGap: false }),
  yAxis: wbValueAxis({ name: '万元', nameTextStyle: { color: '#94a3b8', fontSize: 11 } }),
  series: [
    {
      name: '能耗费用',
      type: 'line',
      smooth: 0.35,
      data: [168, 172, 198, 212, 196, 186],
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

const stockAlerts = [
  { name: '一次性使用输液器', days: 46, level: '高' },
  { name: '骨科植入物（接骨板）', days: 42, level: '高' },
  { name: '造影剂（碘海醇）', days: 36, level: '中' },
  { name: '医用缝合线', days: 34, level: '中' },
  { name: '中心静脉导管', days: 31, level: '中' },
  { name: '无菌手术衣', days: 29, level: '中' },
]

const cols: WbTableColumn[] = [
  { key: 'name', title: '设备名称' },
  { key: 'dept', title: '所属科室' },
  { key: 'count', title: '台数', align: 'right', num: true },
  { key: 'openRate', title: '开机率', align: 'right' },
  { key: 'monthly', title: '月均检查/治疗人次', align: 'right', num: true },
  { key: 'income', title: '月收入（万元）', align: 'right', num: true },
  { key: 'roi', title: '效益评价', align: 'center' },
]

const rows = [
  { name: '3.0T 核磁共振', dept: '放射科', count: 2, openRate: '96.8', monthly: '2,860', income: '486', roi: '良好' },
  { name: '256 排 CT', dept: '放射科', count: 2, openRate: '94.6', monthly: '4,120', income: '412', roi: '良好' },
  { name: 'DSA 血管造影机', dept: '介入中心', count: 1, openRate: '88.4', monthly: '380', income: '296', roi: '良好' },
  { name: '直线加速器', dept: '放疗科', count: 1, openRate: '91.2', monthly: '420', income: '268', roi: '良好' },
  { name: 'PET-CT', dept: '核医学科', count: 1, openRate: '72.6', monthly: '186', income: '158', roi: '偏低' },
  { name: '高清电子胃肠镜', dept: '内镜中心', count: 6, openRate: '89.8', monthly: '1,640', income: '226', roi: '一般' },
  { name: '体外冲击波碎石机', dept: '泌尿外科', count: 1, openRate: '64.2', monthly: '92', income: '46', roi: '偏低' },
]
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
