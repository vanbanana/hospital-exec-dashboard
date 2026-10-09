import { createRouter, createWebHistory } from 'vue-router'
import WorkbenchLayout from '../layouts/WorkbenchLayout.vue'

import ScreenLayout from '../layouts/ScreenLayout.vue'

import { currentProfile } from '../api/session'

const routes = [
  {
    path: '/',
    redirect: '/workbench',
  },
  {
    path: '/workbench',
    component: WorkbenchLayout,
    children: [
      { path: '', name: 'wb-home', component: () => import('../views/workbench/HomeView.vue') },
      {
        path: 'overview',
        name: 'wb-overview',
        component: () => import('../views/workbench/OverviewView.vue'),
      },
      {
        path: 'medical',
        name: 'wb-medical',
        component: () => import('../views/workbench/MedicalView.vue'),
      },
      {
        path: 'operations',
        name: 'wb-operations',
        component: () => import('../views/workbench/OperationsView.vue'),
      },
      {
        path: 'hr',
        name: 'wb-hr',
        component: () => import('../views/workbench/HrView.vue'),
      },
      {
        path: 'research',
        name: 'wb-research',
        component: () => import('../views/workbench/ResearchView.vue'),
      },
      {
        path: 'patient',
        name: 'wb-patient',
        component: () => import('../views/workbench/PatientView.vue'),
      },
      {
        path: 'quality',
        name: 'wb-quality',
        component: () => import('../views/workbench/QualityView.vue'),
      },
      {
        path: 'assets',
        name: 'wb-assets',
        component: () => import('../views/workbench/AssetsView.vue'),
      },
      {
        path: 'compare',
        name: 'wb-compare',
        component: () => import('../views/workbench/CompareView.vue'),
      },
      {
        path: 'topics',
        name: 'wb-topics',
        component: () => import('../views/workbench/TopicsView.vue'),
      },
      {
        path: 'settings',
        name: 'wb-settings',
        component: () => import('../views/workbench/SettingsView.vue'),
      },
      { path: 'preferences', name: 'wb-preferences', component: () => import('../views/workbench/PreferencesView.vue') },
      { path: 'tasks', name: 'wb-tasks', component: () => import('../views/workbench/TasksView.vue') },
      { path: 'access', name: 'wb-access', component: () => import('../views/workbench/AccessView.vue') },
      { path: ':pathMatch(.*)*', redirect: '/workbench' },
    ],
  },
  {
    path: '/login',
    name: 'login',
    component: () => import('../views/LoginView.vue'),
    meta: { public: true },
  },
  {
    path: '/screen',
    component: ScreenLayout,
    // 大屏公开位：meta 沿 matched 链合并，子路由同豁免
    meta: { public: true },
    children: [{ path: '', name: 'screen', component: () => import('../views/screen/ScreenView.vue') }],
  },
  { path: '/:pathMatch(.*)*', redirect: '/workbench' },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

// §3.1 登录态守卫：meta.public 豁免（/login、/screen）；其余路由以 currentProfile()
// 校验会话，失败（真轨 20001 未登录等）→ /login?redirect=<fullPath>；
// 已登录访问 /login → 回工作台。
router.beforeEach(async (to) => {
  if (!to.meta.public) {
    try {
      const p = await currentProfile()
      if (to.path.startsWith('/workbench') && to.name !== 'wb-access' && p.allowed_pages && !p.allowed_pages.includes(to.path)) return p.allowed_pages[0] ?? '/workbench/access'
      return true
    } catch {
      return { path: '/login', query: { redirect: to.fullPath } }
    }
  }
  if (to.name === 'login') {
    try {
      await currentProfile()
      return { path: (await currentProfile()).allowed_pages?.[0] ?? '/workbench/access' }
    } catch {
      return true
    }
  }
  return true
})

export default router
