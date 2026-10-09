<template>
  <WbToast />
  <WbSkeleton v-if="loading && !data" :rows="5" />
  <WbErrorPanel v-if="error" :error="error" :loading="loading" @retry="reload" />
  <div v-if="data" class="wb-preferences">
    <label class="wb-form-row"><span>默认统计范围</span><select class="wb-select" v-model="draft.default_range" :disabled="pending" @change="save('default_range')"><option>本月</option><option>本季</option><option>本年</option></select></label>
    <label class="wb-form-row"><span>工作台刷新间隔</span><select class="wb-select" v-model="draft.refresh_interval" :disabled="pending" @change="save('refresh_interval')"><option>5 分钟</option><option>15 分钟</option><option>30 分钟</option></select></label>
    <label v-for="item in switches" :key="item.key" class="wb-form-row"><span>{{ item.label }}</span><input type="checkbox" v-model="draft[item.key]" :disabled="pending" @change="save(item.key)" /></label>
    <p class="wb-form-desc">声音需点击页面解锁后播放；金额设置作用于 KPI 和指标条。非管理身份的人员姓名始终由服务端强制脱敏。</p>
  </div>
</template>
<script setup lang="ts">
import { reactive, ref, watch, onMounted } from 'vue'
import { api } from '../../api/client'
import { savePreferences } from '../../api/settings'
import { useAsyncData } from '../../api/useAsyncData'
import { applyPreferences, type Preferences } from '../../api/preferences'
import WbToast, { toast } from './WbToast.vue'
import WbErrorPanel from './WbErrorPanel.vue'
import WbSkeleton from './WbSkeleton.vue'

const {data,error,loading,reload}=useAsyncData(()=>api<Preferences>('workbench/settings/preferences'))
const draft=reactive<Preferences>({default_range:'本月',refresh_interval:'5 分钟',alert_sound:true,unit_abbreviation:true,privacy_mask:true})
const confirmed=reactive({...draft})
const pending=ref(false)
const switches: {key:'alert_sound'|'unit_abbreviation'|'privacy_mask';label:string}[]=[{key:'alert_sound',label:'新高风险预警声音'},{key:'unit_abbreviation',label:'KPI 和指标条金额缩写'},{key:'privacy_mask',label:'工单与人员姓名脱敏'}]
watch(data,p=>{if(p && !pending.value){Object.assign(draft,p);Object.assign(confirmed,p);applyPreferences(p)}})
onMounted(reload)
async function save<K extends keyof Preferences>(key: K) {
  if(pending.value)return
  pending.value=true
  try {
    const saved=await savePreferences({[key]:draft[key]})
    Object.assign(draft,saved);Object.assign(confirmed,saved);applyPreferences(saved)
    toast.success('已保存')
  } catch(e) {Object.assign(draft,confirmed);toast.warning(e instanceof Error?e.message:'保存失败')}
  finally {pending.value=false}
}
</script>
