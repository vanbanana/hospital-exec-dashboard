<template>
  <ScrPanel title="实时告警" :sub="total !== undefined ? `未闭环 ${total}` : ''">
    <div v-if="list && list.length" class="alert-feed">
      <div class="feed-track">
        <div v-for="a in feedItems" :key="a.key" class="feed-item" :class="`lv-${a.level}`">
          <span class="scr-tag" :class="levelClass(a.level)">{{ levelText(a.level) }}</span>
          <div class="feed-main">
            <span class="feed-title">{{ a.title }}</span>
            <span class="feed-meta">{{ a.dept }} · {{ fmtTime(a.occurred_at) }}</span>
          </div>
        </div>
      </div>
    </div>
    <div v-else class="scr-empty">当前无未闭环告警</div>
  </ScrPanel>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import ScrPanel from './ScrPanel.vue'
import type { AlertLevel, ScreenAlert } from '../../api/types'

const props = defineProps<{
  list?: ScreenAlert[]
  total?: number
}>()

/* 契约 §1.4-2：API 英文枚举 → 展示中文 高/中/低 */
const levelText = (lv: AlertLevel) => ({ urgent: '高', major: '中', minor: '低' })[lv] ?? lv
const levelClass = (lv: AlertLevel) =>
  ({ urgent: 'is-alert', major: 'is-warn', minor: 'is-info' })[lv] ?? 'is-info'

const fmtTime = (iso: string) => {
  const d = new Date(iso)
  if (isNaN(d.getTime())) return iso
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
}

/* 纵向跑马灯：内容复制一遍做无缝循环（scr-scroll-y 平移 -50%） */
const feedItems = computed(() =>
  (props.list ?? []).flatMap((a) => [
    { ...a, key: `${a.id}-a` },
    { ...a, key: `${a.id}-b` },
  ])
)
</script>

<style scoped>
.alert-feed {
  flex: 1;
  min-height: 0;
  overflow: hidden;
  position: relative;
}

.feed-track {
  display: flex;
  flex-direction: column;
  animation: scr-scroll-y 22s linear infinite;
}

.alert-feed:hover .feed-track {
  animation-play-state: paused;
}

.feed-item {
  display: flex;
  align-items: center;
  gap: var(--scr-space-5);
  padding: var(--scr-space-5) var(--scr-space-1);
  border-bottom: 1px solid rgb(from var(--p-white) r g b / 0.05);
}

.feed-item.lv-urgent .feed-title {
  color: var(--scr-up);
}

.feed-main {
  display: flex;
  flex-direction: column;
  gap: var(--scr-space-1);
  min-width: 0;
}

.feed-title {
  font-size: var(--scr-fs-md);
  color: var(--scr-text-2);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.feed-meta {
  font-size: var(--scr-fs-sm);
  color: var(--scr-text-4);
}
</style>
