// 认证与上下文端点函数 — api-contract §2（演示级认证，无 Token，?role= 切上下文；
// §2.3/§2.4 会话登录经 api() 写路径——client.ts 已支持 method/body，错误形状与真轨一致）
import { api } from './client'
import { clearSession, onLoginSuccess } from './session'
import type { AuthProfileResp, HospitalProfileResp } from './types'

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

/** §2.3 POST /auth/login — 成功响应即全量上下文（同 §2.1 data），入会话缓存后 resolve */
export async function login(username: string, password: string): Promise<AuthProfileResp> {
  const data = await api<AuthProfileResp | null>('auth/login', {}, { method: 'POST', body: { username, password } })
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
    await api<null>('auth/logout', {}, { method: 'POST', body: {} })
  } catch {
    /* 幂等：网络/包络失败不阻断登出 */
  } finally {
    clearSession()
    location.assign('/login')
  }
}
