<template>
  <div class="tech-panel trends-panel">
    <div class="trends-row">
      <!-- 1. 门急诊人次趋势 -->
      <div class="trend-chart-card">
        <div class="chart-title-row">
          <div class="panel-accent-bar"></div>
          <span class="chart-title">门急诊人次趋势 <span class="chart-days">(近7天)</span></span>
          <span class="latest-badge cyan-val">2845</span>
        </div>
        <div class="svg-wrap">
          <svg viewBox="0 0 450 115" preserveAspectRatio="none" class="chart-svg">
            <defs>
              <linearGradient id="trendCyan" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stop-color="#0091ff" stop-opacity="0.22" />
                <stop offset="100%" stop-color="#0066cc" stop-opacity="0.0" />
              </linearGradient>
            </defs>
            <!-- Grid Lines -->
            <line x1="48" y1="18" x2="440" y2="18" stroke="rgba(25, 70, 120, 0.25)" stroke-width="1" />
            <line x1="48" y1="52" x2="440" y2="52" stroke="rgba(25, 70, 120, 0.25)" stroke-width="1" />
            <line x1="48" y1="86" x2="440" y2="86" stroke="rgba(30, 85, 150, 0.65)" stroke-width="1" />

            <!-- Y Axis Numbers -->
            <text x="42" y="22" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="end">4,000</text>
            <text x="42" y="56" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="end">2,000</text>
            <text x="42" y="90" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="end">0</text>

            <!-- Area Fill (Polyline) -->
            <polygon points="68,52 128,44 188,40 248,46 308,34 368,34 428,38 428,86 68,86" fill="url(#trendCyan)" />
            <!-- Straight Polyline -->
            <polyline points="68,52 128,44 188,40 248,46 308,34 368,34 428,38" fill="none" stroke="#0091ff" stroke-width="1.8" />

            <!-- Data Dots -->
            <circle cx="68" cy="52" r="2.5" fill="#ffffff" stroke="#0091ff" stroke-width="1.8" />
            <circle cx="128" cy="44" r="2.5" fill="#ffffff" stroke="#0091ff" stroke-width="1.8" />
            <circle cx="188" cy="40" r="2.5" fill="#ffffff" stroke="#0091ff" stroke-width="1.8" />
            <circle cx="248" cy="46" r="2.5" fill="#ffffff" stroke="#0091ff" stroke-width="1.8" />
            <circle cx="308" cy="34" r="2.5" fill="#ffffff" stroke="#0091ff" stroke-width="1.8" />
            <circle cx="368" cy="34" r="2.5" fill="#ffffff" stroke="#0091ff" stroke-width="1.8" />
            <circle cx="428" cy="38" r="3.5" fill="#ffffff" stroke="#0091ff" stroke-width="2" />

            <!-- Ticks & Dates -->
            <line x1="68" y1="86" x2="68" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="128" y1="86" x2="128" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="188" y1="86" x2="188" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="248" y1="86" x2="248" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="308" y1="86" x2="308" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="368" y1="86" x2="368" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="428" y1="86" x2="428" y2="90" stroke="#2563eb" stroke-width="1.2" />

            <text x="68" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-12</text>
            <text x="128" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-13</text>
            <text x="188" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-14</text>
            <text x="248" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-15</text>
            <text x="308" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-16</text>
            <text x="368" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-17</text>
            <text x="428" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-18</text>
          </svg>
        </div>
      </div>

      <div class="trend-divider"></div>

      <!-- 2. 住院患者趋势 -->
      <div class="trend-chart-card">
        <div class="chart-title-row">
          <div class="panel-accent-bar"></div>
          <span class="chart-title">住院患者趋势 <span class="chart-days">(近7天)</span></span>
          <span class="latest-badge green-val">618</span>
        </div>
        <div class="svg-wrap">
          <svg viewBox="0 0 450 115" preserveAspectRatio="none" class="chart-svg">
            <defs>
              <linearGradient id="trendGreen" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stop-color="#00c882" stop-opacity="0.22" />
                <stop offset="100%" stop-color="#00b377" stop-opacity="0.0" />
              </linearGradient>
            </defs>
            <line x1="48" y1="18" x2="440" y2="18" stroke="rgba(25, 70, 120, 0.25)" stroke-width="1" />
            <line x1="48" y1="52" x2="440" y2="52" stroke="rgba(25, 70, 120, 0.25)" stroke-width="1" />
            <line x1="48" y1="86" x2="440" y2="86" stroke="rgba(30, 85, 150, 0.65)" stroke-width="1" />

            <text x="42" y="22" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="end">800</text>
            <text x="42" y="56" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="end">400</text>
            <text x="42" y="90" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="end">0</text>

            <polygon points="68,54 128,44 188,45 248,47 308,43 368,40 428,37 428,86 68,86" fill="url(#trendGreen)" />
            <polyline points="68,54 128,44 188,45 248,47 308,43 368,40 428,37" fill="none" stroke="#00c882" stroke-width="1.8" />

            <circle cx="68" cy="54" r="2.5" fill="#ffffff" stroke="#00c882" stroke-width="1.8" />
            <circle cx="128" cy="44" r="2.5" fill="#ffffff" stroke="#00c882" stroke-width="1.8" />
            <circle cx="188" cy="45" r="2.5" fill="#ffffff" stroke="#00c882" stroke-width="1.8" />
            <circle cx="248" cy="47" r="2.5" fill="#ffffff" stroke="#00c882" stroke-width="1.8" />
            <circle cx="308" cy="43" r="2.5" fill="#ffffff" stroke="#00c882" stroke-width="1.8" />
            <circle cx="368" cy="40" r="2.5" fill="#ffffff" stroke="#00c882" stroke-width="1.8" />
            <circle cx="428" cy="37" r="3.5" fill="#ffffff" stroke="#00c882" stroke-width="2" />

            <line x1="68" y1="86" x2="68" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="128" y1="86" x2="128" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="188" y1="86" x2="188" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="248" y1="86" x2="248" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="308" y1="86" x2="308" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="368" y1="86" x2="368" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="428" y1="86" x2="428" y2="90" stroke="#2563eb" stroke-width="1.2" />

            <text x="68" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-12</text>
            <text x="128" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-13</text>
            <text x="188" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-14</text>
            <text x="248" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-15</text>
            <text x="308" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-16</text>
            <text x="368" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-17</text>
            <text x="428" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-18</text>
          </svg>
        </div>
      </div>

      <div class="trend-divider"></div>

      <!-- 3. 手术量趋势 -->
      <div class="trend-chart-card">
        <div class="chart-title-row">
          <div class="panel-accent-bar"></div>
          <span class="chart-title">手术量趋势 <span class="chart-days">(近7天)</span></span>
          <span class="latest-badge cyan-val">42</span>
        </div>
        <div class="svg-wrap">
          <svg viewBox="0 0 450 115" preserveAspectRatio="none" class="chart-svg">
            <defs>
              <linearGradient id="trendBlue" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stop-color="#38bdf8" stop-opacity="0.22" />
                <stop offset="100%" stop-color="#0284c7" stop-opacity="0.0" />
              </linearGradient>
            </defs>
            <line x1="48" y1="18" x2="440" y2="18" stroke="rgba(25, 70, 120, 0.25)" stroke-width="1" />
            <line x1="48" y1="52" x2="440" y2="52" stroke="rgba(25, 70, 120, 0.25)" stroke-width="1" />
            <line x1="48" y1="86" x2="440" y2="86" stroke="rgba(30, 85, 150, 0.65)" stroke-width="1" />

            <text x="42" y="22" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="end">80</text>
            <text x="42" y="56" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="end">40</text>
            <text x="42" y="90" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="end">0</text>

            <polygon points="68,54 128,46 188,32 248,47 308,43 368,54 428,52 428,86 68,86" fill="url(#trendBlue)" />
            <polyline points="68,54 128,46 188,32 248,47 308,43 368,54 428,52" fill="none" stroke="#38bdf8" stroke-width="1.8" />

            <circle cx="68" cy="54" r="2.5" fill="#ffffff" stroke="#38bdf8" stroke-width="1.8" />
            <circle cx="128" cy="46" r="2.5" fill="#ffffff" stroke="#38bdf8" stroke-width="1.8" />
            <circle cx="188" cy="32" r="2.5" fill="#ffffff" stroke="#38bdf8" stroke-width="1.8" />
            <circle cx="248" cy="47" r="2.5" fill="#ffffff" stroke="#38bdf8" stroke-width="1.8" />
            <circle cx="308" cy="43" r="2.5" fill="#ffffff" stroke="#38bdf8" stroke-width="1.8" />
            <circle cx="368" cy="54" r="2.5" fill="#ffffff" stroke="#38bdf8" stroke-width="1.8" />
            <circle cx="428" cy="52" r="3.5" fill="#ffffff" stroke="#38bdf8" stroke-width="2" />

            <line x1="68" y1="86" x2="68" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="128" y1="86" x2="128" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="188" y1="86" x2="188" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="248" y1="86" x2="248" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="308" y1="86" x2="308" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="368" y1="86" x2="368" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="428" y1="86" x2="428" y2="90" stroke="#2563eb" stroke-width="1.2" />

            <text x="68" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-12</text>
            <text x="128" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-13</text>
            <text x="188" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-14</text>
            <text x="248" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-15</text>
            <text x="308" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-16</text>
            <text x="368" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-17</text>
            <text x="428" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-18</text>
          </svg>
        </div>
      </div>

      <div class="trend-divider"></div>

      <!-- 4. 床位使用率趋势 -->
      <div class="trend-chart-card">
        <div class="chart-title-row">
          <div class="panel-accent-bar"></div>
          <span class="chart-title">床位使用率趋势 <span class="chart-days">(近7天)</span></span>
          <span class="latest-badge amber-val">90.8%</span>
        </div>
        <div class="svg-wrap">
          <svg viewBox="0 0 450 115" preserveAspectRatio="none" class="chart-svg">
            <defs>
              <linearGradient id="trendAmber" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stop-color="#f59e0b" stop-opacity="0.22" />
                <stop offset="100%" stop-color="#d97706" stop-opacity="0.0" />
              </linearGradient>
            </defs>
            <line x1="48" y1="18" x2="440" y2="18" stroke="rgba(25, 70, 120, 0.25)" stroke-width="1" />
            <line x1="48" y1="52" x2="440" y2="52" stroke="rgba(25, 70, 120, 0.25)" stroke-width="1" />
            <line x1="48" y1="86" x2="440" y2="86" stroke="rgba(30, 85, 150, 0.65)" stroke-width="1" />

            <text x="42" y="22" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="end">100%</text>
            <text x="42" y="56" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="end">50%</text>
            <text x="42" y="90" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="end">0%</text>

            <polygon points="68,34 128,26 188,24 248,27 308,22 368,25 428,28 428,86 68,86" fill="url(#trendAmber)" />
            <polyline points="68,34 128,26 188,24 248,27 308,22 368,25 428,28" fill="none" stroke="#f59e0b" stroke-width="1.8" />

            <circle cx="68" cy="34" r="2.5" fill="#ffffff" stroke="#f59e0b" stroke-width="1.8" />
            <circle cx="128" cy="26" r="2.5" fill="#ffffff" stroke="#f59e0b" stroke-width="1.8" />
            <circle cx="188" cy="24" r="2.5" fill="#ffffff" stroke="#f59e0b" stroke-width="1.8" />
            <circle cx="248" cy="27" r="2.5" fill="#ffffff" stroke="#f59e0b" stroke-width="1.8" />
            <circle cx="308" cy="22" r="2.5" fill="#ffffff" stroke="#f59e0b" stroke-width="1.8" />
            <circle cx="368" cy="25" r="2.5" fill="#ffffff" stroke="#f59e0b" stroke-width="1.8" />
            <circle cx="428" cy="28" r="3.5" fill="#ffffff" stroke="#f59e0b" stroke-width="2" />

            <line x1="68" y1="86" x2="68" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="128" y1="86" x2="128" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="188" y1="86" x2="188" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="248" y1="86" x2="248" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="308" y1="86" x2="308" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="368" y1="86" x2="368" y2="90" stroke="#2563eb" stroke-width="1.2" />
            <line x1="428" y1="86" x2="428" y2="90" stroke="#2563eb" stroke-width="1.2" />

            <text x="68" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-12</text>
            <text x="128" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-13</text>
            <text x="188" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-14</text>
            <text x="248" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-15</text>
            <text x="308" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-16</text>
            <text x="368" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-17</text>
            <text x="428" y="104" fill="#8daed1" font-size="11" font-family="DIN Alternate, sans-serif" text-anchor="middle">09-18</text>
          </svg>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
</script>

<style scoped>
.trends-panel {
  width: 100%;
  height: 172px;
  padding: 8px 16px 8px 16px;
  background: var(--bg-card);
  border: 1px solid var(--border-card);
  border-radius: 6px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.45);
}

.trends-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 100%;
  gap: 12px;
}

.trend-chart-card {
  flex: 1;
  display: flex;
  flex-direction: column;
  position: relative;
  height: 100%;
}

.trend-divider {
  width: 1px;
  height: 110px;
  background: linear-gradient(180deg, transparent, rgba(26, 76, 134, 0.45), transparent);
}

.chart-title-row {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 2px;
}

.chart-title {
  font-size: 15px;
  font-weight: 700;
  color: #ffffff;
  letter-spacing: 0.5px;
}

.chart-days {
  font-size: 13px;
  font-weight: 400;
  color: #8daed1;
  margin-left: 2px;
}

.latest-badge {
  margin-left: auto;
  font-family: "DIN Alternate", "Helvetica Neue", sans-serif;
  font-size: 17px;
  font-weight: 800;
}

.cyan-val {
  color: #00d2ff;
  text-shadow: 0 0 8px rgba(0, 210, 255, 0.6);
}

.green-val {
  color: #00e699;
  text-shadow: 0 0 8px rgba(0, 230, 153, 0.6);
}

.amber-val {
  color: #ffb703;
  text-shadow: 0 0 8px rgba(255, 183, 3, 0.6);
}

.svg-wrap {
  flex: 1;
  width: 100%;
  margin-top: 2px;
}

.chart-svg {
  width: 100%;
  height: 100%;
}
</style>
