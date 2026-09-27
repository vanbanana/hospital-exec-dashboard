/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** 默认 mock 数据源；置 '0' 经 vite proxy 打 Go 后端 /api/v1（契约 §16 切换位） */
  readonly VITE_USE_MOCK?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
