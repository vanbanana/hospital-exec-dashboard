import { ref } from 'vue'
import { applyPreferences } from './preferences'
// 会话态唯一事实源 — frontend-architecture §3.1/§8.4：模块级单 Promise 缓存，
// useSystemDate 同形模式（不依赖 Pinia）。契约 §2.3 登录响应即全量上下文，免二次拉取
import { api, registerUnauthorizedHandler, setOperatorRole } from './client'
import type { AuthProfileResp } from './types'

export const profileState = ref<AuthProfileResp | null>(null)
let generation = 0

let cached: Promise<AuthProfileResp> | null = null

/**
 * 当前会话身份（§2.1 演进注：无 ?role= 时返回会话用户）。
 * 失败（真链路 20001 未登录等）清缓存再原样 rethrow——不清则一次 401 永久钉死会话态；
 * 去向由调用方裁决（router 守卫跳 /login、Header 降级展示）
 */
export function currentProfile(force = false): Promise<AuthProfileResp> {
  if (force) { generation++; cached = null }
  const id = generation
  cached ??= api<AuthProfileResp>('auth/profile')
    .then((resp) => {
      if (id !== generation) return resp
      profileState.value = resp
      applyPreferences(resp.preferences ?? null)
      setOperatorRole(resp.user.username) // 写端点 ?role= 缺省操作人对齐会话身份
      return resp
    })
    .catch((err) => {
      if (id === generation) cached = null
      throw err
    })
  return cached
}

/** §2.3 登录成功响应即全量上下文（同 §2.1 data 形状），直接入缓存免二次拉取 */
export function onLoginSuccess(resp: AuthProfileResp) {
  generation++
  profileState.value = resp
  applyPreferences(resp.preferences ?? null)
  setOperatorRole(resp.user.username)
  cached = Promise.resolve(resp)
}

/** §2.4 登出 / 凭证失效时清空本地会话态 */
export function clearSession() {
  generation++
  profileState.value = null
  applyPreferences(null)
  cached = null
}

// client.ts 401 拦截点注册(写链路 EW 预留,注册于模块加载期——防依赖环故不反向 import)
registerUnauthorizedHandler(clearSession)
