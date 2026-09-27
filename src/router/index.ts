import { createRouter, createWebHistory } from 'vue-router'
import WorkbenchLayout from '../layouts/WorkbenchLayout.vue'
import HomeView from '../views/workbench/HomeView.vue'

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
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

export default router
