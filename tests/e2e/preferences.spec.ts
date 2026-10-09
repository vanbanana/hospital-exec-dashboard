import { expect, test } from '@playwright/test'

test('默认范围与金额偏好保存后实际生效，重新进入页面仍保留', async ({ page }) => {
  await page.goto('/login')
  await page.fill('#login-username', 'president')
  await page.fill('#login-password', 'Edss@2026')
  await page.click('.login-btn')
  await page.waitForURL(/workbench/)
  const before = await (await page.request.get('/api/v1/workbench/settings/preferences')).json()
  expect(before.code).toBe(0)
  try {
    await page.goto('/workbench/settings')
    const selects = page.locator('.wb-preferences .wb-select')
    await selects.nth(0).selectOption('本季')
    await expect(page.locator('.wb-toast-stack')).toContainText('已保存')
    await page.goto('/workbench/overview')
    await expect(page.locator('.wb-seg-item.active')).toHaveText('本季')
    const response = await page.request.put('/api/v1/workbench/settings/preferences', {data:{unit_abbreviation:false}})
    expect((await response.json()).code).toBe(0)
    await page.reload()
    await expect(page.locator('.wb-stat-unit').filter({hasText:/^元$/}).first()).toBeVisible()
    await expect(page.locator('.data-mode-note')).toContainText('演示数据')
  } finally {
    const restored = await page.request.put('/api/v1/workbench/settings/preferences', {data:before.data})
    expect((await restored.json()).code).toBe(0)
  }
})

test('服务端会话吊销后，业务请求清理缓存并回登录页', async ({ page }) => {
  await page.goto('/login')
  await page.fill('#login-username', 'president')
  await page.fill('#login-password', 'Edss@2026')
  await page.click('.login-btn')
  await page.waitForURL(/workbench/)
  await page.waitForLoadState('networkidle')
  const logout = await page.request.post('/api/v1/auth/logout', {data:{}})
  expect((await logout.json()).code).toBe(0)
  await page.locator('.sidebar-nav a[href="/workbench/overview"]').click()
  await page.waitForURL(/login/)
  await expect(page.locator('#login-username')).toBeVisible()
})
