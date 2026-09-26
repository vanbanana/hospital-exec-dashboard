<template>
  <div class="tech-panel kpi-panel">
    <!-- Header -->
    <div class="panel-header">
      <div class="panel-header-left">
        <div class="panel-accent-bar"></div>
        <span class="panel-title">核心运营指标</span>
        <span class="panel-subtitle">今日概览</span>
      </div>
      <div class="panel-more-link">
        <span>&gt; 全部指标</span>
      </div>
    </div>

    <!-- 2x2 Metric Cards Grid -->
    <div class="kpi-grid">
      <!-- Card 1: 今日门急诊 -->
      <div class="metric-card">
        <div class="metric-top-row">
          <div class="metric-icon-wrap cyan-icon">
            <!-- Solid 2-person silhouette SVG -->
            <svg viewBox="0 0 32 32" class="icon-svg">
              <!-- Left person -->
              <circle cx="11" cy="9" r="4.5" fill="#00d2ff" />
              <path d="M 3 24 C 3 18 6 15 11 15 C 16 15 19 18 19 24 Z" fill="#00d2ff" />
              <!-- Right person (slightly behind) -->
              <circle cx="21" cy="11" r="3.8" fill="#38bdf8" />
              <path d="M 16 24 C 16 20 18.5 17 22.5 17 C 26.5 17 29 20 29 24 Z" fill="#38bdf8" opacity="0.85" />
            </svg>
          </div>
          <div class="metric-name-group">
            <span class="metric-name">今日门急诊</span>
          </div>
          <span class="card-arrow">&gt;</span>
        </div>

        <div class="metric-value-row">
          <span class="metric-num">2845</span>
          <span class="metric-unit">人</span>
        </div>

        <div class="metric-trend-row">
          <span class="trend-label">较昨日</span>
          <span class="trend-badge text-up">+6.8% ▲</span>
        </div>

        <!-- Mini Sparkline Area with 5 wavy points -->
        <div class="mini-sparkline">
          <svg viewBox="0 0 200 55" preserveAspectRatio="none" class="spark-svg">
            <defs>
              <linearGradient id="cyanArea" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stop-color="#0091ff" stop-opacity="0.25" />
                <stop offset="100%" stop-color="#0066cc" stop-opacity="0.0" />
              </linearGradient>
            </defs>
            <polygon points="0,42 35,32 75,38 120,22 165,34 200,24 200,55 0,55" fill="url(#cyanArea)" />
            <polyline points="0,42 35,32 75,38 120,22 165,34 200,24" fill="none" stroke="#0091ff" stroke-width="1.8" />
            <circle cx="35" cy="32" r="2.2" fill="#0091ff" />
            <circle cx="75" cy="38" r="2.2" fill="#0091ff" />
            <circle cx="120" cy="22" r="2.2" fill="#0091ff" />
            <circle cx="165" cy="34" r="2.2" fill="#0091ff" />
          </svg>
        </div>
      </div>

      <!-- Card 2: 在院患者 -->
      <div class="metric-card">
        <div class="metric-top-row">
          <div class="metric-icon-wrap emerald-icon">
            <!-- Hospital bed icon -->
            <svg viewBox="0 0 32 32" class="icon-svg">
              <path d="M 4 8 L 4 25 M 4 17 L 28 17 M 28 12 L 28 25 M 4 13 L 26 13 C 27 13 28 14 28 15 L 28 17" fill="none" stroke="#00e699" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" />
              <circle cx="10" cy="11" r="2.5" fill="#00e699" />
            </svg>
          </div>
          <div class="metric-name-group">
            <span class="metric-name">在院患者</span>
          </div>
          <span class="card-arrow">&gt;</span>
        </div>

        <div class="metric-value-row">
          <span class="metric-num">618</span>
          <span class="metric-unit">人</span>
        </div>

        <div class="metric-trend-row">
          <span class="trend-label">较昨日</span>
          <span class="trend-badge text-up">+2.1% ▲</span>
        </div>

        <!-- Mini Sparkline Area -->
        <div class="mini-sparkline">
          <svg viewBox="0 0 200 55" preserveAspectRatio="none" class="spark-svg">
            <defs>
              <linearGradient id="emeraldArea" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stop-color="#00c882" stop-opacity="0.25" />
                <stop offset="100%" stop-color="#00b377" stop-opacity="0.0" />
              </linearGradient>
            </defs>
            <polygon points="0,44 40,36 85,40 130,24 170,28 200,18 200,55 0,55" fill="url(#emeraldArea)" />
            <polyline points="0,44 40,36 85,40 130,24 170,28 200,18" fill="none" stroke="#00c882" stroke-width="1.8" />
            <circle cx="40" cy="36" r="2.2" fill="#00c882" />
            <circle cx="85" cy="40" r="2.2" fill="#00c882" />
            <circle cx="130" cy="24" r="2.2" fill="#00c882" />
            <circle cx="170" cy="28" r="2.2" fill="#00c882" />
          </svg>
        </div>
      </div>

      <!-- Card 3: 床位使用率 -->
      <div class="metric-card">
        <div class="metric-top-row">
          <div class="metric-icon-wrap amber-icon">
            <svg viewBox="0 0 32 32" class="icon-svg">
              <path d="M 28 17 A 12 12 0 1 1 15 5 L 15 17 Z" fill="#f59e0b" />
              <path d="M 18 4 A 12 12 0 0 1 29 15 L 18 15 Z" fill="#fbbf24" />
            </svg>
          </div>
          <div class="metric-name-group">
            <span class="metric-name">床位使用率</span>
          </div>
          <span class="card-arrow">&gt;</span>
        </div>

        <div class="metric-value-row">
          <span class="metric-num">90.8%</span>
        </div>

        <div class="metric-trend-row">
          <span class="trend-label">较昨日</span>
          <span class="trend-badge text-up">+1.5% ▲</span>
        </div>

        <!-- Mini Sparkline Area -->
        <div class="mini-sparkline">
          <svg viewBox="0 0 200 55" preserveAspectRatio="none" class="spark-svg">
            <defs>
              <linearGradient id="amberArea" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stop-color="#f59e0b" stop-opacity="0.25" />
                <stop offset="100%" stop-color="#d97706" stop-opacity="0.0" />
              </linearGradient>
            </defs>
            <polygon points="0,45 35,42 75,30 120,36 160,22 200,20 200,55 0,55" fill="url(#amberArea)" />
            <polyline points="0,45 35,42 75,30 120,36 160,22 200,20" fill="none" stroke="#f59e0b" stroke-width="1.8" />
            <circle cx="75" cy="30" r="2.2" fill="#f59e0b" />
            <circle cx="120" cy="36" r="2.2" fill="#f59e0b" />
            <circle cx="160" cy="22" r="2.2" fill="#f59e0b" />
          </svg>
        </div>
      </div>

      <!-- Card 4: 今日手术 -->
      <div class="metric-card">
        <div class="metric-top-row">
          <div class="metric-icon-wrap blue-icon">
            <!-- Solid Scalpel Icon -->
            <svg viewBox="0 0 32 32" class="icon-svg">
              <path d="M 23 4 L 28 9 L 14 23 L 8 20 Z" fill="#0091ff" />
              <path d="M 8 20 L 14 23 L 6 28 C 4 28 3 27 4 25 Z" fill="#ffffff" />
            </svg>
          </div>
          <div class="metric-name-group">
            <span class="metric-name">今日手术</span>
          </div>
          <span class="card-arrow">&gt;</span>
        </div>

        <div class="metric-value-row">
          <span class="metric-num">42</span>
          <span class="metric-unit">台</span>
        </div>

        <div class="metric-trend-row">
          <span class="trend-label">较昨日</span>
          <span class="trend-badge text-down">-12.5% ▼</span>
        </div>

        <!-- Mini Sparkline Area -->
        <div class="mini-sparkline">
          <svg viewBox="0 0 200 55" preserveAspectRatio="none" class="spark-svg">
            <defs>
              <linearGradient id="blueArea" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stop-color="#0091ff" stop-opacity="0.25" />
                <stop offset="100%" stop-color="#0284c7" stop-opacity="0.0" />
              </linearGradient>
            </defs>
            <polygon points="0,42 45,30 90,26 135,36 170,28 200,32 200,55 0,55" fill="url(#blueArea)" />
            <polyline points="0,42 45,30 90,26 135,36 170,28 200,32" fill="none" stroke="#0091ff" stroke-width="1.8" />
            <circle cx="45" cy="30" r="2.2" fill="#0091ff" />
            <circle cx="90" cy="26" r="2.2" fill="#0091ff" />
            <circle cx="135" cy="36" r="2.2" fill="#0091ff" />
            <circle cx="170" cy="28" r="2.2" fill="#0091ff" />
          </svg>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
</script>

<style scoped>
.kpi-panel {
  width: 100%;
  height: 450px;
}

.kpi-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  grid-template-rows: repeat(2, 1fr);
  gap: 10px;
  padding: 10px 12px 12px 12px;
  flex: 1;
}

.metric-card {
  background: linear-gradient(180deg, rgba(4, 34, 68, 0.75) 0%, rgba(2, 20, 44, 0.9) 100%);
  border: 1px solid rgba(0, 140, 230, 0.35);
  border-radius: 6px;
  padding: 12px 14px 4px 14px;
  display: flex;
  flex-direction: column;
  position: relative;
  overflow: hidden;
  transition: border-color 0.2s;
}

.metric-card:hover {
  border-color: rgba(0, 145, 255, 0.6);
}

.metric-top-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.metric-icon-wrap {
  width: 38px;
  height: 38px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.icon-svg {
  width: 32px;
  height: 32px;
}

.metric-name-group {
  flex: 1;
  margin-left: 10px;
}

.metric-name {
  font-size: 16px;
  font-weight: 600;
  color: #ffffff;
  letter-spacing: 0.5px;
}

.card-arrow {
  color: #5d8ab5;
  font-size: 16px;
  font-weight: 600;
}

.metric-value-row {
  display: flex;
  align-items: baseline;
  margin-top: 4px;
}

.metric-num {
  font-family: "DIN Alternate", "Helvetica Neue", sans-serif;
  font-size: 34px;
  font-weight: 800;
  color: #ffffff;
  letter-spacing: 0.5px;
  line-height: 1.1;
}

.metric-unit {
  font-size: 14px;
  color: #a0c4e8;
  margin-left: 6px;
  font-weight: 500;
}

.metric-trend-row {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: 3px;
  font-size: 13px;
  z-index: 2;
}

.trend-label {
  color: #8daed1;
}

.trend-badge {
  font-family: "DIN Alternate", sans-serif;
  font-weight: 700;
}

.text-up {
  color: #ff5252;
}

.text-down {
  color: #00e699;
}

.mini-sparkline {
  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  height: 52px;
  pointer-events: none;
  z-index: 1;
}

.spark-svg {
  width: 100%;
  height: 100%;
}
</style>
