// 业务基准日 composable — 契约 §2.1 system_date 是全站唯一业务日期源
import { ref } from 'vue'
import { getAuthProfile } from './auth'

// 演示基准日兜底(api-contract §14.1 注1 BASE_DATE);profile 到位即覆盖
const systemDate = ref('2026-10-28')
let booted = false

/** 9 视图页头 + 其他消费位共享同一 Promise,不重复请求 */
export function useSystemDate() {
  if (!booted) {
    booted = true
    void getAuthProfile()
      .then((p) => {
        systemDate.value = p.system_date
      })
      .catch(() => {
        /* chrome 级装饰位:失败保持基准日兜底,不进反馈矩阵 */
      })
  }
  return systemDate
}
