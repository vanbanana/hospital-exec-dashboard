import { defineConfig } from 'vitest/config'
import vue from '@vitejs/plugin-vue'
import { fileURLToPath } from 'node:url'

// 单测配置与 vite.config.ts 解耦：dev server 的 proxy/host 与测试无关，只共享 vue 插件与 @ alias
export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  test: {
    environment: 'jsdom',
    // e2e spec 由 playwright 独立跑（tests/e2e），vitest 只收 tests/unit
    include: ['tests/unit/**/*.spec.ts'],
  },
})
