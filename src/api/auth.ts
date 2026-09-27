// 认证与上下文端点函数 — api-contract §2（演示级认证，无 Token，?role= 切上下文；
// §2.3/§2.4 会话登录为写路径，自含原生 fetch——client.ts 为 GET-only 读轨，见 frontend-api §1.7）
import { api } from './client'
import { clearSession, onLoginSuccess } from './session'
import type { ApiEnvelope, AuthProfileResp, HospitalProfileResp } from './types'

/** §2.1 GET /auth/profile（?role= 切换演示上下文，枚举外后端回 10001） */
export function getAuthProfile(role?: string) {
  return api<AuthProfileResp>('auth/profile', role ? { role } : {})
}

/** §2.2 GET /hospital/profile */
export function getHospitalProfile() {
  return api<HospitalProfileResp>('hospital/profile')
}

/** §2.3 登录失败 reject 形状：与 client.ts 拆包络产出的错误字段同构，供表单内联消费 */
export interface LoginError {
  code: number
  message: string
  fields?: Record<string, string>
  trace_id?: string
}

/** §2.3/§2.4 写路径自拆包络（credentials:'same-origin' 携带 edss_sid Cookie） */
async function postAuth<T>(path: string, body?: unknown): Promise<T | null> {
  const resp = await fetch(`/api/v1/${path}`, {
    method: 'POST',
    credentials: 'same-origin',
    ...(body !== undefined
      ? { headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }
      : {}),
  })
  const env = (await resp.json().catch(() => null)) as ApiEnvelope<T> | null
  // 无包络可拆的传输层失败（网关/代理裸 404、非 JSON 5xx），口径对齐 client.ts
  if (!env) throw { code: 10000, message: `[api] http ${resp.status}` } satisfies LoginError
  if (env.code !== 0) {
    const fields = (env.data as { fields?: Record<string, string> } | null)?.fields
    throw { code: env.code, message: env.message, fields, trace_id: env.trace_id } satisfies LoginError
  }
  return env.data
}

/** §2.3 POST /auth/login — 成功响应即全量上下文（同 §2.1 data），入会话缓存后 resolve */
export async function login(username: string, password: string): Promise<AuthProfileResp> {
  const data = await postAuth<AuthProfileResp>('auth/login', { username, password })
  if (!data) throw { code: 10000, message: '登录响应缺少会话数据' } satisfies LoginError
  onLoginSuccess(data)
  return data
}

/**
 * §2.4 POST /auth/logout — 幂等（成功 data=null）；网络层成败都继续，本地态必清。
 * location.assign 硬跳顺带清内存态；不 import router 防依赖环（frontend-architecture §8.4-2）
 */
export async function logout(): Promise<void> {
  try {
    await postAuth<null>('auth/logout')
  } catch {
    /* 幂等：网络/包络失败不阻断登出 */
  } finally {
    clearSession()
    location.assign('/login')
  }
}
