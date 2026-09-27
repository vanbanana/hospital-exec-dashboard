// 统一取数层 — api<T>(key, params, opts?):VITE_USE_MOCK=1(默认)走 src/mock 注册表,
// =0 时经 vite proxy 打 Go 后端 /api/v1/<key>,拆 ApiEnvelope 包络(error-codes §1/§4)
// 写路径:method 非 GET 时 body JSON 上送、mock 轨按 'METHOD:key' 复合键查 resolver(frontend-architecture §8.4)
import { mockResolvers, type MockParams } from '../mock'
import type { ApiEnvelope } from './types'

const MOCK_LATENCY_MS = 120
const USE_MOCK = import.meta.env.VITE_USE_MOCK !== '0'

export interface ApiOpts {
  method?: 'GET' | 'POST' | 'PUT'
  body?: unknown
}

// 401 未授权拦截回调 — EA session.ts 落地时注册 clearSession(client.ts 不 import session 防依赖环)
let unauthorizedHandler: (() => void) | null = null
export function registerUnauthorizedHandler(fn: () => void) {
  unauthorizedHandler = fn
}

// 演示期操作人角色 — 写端点函数经 ?role= 显式传输(契约 §15 头部约定;缺席=会话用户)
// §8.4-5 文档原写挂 api/auth.ts,auth.ts 已划 EA epic 域,故落 client.ts(lead 已报备)
// 集外账号(如 vp_medical 会话登录)返回 undefined→参数省略,后端 FindOperator 回落会话身份,防 ?role= 撞 10001
const DEMO_OPERATOR_ROLES = new Set(['president', 'ops_director', 'dept_leader', 'admin'])
let operatorRole = 'president'
export function getOperatorRole() {
  return DEMO_OPERATOR_ROLES.has(operatorRole) ? operatorRole : undefined
}
export function setOperatorRole(role: string) {
  operatorRole = role
}

/** 写端点模式匹配:注册键 'METHOD:a/{p}/b' 对调用键 'METHOD:a/1/b' 分段比对,{p} 段捕获字面量回填 params */
function matchMockResolver(callKey: string, params: MockParams) {
  const method = callKey.slice(0, callKey.indexOf(':'))
  for (const regKey of Object.keys(mockResolvers)) {
    if (!regKey.startsWith(`${method}:`)) continue
    const patSegs = regKey.slice(method.length + 1).split('/')
    const callSegs = callKey.slice(method.length + 1).split('/')
    if (patSegs.length !== callSegs.length) continue
    const captured: MockParams = {}
    let ok = true
    for (let i = 0; i < patSegs.length; i++) {
      const pat = patSegs[i]
      const m = /^\{(.+)\}$/.exec(pat)
      if (m) captured[m[1]] = callSegs[i]
      else if (pat !== callSegs[i]) {
        ok = false
        break
      }
    }
    if (ok) {
      Object.assign(params, captured)
      return mockResolvers[regKey]
    }
  }
  return undefined
}

/**
 * 统一取数入口。key = 契约端点路径(如 'workbench/overview'),写端点 key 含字面路径参数(如 'alerts/12/ack')。
 * 真后端路径下:HTTP 层失败或非 0 业务码均抛带数值 code 的 Error,
 * 由 useAsyncData.toApiError 透传到五态反馈(非 0 码无 fields 时落 10000)。
 */
export async function api<T>(key: string, params: MockParams = {}, opts: ApiOpts = {}): Promise<T> {
  const method = opts.method ?? 'GET'

  if (USE_MOCK) {
    // GET 原样按 key 精确匹配;写调用按 'METHOD:key' 复合键,先精确再模式匹配({id} 段回填 params)
    const callKey = method === 'GET' ? key : `${method}:${key}`
    const resolve = mockResolvers[callKey] ?? (method === 'GET' ? undefined : matchMockResolver(callKey, params))
    if (!resolve) throw new Error(`[api] 未注册的端点: ${callKey}`)
    await new Promise((r) => setTimeout(r, MOCK_LATENCY_MS))
    // 深拷贝隔离 mock 模块单例,防止消费方原地修改污染后续请求
    return JSON.parse(JSON.stringify(resolve(params, opts.body))) as T
  }

  const qs = new URLSearchParams()
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== null) qs.set(k, String(v))
  }
  const url = `/api/v1/${key}${qs.size ? `?${qs}` : ''}`
  const resp = await fetch(url, {
    method,
    // 会话凭证为 HttpOnly Cookie edss_sid(契约 §2.3),同源显式携带
    credentials: 'same-origin',
    headers: { Accept: 'application/json', ...(opts.body !== undefined ? { 'Content-Type': 'application/json' } : {}) },
    body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
  })
  let env: ApiEnvelope<T>
  try {
    env = (await resp.json()) as ApiEnvelope<T>
  } catch {
    // 无包络可拆的传输层失败(网关/代理裸 404、非 JSON 5xx)
    throw new Error(`[api] http ${resp.status}`)
  }
  // 31004 口径正常但无数据→resolve(null) 页面自渲空态(error-codes §4)
  if (env.code === 31004) return env.data as T
  if (env.code !== 0) {
    const err = new Error(env.message || `[api] code ${env.code}`) as Error & {
      code?: number
      fields?: Record<string, string>
      trace_id?: string
    }
    err.code = env.code
    const data = env.data as { fields?: Record<string, string> } | null
    if (data?.fields) err.fields = data.fields
    if (env.trace_id) err.trace_id = env.trace_id
    // 401 会话失效:清会话态+硬跳登录页(auth/login 自身除外防环,frontend-api §1.7)
    if (env.code === 20001 || env.code === 20002 || env.code === 20003) {
      if (key !== 'auth/login') {
        unauthorizedHandler?.()
        location.assign(`/login?redirect=${encodeURIComponent(location.pathname + location.search)}`)
      }
    }
    throw err
  }
  return env.data as T
}
