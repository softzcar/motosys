<script setup lang="ts">
import { Package, ShoppingCart, BarChart3, Settings, Users, LayoutDashboard, UserSquare, Truck, FileText, Wallet } from 'lucide-vue-next'

const { isAdmin } = usePerfil()
const route = useRoute()

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
    { label: 'Compras', icon: FileText, to: '/compras' },
    { label: 'Proveedores', icon: Truck, to: '/proveedores' },
    { label: 'Clientes', icon: UserSquare, to: '/clientes' },
    { label: 'Empleados', icon: Users, to: '/empleados' },
    { label: 'Inventario', icon: Package, to: '/inventario' },
    { label: 'Reportes', icon: BarChart3, to: '/reportes' },
    { label: 'Configuración', icon: Settings, to: '/configuracion' }
  ]
})

const isActive = (path: string) => {
  if (path === '/') return route.path === '/'
  return route.path.startsWith(path)
}
</script>

<template>
  <aside class="w-64 bg-slate-900 text-white flex flex-col h-screen shrink-0">
    <div class="h-16 px-6 border-b border-white/10 flex items-center gap-2">
      <img src="/android-icon-48x48.png" alt="motosys logo" class="w-7 h-7 rounded-md" />
      <span class="text-lg font-bold tracking-tight text-white/90">motosys</span>
    </div>

    <nav class="flex-1 p-4 flex flex-col gap-1">
      <NuxtLink
        v-for="item in menuItems"
        :key="item.to"
        :to="item.to"
        class="flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium transition-colors"
        :class="isActive(item.to)
          ? 'bg-blue-600 text-white'
          : 'text-slate-300 hover:bg-slate-800 hover:text-white'"
      >
        <component :is="item.icon" :size="20" />
        {{ item.label }}
      </NuxtLink>
    </nav>
  </aside>
</template>
