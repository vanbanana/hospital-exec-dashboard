<template>
  <div class="campus-stage">
    <img src="../../assets/screen/hospital_campus.jpg" alt="院区楼宇态势" class="campus-img" />
    <div class="stage-vignette"></div>

    <!-- pin 坐标系：.pin-layer 与 cover 渲染后图像矩形同盒（契约 anchor = 图像矩形内 %，§14.1 注7） -->
    <div class="pin-layer">
      <div
        v-for="b in buildings ?? []"
        :key="b.code"
        class="campus-pin"
        :class="{ 'pop-below': needsPopBelow(b) }"
        :style="{ left: `${b.anchor.x}%`, top: `${b.anchor.y}%` }"
      >
        <div class="pin-card" :class="{ 'is-alert': b.status === 'alert' }">
          <component :is="iconOf(b.code)" :size="15" :stroke-width="2" class="pin-icon" />
          <span class="pin-name">{{ b.name }}</span>
          <span class="pin-badge scr-tag" :class="`is-${b.badge_level}`">{{ b.badge }}</span>
          <span v-if="b.status === 'alert'" class="pin-beacon"></span>
        </div>
        <div class="pin-stem" :class="{ 'is-alert': b.status === 'alert' }"></div>
        <div class="pin-pulse" :class="{ 'is-alert': b.status === 'alert' }"></div>

        <!-- hover 楼宇指标卡（契约 metrics 键集随楼种，frontend-api §15 末表） -->
        <div class="pin-pop">
          <div class="pop-title">{{ b.name }}</div>
          <div v-for="(v, k) in b.metrics" :key="k" class="pop-row">
            <span class="pop-label">{{ metricLabel(k) }}</span>
            <span class="pop-val scr-num">{{ v }}{{ metricUnit(k) }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import type { Component } from 'vue'
import { Ambulance, Building2, Microscope, Scissors, Stethoscope } from 'lucide-vue-next'
import type { ScreenBuilding } from '../../api/types'

defineProps<{ buildings?: ScreenBuilding[] }>()

/* B12：anchor.y（图像%）小于阈值时弹层翻到 pin 下方，防顶裁 */
const POP_FLIP_Y = 21
const needsPopBelow = (b: ScreenBuilding) => b.anchor.y < POP_FLIP_Y

/* 楼宇图标位（A8 对齐 REF pin 形态；未知 code 落 Building2） */
const iconOf = (code: string): Component => {
  const map: Record<string, Component> = {
    mz: Stethoscope,
    wk: Scissors,
    jz: Ambulance,
    yj: Microscope,
  }
  return map[code] ?? Building2
}

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
/* .campus-stage/.campus-img/.stage-vignette/.pin-layer 布局与材质在 screen.css 浮层布局区块 */

.campus-pin {
  position: absolute;
  transform: translate(-50%, -100%); /* 锚点 = pin 底缘中心，pulse 光斑落楼宇点 */
  display: flex;
  flex-direction: column;
  align-items: center;
  z-index: var(--scr-z-pin);
  transition: transform var(--scr-dur-pop) ease;
}

.campus-pin:hover {
  transform: translate(-50%, -108%) scale(1.06); /* REF 上浮 8% + 放大 */
}

.pin-card {
  display: flex;
  align-items: center;
  gap: var(--scr-space-3);
  padding: var(--scr-space-2) var(--scr-space-5);
  background: var(--scr-pin-bg);
  border: 1px solid var(--scr-inset-border);
  border-radius: var(--scr-radius-card);
  box-shadow: var(--scr-shadow-pin);
  backdrop-filter: blur(var(--scr-blur-pop));
  white-space: nowrap;
}

.pin-icon {
  color: var(--scr-accent-bright);
  flex-shrink: 0;
}

.pin-name {
  font-size: var(--scr-fs-md);
  font-weight: var(--scr-fw-semibold);
  color: var(--scr-text-1);
  letter-spacing: var(--scr-ls-mid);
}

.pin-badge {
  font-size: var(--scr-fs-axis);
  padding: var(--scr-space-1) var(--scr-space-3);
}

.pin-stem {
  width: 2px; /* REF pin-stem 2×16 */
  height: 16px;
  background: linear-gradient(180deg, var(--scr-royal), transparent);
}

/* REF pin-pulse：落地椭圆光斑垫（非圆点） */
.pin-pulse {
  position: absolute;
  bottom: -4px;
  left: 50%;
  transform: translateX(-50%);
  width: 14px;
  height: 6px;
  border-radius: 50%;
  background: rgb(from var(--scr-royal) r g b / 0.6);
  box-shadow: 0 0 8px rgb(from var(--scr-royal) r g b / 0.4);
}

/* 告警楼宇：红卡边 + 红渐变茎 + 红脉冲 + 卡内 beacon 点（REF pin-card-alert 族） */
.pin-card.is-alert {
  border-color: var(--scr-up);
}
.pin-card.is-alert .pin-icon {
  color: var(--scr-up);
}
.pin-stem.is-alert {
  background: linear-gradient(180deg, var(--scr-up), transparent);
}
.pin-pulse.is-alert {
  background: rgb(from var(--p-red-500) r g b / 0.7);
  box-shadow: 0 0 8px rgb(from var(--p-red-500) r g b / 0.4);
  animation: scr-ping 1.5s ease-out infinite;
}

.pin-beacon {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: var(--scr-up);
  box-shadow: 0 0 6px var(--scr-up);
  animation: pin-beacon-pulse 1.2s infinite;
}

@keyframes pin-beacon-pulse {
  0%, 100% { transform: scale(0.96); opacity: 0.85; }
  50% { transform: scale(1.04); opacity: 1; }
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
  backdrop-filter: blur(var(--scr-blur-pop));
  opacity: 0;
  pointer-events: none;
  transition: opacity var(--scr-dur-fast), transform var(--scr-dur-fast);
  z-index: var(--scr-z-overlay);
}

.campus-pin:hover .pin-pop {
  opacity: 1; /* hover 恢复态（极值豁免） */
  transform: translate(-50%, 0);
}

/* B12：锚点贴近图像顶缘时弹层翻到 pin 下方（锚点=pin 底缘，pop 落 anchor 点下方） */
.campus-pin.pop-below .pin-pop {
  bottom: auto;
  top: calc(100% + 8px);
  transform: translate(-50%, -4px);
}

.pop-title {
  font-size: var(--scr-fs-sm);
  font-weight: var(--scr-fw-semibold);
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
  font-weight: var(--scr-fw-semibold);
  color: var(--scr-text-1);
}
</style>
