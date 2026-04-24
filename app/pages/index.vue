<script setup lang="ts">
import { markRaw, onMounted, ref, computed, watch } from 'vue'
import { 
  BarChart3, 
  TrendingUp, 
  Users, 
  Package, 
  Wallet, 
  ShoppingCart,
  ArrowUpRight,
  ArrowDownRight,
  AlertTriangle,
  Coins,
  Activity
} from 'lucide-vue-next'

const { perfil, isAdmin } = usePerfil()
const { fetchVentas } = useVentas()
const { fetchInventarioStats } = useProductos()
const client = useSupabaseClient()
const { fetchTasas } = useTasas()

// Redirección para vendedores (ellos no ven el resumen gerencial)
onMounted(() => {
  if (isAdmin.value === false) {
    navigateTo('/pos')
  }
  loadStats()
})

const loading = ref(true)
const ventasHoy = ref(0)
const clientesNuevos = ref(0)
const bajoStock = ref(0)
const ventasSemana = ref<{ label: string, total: number }[]>([])
const productosMasVendidos = ref<{ nombre: string, cantidad: number }[]>([])
const tasas = ref<any[]>([])
const chartPeriod = ref('Semanal')

const formatCurrency = (val: number) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD'
  }).format(val)
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
    ventasHoy.value = (salesToday || []).reduce((acc, v) => acc + Number(v.total), 0)

    // 2. Tasas del día
    tasas.value = await fetchTasas()

    // 3. Clientes nuevos (hoy)
    const { count } = await client
      .from('clientes')
      .select('*', { count: 'exact', head: true })
      .gte('created_at', today.toISOString())
      .lte('created_at', tomorrow.toISOString())
    clientesNuevos.value = count || 0

    // 4. Productos más vendidos
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
      .sort((a: any, b: any) => b.cantidad - a.cantidad)
      .slice(0, 4) as any

    // 5. Tendencia de ventas
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

    // 6. Bajo Stock count
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

const stats = computed(() => [
  { 
    label: 'Ventas del Día', 
    value: formatCurrency(ventasHoy.value), 
    icon: markRaw(TrendingUp), 
    color: 'text-emerald-600', 
    bg: 'bg-emerald-50' 
  },
  { 
    label: 'Tasas Configuradas', 
    value: tasas.value.length.toString(), 
    icon: markRaw(Wallet), 
    color: 'text-blue-600', 
    bg: 'bg-blue-50' 
  },
  { 
    label: 'Productos Bajos', 
    value: bajoStock.value.toString(), 
    icon: markRaw(Package), 
    color: 'text-orange-600', 
    bg: 'bg-orange-50' 
  },
  { 
    label: 'Clientes Nuevos', 
    value: clientesNuevos.value.toString(), 
    icon: markRaw(Users), 
    color: 'text-purple-600', 
    bg: 'bg-purple-50' 
  }
])
</script>

<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">
      <div>
        <h1 class="text-2xl font-black text-slate-800 uppercase tracking-tight">Resumen Gerencial</h1>
        <p class="text-slate-500 text-sm">Vista general del estado de tu negocio hoy.</p>
      </div>
      <div v-if="tasas.length > 0" class="flex items-center gap-3 bg-white p-2 rounded-xl border border-slate-100 shadow-sm">
        <div v-for="t in tasas" :key="t.codigo" class="flex flex-col px-3 border-r last:border-0 border-slate-100">
          <span class="text-[9px] font-black text-slate-400 uppercase">{{ t.codigo }}</span>
          <span class="text-xs font-bold text-slate-700">{{ t.tasa.toFixed(2) }}</span>
        </div>
      </div>
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
              <p class="text-xl font-black text-slate-800">
                <Skeleton v-if="loading" width="4rem" height="1.5rem" />
                <span v-else>{{ stat.value }}</span>
              </p>
            </div>
          </div>
        </template>
      </Card>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- Main Chart -->
      <Card class="lg:col-span-2 border-none shadow-sm">
        <template #title>
          <div class="flex items-center justify-between px-2 pt-2">
            <div class="flex items-center gap-2">
              <Activity class="text-blue-600" :size="18" />
              <span class="text-sm font-black uppercase tracking-tight">Tendencia de Ventas</span>
            </div>
            <select 
              v-model="chartPeriod"
              class="bg-slate-50 border-none text-[10px] font-bold text-slate-600 rounded-lg px-3 py-1.5 outline-none cursor-pointer uppercase"
            >
              <option value="Semanal">Semanal</option>
              <option value="Mensual">Mensual</option>
            </select>
          </div>
        </template>
        <template #content>
          <div v-if="loading" class="h-[250px] flex items-center justify-center">
             <ProgressSpinner style="width: 32px; height: 32px" />
          </div>
          <div 
            v-else
            class="h-[250px] w-full bg-slate-50/50 rounded-xl relative overflow-hidden flex items-end px-4 pb-8 gap-1 md:gap-2"
          >
            <div v-if="ventasSemana.length === 0" class="absolute inset-0 flex items-center justify-center text-slate-400 text-xs">
              No hay datos suficientes para el gráfico.
            </div>
            
            <div 
              v-for="dia in ventasSemana" 
              :key="dia.label" 
              class="flex-1 bg-blue-500/20 rounded-t-lg transition-all hover:bg-blue-600 relative group"
              :style="{ 
                height: `${Math.max((dia.total / (Math.max(...ventasSemana.map(d => d.total)) || 1)) * 85, 4)}%` 
              }"
            >
              <!-- Tooltip -->
              <div class="absolute -top-8 left-1/2 -translate-x-1/2 bg-slate-900 text-white text-[9px] font-bold px-2 py-1 rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap z-10 uppercase">
                {{ formatCurrency(dia.total) }}
              </div>
              <!-- Label -->
              <div class="absolute -bottom-6 left-1/2 -translate-x-1/2 text-[8px] font-black text-slate-400 uppercase tracking-tighter">
                {{ dia.label }}
              </div>
            </div>
          </div>
        </template>
      </Card>

      <!-- Best Sellers -->
      <Card class="border-none shadow-sm overflow-hidden">
        <template #title>
          <div class="flex items-center gap-2 px-2 pt-2">
            <Package class="text-orange-500" :size="18" />
            <span class="text-sm font-black uppercase tracking-tight">Más Vendidos</span>
          </div>
        </template>
        <template #content>
          <div v-if="loading" class="space-y-4">
            <Skeleton v-for="i in 4" :key="i" height="3rem" />
          </div>
          <div v-else-if="productosMasVendidos.length === 0" class="text-center py-12 text-slate-400 text-xs uppercase font-bold">
            Sin datos de ventas
          </div>
          <div v-else class="space-y-4">
            <div v-for="(prod, i) in productosMasVendidos" :key="prod.nombre" class="flex items-center gap-3 p-2 rounded-lg hover:bg-slate-50 transition-colors">
              <div class="w-8 h-8 bg-slate-100 rounded-lg flex items-center justify-center text-[10px] font-black text-slate-400 shrink-0">
                #{{ i + 1 }}
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-xs font-bold text-slate-800 truncate uppercase">{{ prod.nombre }}</p>
                <div class="flex items-center gap-2 mt-1">
                  <div class="flex-1 bg-slate-100 h-1 rounded-full overflow-hidden">
                    <div 
                      class="bg-orange-500 h-full rounded-full transition-all duration-1000" 
                      :style="{ width: `${(prod.cantidad / productosMasVendidos[0].cantidad) * 100}%` }"
                    ></div>
                  </div>
                  <span class="text-[10px] font-black text-slate-600 shrink-0">{{ prod.cantidad }} un.</span>
                </div>
              </div>
            </div>
          </div>
        </template>
      </Card>
    </div>

    <!-- Quick Actions -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
      <Button 
        class="w-full h-14 font-black text-xs uppercase tracking-widest gap-3 shadow-sm"
        severity="primary"
        @click="navigateTo('/pos')"
      >
        <template #icon>
          <ShoppingCart :size="18" />
        </template>
        Punto de Venta
      </Button>
      <Button 
        class="w-full h-14 font-black text-xs uppercase tracking-widest gap-3 shadow-sm"
        severity="secondary"
        outlined
        @click="navigateTo('/inventario')"
      >
        <template #icon>
          <Package :size="18" />
        </template>
        Gestionar Inventario
      </Button>
      <Button 
        class="w-full h-14 font-black text-xs uppercase tracking-widest gap-3 shadow-sm"
        severity="secondary"
        outlined
        @click="navigateTo('/reportes')"
      >
        <template #icon>
          <BarChart3 :size="18" />
        </template>
        Reportes y Auditoría
      </Button>
    </div>
  </div>
</template>

<style scoped>
/* Transiciones suaves para las barras del gráfico */
.flex-1 {
  transition: height 0.3s ease-in-out, background-color 0.2s ease;
}
</style>
