import { afterEach, describe, expect, it, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import { nextTick } from 'vue'
import WbToast, { toast, useToast } from '@/components/workbench/WbToast.vue'

// WbToast 回归网——历史 bug：owner 曾用 ref 存对象 token，深响应化后 owner===token 恒 false，
// 没有任何实例认领渲染位 → Toast 栈整体缺席（V3 实测 DOM 缺失）。
// 防回归断言直接压在「DOM 里恰好一个 .wb-toast-stack」上，而非内部实现细节。

const drain = () => {
  // 队列是模块级单例，用例间手工排空；注意不碰 isOwner——求值即占位
  const { toasts } = useToast()
  toasts.splice(0)
}

afterEach(() => {
  vi.useRealTimers()
  drain()
  // 残留 teleported 节点兜底清理（正常路径 unmount 自动带走）
  document.body.querySelectorAll('.wb-toast-stack').forEach((n) => n.remove())
})

describe('WbToast owner 占位', () => {
  it('多实例同页挂载，先到先渲：body 中恰好一份 toast 栈', async () => {
    const w1 = mount(WbToast)
    const w2 = mount(WbToast)
    await nextTick()

    expect(document.body.querySelectorAll('.wb-toast-stack')).toHaveLength(1)

    toast.success('reg-a')
    await nextTick()
    const items = document.body.querySelectorAll('.wb-toast-item')
    expect(items).toHaveLength(1)
    expect(items[0].textContent).toContain('reg-a')

    w1.unmount()
    w2.unmount()
  })

  it('owner 卸载后占位释放，幸存实例自动接管渲染', async () => {
    const w1 = mount(WbToast)
    const w2 = mount(WbToast)
    await nextTick()
    expect(document.body.querySelectorAll('.wb-toast-stack')).toHaveLength(1)

    w1.unmount() // w1 是 owner；释放后 w2 的 computed 重算认领
    await nextTick()
    expect(document.body.querySelectorAll('.wb-toast-stack')).toHaveLength(1)

    toast.error('reg-b')
    await nextTick()
    expect(document.body.querySelectorAll('.wb-toast-item')).toHaveLength(1)
    expect(document.body.querySelector('.wb-toast-item')?.textContent).toContain('reg-b')

    w2.unmount()
    await nextTick()
    expect(document.body.querySelectorAll('.wb-toast-stack')).toHaveLength(0)
  })

  it('owner 缺席时 push 的存量在接管后照常渲染', async () => {
    const w1 = mount(WbToast)
    const w2 = mount(WbToast)
    await nextTick()

    w1.unmount()
    toast.warning('queued-before-handoff')
    await nextTick()

    expect(document.body.querySelectorAll('.wb-toast-stack')).toHaveLength(1)
    expect(document.body.querySelector('.wb-toast-item')?.textContent).toContain(
      'queued-before-handoff',
    )
    w2.unmount()
  })
})

describe('WbToast 队列渲染', () => {
  it('三种 tone 分别挂 tone-* 类，多条共存', async () => {
    const w = mount(WbToast)
    await nextTick()
    toast.success('ok')
    toast.warning('warn')
    toast.error('err')
    await nextTick()

    expect(document.body.querySelector('.wb-toast-item.tone-success')?.textContent).toContain('ok')
    expect(document.body.querySelector('.wb-toast-item.tone-warning')?.textContent).toContain('warn')
    expect(document.body.querySelector('.wb-toast-item.tone-error')?.textContent).toContain('err')
    w.unmount()
  })

  it('条目 3s 后自动出队', async () => {
    vi.useFakeTimers()
    const w = mount(WbToast)
    await nextTick()
    toast.success('ttl')
    await nextTick()
    expect(document.body.querySelectorAll('.wb-toast-item')).toHaveLength(1)

    vi.advanceTimersByTime(3100)
    await nextTick()
    expect(document.body.querySelectorAll('.wb-toast-item')).toHaveLength(0)
    w.unmount()
  })
})
