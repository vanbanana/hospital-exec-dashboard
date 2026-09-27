<template>
  <div class="screen-root">
    <ScrHeader :status="snap?.status" :server-time="snap?.server_time" />

    <div class="screen-body">
      <div v-if="loading" class="screen-state">
        <span class="state-text">正在加载大屏快照…</span>
      </div>
      <div v-else-if="error" class="screen-state">
        <div class="error-bar"></div>
        <span class="state-text error">数据链路中断</span>
        <span class="state-sub">{{ error.message }}</span>
        <span class="state-sub">code {{ error.code }} · trace {{ error.trace_id }}</span>
        <button class="retry-btn" type="button" @click="load">重新连接</button>
      </div>
      <template v-else>
        <!-- 院区图垫底（z1）：img cover + 偏心 vignette + 楼宇 pin（ScrCampusMap 内部解剖） -->
        <ScrCampusMap :buildings="snap?.buildings" />

        <!-- 顶部 KPI 浮条（z25，浮于 overlay 之上） -->
        <ScrKpiStrip :kpis="snap?.kpis" />

        <!-- 浮层 UI（z20，容器穿透、面板恢复交互） -->
        <div class="ui-overlay">
          <aside class="left-column">
            <ScrTrendTabs class="lc-trend" :trends="snap?.trends" :kpis="snap?.kpis" />
            <ScrBuildingBars class="lc-bars" :buildings="snap?.buildings" />
          </aside>
          <div class="bottom-row">
            <ScrDrgQuadrant :data="snap?.drg_quadrant" />
            <ScrDeptRank :list="snap?.dept_ranking" />
            <ScrAlertFeed :list="snap?.alerts?.list" :total="snap?.alerts?.total_open" />
          </div>
        </div>
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import ScrHeader from '../../components/screen/ScrHeader.vue'
import ScrKpiStrip from '../../components/screen/ScrKpiStrip.vue'
import ScrDrgQuadrant from '../../components/screen/ScrDrgQuadrant.vue'
import ScrCampusMap from '../../components/screen/ScrCampusMap.vue'
import ScrDeptRank from '../../components/screen/ScrDeptRank.vue'
import ScrAlertFeed from '../../components/screen/ScrAlertFeed.vue'
import ScrTrendTabs from '../../components/screen/ScrTrendTabs.vue'
import ScrBuildingBars from '../../components/screen/ScrBuildingBars.vue'
import { getScreenSnapshot } from '../../api/screen'
import { toApiError, type ApiError } from '../../api/useAsyncData'
import type { ScreenSnapshotResp } from '../../api/types'

const snap = ref<ScreenSnapshotResp>()
const loading = ref(true)
// 错误态保留 code/trace_id（error-codes §1 包络形状），不再只存 message 字符串
const error = ref<ApiError | null>(null)

async function load() {
  loading.value = true
  error.value = null
  try {
    snap.value = await getScreenSnapshot()
  } catch (e) {
    error.value = toApiError(e)
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.screen-root {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  background:
    radial-gradient(ellipse 120% 70% at 50% -10%, rgb(from var(--p-ink-800) r g b / 0.5), transparent 60%),
    var(--scr-bg);
}

/* .screen-body/.campus-stage/.ui-overlay/.left-column/.bottom-row/.hero-ribbon/.screen-state
   布局骨架统一在 screen.css 浮层布局区块 */

.error-bar {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 3px;
  background: linear-gradient(90deg, transparent, var(--scr-up), transparent);
}

.state-text {
  font-size: var(--scr-fs-md);
  color: var(--scr-text-3);
  letter-spacing: var(--scr-ls-md);
}

.state-text.error {
  color: var(--scr-up);
  font-size: var(--scr-fs-title);
}

.state-sub {
  font-size: var(--scr-fs-sm);
  color: var(--scr-text-4);
}

.retry-btn {
  margin-top: var(--scr-space-3);
  padding: var(--scr-space-4) var(--scr-space-10);
  background: rgb(from var(--p-blue-600) r g b / 0.2);
  border: 1px solid var(--scr-border-glow);
  border-radius: var(--scr-radius-card);
  color: var(--scr-accent-bright);
  font-size: var(--scr-fs-md);
  cursor: pointer;
  transition: background var(--scr-dur-normal);
}

.retry-btn:hover {
  background: rgb(from var(--p-blue-600) r g b / 0.35);
}
</style>
