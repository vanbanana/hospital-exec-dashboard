<template>
  <div class="indicators-card">
    <div class="card-header">
      <h3 class="card-title">医院运营关键指标</h3>
      <router-link to="/workbench/overview" class="more-link">更多 &gt;</router-link>
    </div>

    <div class="indicators-list">
      <div
        v-for="item in indicatorItems"
        :key="item.name"
        class="indicator-item"
      >
        <!-- Icon Circle -->
        <div class="icon-circle" :style="{ backgroundColor: item.circleBg, color: item.iconColor }">
          <component :is="item.icon" :size="17" :stroke-width="1.9" />
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
            :class="item.isPositive ? 'trend-up' : 'trend-down'"
          >
            {{ item.delta }} {{ item.isPositive ? '↑' : '↓' }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import {
  CalendarDays,
  BedDouble,
  Pill,
  Package,
  HeartPulse,
} from 'lucide-vue-next'

const indicatorItems = [
  {
    name: '平均住院日',
    value: '6.8',
    unit: '天',
    delta: '-0.3',
    isPositive: false,
    circleBg: '#e9f0fe',
    iconColor: '#2563eb',
    icon: CalendarDays,
  },
  {
    name: '床位使用率',
    value: '92.1',
    unit: '%',
    delta: '+1.2',
    isPositive: true,
    circleBg: '#e9f0fe',
    iconColor: '#2563eb',
    icon: BedDouble,
  },
  {
    name: '药占比',
    value: '28.4',
    unit: '%',
    delta: '-0.6',
    isPositive: false,
    circleBg: '#e9f0fe',
    iconColor: '#2563eb',
    icon: Pill,
  },
  {
    name: '耗材占比',
    value: '17.9',
    unit: '%',
    delta: '-0.4',
    isPositive: false,
    circleBg: '#e5f6f3',
    iconColor: '#0d9488',
    icon: Package,
  },
  {
    name: '医疗服务收入占比',
    value: '43.6',
    unit: '%',
    delta: '+0.8',
    isPositive: true,
    circleBg: '#e8f6ee',
    iconColor: '#059669',
    icon: HeartPulse,
  },
]
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
