<template>
  <section class="scr-panel">
    <header class="scr-panel-head">
      <span>{{ title }}</span>
      <span v-if="sub" class="scr-head-sub">{{ sub }}</span>
      <slot name="head-extra" />
    </header>
    <div class="scr-panel-body">
      <slot />
    </div>
  </section>
</template>

<script setup lang="ts">
defineProps<{ title: string; sub?: string }>()
</script>
