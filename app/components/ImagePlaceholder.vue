<script setup lang="ts">
import { ImageOff } from 'lucide-vue-next'

withDefaults(defineProps<{
  size?: number | string
  rounded?: string
  label?: string
}>(), {
  size: 64,
  rounded: 'rounded-lg',
  label: 'Sin imagen'
})
</script>

<template>
  <div
    :class="[
      'flex flex-col items-center justify-center bg-slate-50 border border-dashed border-slate-200 text-slate-400',
      rounded
    ]"
    :style="{ width: typeof size === 'number' ? `${size}px` : size, height: typeof size === 'number' ? `${size}px` : size }"
    :aria-label="label"
    role="img"
  >
    <ImageOff :size="Math.max(16, Math.floor((typeof size === 'number' ? size : 64) * 0.35))" stroke-width="1.5" />
  </div>
</template>
