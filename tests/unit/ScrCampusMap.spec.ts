import { describe, expect, it } from 'vitest'
import { shallowMount } from '@vue/test-utils'
import ScrCampusMap from '@/components/screen/ScrCampusMap.vue'
import type { ScreenBuilding } from '@/api/types'

// ScrCampusMap 阈值回归网——历史 bug：card-right / pop-below 判定方向写反。
// 阈值（组件内常量）：anchor.x < 27 → card-right；anchor.y < 21 → pop-below（严格小于）。
// 纯函数未导出，经 shallowMount 断言 .campus-pin 的 class 挂载（契约 §14.1 注7 锚点坐标系）。

const b = (code: string, x: number, y: number, status: ScreenBuilding['status'] = 'normal'): ScreenBuilding => ({
  code,
  name: `${code}楼`,
  status,
  badge: 'b',
  badge_level: 'info',
  anchor: { x, y },
  metrics: {},
})

describe('ScrCampusMap pin 朝向阈值', () => {
  const wrapper = shallowMount(ScrCampusMap, {
    props: {
      buildings: [
        b('topleft', 10, 10), // x<27 && y<21 → 双翻转
        b('boundary', 27, 21), // 恰在阈值 → 均不翻转（严格 <）
        b('left', 26.9, 50), // 仅 card-right
        b('top', 50, 20.9), // 仅 pop-below
        b('inner', 80, 60), // 均不翻转
      ],
    },
  })
  const pins = wrapper.findAll('.campus-pin')

  it('按 buildings 数组逐楼渲 pin', () => {
    expect(pins).toHaveLength(5)
  })

  it('锚点靠左上：card-right + pop-below 同挂', () => {
    expect(pins[0].classes()).toContain('card-right')
    expect(pins[0].classes()).toContain('pop-below')
  })

  it('恰在阈值（x=27, y=21）：不翻转（严格小于边界值）', () => {
    expect(pins[1].classes()).not.toContain('card-right')
    expect(pins[1].classes()).not.toContain('pop-below')
  })

  it('仅 x 越左阈：card-right 单独挂载', () => {
    expect(pins[2].classes()).toContain('card-right')
    expect(pins[2].classes()).not.toContain('pop-below')
  })

  it('仅 y 越顶阈：pop-below 单独挂载', () => {
    expect(pins[3].classes()).not.toContain('card-right')
    expect(pins[3].classes()).toContain('pop-below')
  })

  it('常规位锚点：两向均不翻转', () => {
    expect(pins[4].classes()).not.toContain('card-right')
    expect(pins[4].classes()).not.toContain('pop-below')
  })
})

describe('ScrCampusMap 渲染基线', () => {
  it('pin 定位 style 取 anchor 百分比；alert 态挂 is-alert', () => {
    const wrapper = shallowMount(ScrCampusMap, {
      props: { buildings: [b('jz', 33.5, 44.2, 'alert'), b('mz', 60, 70)] },
    })
    const pins = wrapper.findAll('.campus-pin')
    expect(pins[0].attributes('style')).toContain('left: 33.5%')
    expect(pins[0].attributes('style')).toContain('top: 44.2%')
    expect(pins[0].find('.pin-card').classes()).toContain('is-alert')
    expect(pins[1].find('.pin-card').classes()).not.toContain('is-alert')
  })

  it('buildings 缺席时空渲不崩', () => {
    const wrapper = shallowMount(ScrCampusMap)
    expect(wrapper.findAll('.campus-pin')).toHaveLength(0)
  })
})
