<template>
  <div class="kpi-cards-grid">
    <div
      v-for="card in items"
      :key="card.key"
      class="kpi-card"
    >
      <!-- Icon Container -->
      <div class="kpi-icon-box" :style="{ backgroundColor: styleOf(card.key).bg }">
        <div v-if="styleOf(card.key).yen" class="yen-circle-badge">
          <span class="yen-char">¥</span>
        </div>
        <component
          :is="iconMap[card.icon ?? '']"
          v-else
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
          <span class="trend-label">较上月</span>
          <span class="trend-val wb-num">
            {{ card.delta }}<span class="trend-arrow">{{ card.dir === 'down' ? '↓' : '↑' }}</span>
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
  Stethoscope,
  BedDouble,
  Scissors,
  Users,
  Banknote,
} from 'lucide-vue-next'
import { getHomeKpis } from '../../api/workbench'
import type { HomeKpiItem } from '../../api/types'

const items = ref<HomeKpiItem[]>([])

// 契约下发 icon 为 Lucide 图标名、禁下十六进制色值（api-contract §1.4-6），
// 展示端按业务 key 固定卡片底色与 ¥ 徽标特例
const iconMap: Record<string, Component> = {
  Stethoscope,
  BedDouble,
  Scissors,
  Users,
  Banknote,
}
const cardStyle: Record<string, { bg: string; yen?: boolean }> = {
  outpatient: { bg: '#2563eb' },
  inpatient: { bg: '#3b82f6' },
  surgery: { bg: '#059669' },
  revenue: { bg: '#10b981', yen: true },
  staff: { bg: '#0891b2' },
}
const styleOf = (key: string) => cardStyle[key] ?? { bg: '#2563eb' }

onMounted(async () => {
  items.value = (await getHomeKpis()).list
})
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
