<template>
  <header class="scr-header">
    <div class="hdr-glow"></div>

    <div class="hdr-left">
      <img class="hdr-logo" src="../../assets/workbench/hospital_logo.png" alt="院徽" />
      <div class="hdr-title">
        <h1>XX市人民医院</h1>
        <span class="hdr-sub">HOSPITAL EXECUTIVE COMMAND CENTER</span>
      </div>
    </div>

    <div class="hdr-center">
      <div class="status-pill" :class="statusClass">
        <span class="status-dot"></span>
        <span class="status-text">{{ status?.text ?? '态势未知' }}</span>
        <span v-if="status?.desc" class="status-desc">{{ status.desc }}</span>
      </div>
      <div v-if="status" class="alert-open">
        <span class="scr-tag is-alert">高 {{ status.alert_open.urgent }}</span>
        <span class="scr-tag is-warn">中 {{ status.alert_open.major }}</span>
        <span class="scr-tag is-info">低 {{ status.alert_open.minor }}</span>
      </div>
    </div>

    <div class="hdr-right">
      <button class="adapt-pill" type="button" :title="adaptTitle" @click="adapt?.toggleAdaptMode()">
        <span class="adapt-dot" :class="{ fill: adapt?.adaptMode.value === 'fill' }"></span>
        <span class="scr-num adapt-text">{{ adaptLabel }}</span>
      </button>

      <div class="hdr-clock">
        <span class="scr-num clock-time">{{ clock.time }}</span>
        <span class="clock-date">{{ clock.date }}</span>
        <span class="clock-week">{{ clock.weekday }}</span>
      </div>

      <button class="fs-btn" type="button" title="全屏显示 / 退出全屏" @click="toggleFullscreen">
        <Maximize :size="14" :stroke-width="2" />
      </button>
    </div>
  </header>
</template>

<script setup lang="ts">
import { ref, computed, inject, onMounted, onUnmounted } from 'vue'
import type { Ref } from 'vue'
import { Maximize } from 'lucide-vue-next'
import type { ScreenStatus } from '../../api/types'

/* frontend-api §15：server_time 缺失时屏显时钟回退演示基准日 */
const BASE_FALLBACK = '2026-10-28T08:30:00+08:00'

const props = defineProps<{
  status?: ScreenStatus
  serverTime?: string
}>()

interface ScreenAdapt {
  adaptMode: Ref<'contain' | 'fill'>
  scaleX: Ref<number>
  toggleAdaptMode: () => void
}
const adapt = inject<ScreenAdapt>('screen-adapt')

const statusClass = computed(() => ({
  'is-normal': !props.status || props.status.level === 'normal',
  'is-busy': props.status?.level === 'busy',
  'is-alert': props.status?.level === 'alert',
}))

const adaptLabel = computed(() => {
  if (!adapt) return ''
  const mode = adapt.adaptMode.value === 'fill' ? '智能铺满' : '等比自适应'
  return `${mode} ${Math.round(adapt.scaleX.value * 100)}%`
})
const adaptTitle = computed(() =>
  adapt?.adaptMode.value === 'fill' ? '全屏智能铺满（无黑边），点击切换' : '等比居中（16:9 标准），点击切换'
)

/* 屏显时钟：以契约 server_time 为源起跳，本地秒针推进 */
const clock = ref({ time: '--:--:--', date: '', weekday: '' })
let timer: number | null = null

onMounted(() => {
  const base = new Date(props.serverTime || BASE_FALLBACK)
  const baseMs = isNaN(base.getTime()) ? new Date(BASE_FALLBACK).getTime() : base.getTime()
  const mountMs = Date.now()
  const pad = (n: number) => String(n).padStart(2, '0')
  const tick = () => {
    const now = new Date(baseMs + Date.now() - mountMs)
    clock.value = {
      time: `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`,
      date: `${now.getFullYear()}.${now.getMonth() + 1}.${now.getDate()}`,
      weekday: `星期${'日一二三四五六'[now.getDay()]}`,
    }
  }
  tick()
  timer = window.setInterval(tick, 1000)
})

onUnmounted(() => {
  if (timer) clearInterval(timer)
})

const toggleFullscreen = () => {
  if (!document.fullscreenElement) {
    document.documentElement.requestFullscreen().catch(() => {})
  } else {
    document.exitFullscreen().catch(() => {})
  }
}
</script>

<style scoped>
.scr-header {
  position: relative;
  height: 64px; /* 美术稿 */
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-inline: var(--scr-space-10);
  background: linear-gradient(180deg, var(--p-ink-900), rgb(from var(--p-ink-800) r g b / 0.85));
  border-bottom: 1px solid var(--scr-border);
  box-shadow: 0 4px 16px rgb(from var(--p-ink-950) r g b / 0.5);
}

.hdr-glow {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 2px;
  background: linear-gradient(
    90deg,
    transparent 0%,
    var(--p-blue-600) 35%,
    var(--scr-accent) 50%,
    var(--p-blue-600) 65%,
    transparent 100%
  );
  opacity: 0.85;
}

.hdr-left {
  display: flex;
  align-items: center;
  gap: var(--scr-space-6);
}

.hdr-logo {
  width: 38px; /* 美术稿 */
  height: 38px;
  border-radius: 50%;
  filter: drop-shadow(0 2px 6px rgb(from var(--p-blue-600) r g b / 0.4));
}

.hdr-title {
  display: flex;
  flex-direction: column;
}

.hdr-title h1 {
  font-size: var(--scr-fs-title);
  font-weight: 700;
  letter-spacing: 1.5px;
  color: var(--scr-text-1);
}

.hdr-sub {
  font-size: var(--scr-fs-axis);
  font-family: var(--p-font-number);
  font-weight: 600;
  letter-spacing: 1.4px;
  color: var(--scr-text-3);
}

.hdr-center {
  display: flex;
  align-items: center;
  gap: var(--scr-space-7);
}

.status-pill {
  display: flex;
  align-items: center;
  gap: var(--scr-space-4);
  padding: var(--scr-space-3) var(--scr-space-7);
  border-radius: var(--scr-radius-card);
  border: 1px solid var(--scr-border-glow);
  background: rgb(from var(--p-ink-800) r g b / 0.8);
}

.status-dot {
  width: 7px; /* 美术稿 */
  height: 7px;
  border-radius: 50%;
  background: var(--scr-down);
  box-shadow: 0 0 6px var(--scr-down);
}

.status-pill.is-busy .status-dot {
  background: var(--scr-warn);
  box-shadow: 0 0 6px var(--scr-warn);
}
.status-pill.is-alert .status-dot {
  background: var(--scr-up);
  box-shadow: 0 0 6px var(--scr-up);
  animation: scr-blink 1.2s ease-in-out infinite;
}

.status-text {
  font-size: var(--scr-fs-md);
  font-weight: 600;
  color: var(--scr-text-1);
}

.status-desc {
  font-size: var(--scr-fs-sm);
  color: var(--scr-text-3);
}

.alert-open {
  display: flex;
  align-items: center;
  gap: var(--scr-space-3);
}

.hdr-right {
  display: flex;
  align-items: center;
  gap: var(--scr-space-7);
}

.adapt-pill {
  display: flex;
  align-items: center;
  gap: var(--scr-space-4);
  padding: var(--scr-space-2) var(--scr-space-5);
  background: rgb(from var(--p-ink-800) r g b / 0.85);
  border: 1px solid var(--scr-border);
  border-radius: 12px; /* 美术稿：胶囊 */
  color: var(--scr-text-3);
  font-size: var(--scr-fs-sm);
  cursor: pointer;
  transition: border-color 0.2s, color 0.2s;
}

.adapt-pill:hover {
  border-color: var(--scr-border-glow);
  color: var(--scr-text-1);
}

.adapt-dot {
  width: 6px; /* 美术稿 */
  height: 6px;
  border-radius: 50%;
  background: var(--scr-down);
  box-shadow: 0 0 5px var(--scr-down);
}
.adapt-dot.fill {
  background: var(--scr-accent-bright);
  box-shadow: 0 0 5px var(--scr-accent-bright);
}

.adapt-text {
  font-weight: 600;
  color: var(--scr-text-2);
}

.hdr-clock {
  display: flex;
  align-items: baseline;
  gap: var(--scr-space-5);
}

.clock-time {
  font-size: var(--scr-fs-title);
  font-weight: 700;
  color: var(--scr-text-1);
  letter-spacing: 1px;
}

.clock-date,
.clock-week {
  font-size: var(--scr-fs-md);
  color: var(--scr-text-3);
}

.fs-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--scr-space-3);
  background: var(--p-ink-800);
  border: 1px solid var(--scr-border);
  border-radius: var(--scr-radius-card);
  color: var(--scr-text-3);
  cursor: pointer;
  transition: color 0.2s, border-color 0.2s;
}

.fs-btn:hover {
  color: var(--scr-text-1);
  border-color: var(--scr-border-glow);
}
</style>
