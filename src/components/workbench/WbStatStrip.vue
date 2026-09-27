<template>
  <div class="wb-stat-strip">
    <WbEmpty v-if="!items.length" text="暂无指标数据" />
    <div v-for="item in items" :key="item.label" class="wb-stat">
      <span class="wb-stat-label">{{ item.label }}</span>
      <span class="wb-stat-value">
        {{ item.value }}<span v-if="item.unit" class="wb-stat-unit">{{ item.unit }}</span>
      </span>
      <span v-if="item.delta" class="wb-stat-delta">
        <span class="lbl">{{ item.delta_label || '较上月' }}</span>
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
// 契约 §1.3-3 统一指标条接口——唯一类型源在 api/types，禁止本地瘦身复刻
import type { WbStatItem } from '../../api/types'
import WbEmpty from './WbEmpty.vue'

defineProps<{ items: WbStatItem[] }>()
</script>
