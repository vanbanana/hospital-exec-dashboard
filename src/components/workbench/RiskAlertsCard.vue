<template>
  <div class="risk-card">
    <div class="card-header">
      <h3 class="card-title">风险预警</h3>
      <router-link to="/workbench/quality" class="more-link">更多 &gt;</router-link>
    </div>

    <div class="risk-list">
      <div
        v-for="item in items"
        :key="item.id"
        class="risk-item"
      >
        <span
          class="level-badge"
          :class="`level-${levelLabel[item.level]}`"
        >
          {{ levelLabel[item.level] }}
        </span>
        <span class="risk-text">{{ item.title }}</span>
        <span class="risk-date wb-num">{{ item.occurred_at }}</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { getHomeAlerts } from '../../api/workbench'
import type { AlertLevel, HomeAlertItem } from '../../api/types'

const items = ref<HomeAlertItem[]>([])

// 契约告警级别为英文枚举 urgent|major|minor，展示端映射中文（api-contract §1.4-2）
const levelLabel: Record<AlertLevel, string> = {
  urgent: '高',
  major: '中',
  minor: '低',
}

onMounted(async () => {
  items.value = (await getHomeAlerts()).list
})
</script>

<style scoped>
.risk-card {
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
  margin-bottom: 8px;
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

.risk-list {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  flex: 1;
}

.risk-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 2px 0;
}

.level-badge {
  font-size: 11px;
  font-weight: 600;
  width: 20px;
  padding: 2px 0;
  border-radius: var(--wb-radius-tag);
  flex-shrink: 0;
  text-align: center;
  line-height: 1.3;
}

.level-高 {
  background-color: #feecec;
  color: var(--wb-red);
}

.level-中 {
  background-color: #fdf3e3;
  color: var(--wb-amber);
}

.level-低 {
  background-color: #e5f6f3;
  color: var(--wb-teal);
}

.risk-text {
  flex: 1;
  font-size: 12px;
  color: var(--wb-text-1);
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.risk-date {
  font-size: 12px;
  color: var(--wb-text-3);
  flex-shrink: 0;
}
</style>
