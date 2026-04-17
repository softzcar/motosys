<script setup lang="ts">
import { Trash2 } from 'lucide-vue-next'
import type { CartItem } from '~/types/database'

defineProps<{ item: CartItem }>()

const emit = defineEmits<{
  updateQuantity: [productoId: string, cantidad: number]
  remove: [productoId: string]
}>()
</script>

<template>
  <div class="flex items-center gap-3 py-3 border-b border-slate-100 last:border-0">
    <div class="flex-1 min-w-0">
      <p class="text-sm font-medium text-slate-800 truncate">{{ item.producto.nombre }}</p>
      <p class="text-xs text-slate-500">{{ item.producto.codigo_parte }}</p>
    </div>

    <InputNumber
      :model-value="item.cantidad"
      :min="1"
      :max="item.producto.stock"
      show-buttons
      button-layout="horizontal"
      :input-style="{ width: '3rem', textAlign: 'center' }"
      decrement-button-class="p-button-sm p-button-secondary"
      increment-button-class="p-button-sm p-button-secondary"
      @update:model-value="emit('updateQuantity', item.producto.id, $event ?? 1)"
    />

    <span class="text-sm font-semibold text-slate-800 w-20 text-right">
      ${{ (item.cantidad * item.precio_unitario).toFixed(2) }}
    </span>

    <Button
      text
      rounded
      severity="danger"
      size="small"
      @click="emit('remove', item.producto.id)"
      aria-label="Quitar"
    >
      <Trash2 :size="16" />
    </Button>
  </div>
</template>
