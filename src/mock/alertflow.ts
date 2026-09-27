// 告警督办有状态 mock — frontend-architecture §8.4.4 首个状态源,api-contract §15.1~15.8
// 模块态:alerts 状态机(Map) + todos(Map) + STAFF 常量;每次变更写回 localStorage
// 持久化口径:§8.4.4 原文"页面刷新即重置"经 P3-EW-T2 任务书更新为持久化(刷新后工单还在)
// mockNow() 用墙钟 ISO 串 —— mock 轨无后端虚拟时钟(sim.clock.virtual_now),墙钟为可接受近似
import { homeAlerts } from './home'
import { settingsData } from './settings'
import type { MockParams } from './index'
import type {
  AlertAckResp,
  AlertCloseResp,
  AlertDispatchResp,
  AlertLevel,
  AlertStatus,
  HomeAlertsResp,
  SettingsResp,
  StaffItem,
  StaffListResp,
  TodoItem,
  TodoListResp,
  TodoStatus,
  TodoStatusResp,
  RuleToggleResp,
} from '../api/types'

interface AlertState {
  id: number
  level: AlertLevel
  title: string
  occurred_at: string
  rule_code: string
  alert_status: AlertStatus
}

// 存储态 todo = 契约 TodoItem + 幂等锚点 alert_occurred_at(契约 §15.2 部分唯一索引口径),出参剥离
type StoredTodo = TodoItem & { alert_occurred_at: string }

const LS_KEY = 'mock_alertflow_v1'

const TODO_STATUS_LABEL: Record<TodoStatus, string> = {
  open: '待接单',
  doing: '办理中',
  done: '已办结',
  expired: '已逾期',
}
const TODO_STATUSES = Object.keys(TODO_STATUS_LABEL) as TodoStatus[]

// §15.6 在职人员常量 — 覆盖派发主流科室,每科首行 is_leader(负责人优先联想,排序 is_leader DESC, id)
const STAFF: StaffItem[] = [
  { id: 101, code: 'E0101', name: '周婷', title: '主任医师', dept_id: 19, dept_name: '急诊科', is_leader: true },
  { id: 102, code: 'E0102', name: '林峰', title: '副主任医师', dept_id: 19, dept_name: '急诊科', is_leader: false },
  { id: 103, code: 'E0103', name: '吴敏', title: '主治医师', dept_id: 19, dept_name: '急诊科', is_leader: false },
  { id: 301, code: 'E0301', name: '王建国', title: '主任医师', dept_id: 1, dept_name: '骨科', is_leader: true },
  { id: 302, code: 'E0302', name: '李雪', title: '副主任医师', dept_id: 1, dept_name: '骨科', is_leader: false },
  { id: 303, code: 'E0303', name: '赵磊', title: '主治医师', dept_id: 1, dept_name: '骨科', is_leader: false },
  { id: 401, code: 'E0401', name: '郑海涛', title: '主任医师', dept_id: 20, dept_name: '重症医学科', is_leader: true },
  { id: 402, code: 'E0402', name: '孙丽', title: '副主任医师', dept_id: 20, dept_name: '重症医学科', is_leader: false },
  { id: 501, code: 'M0501', name: '陈正', title: '主任医师', dept_id: 34, dept_name: '医务部', is_leader: true },
  { id: 502, code: 'M0502', name: '刘芳', title: '副主任医师', dept_id: 34, dept_name: '医务部', is_leader: false },
  { id: 601, code: 'M0601', name: '杨光', title: '主治医师', dept_id: 34, dept_name: '医务部', is_leader: false },
]

const mockNow = () => new Date().toISOString()

/** 契约 §15.4 注3:deadline/created_at 出参 'YYYY-MM-DD HH:mm' 本地时——ISO/空格串先 new Date 再取本地分量,直接切片会漏时区偏移 */
function toMinute(s: string): string {
  const d = new Date(s.replace(' ', 'T'))
  if (Number.isNaN(d.getTime())) return s.replace('T', ' ').slice(0, 16)
  const p = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`
}

/** 失败包络形 Error — mock 轨由 client 原样透传,形状对齐真轨拆包络产物(code/fields/current_status/todo_id) */
function fail(
  code: number,
  message: string,
  extra?: { fields?: Record<string, string>; current_status?: string; todo_id?: number },
): never {
  const err = new Error(message) as Error & {
    code?: number
    fields?: Record<string, string>
    current_status?: string
    todo_id?: number
  }
  err.code = code
  if (extra?.fields) err.fields = extra.fields
  if (extra?.current_status) err.current_status = extra.current_status
  if (extra?.todo_id !== undefined) err.todo_id = extra.todo_id
  throw err
}

interface Persisted {
  alerts: AlertState[]
  todos: StoredTodo[]
  next_todo_id?: number
}

function seed(): Persisted {
  return {
    // 初始状态机派生自 homeAlerts(id 201~205)自带 alert_status(§3.6 演进后真源),202 置 processing 对齐真库已认领样态
    alerts: homeAlerts.list.map((a) => ({ ...a })),
    todos: [
      {
        id: 1,
        alert_id: 202,
        alert_occurred_at: '2026-10-27',
        title: '骨科床位使用率持续超标整改',
        assignee_id: 301,
        assignee_name: '王建国',
        dept_name: '骨科',
        deadline: '2026-10-31 17:00',
        todo_status: 'doing',
        status_label: TODO_STATUS_LABEL.doing,
        baseline_value: 96.8,
        current_value: 95.4,
        target_value: 90.0,
        metric_code: 'BED_USE_RATE',
        note: '限期三日回落红线',
        result_note: null,
        created_at: '2026-10-28 09:20',
      },
    ],
    next_todo_id: 2,
  }
}

function load(): Persisted {
  try {
    const raw = localStorage.getItem(LS_KEY)
    if (raw) {
      const s = JSON.parse(raw) as Persisted
      if (Array.isArray(s.alerts) && Array.isArray(s.todos)) return s
    }
  } catch {
    // localStorage 不可用或脏数据 → 退回种子态
  }
  return seed()
}

const persisted = load()

// 与 homeAlerts 种子对账:持久态缺的新告警补 pending(202 补 processing),种子外旧 id 丢弃
const seedIds = new Set(homeAlerts.list.map((a) => a.id))
const alerts = new Map<number, AlertState>()
for (const s of persisted.alerts) {
  if (seedIds.has(s.id)) alerts.set(s.id, s)
}
for (const a of homeAlerts.list) {
  if (!alerts.has(a.id)) alerts.set(a.id, { ...a, alert_status: a.id === 202 ? 'processing' : 'pending' })
}

const todos = new Map<number, StoredTodo>(persisted.todos.map((t) => [t.id, t]))
let nextTodoId = persisted.next_todo_id ?? Math.max(0, ...persisted.todos.map((t) => t.id)) + 1

function save() {
  try {
    const data: Persisted = { alerts: [...alerts.values()], todos: [...todos.values()], next_todo_id: nextTodoId }
    localStorage.setItem(LS_KEY, JSON.stringify(data))
  } catch {
    // 隐私模式等写失败:内存态仍生效,刷新退回上次持久态
  }
}

/** §15.4 注2:expired 惰性清扫 — 读取时把 deadline 已过的 open|doing 单置 expired */
function sweepExpired() {
  const now = Date.now()
  let dirty = false
  for (const t of todos.values()) {
    if (
      (t.todo_status === 'open' || t.todo_status === 'doing') &&
      new Date(t.deadline.replace(' ', 'T')).getTime() < now
    ) {
      t.todo_status = 'expired'
      t.status_label = TODO_STATUS_LABEL.expired
      dirty = true
    }
  }
  if (dirty) save()
}

function openTodoFor(a: AlertState): StoredTodo | undefined {
  for (const t of todos.values()) {
    if (
      t.alert_id === a.id &&
      t.alert_occurred_at === a.occurred_at &&
      (t.todo_status === 'open' || t.todo_status === 'doing')
    ) {
      return t
    }
  }
  return undefined
}

function stripTodo(t: StoredTodo): TodoItem {
  const { alert_occurred_at: _anchor, ...item } = t
  return item
}

function bodyObj(body: unknown): Record<string, unknown> {
  return (typeof body === 'object' && body !== null && !Array.isArray(body) ? body : {}) as Record<string, unknown>
}

/* ===== resolver —— 由 mock/index.ts 注册,(params 含路径回填参数, body 为 client 透传的请求体) ===== */

/** workbench/home/alerts:homeAlerts 同形,过滤打开集 pending|processing(close/done 后自动退出) */
export function alertStateList(): HomeAlertsResp {
  const list = [...alerts.values()]
    .filter((a) => a.alert_status === 'pending' || a.alert_status === 'processing')
    .map(({ id, level, title, occurred_at, rule_code, alert_status }) => ({
      id,
      level,
      title,
      occurred_at,
      rule_code,
      alert_status,
    }))
  return { list }
}

/** §15.6 R10 GET /staff(?dept_id=) */
export function staffList(params: MockParams): StaffListResp {
  let deptId: number | undefined
  if (params.dept_id !== undefined) {
    deptId = Number(params.dept_id)
    if (!Number.isInteger(deptId)) fail(10001, '请求参数错误', { fields: { dept_id: '须为整数' } })
  }
  const list = STAFF.filter((s) => deptId === undefined || s.dept_id === deptId)
  list.sort((x, y) => Number(y.is_leader) - Number(x.is_leader) || x.id - y.id)
  return { list }
}

/** §15.4 R07 GET /todos(?page&size&status&assignee_id) */
export function getTodosList(params: MockParams): TodoListResp {
  const page = params.page === undefined ? 1 : Number(params.page)
  const size = params.size === undefined ? 20 : Number(params.size)
  if (!Number.isInteger(page) || page < 1) fail(10001, '请求参数错误', { fields: { page: '须为正整数' } })
  if (!Number.isInteger(size) || size < 1 || size > 100) fail(10001, '请求参数错误', { fields: { size: '须为 1~100 整数' } })
  const status = params.status
  if (status !== undefined && !TODO_STATUSES.includes(status as TodoStatus)) {
    fail(10001, '请求参数错误', { fields: { status: '枚举域 open|doing|done|expired' } })
  }
  let assigneeId: number | undefined
  if (params.assignee_id !== undefined) {
    assigneeId = Number(params.assignee_id)
    if (!Number.isInteger(assigneeId)) fail(10001, '请求参数错误', { fields: { assignee_id: '须为整数' } })
  }
  sweepExpired()
  let list = [...todos.values()]
  if (status !== undefined) list = list.filter((t) => t.todo_status === status)
  if (assigneeId !== undefined) list = list.filter((t) => t.assignee_id === assigneeId)
  const start = (page - 1) * size
  return { list: list.slice(start, start + size).map(stripTodo), page, size, total: list.length }
}

/** §15.1 R04 POST /alerts/{id}/ack */
export function postAlertAck(params: MockParams): AlertAckResp {
  const id = Number(params.id)
  if (!Number.isInteger(id)) fail(10001, '请求参数错误', { fields: { id: '须为整数' } })
  const a = alerts.get(id)
  if (!a) fail(33001, '告警不存在')
  if (a.alert_status !== 'pending') fail(33002, '告警已被处理', { current_status: a.alert_status })
  a.alert_status = 'processing'
  save()
  return { id: a.id, alert_status: 'processing', ack_at: mockNow(), ack_by: 1 }
}

/** §15.2 R05 POST /alerts/{id}/dispatch */
export function postAlertDispatch(params: MockParams, body?: unknown): AlertDispatchResp {
  const b = bodyObj(body)
  const fields: Record<string, string> = {}
  if (typeof b.assignee_id !== 'number' || !Number.isInteger(b.assignee_id)) fields.assignee_id = '必填,整数'
  if (typeof b.deadline !== 'string' || !b.deadline) fields.deadline = '必填,ISO 8601'
  if (Object.keys(fields).length) fail(10002, '参数校验失败', { fields })
  const id = Number(params.id)
  if (!Number.isInteger(id)) fail(10001, '请求参数错误', { fields: { id: '须为整数' } })
  const a = alerts.get(id)
  if (!a) fail(33001, '告警不存在')
  const dl = new Date(String(b.deadline).replace(' ', 'T'))
  if (Number.isNaN(dl.getTime()) || dl.getTime() <= Date.now()) fail(33103, '截止时间须晚于当前时间')
  const staff = STAFF.find((s) => s.id === b.assignee_id)
  if (!staff) fail(33102, '承办人非在职或不存在')
  if (a.alert_status === 'done' || a.alert_status === 'closed') {
    fail(33002, '告警已办结', { current_status: a.alert_status })
  }
  const opened = openTodoFor(a)
  if (opened) fail(33002, '该告警已有打开的督办工单', { current_status: 'todo_open', todo_id: opened.id })
  const todo: StoredTodo = {
    id: nextTodoId++,
    alert_id: a.id,
    alert_occurred_at: a.occurred_at,
    title: typeof b.title === 'string' && b.title ? b.title : a.title,
    assignee_id: staff.id,
    assignee_name: staff.name,
    dept_name: staff.dept_name,
    deadline: toMinute(String(b.deadline)),
    todo_status: 'open',
    status_label: TODO_STATUS_LABEL.open,
    baseline_value: null,
    current_value: null,
    target_value: null,
    metric_code: a.rule_code,
    note: typeof b.note === 'string' && b.note ? b.note : null,
    result_note: null,
    created_at: toMinute(mockNow()),
  }
  todos.set(todo.id, todo)
  // pending 告警连带自动认领(契约 §15.2 说明),processing 幂等
  a.alert_status = 'processing'
  save()
  return {
    todo_id: todo.id,
    alert_id: a.id,
    alert_status: 'processing',
    assignee_id: staff.id,
    deadline: String(b.deadline),
  }
}

/** §15.3 R06 POST /alerts/{id}/close */
export function postAlertClose(params: MockParams, body?: unknown): AlertCloseResp {
  const b = bodyObj(body)
  if (typeof b.close_note !== 'string' || !b.close_note.trim()) {
    fail(10002, '参数校验失败', { fields: { close_note: '必填,办结理由不能为空' } })
  }
  const id = Number(params.id)
  if (!Number.isInteger(id)) fail(10001, '请求参数错误', { fields: { id: '须为整数' } })
  const a = alerts.get(id)
  if (!a) fail(33001, '告警不存在')
  if (a.alert_status === 'closed' || a.alert_status === 'done') {
    fail(33002, '告警已办结', { current_status: a.alert_status })
  }
  const opened = openTodoFor(a)
  if (opened) fail(33002, '存在打开的督办工单,须先办结', { current_status: 'todo_open', todo_id: opened.id })
  a.alert_status = 'closed'
  save()
  return { id: a.id, alert_status: 'closed', closed_at: mockNow() }
}

/** §15.5 R08 POST /todos/{id}/status */
export function postTodoStatus(params: MockParams, body?: unknown): TodoStatusResp {
  const id = Number(params.id)
  if (!Number.isInteger(id)) fail(10001, '请求参数错误', { fields: { id: '须为整数' } })
  const t = todos.get(id)
  if (!t) fail(33101, '督办工单不存在')
  if (t.todo_status === 'done' || t.todo_status === 'expired') {
    fail(33104, '工单已关闭,禁止变更', { current_status: t.todo_status })
  }
  const b = bodyObj(body)
  if (b.action !== 'accept' && b.action !== 'report') {
    fail(10002, '参数校验失败', { fields: { action: '须为 accept|report' } })
  }
  if (b.action === 'accept') {
    if (t.todo_status !== 'open') fail(33104, '工单已接单,禁止重复变更', { current_status: t.todo_status })
    t.todo_status = 'doing'
  } else {
    if (t.todo_status !== 'doing') {
      fail(10002, '参数校验失败', { fields: { action: 'open 工单须先 accept 接单' } })
    }
    if (typeof b.result_note !== 'string' || !b.result_note.trim()) {
      fail(10002, '参数校验失败', { fields: { result_note: 'report 必填办结说明' } })
    }
    t.result_note = b.result_note
    t.todo_status = 'done'
    // 同事务回填源告警 done(契约 §15.5 语义注;alert_status IN pending|processing 才入打开集,done 自动退出)
    const a = alerts.get(t.alert_id)
    if (a) a.alert_status = 'done'
  }
  t.status_label = TODO_STATUS_LABEL[t.todo_status]
  save()
  return {
    id: t.id,
    todo_status: t.todo_status,
    alert_id: t.alert_id,
    alert_status: alerts.get(t.alert_id)?.alert_status ?? 'processing',
  }
}

/** §15.7 R15 POST /workbench/settings/rules/{code} — 原地改 settingsData.thresholds 行(无需持久化) */
export function postRuleToggle(params: MockParams, body?: unknown): RuleToggleResp {
  const row = settingsData.thresholds.find((r) => r.code === params.code)
  if (!row) fail(10003, '规则不存在')
  const b = bodyObj(body)
  if (typeof b.enabled !== 'boolean') fail(10002, '参数校验失败', { fields: { enabled: '须为布尔' } })
  row.enabled = b.enabled
  return { code: row.code, enabled: row.enabled }
}

/** §15.8 R16 PUT /workbench/settings/preferences — 逐键部分更新,回完整偏好集 */
export function putPreferences(_params: MockParams, body?: unknown): SettingsResp['preferences'] {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) fail(10001, '请求参数错误')
  const b = body as Record<string, unknown>
  const keys = Object.keys(b)
  if (!keys.length || keys.some((k) => !(k in settingsData.preferences))) fail(10001, '请求参数错误')
  const fields: Record<string, string> = {}
  for (const k of keys) {
    const v = b[k]
    if (k === 'default_range' && (typeof v !== 'string' || !['本月', '本季', '本年'].includes(v))) {
      fields[k] = '枚举:本月|本季|本年'
    } else if (k === 'refresh_interval' && (typeof v !== 'string' || !['5 分钟', '15 分钟', '30 分钟'].includes(v))) {
      fields[k] = '枚举:5 分钟|15 分钟|30 分钟'
    } else if (['alert_sound', 'unit_abbreviation', 'privacy_mask'].includes(k) && typeof v !== 'boolean') {
      fields[k] = '须为布尔'
    }
  }
  if (Object.keys(fields).length) fail(10002, '参数校验失败', { fields })
  Object.assign(settingsData.preferences, b)
  return settingsData.preferences
}
