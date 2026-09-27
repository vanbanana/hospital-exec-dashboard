// 系统设置写回端点函数 — api-contract §15.7~15.8(R15/R16);读侧 getSettings 在 workbench.ts
// 写调用一律 params 带 role: getOperatorRole()(契约 §15 头部操作人约定)
import { api, getOperatorRole } from './client'
import type { PreferencesPatch, RuleToggleResp, SettingsResp } from './types'

/** §15.7 R15 POST /workbench/settings/rules/{code} — 预警阈值启停写回 */
export function setRuleEnabled(code: string, enabled: boolean) {
  return api<RuleToggleResp>(`workbench/settings/rules/${code}`, { role: getOperatorRole() }, { method: 'POST', body: { enabled } })
}

/** §15.8 R16 PUT /workbench/settings/preferences — 系统偏好部分更新,回参为完整偏好集 */
export function savePreferences(patch: PreferencesPatch) {
  return api<SettingsResp['preferences']>('workbench/settings/preferences', { role: getOperatorRole() }, { method: 'PUT', body: patch })
}
