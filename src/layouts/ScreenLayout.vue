<template>
  <div class="screen-viewport">
    <!-- 1920×1080 固定设计画布，等比 GPU 缩放居中（--scr-* 令牌作用域入口） -->
    <div class="screen-layout screen-canvas" :style="canvasStyle">
      <router-view />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, provide, onMounted, onUnmounted } from 'vue'
import '../styles/screen.css'
import { readScrCanvas } from '../components/screen/scrTokens'

/* 画布基准尺寸唯一出处：--scr-canvas-w/h（design-tokens §5），onMounted 时经 scrTokens 读取 */
const dims = ref(readScrCanvas())

const adaptMode = ref<'contain' | 'fill'>('contain')
const scaleX = ref(1)
const scaleY = ref(1)

const canvasStyle = computed(() => ({
  width: `${dims.value.w}px`,
  height: `${dims.value.h}px`,
  transform:
    adaptMode.value === 'contain'
      ? `translate(-50%, -50%) scale(${scaleX.value})`
      : `translate(-50%, -50%) scale(${scaleX.value}, ${scaleY.value})`,
}))

const updateScale = () => {
  const sx = window.innerWidth / dims.value.w
  const sy = window.innerHeight / dims.value.h
  if (adaptMode.value === 'contain') {
    scaleX.value = scaleY.value = Math.min(sx, sy)
  } else {
    scaleX.value = sx
    scaleY.value = sy
  }
}

const toggleAdaptMode = () => {
  adaptMode.value = adaptMode.value === 'contain' ? 'fill' : 'contain'
  updateScale()
}

// 顶栏适配胶囊消费（ScrHeader）
provide('screen-adapt', { adaptMode, scaleX, toggleAdaptMode })

let resizeTimer: number | null = null
const onResize = () => {
  if (resizeTimer) clearTimeout(resizeTimer)
  resizeTimer = window.setTimeout(updateScale, 60)
}

onMounted(() => {
  dims.value = readScrCanvas() // 挂载后 .screen-layout 作用域变量已解析
  updateScale()
  window.addEventListener('resize', onResize)
})

onUnmounted(() => {
  if (resizeTimer) clearTimeout(resizeTimer)
  window.removeEventListener('resize', onResize)
})
</script>

<style scoped>
.screen-viewport {
  width: 100vw;
  height: 100vh;
  overflow: hidden;
  position: relative;
  background: var(--p-ink-950); /* 原色直取：viewport 在 .screen-layout 作用域外 */
}

.screen-canvas {
  position: absolute;
  left: 50%;
  top: 50%;
  transform-origin: center center;
  overflow: hidden;
  backface-visibility: hidden;
  box-shadow: 0 0 70px rgb(from var(--p-ink-950) r g b / 0.95);
}
</style>
