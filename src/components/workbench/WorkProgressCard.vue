<template>
  <div class="progress-card">
    <div class="card-header">
      <h3 class="card-title">重点工作进度</h3>
      <router-link to="/workbench/topics" class="more-link">更多 &gt;</router-link>
    </div>

    <WbErrorPanel v-if="error && data === null" :error="error" :loading="loading" @retry="reload" />
    <WbSkeleton v-else-if="data === null && loading" :rows="5" />
    <WbEmpty v-else-if="!items.length" text="暂无重点工作事项" />
    <div v-else class="progress-list">
      <WbStaleTag v-if="stale" :loading="loading" @retry="reload" />
      <div
        v-for="item in items"
        :key="item.id"
        class="progress-item"
      >
        <span class="status-dot" :class="item.status === '进行中' ? 'dot-doing' : 'dot-pending'"></span>
        <span class="task-name">{{ item.name }}</span>
        <div class="task-bar-track">
          <div class="task-bar-fill" :style="{ width: `${item.progress}%` }"></div>
        </div>
        <span class="progress-val wb-num">{{ item.progress }}%</span>
        <span
          class="status-tag"
          :class="item.status === '进行中' ? 'status-active' : 'status-pending'"
        >
          {{ item.status }}
        </span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { getHomeProgress } from '../../api/workbench'
import { useAsyncData } from '../../api/useAsyncData'
import WbSkeleton from './WbSkeleton.vue'
import WbErrorPanel from './WbErrorPanel.vue'
import WbEmpty from './WbEmpty.vue'
import WbStaleTag from './WbStaleTag.vue'

// 五态取数经 useAsyncData（frontend-architecture §10.1）：fetcher 只发请求，态切换由封装收口
const { data, loading, error, stale, reload } = useAsyncData(getHomeProgress)
onMounted(reload)

const items = computed(() => data.value?.list ?? [])
</script>

<style scoped>
.progress-card {
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

.progress-list {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  flex: 1;
}

.progress-item {
  display: flex;
  align-items: center;
  gap: var(--wb-space-2);
  padding: var(--wb-space-1) 0;
}

/* 点色随状态：进行中=绿、待启动=灰，避免无意义异色 */
.status-dot {
  width: 7px;
  height: 7px;
  border-radius: var(--wb-radius-pill);
  flex-shrink: 0;
}
.dot-doing { background-color: var(--wb-green); }
.dot-pending { background-color: var(--wb-text-4); }

.task-name {
  width: 120px;
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-1);
  font-weight: var(--wb-fw-medium);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  flex-shrink: 0;
}

.task-bar-track {
  flex: 1;
  height: 8px;
  background-color: var(--wb-bar-track);
  border-radius: var(--wb-radius-tag);
  overflow: hidden;
}

.task-bar-fill {
  height: 100%;
  background-color: var(--wb-accent);
  border-radius: var(--wb-radius-tag);
  transition: width var(--wb-dur-normal) ease;
}

.progress-val {
  width: 34px;
  text-align: right;
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-2);
  flex-shrink: 0;
}

.status-tag {
  font-size: var(--wb-fs-xs);
  padding: var(--wb-space-1) var(--wb-space-2);
  border-radius: var(--wb-radius-tag);
  font-weight: var(--wb-fw-medium);
  flex-shrink: 0;
  width: 48px;
  text-align: center;
  box-sizing: border-box;
  white-space: nowrap;
}

.status-active {
  background-color: var(--wb-tag-green-bg);
  color: var(--wb-green);
}

.status-pending {
  background-color: var(--wb-tag-amber-bg);
  color: var(--wb-amber);
}
</style>
