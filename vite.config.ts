import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'path'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src')
    }
  },
  server: {
    port: 5173,
    host: '0.0.0.0',
    proxy: {
      // dev 期同源代理打 Go 后端(包络拆解见 client.ts);生产由 nginx 同路径反代
      '/api': { target: 'http://localhost:8080', changeOrigin: true }
    }
  }
})
