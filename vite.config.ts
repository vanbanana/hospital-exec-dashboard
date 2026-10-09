import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { fileURLToPath } from 'node:url'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  },
  server: {
    port: 5173,
    host: '127.0.0.1',
    strictPort: true,
    proxy: {
      // dev 期同源代理打 Go 后端(包络拆解见 client.ts);生产由 nginx 同路径反代
      '/api': { target: 'http://localhost:8080', changeOrigin: true }
    }
  }
})
