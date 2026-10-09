import { expect, test } from '@playwright/test'

async function login(page: import('@playwright/test').Page) {
  await page.goto('/login')
  await page.fill('#login-username', 'president')
  await page.fill('#login-password', 'Edss@2026')
  await page.click('.login-btn')
  await page.waitForURL(/workbench/)
}

test('切换保留完整工作台路径，返回退出全屏', async ({ page }) => {
  await login(page)
  const original = '/workbench/operations?range=month#report'
  await page.goto(original)
  await page.getByRole('link', { name: '数据大屏' }).click()
  await expect(page).toHaveURL(new RegExp('/screen\\?returnTo='))
  expect(new URL(page.url()).searchParams.get('returnTo')).toBe(original)
  await expect(page.getByRole('link', { name: '返回工作台' })).toHaveAttribute('href', original)
  await page.getByTitle('全屏显示 / 退出全屏').click()
  await expect.poll(() => page.evaluate(() => !!document.fullscreenElement)).toBe(true)
  await page.getByRole('link', { name: '返回工作台' }).focus()
  await page.keyboard.press('Enter')
  expect(new URL(page.url()).pathname + new URL(page.url()).search + new URL(page.url()).hash).toBe(original)
  await expect.poll(() => page.evaluate(() => !!document.fullscreenElement)).toBe(false)
})

test('直接进入或非法返回地址回工作台，快照失败仍能返回', async ({ page }) => {
  await login(page)
  for (const query of ['', '?returnTo=https://example.com', '?returnTo=/workbench-other', '?returnTo=/workbench/tasks&returnTo=/workbench/hr', '?returnTo=/workbench/%5Cevil']) {
    await page.goto('/screen' + query)
    await expect(page.getByRole('link', { name: '返回工作台' })).toHaveAttribute('href', '/workbench')
  }
  await page.route('**/api/v1/screen/snapshot*', route => route.abort())
  await page.goto('/screen?returnTo=/workbench/operations')
  await expect(page.getByText('数据链路中断', { exact: true })).toBeVisible()
  await page.getByRole('link', { name: '返回工作台' }).click()
  await expect(page).toHaveURL(/workbench\/operations$/)
})

test('真实科室会话不显示院级大屏入口', async ({ page }) => {
  test.skip(process.env.EDSS_TEST_PRODUCTION !== '1', '需启用真实权限策略')
  await page.goto('/login')
  await page.fill('#login-username', 'dept_leader')
  await page.fill('#login-password', 'Edss@2026')
  await page.click('.login-btn')
  await page.waitForURL(/workbench\/tasks/)
  await expect(page.getByRole('link', { name: '数据大屏' })).toHaveCount(0)
})
