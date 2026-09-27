<template>
  <section class="scr-panel">
    <header class="scr-panel-head">
      <span>{{ title }}</span>
      <!-- REF 面板头无右侧副标（review F3）：sub prop 移除，头部只保留 |||+标题 -->
      <slot name="head-extra" />
    </header>
    <div class="scr-panel-body">
      <slot />
    </div>
  </section>
</template>

<script setup lang="ts">
defineProps<{ title: string }>()
</script>
