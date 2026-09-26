<template>
  <div class="wb-page">
    <WbPageHead title="对比分析" sub="科室横向对比 · 区域对标 · 数据截至 2026-10-28">
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
        <WbTable :columns="table.columns" :rows="table.rows" row-key="dept">
          <template #cell-metric="{ row }">
            <div class="metric-cell">
              <div class="wb-bar">
                <div class="wb-bar-fill" :style="{ width: String(row.bar_pct) + '%' }"></div>
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
          <WbTable :columns="benchCols" :rows="benchmarks" row-key="name">
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
import { ref, computed, onMounted, watch } from 'vue'
import type { EChartsOption } from 'echarts'
import WbPageHead from '../../components/workbench/WbPageHead.vue'
import WbSeg from '../../components/workbench/WbSeg.vue'
import WbChart from '../../components/workbench/WbChart.vue'
import WbTable, { type WbTableColumn } from '../../components/workbench/WbTable.vue'
import { wbPalette, wbTooltip } from '../../components/workbench/chartPresets'
import { getCompare } from '../../api/workbench'
import type { CompareDim, CompareResp, RangeKey, WbTableData } from '../../api/types'

const dim = ref('业务量')
const range = ref('本月')

// 契约 §12.1：WbSeg 选项为中文 UI 标签，入参需映射为 dim 枚举
const DIM_TO_PARAM: Record<string, CompareDim> = {
  业务量: 'scale',
  收入: 'benefit',
  效率: 'efficiency',
  质量: 'quality',
}

const radar = ref<CompareResp['radar'] | null>(null)
const benchmarks = ref<CompareResp['benchmarks']>([])
const table = ref<WbTableData>({ columns: [], rows: [] })

const load = async () => {
  const d = await getCompare(DIM_TO_PARAM[dim.value] ?? 'scale', range.value as RangeKey)
  radar.value = d.radar
  benchmarks.value = d.benchmarks
  table.value = d.table
}
onMounted(load)
watch([dim, range], load)

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
    indicator: radar.value?.indicators ?? [],
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
      data: (radar.value?.series ?? []).map((s, i) => ({
        name: s.name,
        value: s.value,
        itemStyle: { color: i === 0 ? wbPalette.primary : wbPalette.gray },
        lineStyle: i === 0 ? { width: 2 } : { width: 1.5, type: 'dashed' as const },
        areaStyle: { color: i === 0 ? 'rgba(37,99,235,0.12)' : 'rgba(148,163,184,0.08)' },
        symbolSize: i === 0 ? 4 : 3,
      })),
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
