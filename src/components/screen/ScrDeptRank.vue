<template>
  <ScrPanel title="科室效能榜" sub="CMI · DRG结余 · 效能分">
    <table v-if="list && list.length" class="scr-table rank-table">
      <thead>
        <tr>
          <th>名次</th>
          <th>科室</th>
          <th>类别</th>
          <th class="num">CMI</th>
          <th class="num">手术量</th>
          <th class="num">住院日</th>
          <th class="num">结余(万)</th>
          <th class="num">效能分</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="d in list" :key="d.dept_id">
          <td>
            <span class="rank-badge scr-num" :class="`r${d.rank}`">{{ d.rank }}</span>
          </td>
          <td class="dept-name">{{ d.name }}</td>
          <td>
            <span class="cat-tag" :class="d.category">{{ d.category === 'surg' ? '外科系' : '内科系' }}</span>
          </td>
          <td class="num scr-num">{{ d.cmi.toFixed(2) }}</td>
          <td class="num scr-num">{{ d.surg_cnt }}</td>
          <td class="num scr-num">{{ d.alos.toFixed(1) }}</td>
          <td class="num scr-num" :class="d.profit >= 0 ? 'profit-pos' : 'profit-neg'">
            {{ d.profit >= 0 ? '+' : '' }}{{ d.profit.toFixed(1) }}
          </td>
          <td class="num">
            <div class="eff-cell">
              <div class="eff-track">
                <div class="eff-fill" :style="{ width: `${d.eff_score}%` }"></div>
              </div>
              <span class="scr-num eff-val">{{ d.eff_score.toFixed(1) }}</span>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    <div v-else class="scr-empty">暂无科室数据</div>
  </ScrPanel>
</template>

<script setup lang="ts">
import ScrPanel from './ScrPanel.vue'
import type { DeptRankItem } from '../../api/types'

defineProps<{ list?: DeptRankItem[] }>()
</script>

<style scoped>
.rank-table {
  flex: 1;
}

.rank-table th.num,
.rank-table td.num {
  text-align: right;
}

.dept-name {
  color: var(--scr-text-1);
  font-weight: 500;
}

.rank-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 18px; /* 美术稿 */
  height: 18px;
  border-radius: var(--scr-radius-tag);
  font-size: var(--scr-fs-sm);
  font-weight: 700;
  color: var(--scr-text-2);
  background: rgb(from var(--p-slate-400) r g b / 0.16);
}

.rank-badge.r1 {
  background: rgb(from var(--p-amber-500) r g b / 0.22);
  color: var(--scr-warn);
}
.rank-badge.r2 {
  background: rgb(from var(--p-slate-300) r g b / 0.22);
  color: var(--scr-text-2);
}
.rank-badge.r3 {
  background: rgb(from var(--p-amber-600) r g b / 0.22);
  color: var(--p-amber-500);
}

.cat-tag {
  font-size: var(--scr-fs-sm);
  padding: var(--scr-space-1) var(--scr-space-3);
  border-radius: var(--scr-radius-tag);
}
.cat-tag.surg {
  background: rgb(from var(--p-cyan-400) r g b / 0.12);
  color: var(--scr-accent-bright);
}
.cat-tag.med {
  background: rgb(from var(--p-blue-500) r g b / 0.18);
  color: var(--p-blue-300);
}

/* 盈亏按国内惯例：正=红(盈) 负=绿(亏) */
.profit-pos {
  color: var(--scr-up);
  font-weight: 600;
}
.profit-neg {
  color: var(--scr-down);
}

.eff-cell {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: var(--scr-space-4);
}

.eff-track {
  width: 52px; /* 美术稿 */
  height: 4px;
  border-radius: var(--scr-radius-badge);
  background: rgb(from var(--p-slate-400) r g b / 0.18);
  overflow: hidden;
}

.eff-fill {
  height: 100%;
  border-radius: var(--scr-radius-badge);
  background: linear-gradient(90deg, var(--p-blue-600), var(--scr-accent-bright));
}

.eff-val {
  min-width: 30px; /* 美术稿 */
  color: var(--scr-text-1);
  font-weight: 600;
}
</style>
