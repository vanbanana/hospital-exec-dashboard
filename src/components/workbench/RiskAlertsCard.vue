<template>
  <div class="risk-card">
    <div class="card-header">
      <h3 class="card-title">风险预警</h3>
      <router-link to="/workbench/quality" class="more-link">更多 &gt;</router-link>
    </div>

    <WbErrorPanel v-if="error && data === null" :error="error" :loading="loading" @retry="reload" />
    <WbSkeleton v-else-if="data === null && loading" :rows="5" />
    <WbEmpty v-else-if="!items.length" text="暂无预警" />
    <div v-else class="risk-list">
      <WbStaleTag v-if="stale" :loading="loading" @retry="reload" />
      <div v-for="item in items" :key="item.id" class="risk-entry">
        <div class="risk-item">
          <span
            class="level-badge"
            :style="{ backgroundColor: LEVEL_STYLE[item.level].bg, color: LEVEL_STYLE[item.level].fg }"
          >
            {{ levelLabel[item.level] }}
          </span>
          <span class="risk-text" :title="item.title">{{ item.title }}</span>
          <span class="risk-date wb-num">{{ item.occurred_at }}</span>
          <span class="risk-ops">
            <template v-if="!isProcessing(item)">
              <button class="op-link" :disabled="acting.has(item.id)" @click="onAck(item)">认领</button>
            </template>
            <span v-else class="acked-tag">已认领</span>
            <button class="op-link" @click="openDispatch(item)">派发</button>
            <button class="op-link" @click="toggleClose(item)">关闭</button>
          </span>
        </div>
        <!-- R06 行内关闭小结区(不新开弹层) -->
        <div v-if="closeForId === item.id" class="close-panel">
          <textarea
            v-model="closeNote"
            class="wb-select close-input"
            rows="2"
            placeholder="办结理由 / 改善说明（必填）"
          ></textarea>
          <div class="close-foot">
            <span v-if="closeErr" class="field-err">{{ closeErr }}</span>
            <span class="close-btns">
              <button class="op-link" @click="closeForId = null">取消</button>
              <button class="mini-btn" :disabled="acting.has(item.id)" @click="submitClose(item)">
                确认关闭
              </button>
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- R05 督办派发弹层 -->
    <Teleport to="body">
      <div v-if="dispatchFor" class="dsp-overlay" @click.self="dispatchFor = null">
        <div class="dsp-panel" role="dialog">
          <div class="dsp-title">督办派发 · {{ dispatchFor.title }}</div>
          <div v-if="dspBanner" class="dsp-banner">{{ dspBanner }}</div>
          <div class="dsp-field">
            <label class="dsp-label">承办人 <span class="req">*</span></label>
            <select v-model="dspForm.assignee_id" class="wb-select dsp-input">
              <option :value="null" disabled>请选择承办人</option>
              <option v-for="s in staff" :key="s.id" :value="s.id">
                {{ s.name }} · {{ s.title }} · {{ s.dept_name }}{{ s.is_leader ? '（负责人）' : '' }}
              </option>
            </select>
            <div v-if="dspErr.assignee_id" class="field-err">{{ dspErr.assignee_id }}</div>
          </div>
          <div class="dsp-field">
            <label class="dsp-label">截止时间 <span class="req">*</span></label>
            <input v-model="dspForm.deadline" type="datetime-local" class="wb-select dsp-input" />
            <div v-if="dspErr.deadline" class="field-err">{{ dspErr.deadline }}</div>
          </div>
          <div class="dsp-field">
            <label class="dsp-label">工单标题</label>
            <input v-model="dspForm.title" class="wb-select dsp-input" :placeholder="dispatchFor.title" />
          </div>
          <div class="dsp-field">
            <label class="dsp-label">备注</label>
            <textarea v-model="dspForm.note" class="wb-select dsp-input" rows="2"></textarea>
          </div>
          <div class="dsp-foot">
            <button class="op-link" @click="dispatchFor = null">取消</button>
            <button class="mini-btn" :disabled="dspSubmitting" @click="submitDispatch">
              {{ dspSubmitting ? '提交中…' : '派发督办' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>
    <WbToast />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, reactive, ref, watch } from 'vue'
import { getHomeAlerts } from '../../api/workbench'
import { ackAlert, closeAlert, dispatchAlert, getStaff } from '../../api/alertflow'
import { useAsyncData } from '../../api/useAsyncData'
import WbSkeleton from './WbSkeleton.vue'
import WbErrorPanel from './WbErrorPanel.vue'
import WbEmpty from './WbEmpty.vue'
import WbStaleTag from './WbStaleTag.vue'
import WbToast, { toast } from './WbToast.vue'
import type { AlertLevel, HomeAlertItem, StaffItem } from '../../api/types'

// 五态取数经 useAsyncData（frontend-architecture §10.1）
const { data, loading, error, stale, reload } = useAsyncData(getHomeAlerts)

const items = computed(() => data.value?.list ?? [])

// §3.6 演进后出参带 alert_status——processing 态以字段为准;processingIds 只补
// 本会话内刚写入未 reload 的窗口(认领/派发成功或 33002 回传 current_status 时写入)
const processingIds = reactive(new Set<number>())
const isProcessing = (item: HomeAlertItem) =>
  item.alert_status === 'processing' || processingIds.has(item.id)
const acting = reactive(new Set<number>()) // 行级防连点

interface WriteErr {
  code?: number
  message: string
  fields?: Record<string, string>
}
const errInfo = (e: unknown) => e as WriteErr

// 契约告警级别为英文枚举 urgent|major|minor（api-contract §1.4-2）：
// 中文仅作文案;配色按枚举挂 --wb-tag-*-bg / --wb-* 语义 token,文案不充当选择器
const levelLabel: Record<AlertLevel, string> = {
  urgent: '高',
  major: '中',
  minor: '低',
}
const LEVEL_STYLE: Record<AlertLevel, { bg: string; fg: string }> = {
  urgent: { bg: 'var(--wb-tag-red-bg)', fg: 'var(--wb-red)' },
  major: { bg: 'var(--wb-tag-amber-bg)', fg: 'var(--wb-amber)' },
  minor: { bg: 'var(--wb-tag-teal-bg)', fg: 'var(--wb-teal)' },
}

/* ===== R04 认领 ===== */
async function onAck(item: HomeAlertItem) {
  if (acting.has(item.id)) return
  acting.add(item.id)
  try {
    await ackAlert(item.id)
    processingIds.add(item.id)
    toast.success('已认领')
    reload()
  } catch (e) {
    const err = errInfo(e)
    if (err.code === 33002) {
      // 已非 pending(如他人先认领)→ 按 §8.4.6 冲突类:警告 + 局部刷新
      processingIds.add(item.id)
      toast.warning(err.message)
      reload()
    } else {
      toast.error(err.message)
    }
  } finally {
    acting.delete(item.id)
  }
}

/* ===== R05 派发弹层 ===== */
const dispatchFor = ref<HomeAlertItem | null>(null)
const dspSubmitting = ref(false)
const dspBanner = ref('')
const dspErr = reactive<Record<string, string>>({})
const dspForm = reactive({ assignee_id: null as number | null, deadline: '', title: '', note: '' })
const staff = ref<StaffItem[]>([])

function openDispatch(item: HomeAlertItem) {
  dispatchFor.value = item
  dspBanner.value = ''
  for (const k of Object.keys(dspErr)) delete dspErr[k]
  dspForm.assignee_id = null
  dspForm.deadline = ''
  dspForm.title = ''
  dspForm.note = ''
}

async function submitDispatch() {
  const alert = dispatchFor.value
  if (!alert || dspSubmitting.value) return
  for (const k of Object.keys(dspErr)) delete dspErr[k]
  dspBanner.value = ''
  if (dspForm.assignee_id === null || !dspForm.deadline) {
    if (dspForm.assignee_id === null) dspErr.assignee_id = '请选择承办人'
    if (!dspForm.deadline) dspErr.deadline = '请选择截止时间'
    return
  }
  dspSubmitting.value = true
  try {
    await dispatchAlert(alert.id, {
      assignee_id: dspForm.assignee_id,
      deadline: new Date(dspForm.deadline).toISOString(),
      title: dspForm.title.trim() || undefined,
      note: dspForm.note.trim() || undefined,
    })
    processingIds.add(alert.id)
    toast.success('已派发')
    dispatchFor.value = null
    reload()
  } catch (e) {
    const err = errInfo(e)
    if (err.code === 10002 && err.fields) {
      // 表单内联错(error-codes §4):逐字段红标,不弹全局消息
      for (const [k, v] of Object.entries(err.fields)) dspErr[k] = v
    } else {
      if (err.code === 33002) {
        processingIds.add(alert.id)
        reload()
        dspBanner.value = err.message
        toast.warning(err.message)
      } else {
        // error-codes §4:33002 状态冲突走 warning,其余(33001/33102/33103/10000)走 error
        dspBanner.value = err.message
        toast.error(err.message)
      }
    }
  } finally {
    dspSubmitting.value = false
  }
}

function onEsc(e: KeyboardEvent) {
  if (e.key === 'Escape') dispatchFor.value = null
}
watch(dispatchFor, (v) => {
  if (v) window.addEventListener('keydown', onEsc)
  else window.removeEventListener('keydown', onEsc)
})

/* ===== R06 行内关闭 ===== */
const closeForId = ref<number | null>(null)
const closeNote = ref('')
const closeErr = ref('')

function toggleClose(item: HomeAlertItem) {
  if (closeForId.value === item.id) {
    closeForId.value = null
    return
  }
  closeForId.value = item.id
  closeNote.value = ''
  closeErr.value = ''
}

async function submitClose(item: HomeAlertItem) {
  if (!closeNote.value.trim()) {
    closeErr.value = '办结理由不能为空'
    return
  }
  if (acting.has(item.id)) return
  acting.add(item.id)
  try {
    await closeAlert(item.id, closeNote.value.trim())
    toast.success('已关闭')
    closeForId.value = null
    reload()
  } catch (e) {
    const err = errInfo(e)
    if (err.code === 10002 && err.fields?.close_note) {
      closeErr.value = err.fields.close_note
    } else if (err.code === 33002) {
      toast.warning(err.message)
      reload()
    } else {
      toast.error(err.message)
    }
  } finally {
    acting.delete(item.id)
  }
}

onMounted(() => {
  reload()
  // 承办人联想名单预取(§15.6;失败不阻塞卡片,弹层内 select 落空)
  getStaff()
    .then((r) => (staff.value = r.list))
    .catch(() => {})
})
onUnmounted(() => window.removeEventListener('keydown', onEsc))
</script>

<style scoped>
.risk-card {
  height: 100%;
  box-sizing: border-box;
  background: var(--wb-surface);
  border-radius: var(--wb-radius-card);
  border: 1px solid var(--wb-border);
  box-shadow: var(--wb-shadow-card);
  padding: var(--wb-pad-y) var(--wb-pad-x) var(--wb-space-2);
  display: flex;
  flex-direction: column;
  user-select: none;
  min-width: 0;
}

.card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: var(--wb-space-2);
}

.card-title {
  font-size: var(--wb-fs-lg);
  font-weight: var(--wb-fw-bold);
  color: var(--wb-navy);
  margin: 0;
  letter-spacing: var(--wb-ls-md);
}

.more-link {
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-3);
  text-decoration: none;
  transition: color var(--wb-dur-fast);
}

.more-link:hover {
  color: var(--wb-primary);
}

.risk-list {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  flex: 1;
}

.risk-entry {
  min-width: 0;
}

.risk-item {
  display: flex;
  align-items: center;
  gap: var(--wb-space-2);
  padding: var(--wb-space-1) 0;
}

.level-badge {
  font-size: var(--wb-fs-xs);
  font-weight: var(--wb-fw-semibold);
  width: 20px;
  padding: var(--wb-space-1) 0;
  border-radius: var(--wb-radius-tag);
  flex-shrink: 0;
  text-align: center;
  line-height: var(--wb-lh-mid);
}

.risk-text {
  flex: 1;
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-1);
  font-weight: var(--wb-fw-medium);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.risk-date {
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-3);
  flex-shrink: 0;
}

/* 行尾操作区:文字链,不挤压标题(标题侧 flex:1+ellipsis 已保证) */
.risk-ops {
  display: flex;
  align-items: center;
  gap: var(--wb-space-2);
  flex-shrink: 0;
}

.op-link {
  background: none;
  border: none;
  padding: 0;
  font-size: var(--wb-fs-xs);
  color: var(--wb-text-3);
  cursor: pointer;
  font-family: inherit;
  transition: color var(--wb-dur-fast);
}

.op-link:hover:not(:disabled) {
  color: var(--wb-primary);
}

.op-link:disabled {
  cursor: default;
  opacity: var(--wb-opacity-dimmed);
}

.acked-tag {
  font-size: var(--wb-fs-xs);
  color: var(--wb-text-4);
}

/* R06 行内关闭区:hairline 顶边分区,不套卡片 */
.close-panel {
  border-top: 1px solid var(--wb-hairline);
  padding: var(--wb-space-2) 0 var(--wb-space-1);
}

.close-input {
  width: 100%;
  box-sizing: border-box;
  resize: vertical;
}

.close-foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: var(--wb-space-1);
  min-height: 22px;
}

.close-btns {
  display: flex;
  align-items: center;
  gap: var(--wb-space-2);
  margin-left: auto;
}

.field-err {
  font-size: var(--wb-fs-xs);
  color: var(--wb-red);
}

.mini-btn {
  background: var(--wb-accent);
  color: var(--p-white);
  border: none;
  border-radius: var(--wb-radius-inner);
  font-size: var(--wb-fs-xs);
  font-family: inherit;
  padding: var(--wb-space-1) var(--wb-space-3);
  cursor: pointer;
  transition: opacity var(--wb-dur-fast);
}

.mini-btn:disabled {
  cursor: default;
  opacity: var(--wb-opacity-dimmed);
}

/* R05 派发弹层:遮罩色无 token,取 --p-slate-800 原色相对色配方近似 rgba(15,23,42,.32) */
.dsp-overlay {
  position: fixed;
  inset: 0;
  background: rgb(from var(--p-slate-800) r g b / 32%);
  /* 盖过 sticky 页头:无 overlay 层 token,取 --wb-z-sticky 上浮一层 */
  z-index: calc(var(--wb-z-sticky) + 1);
  display: flex;
  align-items: center;
  justify-content: center;
}

.dsp-panel {
  width: 400px;
  max-width: calc(100vw - 48px);
  background: var(--wb-surface);
  border: 1px solid var(--wb-border);
  border-radius: var(--wb-radius-card);
  box-shadow: var(--wb-shadow-card);
  padding: var(--wb-pad-y) var(--wb-pad-x);
}

.dsp-title {
  font-size: var(--wb-fs-lg);
  font-weight: var(--wb-fw-bold);
  color: var(--wb-navy);
  letter-spacing: var(--wb-ls-md);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  margin-bottom: var(--wb-space-3);
}

.dsp-banner {
  font-size: var(--wb-fs-sm);
  color: var(--wb-amber);
  padding-bottom: var(--wb-space-2);
}

.dsp-field {
  margin-bottom: var(--wb-space-3);
}

.dsp-field:last-of-type {
  margin-bottom: var(--wb-space-2);
}

.dsp-label {
  display: block;
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-2);
  font-weight: var(--wb-fw-medium);
  margin-bottom: var(--wb-space-1);
}

.req {
  color: var(--wb-red);
}

.dsp-input {
  width: 100%;
  box-sizing: border-box;
  resize: vertical;
}

.dsp-field .field-err {
  margin-top: var(--wb-space-1);
}

.dsp-foot {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: var(--wb-space-3);
  border-top: 1px solid var(--wb-hairline);
  padding-top: var(--wb-space-3);
}
</style>
