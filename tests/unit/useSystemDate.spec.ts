import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { AuthProfileResp } from '@/api/types'
import { ref, nextTick } from 'vue'

// useSystemDate：业务基准日唯一来源 = profile.system_date；profile 未到位/失败保持空串
// （假日期已清——空串兜底是本用例的回归锚点）

const h = vi.hoisted(() => ({ currentProfile: vi.fn() }))
const profileState = ref<AuthProfileResp | null>(null)

vi.mock('@/api/session', () => ({ currentProfile: h.currentProfile, get profileState() { return profileState } }))

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

const flush = () => new Promise((r) => setTimeout(r, 0))

beforeEach(() => {
  h.currentProfile.mockReset()
  profileState.value = null
  vi.resetModules()
})

describe('useSystemDate', () => {
  it('profile 到位后 systemDate 取 profile.system_date', async () => {
    h.currentProfile.mockImplementation(async () => { profileState.value = profile; return profile })
    const { useSystemDate } = await import('@/api/useSystemDate')
    const d = useSystemDate()
    expect(d.value).toBe('') // 未到位前不预填演示日期
    await flush()
    expect(d.value).toBe('2026-10-28')
    profileState.value = null
    await nextTick()
    expect(d.value).toBe('')
  })

  it('profile 失败时空串兜底，不抛错不造假日期', async () => {
    h.currentProfile.mockRejectedValue(Object.assign(new Error('未登录'), { code: 20001 }))
    const { useSystemDate } = await import('@/api/useSystemDate')
    const d = useSystemDate()
    await flush()
    expect(d.value).toBe('')
  })

  it('多消费位共享同一 boot：重复调用不重复拉 profile', async () => {
    h.currentProfile.mockResolvedValue(profile)
    const { useSystemDate } = await import('@/api/useSystemDate')
    useSystemDate()
    useSystemDate()
    useSystemDate()
    await flush()
    expect(h.currentProfile).toHaveBeenCalledTimes(1)
  })
})
