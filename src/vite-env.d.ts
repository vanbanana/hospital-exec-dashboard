/// <reference types="vite/client" />

interface ImportMetaEnv {
  // 无应用级 env:数据一律经 vite proxy / nginx 打真后端 /api/v1(单轨)
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
