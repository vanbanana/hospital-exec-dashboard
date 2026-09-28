<template>
  <div class="kpi-cards-grid">
    <WbErrorPanel
      v-if="error && data === null"
      class="state-span"
      :error="error"
      :loading="loading"
      @retry="reload"
    />
    <template v-else-if="data === null && loading">
      <div v-for="i in 5" :key="i" class="kpi-card"><WbSkeleton :rows="2" /></div>
    </template>
    <WbEmpty v-else-if="!items.length" class="state-span" text="暂无 KPI 数据" />
    <WbStaleTag v-if="stale" class="state-span" :loading="loading" @retry="reload" />
    <!-- §3.1 period 角标:统计口径消费契约字段 -->
    <div v-if="data?.period" class="kpi-period-tag state-span">统计口径：{{ data.period }}</div>
    <div
      v-for="card in items"
      :key="card.key"
      class="kpi-card"
    >
      <!-- Icon Container -->
      <div class="kpi-icon-box" :style="{ backgroundColor: TONE_BG[card.tone ?? 'primary'] }">
        <component
          :is="iconMap[card.icon ?? '']"
          :size="22"
          :stroke-width="1.9"
          class="kpi-icon"
        />
      </div>

      <!-- Content -->
      <div class="kpi-content">
        <div class="kpi-title">{{ card.label }}</div>
        <div class="kpi-value-row">
          <span class="kpi-number wb-num">{{ card.value }}</span>
          <span v-if="card.unit" class="kpi-unit">{{ card.unit }}</span>
        </div>
        <div class="kpi-trend-row">
          <span class="trend-label">{{ card.delta_label || '较上月' }}</span>
          <span class="trend-val wb-num" :class="{ 'trend-flat': card.dir === 'flat' }">
            {{ card.delta
            }}<span class="trend-arrow">{{ card.dir === 'down' ? '↓' : card.dir === 'flat' ? '–' : '↑' }}</span>
          </span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import type { Component } from 'vue'
import {
  Stethoscope,
  BedDouble,
  Scissors,
  Users,
  Banknote,
} from 'lucide-vue-next'
import { getHomeKpis } from '../../api/workbench'
import { useAsyncData } from '../../api/useAsyncData'
import WbSkeleton from './WbSkeleton.vue'
import WbErrorPanel from './WbErrorPanel.vue'
import WbEmpty from './WbEmpty.vue'
import WbStaleTag from './WbStaleTag.vue'
import type { ToneType } from '../../api/types'

// 五态取数经 useAsyncData（frontend-architecture §10.1）
const { data, loading, error, stale, reload } = useAsyncData(getHomeKpis)
onMounted(reload)

const items = computed(() => data.value?.list ?? [])

// 契约 icon 为 Lucide 图标名、tone 为语义色枚举，禁下十六进制色值（api-contract §1.4-6）；
// 填充底色挂 --wb-* token（蓝填充取 --wb-accent，--wb-primary 为文字强调色）
const iconMap: Record<string, Component> = {
  Stethoscope,
  BedDouble,
  Scissors,
  Users,
  Banknote,
}
const TONE_BG: Record<ToneType, string> = {
  primary: 'var(--wb-accent)',
  teal: 'var(--wb-teal)',
  green: 'var(--wb-green)',
  amber: 'var(--wb-amber)',
  red: 'var(--wb-red)',
  navy: 'var(--wb-navy)',
}

</script>

<style scoped>
.kpi-cards-grid {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: var(--wb-gap);
}

.state-span {
  grid-column: 1 / -1;
}

.kpi-period-tag {
  justify-self: end;
  font-size: var(--wb-fs-xs);
  color: var(--wb-text-3);
  letter-spacing: var(--wb-ls-sm);
}

.kpi-card {
  background: var(--wb-surface);
  border-radius: var(--wb-radius-card);
  border: 1px solid var(--wb-border);
  box-shadow: var(--wb-shadow-card);
  padding: var(--wb-pad-y) var(--wb-pad-x);
  display: flex;
  align-items: center;
  gap: var(--wb-space-3);
  user-select: none;
  transition: transform var(--wb-dur-normal), box-shadow var(--wb-dur-normal);
}

.kpi-card:hover {
  transform: translateY(-1px);
  box-shadow: var(--wb-shadow-hover);
}

.kpi-icon-box {
  width: 44px;
  height: 44px;
  border-radius: var(--wb-radius-card);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--p-white); /* 原色直取 */
  flex-shrink: 0;
}

.kpi-content {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.kpi-title {
  font-size: var(--wb-fs-md);
  color: var(--wb-text-2);
  font-weight: var(--wb-fw-medium);
}

.kpi-value-row {
  display: flex;
  align-items: baseline;
  gap: var(--wb-space-1);
  margin-top: var(--wb-space-1);
}

.kpi-number {
  font-size: var(--wb-fs-hero);
  font-weight: var(--wb-fw-bold);
  color: var(--wb-navy);
  line-height: var(--wb-lh-tight);
}

.kpi-unit {
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-3);
  font-weight: var(--wb-fw-normal);
}

.kpi-trend-row {
  display: flex;
  align-items: center;
  gap: var(--wb-space-1);
  margin-top: var(--wb-space-1);
  font-size: var(--wb-fs-sm);
}

.trend-label {
  color: var(--wb-text-3);
}

.trend-val {
  color: var(--wb-up);
  font-weight: var(--wb-fw-semibold);
  display: flex;
  align-items: center;
  gap: var(--wb-space-1);
}

/* dir=flat 中性色,与全局 .wb-delta-flat 同色口径 */
.trend-val.trend-flat {
  color: var(--wb-text-3);
}

.trend-arrow {
  font-size: var(--wb-fs-xs);
  line-height: var(--wb-lh-solid);
}
</style>
