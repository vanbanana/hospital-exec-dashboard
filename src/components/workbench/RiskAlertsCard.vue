<template>
  <div class="risk-card">
    <div class="card-header">
      <h3 class="card-title">风险预警</h3>
      <router-link to="/workbench/quality" class="more-link">更多 &gt;</router-link>
    </div>

    <WbErrorPanel v-if="error && data === null" :error="error" :loading="loading" @retry="reload" />
    <WbSkeleton v-else-if="data === null && loading" :rows="5" />
    <WbEmpty v-else-if="!items.length" text="暂无预警" />
    <div v-else class="risk-list">
      <WbStaleTag v-if="stale" :loading="loading" @retry="reload" />
      <div
        v-for="item in items"
        :key="item.id"
        class="risk-item"
      >
        <span
          class="level-badge"
          :style="{ backgroundColor: LEVEL_STYLE[item.level].bg, color: LEVEL_STYLE[item.level].fg }"
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
import { computed, onMounted } from 'vue'
import { getHomeAlerts } from '../../api/workbench'
import { useAsyncData } from '../../api/useAsyncData'
import WbSkeleton from './WbSkeleton.vue'
import WbErrorPanel from './WbErrorPanel.vue'
import WbEmpty from './WbEmpty.vue'
import WbStaleTag from './WbStaleTag.vue'
import type { AlertLevel } from '../../api/types'

// 五态取数经 useAsyncData（frontend-architecture §10.1）
const { data, loading, error, stale, reload } = useAsyncData(getHomeAlerts)
onMounted(reload)

const items = computed(() => data.value?.list ?? [])

// 契约告警级别为英文枚举 urgent|major|minor（api-contract §1.4-2）：
// 中文仅作文案;配色按枚举挂 --wb-tag-*-bg / --wb-* 语义 token,文案不充当选择器
const levelLabel: Record<AlertLevel, string> = {
  urgent: '高',
  major: '中',
  minor: '低',
}
const LEVEL_STYLE: Record<AlertLevel, { bg: string; fg: string }> = {
  urgent: { bg: 'var(--wb-tag-red-bg)', fg: 'var(--wb-red)' },
  major: { bg: 'var(--wb-tag-amber-bg)', fg: 'var(--wb-amber)' },
  minor: { bg: 'var(--wb-tag-teal-bg)', fg: 'var(--wb-teal)' },
}
</script>

<style scoped>
.risk-card {
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
  margin-bottom: var(--wb-space-2);
}

.card-title {
  font-size: var(--wb-fs-lg);
  font-weight: var(--wb-fw-bold);
  color: var(--wb-navy);
  margin: 0;
  letter-spacing: 0.3px;
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

.risk-list {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  flex: 1;
}

.risk-item {
  display: flex;
  align-items: center;
  gap: var(--wb-space-2);
  padding: var(--wb-space-1) 0;
}

.level-badge {
  font-size: var(--wb-fs-xs);
  font-weight: var(--wb-fw-semibold);
  width: 20px;
  padding: var(--wb-space-1) 0;
  border-radius: var(--wb-radius-tag);
  flex-shrink: 0;
  text-align: center;
  line-height: 1.3;
}

.level-高 {
  background-color: var(--wb-tag-red-bg);
  color: var(--wb-red);
}

.level-中 {
  background-color: var(--wb-tag-amber-bg);
  color: var(--wb-amber);
}

.level-低 {
  background-color: var(--wb-tag-teal-bg);
  color: var(--wb-teal);
}

.risk-text {
  flex: 1;
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-1);
  font-weight: var(--wb-fw-medium);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.risk-date {
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-3);
  flex-shrink: 0;
}
</style>
