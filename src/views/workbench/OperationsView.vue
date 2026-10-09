<template>
  <div class="wb-page">
    <WbPageHead title="运营管理" :sub="`收支结构 · 费用控制 · 运营效率 · 数据截至 ${systemDate}`">
      <WbStaleTag v-if="stale" :loading="loading" @retry="reload" />
      <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
    </WbPageHead>

    <!-- 五态门：data 未落地时面板级 loading/error/empty（§10.1） -->
    <div v-if="data === null" class="wb-panel">
      <div class="wb-panel-body">
        <WbErrorPanel v-if="error" :error="error" :loading="loading" @retry="reload" />
        <WbSkeleton v-else-if="loading" :rows="8" />
        <WbEmpty v-else text="暂无运营数据" />
      </div>
    </div>
    <template v-else>
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
            <WbEmpty v-if="!costControls.length" text="暂无控费指标" />
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
        <span class="wb-panel-sub">{{ range }} · 按医疗收入排序</span>
      </div>
      <div class="wb-panel-body">
        <WbTable :columns="deptTable.columns" :rows="deptTable.rows" row-key="dept" />
      </div>
    </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import { useDefaultRange } from '../../api/preferences'
import { computed, onMounted, watch } from 'vue'
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
} from '../../components/workbench/chartPresets'
import { getOperations } from '../../api/workbench'
import { useAsyncData } from '../../api/useAsyncData'
import { useSystemDate } from '../../api/useSystemDate'
import type { RangeKey, WbTableData } from '../../api/types'

const systemDate = useSystemDate()
const range = useDefaultRange()
// WbSeg 出参为中文标签,映射为契约 range 枚举(§1.4-1,非法值后端回 10001)
const RANGE_PARAM: Record<string, RangeKey> = { 本月: '本月', 本季: '本季', 本年: '本年' }

// 五态取数经 useAsyncData（frontend-architecture §10.1）：watch(range) 重取走 reload
const { data, loading, error, stale, reload } = useAsyncData(() =>
  getOperations(RANGE_PARAM[range.value] ?? '本年'),
)
onMounted(reload)
watch(range, reload)

const stats = computed(() => data.value?.stats ?? [])
const revenueTrend = computed(() => data.value?.revenue_trend ?? null)
const costControls = computed(() => data.value?.cost_controls ?? [])
const deptTable = computed((): WbTableData => data.value?.dept_table ?? { columns: [], rows: [] })

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
      textStyle: { fontSize: wbChartFs.label, color: wbChart.text },
    },
    xAxis: wbCategoryAxis(t?.months ?? []),
    yAxis: [
      wbValueAxis({ name: '万元', nameTextStyle: { color: wbChart.axis, fontSize: wbChartFs.axis } }),
      wbValueAxis({
        name: '%',
        nameTextStyle: { color: wbChart.axis, fontSize: wbChartFs.axis },
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
      // §6.1 revenue_trend.cost 契约序列:与 income 同轴呈现收支剪刀差
      {
        name: '医疗成本',
        type: 'line',
        data: t?.cost ?? [],
        smooth: 0.35,
        symbol: 'circle',
        symbolSize: 4,
        itemStyle: { color: wbPalette.teal },
        lineStyle: { color: wbPalette.teal, width: 2, type: 'dashed' },
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
  gap: var(--wb-space-1);
}

.ctrl-row {
  display: flex;
  flex-direction: column;
  gap: var(--wb-space-1);
}

.ctrl-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
}

.ctrl-name {
  font-size: var(--wb-fs-md);
  color: var(--wb-text-1);
  font-weight: var(--wb-fw-medium);
}

.ctrl-nums b {
  font-size: var(--wb-fs-md);
  font-weight: var(--wb-fw-bold);
  color: var(--wb-navy);
}

.ctrl-limit {
  font-style: normal;
  font-size: var(--wb-fs-xs);
  color: var(--wb-text-4);
  margin-left: var(--wb-space-1);
}

.ctrl-track {
  position: relative;
  height: 8px;
  background: var(--wb-bar-track);
  border-radius: var(--wb-radius-tag);
  /* 超标项 fill/mark 可 >100%:裁剪到轨道边界,防冲出卡片(超标语义已由红色表达) */
  overflow: hidden;
}

.ctrl-fill {
  height: 100%;
  border-radius: var(--wb-radius-tag);
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
  border-radius: var(--wb-radius-sm);
  opacity: var(--wb-opacity-muted);
}
</style>
