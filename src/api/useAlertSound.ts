import { onMounted, onUnmounted, watch, type Ref } from 'vue'
import { userPreferences } from './preferences'

export function useAlertSound(items: Ref<{ id: number; level: string }[]>) {
  let seen: Set<number> | null = null
  let audio: AudioContext | null = null
  function unlock() {
    if (typeof AudioContext === 'undefined') return
    audio ??= new AudioContext()
    void audio.resume().catch(() => { /* Browsers can deny audio until another user gesture. */ })
  }
  onMounted(() => window.addEventListener('pointerdown', unlock))
  onUnmounted(() => {
    window.removeEventListener('pointerdown', unlock)
    void audio?.close().catch(() => { /* Audio context may already be closed on navigation. */ })
  })
  watch(items, rows => {
    const fresh = seen !== null && rows.some(r => r.level === 'urgent' && !seen!.has(r.id))
    seen = new Set(rows.map(r => r.id))
    if (!fresh || !userPreferences.value?.alert_sound || audio?.state !== 'running') return
    const osc = audio.createOscillator(), gain = audio.createGain()
    osc.frequency.value = 660
    gain.gain.value = 0.04
    osc.connect(gain); gain.connect(audio.destination)
    osc.start(); osc.stop(audio.currentTime + 0.15)
    osc.onended = () => { osc.disconnect(); gain.disconnect() }
  })
}
