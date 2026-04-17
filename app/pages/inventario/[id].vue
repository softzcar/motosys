<script setup lang="ts">
import type { Producto } from '~/types/database'

const route = useRoute()
const client = useSupabaseClient()
const { updateProductoConMotivo, friendlyError } = useProductos()
const toast = useToast()

const producto = ref<Producto | null>(null)
const loading = ref(true)
const saving = ref(false)

const motivoModal = ref(false)
const motivo = ref('')
const pendingValues = ref<Partial<Producto> | null>(null)

const loadProducto = async () => {
  const { data, error } = await client
    .from('productos')
    .select('*')
    .eq('id', route.params.id)
    .single()

  if (error) {
    toast.add({ severity: 'error', summary: 'Producto no encontrado', life: 3000 })
    await navigateTo('/inventario')
    return
  }
  producto.value = data as Producto
  loading.value = false
}

const handleSubmit = (payload: { values: Partial<Producto> }) => {
  if (!producto.value) return
  pendingValues.value = payload.values
  motivo.value = ''
  motivoModal.value = true
}

const confirmarGuardar = async () => {
  if (!producto.value || !pendingValues.value) return
  if (motivo.value.trim().length < 10) {
    toast.add({ severity: 'warn', summary: 'Motivo requerido', detail: 'Mínimo 10 caracteres', life: 3000 })
    return
  }
  saving.value = true
  try {
    await updateProductoConMotivo(producto.value.id, pendingValues.value, motivo.value.trim())
    toast.add({ severity: 'success', summary: 'Cambios guardados', life: 2000 })
    motivoModal.value = false
    await navigateTo('/inventario')
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'No se pudo guardar', detail: friendlyError(e), life: 4000 })
  } finally {
    saving.value = false
  }
}

onMounted(loadProducto)
</script>

<template>
  <div class="max-w-2xl">
    <h1 class="text-2xl font-bold text-slate-800 mb-6">Editar Producto</h1>

    <div v-if="loading" class="flex justify-center py-12">
      <ProgressSpinner />
    </div>

    <div v-else-if="producto" class="bg-white rounded-xl p-6 shadow-sm">
      <InventarioProductoForm
        :producto="producto"
        :loading="saving"
        @submit="handleSubmit"
        @cancel="navigateTo('/inventario')"
      />
    </div>

    <Dialog
      v-model:visible="motivoModal"
      modal
      header="Motivo del cambio"
      :style="{ width: '480px' }"
      :closable="!saving"
    >
      <p class="text-sm text-slate-600 mb-3">
        Indica por qué se modifica este producto. El cambio quedará registrado en la auditoría.
      </p>
      <Textarea
        v-model="motivo"
        rows="4"
        class="w-full"
        placeholder="Ej: Corrección de precio según nueva lista del proveedor"
        :disabled="saving"
      />
      <div class="text-xs text-slate-500 mt-1">
        {{ motivo.trim().length }} / 10 mínimo
      </div>
      <template #footer>
        <Button label="Cancelar" severity="secondary" text :disabled="saving" @click="motivoModal = false" />
        <Button
          label="Guardar"
          :loading="saving"
          :disabled="motivo.trim().length < 10"
          @click="confirmarGuardar"
        />
      </template>
    </Dialog>

    <Toast />
  </div>
</template>
