// 统一取数层 — api<T>(key, params):VITE_USE_MOCK=1(默认)走 src/mock 注册表,
// =0 时经 vite proxy 打 Go 后端 /api/v1/<key>,拆 ApiEnvelope 包络(error-codes §1/§4)
import { mockResolvers, type MockParams } from '../mock'
import type { ApiEnvelope } from './types'

const MOCK_LATENCY_MS = 120
const USE_MOCK = import.meta.env.VITE_USE_MOCK !== '0'

/**
 * 统一取数入口。key = 契约端点路径(如 'workbench/overview')。
 * 真后端路径下:HTTP 层失败或非 0 业务码均抛带数值 code 的 Error,
 * 由 useAsyncData.toApiError 透传到五态反馈(非 0 码无 fields 时落 10000)。
 */
export async function api<T>(key: string, params: MockParams = {}): Promise<T> {
  if (USE_MOCK) {
    const resolve = mockResolvers[key]
    if (!resolve) throw new Error(`[api] 未注册的端点: ${key}`)
    await new Promise((r) => setTimeout(r, MOCK_LATENCY_MS))
    // 深拷贝隔离 mock 模块单例,防止消费方原地修改污染后续请求
    return JSON.parse(JSON.stringify(resolve(params))) as T
  }

  const qs = new URLSearchParams()
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== null) qs.set(k, String(v))
  }
  const url = `/api/v1/${key}${qs.size ? `?${qs}` : ''}`
  const resp = await fetch(url, { headers: { Accept: 'application/json' } })
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
    throw err
  }
  return env.data as T
}
