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

/** §2.1 GET /auth/profile（dept_id: null = 院级视角，库存储哨兵 0 见契约注） */
export function getAuthProfileMock(role?: string): AuthProfileResp {
  return {
    user: ROLE_USER[role ?? ''] ?? ROLE_USER.president!,
    available_roles: [
      { role: 'president', name: '院长 (王建国)', scope: '全院' },
      { role: 'ops_director', name: '运营办主任 (李明)', scope: '全院运营/质控' },
      { role: 'dept_leader', name: '骨科主任 (刘主任)', scope: '本科室' },
    ],
    system_date: '2026-10-28',
    weekday: '星期三',
  }
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
