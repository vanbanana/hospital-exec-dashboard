<template>
  <div class="wb-page-head">
    <div class="wb-page-title-box">
      <h2 class="wb-page-title">{{ title }}</h2>
      <span v-if="sub" class="wb-page-sub">{{ sub }}</span>
    </div>
    <div v-if="$slots.default" class="wb-page-actions">
      <slot />
    </div>
  </div>
</template>

<script setup lang="ts">
defineProps<{ title: string; sub?: string }>()
</script>
