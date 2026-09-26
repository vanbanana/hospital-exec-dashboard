<template>
  <div class="progress-card">
    <div class="card-header">
      <h3 class="card-title">重点工作进度</h3>
      <router-link to="/workbench/topics" class="more-link">更多 &gt;</router-link>
    </div>

    <div class="progress-list">
      <div
        v-for="item in workItems"
        :key="item.name"
        class="progress-item"
      >
        <span class="status-dot" :class="item.status === '进行中' ? 'dot-doing' : 'dot-pending'"></span>
        <span class="task-name">{{ item.name }}</span>
        <div class="task-bar-track">
          <div class="task-bar-fill" :style="{ width: `${item.progress}%` }"></div>
        </div>
        <span class="progress-val wb-num">{{ item.progress }}%</span>
        <span
          class="status-tag"
          :class="item.status === '进行中' ? 'status-active' : 'status-pending'"
        >
          {{ item.status }}
        </span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const workItems = [
  { name: '三甲复评准备', progress: 75, status: '进行中' },
  { name: 'DRG精细化管理', progress: 60, status: '进行中' },
  { name: '智慧医院建设', progress: 40, status: '进行中' },
  { name: '学科建设提升计划', progress: 90, status: '进行中' },
  { name: 'DIP支付方式改革', progress: 30, status: '待启动' },
]
</script>

<style scoped>
.progress-card {
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

.progress-list {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  flex: 1;
}

.progress-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 2px 0;
}

/* 点色随状态：进行中=绿、待启动=灰，避免无意义异色 */
.status-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  flex-shrink: 0;
}
.dot-doing { background-color: var(--wb-green); }
.dot-pending { background-color: var(--wb-text-4); }

.task-name {
  width: 120px;
  font-size: 12px;
  color: var(--wb-text-1);
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  flex-shrink: 0;
}

.task-bar-track {
  flex: 1;
  height: 8px;
  background-color: #f1f5f9;
  border-radius: 4px;
  overflow: hidden;
}

.task-bar-fill {
  height: 100%;
  background-color: var(--wb-accent);
  border-radius: 4px;
  transition: width 0.3s ease;
}

.progress-val {
  width: 34px;
  text-align: right;
  font-size: 12px;
  color: var(--wb-text-2);
  flex-shrink: 0;
}

.status-tag {
  font-size: 11px;
  padding: 2px 6px;
  border-radius: var(--wb-radius-tag);
  font-weight: 500;
  flex-shrink: 0;
  width: 48px;
  text-align: center;
  box-sizing: border-box;
  white-space: nowrap;
}

.status-active {
  background-color: #e8f6ee;
  color: var(--wb-green);
}

.status-pending {
  background-color: #fdf3e3;
  color: var(--wb-amber);
}
</style>
