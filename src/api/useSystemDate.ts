// 业务基准日 composable — 契约 §2.1 system_date 是全站唯一业务日期源
import { ref, watch } from 'vue'
import { currentProfile, profileState } from './session'

// 唯一事实源 = profile.system_date(后端时钟推出);profile 未到位前为空串——
// 不预填演示日期:空数据期页头显示"数据截至 ",好过闪现一个不存在的基准日
const systemDate = ref('')
let booted = false
watch(profileState, p => { systemDate.value = p?.system_date ?? '' }, { immediate: true })

/** 9 视图页头 + 其他消费位共享同一 Promise;经 currentProfile 会话缓存,不与 Header/守卫重复拉取 */
export function useSystemDate() {
  if (!booted) {
    booted = true
    void currentProfile()
      .catch(() => {
        booted = false
        /* chrome 级装饰位:失败保持空串(守卫已把未登录者挡在 /login),不进反馈矩阵 */
      })
  }
  return systemDate
}
