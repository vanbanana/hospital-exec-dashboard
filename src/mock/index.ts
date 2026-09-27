/**
 * Mock 端点注册表 — key 与 api-contract.md 端点路径一一对应。
 * api/client.ts 经此表取数；接 mock server / 真实后端时整层被 http 替换（见 §16）。
 */
import { getAuthProfileMock, hospitalProfile } from './auth'
import { homeIndicators, homeKpis, homeNotices, homeProgress, homeTop10, homeTrends } from './home'
import {
  alertStateList,
  getTodosList,
  postAlertAck,
  postAlertClose,
  postAlertDispatch,
  postRuleToggle,
  postTodoStatus,
  putPreferences,
  staffList,
} from './alertflow'
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

// 契约枚举域(api-contract §1.4-1/§2.1/§5.1/§9.1/§13.1);非法值按 error-codes 抛 10001,mock 期即可演练错误态
const ENUM_DOMAIN: Record<string, Record<string, readonly string[]>> = {
  'auth/profile': { role: ['president', 'ops_director', 'dept_leader'] },
  'workbench/overview': { range: ['本月', '本季', '本年'] },
  'workbench/medical': { tab: ['门急诊', '住院', '手术'], range: ['本月', '本季', '本年'] },
  'workbench/operations': { range: ['本月', '本季', '本年'] },
  'workbench/hr': { range: ['本月', '本季', '本年'] },
  'workbench/compare': { dim: ['scale', 'benefit', 'efficiency', 'quality'], range: ['本月', '本季', '本年'] },
  'workbench/topics': { topic: ['drg', 'insurance', 'exam', 'outp_fund'], range: ['本月', '本季', '本年'] },
  // §15.4 R07;写端点复合键(METHOD:key)不命中本表,断言天然跳过
  'todos': { status: ['open', 'doing', 'done', 'expired'] },
}

// 契约必填参数(无默认值):缺席即 10001;其余参数缺席走默认、出现则必须落在枚举域(空串同样非法)
const REQUIRED_PARAMS: Record<string, readonly string[]> = {
  'workbench/topics': ['topic'],
}

function assertParams(key: string, params: MockParams) {
  const domain = ENUM_DOMAIN[key]
  if (!domain) return
  for (const k of REQUIRED_PARAMS[key] ?? []) {
    if (params[k] === undefined || params[k] === '') {
      throw Object.assign(new Error(`缺少必填参数 ${k}`), { code: 10001 })
    }
  }
  for (const [k, allowed] of Object.entries(domain)) {
    const v = params[k]
    if (v !== undefined && !allowed.includes(v)) {
      throw Object.assign(new Error(`非法参数 ${k}=${v}`), { code: 10001 })
    }
  }
}

// resolver 签名:(params 查询/路径回填参数, body 写请求体) — body 仅写端点使用
export const mockResolvers: Record<string, (params: MockParams, body?: unknown) => unknown> = {
  'auth/profile': (p) => getAuthProfileMock(p.role),
  'hospital/profile': () => hospitalProfile,
  'workbench/home/kpis': () => homeKpis,
  'workbench/home/trends': () => homeTrends,
  'workbench/home/top10': () => homeTop10,
  'workbench/home/indicators': () => homeIndicators,
  'workbench/home/progress': () => homeProgress,
  'workbench/home/alerts': () => alertStateList(), // 状态源派生(§8.4.4),替换原 homeAlerts 常量
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
  /* ===== §15 写侧端点 — 读(GET 精确键) ===== */
  'todos': (p) => getTodosList(p),
  'staff': (p) => staffList(p),
  /* ===== §15 写侧端点 — 写(METHOD:key 复合键,{id}/{code} 由 client 模式匹配回填 params) ===== */
  'POST:alerts/{id}/ack': (p) => postAlertAck(p),
  'POST:alerts/{id}/dispatch': (p, body) => postAlertDispatch(p, body),
  'POST:alerts/{id}/close': (p, body) => postAlertClose(p, body),
  'POST:todos/{id}/status': (p, body) => postTodoStatus(p, body),
  'POST:workbench/settings/rules/{code}': (p, body) => postRuleToggle(p, body),
  'PUT:workbench/settings/preferences': (p, body) => putPreferences(p, body),
}

// 包一层统一校验:resolver 出口前过枚举域,契约外的参数形状进不了数据层
const wrapped = Object.fromEntries(
  Object.entries(mockResolvers).map(([key, fn]) => [
    key,
    (params: MockParams, body?: unknown) => {
      assertParams(key, params)
      return fn(params, body)
    },
  ]),
)
Object.assign(mockResolvers, wrapped)
