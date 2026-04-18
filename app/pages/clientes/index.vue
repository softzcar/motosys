<script setup lang="ts">
import type { Cliente } from '~/composables/useClientes'
import { FilterMatchMode } from '@primevue/core/api'
import { Search, Plus, Pencil, Trash2 } from 'lucide-vue-next'

const { fetchClientes, crearCliente, actualizarCliente, eliminarCliente } = useClientes()
const toast = useToast()
const confirm = useConfirm()

const clientes = ref<Cliente[]>([])
const loading = ref(false)
const total = ref(0)

const isDialogVisible = ref(false)
const saving = ref(false)
const editingId = ref<string | null>(null)

const filters = ref({
  global: { value: null, matchMode: FilterMatchMode.CONTAINS }
})
const sortField = ref('nombre')
const sortOrder = ref(1)
const totalRecords = ref(0)
const rowsPerPage = ref(10)
const firstRow = ref(0)

const formData = ref<Partial<Cliente>>({
  cedula: '',
  nombre: '',
  telefono: ''
})

const loadClientes = async (event?: any) => {
  loading.value = true
  try {
    const page = event?.first !== undefined ? event.first / event.rows : 0
    if (event?.rows) rowsPerPage.value = event.rows
    if (event?.first !== undefined) firstRow.value = event.first
    
    if (event?.sortField) {
      sortField.value = event.sortField
      sortOrder.value = event.sortOrder
    }

    const result = await fetchClientes({ 
      rows: rowsPerPage.value,
      page,
      search: filters.value.global.value || undefined,
      sortField: sortField.value,
      sortOrder: sortOrder.value
    })
    clientes.value = result.data
    totalRecords.value = result.total
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

const onFilter = () => {
  firstRow.value = 0
  loadClientes()
}

const openDialog = (cliente?: Cliente) => {
  if (cliente) {
    editingId.value = cliente.id!
    formData.value = { ...cliente }
  } else {
    editingId.value = null
    formData.value = { cedula: '', nombre: '', telefono: '' }
  }
  isDialogVisible.value = true
}

const saveCliente = async () => {
  if (!formData.value.cedula || !formData.value.nombre) {
    toast.add({ severity: 'warn', summary: 'Atención', detail: 'Cédula y Nombre son obligatorios', life: 3000 })
    return
  }

  saving.value = true
  try {
    if (editingId.value) {
      await actualizarCliente(editingId.value, formData.value)
      toast.add({ severity: 'success', summary: 'Éxito', detail: 'Cliente actualizado', life: 3000 })
    } else {
      await crearCliente(formData.value as Omit<Cliente, 'id'>)
      toast.add({ severity: 'success', summary: 'Éxito', detail: 'Cliente creado', life: 3000 })
    }
    isDialogVisible.value = false
    loadClientes()
  } catch (e: any) {
    let msg = e.message
    if (e.code === '23505') msg = 'La cédula ya está registrada.'
    toast.add({ severity: 'error', summary: 'Error al procesar', detail: msg, life: 5000 })
  } finally {
    saving.value = false
  }
}

const handleDelete = (cliente: Cliente) => {
  confirm.require({
    message: `¿Eliminar al cliente "${cliente.nombre}"? No se podrá si tiene ventas asociadas.`,
    header: 'Confirmar Eliminación',
    acceptLabel: 'Eliminar',
    rejectLabel: 'Cancelar',
    acceptClass: 'p-button-danger',
    accept: async () => {
      try {
        await eliminarCliente(cliente.id!)
        toast.add({ severity: 'success', summary: 'Eliminado', detail: 'Cliente eliminado', life: 3000 })
        loadClientes()
      } catch (e: any) {
        toast.add({ severity: 'error', summary: 'No se puede eliminar', detail: e.message, life: 4000 })
      }
    }
  })
}

onMounted(loadClientes)
</script>

<template>
  <div class="space-y-6">
    <div class="flex flex-wrap items-center justify-between gap-4 mb-6">
      <h1 class="m-0 text-2xl font-bold text-slate-800">Clientes</h1>
      <Button 
        label="Nuevo Cliente" 
        icon="pi pi-plus" 
        severity="success" 
        class="shadow-sm" 
        @click="openDialog()"
      />
    </div>

    <div class="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
      <DataTable 
        :value="clientes" 
        :loading="loading"
        v-model:filters="filters"
        paginator 
        :rows="rowsPerPage" 
        :totalRecords="totalRecords"
        :first="firstRow"
        lazy
        @page="loadClientes"
        @sort="loadClientes"
        :sortField="sortField"
        :sortOrder="sortOrder"
        dataKey="id"
        class="p-datatable-sm text-sm"
        stripedRows
      >
        <template #header>
          <div class="flex justify-end p-2 border-b border-slate-100">
            <div class="relative w-64">
              <Search class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" :size="18" />
              <input 
                v-model="filters['global'].value" 
                placeholder="Buscar por cédula o nombre..." 
                class="w-full pl-10 pr-4 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                @input="onFilter"
              />
            </div>
          </div>
        </template>

        <Column field="cedula" header="Cédula" sortable></Column>
        <Column field="nombre" header="Nombre" sortable></Column>
        <Column field="telefono" header="Teléfono"></Column>
        <Column field="created_at" header="Fecha Registro" sortable>
          <template #body="{ data }">
            {{ new Date(data.created_at).toLocaleDateString() }}
          </template>
        </Column>

        <Column header="" alignFrozen="right" :frozen="true">
          <template #body="{ data }">
            <div class="flex items-center gap-2">
              <button 
                @click="openDialog(data)" 
                class="p-2 text-slate-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition"
                title="Editar"
              >
                <Pencil :size="18" />
              </button>
              <button 
                @click="handleDelete(data)" 
                class="p-2 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition"
                title="Eliminar"
              >
                <Trash2 :size="18" />
              </button>
            </div>
          </template>
        </Column>

        <template #empty>
          <div class="p-8 text-center text-slate-500">
            No se encontraron clientes.
          </div>
        </template>
      </DataTable>
    </div>

    <!-- Modal Formulario Cliente -->
    <Dialog 
      v-model:visible="isDialogVisible" 
      :header="editingId ? 'Editar Cliente' : 'Nuevo Cliente'" 
      modal 
      class="w-full max-w-md"
    >
      <div class="space-y-4 pt-4">
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Cédula / Identificador</label>
          <input 
            v-model="formData.cedula" 
            type="text" 
            class="w-full px-3 py-2 border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            :disabled="!!editingId"
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Nombre Completo</label>
          <input 
            v-model="formData.nombre" 
            type="text" 
            class="w-full px-3 py-2 border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Teléfono</label>
          <input 
            v-model="formData.telefono" 
            type="text" 
            class="w-full px-3 py-2 border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
      </div>
      <template #footer>
        <div class="flex justify-end gap-2 mt-4">
          <button @click="isDialogVisible = false" class="px-4 py-2 text-slate-600 hover:bg-slate-100 rounded-lg transition">
            Cancelar
          </button>
          <button @click="saveCliente" :disabled="saving" class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition flex items-center gap-2">
            <span v-if="saving" class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></span>
            Guardar
          </button>
        </div>
      </template>
    </Dialog>
  </div>
</template>
