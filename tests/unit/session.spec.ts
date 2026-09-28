import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { AuthProfileResp } from '@/api/types'

// session.ts：模块级单 Promise 会话缓存 + 401 清缓存注册
// client.ts 整体 mock——会话层与传输层解耦测

const h = vi.hoisted(() => ({
  api: vi.fn(),
  setOperatorRole: vi.fn(),
  unauthorized: null as null | (() => void),
}))

vi.mock('@/api/client', () => ({
  api: h.api,
  setOperatorRole: h.setOperatorRole,
  registerUnauthorizedHandler: (fn: () => void) => {
    h.unauthorized = fn
  },
}))

const profile: AuthProfileResp = {
  user: {
    id: 1,
    username: 'president',
    real_name: '王建国',
    title: '院长',
    dept_id: null,
    dept_name: '全院',
    avatar: '',
    role: 'president',
  },
  available_roles: [],
  system_date: '2026-10-28',
  weekday: '星期三',
}

// 每个用例全新模块实例——session.ts 的 cached/注册行为都是模块级
async function freshSession() {
  vi.resetModules()
  return await import('@/api/session')
}

beforeEach(() => {
  h.api.mockReset()
  h.setOperatorRole.mockReset()
  h.unauthorized = null
})

describe('currentProfile 会话缓存', () => {
  it('首次拉取后缓存：两次调用只发一次 api', async () => {
    const s = await freshSession()
    h.api.mockResolvedValue(profile)
    const [a, b] = await Promise.all([s.currentProfile(), s.currentProfile()])
    expect(a).toBe(profile)
    expect(b).toBe(profile)
    expect(h.api).toHaveBeenCalledTimes(1)
    expect(h.api).toHaveBeenCalledWith('auth/profile')
  })

  it('成功时把会话 username 写入操作人角色（?role= 缺省对齐）', async () => {
    const s = await freshSession()
    h.api.mockResolvedValue(profile)
    await s.currentProfile()
    expect(h.setOperatorRole).toHaveBeenCalledWith('president')
  })

  it('失败清缓存再 rethrow：下次调用重新拉取，不被一次 401 钉死', async () => {
    const s = await freshSession()
    h.api.mockRejectedValueOnce(Object.assign(new Error('未登录'), { code: 20001 }))
    await expect(s.currentProfile()).rejects.toMatchObject({ code: 20001 })

    h.api.mockResolvedValueOnce(profile)
    await expect(s.currentProfile()).resolves.toBe(profile)
    expect(h.api).toHaveBeenCalledTimes(2)
  })
})

describe('onLoginSuccess / clearSession', () => {
  it('登录响应即全量上下文：直入缓存，currentProfile 不再拉取', async () => {
    const s = await freshSession()
    s.onLoginSuccess(profile)
    await expect(s.currentProfile()).resolves.toBe(profile)
    expect(h.api).not.toHaveBeenCalled()
    expect(h.setOperatorRole).toHaveBeenCalledWith('president')
  })

  it('clearSession 后重新拉取', async () => {
    const s = await freshSession()
    s.onLoginSuccess(profile)
    s.clearSession()
    h.api.mockResolvedValue(profile)
    await s.currentProfile()
    expect(h.api).toHaveBeenCalledTimes(1)
  })
})

describe('未授权清缓存注册', () => {
  it('模块加载期向 client.ts 注册 401 回调', async () => {
    await freshSession()
    expect(h.unauthorized).toBeTypeOf('function')
  })

  it('触发 401 回调 = clearSession：缓存作废，下取重拉', async () => {
    const s = await freshSession()
    s.onLoginSuccess(profile)
    h.unauthorized!()
    h.api.mockResolvedValue(profile)
    await s.currentProfile()
    expect(h.api).toHaveBeenCalledTimes(1)
  })
})
