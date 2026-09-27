// 科技大屏端点函数 — api-contract §14
import { api } from './client'
import type { ScreenSnapshotResp } from './types'

export function getScreenSnapshot() {
  return api<ScreenSnapshotResp>('screen/snapshot')
}
