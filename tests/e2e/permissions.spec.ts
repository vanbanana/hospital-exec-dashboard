import { expect, test } from '@playwright/test'

test.describe('生产权限模式', () => {
  test.skip(process.env.EDSS_TEST_PRODUCTION !== '1', '仅在生产权限开关启用的后端执行')
  test('科室登录进入工单，仅看本科室人员和个人偏好', async ({ page, baseURL }) => {
    const hospitalAlerts: string[] = []
    page.on('request', request => { if (request.url().includes('/api/v1/workbench/home/alerts')) hospitalAlerts.push(request.url()) })
    await page.goto('/login')
    await page.fill('#login-username', 'dept_leader')
    await page.fill('#login-password', 'Edss@2026')
    await page.click('.login-btn')
    await page.waitForURL(/workbench\/tasks/)
    const cookie = (await page.context().cookies()).find(c => c.name === 'edss_sid')
    expect(cookie?.httpOnly).toBe(true)
    if (baseURL?.startsWith('https:')) expect(cookie?.secure).toBe(true)
    await expect(page.locator('.sidebar-nav')).not.toContainText('人力资源')
    await expect(page.locator('.sidebar-nav')).toContainText('个人偏好')
    await expect(page.locator('.notice-badge-wrapper')).toHaveCount(0)
    const denied = await page.request.get('/api/v1/workbench/overview')
    expect(denied.status()).toBe(403)
    const staff = await (await page.request.get('/api/v1/staff')).json()
    expect(staff.code).toBe(0)
    expect(staff.data.list.length).toBeGreaterThan(0)
    expect(staff.data.list.every((s: {dept_id:number;name:string}) => s.dept_id === 1 && s.name.endsWith('**'))).toBe(true)
    expect((await page.request.get('/api/v1/staff?dept_id=19')).status()).toBe(403)
    await page.goto('/workbench/preferences')
    await expect(page.locator('.wb-preferences')).toBeVisible()
    await page.waitForLoadState('networkidle')
    expect(hospitalAlerts).toEqual([])
  })
  test('未登录的大屏数据受保护', async ({ request }) => {
    expect((await request.get('/api/v1/screen/snapshot')).status()).toBe(401)
  })
})
