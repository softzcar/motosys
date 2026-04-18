<script setup lang="ts">
const { createEmpleado, friendlyError } = useEmpleados()
const { isAdmin } = usePerfil()
const toast = useToast()

if (!isAdmin.value) {
  await navigateTo('/')
}

const saving = ref(false)

const handleSubmit = async (data: { nombre: string; email?: string; password?: string; rol: 'admin' | 'vendedor' }) => {
  saving.value = true
  try {
    await createEmpleado({
      nombre: data.nombre,
      email: data.email!,
      password: data.password!,
      rol: data.rol
    })
    toast.add({ severity: 'success', summary: 'Empleado creado', detail: data.nombre, life: 2000 })
    await navigateTo('/empleados')
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'No se pudo crear', detail: friendlyError(e), life: 4000 })
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="max-w-2xl">
    <h1 class="text-2xl font-bold text-slate-800 mb-6">Nuevo Empleado</h1>
    <div class="bg-white rounded-xl p-6 shadow-sm">
      <EmpleadosEmpleadoForm :loading="saving" @submit="handleSubmit" @cancel="navigateTo('/empleados')" />
    </div>
  </div>
</template>
