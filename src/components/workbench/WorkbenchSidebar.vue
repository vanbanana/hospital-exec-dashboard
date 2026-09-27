<template>
  <aside class="workbench-sidebar">
    <!-- Top Brand -->
    <div class="sidebar-brand">
      <img src="../../assets/workbench/hospital_logo.png" alt="院徽" class="brand-logo" />
      <div class="brand-text">
        <h1 class="brand-title">{{ profile.name }}</h1>
        <p class="brand-sub">{{ profile.english_name }}</p>
      </div>
    </div>

    <!-- Navigation Menu -->
    <nav class="sidebar-nav">
      <router-link
        v-for="item in menuItems"
        :key="item.name"
        :to="item.to"
        custom
        v-slot="{ isActive, isExactActive, navigate }"
      >
        <a
          class="nav-item"
          :class="{ active: item.exact ? isExactActive : isActive }"
          @click="navigate"
        >
          <component :is="item.icon" class="nav-icon" :size="16" :stroke-width="1.9" />
          <span class="nav-label">{{ item.name }}</span>
        </a>
      </router-link>
    </nav>

    <!-- Bottom Motto & Sketch -->
    <div class="sidebar-footer">
      <div class="sketch-wrapper">
        <img src="../../assets/workbench/building_sketch.png" alt="建筑线描" class="sketch-img" />
      </div>
      <div class="motto-text">
        <span v-for="w in profile.motto" :key="w">{{ w }}</span>
      </div>
    </div>
  </aside>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { getHospitalProfile } from '../../api/auth'
import type { HospitalProfileResp } from '../../api/types'
import {
  Home,
  LayoutGrid,
  Cross,
  Briefcase,
  Users,
  GraduationCap,
  HeartHandshake,
  Shield,
  Boxes,
  BarChart2,
  PieChart,
  Settings,
} from 'lucide-vue-next'

// 品牌区回退硬编码文案：data=null/接口失败时不留白（frontend-api §2.2 空态）
const profile = ref<HospitalProfileResp>({
  name: 'XX市人民医院',
  english_name: "PEOPLE'S HOSPITAL",
  level: '三级甲等综合医院',
  motto: ['厚德', '精医', '仁爱', '创新'],
  slogans: [],
  pillars: [],
})

onMounted(async () => {
  profile.value = (await getHospitalProfile().catch(() => null)) ?? profile.value
})

const menuItems = [
  { name: '首页', icon: Home, to: '/workbench', exact: true },
  { name: '综合概览', icon: LayoutGrid, to: '/workbench/overview' },
  { name: '医疗业务', icon: Cross, to: '/workbench/medical' },
  { name: '运营管理', icon: Briefcase, to: '/workbench/operations' },
  { name: '人力资源', icon: Users, to: '/workbench/hr' },
  { name: '科研教学', icon: GraduationCap, to: '/workbench/research' },
  { name: '患者服务', icon: HeartHandshake, to: '/workbench/patient' },
  { name: '质量与安全', icon: Shield, to: '/workbench/quality' },
  { name: '资产与后勤', icon: Boxes, to: '/workbench/assets' },
  { name: '对比分析', icon: BarChart2, to: '/workbench/compare' },
  { name: '专题分析', icon: PieChart, to: '/workbench/topics' },
  { name: '系统设置', icon: Settings, to: '/workbench/settings' },
]
</script>

<style scoped>
.workbench-sidebar {
  width: var(--wb-sidebar-w);
  height: 100vh;
  flex-shrink: 0;
  background: var(--wb-sidebar-bg);
  border-right: 1px solid var(--wb-border);
  display: flex;
  flex-direction: column;
  position: relative;
  overflow: hidden;
  user-select: none;
}

.sidebar-brand {
  display: flex;
  align-items: center;
  gap: var(--wb-space-2);
  padding: var(--wb-space-4) var(--wb-space-4) var(--wb-space-3);
}

.brand-logo {
  width: 38px;
  height: 38px;
  border-radius: var(--wb-radius-pill);
  flex-shrink: 0;
}

.brand-text {
  display: flex;
  flex-direction: column;
}

.brand-title {
  font-size: var(--wb-fs-lg);
  font-weight: var(--wb-fw-bold);
  color: var(--wb-navy);
  line-height: var(--wb-lh-snug);
  letter-spacing: var(--wb-ls-lg);
  margin: 0;
}

.brand-sub {
  font-size: var(--wb-fs-2xs);
  font-weight: var(--wb-fw-semibold);
  color: var(--wb-text-3);
  letter-spacing: var(--wb-ls-xl);
  line-height: var(--wb-lh-compact);
  margin-top: var(--wb-space-1);
}

.sidebar-nav {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: var(--wb-space-1);
  padding: var(--wb-space-1) var(--wb-space-3);
  overflow-y: auto;
  scrollbar-width: none;
}
.sidebar-nav::-webkit-scrollbar {
  display: none;
}

.nav-item {
  display: flex;
  align-items: center;
  gap: var(--wb-space-2);
  padding: var(--wb-space-2) var(--wb-space-3);
  border-radius: var(--wb-radius-inner);
  text-decoration: none;
  color: var(--wb-text-2);
  font-size: var(--wb-fs-md);
  font-weight: var(--wb-fw-medium);
  cursor: pointer;
  transition: background var(--wb-dur-fast) ease, color var(--wb-dur-fast) ease;
}

.nav-icon {
  color: var(--wb-text-3);
  flex-shrink: 0;
  transition: color var(--wb-dur-fast) ease;
}

.nav-item:hover {
  background: var(--wb-accent-soft);
  color: var(--wb-primary);
}

.nav-item:hover .nav-icon {
  color: var(--wb-primary);
}

.nav-item.active {
  background: var(--wb-accent);
  color: var(--p-white);
  box-shadow: var(--wb-shadow-accent);
}

.nav-item.active .nav-icon {
  color: var(--p-white);
}

.sidebar-footer {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
  padding-bottom: var(--wb-pad-y);
  margin-top: auto;
}

.sketch-wrapper {
  position: absolute;
  bottom: 28px;
  left: 0;
  right: 0;
  height: 90px;
  overflow: hidden;
  pointer-events: none;
  display: flex;
  align-items: flex-end;
  justify-content: center;
}

.sketch-img {
  width: 100%;
  opacity: var(--wb-opacity-dimmed);
  object-fit: cover;
  filter: contrast(1.1);
}

.motto-text {
  position: relative;
  z-index: var(--wb-z-sticky);
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 82%;
  font-family: "STSong", "Songti SC", "SimSun", serif;
  font-size: var(--wb-fs-sm);
  font-weight: var(--wb-fw-medium);
  color: var(--wb-text-2);
  letter-spacing: var(--wb-ls-2xl);
}
</style>
