import { ref, watch, onUnmounted } from 'vue'
import type { SettingsResp } from './types'

export type Preferences = SettingsResp['preferences']
export const userPreferences = ref<Preferences | null>(null)

export function applyPreferences(p: Preferences | null) {
  userPreferences.value = p ? { ...p } : null
}

export function useDefaultRange() {
  return ref(userPreferences.value?.default_range ?? '本月')
}

export function usePreferencePolling(refresh: () => Promise<void>) {
  let timer: ReturnType<typeof setInterval> | undefined
  const stop = watch(() => userPreferences.value?.refresh_interval, (interval) => {
    clearInterval(timer)
    const minutes = Number.parseInt(interval ?? '', 10)
    if ([5, 15, 30].includes(minutes)) timer = setInterval(() => { void refresh() }, minutes * 60_000)
  }, { immediate: true })
  onUnmounted(() => { stop(); clearInterval(timer) })
}

export function displayMoney(value: string | number, unit?: string) {
  const multiplier = unit === '万元' ? 10_000 : unit === '亿元' ? 100_000_000 : 0
  const n = Number(String(value).replace(/,/g, ''))
  if (userPreferences.value?.unit_abbreviation === false && multiplier && Number.isFinite(n)) {
    return { value: (n * multiplier).toLocaleString('zh-CN', { maximumFractionDigits: 2 }), unit: '元' }
  }
  return { value, unit }
}
