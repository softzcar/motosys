<script setup lang="ts">
import { markRaw, onMounted } from 'vue'
import { BarChart3, TrendingUp, Users, Package, Wallet, ShoppingCart } from 'lucide-vue-next'

const { isAdmin } = usePerfil()

// Redirección para vendedores (ellos no ven el resumen gerencial)
onMounted(() => {
  if (!isAdmin.value) {
    navigateTo('/pos')
  }
})

const stats = [
  { label: 'Ventas del Día', value: '$1,240.00', icon: markRaw(TrendingUp), color: 'text-emerald-600', bg: 'bg-emerald-50' },
  { label: 'Cierres de Caja', value: '3', icon: markRaw(Wallet), color: 'text-blue-600', bg: 'bg-blue-50' },
  { label: 'Productos Bajos', value: '12', icon: markRaw(Package), color: 'text-orange-600', bg: 'bg-orange-50' },
  { label: 'Clientes Nuevos', value: '5', icon: markRaw(Users), color: 'text-purple-600', bg: 'bg-purple-50' }
]

const recentActivity = [
  { id: 1, action: 'Venta realizada', detail: 'Factura #1024 - $45.00', time: 'hace 5 min' },
  { id: 2, action: 'Stock actualizado', detail: 'Pastillas de freno (10 un.)', time: 'hace 15 min' },
  { id: 3, action: 'Cierre de caja', detail: 'Caja Principal - Turno Mañana', time: 'hace 1 hora' },
  { id: 4, action: 'Nuevo cliente', detail: 'Juan Pérez registrado', time: 'hace 2 horas' }
]
</script>

<template>
  <div class="space-y-6">
    <!-- Header -->
    <div>
      <h1 class="text-2xl font-black text-slate-800 uppercase tracking-tight">Resumen Gerencial</h1>
      <p class="text-slate-500 text-sm">Vista general del estado de tu negocio hoy.</p>
    </div>

    <!-- Stats Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
      <Card v-for="stat in stats" :key="stat.label" class="overflow-hidden border-none shadow-sm">
        <template #content>
          <div class="flex items-center gap-4">
            <div :class="[stat.bg, stat.color, 'p-3 rounded-xl']">
              <component :is="stat.icon" :size="24" />
            </div>
            <div>
              <p class="text-[10px] font-black text-slate-400 uppercase tracking-wider">{{ stat.label }}</p>
              <p class="text-xl font-black text-slate-800">{{ stat.value }}</p>
            </div>
          </div>
        </template>
      </Card>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- Recent Activity -->
      <Card class="lg:col-span-2 border-none shadow-sm">
        <template #title>
          <div class="flex items-center gap-2 px-2 pt-2">
            <BarChart3 class="text-blue-600" :size="18" />
            <span class="text-sm font-black uppercase tracking-tight">Actividad Reciente</span>
          </div>
        </template>
        <template #content>
          <div class="space-y-4">
            <div v-for="item in recentActivity" :key="item.id" class="flex items-start justify-between p-3 rounded-lg hover:bg-slate-50 transition-colors border border-slate-100">
              <div class="flex gap-3">
                <div class="mt-1 w-2 h-2 rounded-full bg-blue-500"></div>
                <div>
                  <p class="text-sm font-bold text-slate-800">{{ item.action }}</p>
                  <p class="text-xs text-slate-500">{{ item.detail }}</p>
                </div>
              </div>
              <span class="text-[10px] font-medium text-slate-400 uppercase">{{ item.time }}</span>
            </div>
          </div>
        </template>
      </Card>

      <!-- Quick Actions -->
      <Card class="border-none shadow-sm bg-slate-900 text-white">
        <template #title>
          <span class="text-sm font-black uppercase tracking-tight text-white/90">Acceso Rápido</span>
        </template>
        <template #content>
          <div class="grid grid-cols-1 gap-2">
            <Button 
              label="NUEVA VENTA (POS)" 
              class="w-full justify-start font-bold text-xs"
              severity="primary"
              @click="navigateTo('/pos')"
            >
              <template #icon>
                <ShoppingCart :size="16" class="mr-2" />
              </template>
            </Button>
            <Button 
              label="GESTIONAR INVENTARIO" 
              class="w-full justify-start font-bold text-xs"
              text
              @click="navigateTo('/inventario')"
            >
              <template #icon>
                <Package :size="16" class="mr-2" />
              </template>
            </Button>
            <Button 
              label="VER REPORTES" 
              class="w-full justify-start font-bold text-xs"
              text
              @click="navigateTo('/reportes')"
            >
              <template #icon>
                <BarChart3 :size="16" class="mr-2" />
              </template>
            </Button>
          </div>
        </template>
      </Card>
    </div>
  </div>
</template>
