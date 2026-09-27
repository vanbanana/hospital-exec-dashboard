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
        <!-- 搜索无契约端点支撑，禁用防死交互 -->
        <div class="search-box">
          <Search class="search-icon" :size="15" />
          <input
            type="text"
            placeholder="请输入关键词（如：科室、指标、日期等）"
            class="search-input"
            disabled
          />
        </div>

        <!-- Notification Bell：角标 = 风险预警条数（复用 home/alerts），无数据隐藏徽标 -->
        <div class="notice-badge-wrapper">
          <Bell class="bell-icon" :size="19" />
          <span v-if="alertCount > 0" class="badge-dot">{{ alertCount }}</span>
        </div>

        <div class="action-divider"></div>

        <!-- Director Profile -->
        <div class="user-profile">
          <img
            :src="profile?.user.avatar || fallbackAvatar"
            alt="头像"
            class="avatar-img"
          />
          <span class="user-role">{{ profile?.user.title ?? '院长' }}</span>
          <ChevronDown class="dropdown-icon" :size="14" />
        </div>
      </div>

      <!-- Date Display：auth/profile system_date + weekday -->
      <div class="header-bottom-date">
        {{ dateText }}
      </div>
    </div>
  </header>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { Search, Bell, ChevronDown } from 'lucide-vue-next'
import { getAuthProfile } from '../../api/auth'
import { getHomeAlerts } from '../../api/workbench'
import type { AuthProfileResp } from '../../api/types'

const profile = ref<AuthProfileResp | null>(null)
const alertCount = ref(0)

// 头像降级：data=null/接口失败时回退默认身份展示（frontend-api §2.1 空态）
const fallbackAvatar = new URL('../../assets/workbench/director_avatar.png', import.meta.url).href

onMounted(async () => {
  profile.value = await getAuthProfile().catch(() => null)
  alertCount.value = await getHomeAlerts().then((r) => r.list.length).catch(() => 0)
})

// system_date(YYYY-MM-DD) + weekday → "2026年10月28日 星期三"
const dateText = computed(() => {
  const p = profile.value
  if (!p?.system_date) return ''
  const [y, m, d] = p.system_date.split('-').map(Number)
  return `${y}年${m}月${d}日 ${p.weekday}`
})
</script>

<style scoped>
.workbench-header {
  height: var(--wb-header-h);
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-inline: var(--wb-space-4);
  user-select: none;
}

.header-left {
  display: flex;
  align-items: center;
}

.system-title {
  font-size: var(--wb-fs-xl);
  font-weight: var(--wb-fw-bold);
  color: var(--wb-navy);
  letter-spacing: var(--wb-ls-lg);
  margin: 0;
}

.title-divider {
  width: 1px;
  height: 15px;
  background-color: var(--p-slate-300);
  margin-inline: var(--wb-space-3);
}

.system-subtitle {
  font-size: var(--wb-fs-md);
  color: var(--wb-text-2);
  font-weight: var(--wb-fw-normal);
  letter-spacing: var(--wb-ls-md);
}

.header-right {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: var(--wb-space-1);
}

.header-top-row {
  display: flex;
  align-items: center;
  gap: var(--wb-space-4);
}

.search-box {
  width: 320px;
  height: 34px;
  background: var(--wb-surface);
  border: 1px solid var(--wb-input-border);
  border-radius: var(--wb-radius-pill);
  display: flex;
  align-items: center;
  padding-inline: var(--wb-space-3);
  gap: var(--wb-space-2);
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
  font-size: var(--wb-fs-sm);
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
  transition: color var(--wb-dur-fast);
}

.bell-icon:hover {
  color: var(--wb-primary);
}

.badge-dot {
  position: absolute;
  top: 1px;
  right: 1px;
  background-color: var(--wb-red);
  color: var(--p-white);
  font-size: var(--wb-fs-2xs);
  font-weight: var(--wb-fw-bold);
  width: 14px;
  height: 14px;
  border-radius: var(--wb-radius-pill);
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1.5px solid var(--p-white);
  line-height: var(--wb-lh-solid);
}

.action-divider {
  width: 1px;
  height: 18px;
  background-color: var(--p-slate-200);
}

.user-profile {
  display: flex;
  align-items: center;
  gap: var(--wb-space-2);
  cursor: pointer;
}

.avatar-img {
  width: 32px;
  height: 32px;
  border-radius: var(--wb-radius-pill);
  object-fit: cover;
  border: 1px solid var(--wb-border);
}

.user-role {
  font-size: var(--wb-fs-md);
  font-weight: var(--wb-fw-semibold);
  color: var(--wb-text-1);
}

.dropdown-icon {
  color: var(--wb-text-3);
}

.header-bottom-date {
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-3);
  letter-spacing: var(--wb-ls-sm);
}
</style>
