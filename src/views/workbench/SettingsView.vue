<template>
  <div class="wb-page">
    <p>当前数据源状态来自演示配置，尚未连接医院实时系统。</p>
    <WbPageHead title="系统设置" sub="数据源 · 预警阈值 · 用户权限 · 偏好">
      <WbStaleTag v-if="stale" :loading="loading" @retry="reload" />
    </WbPageHead>

    <!-- 五态门：data 未落地时面板级 loading/error/empty（§10.1） -->
    <div v-if="data === null" class="wb-panel">
      <div class="wb-panel-body">
        <WbErrorPanel v-if="error" :error="error" :loading="loading" @retry="reload" />
        <WbSkeleton v-else-if="loading" :rows="8" />
        <WbEmpty v-else text="暂无设置数据" />
      </div>
    </div>
    <div v-else class="wb-grid wb-grid-2">
      <!-- 左列 -->
      <div class="settings-col">
        <div class="wb-panel">
          <div class="wb-panel-head">
            <h3 class="wb-panel-title">数据源管理</h3>
            <span class="wb-panel-sub">HIS / EMR / 业务系统对接</span>
          </div>
          <div class="wb-panel-body">
            <WbTable :columns="dsCols" :rows="dsRows" row-key="name">
              <template #cell-status="{ value }">
                <span class="wb-tag" :class="value === '已连接' ? 'is-green' : 'is-red'">
                  {{ value }}
                </span>
              </template>
            </WbTable>
          </div>
        </div>

        <div class="wb-panel">
          <div class="wb-panel-head">
            <h3 class="wb-panel-title">指标预警阈值</h3>
            <span class="wb-panel-sub">超过阈值触发首页风险预警</span>
          </div>
          <div class="wb-panel-body">
            <WbTable :columns="thCols" :rows="thRows" row-key="name">
              <template #cell-level="{ value }">
                <span>{{ levelText[String(value)] ?? value }}</span>
              </template>
              <template #cell-enabled="{ row }">
                <button
                  class="wb-switch"
                  :class="{ on: row.enabled }"
                  @click="toggleRule(row)"
                ></button>
              </template>
            </WbTable>
          </div>
        </div>
      </div>

      <!-- 右列 -->
      <div class="settings-col">
        <div class="wb-panel">
          <div class="wb-panel-head">
            <h3 class="wb-panel-title">用户与权限</h3>
            <span class="wb-panel-sub">决策支持系统账号</span>
          </div>
          <div class="wb-panel-body">
            <WbTable :columns="userCols" :rows="userRows" row-key="name">
              <template #cell-role="{ value }">
                <span
                  class="wb-tag"
                  :class="value === '管理员' ? 'is-red' : value === '院领导' ? 'is-blue' : 'is-gray'"
                >{{ value }}</span>
              </template>
              <template #cell-status="{ value }">
                <span class="wb-tag" :class="value === '启用' ? 'is-green' : 'is-gray'">{{ value }}</span>
              </template>
            </WbTable>
          </div>
        </div>

        <div class="wb-panel">
          <div class="wb-panel-head">
            <h3 class="wb-panel-title">系统偏好</h3>
          </div>
          <div class="wb-panel-body">
            <WbPreferences />
          </div>
        </div>
      </div>
    </div>
    <WbToast />
  </div>
</template>

<script setup lang="ts">
import WbPreferences from '../../components/workbench/WbPreferences.vue'
import { reactive, computed, onMounted } from 'vue'
import WbPageHead from '../../components/workbench/WbPageHead.vue'
import WbTable, { type WbTableColumn } from '../../components/workbench/WbTable.vue'
import WbSkeleton from '../../components/workbench/WbSkeleton.vue'
import WbErrorPanel from '../../components/workbench/WbErrorPanel.vue'
import WbEmpty from '../../components/workbench/WbEmpty.vue'
import WbStaleTag from '../../components/workbench/WbStaleTag.vue'
import WbToast, { toast } from '../../components/workbench/WbToast.vue'
import { getSettings } from '../../api/workbench'
import { setRuleEnabled } from '../../api/settings'
import { useAsyncData } from '../../api/useAsyncData'

// §13.2 三个列表非 WbTableData 形状（契约未下发 columns），列定义留本地
const dsCols: WbTableColumn[] = [
  { key: 'name', title: '数据源' },
  { key: 'type', title: '类型' },
  { key: 'status', title: '状态', align: 'center' },
  { key: 'sync', title: '最近同步', align: 'right', num: true },
]

const thCols: WbTableColumn[] = [
  { key: 'name', title: '指标' },
  { key: 'rule', title: '触发条件' },
  { key: 'level', title: '级别', align: 'center' },
  { key: 'enabled', title: '启用', align: 'center' },
]

const userCols: WbTableColumn[] = [
  { key: 'name', title: '姓名' },
  { key: 'role', title: '角色', align: 'center' },
  { key: 'scope', title: '数据范围' },
  { key: 'login', title: '最近登录', align: 'right', num: true },
  { key: 'status', title: '状态', align: 'center' },
]

// thresholds.level 为契约英文枚举（§13.2 注1），界面沿用中文档级文案
const levelText: Record<string, string> = { urgent: '高', major: '中', minor: '低' }

// 五态取数经 useAsyncData（frontend-architecture §10.1）
const { data, loading, error, stale, reload } = useAsyncData(getSettings)
onMounted(reload)

const dsRows = computed(() => data.value?.data_sources ?? [])
const thRows = computed(() => data.value?.thresholds ?? [])
const userRows = computed(() => data.value?.users ?? [])

interface WriteErr {
  code?: number
  message: string
}
const errInfo = (e: unknown) => e as WriteErr

/* ===== R15 阈值启停:乐观翻转 → 写回 → 失败回滚(§15.7) ===== */
const pendingRules = reactive(new Set<string>())
async function toggleRule(row: Record<string, unknown>) {
  const code = String(row.code)
  if (pendingRules.has(code)) return
  const next = !row.enabled
  row.enabled = next
  pendingRules.add(code)
  try {
    await setRuleEnabled(code, next)
    toast.success('已更新')
  } catch (e) {
    row.enabled = !next
    toast.warning(errInfo(e).message)
  } finally {
    pendingRules.delete(code)
  }
}

</script>

<style scoped>
.settings-col {
  display: flex;
  flex-direction: column;
  gap: var(--wb-gap);
  min-width: 0;
}
</style>
