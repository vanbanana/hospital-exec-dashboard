<template>
  <div class="notices-card">
    <div class="card-header">
      <h3 class="card-title">通知与待办</h3>
      <router-link to="/workbench/overview" class="more-link">更多 &gt;</router-link>
    </div>

    <div class="notices-list">
      <div
        v-for="item in noticeItems"
        :key="item.text"
        class="notice-item"
      >
        <span
          class="notice-dot"
          :class="item.urgent ? 'dot-urgent' : 'dot-normal'"
        ></span>
        <span class="notice-text">{{ item.text }}</span>
        <span class="notice-date wb-num">{{ item.date }}</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const noticeItems = [
  { text: '关于加强医疗质量安全管理的通知', date: '2024-10-28', urgent: true },
  { text: '院务会会议材料（10月）', date: '2024-10-27', urgent: true },
  { text: '请审阅2025年预算编制方案', date: '2024-10-26', urgent: true },
  { text: '智慧医院二期建设进展汇报', date: '2024-10-25', urgent: false },
  { text: '上级主管部门调研安排', date: '2024-10-24', urgent: false },
]
</script>

<style scoped>
.notices-card {
  height: 100%;
  box-sizing: border-box;
  background: var(--wb-surface);
  border-radius: var(--wb-radius-card);
  border: 1px solid var(--wb-border);
  box-shadow: var(--wb-shadow-card);
  padding: 14px 16px 10px;
  display: flex;
  flex-direction: column;
  user-select: none;
  min-width: 0;
}

.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
}

.card-title {
  font-size: 15px;
  font-weight: 700;
  color: var(--wb-navy);
  margin: 0;
  letter-spacing: 0.3px;
}

.more-link {
  font-size: 12px;
  color: var(--wb-text-3);
  text-decoration: none;
  transition: color 0.15s;
}

.more-link:hover {
  color: var(--wb-primary);
}

.notices-list {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  flex: 1;
}

.notice-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 2px 0;
}

.notice-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  flex-shrink: 0;
}

.dot-urgent {
  background-color: var(--wb-red);
}

.dot-normal {
  background-color: var(--wb-text-4);
}

.notice-text {
  flex: 1;
  font-size: 12px;
  color: var(--wb-text-1);
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.notice-date {
  font-size: 12px;
  color: var(--wb-text-3);
  flex-shrink: 0;
}
</style>
