<template>
  <div class="kpi-cards-grid">
    <div
      v-for="card in kpiCards"
      :key="card.title"
      class="kpi-card"
    >
      <!-- Icon Container -->
      <div class="kpi-icon-box" :style="{ backgroundColor: card.bgColor }">
        <div v-if="card.isYenBadge" class="yen-circle-badge">
          <span class="yen-char">¥</span>
        </div>
        <component
          :is="card.icon"
          v-else
          :size="22"
          :stroke-width="1.9"
          class="kpi-icon"
        />
      </div>

      <!-- Content -->
      <div class="kpi-content">
        <div class="kpi-title">{{ card.title }}</div>
        <div class="kpi-value-row">
          <span class="kpi-number wb-num">{{ card.value }}</span>
          <span v-if="card.unit" class="kpi-unit">{{ card.unit }}</span>
        </div>
        <div class="kpi-trend-row">
          <span class="trend-label">较上月</span>
          <span class="trend-val wb-num">
            {{ card.change }}<span class="trend-arrow">↑</span>
          </span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import {
  Stethoscope,
  BedDouble,
  Scissors,
  Users,
} from 'lucide-vue-next'

const kpiCards = [
  {
    title: '门急诊人次',
    value: '12,482',
    change: '+3.6%',
    unit: '',
    bgColor: '#2563eb',
    icon: Stethoscope,
    isYenBadge: false,
  },
  {
    title: '住院人次',
    value: '3,920',
    change: '+5.1%',
    unit: '',
    bgColor: '#3b82f6',
    icon: BedDouble,
    isYenBadge: false,
  },
  {
    title: '手术台次',
    value: '1,286',
    change: '+4.8%',
    unit: '',
    bgColor: '#059669',
    icon: Scissors,
    isYenBadge: false,
  },
  {
    title: '医疗总收入',
    value: '23,560',
    unit: '万元',
    change: '+2.9%',
    bgColor: '#10b981',
    icon: null,
    isYenBadge: true,
  },
  {
    title: '在岗职工',
    value: '2,368',
    change: '+0.4%',
    unit: '',
    bgColor: '#0891b2',
    icon: Users,
    isYenBadge: false,
  },
]
</script>

<style scoped>
.kpi-cards-grid {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: var(--wb-gap);
}

.kpi-card {
  background: var(--wb-surface);
  border-radius: var(--wb-radius-card);
  border: 1px solid var(--wb-border);
  box-shadow: var(--wb-shadow-card);
  padding: 14px 16px;
  display: flex;
  align-items: center;
  gap: 14px;
  user-select: none;
  transition: transform 0.2s, box-shadow 0.2s;
}

.kpi-card:hover {
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(15, 23, 42, 0.06);
}

.kpi-icon-box {
  width: 44px;
  height: 44px;
  border-radius: var(--wb-radius-card);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #ffffff;
  flex-shrink: 0;
}

.yen-circle-badge {
  width: 26px;
  height: 26px;
  background-color: #ffffff;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.yen-char {
  color: #10b981;
  font-weight: 700;
  font-size: 15px;
  line-height: 1;
}

.kpi-content {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.kpi-title {
  font-size: 13px;
  color: var(--wb-text-2);
  font-weight: 500;
}

.kpi-value-row {
  display: flex;
  align-items: baseline;
  gap: 4px;
  margin-top: 2px;
}

.kpi-number {
  font-size: 24px;
  font-weight: 700;
  color: var(--wb-navy);
  line-height: 1.15;
}

.kpi-unit {
  font-size: 12px;
  color: var(--wb-text-3);
  font-weight: 400;
}

.kpi-trend-row {
  display: flex;
  align-items: center;
  gap: 5px;
  margin-top: 3px;
  font-size: 12px;
}

.trend-label {
  color: var(--wb-text-3);
}

.trend-val {
  color: var(--wb-up);
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 2px;
}

.trend-arrow {
  font-size: 11px;
  line-height: 1;
}
</style>
