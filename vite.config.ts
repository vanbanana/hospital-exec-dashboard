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
      // VITE_USE_MOCK=0 时经同源代理打 Go 后端(E5 接线;包络拆解见 client.ts)
      '/api': { target: 'http://localhost:8080', changeOrigin: true }
    }
  }
})
