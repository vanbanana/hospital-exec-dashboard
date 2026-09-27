<template>
  <div class="wb-page">
    <WbPageHead title="对比分析" :sub="`科室横向对比 · 区域对标 · 数据截至 ${systemDate}`">
      <WbStaleTag v-if="stale" :loading="loading" @retry="reload" />
      <WbSeg v-model="dim" :options="['业务量', '收入', '效率', '质量']" />
      <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
    </WbPageHead>

    <!-- 五态门：data 未落地时面板级 loading/error/empty（§10.1） -->
    <div v-if="data === null" class="wb-panel">
      <div class="wb-panel-body">
        <WbErrorPanel v-if="error" :error="error" :loading="loading" @retry="reload" />
        <WbSkeleton v-else-if="loading" :rows="8" />
        <WbEmpty v-else text="暂无对比数据" />
      </div>
    </div>
    <template v-else>
    <!-- 科室横向对比表：当前维度指标内嵌条形 -->
    <div class="wb-panel">
      <div class="wb-panel-head">
        <h3 class="wb-panel-title">科室横向对比</h3>
        <span class="wb-panel-sub">当前维度：{{ dim }} · 按{{ range }}排序</span>
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
    </template>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import type { EChartsOption } from 'echarts'
import WbPageHead from '../../components/workbench/WbPageHead.vue'
import WbSeg from '../../components/workbench/WbSeg.vue'
import WbChart from '../../components/workbench/WbChart.vue'
import WbTable from '../../components/workbench/WbTable.vue'
import WbSkeleton from '../../components/workbench/WbSkeleton.vue'
import WbErrorPanel from '../../components/workbench/WbErrorPanel.vue'
import WbEmpty from '../../components/workbench/WbEmpty.vue'
import WbStaleTag from '../../components/workbench/WbStaleTag.vue'
import { wbAlpha, wbChart, wbChartFs, wbPalette, wbTooltip } from '../../components/workbench/chartPresets'
import { getCompare } from '../../api/workbench'
import { useAsyncData } from '../../api/useAsyncData'
import { useSystemDate } from '../../api/useSystemDate'
import type { CompareDim, RangeKey, WbTableColumn, WbTableData } from '../../api/types'

const systemDate = useSystemDate()
const dim = ref('业务量')
const range = ref('本月')
// WbSeg 出参为中文标签,映射为契约 range 枚举(§1.4-1,非法值后端回 10001)
const RANGE_PARAM: Record<string, RangeKey> = { 本月: '本月', 本季: '本季', 本年: '本年' }

// 契约 §12.1：WbSeg 选项为中文 UI 标签，入参需映射为 dim 枚举
const DIM_TO_PARAM: Record<string, CompareDim> = {
  业务量: 'scale',
  收入: 'benefit',
  效率: 'efficiency',
  质量: 'quality',
}

// 五态取数经 useAsyncData（frontend-architecture §10.1）：watch(dim/range) 重取走 reload
const { data, loading, error, stale, reload } = useAsyncData(() =>
  getCompare(DIM_TO_PARAM[dim.value] ?? 'scale', RANGE_PARAM[range.value] ?? '本月'),
)
onMounted(reload)
watch([dim, range], reload)

const radar = computed(() => data.value?.radar ?? null)
const benchmarks = computed(() => data.value?.benchmarks ?? [])
const table = computed((): WbTableData => data.value?.table ?? { columns: [], rows: [] })

const radarOption = computed<EChartsOption>(() => ({
  animation: false,
  tooltip: { ...wbTooltip('item') },
  legend: {
    bottom: 0,
    itemWidth: 14,
    itemHeight: 8,
    textStyle: { fontSize: wbChartFs.label, color: wbChart.text },
  },
  radar: {
    indicator: radar.value?.indicators ?? [],
    radius: '62%',
    center: ['50%', '48%'],
    axisName: { color: wbChart.text, fontSize: wbChartFs.label },
    splitLine: { lineStyle: { color: wbChart.grid } },
    splitArea: { areaStyle: { color: [wbChart.white, wbChart.slate50] } },
    axisLine: { lineStyle: { color: wbChart.axisLine } },
  },
  series: [
    {
      type: 'radar',
      data: (radar.value?.series ?? []).map((s, i) => ({
        name: s.name,
        value: s.value,
        itemStyle: { color: i === 0 ? wbPalette.primary : wbPalette.gray },
        lineStyle: i === 0 ? { width: 2 } : { width: 1.5, type: 'dashed' as const },
        areaStyle: { color: i === 0 ? wbAlpha(wbPalette.primary, 0.12) : wbAlpha(wbPalette.gray, 0.08) },
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
  gap: var(--wb-space-3);
}

.metric-val {
  width: 64px;
  text-align: right;
  font-weight: var(--wb-fw-semibold);
  color: var(--wb-navy);
  flex-shrink: 0;
}

.rank-no {
  font-weight: var(--wb-fw-bold);
  color: var(--wb-text-3);
}
.rank-no.rank-hi {
  color: var(--wb-amber);
}
</style>
