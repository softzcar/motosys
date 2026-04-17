<script setup lang="ts">
import { 
  TrendingUp, 
  ShoppingCart, 
  Package, 
  Users, 
  ArrowUpRight, 
  ArrowDownRight,
  Activity,
  AlertTriangle,
  Eye,
  Coins
} from 'lucide-vue-next'

const { perfil, isAdmin } = usePerfil()
const { fetchVentas, fetchVentaById } = useVentas()
const { fetchInventarioStats } = useProductos()
const { fetchClientes } = useClientes()
const { fetchTasas } = useTasas()
const client = useSupabaseClient()
const toast = useToast()

// Redireccionar si es vendedor
watch(isAdmin, (admin) => {
  if (admin === false) navigateTo('/pos')
}, { immediate: true })

useSeoMeta({
  title: 'Panel de Control - MotoSys',
  description: 'Resumen general del estado de tu negocio.'
})

const loading = ref(true)
const ventasHoy = ref(0)
const totalStock = ref(0)
const clientesNuevos = ref(0)
const bajoStock = ref(0)
const ultimasVentas = ref<any[]>([])
const productosMasVendidos = ref<any[]>([])
const ventasSemana = ref<{ label: string, total: number }[]>([])
const tasas = ref<any[]>([])
const chartPeriod = ref('Semanal')

// Ver detalle
const selectedVenta = ref<any>(null)
const showDetailDialog = ref(false)
const showTasasDialog = ref(false)

const verDetalleVenta = async (venta: any) => {
  try {
    loading.value = true
    const fullVenta = await fetchVentaById(venta.id)
    selectedVenta.value = fullVenta
    showDetailDialog.value = true
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error al cargar detalle', detail: e.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

// Formatear moneda
const formatCurrency = (val: number) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD'
  }).format(val)
}

// Formatear tiempo relativo
const timeAgo = (date: string) => {
  const now = new Date()
  const then = new Date(date)
  const seconds = Math.floor((now.getTime() - then.getTime()) / 1000)
  
  if (seconds < 60) return 'Hace un momento'
  const minutes = Math.floor(seconds / 60)
  if (minutes < 60) return `Hace ${minutes} min`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `Hace ${hours} h`
  return then.toLocaleDateString()
}

const loadStats = async () => {
  loading.value = true
  try {
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const tomorrow = new Date(today)
    tomorrow.setDate(tomorrow.getDate() + 1)

    // Configurar rango según periodo
    const startDate = new Date(today)
    if (chartPeriod.value === 'Semanal') {
      startDate.setDate(startDate.getDate() - 6)
    } else {
      startDate.setDate(startDate.getDate() - 29)
    }

    // 1. Ventas del día
    const { data: salesToday } = await fetchVentas({
      desde: today.toISOString(),
      hasta: tomorrow.toISOString(),
      incluirAnuladas: false,
      rows: 1000 
    })
    ventasHoy.value = salesToday.reduce((acc, v) => acc + Number(v.total), 0)

    // 2. Tasas del día
    const tasasData = await fetchTasas()
    tasas.value = tasasData

    // 3. Clientes nuevos (hoy)
    const { count } = await client
      .from('clientes')
      .select('*', { count: 'exact', head: true })
      .gte('created_at', today.toISOString())
      .lte('created_at', tomorrow.toISOString())
    
    clientesNuevos.value = count || 0

    // 4. Actividad reciente (últimas 5 ventas)
    const { data: recentSales } = await fetchVentas({
      rows: 5,
      sortField: 'fecha',
      sortOrder: -1 // Descendente
    })
    ultimasVentas.value = recentSales

    // 5. Productos más vendidos
    const { data: allDetails } = await client
      .from('detalle_ventas')
      .select('cantidad, producto_id, productos(nombre)')
      .limit(300)

    const productMap = new Map()
    allDetails?.forEach((d: any) => {
      if (!d.productos) return
      const current = productMap.get(d.producto_id) || { nombre: d.productos.nombre, cantidad: 0 }
      current.cantidad += d.cantidad
      productMap.set(d.producto_id, current)
    })

    productosMasVendidos.value = Array.from(productMap.values())
      .sort((a, b) => b.cantidad - a.cantidad)
      .slice(0, 4)

    // 6. Tendencia de ventas
    const { data: trendSales } = await fetchVentas({
      desde: startDate.toISOString(),
      incluirAnuladas: false,
      rows: 1000
    })

    const salesByPeriod = new Map()
    const iterations = chartPeriod.value === 'Semanal' ? 7 : 30
    
    for (let i = 0; i < iterations; i++) {
      const d = new Date(startDate)
      d.setDate(d.getDate() + i)
      const dateKey = d.toISOString().split('T')[0]
      
      let label = ''
      if (chartPeriod.value === 'Semanal') {
        const days = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb']
        label = days[d.getDay()]
      } else {
        label = d.getDate().toString()
      }

      salesByPeriod.set(dateKey, {
        label,
        total: 0
      })
    }

    trendSales?.forEach((v: any) => {
      const dateKey = v.fecha.split('T')[0]
      if (salesByPeriod.has(dateKey)) {
        salesByPeriod.get(dateKey).total += Number(v.total)
      }
    })

    ventasSemana.value = Array.from(salesByPeriod.values())

    // 7. Bajo Stock count (para la stat)
    const invStats = await fetchInventarioStats()
    bajoStock.value = invStats.bajoStockCount

  } catch (e) {
    console.error('Error al cargar estadísticas:', e)
  } finally {
    loading.value = false
  }
}

watch(chartPeriod, () => {
  loadStats()
})

onMounted(() => {
  loadStats()
})

const stats = computed(() => [
  { 
    label: 'Ventas del Día', 
    value: formatCurrency(ventasHoy.value), 
    change: 'Hoy', 
    trend: 'up', 
    icon: ShoppingCart, 
    color: 'text-blue-600',
    bg: 'bg-blue-50',
    to: '/reportes/ventas'
  },
  { 
    label: 'Tasas del Día', 
    value: '', 
    change: 'Configuradas', 
    trend: 'up', 
    icon: Coins, 
    color: 'text-orange-600',
    bg: 'bg-orange-50',
    isTasas: true,
    to: '/configuracion'
  },
  { 
    label: 'Clientes Nuevos', 
    value: clientesNuevos.value.toString(), 
    change: 'Hoy', 
    trend: 'up', 
    icon: Users, 
    color: 'text-purple-600',
    bg: 'bg-purple-50',
    to: '/clientes'
  },
  { 
    label: 'Bajo Stock', 
    value: bajoStock.value.toString(), 
    change: '< 5 unidades', 
    trend: bajoStock.value > 0 ? 'down' : 'up', 
    icon: AlertTriangle, 
    color: bajoStock.value > 0 ? 'text-rose-600' : 'text-emerald-600',
    bg: bajoStock.value > 0 ? 'bg-rose-50' : 'bg-emerald-50',
    to: '/inventario'
  }
])
</script>

<template>
  <div class="space-y-8">
    <!-- Header -->
    <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">
      <div>
        <h1 class="text-3xl font-bold text-slate-900 tracking-tight">
          ¡Hola, {{ perfil?.nombre || 'Bienvenido' }}! 👋
        </h1>
        <p class="text-slate-500 mt-1">Este es el resumen de tu negocio para el día de hoy.</p>
      </div>
      <div class="flex items-center gap-3">
        <NuxtLink 
          to="/pos" 
          class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 transition-colors shadow-sm shadow-blue-200"
        >
          Nueva Venta
        </NuxtLink>
      </div>
    </div>

    <!-- Stats Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
      <div 
        v-for="stat in stats" 
        :key="stat.label"
        @click="stat.isTasas ? showTasasDialog = true : navigateTo(stat.to)"
        class="bg-white p-6 rounded-2xl border border-slate-100 shadow-sm hover:shadow-md transition-all group relative overflow-hidden cursor-pointer"
      >
        <div class="flex items-center justify-between mb-4">
          <div :class="[stat.bg, stat.color, 'p-3 rounded-xl transition-transform group-hover:scale-110']">
            <component :is="stat.icon" class="w-6 h-6" />
          </div>
          <div class="flex items-center gap-2">
            <div :class="[
              stat.trend === 'up' ? 'text-emerald-600 bg-emerald-50' : 'text-rose-600 bg-rose-50',
              'flex items-center gap-1 px-2 py-1 rounded-full text-xs font-bold'
            ]">
              <component :is="stat.trend === 'up' ? ArrowUpRight : ArrowDownRight" class="w-3 h-3" />
              {{ stat.change }}
            </div>
            <ArrowUpRight class="w-4 h-4 text-slate-300 group-hover:text-blue-500 transition-colors" />
          </div>
        </div>
        <div>
          <p class="text-sm font-medium text-slate-500">{{ stat.label }}</p>
          <div v-if="stat.isTasas" class="mt-1 space-y-1">
            <div v-for="t in tasas" :key="t.codigo" class="flex items-center justify-between text-xs">
              <span class="font-bold text-slate-700">{{ t.codigo }}:</span>
              <span class="text-slate-900 font-mono">{{ t.tasa.toFixed(2) }}</span>
            </div>
            <div v-if="tasas.length === 0" class="text-xs text-slate-400">Sin tasas</div>
          </div>
          <p v-else class="text-2xl font-bold text-slate-900 mt-1">{{ stat.value }}</p>
        </div>
      </div>
    </div>

    <!-- Charts Section Placeholder -->
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- Main Chart -->
      <div class="lg:col-span-2 bg-white p-6 rounded-2xl border border-slate-100 shadow-sm">
        <div class="flex items-center justify-between mb-8">
          <div>
            <h3 class="text-lg font-bold text-slate-900">Tendencia de Ventas</h3>
            <p class="text-sm text-slate-500">
              {{ chartPeriod === 'Semanal' ? 'Volumen de ventas en los últimos 7 días' : 'Volumen de ventas en los últimos 30 días' }}
            </p>
          </div>
          <select 
            v-model="chartPeriod"
            class="bg-slate-50 border-none text-sm text-slate-600 rounded-lg px-3 py-2 outline-none cursor-pointer"
          >
            <option value="Semanal">Semanal</option>
            <option value="Mensual">Mensual</option>
          </select>
        </div>
        
        <!-- Chart Section -->
        <div 
          class="h-[300px] w-full bg-slate-50 rounded-xl relative overflow-hidden flex items-end px-4 pb-10 gap-1 md:gap-2"
        >
          <div v-if="ventasSemana.length === 0 && !loading" class="absolute inset-0 flex items-center justify-center text-slate-400 text-sm">
            No hay datos suficientes para el gráfico.
          </div>
          
          <div 
            v-for="dia in ventasSemana" 
            :key="dia.label" 
            class="flex-1 bg-blue-500/20 rounded-t-sm md:rounded-t-lg transition-all hover:bg-blue-500 relative group"
            :style="{ 
              height: `${Math.max((dia.total / (Math.max(...ventasSemana.map(d => d.total)) || 1)) * 85, 2)}%` 
            }"
          >
            <!-- Tooltip -->
            <div class="absolute -top-10 left-1/2 -translate-x-1/2 bg-slate-900 text-white text-[10px] px-2 py-1 rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap z-10">
              {{ formatCurrency(dia.total) }}
            </div>
            <!-- Label -->
            <div class="absolute -bottom-7 left-1/2 -translate-x-1/2 text-[9px] md:text-[10px] font-bold text-slate-400 uppercase">
              {{ dia.label }}
            </div>
          </div>
        </div>
      </div>

      <!-- Side Card -->
      <div class="bg-white p-6 rounded-2xl border border-slate-100 shadow-sm flex flex-col">
        <h3 class="text-lg font-bold text-slate-900 mb-6">Productos Más Vendidos</h3>
        
        <div class="space-y-6 flex-1">
          <div v-if="productosMasVendidos.length === 0 && !loading" class="text-center py-8 text-slate-500 text-sm">
            No hay datos de ventas recientes.
          </div>
          <div v-for="(prod, i) in productosMasVendidos" :key="prod.nombre" class="flex items-center gap-4">
            <div class="w-12 h-12 bg-slate-100 rounded-xl flex items-center justify-center text-slate-400 font-bold">
              #{{ i + 1 }}
            </div>
            <div class="flex-1">
              <p class="text-sm font-bold text-slate-900 truncate w-32" :title="prod.nombre">{{ prod.nombre }}</p>
              <div class="w-full bg-slate-100 h-1.5 rounded-full mt-2">
                <div 
                  class="bg-orange-500 h-1.5 rounded-full transition-all duration-1000" 
                  :style="{ width: `${(prod.cantidad / productosMasVendidos[0].cantidad) * 100}%` }"
                ></div>
              </div>
            </div>
            <div class="text-right">
              <p class="text-sm font-bold text-slate-900">{{ prod.cantidad }}</p>
              <p class="text-[10px] text-slate-500 uppercase">Unidades</p>
            </div>
          </div>
        </div>

        <NuxtLink 
          to="/inventario"
          class="w-full mt-8 py-3 text-sm font-bold text-slate-600 border border-slate-200 rounded-xl hover:bg-slate-50 transition-colors text-center"
        >
          Ver Todo el Inventario
        </NuxtLink>
      </div>
    </div>

    <!-- Recent Activity -->
    <div class="bg-white p-6 rounded-2xl border border-slate-100 shadow-sm">
      <h3 class="text-lg font-bold text-slate-900 mb-6">Actividad Reciente</h3>
      <div class="overflow-x-auto">
        <table class="w-full text-left">
          <thead>
            <tr class="text-slate-400 text-xs uppercase tracking-wider">
              <th class="pb-4 font-medium">Operación</th>
              <th class="pb-4 font-medium">Cliente</th>
              <th class="pb-4 font-medium">Estado</th>
              <th class="pb-4 font-medium">Monto</th>
              <th class="pb-4 font-medium">Hora</th>
              <th class="pb-4 font-medium text-right">Acciones</th>
            </tr>
          </thead>
          <tbody class="text-sm border-t border-slate-50">
            <tr v-if="ultimasVentas.length === 0 && !loading">
              <td colspan="6" class="py-8 text-center text-slate-500">No hay ventas registradas recientemente.</td>
            </tr>
            <tr v-for="venta in ultimasVentas" :key="venta.id" class="group hover:bg-slate-50 transition-colors">
              <td class="py-4 font-medium text-slate-900">Venta #{{ venta.id.slice(0, 8) }}</td>
              <td class="py-4 text-slate-600">
                {{ venta.clientes?.nombre || 'Consumidor Final' }}
              </td>
              <td class="py-4">
                <span 
                  v-if="venta.anulada" 
                  class="px-2 py-1 bg-rose-100 text-rose-700 text-[10px] font-bold rounded-md"
                >
                  ANULADA
                </span>
                <span 
                  v-else 
                  class="px-2 py-1 bg-emerald-100 text-emerald-700 text-[10px] font-bold rounded-md"
                >
                  COMPLETADO
                </span>
              </td>
              <td class="py-4 font-bold text-slate-900">{{ formatCurrency(venta.total) }}</td>
              <td class="py-4 text-slate-400">{{ timeAgo(venta.fecha) }}</td>
              <td class="py-4 text-right text-slate-400">
                <Button 
                  text 
                  rounded 
                  severity="secondary" 
                  @click="verDetalleVenta(venta)"
                >
                  <Eye class="w-4 h-4" />
                </Button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <Dialog 
      v-model:visible="showDetailDialog" 
      modal 
      header="Detalle de Venta" 
      :style="{ width: '750px' }" 
      :breakpoints="{ '1199px': '75vw', '575px': '90vw' }"
    >
      <ReportesVentaReciboDetalle v-if="selectedVenta" :venta="selectedVenta" />
    </Dialog>

    <Dialog 
      v-model:visible="showTasasDialog" 
      modal 
      header="Gestión de Tasas de Cambio" 
      :style="{ width: '50rem' }" 
      :breakpoints="{ '1199px': '75vw', '575px': '90vw' }"
    >
      <ConfiguracionTasasForm @updated="loadStats" />
    </Dialog>
  </div>
</template>

<style scoped>
/* Transiciones suaves para las barras del gráfico */
.flex-1 {
  transition: height 0.3s ease-in-out, background-color 0.2s ease;
}
</style>
