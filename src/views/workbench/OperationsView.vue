<template>
  <div class="wb-page">
    <WbPageHead title="运营管理" sub="收支结构 · 费用控制 · 运营效率 · 数据截至 2026-10-28">
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
                  <i class="ctrl-limit">红线 {{ it.target }}</i>
                </span>
              </div>
              <div class="ctrl-track">
                <div
                  class="ctrl-fill"
                  :class="it.status === '超标' ? 'is-over' : 'is-ok'"
                  :style="{ width: it.pct + '%' }"
                ></div>
                <span class="ctrl-mark" :style="{ left: it.mark_pct + '%' }"></span>
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
        <WbTable :columns="deptTable.columns" :rows="deptTable.rows" row-key="dept" />
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
import { getOperations } from '../../api/workbench'
import type { CostControlItem, OperationsResp, RangeKey, WbStatItem, WbTableData } from '../../api/types'

const range = ref('本年')

const stats = ref<WbStatItem[]>([])
const revenueTrend = ref<OperationsResp['revenue_trend'] | null>(null)
const costControls = ref<CostControlItem[]>([])
const deptTable = ref<WbTableData>({ columns: [], rows: [] })

const load = async () => {
  const d = await getOperations(range.value as RangeKey)
  stats.value = d.stats
  revenueTrend.value = d.revenue_trend
  costControls.value = d.cost_controls
  deptTable.value = d.dept_table
}
onMounted(load)
watch(range, load)

const revOption = computed<EChartsOption>(() => {
  const t = revenueTrend.value
  // 契约 §6.1 注1：结余率序列不下发，前端按 balance / income × 100% 推导
  const rate = (t?.income ?? []).map((v, i) =>
    v ? +(((t?.balance[i] ?? 0) / v) * 100).toFixed(1) : 0,
  )
  return {
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
    xAxis: wbCategoryAxis(t?.months ?? []),
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
        data: t?.income ?? [],
        barWidth: 14,
        itemStyle: { color: wbPalette.primary, borderRadius: [3, 3, 0, 0] },
      },
      {
        name: '结余率',
        type: 'line',
        yAxisIndex: 1,
        data: rate,
        smooth: 0.35,
        symbol: 'circle',
        symbolSize: 5,
        itemStyle: { color: wbPalette.amber },
        lineStyle: { color: wbPalette.amber, width: 2.5 },
      },
    ],
  }
})
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
