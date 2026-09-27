<template>
  <div class="hero-ribbon">
    <template v-if="rows.length">
      <template v-for="(r, i) in rows" :key="r.k.code">
        <div v-if="i > 0" class="hero-divider"></div>
        <div class="hero-item">
          <div class="hero-icon" :class="{ 'icon-warn': r.k.status === 'warn' }">
            <component :is="iconOf(r.k.code)" :size="16" :stroke-width="2" />
          </div>
          <div class="hero-content">
            <span class="hero-label">{{ r.k.name }}</span>
            <div class="hero-val-wrap">
              <span class="hero-value scr-num">{{ fmtNum(r.k.value) }}</span>
              <span class="hero-unit">{{ r.k.unit }}</span>
              <span class="hero-badge" :class="r.badgeCls">{{ fmtDelta(r.k.delta_pct) }}</span>
            </div>
          </div>
          <svg class="kpi-spark" :viewBox="`0 0 ${SPARK_W} ${SPARK_H}`" preserveAspectRatio="none" aria-hidden="true">
            <polyline :points="r.points" fill="none" />
            <circle :cx="r.ex" :cy="r.ey" r="2.2" class="spark-end" />
          </svg>
        </div>
      </template>
    </template>
    <div v-else class="scr-empty">暂无指标数据</div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { Component } from 'vue'
import { Activity, BedDouble, BedSingle, Scissors, Stethoscope } from 'lucide-vue-next'
import type { ScreenKpi } from '../../api/types'

const props = defineProps<{ kpis?: ScreenKpi[] }>()

/* sparkline 美术稿几何 */
const SPARK_W = 72
const SPARK_H = 26
const SPARK_PAD = 2

/* B10：BED_USE_RATE 有专属图标，不再落 Activity 兜底 */
const iconOf = (code: string): Component => {
  const map: Record<string, Component> = {
    OP_DAILY_VISITS: Stethoscope,
    IP_IN_HOSP: BedDouble,
    BED_USE_RATE: BedSingle,
    SURG_DAILY_CNT: Scissors,
  }
  return map[code] ?? Activity
}

const fmtNum = (v: number) => (Number.isInteger(v) ? v.toLocaleString('en-US') : v.toFixed(1))
const fmtDelta = (v: number) => `${v > 0 ? '+' : ''}${v}%`

/* 徽章档位：status=warn 压方向（如床位高使用率告警琥珀）；
   方向色按 REF badge-up=绿/向好 语义（spec §5.3-1：badge-up 用绿不走 --scr-up 红） */
const badgeClass = (k: ScreenKpi) => {
  if (k.status === 'warn') return 'b-warn'
  if (k.direction > 0) return 'b-up'
  if (k.direction < 0) return 'b-down'
  return 'b-flat'
}

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

/* B13：spark 折线点+末点随 kpis 一次性算好，模板零重算 */
const rows = computed(() =>
  (props.kpis ?? []).map((k) => {
    const points = sparkPoints(k.spark)
    const [ex = '0', ey = '0'] = points.split(' ').pop()?.split(',') ?? []
    return { k, points, ex, ey, badgeCls: badgeClass(k) }
  })
)
</script>

<style scoped>
/* .hero-ribbon 外壳（定位/底/边/玻璃）在 screen.css 浮层布局区块 */

.hero-item {
  flex: 1;
  display: flex;
  align-items: center;
  gap: var(--scr-space-5);
  min-width: 0;
}

.hero-icon {
  width: 32px; /* REF hero-metric-icon 32×32 */
  height: 32px;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: var(--scr-radius-card);
  background: rgb(from var(--scr-royal) r g b / 0.16);
  border: 1px solid rgb(from var(--p-cyan-400) r g b / 0.28);
  color: var(--scr-accent-bright);
}

.hero-icon.icon-warn {
  background: rgb(from var(--p-amber-500) r g b / 0.16);
  border-color: rgb(from var(--p-amber-500) r g b / 0.35);
  color: var(--scr-warn);
}

.hero-content {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.hero-label {
  font-size: var(--scr-fs-sm);
  color: var(--scr-text-3);
  letter-spacing: var(--scr-ls-sm);
  line-height: var(--scr-lh-compact);
  white-space: nowrap;
}

.hero-val-wrap {
  display: flex;
  align-items: baseline;
  gap: var(--scr-space-2);
}

.hero-value {
  font-size: var(--scr-fs-19); /* REF hero-metric-value 19px */
  font-weight: var(--scr-fw-bold);
  color: var(--scr-text-1);
  line-height: var(--scr-lh-mini);
}

.hero-unit {
  font-size: var(--scr-fs-10p5);
  color: var(--scr-text-4);
}

.hero-badge {
  font-size: var(--scr-fs-xs);
  font-weight: var(--scr-fw-semibold);
  font-family: var(--p-font-number);
  padding: var(--scr-space-1) 5px; /* REF pad 1px 5px */
  border-radius: var(--scr-radius-badge);
  margin-left: var(--scr-space-2);
  white-space: nowrap;
}

.hero-badge.b-up {
  background: rgb(from var(--p-green-500) r g b / 0.15);
  color: var(--p-green-500); /* 原色直取：REF badge-up 向好绿（spec §5.3-1 裁决） */
}
.hero-badge.b-down {
  background: rgb(from var(--p-red-500) r g b / 0.15);
  color: var(--p-red-500); /* 原色直取：下滑红 */
}
.hero-badge.b-flat {
  background: rgb(from var(--p-cyan-400) r g b / 0.15);
  color: var(--scr-accent-bright);
}
.hero-badge.b-warn {
  background: rgb(from var(--p-amber-500) r g b / 0.15);
  color: var(--scr-warn);
}

.kpi-spark {
  width: 72px; /* 美术稿，与 SPARK_W 一致 */
  height: 26px;
  margin-left: auto;
  flex-shrink: 0;
  align-self: center;
}

.kpi-spark polyline {
  stroke: var(--scr-accent-bright);
  stroke-width: 1.6;
  stroke-linejoin: round;
  stroke-linecap: round;
}

.spark-end {
  fill: none;
  stroke: var(--scr-accent-bright);
  stroke-width: 1.6;
}

.hero-item:has(.icon-warn) .kpi-spark polyline,
.hero-item:has(.icon-warn) .spark-end {
  stroke: var(--scr-warn);
}

/* REF hero-divider 1×28 竖向渐变分隔线 */
.hero-divider {
  width: 1px;
  height: 28px;
  align-self: center;
  margin-inline: var(--scr-space-5);
  background: linear-gradient(180deg, transparent, rgb(from var(--p-white) r g b / 0.12), transparent);
  flex-shrink: 0;
}
</style>
