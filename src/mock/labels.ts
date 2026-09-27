// 契约 §1.3-3 delta_label:stat 项变动口径文案,随 range 联动(本月→较上月/本季→较上季/本年→较去年)
import type { RangeKey } from '../api/types'

export const DELTA_LABEL: Record<RangeKey, string> = {
  本月: '较上月',
  本季: '较上季',
  本年: '较去年',
}
