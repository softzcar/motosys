<script setup lang="ts">
import type { Perfil } from '~/types/database'

const props = defineProps<{
  empleado?: Perfil
  loading?: boolean
}>()

const emit = defineEmits<{
  submit: [data: { nombre: string; email?: string; password?: string; rol: 'admin' | 'vendedor' }]
  cancel: []
}>()

const isEdit = computed(() => !!props.empleado)

const form = ref({
  nombre: props.empleado?.nombre ?? '',
  email: '',
  password: '',
  confirmar: '',
  rol: (props.empleado?.rol ?? 'vendedor') as 'admin' | 'vendedor'
})

const errors = ref<Record<string, string>>({})
const submitted = ref(false)

const validate = () => {
  const e: Record<string, string> = {}

  const nombre = form.value.nombre.trim()
  if (!nombre) e.nombre = 'El nombre es obligatorio'
  else if (nombre.length < 3) e.nombre = 'Debe tener al menos 3 caracteres'
  else if (nombre.length > 80) e.nombre = 'Máximo 80 caracteres'

  const email = form.value.email.trim()
  if (!isEdit.value && !email) e.email = 'El correo es obligatorio'
  else if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) e.email = 'Ingresa un correo válido'

  if (!isEdit.value && !form.value.password) e.password = 'La contraseña es obligatoria'
  else if (form.value.password && form.value.password.length < 8) e.password = 'Mínimo 8 caracteres'

  if (form.value.password && !form.value.confirmar) e.confirmar = 'Confirma la contraseña'
  else if (form.value.confirmar !== form.value.password) e.confirmar = 'Las contraseñas no coinciden'

  if (form.value.rol !== 'admin' && form.value.rol !== 'vendedor') e.rol = 'Selecciona un rol'

  errors.value = e
  return Object.keys(e).length === 0
}

watch(form, () => { if (submitted.value) validate() }, { deep: true })

const roles = [
  { label: 'Vendedor', value: 'vendedor' },
  { label: 'Administrador', value: 'admin' }
]

const handleSubmit = () => {
  submitted.value = true
  if (!validate()) return

  const payload: any = {
    nombre: form.value.nombre.trim(),
    rol: form.value.rol
  }
  
  if (form.value.email.trim()) payload.email = form.value.email.trim().toLowerCase()
  if (form.value.password) payload.password = form.value.password

  emit('submit', payload)
}
</script>

<template>
  <form @submit.prevent="handleSubmit" class="flex flex-col gap-5" novalidate>
    <div class="flex flex-col gap-1.5">
      <label for="nombre" class="text-sm font-medium text-slate-700">
        Nombre completo <span class="text-red-500">*</span>
      </label>
      <InputText id="nombre" v-model="form.nombre" placeholder="Juan Pérez" :invalid="!!errors.nombre" />
      <small v-if="errors.nombre" class="text-red-600">{{ errors.nombre }}</small>
    </div>

    <div class="flex flex-col gap-1.5">
      <label for="email" class="text-sm font-medium text-slate-700">
        Correo electrónico <span v-if="!isEdit" class="text-red-500">*</span>
      </label>
      <InputText id="email" v-model="form.email" type="email" :placeholder="isEdit ? 'Dejar en blanco para mantener el actual' : 'juan@empresa.com'" :invalid="!!errors.email" />
      <small v-if="errors.email" class="text-red-600">{{ errors.email }}</small>
    </div>

    <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
      <div class="flex flex-col gap-1.5">
        <label for="password" class="text-sm font-medium text-slate-700">
          Contraseña <span v-if="!isEdit" class="text-red-500">*</span>
          <span v-else class="text-slate-400 font-normal ml-1">(Opcional)</span>
        </label>
        <Password
          id="password"
          v-model="form.password"
          toggle-mask
          :feedback="false"
          input-class="w-full"
          class="w-full"
          :invalid="!!errors.password"
        />
        <small v-if="errors.password" class="text-red-600">{{ errors.password }}</small>
      </div>
      <div class="flex flex-col gap-1.5">
        <label for="confirmar" class="text-sm font-medium text-slate-700">
          Confirmar contraseña <span v-if="!isEdit" class="text-red-500">*</span>
        </label>
        <Password
          id="confirmar"
          v-model="form.confirmar"
          toggle-mask
          :feedback="false"
          input-class="w-full"
          class="w-full"
          :invalid="!!errors.confirmar"
        />
        <small v-if="errors.confirmar" class="text-red-600">{{ errors.confirmar }}</small>
      </div>
    </div>

    <div class="flex flex-col gap-1.5">
      <label class="text-sm font-medium text-slate-700">
        Rol <span class="text-red-500">*</span>
      </label>
      <Select
        v-model="form.rol"
        :options="roles"
        option-label="label"
        option-value="value"
        placeholder="Selecciona un rol"
        :invalid="!!errors.rol"
      />
      <small class="text-slate-500">Los administradores pueden gestionar productos y empleados.</small>
      <small v-if="errors.rol" class="text-red-600">{{ errors.rol }}</small>
    </div>

    <div class="flex gap-2 justify-end mt-2">
      <Button type="button" label="Cancelar" severity="secondary" :disabled="loading" @click="emit('cancel')" />
      <Button type="submit" :loading="loading" :label="isEdit ? 'Guardar cambios' : 'Crear empleado'" />
    </div>
  </form>
</template>
