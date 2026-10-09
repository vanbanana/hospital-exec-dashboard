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
        <RouterLink v-if="canViewScreen" class="screen-link" :to="{ path: '/screen', query: { returnTo: route.fullPath } }">
          <Monitor :size="16" />
          <span>数据大屏</span>
        </RouterLink>
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

        <!-- Notification Bell：角标 = 风险预警条数（复用 home/alerts），点击落预警承载页（质量与安全），无数据隐藏徽标 -->
        <div v-if="canViewAlerts" class="notice-badge-wrapper" @click="$router.push('/workbench/quality')">
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

    </div>
  </header>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import { Search, Bell, ChevronDown, LogOut, Monitor } from 'lucide-vue-next'
import { RouterLink, useRoute } from 'vue-router'
import { getAuthProfile, logout } from '../../api/auth'
import { currentProfile, profileState } from '../../api/session'
import { setOperatorRole } from '../../api/client'
import { usePreferencePolling } from '../../api/preferences'
import { getHomeAlerts } from '../../api/workbench'
import type { AuthProfileResp } from '../../api/types'

const route = useRoute()
const canViewScreen = computed(() => !!session.value?.allowed_pages?.includes('/workbench/overview'))
const profile = ref<AuthProfileResp | null>(null)
watch(profileState, p => { profile.value = p; session.value = p })
const session = ref<AuthProfileResp | null>(null)
const alertCount = ref(0)
const roleOpen = ref(false)
const profileEl = ref<HTMLElement | null>(null)
const canViewAlerts = computed(() => !!session.value && (!session.value.allowed_pages || (session.value.allowed_pages.includes('/workbench') && session.value.allowed_pages.includes('/workbench/quality'))))
async function refreshAlerts() {
  alertCount.value = canViewAlerts.value ? await getHomeAlerts().then(r => r.list.length).catch(() => 0) : 0
}
usePreferencePolling(refreshAlerts)

// 会话真身（?role= 只切 display 层 profile，session 不动）
const ROLE_SWITCH_ALLOW: readonly string[] = ['admin', 'president']
const canSwitchRole = computed(() => ROLE_SWITCH_ALLOW.includes(session.value?.user.role ?? '') && (session.value?.available_roles.length ?? 0) > 1)

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
// public/ 静态资产:契约 user.avatar 返回同源字面路径 /assets/...,dev 直供、build 拷贝入 dist——双环境同路径
const fallbackAvatar = '/assets/workbench/director_avatar.png'

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
  await refreshAlerts()
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
  white-space: nowrap; /* 窄视口折行比挤压更难看,标题不可断 */
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
  white-space: nowrap;
}

.header-right {
  display: flex;
  align-items: center;
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
/* 搜索无契约端点支撑(模板注释),禁用态显性化:降透明 + 禁手型 */
.search-box:has(.search-input:disabled) {
  opacity: var(--wb-opacity-muted);
  cursor: not-allowed;
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
  /* 浮层档:须盖过 Hero 书法字/标语(z-sticky=2)等页面内容,raised 档不够 */
  z-index: var(--wb-z-dropdown);
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
  white-space: nowrap; /* 长项(运营办主任(刘远明) 全院运营/质控)不折行,菜单按内容撑宽 */
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
  white-space: nowrap; /* 职称(骨科主任等)不换行 */
}

.dropdown-icon {
  color: var(--wb-text-3);
}



.screen-link {
  display: inline-flex;
  align-items: center;
  gap: var(--wb-space-2);
  padding: var(--wb-space-2) var(--wb-space-3);
  border: 1px solid var(--wb-border);
  border-radius: var(--wb-radius-sm);
  color: var(--wb-primary);
  background: var(--wb-surface);
  font-size: var(--wb-fs-sm);
  font-weight: var(--wb-fw-semibold);
  text-decoration: none;
  white-space: nowrap;
  flex-shrink: 0;
  transition: background var(--wb-dur-fast);
}
.screen-link:hover { background: var(--wb-hover-bg); }
.screen-link:focus-visible { outline: 2px solid var(--wb-primary); outline-offset: 2px; }
@media (max-width: 1440px) {
  .system-subtitle, .title-divider { display: none; }
}
@media (max-width: 1100px) {
  .search-box { display: none; }
}
</style>
