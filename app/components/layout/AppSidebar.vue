<script setup lang="ts">
import { Package, ShoppingCart, BarChart3, Settings, Users, LayoutDashboard, UserSquare, Truck, FileText, Wallet, X } from 'lucide-vue-next'
import { useNetworkStore } from '~/stores/network'

const { isAdmin } = usePerfil()
const route = useRoute()
const router = useRouter()
const networkStore = useNetworkStore()
const toast = useToast()

const emit = defineEmits<{ close: [] }>()

const menuItems = computed(() => {
  if (!isAdmin.value) {
    return [
      { label: 'Punto de Venta', icon: ShoppingCart, to: '/pos' }
    ]
  }

  return [
    { label: 'Inicio', icon: LayoutDashboard, to: '/' },
    { label: 'Punto de Venta', icon: ShoppingCart, to: '/pos' },
    { label: 'Caja', icon: Wallet, to: '/caja' },
    { label: 'Inventario', icon: Package, to: '/inventario' },
    { label: 'Compras', icon: FileText, to: '/compras' },
    { label: 'Proveedores', icon: Truck, to: '/proveedores' },
    { label: 'Clientes', icon: UserSquare, to: '/clientes' },
    { label: 'Empleados', icon: Users, to: '/empleados' },
    { label: 'Reportes', icon: BarChart3, to: '/reportes' },
    { label: 'Configuración', icon: Settings, to: '/configuracion' }
  ]
})

const handleNavigation = (e: Event, path: string) => {
  // Siempre permitimos el POS incluso offline
  if (path === '/pos') {
    emit('close')
    return
  }

  // Si está offline y no es el POS, bloqueamos
  if (!networkStore.isOnline) {
    e.preventDefault()
    toast.add({
      severity: 'warn',
      summary: 'Acceso No Disponible',
      detail: 'Esta página requiere conexión a internet.',
      life: 3000
    })
    return
  }

  emit('close')
}

const isActive = (path: string) => {
  if (path === '/') return route.path === '/'
  return route.path.startsWith(path)
}
</script>

<template>
  <aside class="w-full lg:w-64 bg-slate-900 text-white flex flex-col h-full shrink-0">
    <div class="h-16 px-6 border-b border-white/10 flex items-center justify-between gap-2">
      <div class="flex items-center gap-2">
        <img src="/android-icon-48x48.png" alt="motosys logo" class="w-7 h-7 rounded-md" />
        <span class="text-lg font-bold tracking-tight text-white/90">motosys</span>
      </div>
      <button 
        class="lg:hidden p-1 text-slate-400 hover:text-white transition-colors"
        @click="emit('close')"
      >
        <X :size="20" />
      </button>
    </div>

    <nav class="flex-1 p-4 flex flex-col gap-1 overflow-y-auto">
      <NuxtLink
        v-for="item in menuItems"
        :key="item.to"
        :to="item.to"
        class="flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium transition-colors"
        :class="isActive(item.to)
          ? 'bg-blue-600 text-white'
          : 'text-slate-300 hover:bg-slate-800 hover:text-white'"
        @click="handleNavigation($event, item.to)"
      >
        <component :is="item.icon" :size="20" />
        {{ item.label }}
      </NuxtLink>
    </nav>
  </aside>
</template>
