<template>
  <div class="top10-card">
    <div class="card-header">
      <div class="header-title-box">
        <h3 class="card-title">科室业务量 TOP10</h3>
        <span v-if="metricName" class="card-subtitle">（{{ metricName }}）</span>
      </div>
      <router-link to="/workbench/medical" class="more-link">更多 &gt;</router-link>
    </div>

    <WbErrorPanel v-if="error && data === null" :error="error" :loading="loading" @retry="reload" />
    <WbSkeleton v-else-if="data === null && loading" :rows="8" />
    <WbEmpty v-else-if="!items.length" text="暂无排行数据" />
    <div v-else class="ranking-list">
      <WbStaleTag v-if="stale" :loading="loading" @retry="reload" />
      <div
        v-for="item in items"
        :key="item.rank"
        class="ranking-item"
      >
        <span
          class="rank-badge"
          :class="getRankClass(item.rank)"
        >
          {{ item.rank }}
        </span>
        <span class="dept-name">{{ item.name }}</span>
        <div class="bar-track">
          <div
            class="bar-fill"
            :style="{ width: `${(item.value / maxVal) * 100}%` }"
          ></div>
        </div>
        <span class="dept-val wb-num">{{ item.value.toLocaleString('en-US') }}</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { getHomeTop10 } from '../../api/workbench'
import { useAsyncData } from '../../api/useAsyncData'
import WbSkeleton from './WbSkeleton.vue'
import WbErrorPanel from './WbErrorPanel.vue'
import WbEmpty from './WbEmpty.vue'
import WbStaleTag from './WbStaleTag.vue'

// 五态取数经 useAsyncData（frontend-architecture §10.1）
const { data, loading, error, stale, reload } = useAsyncData(getHomeTop10)
onMounted(reload)

const items = computed(() => data.value?.list ?? [])
const metricName = computed(() => data.value?.metric_name ?? '')
// 条形归一化除数兜底 1 防除零
const maxVal = computed(() => data.value?.max_val || 1)

// 金银铜奖牌色，辨识度高于近色系
const getRankClass = (rank: number) => {
  if (rank === 1) return 'rank-gold'
  if (rank === 2) return 'rank-silver'
  if (rank === 3) return 'rank-bronze'
  return 'rank-normal'
}
</script>

<style scoped>
.top10-card {
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
  align-items: baseline;
  justify-content: space-between;
  margin-bottom: var(--wb-space-2);
}

.header-title-box {
  display: flex;
  align-items: baseline;
  gap: var(--wb-space-1);
}

.card-title {
  font-size: var(--wb-fs-lg);
  font-weight: var(--wb-fw-bold);
  color: var(--wb-navy);
  margin: 0;
  letter-spacing: 0.3px;
}

.card-subtitle {
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-3);
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

.ranking-list {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  flex: 1;
}

.ranking-item {
  display: flex;
  align-items: center;
  gap: var(--wb-space-2);
  padding: var(--wb-space-1) 0;
}

.rank-badge {
  width: 17px;
  height: 17px;
  border-radius: var(--wb-radius-tag);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: var(--wb-fs-xs);
  font-weight: var(--wb-fw-bold);
  flex-shrink: 0;
}

.rank-gold {
  background-color: var(--wb-rank-1);
  color: var(--p-white);
}

.rank-silver {
  background-color: var(--wb-rank-2);
  color: var(--p-white);
}

.rank-bronze {
  background-color: var(--wb-rank-3);
  color: var(--p-white);
}

.rank-normal {
  background-color: var(--wb-tag-gray-bg);
  color: var(--wb-text-3);
}

.dept-name {
  width: 110px;
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-1);
  font-weight: var(--wb-fw-medium);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  flex-shrink: 0;
}

.bar-track {
  flex: 1;
  height: 8px;
  background-color: var(--wb-bar-track);
  border-radius: var(--wb-radius-tag);
  overflow: hidden;
}

.bar-fill {
  height: 100%;
  background-color: var(--wb-accent);
  border-radius: var(--wb-radius-tag);
  transition: width var(--wb-dur-normal) ease;
}

.dept-val {
  width: 30px;
  text-align: right;
  font-size: var(--wb-fs-sm);
  font-weight: var(--wb-fw-semibold);
  color: var(--wb-text-1);
  flex-shrink: 0;
}
</style>
