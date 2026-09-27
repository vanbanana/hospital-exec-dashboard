<template>
  <table class="wb-table">
    <thead>
      <tr>
        <th
          v-for="col in columns"
          :key="col.key"
          :style="{
            width: col.width,
            textAlign: col.align === 'right' ? 'right' : col.align === 'center' ? 'center' : 'left',
          }"
        >
          {{ col.title }}
        </th>
      </tr>
    </thead>
    <tbody>
      <tr v-for="(row, rIdx) in rows" :key="rowKey ? String(row[rowKey]) : rIdx">
        <td
          v-for="col in columns"
          :key="col.key"
          :class="{ 'ta-r': col.align === 'right', 'ta-c': col.align === 'center' }"
        >
          <slot :name="`cell-${col.key}`" :row="row" :value="row[col.key]">
            <span :class="{ 'wb-num': col.num }">{{ row[col.key] }}</span>
          </slot>
        </td>
      </tr>
      <!-- 空态行：rows=[] 时占满列宽渲染空态（§10.1 empty 态，不报错不白屏） -->
      <tr v-if="!rows.length" class="wb-table-empty">
        <td :colspan="columns.length || 1">
          <WbEmpty :text="emptyText" />
        </td>
      </tr>
    </tbody>
  </table>
</template>

<script setup lang="ts">
import type { WbTableColumn } from '../../api/types'
import WbEmpty from './WbEmpty.vue'

export type { WbTableColumn }

withDefaults(
  defineProps<{
    columns: WbTableColumn[]
    rows: Record<string, unknown>[]
    rowKey?: string
    emptyText?: string
  }>(),
  { emptyText: '暂无数据' },
)
</script>

<style scoped>
.wb-table-empty:hover {
  background: transparent;
}
</style>
