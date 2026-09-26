<template>
  <div class="wb-seg">
    <button
      v-for="opt in options"
      :key="opt"
      class="wb-seg-item"
      :class="{ active: modelValue === opt }"
      @click="$emit('update:modelValue', opt)"
    >
      {{ opt }}
    </button>
  </div>
</template>

<script setup lang="ts">
defineProps<{ options: string[]; modelValue: string }>()
defineEmits<{ 'update:modelValue': [value: string] }>()
</script>
