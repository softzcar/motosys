<script setup lang="ts">
import type { Perfil } from '~/types/database'

const route = useRoute()
const { fetchEmpleado, updateEmpleado, friendlyError } = useEmpleados()
const { isAdmin } = usePerfil()
const toast = useToast()

if (!isAdmin.value) {
  await navigateTo('/')
}

const empleado = ref<Perfil | null>(null)
const loading = ref(true)
const saving = ref(false)

const load = async () => {
  try {
    empleado.value = await fetchEmpleado(route.params.id as string)
  } catch {
    toast.add({ severity: 'error', summary: 'Empleado no encontrado', life: 3000 })
    await navigateTo('/empleados')
    return
  }
  loading.value = false
}

const handleSubmit = async (data: { nombre: string; rol: 'admin' | 'vendedor'; email?: string; password?: string }) => {
  if (!empleado.value) return
  saving.value = true
  try {
    await updateEmpleado(empleado.value.id, data)
    toast.add({ severity: 'success', summary: 'Cambios guardados', life: 2000 })
    await navigateTo('/empleados')
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'No se pudo guardar', detail: friendlyError(e), life: 4000 })
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>

<template>
  <div class="max-w-2xl">
    <h1 class="text-2xl font-bold text-slate-800 mb-6">Editar Empleado</h1>

    <div v-if="loading" class="flex justify-center py-12">
      <ProgressSpinner />
    </div>

    <div v-else-if="empleado" class="bg-white rounded-xl p-6 shadow-sm">
      <EmpleadosEmpleadoForm
        :empleado="empleado"
        :loading="saving"
        @submit="handleSubmit"
        @cancel="navigateTo('/empleados')"
      />
    </div>
  </div>
</template>
