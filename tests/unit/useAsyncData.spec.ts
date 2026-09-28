import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ApiError, toApiError, useAsyncData } from '@/api/useAsyncData'

// 五态取数封装（frontend-architecture §10.1）：loading/data/error/stale/reload + seq 并发闸
// console.error 为设计内日志，测试中静默

function deferred<T>() {
  let resolve!: (v: T) => void
  let reject!: (e: unknown) => void
  const promise = new Promise<T>((res, rej) => {
    resolve = res
    reject = rej
  })
  return { promise, resolve, reject }
}

beforeEach(() => {
  vi.spyOn(console, 'error').mockImplementation(() => {})
})

afterEach(() => {
  vi.restoreAllMocks()
})

describe('useAsyncData 五态', () => {
  it('loading→data：在途置 loading，成功后 data 落地、error/stale 清空', async () => {
    const d = deferred<{ v: number }>()
    const { data, loading, error, stale, reload } = useAsyncData(() => d.promise)

    expect(loading.value).toBe(false)
    const p = reload()
    expect(loading.value).toBe(true)

    d.resolve({ v: 42 })
    await p
    expect(loading.value).toBe(false)
    expect(data.value).toEqual({ v: 42 })
    expect(error.value).toBeNull()
    expect(stale.value).toBe(false)
  })

  it('error：失败落 ApiError，业务码与 trace_id 透传', async () => {
    const d = deferred<never>()
    const { data, loading, error, stale, reload } = useAsyncData(() => d.promise)

    const srv = Object.assign(new Error('状态已变更'), { code: 33002, trace_id: 'srv-9' })
    const p = reload()
    d.reject(srv)
    await p

    expect(loading.value).toBe(false)
    expect(data.value).toBeNull()
    expect(error.value).toBeInstanceOf(ApiError)
    expect(error.value?.code).toBe(33002)
    expect(error.value?.trace_id).toBe('srv-9')
    expect(error.value?.message).toBe('状态已变更')
    expect(stale.value).toBe(false)
  })

  it('stale：刷新失败保旧数据 + stale=true；再次成功清 stale/error', async () => {
    let gate = deferred<number>()
    const { data, error, stale, reload } = useAsyncData(() => gate.promise)

    gate.resolve(1)
    await reload()
    expect(data.value).toBe(1)

    gate = deferred<number>()
    const p2 = reload()
    gate.reject(new Error('net down'))
    await p2
    // 旧值仍在展示
    expect(data.value).toBe(1)
    expect(stale.value).toBe(true)
    expect(error.value?.message).toBe('net down')

    gate = deferred<number>()
    const p3 = reload()
    gate.resolve(2)
    await p3
    expect(data.value).toBe(2)
    expect(stale.value).toBe(false)
    expect(error.value).toBeNull()
  })

  it('首载即失败：data 仍 null → stale=false（空态而非陈旧态）', async () => {
    const d = deferred<number>()
    const { data, stale, reload } = useAsyncData(() => d.promise)
    const p = reload()
    d.reject(new Error('x'))
    await p
    expect(data.value).toBeNull()
    expect(stale.value).toBe(false)
  })

  it('reload 永不 reject（内部全捕获）', async () => {
    const d = deferred<never>()
    const { reload } = useAsyncData(() => d.promise)
    const p = reload()
    d.reject(new Error('boom'))
    await expect(p).resolves.toBeUndefined()
  })

  it('seq 闸：并发 reload 仅最后一次写态（连续切筛选不串档）', async () => {
    const gates: deferred<string>[] = []
    const { data, loading, reload } = useAsyncData(() => {
      const d = deferred<string>()
      gates.push(d)
      return d.promise
    })

    const p1 = reload()
    const p2 = reload()
    // 后发的先回——先发后回也不能覆盖
    gates[1].resolve('second')
    await p2
    gates[0].resolve('first')
    await p1

    expect(data.value).toBe('second')
    expect(loading.value).toBe(false)
  })
})

describe('toApiError', () => {
  it('ApiError 原样透传', () => {
    const e = new ApiError(20101, '账号或口令错误', 'srv-t')
    expect(toApiError(e)).toBe(e)
  })

  it('数值 code / trace_id 透传（client.ts 失败包络直通）', () => {
    const e = Object.assign(new Error('m'), { code: 33104, trace_id: 'srv-z' })
    const r = toApiError(e)
    expect(r.code).toBe(33104)
    expect(r.trace_id).toBe('srv-z')
  })

  it('无码异常落 10000 + local- 序号 trace', () => {
    const r = toApiError(new Error('weird'))
    expect(r.code).toBe(10000)
    expect(r.trace_id).toMatch(/^local-\d+$/)
  })

  it('非 Error 值转字符串兜底', () => {
    const r = toApiError('plain-fail')
    expect(r.message).toBe('plain-fail')
    expect(r.code).toBe(10000)
  })
})
