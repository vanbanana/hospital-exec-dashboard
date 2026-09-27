<template>
  <div class="campus-stage">
    <img src="../../assets/screen/hospital_campus.jpg" alt="院区楼宇态势" class="campus-img" />
    <div class="campus-vignette"></div>

    <div
      v-for="b in buildings ?? []"
      :key="b.code"
      class="campus-pin"
      :class="`lv-${b.badge_level}`"
      :style="{ left: `${b.anchor.x}%`, top: `${b.anchor.y}%` }"
    >
      <div class="pin-card">
        <span class="pin-name">{{ b.name }}</span>
        <span class="pin-badge scr-tag" :class="`is-${b.badge_level}`">{{ b.badge }}</span>
      </div>
      <div class="pin-stem"></div>
      <div class="pin-dot" :class="{ 'is-alert': b.status === 'alert' }"></div>

      <!-- hover 楼宇指标卡（契约 metrics 键集随楼种，frontend-api §15） -->
      <div class="pin-pop">
        <div class="pop-title">{{ b.name }}</div>
        <div v-for="(v, k) in b.metrics" :key="k" class="pop-row">
          <span class="pop-label">{{ metricLabel(k) }}</span>
          <span class="pop-val scr-num">{{ v }}{{ metricUnit(k) }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { ScreenBuilding } from '../../api/types'

defineProps<{ buildings?: ScreenBuilding[] }>()

/* frontend-api §15 末表 —— 楼宇 metrics 键集的中文展示映射；未知键兜底显示原键名 */
const METRIC_LABELS: Record<string, string> = {
  today_visit: '今日就诊',
  queue_avg_min: '平均候诊',
  bed_use_rate: '床位使用率',
  bed_used: '已用床位',
  bed_open: '开放床位',
  obs_over6h: '留观>6h',
  obs_cnt: '在观人数',
  obs_max_min: '最长留观',
  device_run: '运行设备',
  device_alert: '告警设备',
}
const METRIC_UNITS: Record<string, string> = {
  today_visit: ' 人',
  queue_avg_min: ' 分',
  bed_use_rate: '%',
  bed_used: ' 床',
  bed_open: ' 床',
  obs_over6h: ' 人',
  obs_cnt: ' 人',
  obs_max_min: ' 分',
  device_run: ' 台',
  device_alert: ' 台',
}
const metricLabel = (k: string | number) => METRIC_LABELS[k] ?? k
const metricUnit = (k: string | number) => METRIC_UNITS[k] ?? ''
</script>

<style scoped>
.campus-stage {
  position: relative;
  flex: 1;
  min-height: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.campus-img {
  max-width: 100%;
  max-height: 100%;
  object-fit: contain;
  opacity: 0.94;
}

.campus-vignette {
  position: absolute;
  inset: 0;
  pointer-events: none;
  background: radial-gradient(ellipse at center, transparent 55%, rgb(from var(--p-ink-950) r g b / 0.55) 100%);
}

.campus-pin {
  position: absolute;
  transform: translate(-50%, -100%);
  display: flex;
  flex-direction: column;
  align-items: center;
  z-index: 2;
}

.pin-card {
  display: flex;
  align-items: center;
  gap: var(--scr-space-4);
  padding: var(--scr-space-3) var(--scr-space-5);
  background: rgb(from var(--p-ink-900) r g b / 0.92);
  border: 1px solid var(--scr-border-glow);
  border-radius: var(--scr-radius-card);
  box-shadow: var(--scr-shadow-panel);
  backdrop-filter: blur(8px);
  white-space: nowrap;
}

.pin-name {
  font-size: var(--scr-fs-md);
  font-weight: 600;
  color: var(--scr-text-1);
}

.pin-badge {
  font-size: var(--scr-fs-axis);
  padding: var(--scr-space-1) var(--scr-space-3);
}

.pin-stem {
  width: 1px;
  height: 10px; /* 美术稿 */
  background: linear-gradient(180deg, var(--scr-accent-bright), transparent);
}

.pin-dot {
  width: 7px; /* 美术稿 */
  height: 7px;
  border-radius: 50%;
  background: var(--scr-accent-bright);
  box-shadow: 0 0 8px var(--scr-accent-bright);
}

.campus-pin.lv-warn .pin-dot {
  background: var(--scr-warn);
  box-shadow: 0 0 8px var(--scr-warn);
}
.campus-pin.lv-alert .pin-dot {
  background: var(--scr-up);
  box-shadow: 0 0 8px var(--scr-up);
}
.campus-pin.lv-ok .pin-dot {
  background: var(--scr-down);
  box-shadow: 0 0 8px var(--scr-down);
}
.campus-pin.lv-alert .pin-card {
  border-color: rgb(from var(--p-red-500) r g b / 0.5);
  animation: scr-ping 1.6s ease-out infinite;
}

.pin-pop {
  position: absolute;
  bottom: calc(100% + 8px);
  left: 50%;
  transform: translate(-50%, 4px);
  min-width: 150px; /* 美术稿 */
  padding: var(--scr-space-5) var(--scr-space-6);
  background: rgb(from var(--p-ink-900) r g b / 0.96);
  border: 1px solid var(--scr-border-glow);
  border-radius: var(--scr-radius-card);
  box-shadow: var(--scr-shadow-panel);
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.18s, transform 0.18s;
  z-index: 5;
}

.campus-pin:hover .pin-pop {
  opacity: 1;
  transform: translate(-50%, 0);
}

.pop-title {
  font-size: var(--scr-fs-sm);
  font-weight: 600;
  color: var(--scr-accent-bright);
  margin-bottom: var(--scr-space-3);
  padding-bottom: var(--scr-space-3);
  border-bottom: 1px solid var(--scr-border);
}

.pop-row {
  display: flex;
  justify-content: space-between;
  gap: var(--scr-space-7);
  padding: var(--scr-space-1) 0;
}

.pop-label {
  font-size: var(--scr-fs-sm);
  color: var(--scr-text-3);
}

.pop-val {
  font-size: var(--scr-fs-sm);
  font-weight: 600;
  color: var(--scr-text-1);
}
</style>
