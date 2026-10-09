import { expect, test } from '@playwright/test'

test('全部工作台页面及大屏加载，无脚本或图表错误', async ({ page }) => {
  test.setTimeout(90_000)
  await page.setViewportSize({ width: 1568, height: 880 })
  const errors: string[] = []
  page.on('pageerror', e => errors.push(e.message))
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()) })
  await page.goto('/login')
  await page.fill('#login-username', 'president')
  await page.fill('#login-password', 'Edss@2026')
  await page.click('.login-btn')
  await page.waitForURL(/workbench/)
  // 首次未登录的会话探测预期返回 401；登录后的业务页面必须无错误。
  errors.length = 0
  for (const suffix of ['', 'overview', 'medical', 'operations', 'hr', 'research', 'patient', 'quality', 'assets', 'compare', 'topics', 'settings', 'tasks', 'preferences']) {
    const route = suffix ? `/workbench/${suffix}` : '/workbench'
    await page.goto(route)
    await expect(page).toHaveURL(new RegExp(`${route}$`))
    await expect(page.locator('.workbench-layout')).toBeVisible()
    await page.waitForLoadState('networkidle')
    await expect(page.locator('.wb-error-panel')).toHaveCount(0)
    expect(errors, route).toEqual([])
    if (['research', 'patient', 'quality', 'assets'].includes(suffix)) {
      await expect(page.locator('.wb-page-sub')).toContainText('固定统计口径')
      await expect(page.locator('.wb-page-head .wb-seg')).toHaveCount(0)
    }
    if (suffix === 'tasks' || suffix === 'preferences') await page.screenshot({ path: `test-results/${suffix}-smoke.png`, fullPage: true })
  }
  await page.goto('/unknown-root-route')
  await expect(page).toHaveURL(/\/workbench$/)
  await expect(page.locator('.workbench-layout')).toBeVisible()
  await page.goto('/screen')
  await expect(page.locator('.hero-ribbon .hero-item').first()).toBeVisible()
  await page.waitForLoadState('networkidle')
  expect(errors, '/screen').toEqual([])
  await page.screenshot({ path: 'test-results/screen-smoke.png', fullPage: true })
})
