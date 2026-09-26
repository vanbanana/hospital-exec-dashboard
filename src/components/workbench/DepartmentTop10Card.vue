<template>
  <div class="top10-card">
    <div class="card-header">
      <div class="header-title-box">
        <h3 class="card-title">科室业务量 TOP10</h3>
        <span class="card-subtitle">（住院人次）</span>
      </div>
      <router-link to="/workbench/medical" class="more-link">更多 &gt;</router-link>
    </div>

    <div class="ranking-list">
      <div
        v-for="(item, idx) in departmentData"
        :key="item.name"
        class="ranking-item"
      >
        <span
          class="rank-badge"
          :class="getRankClass(idx + 1)"
        >
          {{ idx + 1 }}
        </span>
        <span class="dept-name">{{ item.name }}</span>
        <div class="bar-track">
          <div
            class="bar-fill"
            :style="{ width: `${(item.value / maxVal) * 100}%` }"
          ></div>
        </div>
        <span class="dept-val wb-num">{{ item.value }}</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const departmentData = [
  { name: '心血管内科', value: 680 },
  { name: '骨科', value: 612 },
  { name: '呼吸与危重症医学科', value: 538 },
  { name: '普通外科', value: 499 },
  { name: '神经内科', value: 436 },
  { name: '肿瘤科', value: 401 },
  { name: '妇产科', value: 389 },
  { name: '儿科', value: 356 },
  { name: '消化内科', value: 320 },
  { name: '泌尿外科', value: 298 },
]

const maxVal = 700

// 金银铜奖牌色，辨识度高于近色系
const getRankClass = (rank: number) => {
  if (rank === 1) return 'rank-gold'
  if (rank === 2) return 'rank-silver'
  if (rank === 3) return 'rank-bronze'
  return 'rank-normal'
}
</script>

<style scoped>
.top10-card {
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
  align-items: baseline;
  justify-content: space-between;
  margin-bottom: 8px;
}

.header-title-box {
  display: flex;
  align-items: baseline;
  gap: 4px;
}

.card-title {
  font-size: 15px;
  font-weight: 700;
  color: var(--wb-navy);
  margin: 0;
  letter-spacing: 0.3px;
}

.card-subtitle {
  font-size: 12px;
  color: var(--wb-text-3);
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

.ranking-list {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  flex: 1;
}

.ranking-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 1.5px 0;
}

.rank-badge {
  width: 17px;
  height: 17px;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  font-weight: 700;
  flex-shrink: 0;
}

.rank-gold {
  background-color: #f59e0b;
  color: #ffffff;
}

.rank-silver {
  background-color: #94a3b8;
  color: #ffffff;
}

.rank-bronze {
  background-color: #d97706;
  color: #ffffff;
}

.rank-normal {
  background-color: #eef2f7;
  color: var(--wb-text-3);
}

.dept-name {
  width: 110px;
  font-size: 12px;
  color: var(--wb-text-1);
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  flex-shrink: 0;
}

.bar-track {
  flex: 1;
  height: 8px;
  background-color: #f1f5f9;
  border-radius: 4px;
  overflow: hidden;
}

.bar-fill {
  height: 100%;
  background-color: var(--wb-accent);
  border-radius: 4px;
  transition: width 0.3s ease;
}

.dept-val {
  width: 30px;
  text-align: right;
  font-size: 12px;
  font-weight: 600;
  color: var(--wb-text-1);
  flex-shrink: 0;
}
</style>
