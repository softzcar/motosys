<script setup lang="ts">
import { LogOut, Menu } from 'lucide-vue-next'

const { logout } = useAuth()
const { perfil } = usePerfil()

const emit = defineEmits<{ toggleSidebar: [] }>()
</script>

<template>
  <header class="h-16 bg-white border-b border-slate-200 flex items-center justify-between px-6 shrink-0">
    <div class="flex items-center gap-4">
      <button class="lg:hidden text-slate-600 hover:text-blue-600 transition-colors" @click="emit('toggleSidebar')">
        <Menu :size="24" />
      </button>
      <div class="flex flex-col">
        <h2 class="text-sm font-bold text-slate-700 leading-none">Motorepuestos Accesorios y Lubricantes Parra</h2>
      </div>
    </div>

    <div class="flex items-center gap-4">
      <div v-if="perfil" class="flex flex-col items-end leading-tight">
        <span class="text-sm font-semibold text-slate-800">{{ perfil.nombre }}</span>
        <span 
          class="text-[11px] font-bold px-2 py-0.5 mt-0.5 rounded-full capitalize tracking-wide"
          :class="perfil.rol === 'admin' ? 'bg-amber-100 text-amber-700' : 'bg-blue-100 text-blue-700'"
        >
          {{ perfil.rol }}
        </span>
      </div>
      <div class="w-px h-8 bg-slate-200 mx-1"></div>
      <Button
        severity="secondary"
        text
        rounded
        @click="logout"
        aria-label="Cerrar sesión"
      >
        <LogOut :size="18" />
      </Button>
    </div>
  </header>
</template>
