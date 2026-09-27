<template>
  <div class="wb-page">
    <WbPageHead title="人力资源" :sub="`人员结构 · 职称梯队 · 科室配置 · 数据截至 ${systemDate}`">
      <WbStaleTag v-if="stale" :loading="loading" @retry="reload" />
      <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
    </WbPageHead>

    <!-- 五态门：data 未落地时面板级 loading/error/empty（§10.1） -->
    <div v-if="data === null" class="wb-panel">
      <div class="wb-panel-body">
        <WbErrorPanel v-if="error" :error="error" :loading="loading" @retry="reload" />
        <WbSkeleton v-else-if="loading" :rows="8" />
        <WbEmpty v-else text="暂无人力资源数据" />
      </div>
    </div>
    <template v-else>
    <WbStatStrip :items="stats" />

    <div class="wb-grid wb-grid-2">
      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">人员构成</h3>
          <span class="wb-panel-sub">按岗位类别</span>
        </div>
        <div class="wb-panel-body structure-body">
          <WbEmpty v-if="!structureData.length" text="暂无人员构成数据" />
          <template v-else>
            <WbChart :option="structureOption" class="structure-donut" />
            <ul class="structure-legend">
              <li v-for="(it, i) in structureData" :key="it.name">
                <span class="wb-dot" :style="{ backgroundColor: wbDonutColor(i) }"></span>
                <span class="structure-name">{{ it.name }}</span>
                <span class="structure-cnt wb-num">{{ it.count }}</span>
                <span class="structure-pct wb-num">{{ it.value }}{{ structureUnit }}</span>
              </li>
            </ul>
          </template>
        </div>
      </div>

      <div class="wb-panel">
        <div class="wb-panel-head">
          <h3 class="wb-panel-title">职称结构</h3>
          <span class="wb-panel-sub">{{ (titles?.categories ?? []).join(' / ') || '职称分段' }}</span>
        </div>
        <div class="wb-panel-body">
          <WbChart :option="titleOption" />
        </div>
      </div>
    </div>

    <div class="wb-panel">
      <div class="wb-panel-head">
        <h3 class="wb-panel-title">重点科室人员配置</h3>
        <span class="wb-panel-sub">编制 vs 在岗 · 缺口预警</span>
      </div>
      <div class="wb-panel-body">
        <WbTable :columns="staffing.columns" :rows="staffing.rows" row-key="dept">
          <template #cell-gap="{ value, row }">
            <!-- 缺口标色由契约 status 枚举驱动(充足/紧张/紧缺),不自造阈值 -->
            <span :class="{ 'gap-warn': row.status !== '充足' }" class="wb-num">{{ value }}</span>
          </template>
          <template #cell-status="{ value }">
            <span class="wb-tag" :class="value === '充足' ? 'is-green' : value === '紧张' ? 'is-amber' : 'is-red'">
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
import { ref, computed, onMounted, watch } from 'vue'
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
  wbDonutColor,
  wbBlueScale,
  wbCategoryAxis,
  wbValueAxis,
  wbTooltip,
  wbGrid,
} from '../../components/workbench/chartPresets'
import { getHr } from '../../api/workbench'
import { useAsyncData } from '../../api/useAsyncData'
import { useSystemDate } from '../../api/useSystemDate'
import type { RangeKey, WbTableData } from '../../api/types'

const systemDate = useSystemDate()
const range = ref('本年')
// WbSeg 出参为中文标签,映射为契约 range 枚举(§1.4-1,非法值后端回 10001)
const RANGE_PARAM: Record<string, RangeKey> = { 本月: '本月', 本季: '本季', 本年: '本年' }

// 五态取数经 useAsyncData（frontend-architecture §10.1）：watch(range) 重取走 reload
const { data, loading, error, stale, reload } = useAsyncData(() =>
  getHr(RANGE_PARAM[range.value] ?? '本年'),
)
onMounted(reload)
watch(range, reload)

const stats = computed(() => data.value?.stats ?? [])
const structureData = computed(() => data.value?.structure.list ?? [])
const structureUnit = computed(() => data.value?.structure.unit ?? '%')
const titles = computed(() => data.value?.titles ?? null)
const staffing = computed((): WbTableData => data.value?.dept_staffing ?? { columns: [], rows: [] })

const structureOption = computed<EChartsOption>(() => ({
  animation: false,
  tooltip: { ...wbTooltip('item'), formatter: (params) => { const p = Array.isArray(params) ? params[0] : params; return `${p?.name ?? ''}：${p?.value ?? ''}${structureUnit.value}（${p?.percent ?? ''}%）` } },
  series: [
    {
      type: 'pie',
      radius: ['56%', '80%'],
      center: ['50%', '50%'],
      itemStyle: { borderColor: wbChart.white, borderWidth: 2 },
      label: { show: false },
      data: structureData.value.map((d, i) => ({
        name: d.name,
        value: d.value,
        itemStyle: { color: wbDonutColor(i) },
      })),
    },
  ],
}))

// 职称层级配色沿用蓝阶深→浅视觉序（正高→初级及以下），契约 titles.series 仅下发 name+values（§7.1）
// 色阶唯一来源 --wb-chart-blue-1..4(design-tokens §6 R5);序列超 4 层时循环取色防越界

const titleOption = computed<EChartsOption>(() => {
  const t = titles.value
  const last = (t?.series.length ?? 0) - 1
  return {
    animation: false,
    grid: wbGrid({ top: 34 }),
    tooltip: { ...wbTooltip('axis'), axisPointer: { type: 'shadow' } },
    legend: {
      top: 0,
      right: 0,
      itemWidth: 10,
      itemHeight: 10,
      textStyle: { fontSize: wbChartFs.label, color: wbChart.text },
    },
    xAxis: wbCategoryAxis(t?.categories ?? []),
    yAxis: wbValueAxis({ name: t?.unit ?? '人', nameTextStyle: { color: wbChart.axis, fontSize: wbChartFs.axis } }),
    series: (t?.series ?? []).map((s, i) => ({
      name: s.name,
      type: 'bar' as const,
      stack: 'total',
      barWidth: i === 0 ? 34 : undefined,
      data: s.values,
      itemStyle: { color: wbBlueScale[i % wbBlueScale.length], borderRadius: i === last ? [3, 3, 0, 0] : undefined },
    })),
  }
})
</script>

<style scoped>
.structure-body {
  flex-direction: row;
  align-items: center;
}

.structure-donut {
  width: 42%;
  min-height: 200px;
}

.structure-legend {
  list-style: none;
  margin: 0;
  padding: 0;
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: var(--wb-space-1);
}

.structure-legend li {
  display: flex;
  align-items: center;
  gap: var(--wb-space-2);
  font-size: var(--wb-fs-md);
  padding: var(--wb-space-2) 0;
  border-bottom: 1px solid var(--wb-hairline);
}
.structure-legend li:last-child {
  border-bottom: none;
}

.structure-name {
  color: var(--wb-text-1);
}

.structure-cnt {
  margin-left: auto;
  font-weight: var(--wb-fw-semibold);
  color: var(--wb-navy);
}

.structure-pct {
  width: 42px;
  text-align: right;
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-3);
}

.gap-warn {
  color: var(--wb-red);
  font-weight: var(--wb-fw-bold);
}
</style>
