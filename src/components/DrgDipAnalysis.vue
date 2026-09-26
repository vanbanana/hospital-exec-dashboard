<template>
  <div class="tech-panel drg-panel">
    <!-- Header -->
    <div class="panel-header">
      <div class="panel-header-left">
        <div class="panel-accent-bar"></div>
        <span class="panel-title">DRG/DIP 运行分析</span>
        <span class="panel-subtitle">CMI 与 盈利能力</span>
      </div>
      <div class="panel-more-link">
        <span>&gt; 查看详情</span>
      </div>
    </div>

    <!-- Chart Container -->
    <div class="chart-container">
      <svg class="quadrant-svg" viewBox="0 0 520 285">
        <!-- Coordinate Box: X: 75 to 485 (width 410), Y: 25 to 225 (height 200) -->
        <!-- Background Grid Lines -->
        <line x1="75" y1="25" x2="485" y2="25" stroke="rgba(25, 70, 120, 0.2)" stroke-width="1" />
        <line x1="75" y1="91" x2="485" y2="91" stroke="rgba(25, 70, 120, 0.2)" stroke-width="1" />
        <line x1="75" y1="158" x2="485" y2="158" stroke="rgba(25, 70, 120, 0.2)" stroke-width="1" />
        <line x1="75" y1="225" x2="485" y2="225" stroke="rgba(25, 70, 120, 0.55)" stroke-width="1" />

        <!-- Quadrant Divider Reference Lines (CMI = 1.8 -> y = 105, 盈亏 = 280 -> x = 288) -->
        <line x1="75" y1="105" x2="485" y2="105" stroke="rgba(56, 189, 248, 0.35)" stroke-width="1" />
        <line x1="288" y1="25" x2="288" y2="225" stroke="rgba(56, 189, 248, 0.35)" stroke-width="1" />

        <!-- Quadrant Labels (Safe Clear Placement) -->
        <!-- Q1: Top-Left (高CMI · 低盈利) -->
        <g class="quad-label-group">
          <text x="92" y="46" fill="#ffb703" font-size="13" font-weight="700">高CMI · 低盈利</text>
          <text x="100" y="66" fill="#ffb703" font-size="12" font-weight="600">(结构优化)</text>
        </g>

        <!-- Q2: Top-Right (高CMI · 高盈利) -->
        <g class="quad-label-group">
          <text x="376" y="46" fill="#00f5d4" font-size="13" font-weight="700">高CMI · 高盈利</text>
          <text x="388" y="66" fill="#00f5d4" font-size="12" font-weight="600">(重点发展)</text>
        </g>

        <!-- Q3: Bottom-Left (低CMI · 低盈利) -->
        <g class="quad-label-group">
          <text x="92" y="196" fill="#ff7675" font-size="13" font-weight="700">低CMI · 低盈利</text>
          <text x="100" y="216" fill="#ff7675" font-size="12" font-weight="600">(需关注)</text>
        </g>

        <!-- Q4: Bottom-Right (低CMI · 高盈利) -->
        <g class="quad-label-group">
          <text x="376" y="196" fill="#00f5d4" font-size="13" font-weight="700">低CMI · 高盈利</text>
          <text x="388" y="216" fill="#00f5d4" font-size="12" font-weight="600">(提质增效)</text>
        </g>

        <!-- Y Axis Ticks & Numbers -->
        <line x1="71" y1="25" x2="75" y2="25" stroke="#38bdf8" stroke-width="1.5" />
        <line x1="71" y1="91" x2="75" y2="91" stroke="#38bdf8" stroke-width="1.5" />
        <line x1="71" y1="158" x2="75" y2="158" stroke="#38bdf8" stroke-width="1.5" />
        <line x1="71" y1="225" x2="75" y2="225" stroke="#38bdf8" stroke-width="1.5" />

        <text x="65" y="29" fill="#a0c4e8" font-size="12" font-family="DIN Alternate, sans-serif" text-anchor="end">3.0</text>
        <text x="65" y="95" fill="#a0c4e8" font-size="12" font-family="DIN Alternate, sans-serif" text-anchor="end">2.0</text>
        <text x="65" y="162" fill="#a0c4e8" font-size="12" font-family="DIN Alternate, sans-serif" text-anchor="end">1.0</text>
        <text x="65" y="229" fill="#a0c4e8" font-size="12" font-family="DIN Alternate, sans-serif" text-anchor="end">0.0</text>

        <!-- Y Axis Title (Vertical Text) -->
        <g transform="translate(24, 128) rotate(-90)">
          <text x="0" y="0" fill="#a0c4e8" font-size="12" text-anchor="middle" font-weight="500">CMI (病例综合指数)</text>
        </g>

        <!-- X Axis Ticks & Numbers -->
        <line x1="75" y1="225" x2="75" y2="230" stroke="#38bdf8" stroke-width="1.5" />
        <line x1="212" y1="225" x2="212" y2="230" stroke="#38bdf8" stroke-width="1.5" />
        <line x1="348" y1="225" x2="348" y2="230" stroke="#38bdf8" stroke-width="1.5" />
        <line x1="485" y1="225" x2="485" y2="230" stroke="#38bdf8" stroke-width="1.5" />

        <text x="75" y="244" fill="#a0c4e8" font-size="12" font-family="DIN Alternate, sans-serif" text-anchor="middle">-500</text>
        <text x="212" y="244" fill="#a0c4e8" font-size="12" font-family="DIN Alternate, sans-serif" text-anchor="middle">0</text>
        <text x="348" y="244" fill="#a0c4e8" font-size="12" font-family="DIN Alternate, sans-serif" text-anchor="middle">500</text>
        <text x="485" y="244" fill="#a0c4e8" font-size="12" font-family="DIN Alternate, sans-serif" text-anchor="middle">1,000</text>

        <!-- X Axis Title -->
        <text x="280" y="264" fill="#a0c4e8" font-size="13" text-anchor="middle" font-weight="500">盈亏金额 (万元)</text>

        <!-- Scatter Points (48 Authentic Points) -->
        <!-- Internal Medicine (内科: Blue #00a8ff) -->
        <circle cx="110" cy="180" r="4.5" fill="#00a8ff" stroke="#ffffff" stroke-width="0.8" />
        <circle cx="140" cy="172" r="4.5" fill="#00a8ff" stroke="#ffffff" stroke-width="0.8" />
        <circle cx="195" cy="148" r="4.5" fill="#00a8ff" stroke="#ffffff" stroke-width="0.8" />
        <circle cx="215" cy="162" r="4.5" fill="#00a8ff" stroke="#ffffff" stroke-width="0.8" />
        <circle cx="235" cy="115" r="4.5" fill="#00a8ff" stroke="#ffffff" stroke-width="0.8" />
        <circle cx="245" cy="145" r="4.5" fill="#00a8ff" stroke="#ffffff" stroke-width="0.8" />
        <circle cx="258" cy="132" r="4.5" fill="#00a8ff" stroke="#ffffff" stroke-width="0.8" />
        <circle cx="270" cy="154" r="4.5" fill="#00a8ff" stroke="#ffffff" stroke-width="0.8" />
        <circle cx="282" cy="125" r="4.5" fill="#00a8ff" stroke="#ffffff" stroke-width="0.8" />
        <circle cx="295" cy="142" r="4.5" fill="#00a8ff" stroke="#ffffff" stroke-width="0.8" />
        <circle cx="310" cy="130" r="4.5" fill="#00a8ff" stroke="#ffffff" stroke-width="0.8" />
        <circle cx="325" cy="85" r="5" fill="#00a8ff" stroke="#ffffff" stroke-width="0.8" />
        <circle cx="285" cy="218" r="4.5" fill="#00a8ff" stroke="#ffffff" stroke-width="0.8" />
        <circle cx="260" cy="180" r="4.5" fill="#00a8ff" stroke="#ffffff" stroke-width="0.8" />
        <circle cx="240" cy="195" r="4.5" fill="#00a8ff" stroke="#ffffff" stroke-width="0.8" />

        <!-- Surgery (外科: Cyan #38bdf8) -->
        <circle cx="285" cy="108" r="4.5" fill="#38bdf8" />
        <circle cx="272" cy="144" r="4.5" fill="#38bdf8" />
        <circle cx="298" cy="148" r="4.5" fill="#38bdf8" />
        <circle cx="312" cy="152" r="4.5" fill="#38bdf8" />
        <circle cx="278" cy="162" r="4.5" fill="#38bdf8" />
        <circle cx="252" cy="168" r="4.5" fill="#38bdf8" />
        <circle cx="265" cy="178" r="4.5" fill="#38bdf8" />
        <circle cx="238" cy="165" r="4.5" fill="#38bdf8" />
        <circle cx="304" cy="138" r="4.5" fill="#38bdf8" />
        <circle cx="288" cy="158" r="4.5" fill="#38bdf8" />

        <!-- MedTech (医技: Yellow/Gold #ffb703) -->
        <circle cx="185" cy="182" r="5" fill="#ffb703" stroke="#ffffff" stroke-width="0.8" />
        <circle cx="198" cy="155" r="5" fill="#ffb703" stroke="#ffffff" stroke-width="0.8" />
        <circle cx="208" cy="175" r="5" fill="#ffb703" stroke="#ffffff" stroke-width="0.8" />
        <circle cx="220" cy="188" r="5" fill="#ffb703" stroke="#ffffff" stroke-width="0.8" />
        <circle cx="228" cy="158" r="5" fill="#ffdf7e" stroke="#ffffff" stroke-width="0.8" />

        <!-- Other / Specialized (绿色/蓝青: #00e699 / #00f5d4) -->
        <circle cx="318" cy="138" r="4.5" fill="#00e699" />
        <circle cx="330" cy="120" r="5" fill="#00e699" />
        <circle cx="342" cy="128" r="4.5" fill="#00e699" />
        <circle cx="358" cy="132" r="5" fill="#00e699" />
        <circle cx="368" cy="155" r="4.5" fill="#00e699" />
        <circle cx="378" cy="168" r="4.5" fill="#00e699" />
        <circle cx="388" cy="160" r="5" fill="#00e699" />
        <circle cx="412" cy="145" r="4.5" fill="#00e699" />
        <circle cx="428" cy="128" r="5" fill="#00e699" />
        <circle cx="438" cy="124" r="4.5" fill="#00e699" />
        <circle cx="452" cy="148" r="4.5" fill="#00e699" />
        <circle cx="482" cy="168" r="5" fill="#00e699" />
        <circle cx="348" cy="202" r="4.5" fill="#00e699" />
        <circle cx="322" cy="214" r="4.5" fill="#00e699" />
        <circle cx="418" cy="198" r="4.5" fill="#00e699" />
        <circle cx="440" cy="212" r="4.5" fill="#00e699" />
        <circle cx="365" cy="182" r="4.5" fill="#00e699" />
      </svg>

      <!-- Bottom Legend -->
      <div class="chart-legend">
        <div class="legend-item">
          <span class="legend-dot dot-internal"></span>
          <span class="legend-text">内科</span>
        </div>
        <div class="legend-item">
          <span class="legend-dot dot-surgery"></span>
          <span class="legend-text">外科</span>
        </div>
        <div class="legend-item">
          <span class="legend-dot dot-medtech"></span>
          <span class="legend-text">医技</span>
        </div>
        <div class="legend-item">
          <span class="legend-dot dot-other"></span>
          <span class="legend-text">其他</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
</script>

<style scoped>
.drg-panel {
  width: 100%;
  height: 376px;
}

.chart-container {
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  padding: 4px 12px 10px 12px;
  position: relative;
}

.quadrant-svg {
  width: 100%;
  height: 282px;
}

.chart-legend {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 28px;
  margin-top: -6px;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 6px;
}

.legend-dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  display: inline-block;
}

.dot-internal {
  background-color: #0091ff;
}

.dot-surgery {
  background-color: #38bdf8;
}

.dot-medtech {
  background-color: #f59e0b;
}

.dot-other {
  background-color: #93c5fd;
}

.legend-text {
  font-size: 13px;
  color: #c5dbee;
  font-weight: 500;
}
</style>
