// 认证与上下文端点函数 — api-contract §2（演示级认证，无 Token，?role= 切上下文）
import { api } from './client'
import type { AuthProfileResp, HospitalProfileResp } from './types'

/** §2.1 GET /auth/profile */
export function getAuthProfile() {
  return api<AuthProfileResp>('auth/profile')
}

/** §2.2 GET /hospital/profile */
export function getHospitalProfile() {
  return api<HospitalProfileResp>('hospital/profile')
}
