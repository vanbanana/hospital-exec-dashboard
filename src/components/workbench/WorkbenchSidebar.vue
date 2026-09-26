<template>
  <aside class="workbench-sidebar">
    <!-- Top Brand -->
    <div class="sidebar-brand">
      <img src="../../assets/workbench/hospital_logo.png" alt="院徽" class="brand-logo" />
      <div class="brand-text">
        <h1 class="brand-title">XX市人民医院</h1>
        <p class="brand-sub">PEOPLE'S HOSPITAL</p>
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
        <span>厚德</span>
        <span>精医</span>
        <span>仁爱</span>
        <span>创新</span>
      </div>
    </div>
  </aside>
</template>

<script setup lang="ts">
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
  width: 204px;
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
  gap: 10px;
  padding: 16px 16px 12px;
}

.brand-logo {
  width: 38px;
  height: 38px;
  border-radius: 50%;
  flex-shrink: 0;
}

.brand-text {
  display: flex;
  flex-direction: column;
}

.brand-title {
  font-size: 16px;
  font-weight: 700;
  color: var(--wb-navy);
  line-height: 1.25;
  letter-spacing: 0.5px;
  margin: 0;
}

.brand-sub {
  font-size: 9px;
  font-weight: 600;
  color: var(--wb-text-3);
  letter-spacing: 1px;
  line-height: 1.2;
  margin-top: 3px;
}

.sidebar-nav {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 4px 12px;
  overflow-y: auto;
  scrollbar-width: none;
}
.sidebar-nav::-webkit-scrollbar {
  display: none;
}

.nav-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 9px 12px;
  border-radius: var(--wb-radius-inner);
  text-decoration: none;
  color: var(--wb-text-2);
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease;
}

.nav-icon {
  color: var(--wb-text-3);
  flex-shrink: 0;
  transition: color 0.15s ease;
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
  color: #ffffff;
  box-shadow: 0 3px 8px rgba(37, 99, 235, 0.25);
}

.nav-item.active .nav-icon {
  color: #ffffff;
}

.sidebar-footer {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
  padding-bottom: 14px;
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
  opacity: 0.7;
  object-fit: cover;
  filter: contrast(1.1);
}

.motto-text {
  position: relative;
  z-index: 2;
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 82%;
  font-family: "STSong", "Songti SC", "SimSun", serif;
  font-size: 12px;
  font-weight: 500;
  color: var(--wb-text-2);
  letter-spacing: 2px;
}
</style>
