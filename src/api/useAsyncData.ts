// 取数五态封装 — frontend-architecture §10.1 唯一状态源（loading/error/empty/stale/retry）
// 视图/卡片只声明 fetcher 与触发点（onMounted/watch/重试按钮），状态切换全部由本模块收口
import { ref, type Ref } from 'vue'

/**
 * 统一错误形状 — 对齐 error-codes §1 失败包络（code/message/trace_id）。
 * mock 期由 toApiError 归一化产出；接 http 层后由响应拦截器按 §4 矩阵产出同一形状。
 */
export class ApiError extends Error {
  readonly code: number
  readonly trace_id: string

  constructor(code: number, message: string, trace_id = '') {
    super(message)
    this.name = 'ApiError'
    this.code = code
    this.trace_id = trace_id
  }
}

// mock 期无服务端 trace_id —— 本地递增序号替代，local- 前缀标明非服务端来源
let localTraceSeq = 0

export function toApiError(err: unknown): ApiError {
  if (err instanceof ApiError) return err
  const message = err instanceof Error ? err.message : String(err)
  // 10000 = 通用"系统繁忙"兜底（error-codes §3 通用段）
  return new ApiError(10000, message || '系统繁忙，请稍后重试', `local-${++localTraceSeq}`)
}

export interface AsyncData<T> {
  /** 最近一次成功负载；null = 从未成功（首载中 / 失败 / code=31004 空态） */
  data: Ref<T | null>
  /** 请求在途 */
  loading: Ref<boolean>
  /** 最近一次失败错误；成功后清空 */
  error: Ref<ApiError | null>
  /** 刷新失败但旧数据仍在展示（§10.1 stale 态） */
  stale: Ref<boolean>
  /** 重发同一请求 — onMounted/watch/重试按钮共用入口；内部全捕获，永不 reject */
  reload: () => Promise<void>
}

export function useAsyncData<T>(fetcher: () => Promise<T>): AsyncData<T> {
  const data = ref(null) as Ref<T | null>
  const loading = ref(false)
  const error = ref<ApiError | null>(null)
  const stale = ref(false)
  // 序号闸：并发重取仅最后一次允许写态（连续切换筛选不串档）
  let seq = 0

  const reload = async () => {
    const id = ++seq
    loading.value = true
    try {
      const d = await fetcher()
      if (id !== seq) return
      data.value = d
      error.value = null
      stale.value = false
    } catch (err) {
      if (id !== seq) return
      error.value = toApiError(err)
      stale.value = data.value !== null
      console.error(
        `[useAsyncData] ${error.value.message} (code=${error.value.code}, trace_id=${error.value.trace_id})`,
      )
    } finally {
      if (id === seq) loading.value = false
    }
  }

  return { data, loading, error, stale, reload }
}
