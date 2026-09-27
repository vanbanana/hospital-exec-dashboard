// 认证与上下文数据包 — api-contract §2.1/§2.2 示例锚定，BASE_DATE=2026-10-28 周三
import type { AuthProfileResp, HospitalProfileResp } from '../api/types'

// §2.1 avatar 契约声明为 src/assets 内资源路径；mock 期经 Vite 资源管线解析成可访问 URL
const directorAvatar = new URL('../assets/workbench/director_avatar.png', import.meta.url).href

// §2.1 ?role= 切换演示上下文:三角色上下文按 available_roles 名单实配,dept_id 骨科=1(§14.1 科室表)
const ROLE_USER: Record<string, AuthProfileResp['user']> = {
  president: { id: 1, username: 'president', real_name: '王建国', title: '院长', dept_id: null, dept_name: '全院', avatar: directorAvatar, role: 'president' },
  ops_director: { id: 2, username: 'ops_director', real_name: '李明', title: '运营办主任', dept_id: null, dept_name: '运营办', avatar: directorAvatar, role: 'ops_director' },
  dept_leader: { id: 3, username: 'dept_leader', real_name: '刘主任', title: '骨科主任', dept_id: 1, dept_name: '骨科', avatar: directorAvatar, role: 'dept_leader' },
}

/** §2.3 演示账号口令表 — 与 backend/README 演示凭据同源;admin 不入(user.role 契约域=3 演示角色)
 * mock 轨凭此演练 20101 分支 */
const DEMO_CRED: Record<string, string> = {
  president: 'Edss@2026',
  ops_director: 'Edss@2026',
  dept_leader: 'Edss@2026',
}

// §2.3/§2.4 会话旗标 — localStorage 持久化对齐 HttpOnly Cookie 跨刷新语义(frontend-architecture §8.4-4)
const SESSION_KEY = 'edss_mock_session'

/** 当前 mock 会话用户名(无旗标→null)——alertflow 写侧 ack_by/dispatcher 取此回填 */
export function sessionUsername(): string | null {
  try {
    return localStorage.getItem(SESSION_KEY)
  } catch {
    return null
  }
}

const AVAILABLE_ROLES: AuthProfileResp['available_roles'] = [
  { role: 'president', name: '院长 (王建国)', scope: '全院' },
  { role: 'ops_director', name: '运营办主任 (李明)', scope: '全院运营/质控' },
  { role: 'dept_leader', name: '骨科主任 (刘主任)', scope: '本科室' },
]

function profileOf(username: string): AuthProfileResp {
  return {
    user: ROLE_USER[username]!,
    available_roles: AVAILABLE_ROLES,
    system_date: '2026-10-28',
    weekday: '星期三',
  }
}

/** 会话旗标闸——端点在会话中间件后(契约 §2.1 演进注):无旗标一律 20001,?role= 演示切换不豁免 */
export function assertSession() {
  const u = sessionUsername()
  if (!u || !ROLE_USER[u]) {
    throw Object.assign(new Error('未登录或凭证缺失'), { code: 20001 })
  }
  return u
}

/** 会话用户角色——mock RBAC 门消费(settings/config 20004 等) */
export function sessionRole(): string | undefined {
  const u = sessionUsername()
  return u ? ROLE_USER[u]?.role : undefined
}

/**
 * §2.1 GET /auth/profile（dept_id: null = 院级视角，库存储哨兵 0 见契约注）
 * 会话闸先于 ?role= 解析(真轨序:Session 中间件→handler);?role= 出席=演示切换,缺席=会话用户
 */
export function getAuthProfileMock(role?: string): AuthProfileResp {
  const u = assertSession()
  if (role) return profileOf(role)
  return profileOf(u)
}

/** §2.3 POST /auth/login — 校验演示凭据 → 置会话旗标 → 返全量上下文 */
export function postAuthLoginMock(body: unknown): AuthProfileResp {
  const b = (body ?? {}) as { username?: string; password?: string }
  const fields: Record<string, string> = {}
  if (!b?.username) fields.username = '用户名不能为空'
  if (!b?.password) fields.password = '口令不能为空'
  if (Object.keys(fields).length) {
    // err.fields 直挂与 client.ts 真轨拆包络产形一致,表单内联可直接消费
    throw Object.assign(new Error('必填字段缺失'), { code: 10001, fields })
  }
  if (DEMO_CRED[b.username!] !== b.password) {
    throw Object.assign(new Error('用户名或密码错误'), { code: 20101 })
  }
  try {
    localStorage.setItem(SESSION_KEY, b.username!)
  } catch {
    /* 隐私模式降级为内存态:本轮内页面不失效 */
  }
  return profileOf(b.username!)
}

/** §2.4 POST /auth/logout — 幂等:清旗标恒成功,返 null */
export function postAuthLogoutMock(): null {
  try {
    localStorage.removeItem(SESSION_KEY)
  } catch {
    /* 幂等不清失败态 */
  }
  return null
}

/** §2.2 GET /hospital/profile */
export const hospitalProfile: HospitalProfileResp = {
  name: 'XX市人民医院',
  english_name: "PEOPLE'S HOSPITAL",
  level: '三级甲等综合医院',
  motto: ['厚德', '精医', '仁爱', '创新'],
  slogans: ['以数据洞察全局', '以科学决策引领医院高质量发展'],
  pillars: ['人民至上', '生命至上', '健康至上'],
}
