import { defineConfig, devices } from '@playwright/test'

// e2e 打真链路：webServer 起 npm run dev(:5173)，/api 经 vite proxy 落到已在跑的 Go 后端(:8080)
export default defineConfig({
  testDir: './tests/e2e',
  timeout: 30_000,
  retries: 0,
  reporter: 'list',
  use: {
    baseURL: 'http://localhost:5173',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:5173',
    // 开发机上 dev server 常已在跑，直接复用；CI 环境(F2)无驻留进程时自动拉起
    reuseExistingServer: true,
    timeout: 60_000,
  },
})
