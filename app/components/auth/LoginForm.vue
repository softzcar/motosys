<script setup lang="ts">
import { ref } from 'vue'

const { login } = useAuth()

const email = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')

const handleLogin = async () => {
  error.value = ''
  loading.value = true
  try {
    await login(email.value, password.value)
  } catch (e: any) {
    error.value = e.message || 'Error al iniciar sesión'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <form @submit.prevent="handleLogin" class="flex flex-col gap-4">
    <h2 class="text-xl font-semibold text-slate-800">Iniciar Sesión</h2>

    <Message v-if="error" severity="error" :closable="false">{{ error }}</Message>

    <div class="flex flex-col gap-2">
      <label for="email" class="text-sm font-medium text-slate-700">Email</label>
      <InputText
        id="email"
        v-model="email"
        type="email"
        placeholder="correo@empresa.com"
        required
      />
    </div>

    <div class="flex flex-col gap-1">
      <label for="password" class="text-sm font-medium text-slate-700">Contraseña</label>
      <Password
        id="password"
        v-model="password"
        :feedback="false"
        toggle-mask
        input-class="w-full"
        required
      />
      <div class="flex justify-end">
        <NuxtLink to="/forgot-password" class="text-xs text-blue-600 hover:underline">¿Olvidaste tu contraseña?</NuxtLink>
      </div>
    </div>

    <Button
      label="Entrar"
      :loading="loading"
      class="w-full"
      @click="handleLogin"
    />

    <p class="text-center text-sm text-slate-500">
      ¿No tienes cuenta?
      <NuxtLink to="/register" class="text-blue-600 hover:underline">Regístrate aquí</NuxtLink>
    </p>
  </form>
</template>
