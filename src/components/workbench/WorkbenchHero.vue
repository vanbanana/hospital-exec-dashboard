<template>
  <section class="workbench-hero">
    <!-- Left Slogan Text -->
    <div class="hero-left">
      <div class="slogan-line first-line">{{ profile.slogans[0] }}</div>
      <div class="slogan-line second-line">{{ profile.slogans[1] }}</div>
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
        <img src="../../assets/workbench/slogan_col3.png" :alt="profile.pillars[2]" />
      </div>
      <div class="calligraphy-col col-shengming">
        <img src="../../assets/workbench/slogan_col2.png" :alt="profile.pillars[1]" />
      </div>
      <div class="calligraphy-col col-renmin">
        <img src="../../assets/workbench/slogan_col1.png" :alt="profile.pillars[0]" />
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { getHospitalProfile } from '../../api/auth'
import type { HospitalProfileResp } from '../../api/types'

// 文案回退硬编码：data=null/接口失败时不留白（frontend-api §2.2 空态）
const profile = ref<HospitalProfileResp>({
  name: '',
  english_name: '',
  level: '',
  motto: [],
  slogans: ['以数据洞察全局', '以科学决策引领医院高质量发展'],
  pillars: ['人民至上', '生命至上', '健康至上'],
})

onMounted(async () => {
  profile.value = (await getHospitalProfile().catch(() => null)) ?? profile.value
})
</script>

<style scoped>
.workbench-hero {
  position: relative;
  height: 130px; /* 美术稿 */
  flex-shrink: 0;
  background: linear-gradient(135deg, #dcecfe 0%, #ebf3fe 38%, #e1effe 72%, #d9e9fe 100%); /* 美术稿 */
  border-radius: var(--wb-radius-card);
  border: 1px solid var(--wb-border);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-inline: 32px; /* 美术稿 */
  overflow: hidden;
  user-select: none;
}

.hero-left {
  position: relative;
  z-index: var(--wb-z-sticky);
  display: flex;
  flex-direction: column;
}

.slogan-line {
  font-size: var(--wb-fs-hero);
  font-weight: var(--wb-fw-bold);
  color: #123e8c; /* 美术稿 */
  letter-spacing: var(--wb-ls-xl);
  line-height: var(--wb-lh-normal);
  white-space: nowrap;
}

.second-line {
  margin-top: var(--wb-space-1);
  margin-left: 44px; /* 美术稿 */
}

.slogan-accent-bar {
  width: 32px; /* 美术稿 */
  height: 3px;
  background-color: #1d5ec9; /* 美术稿 */
  border-radius: var(--wb-radius-sm);
  margin-top: var(--wb-space-2);
}

.hero-building-container {
  position: absolute;
  top: 0;
  bottom: 0;
  right: 216px; /* 美术稿 */
  width: 520px; /* 美术稿 */
  height: 100%;
  pointer-events: none;
  z-index: var(--wb-z-raised);
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
  z-index: var(--wb-z-sticky);
  display: flex;
  align-items: flex-start;
  gap: var(--wb-space-5);
}

.calligraphy-col {
  display: flex;
  align-items: center;
  justify-content: center;
}

.calligraphy-col img {
  height: 80px; /* 美术稿 */
  width: auto;
  object-fit: contain;
}

/* Staggered vertical waterfall arrangement */
.col-renmin {
  margin-top: 0;
}

.col-shengming {
  margin-top: var(--wb-space-5);
}

.col-jiankang {
  margin-top: 36px; /* 美术稿 */
}
</style>
