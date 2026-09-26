<template>
  <header class="workbench-header">
    <!-- Left Titles -->
    <div class="header-left">
      <h2 class="system-title">院长查询与决策支持系统</h2>
      <div class="title-divider"></div>
      <span class="system-subtitle">数据赋能管理 · 决策引领发展</span>
    </div>

    <!-- Right Controls & Info -->
    <div class="header-right">
      <div class="header-top-row">
        <!-- Search Box -->
        <div class="search-box">
          <Search class="search-icon" :size="15" />
          <input
            type="text"
            placeholder="请输入关键词（如：科室、指标、日期等）"
            class="search-input"
          />
        </div>

        <!-- Notification Bell -->
        <div class="notice-badge-wrapper">
          <Bell class="bell-icon" :size="19" />
          <span class="badge-dot">4</span>
        </div>

        <div class="action-divider"></div>

        <!-- Director Profile -->
        <div class="user-profile">
          <img
            src="../../assets/workbench/director_avatar.png"
            alt="院长头像"
            class="avatar-img"
          />
          <span class="user-role">院长</span>
          <ChevronDown class="dropdown-icon" :size="14" />
        </div>
      </div>

      <!-- Date Display -->
      <div class="header-bottom-date">
        2026年10月28日 星期三
      </div>
    </div>
  </header>
</template>

<script setup lang="ts">
import { Search, Bell, ChevronDown } from 'lucide-vue-next'
</script>

<style scoped>
.workbench-header {
  height: 64px;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 16px;
  user-select: none;
}

.header-left {
  display: flex;
  align-items: center;
}

.system-title {
  font-size: 20px;
  font-weight: 700;
  color: var(--wb-navy);
  letter-spacing: 0.5px;
  margin: 0;
}

.title-divider {
  width: 1px;
  height: 15px;
  background-color: #cbd5e1;
  margin: 0 12px;
}

.system-subtitle {
  font-size: 13px;
  color: var(--wb-text-2);
  font-weight: 400;
  letter-spacing: 0.3px;
}

.header-right {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 2px;
}

.header-top-row {
  display: flex;
  align-items: center;
  gap: 16px;
}

.search-box {
  width: 320px;
  height: 34px;
  background: var(--wb-surface);
  border: 1px solid var(--wb-input-border);
  border-radius: 17px;
  display: flex;
  align-items: center;
  padding: 0 12px;
  gap: 8px;
}

.search-icon {
  color: var(--wb-text-4);
  flex-shrink: 0;
}

.search-input {
  border: none;
  outline: none;
  background: transparent;
  width: 100%;
  font-size: 12px;
  color: var(--wb-text-1);
}

.search-input::placeholder {
  color: var(--wb-text-4);
}

.notice-badge-wrapper {
  position: relative;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
}

.bell-icon {
  color: var(--wb-text-2);
  transition: color 0.15s;
}

.bell-icon:hover {
  color: var(--wb-primary);
}

.badge-dot {
  position: absolute;
  top: 1px;
  right: 1px;
  background-color: var(--wb-red);
  color: #ffffff;
  font-size: 10px;
  font-weight: 700;
  width: 14px;
  height: 14px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1.5px solid #ffffff;
  line-height: 1;
}

.action-divider {
  width: 1px;
  height: 18px;
  background-color: #e2e8f0;
}

.user-profile {
  display: flex;
  align-items: center;
  gap: 7px;
  cursor: pointer;
}

.avatar-img {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  object-fit: cover;
  border: 1px solid #dbeafe;
}

.user-role {
  font-size: 13px;
  font-weight: 600;
  color: var(--wb-text-1);
}

.dropdown-icon {
  color: var(--wb-text-3);
}

.header-bottom-date {
  font-size: 12px;
  color: var(--wb-text-3);
  letter-spacing: 0.2px;
}
</style>
