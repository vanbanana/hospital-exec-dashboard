<template>
  <ScrPanel title="楼宇运行" sub="主指标负荷">
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
        <span class="bld-val scr-num">
          {{ r.valText }}<span v-if="r.valSub" class="bld-slash">/{{ r.valSub }}</span>
        </span>
        <div class="bld-pct-box">
          <div class="bld-track">
            <div class="bld-fill" :class="r.fill" :style="{ width: `${r.pct}%` }"></div>
          </div>
          <span class="bld-pct scr-num">{{ r.pct }}%</span>
        </div>
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
import type { ScreenBuilding } from '../../api/types'

const props = defineProps<{ buildings?: ScreenBuilding[] }>()

interface BldRow {
  code: string
  name: string
  icon: Component
  metricLabel: string
  valText: string
  valSub?: string
  pct: number
  fill: '' | 'fill-sky' | 'fill-cyan' | 'fill-alert'
}

const clampPct = (v: number) => Math.max(0, Math.min(100, Math.round(v)))

/* 各楼主指标与条的量程（metrics 键集见 frontend-api §15 末表） */
function buildRow(b: ScreenBuilding): BldRow {
  const m = b.metrics
  let icon: Component = Building2
  let metricLabel = '运行指标'
  let valText = ''
  let valSub: string | undefined
  let pct = 0

  switch (b.code) {
    case 'mz': // 门诊楼：候诊均时，60min 展示量程（契约无量程字段，归一参数）
      icon = Stethoscope
      metricLabel = '候诊均时'
      valText = `${m.queue_avg_min ?? 0}分`
      pct = clampPct(((m.queue_avg_min ?? 0) / 60) * 100)
      break
    case 'wk': // 外科楼：床位使用率
      icon = BedDouble
      metricLabel = '床位使用率'
      valText = `${m.bed_used ?? 0}`
      valSub = `${m.bed_open ?? 0}`
      pct = clampPct(m.bed_use_rate ?? 0)
      break
    case 'jz': // 急诊楼：留观超时 计数/在观总数
      icon = Siren
      metricLabel = '留观超时'
      valText = `${m.obs_over6h ?? 0}`
      valSub = `${m.obs_cnt ?? 0}`
      pct = clampPct(m.obs_cnt ? ((m.obs_over6h ?? 0) / m.obs_cnt) * 100 : 0)
      break
    case 'yj': // 医技楼：设备运行 运行数/(运行+告警)
      icon = Microscope
      metricLabel = '设备运行率'
      valText = `${m.device_run ?? 0}台`
      pct = clampPct(
        (m.device_run ?? 0) + (m.device_alert ?? 0)
          ? ((m.device_run ?? 0) / ((m.device_run ?? 0) + (m.device_alert ?? 0))) * 100
          : 0
      )
      break
    default: { // 未知楼种兜底：取 metrics 首键，≤100 直读为百分比
      const [k, v] = Object.entries(m)[0] ?? ['—', 0]
      metricLabel = k
      valText = `${v}`
      pct = v <= 100 ? clampPct(v) : 0
    }
  }

  /* REF fill 色阶映射：告警>红、busy>亮蓝、≥85%>满档青、其余默认蓝 */
  const fill: BldRow['fill'] =
    b.status === 'alert' ? 'fill-alert'
    : b.status === 'busy' ? 'fill-sky'
    : pct >= 85 ? 'fill-cyan'
    : ''

  return { code: b.code, name: b.name, icon, metricLabel, valText, valSub, pct, fill }
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
  border-bottom: 1px solid rgb(from var(--p-white) r g b / 0.05);
}

.bld-row:last-child {
  border-bottom: none;
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

.bld-slash {
  font-size: var(--scr-fs-xs);
  color: var(--scr-text-4);
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
