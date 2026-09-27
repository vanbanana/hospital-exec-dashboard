<template>
  <div class="wb-error-panel" role="alert">
    <AlertCircle :size="22" :stroke-width="1.8" class="wb-error-icon" />
    <p class="wb-error-text">{{ error?.message || '加载失败，请稍后重试' }}</p>
    <p v-if="error" class="wb-error-meta wb-num">
      code {{ error.code }}<template v-if="error.trace_id"> · trace {{ error.trace_id }}</template>
    </p>
    <button class="wb-error-retry" :disabled="loading" @click="$emit('retry')">
      <RefreshCw :size="12" :stroke-width="2" />
      {{ loading ? '加载中' : '重试' }}
    </button>
  </div>
</template>

<script setup lang="ts">
// 面板级错误态原语 — §10.1 error/retry 态：错误信息 + code/trace_id + 显式重试入口
import { AlertCircle, RefreshCw } from 'lucide-vue-next'
import type { ApiError } from '../../api/useAsyncData'

defineProps<{ error: ApiError | null; loading?: boolean }>()
defineEmits<{ retry: [] }>()
</script>

<style scoped>
.wb-error-panel {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--wb-space-2);
  padding: var(--wb-space-4);
  text-align: center;
}

.wb-error-icon {
  color: var(--wb-amber);
}

.wb-error-text {
  font-size: var(--wb-fs-md);
  color: var(--wb-text-2);
}

.wb-error-meta {
  font-size: var(--wb-fs-xs);
  color: var(--wb-text-4);
}

.wb-error-retry {
  display: inline-flex;
  align-items: center;
  gap: var(--wb-space-1);
  margin-top: var(--wb-space-1);
  border: 1px solid var(--wb-input-border);
  border-radius: var(--wb-radius-inner);
  background: var(--wb-surface);
  color: var(--wb-primary);
  font-size: var(--wb-fs-sm);
  font-weight: var(--wb-fw-medium);
  font-family: inherit;
  padding: var(--wb-space-1) var(--wb-space-3);
  cursor: pointer;
  transition: all var(--wb-dur-fast);
}

.wb-error-retry:hover:not(:disabled) {
  border-color: var(--wb-accent);
  background: var(--wb-accent-soft);
}

.wb-error-retry:disabled {
  color: var(--wb-text-4);
  cursor: default;
}
</style>
