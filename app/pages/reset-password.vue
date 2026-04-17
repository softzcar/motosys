<script setup lang="ts">
definePageMeta({ layout: 'auth' })

const { updatePassword } = useAuth()
const password = ref('')
const confirmar = ref('')
const loading = ref(false)
const error = ref('')
const success = ref(false)

const handleReset = async () => {
  error.value = ''
  
  if (password.value.length < 8) {
    error.value = 'La contraseña debe tener al menos 8 caracteres'
    return
  }
  if (password.value !== confirmar.value) {
    error.value = 'Las contraseñas no coinciden'
    return
  }

  loading.value = true
  try {
    await updatePassword(password.value)
    success.value = true
    setTimeout(() => {
      navigateTo('/inventario')
    }, 2000)
  } catch (e: any) {
    error.value = e.message || 'Error al actualizar la contraseña'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="flex flex-col gap-4">
    <h2 class="text-xl font-semibold text-slate-800">Nueva Contraseña</h2>

    <Message v-if="success" severity="success" :closable="false">
      ¡Contraseña actualizada con éxito! Redirigiendo...
    </Message>

    <Message v-else-if="error" severity="error" :closable="false">{{ error }}</Message>

    <form v-if="!success" @submit.prevent="handleReset" class="flex flex-col gap-4">
      <p class="text-sm text-slate-600">
        Por favor ingresa tu nueva contraseña a continuación.
      </p>

      <div class="flex flex-col gap-2">
        <label for="password" class="text-sm font-medium text-slate-700">Contraseña</label>
        <Password
          id="password"
          v-model="password"
          toggle-mask
          :feedback="false"
          input-class="w-full"
          class="w-full"
          required
        />
      </div>

      <div class="flex flex-col gap-2">
        <label for="confirmar" class="text-sm font-medium text-slate-700">Confirmar contraseña</label>
        <Password
          id="confirmar"
          v-model="confirmar"
          toggle-mask
          :feedback="false"
          input-class="w-full"
          class="w-full"
          required
        />
      </div>

      <Button
        type="submit"
        label="Guardar nueva contraseña"
        :loading="loading"
        class="w-full mt-2"
      />
    </form>
  </div>
</template>
