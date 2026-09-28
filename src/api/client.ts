// 统一取数层 — api<T>(key, params, opts?) 经 vite proxy / nginx 打 Go 后端
// /api/v1/<key>,拆 ApiEnvelope 包络(error-codes §1/§4)。
// 写路径:method 非 GET 时 body JSON 上送(frontend-architecture §8.4)。
// 无 mock 轨:任何端点一律打真后端,失败走错误码/五态反馈,不回落假数据
import type { ApiEnvelope } from './types'

// api() 查询参数形状:契约参数全为字符串;undefined 键省略不进 qs
export type ApiParams = Record<string, string | undefined>

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
// 域=§2.1 演示账号三角色;admin 不入——admin 会话走省略 ?role= 路径,后端按会话身份定位
const DEMO_OPERATOR_ROLES = new Set(['president', 'ops_director', 'dept_leader'])
let operatorRole = 'president'
export function getOperatorRole() {
  return DEMO_OPERATOR_ROLES.has(operatorRole) ? operatorRole : undefined
}
export function setOperatorRole(role: string) {
  operatorRole = role
}

/**
 * 统一取数入口。key = 契约端点路径(如 'workbench/overview'),写端点 key 含字面路径参数(如 'alerts/12/ack')。
 * HTTP 层失败或非 0 业务码均抛带数值 code 的 Error,
 * 由 useAsyncData.toApiError 透传到五态反馈(非 0 码无 fields 时落 10000)。
 */
export async function api<T>(key: string, params: ApiParams = {}, opts: ApiOpts = {}): Promise<T> {
  const method = opts.method ?? 'GET'

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
      current_status?: string
      todo_id?: number
      trace_id?: string
    }
    err.code = env.code
    const data = env.data as {
      fields?: Record<string, string>
      current_status?: string
      todo_id?: number
    } | null
    if (data?.fields) err.fields = data.fields
    // 契约 §15.1/§15.2/§15.5 冲突码(33002/33104)回传 data.current_status[+todo_id],原样挂 err
    if (data?.current_status !== undefined) err.current_status = data.current_status
    if (data?.todo_id !== undefined) err.todo_id = data.todo_id
    if (env.trace_id) err.trace_id = env.trace_id
    // 401 会话失效:清会话态+硬跳登录页;auth/* 自检族全豁免——守卫以 profile 20001 判
    // 未登录,拦截会引起 /login?redirect=/login?... 无限套娃(frontend-api §1.7)
    if (env.code === 20001 || env.code === 20002 || env.code === 20003) {
      if (!key.startsWith('auth/')) {
        unauthorizedHandler?.()
        location.assign(`/login?redirect=${encodeURIComponent(location.pathname + location.search)}`)
      }
    }
    throw err
  }
  return env.data as T
}
