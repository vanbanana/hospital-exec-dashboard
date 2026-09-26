<template>
  <div class="screen-adapter-viewport">
    <!-- Fixed 1920x1080 Design Canvas with Proportional GPU Scale -->
    <div
      class="screen-canvas"
      :style="canvasStyle"
    >
      <!-- Top Futuristic Navigation Header -->
      <HeaderNav
        :currentTab="currentTab"
        :scalePercent="Math.round(scaleX * 100)"
        :adaptMode="adaptMode"
        @update:currentTab="handleTabChange"
        @toggleAdaptMode="toggleAdaptMode"
      />

      <!-- Main View Area (1920 x 1016 px) with Smooth View Transitions -->
      <main class="main-viewport">
        <transition name="view-fade" mode="out-in">
          <component :is="activeComponent" :key="currentTab" />
        </transition>
      </main>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import HeaderNav from './components/HeaderNav.vue'
import OverviewView from './views/OverviewView.vue'
import EpidemicControlView from './views/EpidemicControlView.vue'
import SecurityView from './views/SecurityView.vue'
import LogisticsView from './views/LogisticsView.vue'

const DESIGN_WIDTH = 1920
const DESIGN_HEIGHT = 1080

const currentTab = ref('overview')
const adaptMode = ref<'contain' | 'fill'>('contain')
const scaleX = ref(1)
const scaleY = ref(1)

const handleTabChange = (tabId: string) => {
  currentTab.value = tabId
}

const toggleAdaptMode = () => {
  adaptMode.value = adaptMode.value === 'contain' ? 'fill' : 'contain'
  updateScale()
}

const activeComponent = computed(() => {
  switch (currentTab.value) {
    case 'overview':
      return OverviewView
    case 'epidemic':
      return EpidemicControlView
    case 'energy':
      return OverviewView
    case 'security':
      return SecurityView
    case 'logistics':
      return LogisticsView
    case 'transit':
      return LogisticsView
    case 'emergency':
      return SecurityView
    case 'revenue':
      return EpidemicControlView
    default:
      return OverviewView
  }
})

const canvasStyle = computed(() => {
  const transform = adaptMode.value === 'contain'
    ? `translate(-50%, -50%) scale(${scaleX.value})`
    : `translate(-50%, -50%) scale(${scaleX.value}, ${scaleY.value})`

  return {
    transform,
    width: `${DESIGN_WIDTH}px`,
    height: `${DESIGN_HEIGHT}px`
  }
})

let isInternalResize = false
let resizeTimeout: number | null = null

const updateScale = () => {
  const windowW = window.innerWidth
  const windowH = window.innerHeight
  const sx = windowW / DESIGN_WIDTH
  const sy = windowH / DESIGN_HEIGHT

  if (adaptMode.value === 'contain') {
    const s = Math.min(sx, sy)
    scaleX.value = s
    scaleY.value = s
  } else {
    scaleX.value = sx
    scaleY.value = sy
  }

  // Safely broadcast cockpit-resize to all chart instances without triggering infinite window.resize loop
  isInternalResize = true
  window.dispatchEvent(new CustomEvent('cockpit-resize', {
    detail: { scaleX: scaleX.value, scaleY: scaleY.value, mode: adaptMode.value }
  }))
  isInternalResize = false
}

const onWindowResize = (e: Event) => {
  if (isInternalResize) return
  if (resizeTimeout) clearTimeout(resizeTimeout)
  resizeTimeout = window.setTimeout(updateScale, 60)
}

onMounted(() => {
  updateScale()
  window.addEventListener('resize', onWindowResize)
})

onUnmounted(() => {
  if (resizeTimeout) clearTimeout(resizeTimeout)
  window.removeEventListener('resize', onWindowResize)
})
</script>

<style scoped>
.screen-adapter-viewport {
  width: 100vw;
  height: 100vh;
  overflow: hidden;
  background-color: #060b17;
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
}

.screen-canvas {
  position: absolute;
  left: 50%;
  top: 50%;
  transform-origin: center center;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  background-color: var(--bg-dark);
  box-shadow: 0 0 70px rgba(0, 0, 0, 0.95);
  backface-visibility: hidden;
  -webkit-font-smoothing: antialiased;
}

.main-viewport {
  flex: 1;
  width: 1920px;
  height: 1016px;
  position: relative;
  overflow: hidden;
}

.view-fade-enter-active,
.view-fade-leave-active {
  transition: opacity 0.22s ease, transform 0.22s ease;
}

.view-fade-enter-from {
  opacity: 0;
  transform: scale(0.994);
}

.view-fade-leave-to {
  opacity: 0;
  transform: scale(1.006);
}
</style>
