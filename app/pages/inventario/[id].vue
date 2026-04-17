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

const confirmDesactivarModal = ref(false)

const handleSubmit = async (payload: { values: Partial<Producto> }) => {
  if (!producto.value) return
  
  // DETECCIÓN DE DESACTIVACIÓN CRÍTICA
  if (producto.value.activo && payload.values.activo === false) {
    pendingValues.value = payload.values
    confirmDesactivarModal.value = true
    return
  }

  pendingValues.value = payload.values
  motivo.value = ''
  motivoModal.value = true
}

const confirmarDesactivacionAutomatica = async () => {
  if (!producto.value) return
  
  saving.value = true
  
  try {
    // BLINDAJE: Solo enviamos los campos estrictamente necesarios para la actualización
    // Tomamos los valores REALES del producto en DB (ignorando el formulario)
    const finalValues: Partial<Producto> = {
      nombre: producto.value.nombre,
      codigo_parte: producto.value.codigo_parte,
      categoria_id: producto.value.categoria_id,
      precio_venta: producto.value.precio_venta,
      stock: 0,
      activo: false
    }

    await updateProductoConMotivo(producto.value.id, finalValues, 'Desactivación de producto')
    
    confirmDesactivarModal.value = false
    
    toast.add({ 
      severity: 'success', 
      summary: 'Producto desactivado', 
      detail: 'Stock descargado y acción registrada', 
      life: 3000 
    })
    
    // Pequeño delay para que el usuario vea el éxito antes de navegar
    setTimeout(() => {
      navigateTo('/inventario')
    }, 500)

  } catch (e: any) {
    console.error('Error en desactivación:', e)
    toast.add({ 
      severity: 'error', 
      summary: 'Error al desactivar', 
      detail: friendlyError(e), 
      life: 5000 
    })
  } finally {
    saving.value = false
  }
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

    <!-- Modal Confirmación Desactivación Blindada -->
    <Dialog
      v-model:visible="confirmDesactivarModal"
      modal
      header="Confirmar Desactivación de Producto"
      :style="{ width: '500px' }"
      :closable="!saving"
    >
      <div class="space-y-4">
        <div class="bg-rose-50 border-2 border-rose-200 rounded-xl p-4 flex gap-4 items-start">
          <div class="p-2 bg-rose-100 rounded-lg text-rose-700">
             <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><path d="M12 9v4"/><path d="M12 17h.01"/></svg>
          </div>
          <div>
            <p class="font-black text-rose-800 uppercase tracking-tight text-sm mb-1">Procedimiento de Seguridad</p>
            <p class="text-sm text-rose-900 leading-tight">Estás a punto de desactivar un producto con existencias (<b>{{ producto.stock }} uds</b>).</p>
          </div>
        </div>

        <div class="space-y-2 px-1">
           <div class="flex gap-2 items-start text-sm text-slate-600">
              <div class="mt-1 text-emerald-600 font-bold">✓</div>
              <p>El stock se descargará a <b>CERO</b> automáticamente.</p>
           </div>
           <div class="flex gap-2 items-start text-sm text-slate-600">
              <div class="mt-1 text-emerald-600 font-bold">✓</div>
              <p>Se creará una incidencia de auditoría automática.</p>
           </div>
           <div class="flex gap-2 items-start text-sm text-slate-600">
              <div class="mt-1 text-rose-600 font-bold">✕</div>
              <p>Se <b>descartará</b> cualquier otro cambio que hayas hecho en el formulario (nombre, precio, etc).</p>
           </div>
        </div>

        <p class="text-[11px] text-slate-500 italic bg-slate-50 p-2 rounded-lg border border-slate-100">
           Para modificar datos del producto, debe mantenerlo ACTIVO, guardar esos cambios y luego proceder con la desactivación.
        </p>
      </div>

      <template #footer>
        <Button label="Volver al formulario" severity="secondary" text :disabled="saving" @click="confirmDesactivarModal = false" />
        <Button
          label="Entendido, Desactivar"
          severity="danger"
          :loading="saving"
          @click="confirmarDesactivacionAutomatica"
        />
      </template>
    </Dialog>

    <Toast />
  </div>
</template>
