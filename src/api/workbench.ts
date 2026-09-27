// 工作台端点函数 — 每端点一个函数，返回类型即契约 data 负载（api-contract §3~§13）
import { api } from './client'
import type {
  AssetsResp,
  CompareDim,
  CompareResp,
  HomeAlertsResp,
  HomeIndicatorsResp,
  HomeKpisResp,
  HomeNoticesResp,
  HomeProgressResp,
  HomeTop10Resp,
  HomeTrendsResp,
  HrResp,
  MedicalResp,
  MedicalTab,
  OperationsResp,
  OverviewResp,
  PatientResp,
  QualityResp,
  RangeKey,
  ResearchResp,
  SettingsResp,
  TopicKey,
  TopicsResp,
} from './types'

/* ===== §3 首页 ===== */

export function getHomeKpis() {
  return api<HomeKpisResp>('workbench/home/kpis')
}

export function getHomeTrend() {
  return api<HomeTrendsResp>('workbench/home/trends')
}

export function getHomeTop10() {
  return api<HomeTop10Resp>('workbench/home/top10')
}

export function getHomeIndicators() {
  return api<HomeIndicatorsResp>('workbench/home/indicators')
}

export function getHomeProgress() {
  return api<HomeProgressResp>('workbench/home/progress')
}

export function getHomeAlerts() {
  return api<HomeAlertsResp>('workbench/home/alerts')
}

export function getHomeNotices() {
  return api<HomeNoticesResp>('workbench/home/notices')
}

/* ===== §4~§13 业务页 ===== */

export function getOverview(range: RangeKey = '本年') {
  return api<OverviewResp>('workbench/overview', { range })
}

export function getMedical(tab: MedicalTab = '门急诊', range: RangeKey = '本年') {
  return api<MedicalResp>('workbench/medical', { tab, range })
}

export function getOperations(range: RangeKey = '本年') {
  return api<OperationsResp>('workbench/operations', { range })
}

export function getHr(range: RangeKey = '本年') {
  return api<HrResp>('workbench/hr', { range })
}

export function getResearch() {
  return api<ResearchResp>('workbench/research')
}

export function getPatient() {
  return api<PatientResp>('workbench/patient')
}

export function getQuality() {
  return api<QualityResp>('workbench/quality')
}

export function getAssets() {
  return api<AssetsResp>('workbench/assets')
}

export function getCompare(dim: CompareDim = 'scale', range: RangeKey = '本月') {
  return api<CompareResp>('workbench/compare', { dim, range })
}

export function getTopics(topic: TopicKey, range: RangeKey = '本年') {
  return api<TopicsResp>('workbench/topics', { topic, range })
}

export function getSettings() {
  return api<SettingsResp>('workbench/settings/config')
}
