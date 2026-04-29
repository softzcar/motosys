<script setup lang="ts">
import { LogOut, Menu, RefreshCcw } from 'lucide-vue-next'
import { useNetworkStore } from '~/stores/network'

const { logout } = useAuth() // Vincular función de salida
const { perfil } = usePerfil()
const networkStore = useNetworkStore()
const confirm = useConfirm()

const handleLogout = () => {
  confirm.require({
    message: '¿Estás seguro de que deseas salir del sistema?',
    header: 'Confirmar Salida',
    icon: 'pi pi-exclamation-triangle',
    rejectProps: {
      label: 'Cancelar',
      severity: 'secondary',
      outlined: true
    },
    acceptProps: {
      label: 'Cerrar Sesión',
      severity: 'danger'
    },
    accept: async () => {
      // Limpieza de rastro local SIEMPRE (crítico para que el middleware no restaure sesión)
      const { db } = await import('~/composables/useOfflineDb')
      await db.perfil.clear()

      if (!networkStore.isOnline) {
        return navigateTo('/login')
      }

      try {
        await logout()
      } catch (e) {
        console.error('Error cerrando sesión online:', e)
        return navigateTo('/login')
      }
    }
  })
}

const emit = defineEmits<{ toggleSidebar: [] }>()
</script>

<template>
  <header class="h-16 bg-white border-b border-slate-200 flex items-center justify-between px-6 shrink-0">
    <div class="flex items-center gap-4">
      <button class="lg:hidden text-slate-600 hover:text-blue-600 transition-colors" @click="emit('toggleSidebar')">
        <Menu :size="24" />
      </button>
      <div class="flex flex-col">
        <h2 class="text-sm font-bold text-slate-700 leading-none truncate max-w-[150px] md:max-w-none">
          Motorepuestos Accesorios y Lubricantes Parra
        </h2>
      </div>
    </div>

    <div class="flex items-center gap-4 md:gap-6">
      <!-- Indicador de Red Global -->
      <div class="flex items-center gap-3">
         <div v-if="networkStore.isSyncing" class="flex items-center gap-2 px-3 py-1 bg-blue-50 text-blue-600 rounded-full">
            <RefreshCcw :size="12" class="animate-spin" />
            <span class="hidden sm:inline text-[10px] font-black uppercase tracking-widest">Sincronizando...</span>
         </div>

         <div 
            class="flex items-center gap-2 px-2.5 py-1 rounded-full text-[9px] font-black uppercase tracking-tighter border transition-all duration-500"
            :class="networkStore.isOnline ? 'bg-emerald-50 text-emerald-600 border-emerald-200' : 'bg-orange-50 text-orange-600 border-orange-200 animate-pulse'"
         >
            <div class="w-1.5 h-1.5 rounded-full" :class="networkStore.isOnline ? 'bg-emerald-500 shadow-[0_0_6px_rgba(16,185,129,0.5)]' : 'bg-orange-500 shadow-[0_0_8px_rgba(249,115,22,0.5)]'"></div>
            {{ networkStore.isOnline ? 'Online' : 'Offline' }}
         </div>
      </div>

      <!-- Perfil y Salida -->
      <div class="flex items-center gap-4">
        <div v-if="perfil" class="hidden md:flex flex-col items-end leading-tight">
          <span class="text-sm font-semibold text-slate-800">{{ perfil.nombre }}</span>
          <span 
            class="text-[10px] font-bold px-2 py-0.5 mt-0.5 rounded-full capitalize tracking-wide border"
            :class="perfil.rol === 'admin' ? 'bg-amber-50 text-amber-700 border-amber-100' : 'bg-blue-50 text-blue-700 border-blue-100'"
          >
            {{ perfil.rol }}
          </span>
        </div>
        
        <div class="hidden md:block w-px h-8 bg-slate-200 mx-1"></div>
        
        <Button
          severity="secondary"
          text
          rounded
          @click="handleLogout"
          aria-label="Cerrar sesión"
        >
          <LogOut :size="18" />
        </Button>
      </div>
    </div>
  </header>
</template>
