<template>
  <div class="tech-panel ranking-panel">
    <!-- Header -->
    <div class="panel-header">
      <div class="panel-header-left">
        <div class="panel-accent-bar"></div>
        <span class="panel-title">临床科室运营效率排名</span>
        <span class="panel-subtitle">(近30天)</span>
      </div>
      <div class="panel-more-link">
        <span>&gt; 更多排名</span>
      </div>
    </div>

    <!-- Table Content -->
    <div class="table-container">
      <table class="ranking-table">
        <thead>
          <tr>
            <th style="width: 48px; text-align: center;">排名</th>
            <th style="width: 80px; text-align: left;">科室</th>
            <th style="width: 55px; text-align: right;">CMI</th>
            <th style="width: 60px; text-align: right;">手术量</th>
            <th style="width: 85px; text-align: right;">平均住院日</th>
            <th style="width: 175px; text-align: left; padding-left: 14px;">运行效率</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="row in rankingList" :key="row.rank" class="table-row">
            <!-- Rank Badge -->
            <td style="text-align: center;">
              <span v-if="row.rank === 1" class="rank-badge rank-1">1</span>
              <span v-else-if="row.rank === 2" class="rank-badge rank-2">2</span>
              <span v-else-if="row.rank === 3" class="rank-badge rank-3">3</span>
              <span v-else class="rank-num">{{ row.rank }}</span>
            </td>

            <!-- Department Name -->
            <td class="dept-name">{{ row.name }}</td>

            <!-- CMI -->
            <td class="num-col">{{ row.cmi.toFixed(2) }}</td>

            <!-- Surgery Count -->
            <td class="num-col">{{ row.surgery }}</td>

            <!-- Avg Stay Days -->
            <td class="num-col">{{ row.stayDays.toFixed(1) }}</td>

            <!-- Efficiency Progress Bar with White End-Cap Marker -->
            <td class="bar-col">
              <div class="progress-wrap">
                <div class="progress-track">
                  <div
                    class="progress-fill"
                    :class="row.rank <= 3 ? 'fill-green' : 'fill-blue'"
                    :style="{ width: row.score + '%' }"
                  ></div>
                  <!-- White end-cap marker indicating 100% full scale -->
                  <div class="track-endcap"></div>
                </div>
                <span class="score-text">{{ row.score }}分</span>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup lang="ts">
const rankingList = [
  { rank: 1, name: '骨科', cmi: 1.62, surgery: 186, stayDays: 6.2, score: 92 },
  { rank: 2, name: '普外科', cmi: 1.48, surgery: 142, stayDays: 5.8, score: 88 },
  { rank: 3, name: '心内科', cmi: 1.35, surgery: 128, stayDays: 5.1, score: 86 },
  { rank: 4, name: '神经外科', cmi: 1.28, surgery: 96, stayDays: 6.5, score: 82 },
  { rank: 5, name: '肿瘤科', cmi: 1.24, surgery: 110, stayDays: 6.8, score: 80 },
  { rank: 6, name: '呼吸内科', cmi: 1.18, surgery: 78, stayDays: 7.1, score: 76 },
  { rank: 7, name: '消化内科', cmi: 1.16, surgery: 68, stayDays: 6.9, score: 74 },
  { rank: 8, name: '泌尿外科', cmi: 1.12, surgery: 72, stayDays: 6.3, score: 72 },
  { rank: 9, name: '妇产科', cmi: 1.08, surgery: 64, stayDays: 5.5, score: 70 },
  { rank: 10, name: '儿科', cmi: 1.05, surgery: 52, stayDays: 5.8, score: 68 },
]
</script>

<style scoped>
.ranking-panel {
  width: 100%;
  height: 450px;
}

.table-container {
  flex: 1;
  padding: 4px 12px 6px 12px;
  display: flex;
  flex-direction: column;
}

.ranking-table {
  width: 100%;
  height: 100%;
  border-collapse: collapse;
}

.ranking-table th {
  font-size: 13px;
  font-weight: 600;
  color: #8bb5e0;
  padding: 2px 4px 6px 4px;
  border-bottom: 1px solid rgba(26, 76, 134, 0.4);
}

.ranking-table td {
  padding: 2px 4px;
  font-size: 13px;
  vertical-align: middle;
}

.table-row {
  transition: background-color 0.15s;
}

.table-row:hover {
  background-color: rgba(14, 52, 107, 0.35);
}

/* Rank Badges */
.rank-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  font-size: 11px;
  font-weight: 800;
  color: #061021;
}

.rank-1 {
  background: #f59e0b;
}

.rank-2 {
  background: #94a3b8;
}

.rank-3 {
  background: #d97706;
}

.rank-num {
  font-family: "DIN Alternate", sans-serif;
  color: #8daed1;
  font-weight: 700;
  font-size: 12px;
}

.dept-name {
  color: #ffffff;
  font-weight: 600;
}

.num-col {
  font-family: "DIN Alternate", "Helvetica Neue", sans-serif;
  color: #c5dbee;
  font-size: 13px;
}

/* Progress bar */
.bar-col {
  padding-left: 14px;
}

.progress-wrap {
  display: flex;
  align-items: center;
  gap: 8px;
}

.progress-track {
  flex: 1;
  height: 10px;
  background: rgba(10, 35, 70, 0.85);
  border-radius: 2px;
  position: relative;
  overflow: hidden;
  border: 1px solid rgba(22, 64, 112, 0.6);
}

.progress-fill {
  height: 100%;
  border-radius: 2px;
  transition: width 0.4s ease-out;
}

.fill-green {
  background: linear-gradient(90deg, #00b4d8, #00e699);
}

.fill-blue {
  background: linear-gradient(90deg, #0077b6, #0091ff);
}

.track-endcap {
  position: absolute;
  right: 0;
  top: 0;
  bottom: 0;
  width: 2.5px;
  background: #ffffff;
  z-index: 5;
}

.score-text {
  font-family: "DIN Alternate", sans-serif;
  font-size: 13px;
  font-weight: 700;
  color: #ffffff;
  width: 36px;
  text-align: right;
}
</style>
