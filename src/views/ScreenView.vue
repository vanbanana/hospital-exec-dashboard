<template>
  <div class="viewport-root">
    <div
      ref="dashboardRef"
      class="screen-wrapper"
      :style="scaleStyle"
    >
      <!-- 1. Header Banner (88px) -->
      <HeaderBanner />

      <!-- 2. Main Middle Area (868px) -->
      <main class="dashboard-body">
        <!-- Left Column (526px) -->
        <aside class="col-left">
          <KpiCards />
          <DrgDipAnalysis />
        </aside>

        <!-- Center Column (940px) -->
        <section class="col-center">
          <CampusMap />
          <ValuePillars />
        </section>

        <!-- Right Column (526px) -->
        <aside class="col-right">
          <DepartmentRanking />
          <WarningAlerts />
        </aside>
      </main>

      <!-- 3. Bottom Trend Charts (196px) -->
      <footer class="dashboard-bottom">
        <TrendCharts />
      </footer>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed, provide } from 'vue'
import HeaderBanner from '../components/HeaderBanner.vue'
import KpiCards from '../components/KpiCards.vue'
import DrgDipAnalysis from '../components/DrgDipAnalysis.vue'
import CampusMap from '../components/CampusMap.vue'
import ValuePillars from '../components/ValuePillars.vue'
import DepartmentRanking from '../components/DepartmentRanking.vue'
import WarningAlerts from '../components/WarningAlerts.vue'
import TrendCharts from '../components/TrendCharts.vue'
import { getScreenSnapshot } from '../api/screen'
import type { ScreenSnapshotResp } from '../api/types'

const dashboardRef = ref<HTMLElement | null>(null)
const scale = ref(1)

// §14.1 快照在视图层取数；旧大屏组件（src/components/*.vue）冻结期由视图 provide，
// 整合进主工程时各面板改 inject 消费
const snapshot = ref<ScreenSnapshotResp | null>(null)
provide('screenSnapshot', snapshot)

const BASE_WIDTH = 2048
const BASE_HEIGHT = 1152

const updateScale = () => {
  const windowWidth = window.innerWidth
  const windowHeight = window.innerHeight
  const scaleX = windowWidth / BASE_WIDTH
  const scaleY = windowHeight / BASE_HEIGHT
  scale.value = Math.min(scaleX, scaleY)
}

const scaleStyle = computed(() => {
  return {
    width: `${BASE_WIDTH}px`,
    height: `${BASE_HEIGHT}px`,
    transform: `scale(${scale.value})`,
    transformOrigin: 'center center',
  }
})

const loadSnapshot = async () => {
  snapshot.value = await getScreenSnapshot()
}

onMounted(() => {
  updateScale()
  window.addEventListener('resize', updateScale)
  loadSnapshot()
})

onUnmounted(() => {
  window.removeEventListener('resize', updateScale)
})
</script>

<style scoped>
.viewport-root {
  width: 100vw;
  height: 100vh;
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: #010a15;
}

.screen-wrapper {
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  box-shadow: 0 0 50px rgba(0, 0, 0, 0.95);
}

.dashboard-body {
  display: flex;
  gap: 16px;
  padding: 20px 20px 0 20px;
  width: 100%;
  height: 862px;
}

.col-left {
  width: 514px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.col-center {
  width: 948px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.col-right {
  width: 514px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.dashboard-bottom {
  padding: 14px 20px 16px 20px;
  width: 100%;
  height: 202px;
}
</style>
