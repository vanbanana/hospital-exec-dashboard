import { createRouter, createWebHistory } from 'vue-router'
import WorkbenchLayout from '../layouts/WorkbenchLayout.vue'
import HomeView from '../views/workbench/HomeView.vue'
import ScreenLayout from '../layouts/ScreenLayout.vue'
import ScreenView from '../views/screen/ScreenView.vue'
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
      { path: '', name: 'wb-home', component: HomeView },
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
    children: [{ path: '', name: 'screen', component: ScreenView }],
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

// §3.1 登录态守卫：meta.public 豁免（/login、/screen）；其余路由以 currentProfile()
// 校验会话，失败 → /login?redirect=<fullPath>；已登录访问 /login → 回工作台。
// mock 轨 profile 恒 resolve = 恒放行恒跳回，与"mock 轨=已认证演示"语义一致
router.beforeEach(async (to) => {
  if (!to.meta.public) {
    try {
      await currentProfile()
      return true
    } catch {
      return { path: '/login', query: { redirect: to.fullPath } }
    }
  }
  if (to.name === 'login') {
    try {
      await currentProfile()
      return { path: '/workbench' }
    } catch {
      return true
    }
  }
  return true
})

export default router
