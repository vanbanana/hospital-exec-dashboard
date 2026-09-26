<template>
  <div class="indicators-card">
    <div class="card-header">
      <h3 class="card-title">医院运营关键指标</h3>
      <router-link to="/workbench/overview" class="more-link">更多 &gt;</router-link>
    </div>

    <div class="indicators-list">
      <div
        v-for="item in items"
        :key="item.code"
        class="indicator-item"
      >
        <!-- Icon Circle -->
        <div class="icon-circle" :style="{ backgroundColor: styleOf(item.tone).circleBg, color: styleOf(item.tone).iconColor }">
          <component :is="iconMap[item.icon ?? '']" :size="17" :stroke-width="1.9" />
        </div>

        <!-- Metric Details -->
        <div class="metric-info">
          <span class="metric-name">{{ item.name }}</span>
          <div class="metric-val-row">
            <span class="metric-num wb-num">{{ item.value }}</span>
            <span v-if="item.unit" class="metric-unit">{{ item.unit }}</span>
          </div>
        </div>

        <!-- Trend -->
        <div class="trend-box">
          <span class="trend-text">较上月</span>
          <span
            class="trend-delta wb-num"
            :class="item.dir === 'down' ? 'trend-down' : 'trend-up'"
          >
            {{ item.delta }} {{ item.dir === 'down' ? '↓' : '↑' }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import type { Component } from 'vue'
import {
  CalendarDays,
  BedDouble,
  Pill,
  Package,
  HeartPulse,
} from 'lucide-vue-next'
import { getHomeIndicators } from '../../api/workbench'
import type { HomeIndicator, ToneType } from '../../api/types'

const items = ref<HomeIndicator[]>([])

// 契约 icon/tone 为语义枚举（api-contract §1.3），展示端映射组件与配色
const iconMap: Record<string, Component> = {
  CalendarDays,
  BedDouble,
  Pill,
  Package,
  HeartPulse,
}
const toneStyle: Record<ToneType, { circleBg: string; iconColor: string }> = {
  primary: { circleBg: '#e9f0fe', iconColor: '#2563eb' },
  teal: { circleBg: '#e5f6f3', iconColor: '#0d9488' },
  green: { circleBg: '#e8f6ee', iconColor: '#059669' },
  amber: { circleBg: '#fdf3e3', iconColor: '#d97706' },
  red: { circleBg: '#feecec', iconColor: '#ef4444' },
  navy: { circleBg: '#eef2f7', iconColor: '#0b1f47' },
}
const styleOf = (tone: ToneType = 'primary') => toneStyle[tone]

onMounted(async () => {
  items.value = (await getHomeIndicators()).list
})
</script>

<style scoped>
.indicators-card {
  height: 100%;
  box-sizing: border-box;
  background: var(--wb-surface);
  border-radius: var(--wb-radius-card);
  border: 1px solid var(--wb-border);
  box-shadow: var(--wb-shadow-card);
  padding: 14px 16px 10px;
  display: flex;
  flex-direction: column;
  user-select: none;
  min-width: 0;
}

.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 4px;
}

.card-title {
  font-size: 15px;
  font-weight: 700;
  color: var(--wb-navy);
  margin: 0;
  letter-spacing: 0.3px;
}

.more-link {
  font-size: 12px;
  color: var(--wb-text-3);
  text-decoration: none;
  transition: color 0.15s;
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
  padding: 4px 0;
}

.indicator-item:not(:last-child) {
  border-bottom: 1px solid var(--wb-hairline);
}

.icon-circle {
  width: 34px;
  height: 34px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-right: 11px;
  flex-shrink: 0;
}

.metric-info {
  display: flex;
  flex-direction: column;
  flex: 1;
  min-width: 0;
}

.metric-name {
  font-size: 12px;
  color: var(--wb-text-2);
  font-weight: 500;
  white-space: nowrap;
}

.metric-val-row {
  display: flex;
  align-items: baseline;
  gap: 2px;
  margin-top: 1px;
}

.metric-num {
  font-size: 18px;
  font-weight: 700;
  color: var(--wb-navy);
  line-height: 1.1;
}

.metric-unit {
  font-size: 11px;
  color: var(--wb-text-3);
  font-weight: 400;
}

.trend-box {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
}

.trend-text {
  color: var(--wb-text-3);
}

.trend-delta {
  font-weight: 600;
}

.trend-up {
  color: var(--wb-up);
}

.trend-down {
  color: var(--wb-down);
}
</style>
