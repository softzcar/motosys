<script setup lang="ts">
import type { Perfil } from '~/types/database'

const { fetchEmpleados, deleteEmpleado, actualizarEstado, friendlyError } = useEmpleados()
const { isAdmin } = usePerfil()
const supaUser = useSupabaseUser()
const toast = useToast()
const confirm = useConfirm()

if (!isAdmin.value) {
  await navigateTo('/')
}

const empleados = ref<Perfil[]>([])
const total = ref(0)
const loading = ref(false)
const currentPage = ref(0)
const currentSearch = ref('')
const sortField = ref('nombre')
const sortOrder = ref(1)
const mostrarInactivos = ref(false)

const load = async () => {
  loading.value = true
  try {
    const result = await fetchEmpleados({
      search: currentSearch.value,
      page: currentPage.value,
      rows: 20,
      sortField: sortField.value,
      sortOrder: sortOrder.value,
      incluirInactivos: mostrarInactivos.value
    })
    empleados.value = result.data
    total.value = result.total
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: friendlyError(e), life: 3000 })
  } finally {
    loading.value = false
  }
}

const handlePage = (event: { page: number; rows: number }) => {
  currentPage.value = event.page
  load()
}
const handleSearch = (term: string) => {
  currentSearch.value = term
  currentPage.value = 0
  load()
}
const handleSort = (event: { sortField: string; sortOrder: number }) => {
  sortField.value = event.sortField
  sortOrder.value = event.sortOrder
  load()
}
const handleEdit = (empleado: Perfil) => navigateTo(`/empleados/${empleado.id}`)

const handleToggleEstado = async (empleado: Perfil) => {
  const nuevoEstado = !empleado.activo
  try {
    await actualizarEstado(empleado.id, nuevoEstado)
    toast.add({ 
      severity: 'success', 
      summary: 'Éxito', 
      detail: `Empleado ${nuevoEstado ? 'reactivado' : 'desactivado'} correctamente`, 
      life: 3000 
    })
    await load()
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: friendlyError(e), life: 3000 })
  }
}

const handleDelete = (empleado: Perfil) => {
  confirm.require({
    message: `¿Qué deseas hacer con el empleado "${empleado.nombre}"?`,
    header: 'Gestión de Empleado',
    icon: 'pi pi-user-minus',
    acceptLabel: 'Desactivar',
    rejectLabel: 'Eliminar Permanente',
    acceptClass: 'p-button-warning',
    rejectClass: 'p-button-danger p-button-outlined',
    accept: async () => {
      await handleToggleEstado(empleado)
    },
    reject: () => {
      // Usamos un pequeño delay para permitir que el primer modal se cierre completamente
      setTimeout(() => {
        confirm.require({
          message: 'Esta acción borrará al empleado permanentemente y solo es posible si no tiene registros (ventas/compras). ¿Estás seguro?',
          header: 'Confirmar Eliminación Permanente',
          icon: 'pi pi-exclamation-triangle',
          acceptLabel: 'Sí, Eliminar',
          rejectLabel: 'Cancelar',
          acceptClass: 'p-button-danger',
          accept: async () => {
            try {
              await deleteEmpleado(empleado.id)
              toast.add({ severity: 'success', summary: 'Empleado eliminado', life: 2000 })
              await load()
            } catch (e: any) {
              const errorMessage = e.data?.message || e.message || 'Error inesperado al eliminar'
              toast.add({ 
                severity: 'error', 
                summary: 'No se puede eliminar', 
                detail: errorMessage, 
                life: 7000 
              })
            }
          }
        })
      }, 300)
    }
  })
}

onMounted(load)
</script>

<template>
  <div>
    <h1 class="text-2xl font-bold text-slate-800 mb-6">Empleados</h1>

    <EmpleadosEmpleadoTable
      :empleados="empleados"
      :total="total"
      :loading="loading"
      :current-user-id="supaUser?.id"
      :sort-field="sortField"
      :sort-order="sortOrder"
      :mostrar-inactivos="mostrarInactivos"
      @page="handlePage"
      @search="handleSearch"
      @sort="handleSort"
      @edit="handleEdit"
      @delete="handleDelete"
      @toggle-inactivos="mostrarInactivos = $event; load()"
      @toggle-estado="handleToggleEstado"
    />

  </div>
</template>
