<template>
  <header class="header-container">
    <!-- Top Glowing Horizontal Neon Line -->
    <div class="header-glow-bar"></div>

    <div class="header-inner">
      <!-- Left: Logo & Title -->
      <div class="header-left">
        <div class="logo-shield">
          <svg viewBox="0 0 32 32" class="shield-svg">
            <polygon points="16,2 30,8 30,22 16,30 2,22 2,8" class="shield-border" />
            <path d="M16 7 L16 25 M7 16 L25 16" class="cross-path" />
          </svg>
        </div>
        <div class="title-wrap">
          <h1 class="main-title">智慧医院综合管理平台</h1>
          <span class="sub-title">SMART HOSPITAL MANAGEMENT PLATFORM</span>
        </div>
        <div class="title-tail-decoration"></div>
      </div>

      <!-- Center: Navigation Tabs (8 Modules) -->
      <nav class="nav-tabs">
        <button
          v-for="tab in tabs"
          :key="tab.id"
          class="nav-tab-btn"
          :class="{ active: currentTab === tab.id }"
          @click="$emit('update:currentTab', tab.id)"
        >
          <span class="tab-label">{{ tab.name }}</span>
          <div class="tab-glow" v-if="currentTab === tab.id"></div>
          <div class="tab-bottom-notch" v-if="currentTab === tab.id"></div>
        </button>
      </nav>

      <!-- Right: Clock, Date, Scale Indicator & Tools -->
      <div class="header-right">
        <!-- Proportional Scale Indicator Badge with Click-to-Switch Mode -->
        <button
          type="button"
          class="scale-indicator-pill clickable-pill"
          :title="`当前模式: ${adaptMode === 'fill' ? '全屏智能铺满 (无黑边)' : '等比居中 (16:9标准)'}，缩放率: ${scalePercent || 100}%。点击切换适配模式`"
          @click="$emit('toggleAdaptMode')"
        >
          <span class="scale-dot" :class="{ 'scale-dot-fill': adaptMode === 'fill' }"></span>
          <span class="scale-text">{{ adaptMode === 'fill' ? '智能铺满' : '等比自适应' }} {{ scalePercent || 100 }}%</span>
          <span class="scale-mode-hint">{{ adaptMode === 'fill' ? 'FILL' : 'FIT' }}</span>
        </button>

        <div class="time-display">
          <span class="digital-time">{{ currentTime }}</span>
          <span class="date-text">{{ currentDate }}</span>
          <span class="weekday-text">{{ currentWeekday }}</span>
        </div>

        <button class="fullscreen-btn" @click="toggleFullscreen" title="全屏显示 / 退出全屏">
          <svg viewBox="0 0 24 24" width="15" height="15" stroke="currentColor" stroke-width="2" fill="none">
            <path d="M8 3H5a2 2 0 0 0-2 2v3m18 0V5a2 2 0 0 0-2-2h-3m0 18h3a2 2 0 0 0 2-2v-3M3 16v3a2 2 0 0 0 2 2h3" />
          </svg>
        </button>
      </div>
    </div>
  </header>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'

defineProps<{
  currentTab: string
  scalePercent?: number
  adaptMode?: 'contain' | 'fill'
}>()

defineEmits<{
  (e: 'update:currentTab', id: string): void
  (e: 'toggleAdaptMode'): void
}>()

const tabs = [
  { id: 'overview', name: '总体态势' },
  { id: 'epidemic', name: '病情防控' },
  { id: 'energy', name: '能源管理' },
  { id: 'security', name: '安防管理' },
  { id: 'logistics', name: '智慧后勤' },
  { id: 'transit', name: '便捷出行' },
  { id: 'emergency', name: '应急救援' },
  { id: 'revenue', name: '医疗营收' }
]

const currentTime = ref('13:03:45')
const currentDate = ref('2025.4.1')
const currentWeekday = ref('星期二')

let timer: number | null = null

const updateClock = () => {
  const now = new Date()
  const pad = (n: number) => n.toString().padStart(2, '0')
  currentTime.value = `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`
  const weekdays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六']
  currentWeekday.value = weekdays[now.getDay()]
  currentDate.value = `${now.getFullYear()}.${now.getMonth() + 1}.${now.getDate()}`
}

const toggleFullscreen = () => {
  if (!document.fullscreenElement) {
    document.documentElement.requestFullscreen().catch(() => {})
  } else {
    document.exitFullscreen().catch(() => {})
  }
}

onMounted(() => {
  updateClock()
  timer = window.setInterval(updateClock, 1000)
})

onUnmounted(() => {
  if (timer) clearInterval(timer)
})
</script>

<style scoped>
.header-container {
  height: 64px;
  width: 1920px;
  background: linear-gradient(180deg, #0b1325 0%, #101a30 70%, #0c1428 100%);
  position: relative;
  z-index: 100;
  border-bottom: 1px solid var(--border-panel);
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4);
  flex-shrink: 0;
}

.header-glow-bar {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 2px;
  background: linear-gradient(90deg, transparent 0%, #1e65eb 35%, #00b4d8 50%, #1e65eb 65%, transparent 100%);
  opacity: 0.85;
}

.header-inner {
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 24px;
}

/* Left: Logo & Title */
.header-left {
  display: flex;
  align-items: center;
  gap: 12px;
  position: relative;
}

.logo-shield {
  width: 38px;
  height: 38px;
  display: flex;
  align-items: center;
  justify-content: center;
  filter: drop-shadow(0 2px 6px rgba(30, 101, 235, 0.4));
}

.shield-svg {
  width: 100%;
  height: 100%;
}

.shield-border {
  fill: rgba(30, 101, 235, 0.16);
  stroke: #1e65eb;
  stroke-width: 2.2;
}

.cross-path {
  stroke: #ffffff;
  stroke-width: 3.5;
  stroke-linecap: round;
}

.title-wrap {
  display: flex;
  flex-direction: column;
}

.main-title {
  font-size: 21px;
  font-weight: 700;
  letter-spacing: 1.5px;
  color: #ffffff;
  -webkit-text-fill-color: #ffffff;
  text-shadow: none;
}

.sub-title {
  font-size: 8.5px;
  font-family: 'Rajdhani', monospace;
  font-weight: 600;
  letter-spacing: 1.4px;
  color: #8fa0bf;
  opacity: 0.9;
}

.title-tail-decoration {
  width: 50px;
  height: 2px;
  background: linear-gradient(90deg, #1e65eb, transparent);
  margin-left: 6px;
}

/* Center: Tabs */
.nav-tabs {
  display: flex;
  align-items: center;
  gap: 6px;
  background: rgba(13, 23, 46, 0.85);
  padding: 4px 8px;
  border-radius: 4px;
  border: 1px solid #192c55;
}

.nav-tab-btn {
  position: relative;
  background: transparent;
  border: 1px solid transparent;
  color: #8fa0bf;
  font-size: 13.5px;
  font-weight: 500;
  padding: 6px 14px;
  cursor: pointer;
  transition: all 0.2s ease;
  border-radius: 3px;
}

.nav-tab-btn:hover {
  color: #ffffff;
  background: rgba(30, 101, 235, 0.15);
}

.nav-tab-btn.active {
  color: #ffffff;
  font-weight: 600;
  background: linear-gradient(180deg, #1e65eb 0%, #1345b5 100%);
  border: 1px solid #2563eb;
  box-shadow: 0 2px 8px rgba(30, 101, 235, 0.35);
  text-shadow: none;
}

.tab-glow,
.tab-bottom-notch {
  display: none;
}

/* Right: Scale Indicator, Clock & Tools */
.header-right {
  display: flex;
  align-items: center;
  gap: 16px;
}

.scale-indicator-pill {
  display: flex;
  align-items: center;
  gap: 7px;
  padding: 4px 10px;
  background: rgba(18, 32, 58, 0.85);
  border: 1px solid #1c3664;
  border-radius: 12px;
  font-size: 11.5px;
  color: #8fa0bf;
  letter-spacing: 0.3px;
  cursor: pointer;
  outline: none;
  transition: all 0.2s cubic-bezier(0.2, 0, 0, 1);
}

.scale-indicator-pill:hover {
  background: rgba(28, 50, 90, 0.95);
  border-color: #2563eb;
  color: #ffffff;
  box-shadow: 0 0 10px rgba(30, 101, 235, 0.3);
}

.scale-indicator-pill:active {
  transform: scale(0.97);
}

.scale-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background-color: #10b981;
  box-shadow: 0 0 6px #10b981;
  transition: all 0.2s ease;
}

.scale-dot-fill {
  background-color: #38bdf8;
  box-shadow: 0 0 6px #38bdf8;
}

.scale-text {
  font-family: var(--font-number);
  font-weight: 600;
  color: #cbd5e1;
}

.scale-mode-hint {
  font-size: 9.5px;
  font-weight: 700;
  padding: 1px 4px;
  border-radius: 3px;
  background: rgba(30, 101, 235, 0.25);
  color: #38bdf8;
  border: 1px solid rgba(56, 189, 248, 0.3);
}

.time-display {
  display: flex;
  align-items: baseline;
  gap: 10px;
}

.digital-time {
  font-family: var(--font-number);
  font-size: 20px;
  font-weight: 700;
  color: #ffffff;
  letter-spacing: 1px;
}

.date-text, .weekday-text {
  font-size: 13px;
  font-weight: 500;
  color: #8fa0bf;
}

.fullscreen-btn {
  background: #132244;
  border: 1px solid #192c55;
  color: #8fa0bf;
  padding: 6px;
  border-radius: 4px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
}

.fullscreen-btn:hover {
  background: #1e65eb;
  border-color: #2563eb;
  color: #ffffff;
  box-shadow: 0 2px 8px rgba(30, 101, 235, 0.35);
}
</style>
