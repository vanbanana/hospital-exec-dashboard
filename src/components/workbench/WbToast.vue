<script lang="ts">
// 轻量全局提示等价物 — error-codes §4 ElMessage 语义的 token 化替代
// 模块级队列:无全局挂载位(App.vue 不归本 epic),各写操作宿主内 <WbToast/> 渲染同一队列
import { computed, reactive, shallowRef } from 'vue'

export interface WbToastItem {
  id: number
  text: string
  tone: 'success' | 'warning' | 'error'
}

const toasts = reactive<WbToastItem[]>([])
let seq = 0
// 渲染占位:多宿主同页挂载时先到先渲,其余空渲——否则同一队列被渲 N 遍。
// owner 必须 shallowRef:ref 会深响应化 .value,存的是 token 的 reactive 代理,
// owner.value===token 恒 false → 无任何实例是 owner → Toast 栈永不渲染(V3 实测 DOM 缺失)
const owner = shallowRef<object | null>(null)

function push(text: string, tone: WbToastItem['tone']) {
  const id = ++seq
  toasts.push({ id, text, tone })
  setTimeout(() => {
    const i = toasts.findIndex((t) => t.id === id)
    if (i >= 0) toasts.splice(i, 1)
  }, 3000)
}

export function useToast() {
  const token = {}
  // 经函数写值:分支内直接赋值会被 TS 收窄(owner.value===null 后视为 null)报错
  const setOwner = (v: object | null) => {
    owner.value = v
  }
  // computed 内惰性认领(首实例求值即占),占位释放→响应式重算→自动接管
  const isOwner = computed(() => {
    if (owner.value === null) setOwner(token)
    return owner.value === token
  })
  const release = () => {
    if (owner.value === token) setOwner(null)
  }
  return { toasts, isOwner, release, push }
}

export const toast = {
  success: (text: string) => push(text, 'success'),
  warning: (text: string) => push(text, 'warning'),
  error: (text: string) => push(text, 'error'),
}
</script>

<script setup lang="ts">
import { onUnmounted } from 'vue'

const { toasts, isOwner, release } = useToast()
onUnmounted(release)
</script>

<template>
  <Teleport v-if="isOwner" to="body">
    <div class="wb-toast-stack">
      <TransitionGroup name="wb-toast">
        <div v-for="t in toasts" :key="t.id" class="wb-toast-item" :class="`tone-${t.tone}`">
          {{ t.text }}
        </div>
      </TransitionGroup>
    </div>
  </Teleport>
</template>

<style scoped>
.wb-toast-stack {
  position: fixed;
  top: 24px;
  right: 24px;
  /* 置顶档:盖过弹层(令牌阶梯 toast=5) */
  z-index: var(--wb-z-toast);
  display: flex;
  flex-direction: column;
  gap: var(--wb-space-2);
  pointer-events: none;
}

.wb-toast-item {
  pointer-events: auto;
  min-width: 180px;
  max-width: 320px;
  background: var(--wb-surface);
  border: 1px solid var(--wb-border);
  border-radius: var(--wb-radius-card);
  box-shadow: var(--wb-shadow-card);
  padding: var(--wb-space-2) var(--wb-space-3);
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-1);
  border-left: 3px solid var(--wb-text-4);
}

.tone-success {
  border-left-color: var(--wb-green);
}
.tone-warning {
  border-left-color: var(--wb-amber);
}
.tone-error {
  border-left-color: var(--wb-red);
}

.wb-toast-enter-active,
.wb-toast-leave-active,
.wb-toast-move {
  transition: opacity var(--wb-dur-fast), transform var(--wb-dur-fast);
}
.wb-toast-enter-from,
.wb-toast-leave-to {
  opacity: 0;
  transform: translateX(12px);
}
</style>
