<template>
  <header class="header-container">
    <!-- Left: Hospital Logo & Name -->
    <div class="header-left">
      <div class="logo-box">
        <img src="../assets/hospital_logo.svg" alt="市中心医院院徽" class="logo-img" />
      </div>
      <div class="hospital-title-group">
        <div class="hospital-name">市中心医院</div>
        <div class="hospital-motto">厚德 &nbsp;精医 &nbsp;仁爱 &nbsp;创新</div>
      </div>
    </div>

    <!-- Center: Main Screen Title & Core Slogan (Dead-center absolute alignment) -->
    <div class="header-center">
      <h1 class="screen-title">市中心医院 · 综合运营决策指挥大屏</h1>
      <div class="screen-subtitle">人民至上 · 生命至上 · 精细管理 · 高质量发展</div>
    </div>

    <!-- Right: Time & Operational Status Badge -->
    <div class="header-right">
      <div class="datetime-box">
        <div class="time-str">2026-09-18 &nbsp;08:30</div>
        <div class="weekday-str">星期五</div>
      </div>

      <div class="status-badge">
        <div class="status-icon-circle">
          <svg viewBox="0 0 24 24" class="check-svg">
            <path d="M5 13l4 4L19 7" stroke="#ffffff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" fill="none" />
          </svg>
        </div>
        <div class="status-text-group">
          <div class="status-title">运行平稳</div>
          <div class="status-desc">医院整体运行正常</div>
        </div>
      </div>
    </div>

    <!-- Bottom High-Tech Cyan Line with Centered Stepped Accent -->
    <div class="header-bottom-line">
      <svg class="line-svg" viewBox="0 0 2048 20" preserveAspectRatio="none">
        <defs>
          <linearGradient id="lineGlow" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stop-color="#0066cc" stop-opacity="0.1" />
            <stop offset="30%" stop-color="#0284c7" stop-opacity="0.5" />
            <stop offset="46%" stop-color="#38bdf8" stop-opacity="0.9" />
            <stop offset="50%" stop-color="#ffffff" stop-opacity="1" />
            <stop offset="54%" stop-color="#38bdf8" stop-opacity="0.9" />
            <stop offset="70%" stop-color="#0284c7" stop-opacity="0.5" />
            <stop offset="100%" stop-color="#0066cc" stop-opacity="0.1" />
          </linearGradient>
        </defs>
        <!-- Background track -->
        <line x1="0" y1="12" x2="2048" y2="12" stroke="rgba(24, 70, 120, 0.4)" stroke-width="1.5" />
        <!-- Stepped trapezoid line precisely framing the center column (534px to 1498px) -->
        <path d="M 0 12 L 530 12 L 558 19 L 1490 19 L 1518 12 L 2048 12" fill="none" stroke="url(#lineGlow)" stroke-width="2" />
        <!-- Center flare bar centered at 1024px -->
        <rect x="864" y="17.5" width="320" height="3" rx="1.5" fill="#38bdf8" />
      </svg>
    </div>
  </header>
</template>

<script setup lang="ts">
</script>

<style scoped>
.header-container {
  width: 100%;
  height: 88px;
  position: relative;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 24px 8px 24px;
  background: linear-gradient(180deg, rgba(3, 18, 40, 0.98) 0%, rgba(2, 14, 32, 0.92) 100%);
  border-bottom: 1px solid rgba(24, 76, 138, 0.4);
  z-index: 50;
}

/* Left Group */
.header-left {
  display: flex;
  align-items: center;
  gap: 14px;
  z-index: 2;
}

.logo-box {
  width: 52px;
  height: 52px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(14, 52, 107, 0.6) 0%, transparent 70%);
  display: flex;
  align-items: center;
  justify-content: center;
}

.logo-img {
  width: 50px;
  height: 50px;
  object-fit: contain;
}

.hospital-title-group {
  display: flex;
  flex-direction: column;
  justify-content: center;
}

.hospital-name {
  font-size: 24px;
  font-weight: 800;
  letter-spacing: 1.5px;
  color: #ffffff;
  line-height: 1.2;
}

.hospital-motto {
  font-size: 12px;
  font-weight: 500;
  letter-spacing: 3px;
  color: #7fa4cc;
  margin-top: 4px;
}

/* Center Group (Dead-center locked) */
.header-center {
  position: absolute;
  left: 50%;
  top: 12px;
  transform: translateX(-50%);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  pointer-events: none;
  z-index: 10;
}

.screen-title {
  font-size: 32px;
  font-weight: 900;
  letter-spacing: 2px;
  color: #ffffff;
  text-shadow: 0 2px 4px rgba(0, 0, 0, 0.6), 0 0 14px rgba(0, 145, 255, 0.35);
  line-height: 1.15;
}

.screen-subtitle {
  font-size: 13px;
  font-weight: 500;
  letter-spacing: 3px;
  color: #8bb5e0;
  margin-top: 5px;
}

/* Right Group */
.header-right {
  display: flex;
  align-items: center;
  gap: 20px;
  justify-content: flex-end;
  z-index: 2;
}

.datetime-box {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
}

.time-str {
  font-family: "DIN Alternate", "Helvetica Neue", sans-serif;
  font-size: 22px;
  font-weight: 700;
  color: #ffffff;
  letter-spacing: 0.5px;
}

.weekday-str {
  font-size: 13px;
  color: #7ea4cc;
  margin-top: 1px;
}

/* Status Badge */
.status-badge {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 6px 14px;
  border-radius: 6px;
  background: rgba(0, 36, 28, 0.5);
  border: 1px solid #00c882;
}

.status-icon-circle {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  background: #00c882;
  display: flex;
  align-items: center;
  justify-content: center;
}

.check-svg {
  width: 14px;
  height: 14px;
}

.status-text-group {
  display: flex;
  flex-direction: column;
}

.status-title {
  font-size: 14px;
  font-weight: 800;
  color: #00e699;
  letter-spacing: 1px;
  line-height: 1.2;
}

.status-desc {
  font-size: 11px;
  color: #a8e5cc;
  margin-top: 2px;
  letter-spacing: 0.5px;
}

/* Bottom Line */
.header-bottom-line {
  position: absolute;
  left: 0;
  bottom: 0;
  width: 100%;
  height: 20px;
  pointer-events: none;
}

.line-svg {
  width: 100%;
  height: 100%;
}
</style>
