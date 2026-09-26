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
  padding: 2px 16px 14px;
}

.workbench-scroll::-webkit-scrollbar {
  width: 6px;
}
.workbench-scroll::-webkit-scrollbar-thumb {
  background: #cbd5e1;
  border-radius: 3px;
}
</style>
