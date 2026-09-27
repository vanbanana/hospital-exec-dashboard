<template>
  <div class="workbench-layout">
    <WorkbenchSidebar />

    <main class="workbench-main">
      <WorkbenchHeader />
      <div class="workbench-scroll">
        <router-view />
      </div>
    </main>
  </div>
</template>

<script setup lang="ts">
import WorkbenchSidebar from '../components/workbench/WorkbenchSidebar.vue'
import WorkbenchHeader from '../components/workbench/WorkbenchHeader.vue'
</script>

<style scoped>
.workbench-layout {
  width: 100vw;
  height: 100vh;
  display: flex;
  background-color: var(--wb-bg);
  overflow: hidden;
}

.workbench-main {
  flex: 1;
  min-width: 0;
  height: 100vh;
  display: flex;
  flex-direction: column;
}

/* 滚动区：统一的页面内边距与纵向节奏 */
.workbench-scroll {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  overflow-x: hidden;
  padding: var(--wb-space-1) var(--wb-space-4) var(--wb-pad-y);
}

.workbench-scroll::-webkit-scrollbar {
  width: var(--wb-scrollbar-w);
}
.workbench-scroll::-webkit-scrollbar-thumb {
  background: var(--wb-scrollbar);
  border-radius: var(--wb-radius-pill);
}
</style>
