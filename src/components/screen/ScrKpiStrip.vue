<template>
  <div class="scr-panel kpi-strip">
    <template v-if="kpis && kpis.length">
      <template v-for="(k, i) in kpis" :key="k.code">
        <div v-if="i > 0" class="kpi-divider"></div>
        <div class="kpi-item" :class="{ 'is-warn': k.status === 'warn' }">
          <div class="kpi-icon">
            <component :is="iconOf(k.code)" :size="16" :stroke-width="2" />
          </div>
          <div class="kpi-main">
            <span class="kpi-name">{{ k.name }}</span>
            <div class="kpi-val-row">
              <span class="kpi-value scr-num">{{ fmtNum(k.value) }}</span>
              <span class="kpi-unit">{{ k.unit }}</span>
              <span class="kpi-delta" :class="dirClass(k.direction)">
                {{ dirMark(k.direction) }}{{ fmtDelta(k.delta_pct) }}
              </span>
            </div>
          </div>
          <svg class="kpi-spark" :viewBox="`0 0 ${SPARK_W} ${SPARK_H}`" preserveAspectRatio="none" aria-hidden="true">
            <polyline :points="sparkPoints(k.spark)" fill="none" />
            <circle :cx="lastPt(k.spark).x" :cy="lastPt(k.spark).y" r="2.2" class="spark-end" />
          </svg>
        </div>
      </template>
    </template>
    <div v-else class="scr-empty">暂无指标数据</div>
  </div>
</template>

<script setup lang="ts">
import type { Component } from 'vue'
import { Activity, BedDouble, Scissors, Stethoscope } from 'lucide-vue-next'
import type { ScreenKpi } from '../../api/types'

defineProps<{ kpis?: ScreenKpi[] }>()

/* sparkline 美术稿几何 */
const SPARK_W = 72
const SPARK_H = 26
const SPARK_PAD = 2

const iconOf = (code: string): Component => {
  const map: Record<string, Component> = {
    OP_DAILY_VISITS: Stethoscope,
    IP_IN_HOSP: BedDouble,
    SURG_DAILY_CNT: Scissors,
  }
  return map[code] ?? Activity
}

const fmtNum = (v: number) => (Number.isInteger(v) ? v.toLocaleString('en-US') : v.toFixed(1))
const fmtDelta = (v: number) => `${v > 0 ? '+' : ''}${v}%`
const dirMark = (d: number) => (d > 0 ? '▲ ' : d < 0 ? '▼ ' : '')
// 中国医疗管理惯例：升=红(--scr-up)，降=绿(--scr-down)
const dirClass = (d: number) => (d > 0 ? 'is-up' : d < 0 ? 'is-down' : 'is-flat')

function sparkPoints(spark: number[]): string {
  if (!spark.length) return ''
  const min = Math.min(...spark)
  const max = Math.max(...spark)
  const range = max - min || 1
  const step = (SPARK_W - SPARK_PAD * 2) / Math.max(spark.length - 1, 1)
  return spark
    .map((v, i) => {
      const x = SPARK_PAD + i * step
      const y = SPARK_H - SPARK_PAD - ((v - min) / range) * (SPARK_H - SPARK_PAD * 2)
      return `${x.toFixed(1)},${y.toFixed(1)}`
    })
    .join(' ')
}

function lastPt(spark: number[]) {
  const pts = sparkPoints(spark).split(' ')
  const last = pts[pts.length - 1]?.split(',') ?? ['0', '0']
  return { x: last[0], y: last[1] }
}
</script>

<style scoped>
.kpi-strip {
  flex-direction: row;
  align-items: stretch;
  padding-inline: var(--scr-space-9);
}

.kpi-item {
  flex: 1;
  display: flex;
  align-items: center;
  gap: var(--scr-space-6);
  min-width: 0;
}

.kpi-icon {
  width: 34px; /* 美术稿 */
  height: 34px;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: var(--scr-radius-card);
  background: rgb(from var(--p-blue-600) r g b / 0.16);
  border: 1px solid var(--scr-border-glow);
  color: var(--scr-accent-bright);
}

.kpi-item.is-warn .kpi-icon {
  background: rgb(from var(--p-amber-500) r g b / 0.14);
  border-color: rgb(from var(--p-amber-500) r g b / 0.4);
  color: var(--scr-warn);
}

.kpi-main {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.kpi-name {
  font-size: var(--scr-fs-sm);
  color: var(--scr-text-3);
  letter-spacing: 0.3px;
  white-space: nowrap;
}

.kpi-val-row {
  display: flex;
  align-items: baseline;
  gap: var(--scr-space-3);
}

.kpi-value {
  font-size: var(--scr-fs-num);
  font-weight: 700;
  color: var(--scr-text-1);
  line-height: 1.15;
}

.kpi-item.is-warn .kpi-value {
  color: var(--scr-warn);
}

.kpi-unit {
  font-size: var(--scr-fs-sm);
  color: var(--scr-text-4);
}

.kpi-delta {
  font-size: var(--scr-fs-sm);
  font-weight: 600;
  font-family: var(--p-font-number);
}
.kpi-delta.is-up {
  color: var(--scr-up);
}
.kpi-delta.is-down {
  color: var(--scr-down);
}
.kpi-delta.is-flat {
  color: var(--scr-text-4);
}

.kpi-spark {
  width: 72px; /* 美术稿，与 SPARK_W 一致 */
  height: 26px;
  margin-left: auto;
  flex-shrink: 0;
}

.kpi-spark polyline {
  stroke: var(--scr-accent-bright);
  stroke-width: 1.6;
  stroke-linejoin: round;
  stroke-linecap: round;
}

.kpi-item.is-warn .kpi-spark polyline,
.kpi-item.is-warn .spark-end {
  stroke: var(--scr-warn);
}

.spark-end {
  fill: none;
  stroke: var(--scr-accent-bright);
  stroke-width: 1.6;
}

.kpi-divider {
  width: 1px;
  align-self: center;
  height: 34px; /* 美术稿 */
  margin-inline: var(--scr-space-8);
  background: linear-gradient(180deg, transparent, var(--scr-border), transparent);
  flex-shrink: 0;
}
</style>
