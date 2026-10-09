import { afterEach, expect, it, vi } from 'vitest'
import { defineComponent, h, nextTick, ref } from 'vue'
import { mount } from '@vue/test-utils'
import { useAlertSound } from '@/api/useAlertSound'
import { applyPreferences } from '@/api/preferences'

afterEach(() => { applyPreferences(null); vi.unstubAllGlobals() })
it('首载静默，用户解锁后仅新增高风险预警播放，关闭偏好后停止', async () => {
  const start=vi.fn()
  class FakeAudio {
    state='running'; currentTime=0; destination={}
    resume=async()=>{};close=async()=>{}
    createOscillator(){return {frequency:{value:0},connect:vi.fn(),disconnect:vi.fn(),start,stop:vi.fn(),onended:null}}
    createGain(){return {gain:{value:0},connect:vi.fn(),disconnect:vi.fn()}}
  }
  vi.stubGlobal('AudioContext',FakeAudio)
  applyPreferences({default_range:'本月',refresh_interval:'5 分钟',alert_sound:true,unit_abbreviation:true,privacy_mask:true})
  const items=ref<{id:number;level:string}[]>([])
  const c=mount(defineComponent({setup(){useAlertSound(items);return()=>h('div')}}))
  window.dispatchEvent(new Event('pointerdown'))
  items.value=[{id:1,level:'urgent'}]; await nextTick(); expect(start).not.toHaveBeenCalled()
  items.value=[{id:1,level:'urgent'},{id:2,level:'urgent'}]; await nextTick(); expect(start).toHaveBeenCalledTimes(1)
  applyPreferences({default_range:'本月',refresh_interval:'5 分钟',alert_sound:false,unit_abbreviation:true,privacy_mask:true})
  items.value=[{id:3,level:'urgent'}]; await nextTick(); expect(start).toHaveBeenCalledTimes(1)
  c.unmount()
})
