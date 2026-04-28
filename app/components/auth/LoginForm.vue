<script setup lang="ts">
import { useOfflineDb, db } from '~/composables/useOfflineDb'
import { useNetworkStore } from '~/stores/network'

const { login } = useAuth()
const { fetchPerfil } = usePerfil()
const networkStore = useNetworkStore()
const toast = useToast()

const email = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')

const handleLogin = async () => {
  error.value = ''
  loading.value = true
  
  try {
    if (networkStore.isOnline) {
      // --- LOGIN ONLINE ---
      await login(email.value, password.value)
      
      if (import.meta.client) {
        await fetchPerfil() 
      }
      
      return navigateTo('/pos')
    } else {
      // --- LOGIN OFFLINE ---
      console.log('🔐 Intentando acceso de emergencia offline...')
      const { cachePerfil } = useOfflineDb()
      
      // Acceso directo a la DB para evitar problemas de caché con el composable
      const authorizedUser = await db.profiles_cache.get(email.value)
      
      if (authorizedUser) {
        // Restaurar este perfil como 'Sesión Activa' en Dexie
        await cachePerfil(authorizedUser)
        
        toast.add({
          severity: 'info',
          summary: 'Acceso Offline',
          detail: `Bienvenido de nuevo, ${authorizedUser.nombre}. Operando en local.`,
          life: 5000
        })
        return navigateTo('/pos')
      } else {
        throw new Error('Este usuario no está registrado para acceso offline en este equipo.')
      }
    }
  } catch (e: any) {
    error.value = e.message || 'Error al iniciar sesión'
  } finally {
    loading.value = false
  }
}
onMounted(() => {
  console.log('✅ LoginForm montado correctamente')
})
</script>

<template>
  <form @submit.prevent="handleLogin" class="flex flex-col gap-4">
    <div class="text-center mb-2">
      <h2 class="text-2xl font-black text-slate-800 uppercase tracking-tight">MotoSys</h2>
      <p class="text-xs font-bold text-slate-400 uppercase tracking-widest">Sistema de Gestión</p>
    </div>

    <Message v-if="error" severity="error" :closable="false">{{ error }}</Message>
    
    <div v-if="!networkStore.isOnline" class="p-3 bg-orange-50 border border-orange-200 rounded-lg flex items-center gap-3 animate-pulse">
       <div class="w-2 h-2 rounded-full bg-orange-500"></div>
       <span class="text-[10px] font-black text-orange-700 uppercase tracking-wider">Modo de Emergencia Offline Activo</span>
    </div>

    <div class="flex flex-col gap-2">
      <label for="email" class="text-xs font-black text-slate-500 uppercase tracking-wider">Correo Electrónico</label>
      <InputText
        id="email"
        v-model="email"
        type="email"
        placeholder="usuario@empresa.com"
        class="h-12"
        required
      />
    </div>

    <div class="flex flex-col gap-1">
      <label for="password" class="text-xs font-black text-slate-500 uppercase tracking-wider">Contraseña</label>
      <Password
        id="password"
        v-model="password"
        :feedback="false"
        toggle-mask
        input-class="w-full h-12"
        placeholder="••••••••"
        required
      />
      <div class="flex justify-end mt-1" v-if="networkStore.isOnline">
        <NuxtLink to="/forgot-password" class="text-[11px] font-bold text-blue-600 hover:underline uppercase">¿Olvidó su clave?</NuxtLink>
      </div>
    </div>

    <Button
      :label="networkStore.isOnline ? 'INICIAR SESIÓN' : 'ENTRAR SIN CONEXIÓN'"
      :loading="loading"
      :severity="networkStore.isOnline ? 'primary' : 'warning'"
      class="h-12 font-black tracking-widest"
      @click="handleLogin"
    />

    <p class="text-center text-[10px] text-slate-400 font-bold uppercase mt-2">
      MotoSys v2.0 - Resiliencia Activa
    </p>
  </form>
</template>
