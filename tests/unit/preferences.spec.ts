import { afterEach, describe, expect, it, vi } from 'vitest'
import { defineComponent, h } from 'vue'
import { mount } from '@vue/test-utils'
import { applyPreferences, displayMoney, useDefaultRange, usePreferencePolling } from '@/api/preferences'

const prefs = {default_range:'本季',refresh_interval:'5 分钟',alert_sound:true,unit_abbreviation:true,privacy_mask:true}
afterEach(() => { applyPreferences(null); vi.useRealTimers() })
describe('用户偏好实际行为', () => {
  it('新页面使用服务器返回的默认时间范围', () => {
    applyPreferences(prefs)
    expect(useDefaultRange().value).toBe('本季')
  })
  it('金额关闭缩写后换算为元，比例保持原单位', () => {
    applyPreferences({...prefs,unit_abbreviation:false})
    expect(displayMoney('1.25','万元')).toEqual({value:'12,500',unit:'元'})
    expect(displayMoney('92.12','%')).toEqual({value:'92.12',unit:'%'})
  })
  it('按偏好轮询并在卸载时清理', async () => {
    vi.useFakeTimers()
    applyPreferences(prefs)
    const refresh=vi.fn(async () => {})
    const c=mount(defineComponent({setup(){usePreferencePolling(refresh);return()=>h('div')}}))
    await vi.advanceTimersByTimeAsync(300000)
    expect(refresh).toHaveBeenCalledTimes(1)
    c.unmount()
    await vi.advanceTimersByTimeAsync(300000)
    expect(refresh).toHaveBeenCalledTimes(1)
  })
})
