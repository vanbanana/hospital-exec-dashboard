<template>
  <div class="wb-empty" role="status">
    <Inbox :size="20" :stroke-width="1.8" class="wb-empty-icon" />
    <span class="wb-empty-text">{{ text }}</span>
  </div>
</template>

<script setup lang="ts">
// 空态原语 — §10.1 empty 态：表格空行 / 卡片空态 / 区块空占位通用
import { Inbox } from 'lucide-vue-next'

withDefaults(defineProps<{ text?: string }>(), { text: '暂无数据' })
</script>

<style scoped>
.wb-empty {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--wb-space-2);
  padding: var(--wb-space-4);
  color: var(--wb-text-4);
}

.wb-empty-text {
  font-size: var(--wb-fs-sm);
}
</style>
