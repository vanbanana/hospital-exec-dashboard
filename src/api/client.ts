// 统一 mock 解析层 — api<T>(key, params) 从 src/mock/ 注册表取数（api-contract §16）
import { mockResolvers, type MockParams } from '../mock'

const MOCK_LATENCY_MS = 120

/**
 * 统一取数入口。key = 契约端点路径（如 'workbench/overview'）。
 * TODO(devin): VITE_USE_MOCK 开关位 —— 接 http 层后改为
 *   `import.meta.env.VITE_USE_MOCK !== '0' ? mockResolvers[key] : http.get(key, { params })`
 * 并在此拆 ApiEnvelope 包络、映射错误码（见 error-codes.md §4）。
 */
export async function api<T>(key: string, params: MockParams = {}): Promise<T> {
  const resolve = mockResolvers[key]
  if (!resolve) throw new Error(`[api] 未注册的端点: ${key}`)
  await new Promise((r) => setTimeout(r, MOCK_LATENCY_MS))
  // 深拷贝隔离 mock 模块单例，防止消费方原地修改污染后续请求
  return JSON.parse(JSON.stringify(resolve(params))) as T
}
