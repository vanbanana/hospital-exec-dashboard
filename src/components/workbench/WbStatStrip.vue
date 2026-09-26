<template>
  <div class="wb-stat-strip">
    <div v-for="item in items" :key="item.label" class="wb-stat">
      <span class="wb-stat-label">{{ item.label }}</span>
      <span class="wb-stat-value">
        {{ item.value }}<span v-if="item.unit" class="wb-stat-unit">{{ item.unit }}</span>
      </span>
      <span v-if="item.delta" class="wb-stat-delta">
        <span class="lbl">{{ item.deltaLabel || '较上月' }}</span>
        <span
          :class="
            item.dir === 'down'
              ? 'wb-delta-down'
              : item.dir === 'flat'
                ? 'wb-delta-flat'
                : 'wb-delta-up'
          "
        >
          {{ item.delta }} {{ item.dir === 'down' ? '↓' : item.dir === 'flat' ? '–' : '↑' }}
        </span>
      </span>
      <span v-else-if="item.note" class="wb-stat-delta">
        <span class="lbl">{{ item.note }}</span>
      </span>
    </div>
  </div>
</template>

<script setup lang="ts">
export interface WbStatItem {
  label: string
  value: string | number
  unit?: string
  delta?: string
  dir?: 'up' | 'down' | 'flat'
  deltaLabel?: string
  note?: string
}

defineProps<{ items: WbStatItem[] }>()
</script>
