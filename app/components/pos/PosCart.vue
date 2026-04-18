<script setup lang="ts">
import { ShoppingCart } from 'lucide-vue-next'

const cart = useCartStore()

defineProps<{
  disabled?: boolean
}>()

const emit = defineEmits<{ checkout: [] }>()
</script>

<template>
  <div class="bg-white rounded-xl shadow-sm flex flex-col h-full">
    <div class="p-4 border-b border-slate-200 flex items-center gap-2">
      <ShoppingCart :size="20" class="text-slate-600" />
      <h2 class="font-semibold text-slate-800">Carrito</h2>
      <Tag v-if="cart.itemCount > 0" :value="String(cart.itemCount)" rounded />
    </div>

    <!-- Mover el total y el botón a la parte superior -->
    <div class="p-4 border-b border-slate-100 bg-slate-50/50">
      <div class="flex justify-between items-center mb-4">
        <span class="text-lg font-bold text-slate-800">Total</span>
        <span class="text-2xl font-bold text-blue-600">${{ cart.total.toFixed(2) }}</span>
      </div>

      <Button
        label="Procesar Venta (F3)"
        class="w-full font-bold shadow-md"
        severity="success"
        :disabled="cart.items.length === 0 || disabled"
        :tabindex="disabled ? -1 : 0"
        @click="emit('checkout')"
      />
    </div>

    <div class="flex-1 overflow-auto p-4">
      <div v-if="cart.items.length === 0" class="text-center py-12 text-slate-400">
        <ShoppingCart :size="48" class="mx-auto mb-3 opacity-50" />
        <p>Escanea o busca un producto</p>
      </div>

      <PosCartItem
        v-for="item in cart.items"
        :key="item.producto.id"
        :item="item"
        :disabled="disabled"
        @update-quantity="cart.updateQuantity"
        @remove="cart.removeItem"
      />
    </div>
  </div>
</template>
