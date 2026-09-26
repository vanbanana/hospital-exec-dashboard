<template>
  <div class="wb-page">
    <WbPageHead title="专题分析" sub="DRG 付费 · 医保基金 · 国考指标 · 门诊统筹">
      <WbSeg v-model="range" :options="['本月', '本季', '本年']" />
    </WbPageHead>

    <div class="topics-layout">
      <!-- 页内专题子导航 -->
      <div class="wb-panel topics-nav-panel">
        <div class="wb-subnav">
          <div
            v-for="t in topicList"
            :key="t.key"
            class="wb-subnav-item"
            :class="{ active: topic === t.key }"
            @click="topic = t.key"
          >
            <component :is="t.icon" :size="15" :stroke-width="1.9" />
            <span>{{ t.name }}</span>
          </div>
        </div>
      </div>

      <!-- 专题内容 -->
      <div class="topics-content">
        <WbStatStrip :items="cur.stats" />

        <div v-if="cur.chart" class="wb-panel">
          <div class="wb-panel-head">
            <h3 class="wb-panel-title">{{ cur.chartTitle }}</h3>
            <span class="wb-panel-sub">{{ cur.chartSub }}</span>
          </div>
          <div class="wb-panel-body topics-chart-body">
            <WbChart :option="cur.chart" />
          </div>
        </div>

        <div class="wb-panel">
          <div class="wb-panel-head">
            <h3 class="wb-panel-title">{{ cur.tableTitle }}</h3>
            <span class="wb-panel-sub">{{ cur.tableSub }}</span>
          </div>
          <div class="wb-panel-body">
            <WbTable :columns="cur.cols" :rows="cur.rows" :row-key="cur.rowKey" />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import type { EChartsOption } from 'echarts'
import {
  FolderKanban,
  Landmark,
  Award,
  Store,
} from 'lucide-vue-next'
import WbPageHead from '../../components/workbench/WbPageHead.vue'
import WbSeg from '../../components/workbench/WbSeg.vue'
import WbStatStrip, { type WbStatItem } from '../../components/workbench/WbStatStrip.vue'
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
const topic = ref('drg')

const topicList = [
  { key: 'drg', name: 'DRG 付费分析', icon: FolderKanban },
  { key: 'insurance', name: '医保基金运行', icon: Landmark },
  { key: 'exam', name: '三级公立医院国考', icon: Award },
  { key: 'outpFund', name: '门诊统筹', icon: Store },
]

const months = ['5月', '6月', '7月', '8月', '9月', '10月']

const lineChart = (name: string, data: number[]): EChartsOption => ({
  animation: false,
  grid: wbGrid({ top: 20 }),
  tooltip: wbTooltip('axis'),
  xAxis: wbCategoryAxis(months, { boundaryGap: false }),
  yAxis: wbValueAxis(),
  series: [
    {
      name,
      type: 'line',
      smooth: 0.35,
      data,
      symbol: 'circle',
      symbolSize: 5,
      itemStyle: { color: wbPalette.primary, borderColor: '#fff', borderWidth: 1.5 },
      lineStyle: { color: wbPalette.primary, width: 2.5 },
      areaStyle: {
        color: {
          type: 'linear', x: 0, y: 0, x2: 0, y2: 1,
          colorStops: [
            { offset: 0, color: 'rgba(37,99,235,0.12)' },
            { offset: 1, color: 'rgba(37,99,235,0.02)' },
          ],
        },
      },
    },
  ],
})

const barChart = (cats: string[], data: number[]): EChartsOption => ({
  animation: false,
  grid: wbGrid({ top: 20 }),
  tooltip: wbTooltip('axis'),
  xAxis: wbCategoryAxis(cats),
  yAxis: wbValueAxis(),
  series: [
    {
      type: 'bar',
      data,
      barWidth: 18,
      itemStyle: { color: wbPalette.primary, borderRadius: [3, 3, 0, 0] },
    },
  ],
})

interface TopicDef {
  stats: WbStatItem[]
  chartTitle: string
  chartSub: string
  chart: EChartsOption | null
  tableTitle: string
  tableSub: string
  rowKey: string
  cols: WbTableColumn[]
  rows: Record<string, unknown>[]
}

const topics: Record<string, TopicDef> = {
  drg: {
    stats: [
      { label: 'CMI 值', value: '1.08', delta: '+0.04', dir: 'up' },
      { label: '入组率', value: '98.5', unit: '%', delta: '+0.6%', dir: 'up' },
      { label: '费用消耗指数', value: '0.92', delta: '-0.03', dir: 'down' },
      { label: '时间消耗指数', value: '0.95', delta: '-0.02', dir: 'down' },
      { label: 'RW≥2 占比', value: '21.4', unit: '%', delta: '+1.8%', dir: 'up' },
      { label: '低风险组死亡率', value: '0.02', unit: '%', delta: '持平', dir: 'flat' },
    ],
    chartTitle: '病组权重（RW）分布',
    chartSub: '本月出院病例按 RW 分段',
    chart: barChart(['<0.5', '0.5-1', '1-2', '2-5', '5-10', '≥10'], [420, 1620, 1480, 320, 62, 18]),
    tableTitle: '科室 DRG 核心指标',
    tableSub: '按 CMI 排序',
    rowKey: 'dept',
    cols: [
      { key: 'dept', title: '科室' },
      { key: 'cmi', title: 'CMI', align: 'right', num: true },
      { key: 'cases', title: '入组病例', align: 'right', num: true },
      { key: 'costIdx', title: '费用消耗指数', align: 'right', num: true },
      { key: 'timeIdx', title: '时间消耗指数', align: 'right', num: true },
      { key: 'rw2', title: 'RW≥2 占比', align: 'right', num: true },
      { key: 'profit', title: 'DRG 结余（万元）', align: 'right', num: true },
    ],
    rows: [
      { dept: '心血管内科', cmi: '1.42', cases: '658', costIdx: '0.96', timeIdx: '0.98', rw2: '28.6%', profit: '+86.4' },
      { dept: '骨科', cmi: '1.36', cases: '596', costIdx: '0.88', timeIdx: '0.94', rw2: '32.4%', profit: '+124.6' },
      { dept: '神经外科', cmi: '1.68', cases: '142', costIdx: '1.02', timeIdx: '1.06', rw2: '46.8%', profit: '-12.8' },
      { dept: '普通外科', cmi: '1.18', cases: '486', costIdx: '0.86', timeIdx: '0.92', rw2: '24.2%', profit: '+98.2' },
      { dept: '肿瘤科', cmi: '1.24', cases: '392', costIdx: '1.08', timeIdx: '1.02', rw2: '26.4%', profit: '-34.6' },
      { dept: '呼吸与危重症医学科', cmi: '1.12', cases: '524', costIdx: '0.94', timeIdx: '0.96', rw2: '22.8%', profit: '+42.8' },
      { dept: '神经内科', cmi: '0.94', cases: '428', costIdx: '0.90', timeIdx: '0.98', rw2: '12.6%', profit: '+38.2' },
      { dept: '儿科', cmi: '0.68', cases: '342', costIdx: '0.84', timeIdx: '0.88', rw2: '4.2%', profit: '+28.4' },
    ],
  },
  insurance: {
    stats: [
      { label: '医保结算人次', value: '8,462', delta: '+4.2%', dir: 'up' },
      { label: '医保基金支付', value: '9,860', unit: '万元', delta: '+3.8%', dir: 'up' },
      { label: '基金结余率', value: '6.8', unit: '%', delta: '+0.4%', dir: 'up' },
      { label: '拒付/扣款率', value: '0.8', unit: '%', delta: '-0.2%', dir: 'down' },
      { label: '次均医保费用', value: '8,640', unit: '元', delta: '+1.6%', dir: 'up' },
      { label: '异地就医结算', value: '486', unit: '人次', delta: '+12.4%', dir: 'up' },
    ],
    chartTitle: '医保基金月度支付',
    chartSub: '近 6 个月（万元）',
    chart: lineChart('基金支付', [886, 920, 946, 968, 942, 986]),
    tableTitle: '分险种结算情况',
    tableSub: '本月',
    rowKey: 'type',
    cols: [
      { key: 'type', title: '险种' },
      { key: 'cases', title: '结算人次', align: 'right', num: true },
      { key: 'fund', title: '基金支付（万元）', align: 'right', num: true },
      { key: 'self', title: '个人自付（万元）', align: 'right', num: true },
      { key: 'ratio', title: '报销比例', align: 'right', num: true },
      { key: 'status', title: '运行状态', align: 'center' },
    ],
    rows: [
      { type: '职工医保', cases: '4,286', fund: '5,680', self: '1,420', ratio: '80.0%', status: '平稳' },
      { type: '居民医保', cases: '3,246', fund: '3,420', self: '1,486', ratio: '69.7%', status: '平稳' },
      { type: '生育保险', cases: '486', fund: '420', self: '128', ratio: '76.6%', status: '平稳' },
      { type: '大病保险', cases: '286', fund: '286', self: '86', ratio: '76.9%', status: '关注' },
      { type: '医疗救助', cases: '158', fund: '54', self: '12', ratio: '81.8%', status: '平稳' },
    ],
  },
  exam: {
    stats: [
      { label: '国考预估得分', value: '786', unit: '分', delta: '+18分', dir: 'up' },
      { label: '指标达标率', value: '82.4', unit: '%', delta: '+3.6%', dir: 'up' },
      { label: '医疗质量得分率', value: '86.2', unit: '%', delta: '+2.4%', dir: 'up' },
      { label: '运营效率得分率', value: '78.6', unit: '%', delta: '+4.2%', dir: 'up' },
      { label: '持续发展得分率', value: '74.8', unit: '%', delta: '+1.8%', dir: 'up' },
      { label: '满意度得分率', value: '91.2', unit: '%', delta: '+0.6%', dir: 'up' },
    ],
    chartTitle: '近 6 个月指标达标率',
    chartSub: '已监测指标达标占比',
    chart: lineChart('达标率', [74.2, 76.8, 78.4, 79.6, 81.2, 82.4]),
    tableTitle: '关键国考指标',
    tableSub: '得分率偏低的重点项',
    rowKey: 'name',
    cols: [
      { key: 'name', title: '指标名称' },
      { key: 'full', title: '分值', align: 'right', num: true },
      { key: 'score', title: '得分率', align: 'right', num: true },
      { key: 'trend', title: '趋势', align: 'center' },
      { key: 'owner', title: '责任部门' },
    ],
    rows: [
      { name: '出院患者四级手术比例', full: 40, score: '68%', trend: '↑', owner: '医务部' },
      { name: '每床日收入（剔除药耗）', full: 30, score: '72%', trend: '↑', owner: '财务部' },
      { name: '人员支出占业务支出比重', full: 30, score: '64%', trend: '→', owner: '人力资源部' },
      { name: '万元收入能耗支出', full: 20, score: '76%', trend: '↑', owner: '后勤保障部' },
      { name: '医护比', full: 20, score: '82%', trend: '↑', owner: '人力资源部' },
      { name: '住院患者满意度', full: 20, score: '95%', trend: '→', owner: '护理部' },
    ],
  },
  outpFund: {
    stats: [
      { label: '门诊统筹结算人次', value: '6,248', delta: '+18.6%', dir: 'up' },
      { label: '统筹基金支付', value: '486', unit: '万元', delta: '+22.4%', dir: 'up' },
      { label: '人均统筹费用', value: '78', unit: '元', delta: '+3.2%', dir: 'up' },
      { label: '个人账户支出', value: '326', unit: '万元', delta: '-4.6%', dir: 'down' },
      { label: '慢特病结算', value: '1,846', unit: '人次', delta: '+8.4%', dir: 'up' },
      { label: '处方外流率', value: '12.4', unit: '%', delta: '+2.8%', dir: 'up' },
    ],
    chartTitle: '门诊统筹基金月度支出',
    chartSub: '近 6 个月（万元）',
    chart: lineChart('统筹基金支付', [342, 386, 412, 438, 456, 486]),
    tableTitle: '科室门诊统筹使用',
    tableSub: '按统筹支付额排序',
    rowKey: 'dept',
    cols: [
      { key: 'dept', title: '科室' },
      { key: 'cases', title: '结算人次', align: 'right', num: true },
      { key: 'fund', title: '统筹支付（万元）', align: 'right', num: true },
      { key: 'avg', title: '人均费用（元）', align: 'right', num: true },
      { key: 'chronic', title: '慢特病占比', align: 'right', num: true },
    ],
    rows: [
      { dept: '内分泌科', cases: '986', fund: '86.4', avg: '88', chronic: '68.4%' },
      { dept: '心血管内科', cases: '912', fund: '92.6', avg: '102', chronic: '62.8%' },
      { dept: '神经内科', cases: '684', fund: '62.8', avg: '92', chronic: '54.2%' },
      { dept: '呼吸与危重症医学科', cases: '596', fund: '58.4', avg: '98', chronic: '42.6%' },
      { dept: '消化内科', cases: '512', fund: '44.2', avg: '86', chronic: '38.4%' },
      { dept: '中医科', cases: '468', fund: '38.6', avg: '82', chronic: '46.8%' },
    ],
  },
}

const cur = computed(() => topics[topic.value])
</script>

<style scoped>
.topics-layout {
  display: grid;
  grid-template-columns: 200px minmax(0, 1fr);
  gap: var(--wb-gap);
  align-items: start;
}

.topics-nav-panel {
  padding: 8px 0;
  position: sticky;
  top: 0;
}

.topics-content {
  display: flex;
  flex-direction: column;
  gap: var(--wb-gap);
  min-width: 0;
}

.topics-chart-body {
  min-height: 220px;
}
</style>
