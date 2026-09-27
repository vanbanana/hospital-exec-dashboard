import { createApp } from 'vue'
import './styles/index.css'
import './styles/workbench.css'
import App from './App.vue'
import router from './router'

const app = createApp(App)

// 全局兜底（frontend-architecture §10）：组件树内未捕获错误与逃逸的
// Promise rejection 统一留痕——不吞错、不阻断页面（防白屏裸崩）
app.config.errorHandler = (err, _instance, info) => {
  console.error(`[app] errorHandler(${info}):`, err)
}
window.addEventListener('unhandledrejection', (e) => {
  console.error('[app] unhandledrejection:', e.reason)
  e.preventDefault()
})

app.use(router)
app.mount('#app')
