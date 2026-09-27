<template>
  <div class="notices-card">
    <div class="card-header">
      <h3 class="card-title">通知与待办</h3>
      <router-link to="/workbench/overview" class="more-link">更多 &gt;</router-link>
    </div>

    <WbErrorPanel v-if="error && data === null" :error="error" :loading="loading" @retry="reload" />
    <WbSkeleton v-else-if="data === null && loading" :rows="5" />
    <WbEmpty v-else-if="!items.length" text="暂无通知与待办" />
    <div v-else class="notices-list">
      <WbStaleTag v-if="stale" :loading="loading" @retry="reload" />
      <div
        v-for="item in items"
        :key="item.id"
        class="notice-item"
      >
        <span
          class="notice-dot"
          :class="item.urgent ? 'dot-urgent' : 'dot-normal'"
        ></span>
        <span class="notice-text">{{ item.text }}</span>
        <span class="notice-date wb-num">{{ item.date }}</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { getHomeNotices } from '../../api/workbench'
import { useAsyncData } from '../../api/useAsyncData'
import WbSkeleton from './WbSkeleton.vue'
import WbErrorPanel from './WbErrorPanel.vue'
import WbEmpty from './WbEmpty.vue'
import WbStaleTag from './WbStaleTag.vue'

// 五态取数经 useAsyncData（frontend-architecture §10.1）
const { data, loading, error, stale, reload } = useAsyncData(getHomeNotices)
onMounted(reload)

const items = computed(() => data.value?.list ?? [])
</script>

<style scoped>
.notices-card {
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

.notices-list {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  flex: 1;
}

.notice-item {
  display: flex;
  align-items: center;
  gap: var(--wb-space-2);
  padding: var(--wb-space-1) 0;
}

.notice-dot {
  width: 7px;
  height: 7px;
  border-radius: var(--wb-radius-pill);
  flex-shrink: 0;
}

.dot-urgent {
  background-color: var(--wb-red);
}

.dot-normal {
  background-color: var(--wb-text-4);
}

.notice-text {
  flex: 1;
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-1);
  font-weight: var(--wb-fw-medium);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.notice-date {
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-3);
  flex-shrink: 0;
}
</style>
