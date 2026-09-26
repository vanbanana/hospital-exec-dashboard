<template>
  <section class="workbench-hero">
    <!-- Left Slogan Text -->
    <div class="hero-left">
      <div class="slogan-line first-line">以数据洞察全局</div>
      <div class="slogan-line second-line">以科学决策引领医院高质量发展</div>
      <div class="slogan-accent-bar"></div>
    </div>

    <!-- Center/Right Hospital Building Illustration -->
    <div class="hero-building-container">
      <img
        src="../../assets/workbench/hero_building.png"
        alt="医院门诊大楼"
        class="hero-building-img"
      />
    </div>

    <!-- Right Calligraphy Pillars -->
    <div class="hero-calligraphy">
      <div class="calligraphy-col col-jiankang">
        <img src="../../assets/workbench/slogan_col3.png" alt="健康至上" />
      </div>
      <div class="calligraphy-col col-shengming">
        <img src="../../assets/workbench/slogan_col2.png" alt="生命至上" />
      </div>
      <div class="calligraphy-col col-renmin">
        <img src="../../assets/workbench/slogan_col1.png" alt="人民至上" />
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
// Hero component
</script>

<style scoped>
.workbench-hero {
  position: relative;
  height: 130px;
  flex-shrink: 0;
  background: linear-gradient(135deg, #dcecfe 0%, #ebf3fe 38%, #e1effe 72%, #d9e9fe 100%);
  border-radius: var(--wb-radius-card);
  border: 1px solid var(--wb-border);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 32px;
  overflow: hidden;
  user-select: none;
}

.hero-left {
  position: relative;
  z-index: 2;
  display: flex;
  flex-direction: column;
}

.slogan-line {
  font-size: 24px;
  font-weight: 700;
  color: #123e8c;
  letter-spacing: 1px;
  line-height: 1.35;
  white-space: nowrap;
}

.second-line {
  margin-top: 4px;
  margin-left: 44px;
}

.slogan-accent-bar {
  width: 32px;
  height: 3px;
  background-color: #1d5ec9;
  border-radius: 2px;
  margin-top: 10px;
}

.hero-building-container {
  position: absolute;
  top: 0;
  bottom: 0;
  right: 216px;
  width: 520px;
  height: 100%;
  pointer-events: none;
  z-index: 1;
  display: flex;
  align-items: center;
  justify-content: center;
}

.hero-building-img {
  height: 100%;
  width: 100%;
  object-fit: contain;
  object-position: center;
}

.hero-calligraphy {
  position: relative;
  z-index: 2;
  display: flex;
  align-items: flex-start;
  gap: 18px;
}

.calligraphy-col {
  display: flex;
  align-items: center;
  justify-content: center;
}

.calligraphy-col img {
  height: 80px;
  width: auto;
  object-fit: contain;
}

/* Staggered vertical waterfall arrangement */
.col-renmin {
  margin-top: 0;
}

.col-shengming {
  margin-top: 18px;
}

.col-jiankang {
  margin-top: 36px;
}
</style>
