/**
 * Mock 端点注册表 — key 与 api-contract.md 端点路径一一对应。
 * api/client.ts 经此表取数；接 mock server / 真实后端时整层被 http 替换（见 §16）。
 */
import { authProfile, hospitalProfile } from './auth'
import { homeAlerts, homeIndicators, homeKpis, homeNotices, homeProgress, homeTop10, homeTrends } from './home'
import { getOverviewMock } from './overview'
import { getMedicalMock } from './medical'
import { getOperationsMock } from './operations'
import { getCompareMock } from './compare'
import { getTopicsMock } from './topics'
import { qualityData } from './quality'
import { getHrMock } from './hr'
import { researchData } from './research'
import { patientData } from './patient'
import { assetsData } from './assets'
import { settingsData } from './settings'
import { screenSnapshot } from './screen'

export type MockParams = Record<string, string>

export const mockResolvers: Record<string, (params: MockParams) => unknown> = {
  'auth/profile': () => authProfile,
  'hospital/profile': () => hospitalProfile,
  'workbench/home/kpis': () => homeKpis,
  'workbench/home/trends': () => homeTrends,
  'workbench/home/top10': () => homeTop10,
  'workbench/home/indicators': () => homeIndicators,
  'workbench/home/progress': () => homeProgress,
  'workbench/home/alerts': () => homeAlerts,
  'workbench/home/notices': () => homeNotices,
  'workbench/overview': (p) => getOverviewMock(p.range),
  'workbench/medical': (p) => getMedicalMock(p.tab, p.range),
  'workbench/operations': (p) => getOperationsMock(p.range),
  'workbench/hr': (p) => getHrMock(p.range),
  'workbench/research': () => researchData,
  'workbench/patient': () => patientData,
  'workbench/quality': () => qualityData,
  'workbench/assets': () => assetsData,
  'workbench/compare': (p) => getCompareMock(p.dim, p.range),
  'workbench/topics': (p) => getTopicsMock(p.topic, p.range),
  'workbench/settings/config': () => settingsData,
  'screen/snapshot': () => screenSnapshot,
}
