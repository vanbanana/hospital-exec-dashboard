<template>
  <header class="scr-header">
    <div class="hdr-glow"></div>

    <div class="hdr-left">
      <img class="hdr-logo" src="../../assets/workbench/hospital_logo.png" alt="院徽" />
      <div class="hdr-title">
        <h1>{{ hospitalName }}</h1>
        <span class="hdr-sub">{{ englishName }}</span>
      </div>
      <div class="hdr-tail"></div>
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
        <span class="adapt-hint">{{ adapt?.adaptMode.value === 'fill' ? 'FILL' : 'FIT' }}</span>
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
import { ref, computed, inject, watch, onMounted, onUnmounted } from 'vue'
import type { Ref } from 'vue'
import { Maximize } from 'lucide-vue-next'
import type { ScreenStatus } from '../../api/types'
import { getHospitalProfile } from '../../api/auth'

/* frontend-api §15：server_time 缺失时屏显时钟回退演示基准日 */
const BASE_FALLBACK = '2026-10-28T08:30:00+08:00'

const props = defineProps<{
  status?: ScreenStatus
  serverTime?: string
}>()

interface ScreenAdapt {
  adaptMode: Ref<'contain' | 'fill'>
  scaleX: Ref<number>
  scaleY: Ref<number>
  toggleAdaptMode: () => void
}
const adapt = inject<ScreenAdapt>('screen-adapt')

/* B8：status 缺失落 is-unknown 中性灰，不显示"正常"绿态 */
const statusClass = computed(() => ({
  'is-unknown': !props.status,
  'is-normal': props.status?.level === 'normal',
  'is-busy': props.status?.level === 'busy',
  'is-alert': props.status?.level === 'alert',
}))

/* B9：fill 模式 X/Y 双轴分别显示（如 110%×95%） */
const adaptLabel = computed(() => {
  if (!adapt) return ''
  const sx = Math.round(adapt.scaleX.value * 100)
  if (adapt.adaptMode.value === 'fill') {
    return `智能铺满 ${sx}%×${Math.round(adapt.scaleY.value * 100)}%`
  }
  return `等比自适应 ${sx}%`
})
const adaptTitle = computed(() =>
  adapt?.adaptMode.value === 'fill' ? '全屏智能铺满（无黑边），点击切换' : '等比居中（16:9 标准），点击切换'
)

/* 院名/英文副标走 hospital/profile（契约 §2.2），失败回退兜底文案——大屏不阻断；
   兜底值属品牌文案（frontend-api §15 豁免登记 C20），非契约字段 */
const hospitalName = ref('XX市人民医院')
const englishName = ref('HOSPITAL EXECUTIVE COMMAND CENTER')
onMounted(() => {
  getHospitalProfile()
    .then((d) => {
      if (d?.name) hospitalName.value = d.name
      if (d?.english_name) englishName.value = d.english_name
    })
    .catch(() => { /* 失败保留默认院名/副标，大屏无 error 态 */ })
})

/* 屏显时钟：server_time(+08:00) 按字面墙钟渲染——解析字段后以 UTC 构造/读出，
   全程不经本地时区换算（gap B7）；prop 到达时重锚 baseMs（gap B2） */
const clock = ref({ time: '--:--:--', date: '', weekday: '' })
let baseMs = 0
let mountMs = 0
let timer: number | null = null

const parseWallClock = (s: string): number | null => {
  const m = s.match(/^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})/)
  if (!m) return null
  return Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6])
}

const pad = (n: number) => String(n).padStart(2, '0')
const tick = () => {
  const now = new Date(baseMs + Date.now() - mountMs)
  clock.value = {
    time: `${pad(now.getUTCHours())}:${pad(now.getUTCMinutes())}:${pad(now.getUTCSeconds())}`,
    date: `${now.getUTCFullYear()}.${now.getUTCMonth() + 1}.${now.getUTCDate()}`,
    weekday: `星期${'日一二三四五六'[now.getUTCDay()]}`,
  }
}

watch(
  () => props.serverTime,
  (v) => {
    baseMs = parseWallClock(v || BASE_FALLBACK) ?? Date.UTC(2026, 9, 28, 0, 30, 0)
    mountMs = Date.now()
    tick()
  },
  { immediate: true }
)

onMounted(() => {
  timer = window.setInterval(tick, 1000)
})

onUnmounted(() => {
  if (timer) clearInterval(timer)
})

const toggleFullscreen = () => {
  if (!document.fullscreenElement) {
    // 全屏被浏览器拒绝（用户未交互/权限）时静默忽略，不阻断
    document.documentElement.requestFullscreen().catch(() => {})
  } else {
    document.exitFullscreen().catch(() => {}) // 同上，退出失败静默
  }
}
</script>

<style scoped>
.scr-header {
  position: relative;
  z-index: var(--scr-z-header);
  height: var(--scr-header-h);
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-inline: var(--scr-space-10);
  background: var(--scr-header-bg);
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
    var(--scr-royal) 35%,
    var(--scr-accent) 50%,
    var(--scr-royal) 65%,
    transparent 100%
  );
  opacity: var(--scr-opacity-sub);
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
  filter: drop-shadow(0 2px 6px rgb(from var(--scr-royal) r g b / 0.4));
}

.hdr-title {
  display: flex;
  flex-direction: column;
}

.hdr-title h1 {
  font-size: var(--scr-fs-21);
  font-weight: var(--scr-fw-bold);
  letter-spacing: var(--scr-ls-xl);
  color: var(--scr-text-1);
}

.hdr-sub {
  font-size: var(--scr-fs-8p5);
  font-family: var(--p-font-number);
  font-weight: var(--scr-fw-semibold);
  letter-spacing: var(--scr-ls-lg);
  color: var(--scr-text-3);
  opacity: 0.9;
}

/* REF title-tail-decoration：标题尾饰渐变线 */
.hdr-tail {
  width: 50px; /* 美术稿 */
  height: 2px;
  margin-left: var(--scr-space-3);
  align-self: center;
  background: linear-gradient(90deg, var(--scr-royal), transparent);
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

/* B8：未知态中性灰点，不发"正常"绿光 */
.status-pill.is-unknown {
  border-color: var(--scr-border);
}
.status-pill.is-unknown .status-dot {
  background: var(--scr-text-3);
  box-shadow: none;
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
  font-weight: var(--scr-fw-semibold);
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
  gap: var(--scr-space-8);
}

.adapt-pill {
  display: flex;
  align-items: center;
  gap: var(--scr-space-4);
  padding: var(--scr-space-2) var(--scr-space-5);
  background: rgb(from var(--p-ink-800) r g b / 0.85);
  border: 1px solid var(--scr-inset-border);
  border-radius: var(--scr-radius-chip);
  color: var(--scr-text-3);
  font-size: var(--scr-fs-11p5);
  letter-spacing: var(--scr-ls-sm);
  cursor: pointer;
  transition: all var(--scr-dur-normal) cubic-bezier(0.2, 0, 0, 1);
}

.adapt-pill:hover {
  border-color: var(--p-blue-600); /* 原色直取：REF hover 亮蓝边 */
  color: var(--scr-text-1);
  box-shadow: 0 0 10px rgb(from var(--scr-royal) r g b / 0.3);
}
.adapt-pill:active {
  transform: scale(0.97);
}

.adapt-dot {
  width: 6px; /* 美术稿 */
  height: 6px;
  border-radius: 50%;
  background: var(--scr-down);
  box-shadow: 0 0 5px var(--scr-down);
  transition: all var(--scr-dur-normal) ease;
}
.adapt-dot.fill {
  background: var(--scr-accent-bright);
  box-shadow: 0 0 5px var(--scr-accent-bright);
}

.adapt-text {
  font-family: var(--p-font-number);
  font-weight: var(--scr-fw-semibold);
  color: var(--scr-text-2);
}

/* REF scale-mode-hint：FIT/FILL 模式芯片 */
.adapt-hint {
  font-family: var(--p-font-number);
  font-size: var(--scr-fs-9p5);
  font-weight: var(--scr-fw-bold);
  padding: var(--scr-space-1) var(--scr-space-2);
  border-radius: var(--scr-radius-tag);
  background: rgb(from var(--scr-royal) r g b / 0.25);
  color: var(--scr-accent-bright);
  border: 1px solid rgb(from var(--p-cyan-400) r g b / 0.3);
}

.hdr-clock {
  display: flex;
  align-items: baseline;
  gap: var(--scr-space-5);
}

.clock-time {
  font-size: var(--scr-fs-title);
  font-weight: var(--scr-fw-bold);
  color: var(--scr-text-1);
  letter-spacing: var(--scr-ls-md);
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
  background: var(--scr-inset-bg);
  border: 1px solid var(--scr-inset-border);
  border-radius: var(--scr-radius-card);
  color: var(--scr-text-3);
  cursor: pointer;
  transition: all var(--scr-dur-normal);
}

.fs-btn:hover {
  background: var(--scr-royal);
  border-color: var(--p-blue-600); /* 原色直取：REF hover 亮一档蓝边 */
  color: var(--scr-text-1);
  box-shadow: 0 2px 8px rgb(from var(--scr-royal) r g b / 0.35);
}
</style>
