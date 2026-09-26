<template>
  <div class="tech-panel alerts-panel">
    <!-- Header -->
    <div class="panel-header">
      <div class="panel-header-left">
        <div class="panel-accent-bar"></div>
        <span class="panel-title">重要预警与待办事项</span>
      </div>
      <div class="panel-more-link">
        <span>&gt; 全部预警</span>
      </div>
    </div>

    <!-- Table -->
    <div class="table-container">
      <table class="alerts-table">
        <thead>
          <tr>
            <th style="width: 50px; text-align: left;">时间</th>
            <th style="text-align: left;">事项</th>
            <th style="width: 55px; text-align: center;">等级</th>
            <th style="width: 60px; text-align: center;">状态</th>
            <th style="width: 105px; text-align: center;">操作</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(item, idx) in alertList" :key="idx" class="alert-row">
            <!-- Time -->
            <td class="time-col">{{ item.time }}</td>

            <!-- Matter -->
            <td class="matter-col">{{ item.title }}</td>

            <!-- Level Badge -->
            <td style="text-align: center;">
              <span class="level-badge" :class="item.levelClass">{{ item.level }}</span>
            </td>

            <!-- Status -->
            <td style="text-align: center;">
              <span class="status-label" :class="item.status === '待处理' ? 'status-pending' : 'status-processing'">
                {{ item.status }}
              </span>
            </td>

            <!-- Operations -->
            <td style="text-align: center;">
              <div class="actions-group">
                <button class="action-btn">下发</button>
                <button class="action-btn">督办</button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup lang="ts">
const alertList = [
  { time: '08:12', title: '急诊留观超时 (>6h)', level: '紧急', levelClass: 'level-urgent', status: '待处理' },
  { time: '07:50', title: '外科楼床位使用率96%', level: '重要', levelClass: 'level-important', status: '处理中' },
  { time: '06:30', title: '手术室周转时间超标', level: '重要', levelClass: 'level-important', status: '待处理' },
  { time: '05:20', title: '部分药品库存预警', level: '一般', levelClass: 'level-normal', status: '待处理' },
  { time: '05:10', title: '医学影像设备待维护', level: '一般', levelClass: 'level-normal', status: '处理中' },
]
</script>

<style scoped>
.alerts-panel {
  width: 100%;
  height: 376px;
}

.table-container {
  flex: 1;
  padding: 6px 14px 8px 14px;
}

.alerts-table {
  width: 100%;
  border-collapse: collapse;
}

.alerts-table th {
  font-size: 13px;
  font-weight: 600;
  color: #8bb5e0;
  padding: 6px 4px;
  border-bottom: 1px solid rgba(26, 76, 134, 0.4);
}

.alerts-table td {
  padding: 9px 4px;
  font-size: 13px;
}

.alert-row {
  border-bottom: 1px dotted rgba(56, 189, 248, 0.35);
  transition: background-color 0.15s;
}

.alert-row:last-child {
  border-bottom: none;
}

.alert-row:hover {
  background-color: rgba(14, 52, 107, 0.35);
}

.time-col {
  font-family: "DIN Alternate", sans-serif;
  color: #c5dbee;
  font-size: 13px;
}

.matter-col {
  color: #ffffff;
  font-weight: 500;
}

/* Level Badges */
.level-badge {
  display: inline-block;
  padding: 2px 7px;
  border-radius: 3px;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.5px;
}

.level-urgent {
  background: #ef4444;
  color: #ffffff;
}

.level-important {
  background: #f97316;
  color: #ffffff;
}

.level-normal {
  background: #facc15;
  color: #0f172a;
  font-weight: 800;
}

/* Status */
.status-label {
  font-size: 12px;
  font-weight: 600;
}

.status-pending {
  color: #f97316;
}

.status-processing {
  color: #38bdf8;
}

/* Action buttons */
.actions-group {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}

.action-btn {
  background: rgba(4, 32, 68, 0.7);
  border: 1px solid rgba(0, 145, 234, 0.55);
  color: #ffffff;
  border-radius: 4px;
  padding: 3px 11px;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  transition: background-color 0.15s, border-color 0.15s;
}

.action-btn:hover {
  background: rgba(0, 145, 234, 0.3);
  border-color: #38bdf8;
}
</style>
