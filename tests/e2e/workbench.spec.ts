import { expect, test } from '@playwright/test'

// e2e 主链路：登录 → 工作台 KPI → 告警派发弹层 → /screen KPI+pin
// 真链路打 Go 后端（vite proxy :5173 → :8080），演示账号 president/Edss@2026（backend/README 演示账号表）

test('登录 → 工作台 KPI 非空 → 派发弹层可见', async ({ page }) => {
  await page.goto('/workbench')
  // §3.1 守卫：未登录跳 /login?redirect=/workbench
  await page.waitForURL(/\/login/)

  await page.fill('#login-username', 'president')
  await page.fill('#login-password', 'Edss@2026')
  await page.click('.login-btn')

  await page.waitForURL(/\/workbench/)

  // 首页 KPI 卡：契约 §3 真数据非空
  const kpiNumbers = page.locator('.kpi-card .kpi-number')
  await expect(kpiNumbers.first()).toBeVisible()
  expect(await kpiNumbers.count()).toBeGreaterThan(0)
  expect((await kpiNumbers.first().innerText()).trim()).not.toBe('')

  // R05 派发弹层（RiskAlertsCard → Teleport .dsp-overlay）
  await page.locator('.risk-ops .op-link', { hasText: '派发' }).first().click()
  await expect(page.locator('.dsp-overlay')).toBeVisible()
  await expect(page.locator('.dsp-panel')).toBeVisible()
  await expect(page.locator('.dsp-title')).toContainText('督办派发')
})

test('/screen KPI 条与院区 pin 渲染', async ({ page }) => {
  await page.goto('/screen')
  // §14 屏顶 KPI 浮条（契约 §14.1 注6：value 恒等于 spark 末点）
  const kpiItems = page.locator('.hero-ribbon .hero-item')
  await expect(kpiItems.first()).toBeVisible()
  expect(await kpiItems.count()).toBeGreaterThan(0)
  expect((await kpiItems.first().locator('.hero-value').innerText()).trim()).not.toBe('')

  // 院区图楼宇 pin（§14.1 注7 anchor 坐标系）
  expect(await page.locator('.campus-pin').count()).toBeGreaterThan(0)
})
