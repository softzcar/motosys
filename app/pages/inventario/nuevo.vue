<script setup lang="ts">
import type { Producto } from '~/types/database'

const { createProducto, friendlyError } = useProductos()
const toast = useToast()

const saving = ref(false)

const handleSubmit = async (payload: { values: Partial<Producto> }) => {
  saving.value = true
  try {
    await createProducto(payload.values)

    toast.add({ severity: 'success', summary: 'Producto creado', detail: payload.values.nombre, life: 2000 })
    await navigateTo('/inventario')
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'No se pudo crear', detail: friendlyError(e), life: 4000 })
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="max-w-2xl">
    <h1 class="text-2xl font-bold text-slate-800 mb-6">Nuevo Producto</h1>

    <div class="bg-white rounded-xl p-6 shadow-sm">
      <InventarioProductoForm :loading="saving" @submit="handleSubmit" @cancel="navigateTo('/inventario')" />
    </div>

    <Toast />
  </div>
</template>
