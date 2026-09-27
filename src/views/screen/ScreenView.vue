<template>
  <div class="screen-root">
    <ScrHeader :status="snap?.status" :server-time="snap?.server_time" />

    <div v-if="loading" class="screen-state">
      <span class="state-text">正在加载大屏快照…</span>
    </div>
    <div v-else-if="error" class="screen-state">
      <div class="error-bar"></div>
      <span class="state-text error">数据链路中断</span>
      <span class="state-sub">{{ error }}</span>
      <button class="retry-btn" type="button" @click="load">重新连接</button>
    </div>
    <div v-else class="screen-body">
      <div class="col col-l">
        <ScrDrgQuadrant class="p-drg" :data="snap?.drg_quadrant" />
        <ScrDeptRank class="p-grow" :list="snap?.dept_ranking" />
      </div>
      <div class="col col-c">
        <ScrKpiStrip class="p-kpi" :kpis="snap?.kpis" />
        <ScrCampusMap :buildings="snap?.buildings" />
      </div>
      <div class="col col-r">
        <ScrTrendGrid class="p-trend" :trends="snap?.trends" :kpis="snap?.kpis" />
        <ScrAlertFeed class="p-grow" :list="snap?.alerts?.list" :total="snap?.alerts?.total_open" />
      </div>
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
import ScrTrendGrid from '../../components/screen/ScrTrendGrid.vue'
import { getScreenSnapshot } from '../../api/screen'
import type { ScreenSnapshotResp } from '../../api/types'

const snap = ref<ScreenSnapshotResp>()
const loading = ref(true)
const error = ref('')

async function load() {
  loading.value = true
  error.value = ''
  try {
    snap.value = await getScreenSnapshot()
  } catch (e) {
    error.value = e instanceof Error ? e.message : '未知错误'
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

.screen-body {
  flex: 1;
  min-height: 0;
  display: flex;
  gap: var(--scr-space-7); /* 美术稿 */
  padding: var(--scr-space-7);
}

.col {
  display: flex;
  flex-direction: column;
  gap: var(--scr-space-7);
  min-height: 0;
  min-width: 0;
}

.col-l {
  width: 436px; /* 美术稿 */
  flex-shrink: 0;
}

.col-c {
  flex: 1;
}

.col-r {
  width: 400px; /* 美术稿 */
  flex-shrink: 0;
}

.p-drg {
  height: 396px; /* 美术稿 */
  flex-shrink: 0;
}

.p-grow {
  flex: 1;
  min-height: 0;
}

.p-kpi {
  height: 82px; /* 美术稿 */
  flex-shrink: 0;
}

.p-trend {
  height: 396px; /* 美术稿 */
  flex-shrink: 0;
}

/* 整屏状态态（loading / error-retry，frontend-api §15 空错态） */
.screen-state {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--scr-space-5);
  position: relative;
}

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
  letter-spacing: 1px;
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
  transition: background 0.2s;
}

.retry-btn:hover {
  background: rgb(from var(--p-blue-600) r g b / 0.35);
}
</style>
