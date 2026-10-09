<template>
  <div class="indicators-card">
    <div class="card-header">
      <h3 class="card-title">医院运营关键指标</h3>
      <router-link to="/workbench/overview" class="more-link">更多 &gt;</router-link>
    </div>

    <WbErrorPanel v-if="error && data === null" :error="error" :loading="loading" @retry="reload" />
    <WbSkeleton v-else-if="data === null && loading" :rows="5" />
    <WbEmpty v-else-if="!items.length" text="暂无指标数据" />
    <div v-else class="indicators-list">
      <WbStaleTag v-if="stale" :loading="loading" @retry="reload" />
      <div
        v-for="item in items"
        :key="item.code"
        class="indicator-item"
      >
        <!-- Icon Circle -->
        <div class="icon-circle" :style="{ backgroundColor: styleOf(item.tone).bg, color: styleOf(item.tone).fg }">
          <component :is="iconMap[item.icon ?? '']" :size="17" :stroke-width="1.9" />
        </div>

        <!-- Metric Details -->
        <div class="metric-info">
          <span class="metric-name">{{ item.name }}</span>
          <div class="metric-val-row">
            <span class="metric-num wb-num">{{ displayMoney(item.value, item.unit).value }}</span>
            <span v-if="item.unit" class="metric-unit">{{ displayMoney(item.value, item.unit).unit }}</span>
          </div>
        </div>

        <!-- Trend -->
        <div class="trend-box">
          <span class="trend-text">{{ item.delta_label || '较上月' }}</span>
          <span
            class="trend-delta wb-num"
            :class="item.dir === 'down' ? 'trend-down' : item.dir === 'flat' ? 'trend-flat' : 'trend-up'"
          >
            {{ item.delta }} {{ item.dir === 'down' ? '↓' : item.dir === 'flat' ? '–' : '↑' }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { displayMoney } from '../../api/preferences'
import { computed, onMounted } from 'vue'
import type { Component } from 'vue'
import {
  CalendarDays,
  BedDouble,
  Pill,
  Package,
  HeartPulse,
} from 'lucide-vue-next'
import { getHomeIndicators } from '../../api/workbench'
import { useAsyncData } from '../../api/useAsyncData'
import WbSkeleton from './WbSkeleton.vue'
import WbErrorPanel from './WbErrorPanel.vue'
import WbEmpty from './WbEmpty.vue'
import WbStaleTag from './WbStaleTag.vue'
import type { HomeIndicator, ToneType, WbStatItem } from '../../api/types'

// 五态取数经 useAsyncData（frontend-architecture §10.1）
const { data, loading, error, stale, reload } = useAsyncData(getHomeIndicators)
onMounted(reload)

// 契约 §3.4 未下发 delta_label；按 WbStatItem(§1.3-3) 可选字段预留消费位，契约补发即生效
const items = computed<(HomeIndicator & Pick<WbStatItem, 'delta_label'>)[]>(
  () => data.value?.list ?? [],
)

// 契约 icon/tone 为语义枚举（api-contract §1.3）；配色挂 --wb-tag-*-bg / --wb-* 语义 token
// （design-tokens §4），蓝图标取 --wb-accent(--wb-primary 为文字强调色)
const iconMap: Record<string, Component> = {
  CalendarDays,
  BedDouble,
  Pill,
  Package,
  HeartPulse,
}
const TONE_STYLE: Record<ToneType, { bg: string; fg: string }> = {
  primary: { bg: 'var(--wb-tag-blue-bg)', fg: 'var(--wb-accent)' },
  teal: { bg: 'var(--wb-tag-teal-bg)', fg: 'var(--wb-teal)' },
  green: { bg: 'var(--wb-tag-green-bg)', fg: 'var(--wb-green)' },
  amber: { bg: 'var(--wb-tag-amber-bg)', fg: 'var(--wb-amber)' },
  red: { bg: 'var(--wb-tag-red-bg)', fg: 'var(--wb-red)' },
  navy: { bg: 'var(--wb-tag-gray-bg)', fg: 'var(--wb-navy)' },
}
const styleOf = (tone: ToneType = 'primary') => TONE_STYLE[tone]
</script>

<style scoped>
.indicators-card {
  height: 100%;
  box-sizing: border-box;
  background: var(--wb-surface);
  border-radius: var(--wb-radius-card);
  border: 1px solid var(--wb-border);
  box-shadow: var(--wb-shadow-card);
  padding: var(--wb-pad-y) var(--wb-pad-x) var(--wb-space-2);
  display: flex;
  flex-direction: column;
  user-select: none;
  min-width: 0;
}

.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: var(--wb-space-1);
}

.card-title {
  font-size: var(--wb-fs-lg);
  font-weight: var(--wb-fw-bold);
  color: var(--wb-navy);
  margin: 0;
  letter-spacing: var(--wb-ls-md);
}

.more-link {
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-3);
  text-decoration: none;
  transition: color var(--wb-dur-fast);
}

.more-link:hover {
  color: var(--wb-primary);
}

.indicators-list {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  flex: 1;
}

.indicator-item {
  display: flex;
  align-items: center;
  padding: var(--wb-space-1) 0;
}

.indicator-item:not(:last-child) {
  border-bottom: 1px solid var(--wb-hairline);
}

.icon-circle {
  width: 34px;
  height: 34px;
  border-radius: var(--wb-radius-pill);
  display: flex;
  align-items: center;
  justify-content: center;
  margin-right: var(--wb-space-3);
  flex-shrink: 0;
}

.metric-info {
  display: flex;
  flex-direction: column;
  flex: 1;
  min-width: 0;
}

.metric-name {
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-2);
  font-weight: var(--wb-fw-medium);
  white-space: nowrap;
}

.metric-val-row {
  display: flex;
  align-items: baseline;
  gap: var(--wb-space-1);
  margin-top: 1px;
}

.metric-num {
  font-size: var(--wb-fs-xl);
  font-weight: var(--wb-fw-bold);
  color: var(--wb-navy);
  line-height: var(--wb-lh-mini);
}

.metric-unit {
  font-size: var(--wb-fs-xs);
  color: var(--wb-text-3);
  font-weight: var(--wb-fw-normal);
}

.trend-box {
  display: flex;
  align-items: center;
  gap: var(--wb-space-1);
  font-size: var(--wb-fs-sm);
}

.trend-text {
  color: var(--wb-text-3);
}

.trend-delta {
  font-weight: var(--wb-fw-semibold);
}

.trend-up {
  color: var(--wb-up);
}

.trend-down {
  color: var(--wb-down);
}

/* dir=flat 中性色,与全局 .wb-delta-flat 同色口径 */
.trend-flat {
  color: var(--wb-text-3);
}
</style>
