<template>
  <div class="notices-card">
    <div class="card-header">
      <h3 class="card-title">通知与待办</h3>
      <div class="head-ops">
        <WbSeg v-model="seg" :options="['通知', '督办工单']" />
        <router-link to="/workbench/overview" class="more-link">更多 &gt;</router-link>
      </div>
    </div>

    <WbErrorPanel v-if="cur.error && cur.data === null" :error="cur.error" :loading="cur.loading" @retry="cur.reload" />
    <WbSkeleton v-else-if="cur.data === null && cur.loading" :rows="5" />
    <WbEmpty v-else-if="!rowCount" :text="seg === '通知' ? '暂无通知与待办' : '暂无督办工单'" />
    <div v-else class="notices-list">
      <WbStaleTag v-if="cur.stale" :loading="cur.loading" @retry="cur.reload" />
      <!-- 通知态 -->
      <template v-if="seg === '通知'">
        <div v-for="item in noticeItems" :key="item.id" class="notice-item">
          <span class="notice-dot" :class="item.urgent ? 'dot-urgent' : 'dot-normal'"></span>
          <span class="notice-text">{{ item.text }}</span>
          <span class="notice-date wb-num">{{ item.date }}</span>
        </div>
      </template>
      <!-- 督办工单态(§15.4 R07) -->
      <template v-else>
        <div v-for="t in todoItems" :key="t.id" class="todo-entry">
          <div class="notice-item">
            <span class="todo-title" :title="t.title">{{ t.title }}</span>
            <span class="todo-assignee">{{ t.assignee_name }}</span>
            <span class="notice-date wb-num">{{ t.deadline }}</span>
            <span class="wb-tag todo-tag" :class="TAG_CLS[t.todo_status]">{{ t.status_label }}</span>
            <span class="todo-ops">
              <button
                v-if="t.todo_status === 'open'"
                class="op-link"
                :disabled="acting.has(t.id)"
                @click="onAccept(t)"
              >
                接单
              </button>
              <button
                v-else-if="t.todo_status === 'doing'"
                class="op-link"
                @click="toggleReport(t)"
              >
                办结
              </button>
            </span>
          </div>
          <!-- R08 report 行内办结区 -->
          <div v-if="reportForId === t.id" class="report-panel">
            <textarea
              v-model="reportNote"
              class="wb-select report-input"
              rows="2"
              placeholder="整改举措 / 办结说明（必填）"
            ></textarea>
            <div class="report-foot">
              <span v-if="reportErr" class="field-err">{{ reportErr }}</span>
              <span class="report-btns">
                <button class="op-link" @click="reportForId = null">取消</button>
                <button class="mini-btn" :disabled="acting.has(t.id)" @click="submitReport(t)">
                  提交办结
                </button>
              </span>
            </div>
          </div>
        </div>
      </template>
    </div>
    <WbToast />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { getHomeNotices } from '../../api/workbench'
import { getTodos, setTodoStatus } from '../../api/alertflow'
import { useAsyncData } from '../../api/useAsyncData'
import WbSkeleton from './WbSkeleton.vue'
import WbErrorPanel from './WbErrorPanel.vue'
import WbEmpty from './WbEmpty.vue'
import WbStaleTag from './WbStaleTag.vue'
import WbSeg from './WbSeg.vue'
import WbToast, { toast } from './WbToast.vue'
import type { TodoItem, TodoStatus } from '../../api/types'

// 通知/督办双数据源(§8.4.3 写后读=各自 reload;两套五态互不影响,回切不重取)
const seg = ref('通知')
const {
  data: noticesData,
  loading: noticesLoading,
  error: noticesErr,
  stale: noticesStale,
  reload: noticesReload,
} = useAsyncData(getHomeNotices)
const {
  data: todosData,
  loading: todosLoading,
  error: todosErr,
  stale: todosStale,
  reload: todosReload,
} = useAsyncData(() => getTodos({ size: 6 }))
onMounted(() => {
  noticesReload()
  todosReload()
})
// 切回督办 seg 重取——派发/办结后跨段可见(EW 终审问题2:同页演示断点)
watch(seg, (v) => {
  if (v === '督办工单') todosReload()
})

const cur = computed(() =>
  seg.value === '通知'
    ? { data: noticesData.value, loading: noticesLoading.value, error: noticesErr.value, stale: noticesStale.value, reload: noticesReload }
    : { data: todosData.value, loading: todosLoading.value, error: todosErr.value, stale: todosStale.value, reload: todosReload },
)

const noticeItems = computed(() => noticesData.value?.list ?? [])
const todoItems = computed(() => todosData.value?.list ?? [])
const rowCount = computed(() => (seg.value === '通知' ? noticeItems.value.length : todoItems.value.length))

// 工单状态 tag 色:open→amber,doing→teal,done→灰弱化,expired→red(任务书指定 token 映射)
const TAG_CLS: Record<TodoStatus, string> = {
  open: 'is-amber',
  doing: 'tag-teal',
  done: 'tag-dim',
  expired: 'is-red',
}

interface WriteErr {
  code?: number
  message: string
  fields?: Record<string, string>
}
const errInfo = (e: unknown) => e as WriteErr

const acting = reactive(new Set<number>()) // 行级防连点
const reportForId = ref<number | null>(null)
const reportNote = ref('')
const reportErr = ref('')

/* ===== R08 接单(open→doing) ===== */
async function onAccept(t: TodoItem) {
  if (acting.has(t.id)) return
  acting.add(t.id)
  try {
    await setTodoStatus(t.id, { action: 'accept' })
    toast.success('已接单')
    todosReload()
  } catch (e) {
    const err = errInfo(e)
    if (err.code === 33104) {
      // 冲突类(§8.4.6):警告 + 局部刷新
      toast.warning(err.message)
      todosReload()
    } else {
      toast.error(err.message)
    }
  } finally {
    acting.delete(t.id)
  }
}

/* ===== R08 办结(doing→done,同事务回填告警 done) ===== */
function toggleReport(t: TodoItem) {
  if (reportForId.value === t.id) {
    reportForId.value = null
    return
  }
  reportForId.value = t.id
  reportNote.value = ''
  reportErr.value = ''
}

async function submitReport(t: TodoItem) {
  if (!reportNote.value.trim()) {
    reportErr.value = '办结说明不能为空'
    return
  }
  if (acting.has(t.id)) return
  acting.add(t.id)
  try {
    await setTodoStatus(t.id, { action: 'report', result_note: reportNote.value.trim() })
    toast.success('已办结')
    reportForId.value = null
    todosReload()
  } catch (e) {
    const err = errInfo(e)
    if (err.code === 10002 && err.fields?.result_note) {
      reportErr.value = err.fields.result_note
    } else if (err.code === 33104) {
      toast.warning(err.message)
      todosReload()
    } else {
      toast.error(err.message)
    }
  } finally {
    acting.delete(t.id)
  }
}
</script>

<style scoped>
.notices-card {
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
  gap: var(--wb-space-2);
  margin-bottom: var(--wb-space-2);
}

.card-title {
  font-size: var(--wb-fs-lg);
  font-weight: var(--wb-fw-bold);
  color: var(--wb-navy);
  margin: 0;
  letter-spacing: var(--wb-ls-md);
  flex-shrink: 0;
}

.head-ops {
  display: flex;
  align-items: center;
  gap: var(--wb-space-2);
  min-width: 0;
}

.more-link {
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-3);
  text-decoration: none;
  transition: color var(--wb-dur-fast);
  flex-shrink: 0;
}

.more-link:hover {
  color: var(--wb-primary);
}

.notices-list {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  flex: 1;
}

.notice-item {
  display: flex;
  align-items: center;
  gap: var(--wb-space-2);
  padding: var(--wb-space-1) 0;
}

.notice-dot {
  width: 7px;
  height: 7px;
  border-radius: var(--wb-radius-pill);
  flex-shrink: 0;
}

.dot-urgent {
  background-color: var(--wb-red);
}

.dot-normal {
  background-color: var(--wb-text-4);
}

.notice-text {
  flex: 1;
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-1);
  font-weight: var(--wb-fw-medium);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.notice-date {
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-3);
  flex-shrink: 0;
}

/* 督办工单行 */
.todo-entry {
  min-width: 0;
}

.todo-title {
  flex: 1;
  min-width: 0;
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-1);
  font-weight: var(--wb-fw-medium);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.todo-assignee {
  font-size: var(--wb-fs-sm);
  color: var(--wb-text-3);
  flex-shrink: 0;
}

/* wb-tag 无 teal/弱化档,按任务书指定 token 就近映射 */
.todo-tag.tag-teal {
  background: var(--wb-tag-teal-bg);
  color: var(--wb-teal);
}

.todo-tag.tag-dim {
  background: var(--wb-tag-gray-bg);
  color: var(--wb-text-4);
}

.todo-ops {
  flex-shrink: 0;
  min-width: 24px;
  text-align: right;
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

/* R08 行内办结区:hairline 分区,不套卡片 */
.report-panel {
  border-top: 1px solid var(--wb-hairline);
  padding: var(--wb-space-2) 0 var(--wb-space-1);
}

.report-input {
  width: 100%;
  box-sizing: border-box;
  resize: vertical;
}

.report-foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: var(--wb-space-1);
  min-height: 22px;
}

.report-btns {
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
</style>
