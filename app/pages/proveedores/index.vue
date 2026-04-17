<script setup lang="ts">
import { useProveedores, type Proveedor } from '~/composables/useProveedores'
import { useToast } from 'primevue/usetoast'
import { FilterMatchMode } from '@primevue/core/api'
import { Search, Plus, Pencil, Trash2 } from 'lucide-vue-next'

const { fetchProveedores, crearProveedor, actualizarProveedor, eliminarProveedor } = useProveedores()
const toast = useToast()

const proveedores = ref<Proveedor[]>([])
const loading = ref(true)
const totalRecords = ref(0)
const proveedorDialog = ref(false)
const deleteProveedorDialog = ref(false)
const proveedor = ref<Proveedor>({ nombre: '', telefono: '', direccion: '' })
const submitted = ref(false)
const filters = ref({
  global: { value: null, matchMode: FilterMatchMode.CONTAINS }
})
const sortField = ref('nombre')
const sortOrder = ref(1)

const loadProveedores = async (event?: any) => {
  loading.value = true
  try {
    const page = event?.first !== undefined ? event.first / event.rows : 0
    if (event?.sortField) {
      sortField.value = event.sortField
      sortOrder.value = event.sortOrder
    }
    const { data, total } = await fetchProveedores({ 
      search: filters.value.global.value ?? undefined,
      page,
      rows: event?.rows ?? 10,
      sortField: sortField.value,
      sortOrder: sortOrder.value
    })
    proveedores.value = data
    totalRecords.value = total
  } catch (error: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: error.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  loadProveedores()
})

const openNew = () => {
  proveedor.value = { nombre: '', telefono: '', direccion: '' }
  submitted.value = false
  proveedorDialog.value = true
}

const hideDialog = () => {
  proveedorDialog.value = false
  submitted.value = false
}

const saveProveedor = async () => {
  submitted.value = true

  if (proveedor.value.nombre.trim()) {
    try {
      if (proveedor.value.id) {
        await actualizarProveedor(proveedor.value.id, proveedor.value)
        toast.add({ severity: 'success', summary: 'Éxito', detail: 'Proveedor actualizado', life: 3000 })
      } else {
        await crearProveedor(proveedor.value)
        toast.add({ severity: 'success', summary: 'Éxito', detail: 'Proveedor creado', life: 3000 })
      }
      proveedorDialog.value = false
      proveedor.value = { nombre: '', telefono: '', direccion: '' }
      loadProveedores()
    } catch (error: any) {
      toast.add({ severity: 'error', summary: 'Error', detail: error.message, life: 3000 })
    }
  }
}

const editProveedor = (p: Proveedor) => {
  proveedor.value = { ...p }
  proveedorDialog.value = true
}

const confirmDeleteProveedor = (p: Proveedor) => {
  proveedor.value = p
  deleteProveedorDialog.value = true
}

const deleteProveedor = async () => {
  try {
    if (proveedor.value.id) {
      await eliminarProveedor(proveedor.value.id)
      proveedor.value = { nombre: '', telefono: '', direccion: '' }
      loadProveedores()
      toast.add({ severity: 'success', summary: 'Éxito', detail: 'Proveedor eliminado', life: 3000 })
    }
  } catch (error: any) {
    if (error.code === '23503') {
      toast.add({ 
        severity: 'error', 
        summary: 'Error al eliminar', 
        detail: 'No se puede eliminar este proveedor porque tiene compras registradas en el sistema. Te recomendamos mantenerlo para preservar el historial.', 
        life: 5000 
      })
    } else {
      toast.add({ severity: 'error', summary: 'Error', detail: error.message, life: 3000 })
    }
  } finally {
    deleteProveedorDialog.value = false
  }
}

const onFilter = () => {
  loadProveedores()
}
</script>

<template>
  <div class="card p-4">
    <div class="flex flex-wrap items-center justify-between gap-4 mb-6">
      <h1 class="m-0 text-2xl font-bold text-slate-800">Gestión de Proveedores</h1>
      <div class="flex flex-wrap items-center gap-3">
        <IconField iconPosition="left">
          <InputIcon>
            <Search :size="16" class="text-slate-400" />
          </InputIcon>
          <InputText v-model="filters.global.value" placeholder="Buscar..." @input="onFilter" />
        </IconField>
        <Button severity="success" class="shadow-sm flex items-center gap-2" @click="openNew">
          <Plus :size="16" />
          Nuevo Proveedor
        </Button>
      </div>
    </div>

    <DataTable 
      v-model:filters="filters" 
      :value="proveedores" 
      dataKey="id" 
      :paginator="true" 
      :rows="10" 
      :totalRecords="totalRecords"
      :loading="loading"
      @page="loadProveedores"
      @sort="loadProveedores"
      :sort-field="sortField"
      :sort-order="sortOrder"
      lazy
      stripedRows
      class="p-datatable-sm"
      responsiveLayout="stack"
    >
      <Column field="nombre" header="Nombre" sortable></Column>
      <Column field="telefono" header="Teléfono"></Column>
      <Column field="direccion" header="Dirección"></Column>
      <Column :exportable="false" header="Acciones" alignFrozen="right" frozen>
        <template #body="slotProps">
          <div class="flex items-center gap-2">
            <button
              @click="editProveedor(slotProps.data)"
              class="p-2 text-slate-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition"
              title="Editar"
            >
              <Pencil :size="18" />
            </button>
            <button
              @click="confirmDeleteProveedor(slotProps.data)"
              class="p-2 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition"
              title="Eliminar"
            >
              <Trash2 :size="18" />
            </button>
          </div>
        </template>
      </Column>
    </DataTable>

    <Dialog v-model:visible="proveedorDialog" :style="{ width: '450px' }" header="Detalles del Proveedor" :modal="true" class="p-fluid">
      <div class="field mb-3">
        <label for="nombre" class="font-bold">Nombre</label>
        <InputText id="nombre" v-model.trim="proveedor.nombre" required="true" autofocus :class="{ 'p-invalid': submitted && !proveedor.nombre }" />
        <small class="p-error" v-if="submitted && !proveedor.nombre">El nombre es requerido.</small>
      </div>
      <div class="field mb-3">
        <label for="telefono" class="font-bold">Teléfono</label>
        <InputText id="telefono" v-model.trim="proveedor.telefono" />
      </div>
      <div class="field mb-3">
        <label for="direccion" class="font-bold">Dirección</label>
        <Textarea id="direccion" v-model="proveedor.direccion" rows="3" cols="20" />
      </div>
      <template #footer>
        <Button label="Cancelar" icon="pi pi-times" text @click="hideDialog" />
        <Button label="Guardar" icon="pi pi-check" @click="saveProveedor" />
      </template>
    </Dialog>

    <Dialog v-model:visible="deleteProveedorDialog" :style="{ width: '450px' }" header="Confirmar" :modal="true">
      <div class="flex align-items-center justify-content-center">
        <i class="pi pi-exclamation-triangle mr-3" style="font-size: 2rem" />
        <span v-if="proveedor">¿Estás seguro de que quieres eliminar a <b>{{ proveedor.nombre }}</b>?</span>
      </div>
      <template #footer>
        <Button label="No" icon="pi pi-times" text @click="deleteProveedorDialog = false" />
        <Button label="Sí" icon="pi pi-check" severity="danger" @click="deleteProveedor" />
      </template>
    </Dialog>

    <Toast />
  </div>
</template>
