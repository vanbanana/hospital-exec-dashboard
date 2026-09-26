<template>
  <div class="wb-page">
    <WbPageHead title="运营管理" sub="收支结构 · 费用控制 · 运营效率 · 数据截至 2024-10-28">
      <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
    </WbPageHead>

    <WbStatStrip :items="stats" />

    <div class="wb-grid wb-grid-2-1">
      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">月度收支趋势</h3>
          <span class="wb-panel-sub">收入（柱 · 万元） × 结余率（线 · %）</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="revOption" />
        </div>
      </div>

      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">费用控制监测</h3>
          <span class="wb-panel-sub">对标红线值</span>
        </div>
        <div class="wb-panel-body">
          <div class="ctrl-list">
            <div v-for="it in costControls" :key="it.name" class="ctrl-row">
              <div class="ctrl-head">
                <span class="ctrl-name">{{ it.name }}</span>
                <span class="ctrl-nums">
                  <b class="wb-num">{{ it.value }}</b>
                  <i class="ctrl-limit">红线 {{ it.limit }}</i>
                </span>
              </div>
              <div class="ctrl-track">
                <div
                  class="ctrl-fill"
                  :class="it.over ? 'is-over' : 'is-ok'"
                  :style="{ width: it.pct + '%' }"
                ></div>
                <span class="ctrl-mark" :style="{ left: it.markPct + '%' }"></span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="wb-panel">
      <div class="wb-panel-head">
        <h3 class="wb-panel-title">科室运营指标</h3>
        <span class="wb-panel-sub">本月 · 按医疗收入排序</span>
      </div>
      <div class="wb-panel-body">
        <WbTable :columns="cols" :rows="rows" row-key="dept">
          <template #cell-status="{ value }">
            <span class="wb-tag" :class="value === '达标' ? 'is-green' : value === '关注' ? 'is-amber' : 'is-red'">
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
  wbCategoryAxis,
  wbValueAxis,
  wbTooltip,
  wbGrid,
} from '../../components/workbench/chartPresets'

const range = ref('本年')

const stats = [
  { label: '医疗总收入', value: '23,560', unit: '万元', delta: '+2.9%', dir: 'up' as const },
  { label: '门诊收入', value: '8,940', unit: '万元', delta: '+3.4%', dir: 'up' as const },
  { label: '住院收入', value: '13,680', unit: '万元', delta: '+2.6%', dir: 'up' as const },
  { label: '收支结余率', value: '4.2', unit: '%', delta: '-0.4%', dir: 'down' as const },
  { label: '次均门诊费用', value: '286', unit: '元', delta: '+1.8%', dir: 'up' as const },
  { label: '次均住院费用', value: '9,860', unit: '元', delta: '+2.4%', dir: 'up' as const },
]

const months = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月']

const revOption = computed<EChartsOption>(() => ({
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
  xAxis: wbCategoryAxis(months),
  yAxis: [
    wbValueAxis({ name: '万元', nameTextStyle: { color: '#94a3b8', fontSize: 11 } }),
    wbValueAxis({
      name: '%',
      nameTextStyle: { color: '#94a3b8', fontSize: 11 },
      splitLine: { show: false },
      min: 0,
      max: 10,
    }),
  ],
  series: [
    {
      name: '医疗收入',
      type: 'bar',
      data: [1420, 1280, 1720, 1850, 1980, 2060, 2210, 2150, 2080, 2356, 2260, 2180],
      barWidth: 14,
      itemStyle: { color: wbPalette.primary, borderRadius: [3, 3, 0, 0] },
    },
    {
      name: '结余率',
      type: 'line',
      yAxisIndex: 1,
      data: [3.2, 2.8, 4.1, 4.6, 4.9, 5.2, 5.6, 5.1, 4.6, 4.2, 4.4, 4.6],
      smooth: 0.35,
      symbol: 'circle',
      symbolSize: 5,
      itemStyle: { color: wbPalette.amber },
      lineStyle: { color: wbPalette.amber, width: 2.5 },
    },
  ],
}))

const costControls = [
  { name: '药占比', value: '28.4%', limit: '30%', pct: 71, markPct: 75, over: false },
  { name: '耗占比', value: '17.9%', limit: '20%', pct: 67, markPct: 75, over: false },
  { name: '次均费用增幅', value: '2.4%', limit: '8%', pct: 30, markPct: 80, over: false },
  { name: '百元医疗收入耗材', value: '12.6元', limit: '15元', pct: 63, markPct: 75, over: false },
  { name: '住院抗菌药物强度', value: '38.2', limit: '40', pct: 76, markPct: 80, over: false },
  { name: '门诊输液率', value: '9.8%', limit: '8%', pct: 86, markPct: 70, over: true },
]

const cols: WbTableColumn[] = [
  { key: 'dept', title: '科室' },
  { key: 'rev', title: '医疗收入（万元）', align: 'right', num: true },
  { key: 'mom', title: '环比', align: 'right' },
  { key: 'drug', title: '药占比', align: 'right', num: true },
  { key: 'material', title: '耗占比', align: 'right', num: true },
  { key: 'avgFee', title: '次均费用', align: 'right' },
  { key: 'balance', title: '结余率', align: 'right', num: true },
  { key: 'status', title: '费用控制', align: 'center' },
]

const rows = [
  { dept: '心血管内科', rev: '2,846', mom: '+5.2%', drug: '24.8%', material: '21.4%', avgFee: '12,400元', balance: '6.8%', status: '达标' },
  { dept: '骨科', rev: '2,412', mom: '+6.1%', drug: '12.4%', material: '38.6%', avgFee: '15,860元', balance: '5.9%', status: '关注' },
  { dept: '肿瘤科', rev: '2,186', mom: '+7.4%', drug: '42.8%', material: '12.2%', avgFee: '16,240元', balance: '2.1%', status: '超标' },
  { dept: '呼吸与危重症医学科', rev: '1,986', mom: '+4.8%', drug: '32.6%', material: '14.8%', avgFee: '11,280元', balance: '4.6%', status: '关注' },
  { dept: '普通外科', rev: '1,842', mom: '+3.6%', drug: '18.2%', material: '26.4%', avgFee: '14,520元', balance: '6.2%', status: '达标' },
  { dept: '神经内科', rev: '1,486', mom: '+2.4%', drug: '36.4%', material: '8.6%', avgFee: '9,680元', balance: '3.8%', status: '关注' },
  { dept: '妇产科', rev: '1,246', mom: '-2.6%', drug: '15.6%', material: '18.2%', avgFee: '7,460元', balance: '5.4%', status: '达标' },
  { dept: '儿科', rev: '986', mom: '+1.8%', drug: '26.4%', material: '6.8%', avgFee: '4,280元', balance: '3.2%', status: '达标' },
]
</script>

<style scoped>
.ctrl-list {
  display: flex;
  flex-direction: column;
  justify-content: space-evenly;
  height: 100%;
  gap: 6px;
}

.ctrl-row {
  display: flex;
  flex-direction: column;
  gap: 5px;
}

.ctrl-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
}

.ctrl-name {
  font-size: 13px;
  color: var(--wb-text-1);
  font-weight: 500;
}

.ctrl-nums b {
  font-size: 14px;
  font-weight: 700;
  color: var(--wb-navy);
}

.ctrl-limit {
  font-style: normal;
  font-size: 11px;
  color: var(--wb-text-4);
  margin-left: 6px;
}

.ctrl-track {
  position: relative;
  height: 8px;
  background: #f1f5f9;
  border-radius: 4px;
}

.ctrl-fill {
  height: 100%;
  border-radius: 4px;
}
.ctrl-fill.is-ok { background: var(--wb-accent); }
.ctrl-fill.is-over { background: var(--wb-red); }

/* 红线刻度标记 */
.ctrl-mark {
  position: absolute;
  top: -2px;
  bottom: -2px;
  width: 2px;
  background: var(--wb-red);
  border-radius: 1px;
  opacity: 0.6;
}
</style>
