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

        <!-- Director Profile：点击展开角色切换菜单(契约 §2.1 ?role= 演示上下文) -->
        <div class="user-profile" ref="profileEl" @click="roleOpen = !roleOpen">
          <img
            :src="profile?.user.avatar || fallbackAvatar"
            alt="头像"
            class="avatar-img"
          />
          <span class="user-role">{{ profile?.user.title ?? '院长' }}</span>
          <ChevronDown class="dropdown-icon" :size="14" />
          <div v-if="roleOpen" class="role-menu" @click.stop>
            <!-- 视角切换=管理位特权：仅 admin/president 会话开放（§2.1 演进注，写面 admin 域同口径） -->
            <template v-if="canSwitchRole">
              <div
                v-for="r in profile?.available_roles ?? []"
                :key="r.role"
                class="role-item"
                :class="{ 'is-active': r.role === profile?.user.role }"
                @click="switchRole(r.role)"
              >
                <span class="role-name">{{ r.name }}</span>
                <span class="role-scope">{{ r.scope }}</span>
              </div>
              <div class="menu-divider"></div>
            </template>
            <div class="role-item logout-item" @click="onLogout">
              <LogOut :size="14" class="logout-icon" />
              <span class="role-name">退出登录</span>
            </div>
          </div>
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
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import { Search, Bell, ChevronDown, LogOut } from 'lucide-vue-next'
import { getAuthProfile, logout } from '../../api/auth'
import { currentProfile } from '../../api/session'
import { setOperatorRole } from '../../api/client'
import { getHomeAlerts } from '../../api/workbench'
import type { AuthProfileResp } from '../../api/types'

const profile = ref<AuthProfileResp | null>(null)
const session = ref<AuthProfileResp | null>(null)
const alertCount = ref(0)
const roleOpen = ref(false)
const profileEl = ref<HTMLElement | null>(null)

// 会话真身（?role= 只切 display 层 profile，session 不动）
const ROLE_SWITCH_ALLOW: readonly string[] = ['admin', 'president']
const canSwitchRole = computed(() => ROLE_SWITCH_ALLOW.includes(session.value?.user.role ?? ''))

// §2.1 ?role= 切换演示上下文;失败保持当前角色与操作人不动(写端点 ?role= 不跟挂),菜单收起
const switchRole = async (role: string) => {
  roleOpen.value = false
  const next = await getAuthProfile(role).catch(() => null)
  if (!next) return
  profile.value = next
  setOperatorRole(role) // 写端点 ?role= 操作人同步切换(契约 §15 头部)
}

const onLogout = () => {
  roleOpen.value = false
  void logout()
}

// 头像降级：data=null/接口失败时回退默认身份展示（frontend-api §2.1 空态）
const fallbackAvatar = new URL('../../assets/workbench/director_avatar.png', import.meta.url).href

// 角色菜单开合:弹层期间挂 document 点外侧 + Esc 关闭(同 RiskAlertsCard 派发弹层模式),收起即卸
function onDocClick(e: MouseEvent) {
  if (profileEl.value && !profileEl.value.contains(e.target as Node)) roleOpen.value = false
}
function onMenuEsc(e: KeyboardEvent) {
  if (e.key === 'Escape') roleOpen.value = false
}
watch(roleOpen, (v) => {
  if (v) {
    document.addEventListener('click', onDocClick)
    window.addEventListener('keydown', onMenuEsc)
  } else {
    document.removeEventListener('click', onDocClick)
    window.removeEventListener('keydown', onMenuEsc)
  }
})
onUnmounted(() => {
  document.removeEventListener('click', onDocClick)
  window.removeEventListener('keydown', onMenuEsc)
})

onMounted(async () => {
  // 会话真身与展示 profile 同源会话缓存(§2.1);显式 ?role= 切换见 switchRole 裸调
  const p = await currentProfile().catch(() => null)
  session.value = p
  profile.value = p
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
  background-color: var(--p-slate-300); /* 原色直取 */
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
  color: var(--p-white); /* 原色直取 */
  font-size: var(--wb-fs-2xs);
  font-weight: var(--wb-fw-bold);
  width: 14px;
  height: 14px;
  border-radius: var(--wb-radius-pill);
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1.5px solid var(--p-white); /* 原色直取 */
  line-height: var(--wb-lh-solid);
}

.action-divider {
  width: 1px;
  height: 18px;
  background-color: var(--p-slate-200); /* 原色直取 */
}

.user-profile {
  display: flex;
  align-items: center;
  gap: var(--wb-space-2);
  cursor: pointer;
  position: relative;
}

.role-menu {
  position: absolute;
  top: calc(100% + 6px);
  right: 0;
  min-width: 200px;
  background: var(--wb-surface);
  border: 1px solid var(--wb-border);
  border-radius: var(--wb-radius-card);
  box-shadow: var(--wb-shadow-hover);
  z-index: var(--wb-z-raised);
  padding: var(--wb-space-1);
}

.role-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: var(--wb-space-3);
  padding: var(--wb-space-2) var(--wb-space-3);
  border-radius: var(--wb-radius-sm);
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-1);
  cursor: pointer;
}

.role-item:hover {
  background: var(--wb-hover-bg);
}

.role-item.is-active {
  color: var(--wb-primary);
  font-weight: var(--wb-fw-semibold);
}

.menu-divider {
  height: 1px;
  background: var(--wb-hairline);
  margin: var(--wb-space-1) 0;
}

.logout-item {
  justify-content: flex-start;
}

.logout-icon {
  color: var(--wb-text-3);
  flex-shrink: 0;
}

.role-scope {
  font-size: var(--wb-fs-xs);
  color: var(--wb-text-3);
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
