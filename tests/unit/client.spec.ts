import { afterEach, describe, expect, it, vi } from 'vitest'
import {
  api,
  getOperatorRole,
  registerUnauthorizedHandler,
  setOperatorRole,
} from '@/api/client'
import type { ApiEnvelope } from '@/api/types'

// client.ts 是单轨取数入口：包络拆包 / 错误码透传 / ?role= / 401 拦截 / 31004 空态语义
// 全部经 stub fetch 验证，不打真后端

const env = <T>(over: Partial<ApiEnvelope<T>> = {}): ApiEnvelope<T> => ({
  code: 0,
  message: 'ok',
  data: null,
  trace_id: 'trace-test',
  ts: 1,
  ...over,
})

function stubFetch(payload: unknown, status = 200) {
  const fetchMock = vi.fn().mockResolvedValue({
    status,
    json: () => Promise.resolve(payload),
  })
  vi.stubGlobal('fetch', fetchMock)
  return fetchMock
}

const lastUrl = (fetchMock: ReturnType<typeof vi.fn>) => fetchMock.mock.calls.at(-1)?.[0] as string
const lastInit = (fetchMock: ReturnType<typeof vi.fn>) =>
  fetchMock.mock.calls.at(-1)?.[1] as RequestInit

afterEach(() => {
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
})

describe('包络拆包', () => {
  it('code=0 直返 data 负载', async () => {
    stubFetch(env({ data: { a: 1 } }))
    await expect(api<{ a: number }>('workbench/overview')).resolves.toEqual({ a: 1 })
  })

  it('非 JSON 响应抛 [api] http <status>（传输层失败，无包络可拆）', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue({ status: 502, json: () => Promise.reject(new Error('bad json')) })
    vi.stubGlobal('fetch', fetchMock)
    await expect(api('workbench/overview')).rejects.toThrow('[api] http 502')
  })
})

describe('查询参数', () => {
  it('params 拼进 ?qs，undefined 键省略', async () => {
    const fetchMock = stubFetch(env({ data: {} }))
    await api('workbench/overview', { range: '本月', dim: 'scale', drop: undefined })
    expect(lastUrl(fetchMock)).toBe('/api/v1/workbench/overview?range=%E6%9C%AC%E6%9C%88&dim=scale')
  })

  it('无 params 时 URL 不带 ?', async () => {
    const fetchMock = stubFetch(env({ data: {} }))
    await api('workbench/home/kpis')
    expect(lastUrl(fetchMock)).toBe('/api/v1/workbench/home/kpis')
  })
})

describe('写路径', () => {
  it('POST 上送 JSON body + Content-Type，GET 不带 body/Content-Type', async () => {
    const fetchMock = stubFetch(env({ data: {} }))
    await api('alerts/101/ack', { role: 'president' }, { method: 'POST', body: { x: 1 } })
    expect(lastInit(fetchMock).method).toBe('POST')
    expect(lastInit(fetchMock).body).toBe('{"x":1}')
    expect((lastInit(fetchMock).headers as Record<string, string>)['Content-Type']).toBe(
      'application/json',
    )
    await api('workbench/home/kpis')
    expect(lastInit(fetchMock).body).toBeUndefined()
    expect((lastInit(fetchMock).headers as Record<string, string>)['Content-Type']).toBeUndefined()
  })
})

describe('非 0 业务码', () => {
  it('抛错携带 code/message/trace_id', async () => {
    stubFetch(env({ code: 33001, message: '告警不存在', trace_id: 'srv-abc' }))
    const err = await api('alerts/999/ack').catch((e) => e)
    expect(err).toBeInstanceOf(Error)
    expect(err.message).toBe('告警不存在')
    expect(err.code).toBe(33001)
    expect(err.trace_id).toBe('srv-abc')
  })

  it('fields / current_status / todo_id 原样挂 err（契约 §15.1/§15.2/§15.5 冲突码）', async () => {
    stubFetch(
      env({
        code: 33002,
        message: '状态已变更',
        data: {
          fields: { deadline: '已过截止时间' },
          current_status: 'processing',
          todo_id: 7,
        },
      }),
    )
    const err = await api('alerts/101/dispatch').catch((e) => e)
    expect(err.code).toBe(33002)
    expect(err.fields).toEqual({ deadline: '已过截止时间' })
    expect(err.current_status).toBe('processing')
    expect(err.todo_id).toBe(7)
  })

  it('message 缺省时兜底 [api] code <n>', async () => {
    stubFetch(env({ code: 10000, message: '' }))
    await expect(api('x')).rejects.toThrow('[api] code 10000')
  })
})

describe('31004 语义', () => {
  it('口径正常但无数据 → resolve(null) 而非抛错（页面自渲空态）', async () => {
    stubFetch(env({ code: 31004, data: null, message: 'no data' }))
    await expect(api('workbench/topics')).resolves.toBeNull()
  })
})

describe('401 未授权拦截', () => {
  // jsdom 的 location/location.assign 均 configurable:false，无法 spy；
  // 可观测断言压在「回调触发 + 错误照常抛出」上，硬跳 /login 由 e2e 覆盖
  it('20001 触发已注册回调（业务端点）', async () => {
    const onUnauthorized = vi.fn()
    registerUnauthorizedHandler(onUnauthorized)
    stubFetch(env({ code: 20001, message: '未登录' }))
    await expect(api('workbench/overview')).rejects.toMatchObject({ code: 20001 })
    expect(onUnauthorized).toHaveBeenCalledOnce()
  })

  it.each([20002, 20003])('授权类码 %s 同样触发拦截', async (code) => {
    const onUnauthorized = vi.fn()
    registerUnauthorizedHandler(onUnauthorized)
    stubFetch(env({ code, message: 'x' }))
    await expect(api('workbench/overview')).rejects.toMatchObject({ code })
    expect(onUnauthorized).toHaveBeenCalledOnce()
  })

  it('auth/* 自检族豁免拦截（防 /login 重定向套娃）', async () => {
    const onUnauthorized = vi.fn()
    registerUnauthorizedHandler(onUnauthorized)
    stubFetch(env({ code: 20001, message: '未登录' }))
    await expect(api('auth/profile')).rejects.toMatchObject({ code: 20001 })
    expect(onUnauthorized).not.toHaveBeenCalled()
  })
})

describe('操作人角色映射（?role= 缺省操作人域）', () => {
  it.each([
    ['president', 'president'],
    ['ops_director', 'ops_director'],
    ['dept_leader', 'dept_leader'],
  ])('演示账号 %s → 透传', (input, expected) => {
    setOperatorRole(input)
    expect(getOperatorRole()).toBe(expected)
  })

  it.each(['admin', 'vp_medical', 'ghost', ''])('集外账号 %s → undefined（参数省略，后端回落会话身份）', (input) => {
    setOperatorRole(input)
    expect(getOperatorRole()).toBeUndefined()
  })

  it('undefined 角色不进 qs（撞 10001 防护）', async () => {
    setOperatorRole('vp_medical')
    const fetchMock = stubFetch(env({ data: {} }))
    await api('alerts/101/ack', { role: getOperatorRole() }, { method: 'POST', body: {} })
    expect(lastUrl(fetchMock)).toBe('/api/v1/alerts/101/ack')
  })
})
