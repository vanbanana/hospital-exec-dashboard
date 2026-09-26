<template>
  <div class="wb-page">
    <WbPageHead title="系统设置" sub="数据源 · 预警阈值 · 用户权限 · 偏好" />

    <div class="wb-grid wb-grid-2">
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
              <template #cell-enabled="{ row }">
                <button
                  class="wb-switch"
                  :class="{ on: row.enabled }"
                  @click="row.enabled = !row.enabled"
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
            <div class="wb-form-row">
              <div>
                <div class="wb-form-label">默认时间范围</div>
                <div class="wb-form-desc">进入工作台时默认展示的统计口径</div>
              </div>
              <select class="wb-select" v-model="pref.range">
                <option>本月</option>
                <option>本季</option>
                <option>本年</option>
              </select>
            </div>
            <div class="wb-form-row">
              <div>
                <div class="wb-form-label">数据刷新频率</div>
                <div class="wb-form-desc">实时类指标的自动刷新间隔</div>
              </div>
              <select class="wb-select" v-model="pref.refresh">
                <option>5 分钟</option>
                <option>15 分钟</option>
                <option>30 分钟</option>
              </select>
            </div>
            <div class="wb-form-row">
              <div>
                <div class="wb-form-label">新预警声音提醒</div>
                <div class="wb-form-desc">出现高风险预警时播放提示音</div>
              </div>
              <button class="wb-switch" :class="{ on: pref.sound }" @click="pref.sound = !pref.sound"></button>
            </div>
            <div class="wb-form-row">
              <div>
                <div class="wb-form-label">金额单位缩写</div>
                <div class="wb-form-desc">大额指标以「万元/亿元」缩写展示</div>
              </div>
              <button class="wb-switch" :class="{ on: pref.unitAbbr }" @click="pref.unitAbbr = !pref.unitAbbr"></button>
            </div>
            <div class="wb-form-row">
              <div>
                <div class="wb-form-label">敏感数据脱敏</div>
                <div class="wb-form-desc">人员姓名等字段在非管理端脱敏显示</div>
              </div>
              <button class="wb-switch" :class="{ on: pref.mask }" @click="pref.mask = !pref.mask"></button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { reactive } from 'vue'
import WbPageHead from '../../components/workbench/WbPageHead.vue'
import WbTable, { type WbTableColumn } from '../../components/workbench/WbTable.vue'

const dsCols: WbTableColumn[] = [
  { key: 'name', title: '数据源' },
  { key: 'type', title: '类型' },
  { key: 'status', title: '状态', align: 'center' },
  { key: 'sync', title: '最近同步', align: 'right', num: true },
]

const dsRows = [
  { name: 'HIS 门诊收费系统', type: '业务库 · 准实时', status: '已连接', sync: '10-28 09:42' },
  { name: 'HIS 住院管理系统', type: '业务库 · 准实时', status: '已连接', sync: '10-28 09:42' },
  { name: 'EMR 电子病历', type: '业务库 · 小时级', status: '已连接', sync: '10-28 09:00' },
  { name: 'LIS 检验系统', type: '业务库 · 小时级', status: '已连接', sync: '10-28 09:05' },
  { name: 'HRP 人财物系统', type: '业务库 · 日终批', status: '已连接', sync: '10-28 06:30' },
  { name: '医保结算接口', type: '局端接口 · 日终批', status: '异常', sync: '10-27 23:58' },
]

const thCols: WbTableColumn[] = [
  { key: 'name', title: '指标' },
  { key: 'rule', title: '触发条件' },
  { key: 'level', title: '级别', align: 'center' },
  { key: 'enabled', title: '启用', align: 'center' },
]

const thRows = reactive([
  { name: '床位使用率', rule: '连续 3 日 > 95%', level: '高', enabled: true },
  { name: '药占比', rule: '> 30%', level: '中', enabled: true },
  { name: '耗占比', rule: '> 20%', level: '中', enabled: true },
  { name: '住院费用增幅', rule: '同比 > 8%', level: '高', enabled: true },
  { name: '库存周转天数', rule: '> 35 天', level: '低', enabled: true },
  { name: '危急值超时率', rule: '及时率 < 95%', level: '高', enabled: true },
  { name: '设备开机率', rule: '< 60%', level: '低', enabled: false },
])

const userCols: WbTableColumn[] = [
  { key: 'name', title: '姓名' },
  { key: 'role', title: '角色', align: 'center' },
  { key: 'scope', title: '数据范围' },
  { key: 'login', title: '最近登录', align: 'right', num: true },
  { key: 'status', title: '状态', align: 'center' },
]

const userRows = [
  { name: 'system_admin', role: '管理员', scope: '全部', login: '10-28 09:12', status: '启用' },
  { name: '院长', role: '院领导', scope: '全院', login: '10-28 08:46', status: '启用' },
  { name: '分管副院长·医疗', role: '院领导', scope: '全院', login: '10-27 17:32', status: '启用' },
  { name: '医务部主任', role: '部门负责人', scope: '医疗业务', login: '10-28 08:58', status: '启用' },
  { name: '财务部主任', role: '部门负责人', scope: '运营财务', login: '10-28 09:05', status: '启用' },
  { name: '质控科主任', role: '部门负责人', scope: '质量安全', login: '10-27 16:20', status: '启用' },
]

const pref = reactive({
  range: '本月',
  refresh: '5 分钟',
  sound: true,
  unitAbbr: true,
  mask: true,
})
</script>

<style scoped>
.settings-col {
  display: flex;
  flex-direction: column;
  gap: var(--wb-gap);
  min-width: 0;
}
</style>
