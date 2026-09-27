<template>
  <ScrPanel title="楼宇运行">
    <!-- REF 医疗资源占用 res-row 解剖：图标盒 + 名称/指标名 + 指标值 + 渐变条 + 右侧% -->
    <div v-if="rows.length" class="bld-rows">
      <div v-for="r in rows" :key="r.code" class="bld-row">
        <div class="bld-icon">
          <component :is="r.icon" :size="15" :stroke-width="2" />
        </div>
        <div class="bld-label">
          <span class="bld-name">{{ r.name }}</span>
          <span class="bld-metric">{{ r.metricLabel }}</span>
        </div>
        <!-- primary_metric 缺席的降级行：仅名称+badge 文本，不渲值/量程条（§14.1 注8） -->
        <template v-if="!r.degraded">
          <span class="bld-val scr-num">{{ r.valText }}</span>
          <div class="bld-pct-box">
            <div class="bld-track">
              <div class="bld-fill" :class="r.fill" :style="{ width: `${r.pct}%` }"></div>
            </div>
            <span class="bld-pct scr-num">{{ r.pct }}%</span>
          </div>
        </template>
        <span v-else class="bld-badge scr-tag" :class="`is-${r.badgeLevel}`">{{ r.badge }}</span>
      </div>
    </div>
    <div v-else class="scr-empty">暂无楼宇数据</div>
  </ScrPanel>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { Component } from 'vue'
import { BedDouble, Building2, Microscope, Siren, Stethoscope } from 'lucide-vue-next'
import ScrPanel from './ScrPanel.vue'
import type { BuildingBadgeLevel, ScreenBuilding } from '../../api/types'

const props = defineProps<{ buildings?: ScreenBuilding[] }>()

interface BldRow {
  code: string
  name: string
  icon: Component
  metricLabel: string
  degraded: boolean
  badge: string
  badgeLevel: BuildingBadgeLevel
  valText: string
  pct: number
  fill: '' | 'fill-sky' | 'fill-cyan' | 'fill-alert'
}

const clampPct = (v: number) => Math.max(0, Math.min(100, Math.round(v)))

/* 楼宇图标位（纯展示映射，与 ScrCampusMap 同族；未知 code 落 Building2） */
const iconOf = (code: string): Component => {
  const map: Record<string, Component> = {
    mz: Stethoscope,
    wk: BedDouble,
    jz: Siren,
    yj: Microscope,
  }
  return map[code] ?? Building2
}

/* 主指标取值与量程全部走契约 primary_metric（§14.1 注8：key→metrics 取值、max 归一）；
   字段缺席时不得自造展示口径——行降级为名称+badge */
function buildRow(b: ScreenBuilding): BldRow {
  const base = {
    code: b.code,
    name: b.name,
    icon: iconOf(b.code),
    badge: b.badge,
    badgeLevel: b.badge_level,
  }
  const pm = b.primary_metric
  if (!pm) {
    return { ...base, metricLabel: '', degraded: true, valText: '', pct: 0, fill: '' }
  }
  const v = b.metrics[pm.key] ?? 0
  const valText = `${v}${pm.unit}`
  const pct = pm.max > 0 ? clampPct((v / pm.max) * 100) : 0

  /* REF fill 色阶映射：告警>红、busy>亮蓝、≥85%>满档青、其余默认蓝。
     pct>=85 仅样式满档阈值（视觉分档），非业务预警口径 */
  const fill: BldRow['fill'] =
    b.status === 'alert' ? 'fill-alert'
    : b.status === 'busy' ? 'fill-sky'
    : pct >= 85 ? 'fill-cyan'
    : ''

  return { ...base, metricLabel: pm.label, degraded: false, valText, pct, fill }
}

const rows = computed(() => (props.buildings ?? []).map(buildRow))
</script>

<style scoped>
.bld-rows {
  flex: 1;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

.bld-row {
  flex: 1;
  display: flex;
  align-items: center;
  gap: var(--scr-space-5);
  font-size: var(--scr-fs-12);
}

/* REF res-icon-box：24×24、ink 底 + 描边、icon 15 亮青 */
.bld-icon {
  width: 24px; /* 美术稿（REF res-icon-box） */
  height: 24px;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--scr-iconbox-bg);
  border: 1px solid var(--scr-inset-border);
  border-radius: var(--scr-radius-tag);
  color: var(--scr-accent-bright);
}

.bld-label {
  width: 96px; /* 美术稿（REF res-label 95px） */
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  gap: var(--scr-space-1);
}

.bld-name {
  font-size: var(--scr-fs-12);
  color: var(--scr-text-2);
}

.bld-metric {
  font-size: var(--scr-fs-xs);
  color: var(--scr-text-4);
}

.bld-val {
  width: 56px; /* 美术稿（REF res-ratio 55px） */
  flex-shrink: 0;
  font-size: var(--scr-fs-md);
  font-weight: var(--scr-fw-semibold);
  color: var(--scr-text-1);
}

/* 降级行的 badge 右对齐（primary_metric 缺席分支） */
.bld-badge {
  margin-left: auto;
}

.bld-pct-box {
  flex: 1;
  display: flex;
  align-items: center;
  gap: var(--scr-space-4);
  min-width: 0;
}

/* REF progress-bar-bg：h6、ink 轨道 + 1px 描边、radius3 */
.bld-track {
  flex: 1;
  height: 6px; /* 美术稿（REF 轨道高） */
  border-radius: var(--scr-radius-tag);
  background: var(--scr-bar-track);
  border: 1px solid var(--scr-inset-border);
  overflow: hidden;
}

.bld-fill {
  height: 100%;
  border-radius: var(--scr-radius-tag);
  background: var(--scr-bar-fill);
}

.bld-fill.fill-sky { background: var(--scr-bar-fill-sky); }
.bld-fill.fill-cyan { background: var(--scr-bar-fill-cyan); }
.bld-fill.fill-alert { background: var(--scr-bar-fill-alert); }

.bld-pct {
  width: 34px; /* 美术稿（REF res-pct） */
  flex-shrink: 0;
  text-align: right;
  font-size: var(--scr-fs-12);
  font-weight: var(--scr-fw-bold);
  color: var(--scr-text-1);
}
</style>
