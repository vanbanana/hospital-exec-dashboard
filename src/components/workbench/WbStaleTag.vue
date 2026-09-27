<template>
  <span class="wb-stale-tag" role="status">
    <span class="wb-stale-dot"></span>
    数据未更新
    <button class="wb-stale-retry" :disabled="loading" @click="$emit('retry')">
      {{ loading ? '刷新中' : '重试' }}
    </button>
  </span>
</template>

<script setup lang="ts">
// stale 角标原语 — §10.1 stale 态：刷新失败保留旧数据时挂"数据未更新"角标 + 重试入口
defineProps<{ loading?: boolean }>()
defineEmits<{ retry: [] }>()
</script>

<style scoped>
.wb-stale-tag {
  display: inline-flex;
  align-items: center;
  align-self: flex-start;
  gap: var(--wb-space-1);
  font-size: var(--wb-fs-xs);
  font-weight: var(--wb-fw-medium);
  color: var(--wb-amber);
  background: var(--wb-tag-amber-bg);
  border-radius: var(--wb-radius-tag);
  padding: var(--wb-space-1) var(--wb-space-2);
  flex-shrink: 0;
  white-space: nowrap;
}

.wb-stale-dot {
  width: 5px;
  height: 5px;
  border-radius: var(--wb-radius-pill);
  background: var(--wb-amber);
}

.wb-stale-retry {
  border: none;
  background: transparent;
  color: var(--wb-primary);
  font-size: var(--wb-fs-xs);
  font-weight: var(--wb-fw-semibold);
  font-family: inherit;
  padding: 0;
  cursor: pointer;
}

.wb-stale-retry:disabled {
  color: var(--wb-text-4);
  cursor: default;
}
</style>
