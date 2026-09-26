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
    </tbody>
  </table>
</template>

<script setup lang="ts">
export interface WbTableColumn {
  key: string
  title: string
  width?: string
  align?: 'left' | 'center' | 'right'
  num?: boolean
}

defineProps<{
  columns: WbTableColumn[]
  rows: Record<string, unknown>[]
  rowKey?: string
}>()
</script>
