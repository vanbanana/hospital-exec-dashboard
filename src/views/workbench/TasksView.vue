<template>
  <div>
    <WbToast />
    <WbPageHead title="督办工单" sub="查看授权范围内的工单，接单并提交办结结果" />
    <label class="tasks-toolbar">状态 <select v-model="status" class="wb-select"><option value="">全部</option><option v-for="s in ['open','doing','done','expired']" :key="s" :value="s">{{ labels[s] }}</option></select></label>
    <WbErrorPanel v-if="error && !data" :error="error" :loading="loading" @retry="reload" />
    <WbStaleTag v-if="stale" :loading="loading" @retry="reload" />
    <WbSkeleton v-if="loading && !data" :rows="5" />
    <WbTable v-else :columns="columns" :rows="rows" row-key="id">
      <template #cell-action="{ row }">
        <button v-if="canWrite && row.todo_status === 'open'" class="task-button" :disabled="pending !== null" @click="transit(Number(row.id), 'accept')">接单</button>
        <button v-if="canWrite && row.todo_status === 'doing'" class="task-button" :disabled="pending !== null" @click="reportId = Number(row.id)">办结</button>
      </template>
    </WbTable>
    <p class="tasks-pagination">共 {{ data?.total ?? 0 }} 条 · 第 {{ page }} 页 <button class="task-button" :disabled="page === 1 || loading" @click="page--">上一页</button> <button class="task-button" :disabled="page * 20 >= (data?.total ?? 0) || loading" @click="page++">下一页</button></p>
    <form class="task-report" v-if="reportId !== null" @submit.prevent="transit(reportId!, 'report')">
      <label>办结结果 <textarea v-model="note" class="wb-select" required maxlength="2000" rows="4" /></label>
      <button class="task-button" :disabled="pending !== null || !note.trim()">提交办结</button>
      <button class="task-button" type="button" @click="reportId = null; note = ''">取消</button>
    </form>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, onMounted, watch } from 'vue'
import { api } from '../../api/client'
import { useAsyncData } from '../../api/useAsyncData'
import { profileState } from '../../api/session'
import WbPageHead from '../../components/workbench/WbPageHead.vue'
import WbSkeleton from '../../components/workbench/WbSkeleton.vue'
import WbTable from '../../components/workbench/WbTable.vue'
import WbErrorPanel from '../../components/workbench/WbErrorPanel.vue'
import WbStaleTag from '../../components/workbench/WbStaleTag.vue'
import WbToast, { toast } from '../../components/workbench/WbToast.vue'
import type { WbTableColumn } from '../../api/types'

interface TodoPage { list: Record<string, unknown>[]; total: number }
const page = ref(1), status = ref(''), note = ref('')
const pending = ref<number | null>(null), reportId = ref<number | null>(null)
const canWrite = computed(() => ['admin','president','ops_director','dept_leader'].includes(profileState.value?.user.role ?? ''))
const labels: Record<string,string> = { open:'待接单', doing:'办理中', done:'已办结', expired:'已逾期' }
const columns: WbTableColumn[] = [{key:'title',title:'工单'}, {key:'assignee_name',title:'承办人'}, {key:'dept_name',title:'科室'}, {key:'deadline',title:'截止时间'}, {key:'status_label',title:'状态'}, {key:'action',title:'操作'}]
const {data,error,loading,stale,reload} = useAsyncData(() => api<TodoPage>('todos', {page:String(page.value),size:'20',status:status.value || undefined}))
const rows = computed(() => data.value?.list ?? [])
onMounted(reload)
watch(status, () => { page.value = 1; void reload() })
watch(page, reload)
async function transit(id: number, action: 'accept' | 'report') {
  if (pending.value !== null || (action === 'report' && !note.value.trim())) return
  pending.value = id
  try {
    await api(`todos/${id}/status`, {}, {method:'POST', body:{action, result_note: action === 'report' ? note.value.trim() : undefined}})
    reportId.value = null; note.value = ''; toast.success('已更新'); await reload()
  } catch (e) { toast.warning(e instanceof Error ? e.message : '操作失败'); await reload() }
  finally { pending.value = null }
}
</script>

<style scoped>
.tasks-toolbar { display: flex; align-items: center; gap: var(--wb-space-2); margin-bottom: var(--wb-space-3); font-size: var(--wb-fs-sm); color: var(--wb-text-2); }
.tasks-pagination { display: flex; align-items: center; gap: var(--wb-space-2); margin-top: var(--wb-space-3); font-size: var(--wb-fs-sm); color: var(--wb-text-3); }
.task-button { border: 1px solid var(--wb-input-border); border-radius: var(--wb-radius-inner); background: var(--wb-surface); color: var(--wb-text-1); padding: var(--wb-space-1) var(--wb-space-2); font: inherit; font-size: var(--wb-fs-sm); cursor: pointer; }
.task-button:disabled { color: var(--wb-text-3); cursor: not-allowed; }
.task-button:hover:not(:disabled) { border-color: var(--wb-accent); }
.task-button:focus-visible { outline: 2px solid var(--wb-accent); }
.task-report { display: flex; flex-direction: column; align-items: flex-start; gap: var(--wb-space-2); margin-top: var(--wb-space-4); padding-top: var(--wb-space-3); border-top: 1px solid var(--wb-hairline); }
.task-report label { display: flex; flex-direction: column; gap: var(--wb-space-2); font-size: var(--wb-fs-sm); }
.task-report textarea { resize: vertical; }
</style>
