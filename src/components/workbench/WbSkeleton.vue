<template>
  <div class="wb-skel" role="status" aria-label="加载中">
    <div v-for="i in rows" :key="i" class="wb-skel-row"></div>
  </div>
</template>

<script setup lang="ts">
// 加载占位原语 — §10.1 loading 态：骨架条脉冲占位，不闪现空数据尖峰
withDefaults(defineProps<{ rows?: number }>(), { rows: 4 })
</script>

<style scoped>
.wb-skel {
  flex: 1;
  min-width: 0;
  min-height: 0;
  display: flex;
  flex-direction: column;
  justify-content: space-evenly;
  gap: var(--wb-space-3);
  padding: var(--wb-space-2) 0;
}

.wb-skel-row {
  height: var(--wb-space-3);
  border-radius: var(--wb-radius-tag);
  background: var(--wb-bar-track);
  animation: wb-skel-pulse calc(var(--wb-dur-normal) * 6) ease-in-out infinite;
}

.wb-skel-row:last-child {
  width: 62%;
}

@keyframes wb-skel-pulse {
  0%,
  100% {
    opacity: 1;
  }
  50% {
    opacity: var(--wb-opacity-dimmed);
  }
}
</style>
