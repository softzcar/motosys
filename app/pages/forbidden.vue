<script setup lang="ts">
import { ShieldAlert, ArrowLeft, Home } from 'lucide-vue-next'

const { perfil } = usePerfil()

const goBack = () => {
  if (perfil.value?.rol === 'vendedor') {
    navigateTo('/pos')
  } else {
    navigateTo('/')
  }
}
</script>

<template>
  <div class="min-h-screen bg-slate-50 flex items-center justify-center p-6">
    <div class="max-w-md w-full bg-white rounded-2xl shadow-xl border border-slate-200 p-8 text-center">
      <div class="w-20 h-20 bg-rose-100 text-rose-600 rounded-full flex items-center justify-center mx-auto mb-6">
        <ShieldAlert :size="48" />
      </div>
      
      <h1 class="text-2xl font-black text-slate-900 mb-2 uppercase tracking-tight">Acceso Denegado</h1>
      <p class="text-slate-500 mb-8 leading-relaxed">
        Lo sentimos, no tienes los permisos necesarios para acceder a esta sección del sistema. 
        Esta acción ha sido registrada por seguridad.
      </p>

      <div class="flex flex-col gap-3">
        <Button @click="goBack" severity="primary" class="w-full flex items-center justify-center gap-2 h-12 font-bold uppercase tracking-wide">
          <Home :size="18" />
          Volver al Inicio
        </Button>
        <Button @click="navigateTo('/login')" variant="text" severity="secondary" class="w-full text-xs font-bold uppercase text-slate-400">
          Cerrar Sesión
        </Button>
      </div>
    </div>
  </div>
</template>
