// 告警督办闭环端点函数 — api-contract §15.1~15.6(R04~R08/R10)
// 写调用一律 params 带 role: getOperatorRole()(契约 §15 头部操作人约定;读端点不带)
import { api, getOperatorRole } from './client'
import type {
  AlertAckResp,
  AlertCloseResp,
  AlertDispatchReq,
  AlertDispatchResp,
  StaffListResp,
  TodoListResp,
  TodoStatus,
  TodoStatusReq,
  TodoStatusResp,
} from './types'

/** §15.1 R04 POST /alerts/{id}/ack — 告警认领(pending→processing) */
export function ackAlert(id: number) {
  return api<AlertAckResp>(`alerts/${id}/ack`, { role: getOperatorRole() }, { method: 'POST', body: {} })
}

/** §15.2 R05 POST /alerts/{id}/dispatch — 告警派发督办工单 */
export function dispatchAlert(id: number, req: AlertDispatchReq) {
  return api<AlertDispatchResp>(`alerts/${id}/dispatch`, { role: getOperatorRole() }, { method: 'POST', body: req })
}

/** §15.3 R06 POST /alerts/{id}/close — 告警直接闭环(必填办结理由) */
export function closeAlert(id: number, closeNote: string) {
  return api<AlertCloseResp>(`alerts/${id}/close`, { role: getOperatorRole() }, { method: 'POST', body: { close_note: closeNote } })
}

/** §15.4 R07 GET /todos — 督办工单分页列表(读,不带 role) */
export function getTodos(params?: { page?: number; size?: number; status?: TodoStatus; assignee_id?: number }) {
  const p: Record<string, string> = {}
  if (params?.page !== undefined) p.page = String(params.page)
  if (params?.size !== undefined) p.size = String(params.size)
  if (params?.status !== undefined) p.status = params.status
  if (params?.assignee_id !== undefined) p.assignee_id = String(params.assignee_id)
  return api<TodoListResp>('todos', p)
}

/** §15.5 R08 POST /todos/{id}/status — 工单接单/办结反馈 */
export function setTodoStatus(id: number, req: TodoStatusReq) {
  return api<TodoStatusResp>(`todos/${id}/status`, { role: getOperatorRole() }, { method: 'POST', body: req })
}

/** §15.6 R10 GET /staff — 承办人联想选择器(读) */
export function getStaff(deptId?: number) {
  return api<StaffListResp>('staff', deptId !== undefined ? { dept_id: String(deptId) } : {})
}
