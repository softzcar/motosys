<script setup lang="ts">
import { ref } from 'vue'

const { register } = useAuth()

const step = ref(1)
const loading = ref(false)
const error = ref('')

const form = ref({
  nombre: '',
  email: '',
  password: ''
})

const handleRegister = async () => {
  error.value = ''
  loading.value = true
  try {
    await register(form.value)
  } catch (e: any) {
    error.value = e.message || 'Error al registrarse'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <form @submit.prevent="handleRegister" class="flex flex-col gap-4">
    <h2 class="text-xl font-semibold text-slate-800">Crear Cuenta Admin</h2>

    <Message v-if="error" severity="error" :closable="false">{{ error }}</Message>

    <template v-if="true">
      <div class="flex flex-col gap-2">
        <label class="text-sm font-medium text-slate-700">Tu Nombre</label>
        <InputText
          v-model="form.nombre"
          placeholder="Juan Pérez"
          required
        />
      </div>

      <div class="flex flex-col gap-2">
        <label class="text-sm font-medium text-slate-700">Email</label>
        <InputText
          v-model="form.email"
          type="email"
          placeholder="correo@empresa.com"
          required
        />
      </div>

      <div class="flex flex-col gap-2">
        <label class="text-sm font-medium text-slate-700">Contraseña</label>
        <Password
          v-model="form.password"
          toggle-mask
          input-class="w-full"
          required
        />
      </div>

      <div class="flex gap-2">
        <Button
          type="submit"
          label="Crear Cuenta"
          :loading="loading"
          class="w-full"
        />
      </div>
    </template>

    <p class="text-center text-sm text-slate-500">
      ¿Ya tienes cuenta?
      <NuxtLink to="/login" class="text-blue-600 hover:underline">Inicia sesión</NuxtLink>
    </p>
  </form>
</template>
