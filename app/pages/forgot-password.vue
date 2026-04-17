<script setup lang="ts">
definePageMeta({ layout: 'auth' })

const { recoverPassword } = useAuth()
const email = ref('')
const loading = ref(false)
const error = ref('')
const success = ref(false)

const handleRecover = async () => {
  error.value = ''
  loading.value = true
  try {
    await recoverPassword(email.value)
    success.value = true
  } catch (e: any) {
    error.value = e.message || 'Error al enviar el correo. Verifica tu dirección.'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="flex flex-col gap-4">
    <h2 class="text-xl font-semibold text-slate-800">Recuperar Contraseña</h2>
    
    <Message v-if="success" severity="success" :closable="false">
      Si el correo existe, te enviaremos un enlace para restablecer tu contraseña. Revisa tu bandeja de entrada o spam.
    </Message>
    
    <Message v-else-if="error" severity="error" :closable="false">{{ error }}</Message>

    <form v-if="!success" @submit.prevent="handleRecover" class="flex flex-col gap-4">
      <p class="text-sm text-slate-600">
        Ingresa el correo electrónico asociado a tu cuenta y te enviaremos instrucciones.
      </p>

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

      <Button
        type="submit"
        label="Enviar enlace"
        :loading="loading"
        class="w-full mt-2"
      />
    </form>

    <div class="mt-4 text-center">
      <NuxtLink to="/login" class="text-sm text-blue-600 hover:underline inline-flex items-center gap-1">
        <i class="pi pi-arrow-left text-xs"></i> Volver al inicio de sesión
      </NuxtLink>
    </div>
  </div>
</template>
