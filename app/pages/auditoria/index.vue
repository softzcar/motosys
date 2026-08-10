<script setup lang="ts">
import {
  Package,
  AlertTriangle,
  TrendingUp,
  CheckCircle2,
  Search,
  Printer,
  RotateCcw,
  ArrowUpRight,
  ArrowDownRight,
  AlertCircle,
  Check,
  DollarSign,
  Wallet,
  ReceiptText,
  Ban,
  ClipboardList,
  FileText
} from 'lucide-vue-next'
import { useAuditoria, type AuditoriaStockItem, type CompraDetalleAuditoria } from '~/composables/useAuditoria'
import { useCategoriasProductos } from '~/composables/useCategoriasProductos'
import { useMarcas } from '~/composables/useMarcas'
import { useProductos } from '~/composables/useProductos'
import { useProveedores } from '~/composables/useProveedores'
import { useMetodosPago } from '~/composables/useMetodosPago'
import { useHistorialProductos, type HistorialProductoItem } from '~/composables/useHistorialProductos'
import { useOfflineDb, db } from '~/composables/useOfflineDb'
import type { Producto } from '~/types/database'

// Composables
const { fetchAuditoriaStock, fetchAuditoriaPagos, fetchComprasProducto } = useAuditoria()
const { fetchAllCategorias } = useCategoriasProductos()
const { fetchAllMarcas } = useMarcas()
const { updateProductoConMotivo, fetchProductos, findByCodigo } = useProductos()
const { fetchAllProveedores } = useProveedores()
const { fetchMetodosPago } = useMetodosPago()
const { fetchHistorialProducto } = useHistorialProductos()
const { isOnline } = useOfflineDb()
const toast = useToast()

// Estados Generales
const activeTab = ref('stock')
const loading = ref(false)
const range = ref<Date[]>([])

// --- ESTADOS TAB 3: AUDITORÍA DE PRODUCTOS (TYPEAHEAD) ---
const searchTypeahead = ref('')
const typeaheadResultados = ref<Producto[]>([])
const loadingTypeahead = ref(false)
const productoSeleccionadoAuditoria = ref<Producto | null>(null)
const historialProductoSeleccionado = ref<HistorialProductoItem | null>(null)
const loadingHistorialItem = ref(false)

const buscarTypeahead = useDebounceFn(async () => {
  if (!searchTypeahead.value || searchTypeahead.value.length < 2) {
    typeaheadResultados.value = []
    return
  }
  loadingTypeahead.value = true
  try {
    if (isOnline.value) {
      const { data } = await fetchProductos({ search: searchTypeahead.value, rows: 50, soloActivos: true })
      typeaheadResultados.value = data
    } else {
      const term = searchTypeahead.value.toLowerCase()
      const localResults = await db.productos
        .filter(p => 
          p.nombre.toLowerCase().includes(term) || 
          p.codigo_parte.toLowerCase().includes(term)
        )
        .limit(50)
        .toArray()
      typeaheadResultados.value = localResults
    }
  } catch (e) {
    console.error('Error buscando productos:', e)
    typeaheadResultados.value = []
  } finally {
    loadingTypeahead.value = false
  }
}, 300)

const seleccionarProductoTypeahead = async (prod: Producto) => {
  productoSeleccionadoAuditoria.value = prod
  searchTypeahead.value = ''
  typeaheadResultados.value = []
  
  loadingHistorialItem.value = true
  try {
    const { compras, ajustes, ventas } = await fetchHistorialProducto(prod.id)
    const totalComprado = compras.filter(c => !c.anulada).reduce((acc, c) => acc + c.cantidad, 0)
    const totalVendido = ventas.filter(v => !v.anulada).reduce((acc, v) => acc + v.cantidad, 0)
    const totalAjustado = ajustes.reduce((acc, a) => acc + a.diferencia, 0)

    historialProductoSeleccionado.value = {
      producto: prod,
      compras,
      ajustes,
      ventas,
      resumen: {
        totalComprado,
        totalAjustado,
        totalVendido,
        stockActual: prod.stock
      }
    }
  } catch (err: any) {
    console.error('Error cargando historial de producto:', err)
    toast.add({ severity: 'error', summary: 'Error al obtener historial', detail: err.message, life: 3000 })
  } finally {
    loadingHistorialItem.value = false
  }
}

// Scanner de código de barras para la pestaña de auditoría de productos
useBarcodeScanner(async (code) => {
  if (activeTab.value !== 'productos') return
  try {
    let producto = null
    if (isOnline.value) {
      producto = await findByCodigo(code)
    } else {
      producto = await db.productos.where('codigo_parte').equals(code).first()
    }
    if (producto) {
      await seleccionarProductoTypeahead(producto)
    } else {
      toast.add({ severity: 'warn', summary: 'No encontrado', detail: `Código: ${code}`, life: 3000 })
    }
  } catch (e) {
    console.error('Error escaneando:', e)
  }
})

// Catálogos de Filtros
const categorias = ref<any[]>([])
const marcas = ref<any[]>([])
const proveedores = ref<any[]>([])
const metodosPago = ref<any[]>([])

// --- ESTADOS TAB 1: STOCK ---
const rawItems = ref<AuditoriaStockItem[]>([])
const searchQuery = ref('')
const selectedCategoriaId = ref<string | null>(null)
const selectedMarcaId = ref<string | null>(null)
const selectedProveedorId = ref<string | null>(null)
const filtroEstado = ref<'todos' | 'fallas' | 'correctos'>('todos')
const filtroEstadoOptions = [
  { label: 'Todos', value: 'todos' },
  { label: 'Solo fallas', value: 'fallas' },
  { label: 'Solo correctos', value: 'correctos' }
]
const corrigiendo = ref<Record<string, boolean>>({})

// Estados para Modal de Detalle de Compras
const detalleModal = ref(false)
const detalleItem = ref<AuditoriaStockItem | null>(null)
const detalleCompras = ref<CompraDetalleAuditoria[]>([])
const loadingDetalle = ref(false)

// Estados para Modal de Corrección
const corregirModal = ref(false)
const productoACorregir = ref<AuditoriaStockItem | null>(null)
const cantidadCorregir = ref<number>(0)
const motivoCorregir = ref<string>('')


// --- ESTADOS TAB 2: PAGOS ---
const rawPagos = ref<any[]>([])
const searchQueryPagos = ref('')
const selectedMetodoPagoId = ref<string | null>(null)
const selectedMoneda = ref<string | null>(null)

const monedasOptions = [
  { label: 'Dólares (USD)', value: 'USD' },
  { label: 'Bolívares (Bs)', value: 'Bs' },
  { label: 'Pesos (COP)', value: 'COP' }
]

// Configuración Inicial de Fechas (mes actual por defecto)
const defaultRange = () => {
  const hoy = new Date()
  const inicio = new Date(hoy.getFullYear(), hoy.getMonth(), 1)
  return [inicio, hoy]
}

const dateRangeStr = computed(() => {
  if (range.value.length === 2 && range.value[0] && range.value[1]) {
    return {
      desde: range.value[0].toISOString(),
      hasta: new Date(range.value[1].setHours(23, 59, 59, 999)).toISOString()
    }
  }
  return null
})

// Cargar Datos según pestaña activa
const loadActiveData = async () => {
  if (!dateRangeStr.value) return
  loading.value = true
  try {
    if (activeTab.value === 'stock') {
      const data = await fetchAuditoriaStock(
        dateRangeStr.value.desde,
        dateRangeStr.value.hasta
      )
      rawItems.value = data
    } else {
      const data = await fetchAuditoriaPagos(
        dateRangeStr.value.desde,
        dateRangeStr.value.hasta
      )
      rawPagos.value = data
    }
  } catch (err: any) {
    toast.add({
      severity: 'error',
      summary: 'Error al cargar datos',
      detail: err.message || 'No se pudo conectar a Supabase',
      life: 5000
    })
  } finally {
    loading.value = false
  }
}

// Cargar Catálogos de Filtros
const loadFilters = async () => {
  try {
    const [cats, marcs, provs, metodos] = await Promise.all([
      fetchAllCategorias(),
      fetchAllMarcas(),
      fetchAllProveedores(),
      fetchMetodosPago()
    ])
    categorias.value = cats || []
    marcas.value = marcs || []
    proveedores.value = provs || []
    metodosPago.value = metodos || []
  } catch (err) {
    console.error('Error cargando filtros de auditoría:', err)
  }
}

// Observar cambio de Pestaña o Fechas
watch([activeTab, range], () => {
  loadActiveData()
})

// Inicialización
onMounted(async () => {
  if (range.value.length === 0) {
    range.value = defaultRange()
  }
  await Promise.all([
    loadFilters(),
    loadActiveData()
  ])
})

// --- LÓGICA TAB 1: STOCK ---
const filteredItems = computed(() => {
  return rawItems.value.filter(item => {
    if (searchQuery.value) {
      const q = searchQuery.value.toLowerCase()
      const matchName = item.nombre?.toLowerCase().includes(q)
      const matchCode = item.codigo_parte?.toLowerCase().includes(q)
      if (!matchName && !matchCode) return false
    }

    if (selectedCategoriaId.value && item.categoria_id !== selectedCategoriaId.value) {
      return false
    }

    if (selectedMarcaId.value && item.marca_id !== selectedMarcaId.value) {
      return false
    }

    if (filtroEstado.value !== 'todos') {
      const esperado = item.stock_inicial + item.compras_periodo - item.ventas_periodo
      const diff = item.stock_real_periodo - esperado
      if (filtroEstado.value === 'fallas' && diff === 0) return false
      if (filtroEstado.value === 'correctos' && diff !== 0) return false
    }

    if (selectedProveedorId.value) {
      if (!item.proveedores_ids || !item.proveedores_ids.includes(selectedProveedorId.value)) {
        return false
      }
    }

    return true
  })
})

const stats = computed(() => {
  const total = filteredItems.value.length
  let discrepanciasCount = 0
  let totalComp = 0
  let totalVent = 0
  let totalAj = 0

  filteredItems.value.forEach(item => {
    const esperado = item.stock_inicial + item.compras_periodo - item.ventas_periodo
    const diff = item.stock_real_periodo - esperado
    if (diff !== 0) discrepanciasCount++
    
    totalComp += item.compras_periodo
    totalVent += item.ventas_periodo
    totalAj += Math.abs(item.ajustes_periodo)
  })

  const exactitud = total > 0 ? Math.round(((total - discrepanciasCount) / total) * 100) : 100

  return {
    total,
    discrepanciasCount,
    totalComp,
    totalVent,
    totalAj,
    exactitud
  }
})

const abrirDetalle = async (item: AuditoriaStockItem) => {
  detalleItem.value = item
  detalleCompras.value = []
  detalleModal.value = true
  loadingDetalle.value = true
  try {
    detalleCompras.value = await fetchComprasProducto(item.id, dateRangeStr.value!.desde, dateRangeStr.value!.hasta)
  } catch (err: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: err.message, life: 4000 })
  } finally {
    loadingDetalle.value = false
  }
}

const corregirStock = (item: AuditoriaStockItem) => {
  productoACorregir.value = item
  const esperado = item.stock_inicial + item.compras_periodo - item.ventas_periodo
  cantidadCorregir.value = esperado
  motivoCorregir.value = 'Corregido por auditoría'
  corregirModal.value = true
}

const confirmarCorreccion = async () => {
  if (!productoACorregir.value) return
  const item = productoACorregir.value
  const nuevaCantidad = cantidadCorregir.value
  const motivo = motivoCorregir.value.trim() || 'Corregido por auditoría'

  corrigiendo.value[item.id] = true
  corregirModal.value = false
  try {
    await updateProductoConMotivo(item.id, { stock: nuevaCantidad }, motivo)
    toast.add({
      severity: 'success',
      summary: 'Stock Corregido',
      detail: `El stock de "${item.nombre}" ha sido actualizado a ${nuevaCantidad} unidades.`,
      life: 3000
    })
    await loadActiveData()
  } catch (err: any) {
    toast.add({
      severity: 'error',
      summary: 'Error al corregir stock',
      detail: err.message || 'No se pudo actualizar el stock',
      life: 5000
    })
  } finally {
    corrigiendo.value[item.id] = false
    productoACorregir.value = null
  }
}

// --- LÓGICA TAB 2: PAGOS ---
const filteredPagos = computed(() => {
  return rawPagos.value.filter(p => {
    if (searchQueryPagos.value) {
      const q = searchQueryPagos.value.toLowerCase()
      const refMatch = p.referencia?.toLowerCase().includes(q)
      const numMatch = p.ventas?.numero?.toString().includes(q)
      if (!refMatch && !numMatch) return false
    }

    if (selectedMetodoPagoId.value && p.metodo_pago_id !== selectedMetodoPagoId.value) {
      return false
    }

    if (selectedMoneda.value && p.metodos_pago?.moneda !== selectedMoneda.value) {
      return false
    }

    return true
  })
})

const pagosStats = computed(() => {
  let totalUsd = 0
  let totalVes = 0
  let totalCount = 0
  let anuladasCount = 0

  filteredPagos.value.forEach(p => {
    if (p.ventas?.anulada) {
      anuladasCount++
    } else {
      totalCount++
      totalUsd += Number(p.monto_usd) || 0
      if (p.metodos_pago?.moneda === 'Bs') {
        totalVes += Number(p.monto_recibido) || 0
      }
    }
  })

  return {
    totalUsd,
    totalVes,
    totalCount,
    anuladasCount
  }
})

const totalPorMetodo = computed(() => {
  const totals: Record<string, { total: number; moneda: string }> = {}
  filteredPagos.value.forEach(p => {
    if (p.ventas?.anulada) return
    const metodo = p.metodos_pago?.nombre || 'Desconocido'
    const moneda = p.metodos_pago?.moneda || 'USD'
    const monto = Number(p.monto_recibido) || 0
    if (!totals[metodo]) {
      totals[metodo] = { total: 0, moneda }
    }
    totals[metodo].total += monto
  })
  return totals
})

// Imprimir Reporte
const imprimirReporte = () => {
  window.print()
}

const formatCurrency = (val: number, currency: string = 'USD') => {
  const formatted = new Intl.NumberFormat('es-VE', { 
    minimumFractionDigits: 2,
    maximumFractionDigits: 2
  }).format(val)
  
  if (currency === 'USD' || currency === '$') {
    return `${formatted} $`
  } else if (currency === 'VES' || currency === 'Bs' || currency === 'Bs.F') {
    return `${formatted} Bs.`
  } else {
    return `${formatted} ${currency}`
  }
}

const formatDateTime = (dateStr: string) => {
  if (!dateStr) return ''
  const date = new Date(dateStr)
  return date.toLocaleString('es-VE', { 
    day: '2-digit', 
    month: '2-digit', 
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}
</script>

<template>
  <div class="space-y-6">
    <!-- Header con Filtro de Fecha -->
    <div class="flex flex-wrap items-center justify-between gap-4 bg-white p-5 rounded-xl shadow-sm border border-slate-200">
      <div>
        <h1 class="text-2xl font-bold text-slate-800 m-0">Consola de Auditoría</h1>
        <p class="text-slate-400 text-xs mt-1 italic">Trazabilidad general de inventarios y flujos de caja</p>
      </div>
      <div class="flex flex-wrap items-center gap-3">
        <label class="text-xs font-bold text-slate-500 uppercase tracking-widest">Periodo:</label>
        <DatePicker
          v-model="range"
          selectionMode="range"
          showIcon
          iconDisplay="input"
          dateFormat="dd/mm/yy"
          placeholder="Rango de fechas"
          class="w-64"
        />
        <Button 
          severity="info" 
          outlined 
          @click="imprimirReporte" 
          class="flex items-center gap-2"
          v-tooltip.top="'Imprimir reporte tamaño carta'"
        >
          <Printer class="w-4 h-4" />
          <span>Imprimir</span>
        </Button>
        <Button 
          icon="pi pi-refresh" 
          severity="secondary" 
          text 
          rounded 
          @click="loadActiveData" 
          v-tooltip.top="'Refrescar datos'" 
          :loading="loading"
        />
      </div>
    </div>

    <!-- Pestañas de Auditoría -->
    <Tabs :value="activeTab" @update:value="(val) => activeTab = val">
      <TabList>
        <Tab value="stock" class="flex items-center gap-2">
          <Package :size="16" /> Auditoría de Stock
        </Tab>
        <Tab value="pagos" class="flex items-center gap-2">
          <DollarSign :size="16" /> Auditoría de Pagos
        </Tab>
        <Tab value="productos" class="flex items-center gap-2">
          <RotateCcw :size="16" /> Auditoría de Productos
        </Tab>
      </TabList>

      <TabPanels class="mt-4">
        <!-- PESTAÑA 1: AUDITORÍA DE STOCK -->
        <TabPanel value="stock">
          <div class="space-y-6">
            <!-- Indicadores / Cards de Resumen -->
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
              <div class="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex items-center gap-4">
                <div class="p-3 bg-blue-50 text-blue-600 rounded-lg">
                  <Package class="w-6 h-6" />
                </div>
                <div>
                  <p class="text-slate-400 text-[10px] font-bold uppercase tracking-wider mb-0.5">Total Ítems</p>
                  <p class="text-2xl font-black text-slate-800 leading-none">{{ stats.total }}</p>
                </div>
              </div>

              <div class="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex items-center gap-4">
                <div class="p-3 rounded-lg" :class="stats.discrepanciasCount > 0 ? 'bg-rose-50 text-rose-600' : 'bg-slate-50 text-slate-400'">
                  <AlertTriangle class="w-6 h-6" />
                </div>
                <div>
                  <p class="text-slate-400 text-[10px] font-bold uppercase tracking-wider mb-0.5">Discrepancias</p>
                  <p class="text-2xl font-black leading-none" :class="stats.discrepanciasCount > 0 ? 'text-rose-600' : 'text-slate-700'">
                    {{ stats.discrepanciasCount }}
                  </p>
                </div>
              </div>

              <div class="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex items-center gap-4">
                <div class="p-3 rounded-lg" :class="stats.exactitud >= 95 ? 'bg-emerald-50 text-emerald-600' : 'bg-amber-50 text-amber-600'">
                  <CheckCircle2 class="w-6 h-6" />
                </div>
                <div>
                  <p class="text-slate-400 text-[10px] font-bold uppercase tracking-wider mb-0.5">Exactitud de Stock</p>
                  <p class="text-2xl font-black leading-none" :class="stats.exactitud >= 95 ? 'text-emerald-600' : 'text-amber-600'">
                    {{ stats.exactitud }}%
                  </p>
                </div>
              </div>

              <div class="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex items-center gap-4">
                <div class="p-3 bg-slate-50 text-slate-600 rounded-lg">
                  <TrendingUp class="w-6 h-6" />
                </div>
                <div>
                  <p class="text-slate-400 text-[10px] font-bold uppercase tracking-wider mb-0.5">Movimientos</p>
                  <p class="text-xs font-bold text-slate-700 leading-tight">
                    Comp: +{{ stats.totalComp }} uds<br>
                    Vent: -{{ stats.totalVent }} uds
                  </p>
                </div>
              </div>
            </div>

            <!-- Barra de Filtros Stock -->
            <div class="bg-white p-4 rounded-xl border border-slate-200 shadow-sm flex flex-wrap items-center justify-between gap-4">
              <div class="flex flex-wrap items-center gap-3 flex-1 min-w-[300px]">
                <IconField class="w-64">
                  <InputIcon>
                    <Search class="w-4 h-4 text-slate-400" />
                  </InputIcon>
                  <InputText v-model="searchQuery" placeholder="Buscar por producto o código..." class="w-full" />
                </IconField>

                <Select
                  v-model="selectedCategoriaId"
                  :options="categorias"
                  optionLabel="nombre"
                  optionValue="id"
                  placeholder="Todas las categorías"
                  showClear
                  class="w-48"
                />

                <Select
                  v-model="selectedMarcaId"
                  :options="marcas"
                  optionLabel="nombre"
                  optionValue="id"
                  placeholder="Todas las marcas"
                  showClear
                  class="w-48"
                />

                <Select
                  v-model="selectedProveedorId"
                  :options="proveedores"
                  optionLabel="nombre"
                  optionValue="id"
                  placeholder="Todos los proveedores"
                  showClear
                  class="w-48"
                />
              </div>

              <div class="flex items-center gap-3">
                <SelectButton
                  v-model="filtroEstado"
                  :options="filtroEstadoOptions"
                  optionLabel="label"
                  optionValue="value"
                  class="text-xs"
                />
                <Button label="Imprimir Reporte" icon="pi pi-print" severity="info" outlined size="small" @click="imprimirReporte" class="h-8 shadow-sm" />
              </div>
            </div>

            <!-- DataTable Stock -->
            <div class="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
              <DataTable 
                :value="filteredItems" 
                paginator 
                :rows="50" 
                :loading="loading"
                stripedRows 
                class="p-datatable-sm text-xs"
                sortField="nombre"
                :sortOrder="1"
              >
                <template #empty>
                  <div class="flex flex-col items-center justify-center p-8 text-slate-400">
                    <AlertCircle class="w-8 h-8 mb-2" />
                    <p>No se encontraron registros de auditoría de inventario</p>
                  </div>
                </template>

                <Column field="codigo_parte" header="Código/SKU" sortable class="font-bold text-slate-600 w-32"></Column>
                <Column field="nombre" header="Producto" sortable>
                  <template #body="slotProps">
                    <div class="font-bold text-slate-800">{{ slotProps.data.nombre }}</div>
                    <div class="flex gap-2 mt-0.5 text-[10px] text-slate-400 uppercase font-semibold">
                      <span v-if="slotProps.data.marca_nombre">[{{ slotProps.data.marca_nombre }}]</span>
                      <span v-if="slotProps.data.categoria_nombre">({{ slotProps.data.categoria_nombre }})</span>
                    </div>
                  </template>
                </Column>
                
                <Column field="stock_inicial" header="Stock Inicial" sortable class="text-center w-28"></Column>
                
                <Column field="compras_periodo" header="Compras (+)" sortable class="text-center w-28 text-emerald-600 font-bold">
                  <template #body="slotProps">
                    <span v-if="slotProps.data.compras_periodo > 0">+{{ slotProps.data.compras_periodo }}</span>
                    <span class="text-slate-300" v-else>0</span>
                  </template>
                </Column>
                
                <Column field="ventas_periodo" header="Ventas (-)" sortable class="text-center w-28 text-rose-600 font-bold">
                  <template #body="slotProps">
                    <span v-if="slotProps.data.ventas_periodo > 0">-{{ slotProps.data.ventas_periodo }}</span>
                    <span class="text-slate-300" v-else>0</span>
                  </template>
                </Column>

                <Column field="ajustes_periodo" header="Ajustes (+/-)" sortable class="text-center w-28">
                  <template #body="slotProps">
                    <span v-if="slotProps.data.ajustes_periodo > 0" class="text-blue-600 font-bold">+{{ slotProps.data.ajustes_periodo }}</span>
                    <span v-else-if="slotProps.data.ajustes_periodo < 0" class="text-amber-600 font-bold">{{ slotProps.data.ajustes_periodo }}</span>
                    <span class="text-slate-300" v-else>0</span>
                  </template>
                </Column>

                <Column header="Debería Haber" class="text-center w-32 bg-blue-50/20 font-bold text-slate-700">
                  <template #body="slotProps">
                    {{ slotProps.data.stock_inicial + slotProps.data.compras_periodo - slotProps.data.ventas_periodo }}
                  </template>
                </Column>

                <Column field="stock_real_periodo" header="Stock Real" sortable class="text-center w-32 bg-slate-50/30 font-bold text-slate-700"></Column>

                <Column header="Diferencia" class="text-center w-28 font-bold">
                  <template #body="slotProps">
                    <div 
                      v-if="(slotProps.data.stock_real_periodo - (slotProps.data.stock_inicial + slotProps.data.compras_periodo - slotProps.data.ventas_periodo)) !== 0"
                      class="px-2 py-1 bg-rose-50 text-rose-700 rounded-md font-black"
                    >
                      {{ slotProps.data.stock_real_periodo - (slotProps.data.stock_inicial + slotProps.data.compras_periodo - slotProps.data.ventas_periodo) }}
                    </div>
                    <div class="text-slate-400" v-else>
                      0
                    </div>
                  </template>
                </Column>

                <Column header="Estado" class="text-center w-24">
                  <template #body="slotProps">
                    <Tag 
                      v-if="(slotProps.data.stock_real_periodo - (slotProps.data.stock_inicial + slotProps.data.compras_periodo - slotProps.data.ventas_periodo)) !== 0"
                      severity="danger" 
                      value="Falla" 
                    />
                    <Tag 
                      v-else
                      severity="success" 
                      value="OK" 
                    />
                  </template>
                </Column>

                <Column :exportable="false" header="Acciones" class="text-center w-24">
                  <template #body="slotProps">
                    <div class="flex items-center justify-center gap-1">
                      <Button
                        severity="secondary"
                        rounded
                        text
                        v-tooltip.top="'Ver detalle de compras'"
                        @click="abrirDetalle(slotProps.data)"
                        class="!p-1 hover:bg-slate-100 text-slate-500"
                      >
                        <FileText class="w-4 h-4" />
                      </Button>
                      <Button
                        v-if="(slotProps.data.stock_real_periodo - (slotProps.data.stock_inicial + slotProps.data.compras_periodo - slotProps.data.ventas_periodo)) !== 0"
                        severity="success"
                        rounded
                        text
                        v-tooltip.top="'Corregir stock al valor esperado'"
                        :loading="corrigiendo[slotProps.data.id]"
                        @click="corregirStock(slotProps.data)"
                        class="!p-1 hover:bg-emerald-50 text-emerald-600"
                      >
                        <Check class="w-5 h-5" />
                      </Button>
                    </div>
                  </template>
                </Column>
              </DataTable>
            </div>
          </div>
        </TabPanel>

        <!-- PESTAÑA 2: AUDITORÍA DE PAGOS -->
        <TabPanel value="pagos">
          <div class="space-y-6">
            <!-- Indicadores / Cards de Resumen Pagos -->
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
              <div class="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex items-center gap-4">
                <div class="p-3 bg-blue-50 text-blue-600 rounded-lg">
                  <DollarSign class="w-6 h-6" />
                </div>
                <div>
                  <p class="text-slate-400 text-[10px] font-bold uppercase tracking-wider mb-0.5">Ingresos USD (Ref.)</p>
                  <p class="text-2xl font-black text-blue-700 leading-none">{{ formatCurrency(pagosStats.totalUsd, 'USD') }}</p>
                </div>
              </div>

              <div class="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex items-center gap-4">
                <div class="p-3 bg-emerald-50 text-emerald-600 rounded-lg">
                  <Wallet class="w-6 h-6" />
                </div>
                <div>
                  <p class="text-slate-400 text-[10px] font-bold uppercase tracking-wider mb-0.5">Ingresos Bs</p>
                  <p class="text-2xl font-black text-emerald-700 leading-none">{{ formatCurrency(pagosStats.totalVes, 'Bs') }}</p>
                </div>
              </div>

              <div class="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex items-center gap-4">
                <div class="p-3 bg-slate-50 text-slate-600 rounded-lg">
                  <ReceiptText class="w-6 h-6" />
                </div>
                <div>
                  <p class="text-slate-400 text-[10px] font-bold uppercase tracking-wider mb-0.5">Transacciones</p>
                  <p class="text-2xl font-black text-slate-800 leading-none">{{ pagosStats.totalCount }}</p>
                </div>
              </div>

              <div class="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex items-center gap-4">
                <div class="p-3 rounded-lg" :class="pagosStats.anuladasCount > 0 ? 'bg-rose-50 text-rose-600' : 'bg-slate-50 text-slate-400'">
                  <Ban class="w-6 h-6" />
                </div>
                <div>
                  <p class="text-slate-400 text-[10px] font-bold uppercase tracking-wider mb-0.5">Ventas Anuladas</p>
                  <p class="text-2xl font-black leading-none" :class="pagosStats.anuladasCount > 0 ? 'text-rose-600' : 'text-slate-700'">
                    {{ pagosStats.anuladasCount }}
                  </p>
                </div>
              </div>
            </div>

            <!-- Desglose por Método de Pago -->
            <div v-if="Object.keys(totalPorMetodo).length > 0" class="bg-white p-5 rounded-xl border border-slate-200 shadow-sm">
              <h3 class="text-xs font-bold text-slate-500 uppercase tracking-widest mb-3">Totales por Método de Pago (Vigentes)</h3>
              <div class="flex flex-wrap gap-4">
                <div 
                  v-for="(info, metodo) in totalPorMetodo" 
                  :key="metodo" 
                  class="px-4 py-2.5 bg-slate-50 border border-slate-200 rounded-lg flex flex-col min-w-[160px]"
                >
                  <span class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">{{ metodo }}</span>
                  <span class="text-base font-black text-slate-800 mt-1">
                    {{ formatCurrency(info.total, info.moneda) }}
                  </span>
                </div>
              </div>
            </div>

            <!-- Barra de Filtros Pagos -->
            <div class="bg-white p-4 rounded-xl border border-slate-200 shadow-sm flex flex-wrap items-center justify-between gap-4">
              <div class="flex flex-wrap items-center gap-3 flex-1 min-w-[300px]">
                <IconField class="w-64">
                  <InputIcon>
                    <Search class="w-4 h-4 text-slate-400" />
                  </InputIcon>
                  <InputText v-model="searchQueryPagos" placeholder="Buscar por referencia o venta..." class="w-full" />
                </IconField>

                <Select
                  v-model="selectedMetodoPagoId"
                  :options="metodosPago"
                  optionLabel="nombre"
                  optionValue="id"
                  placeholder="Todos los métodos"
                  showClear
                  class="w-48"
                />

                <Select
                  v-model="selectedMoneda"
                  :options="monedasOptions"
                  optionLabel="label"
                  optionValue="value"
                  placeholder="Todas las monedas"
                  showClear
                  class="w-48"
                />
              </div>
            </div>

            <!-- DataTable Pagos -->
            <div class="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
              <DataTable 
                :value="filteredPagos" 
                paginator 
                :rows="50" 
                :loading="loading"
                stripedRows 
                class="p-datatable-sm text-xs"
                sortField="created_at"
                :sortOrder="-1"
              >
                <template #empty>
                  <div class="flex flex-col items-center justify-center p-8 text-slate-400">
                    <AlertCircle class="w-8 h-8 mb-2" />
                    <p>No se encontraron registros de pagos en el rango seleccionado</p>
                  </div>
                </template>

                <Column field="created_at" header="Fecha / Hora" sortable class="w-36">
                  <template #body="slotProps">
                    {{ formatDateTime(slotProps.data.created_at) }}
                  </template>
                </Column>

                <Column field="ventas.numero" header="Venta #" sortable class="text-center font-bold w-20">
                  <template #body="slotProps">
                    {{ slotProps.data.ventas?.numero || 'N/A' }}
                  </template>
                </Column>

                <Column field="metodos_pago.nombre" header="Método de Pago" sortable></Column>
                
                <Column field="metodos_pago.moneda" header="Moneda" sortable class="text-center w-20 font-bold"></Column>

                <Column field="monto_recibido" header="Monto Recibido" sortable class="text-right w-36 font-black">
                  <template #body="slotProps">
                    {{ formatCurrency(Number(slotProps.data.monto_recibido), slotProps.data.metodos_pago?.moneda) }}
                  </template>
                </Column>

                <Column field="tasa_aplicada" header="Tasa" sortable class="text-right w-24">
                  <template #body="slotProps">
                    {{ Number(slotProps.data.tasa_aplicada).toLocaleString('es-VE', { minimumFractionDigits: 2 }) }}
                  </template>
                </Column>

                <Column field="monto_usd" header="Equiv. USD" sortable class="text-right w-32 font-black text-slate-700 bg-slate-50/20">
                  <template #body="slotProps">
                    {{ formatCurrency(Number(slotProps.data.monto_usd), 'USD') }}
                  </template>
                </Column>

                <Column field="referencia" header="Referencia / Detalles" class="w-48">
                  <template #body="slotProps">
                    <span v-if="slotProps.data.referencia" class="font-medium text-slate-600 block max-w-xs truncate" v-tooltip.top="slotProps.data.referencia">
                      {{ slotProps.data.referencia }}
                    </span>
                    <span v-else class="text-slate-300 italic">Sin detalle</span>
                  </template>
                </Column>

                <Column header="Estado" class="text-center w-24">
                  <template #body="slotProps">
                    <Tag 
                      v-if="slotProps.data.ventas?.anulada"
                      severity="danger" 
                      value="Anulada" 
                    />
                    <Tag 
                      v-else
                      severity="success" 
                      value="Vigente" 
                    />
                  </template>
                </Column>
              </DataTable>
            </div>
          </div>
        </TabPanel>

        <!-- PESTAÑA 3: AUDITORÍA DE PRODUCTOS (TYPEAHEAD) -->
        <TabPanel value="productos">
          <div class="space-y-6">
            <!-- Barra de Búsqueda Typeahead exacta como POS -->
            <div class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 relative">
              <div class="flex items-center justify-between mb-2">
                <label class="text-xs font-bold text-slate-700 uppercase tracking-wide">
                  Buscar producto para auditoría (Nombre o SKU / Código de parte)
                </label>
                <span class="text-[10px] font-bold text-slate-400 bg-slate-100 px-2 py-0.5 rounded uppercase">
                  Scanner / Código de Barras Activo
                </span>
              </div>

              <IconField class="w-full">
                <InputIcon class="pi pi-search" />
                <InputText
                  v-model="searchTypeahead"
                  placeholder="Escribe el nombre del producto o código SKU..."
                  class="w-full text-sm"
                  @input="buscarTypeahead"
                />
              </IconField>

              <!-- Resultados desplegables del Typeahead -->
              <div 
                v-if="typeaheadResultados.length > 0" 
                class="absolute z-50 left-4 right-4 top-full mt-1 bg-white border border-slate-200 rounded-xl shadow-xl max-h-80 overflow-y-auto divide-y divide-slate-100"
              >
                <button
                  v-for="p in typeaheadResultados"
                  :key="p.id"
                  class="w-full text-left p-3 hover:bg-slate-50 transition-colors flex items-center justify-between"
                  @click="seleccionarProductoTypeahead(p)"
                >
                  <div>
                    <p class="text-sm font-bold text-slate-800">{{ p.nombre }}</p>
                    <p class="text-xs text-slate-500 font-mono">SKU: {{ p.codigo_parte }}</p>
                  </div>
                  <div class="text-right">
                    <span class="text-xs font-black text-slate-700 block">${{ Number(p.precio_venta).toFixed(2) }}</span>
                    <Tag :severity="p.stock < 5 ? 'danger' : 'success'" :value="`Stock: ${p.stock}`" class="text-[10px]" />
                  </div>
                </button>
              </div>

              <div v-else-if="loadingTypeahead" class="mt-2 text-xs text-slate-400 italic">
                Buscando productos...
              </div>
            </div>

            <!-- Contenido del Historial del Producto Seleccionado -->
            <div v-if="loadingHistorialItem" class="bg-white rounded-xl border border-slate-200 p-12 text-center text-slate-400 font-bold uppercase text-xs">
              Cargando trazabilidad e historial del producto...
            </div>

            <div v-else-if="!historialProductoSeleccionado" class="bg-white rounded-xl border border-slate-200 p-12 text-center text-slate-400 font-bold uppercase text-xs flex flex-col items-center gap-2">
              <Search :size="32" class="opacity-40" />
              <p>Selecciona un producto mediante el buscador arriba para consultar su historial de compras, facturas, ajustes y ventas.</p>
            </div>

            <div v-else class="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden p-5 space-y-4">
              <!-- Encabezado del Producto -->
              <div class="flex justify-between items-center bg-slate-900 text-white p-3 rounded-lg">
                <div>
                  <h4 class="text-base font-black uppercase m-0 tracking-wide">{{ historialProductoSeleccionado.producto.nombre }}</h4>
                  <p class="text-[10px] text-slate-300 font-bold m-0 mt-0.5">SKU / CÓDIGO: {{ historialProductoSeleccionado.producto.codigo_parte }}</p>
                </div>
                <div class="flex gap-4 text-xs font-bold bg-slate-800 px-3 py-1.5 rounded border border-slate-700">
                  <span>Stock Actual: <strong class="text-emerald-400 font-black">{{ historialProductoSeleccionado.producto.stock }}</strong></span>
                  <span v-if="historialProductoSeleccionado.producto.ubicacion">Ubicación: <strong>{{ historialProductoSeleccionado.producto.ubicacion }}</strong></span>
                </div>
              </div>

              <!-- Resumen rápido -->
              <div class="grid grid-cols-2 md:grid-cols-4 gap-3 bg-slate-50 p-3 rounded-lg border border-slate-200 text-xs">
                <div>
                  <span class="text-slate-400 font-bold uppercase text-[10px] block">Total Comprado</span>
                  <span class="font-black text-slate-800 text-sm">{{ historialProductoSeleccionado.resumen.totalComprado }} unidades</span>
                </div>
                <div>
                  <span class="text-slate-400 font-bold uppercase text-[10px] block">Total Vendido</span>
                  <span class="font-black text-slate-800 text-sm">{{ historialProductoSeleccionado.resumen.totalVendido }} unidades</span>
                </div>
                <div>
                  <span class="text-slate-400 font-bold uppercase text-[10px] block">Ajustes Netos</span>
                  <span class="font-black text-sm" :class="historialProductoSeleccionado.resumen.totalAjustado >= 0 ? 'text-emerald-600' : 'text-rose-600'">
                    {{ historialProductoSeleccionado.resumen.totalAjustado > 0 ? '+' : '' }}{{ historialProductoSeleccionado.resumen.totalAjustado }}
                  </span>
                </div>
                <div>
                  <span class="text-slate-400 font-bold uppercase text-[10px] block">Stock en Sistema</span>
                  <span class="font-black text-slate-800 text-sm">{{ historialProductoSeleccionado.resumen.stockActual }}</span>
                </div>
              </div>

              <!-- 1. COMPRAS Y FACTURAS -->
              <div>
                <h5 class="text-xs font-black uppercase text-slate-700 mb-2 flex items-center gap-2">
                  <Package :size="14" /> 1. Historial de Compras y Facturas ({{ historialProductoSeleccionado.compras.length }})
                </h5>
                <DataTable :value="historialProductoSeleccionado.compras" stripedRows class="p-datatable-sm text-xs">
                  <Column field="fecha" header="Fecha">
                    <template #body="{ data }">{{ new Date(data.fecha).toLocaleDateString('es-VE') }}</template>
                  </Column>
                  <Column field="numero_compra" header="N° Compra">
                    <template #body="{ data }">#{{ data.numero_compra }}</template>
                  </Column>
                  <Column field="numero_factura" header="Factura">
                    <template #body="{ data }">{{ data.numero_factura || 'N/A' }}</template>
                  </Column>
                  <Column field="proveedor_nombre" header="Proveedor"></Column>
                  <Column field="cantidad" header="Cantidad Ingresada" class="text-center font-bold"></Column>
                  <Column field="costo_unitario" header="Costo U.">
                    <template #body="{ data }">${{ Number(data.costo_unitario).toFixed(2) }}</template>
                  </Column>
                </DataTable>
              </div>

              <!-- 2. AJUSTES Y AUDITORÍA -->
              <div>
                <h5 class="text-xs font-black uppercase text-slate-700 mb-2 flex items-center gap-2">
                  <AlertCircle :size="14" /> 2. Ajustes Manuales y Auditoría ({{ historialProductoSeleccionado.ajustes.length }})
                </h5>
                <DataTable :value="historialProductoSeleccionado.ajustes" stripedRows class="p-datatable-sm text-xs">
                  <Column field="fecha" header="Fecha">
                    <template #body="{ data }">{{ new Date(data.fecha).toLocaleString('es-VE') }}</template>
                  </Column>
                  <Column field="accion" header="Acción" class="uppercase font-bold"></Column>
                  <Column field="usuario_nombre" header="Usuario"></Column>
                  <Column field="motivo" header="Motivo / Descripción">
                    <template #body="{ data }"><span class="italic text-slate-600">{{ data.motivo || 'N/A' }}</span></template>
                  </Column>
                  <Column header="Cambio Stock" class="text-center font-bold">
                    <template #body="{ data }">{{ data.stock_anterior }} &rarr; {{ data.stock_nuevo }}</template>
                  </Column>
                  <Column field="diferencia" header="Diferencia" class="text-center font-black">
                    <template #body="{ data }">
                      <span :class="data.diferencia >= 0 ? 'text-emerald-600' : 'text-rose-600'">
                        {{ data.diferencia > 0 ? '+' : '' }}{{ data.diferencia }}
                      </span>
                    </template>
                  </Column>
                </DataTable>
              </div>

              <!-- 3. VENTAS -->
              <div>
                <h5 class="text-xs font-black uppercase text-slate-700 mb-2 flex items-center gap-2">
                  <TrendingUp :size="14" /> 3. Historial de Ventas ({{ historialProductoSeleccionado.ventas.length }})
                </h5>
                <DataTable :value="historialProductoSeleccionado.ventas" stripedRows class="p-datatable-sm text-xs">
                  <Column field="fecha" header="Fecha">
                    <template #body="{ data }">{{ new Date(data.fecha).toLocaleDateString('es-VE') }}</template>
                  </Column>
                  <Column field="numero_venta" header="N° Venta">
                    <template #body="{ data }">#{{ data.numero_venta }}</template>
                  </Column>
                  <Column field="cliente_nombre" header="Cliente"></Column>
                  <Column field="cantidad" header="Cantidad Vendida" class="text-center font-bold"></Column>
                  <Column field="precio_unitario" header="Precio U.">
                    <template #body="{ data }">${{ Number(data.precio_unitario).toFixed(2) }}</template>
                  </Column>
                  <Column field="subtotal" header="Subtotal">
                    <template #body="{ data }">${{ Number(data.subtotal).toFixed(2) }}</template>
                  </Column>
                </DataTable>
              </div>
            </div>
          </div>
        </TabPanel>
      </TabPanels>
    </Tabs>

    <!-- Reportes Imprimibles (Ocultos en pantalla, se muestran en print) -->
    <div v-show="activeTab === 'stock'">
      <ReportesAuditoriaStockPrintReport 
        :items="filteredItems" 
        :filtros="{
          desde: dateRangeStr?.desde,
          hasta: dateRangeStr?.hasta,
          search: searchQuery,
          categoria: categorias.find(c => c.id === selectedCategoriaId)?.nombre,
          marca: marcas.find(m => m.id === selectedMarcaId)?.nombre,
          proveedor: proveedores.find(p => p.id === selectedProveedorId)?.nombre,
          filtroEstado: filtroEstado
        }"
      />
    </div>

    <div v-show="activeTab === 'pagos'">
      <ReportesAuditoriaPagosPrintReport 
        :items="filteredPagos" 
        :filtros="{
          desde: dateRangeStr?.desde,
          hasta: dateRangeStr?.hasta,
          search: searchQueryPagos,
          metodoPagoId: selectedMetodoPagoId
        }"
      />
    </div>

    <div v-show="activeTab === 'productos'">
      <ReportesHistorialProductoReport 
        :items="historialProductoSeleccionado ? [historialProductoSeleccionado] : []" 
        :loading="loadingHistorialItem" 
      />
    </div>

    <!-- Dialog de Detalle de Compras por Producto -->
    <Dialog
      v-model:visible="detalleModal"
      :header="detalleItem ? `Compras del período — ${detalleItem.nombre}` : 'Detalle de Compras'"
      modal
      :style="{ width: '680px' }"
    >
      <div v-if="detalleItem" class="space-y-4">
        <div class="p-3 bg-slate-50 border border-slate-200 rounded-lg text-xs grid grid-cols-3 gap-3">
          <div>
            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Código</p>
            <p class="font-bold text-slate-700">{{ detalleItem.codigo_parte }}</p>
          </div>
          <div>
            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Compras período</p>
            <p class="font-black text-emerald-600 text-sm">+{{ detalleItem.compras_periodo }} uds</p>
          </div>
          <div>
            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Ventas período</p>
            <p class="font-black text-rose-600 text-sm">-{{ detalleItem.ventas_periodo }} uds</p>
          </div>
        </div>

        <div v-if="loadingDetalle" class="flex items-center justify-center py-8 text-slate-400">
          <i class="pi pi-spin pi-spinner mr-2"></i> Cargando compras...
        </div>

        <DataTable
          v-else
          :value="detalleCompras"
          class="p-datatable-sm text-xs"
          stripedRows
          :paginator="detalleCompras.length > 10"
          :rows="10"
        >
          <template #empty>
            <div class="text-center py-6 text-slate-400 text-xs">
              No hay compras registradas para este producto en el período seleccionado.
            </div>
          </template>

          <Column header="Compra #" class="w-20 text-center font-bold">
            <template #body="s">
              <span class="font-black text-slate-700">#{{ s.data.compras?.numero }}</span>
            </template>
          </Column>

          <Column header="Factura" class="w-32">
            <template #body="s">
              <span v-if="s.data.compras?.numero_factura" class="font-medium text-blue-700">
                {{ s.data.compras.numero_factura }}
              </span>
              <span v-else class="text-slate-300 italic">Sin factura</span>
            </template>
          </Column>

          <Column header="Proveedor">
            <template #body="s">
              <span class="font-semibold text-slate-700">
                {{ s.data.compras?.proveedores?.nombre || 'Desconocido' }}
              </span>
            </template>
          </Column>

          <Column header="Fecha" class="w-28 text-center">
            <template #body="s">
              {{ s.data.compras?.fecha ? new Date(s.data.compras.fecha + 'T00:00:00').toLocaleDateString('es-VE') : '' }}
            </template>
          </Column>

          <Column header="Cant." class="w-16 text-center font-bold text-emerald-600">
            <template #body="s">
              +{{ s.data.cantidad }}
            </template>
          </Column>
        </DataTable>
      </div>

      <template #footer>
        <Button label="Cerrar" severity="secondary" text @click="detalleModal = false" />
      </template>
    </Dialog>

    <!-- Dialog de Ajuste / Corrección de Stock -->
    <Dialog
      v-model:visible="corregirModal"
      header="Ajustar / Corregir Stock"
      modal
      :style="{ width: '450px' }"
      :closable="!productoACorregir || !corrigiendo[productoACorregir.id]"
    >
      <div v-if="productoACorregir" class="flex flex-col gap-4">
        <!-- Detalles del producto -->
        <div class="p-3 bg-slate-50 border border-slate-200 rounded-lg text-xs space-y-1">
          <p class="font-bold text-slate-700 uppercase tracking-wider text-[10px]">Producto a corregir</p>
          <p class="text-sm font-bold text-slate-800">{{ productoACorregir.nombre }}</p>
          <p class="text-slate-500 text-[10px]">Código/SKU: <span class="font-semibold text-slate-700">{{ productoACorregir.codigo_parte }}</span></p>
          <div class="grid grid-cols-2 gap-2 mt-2 pt-2 border-t border-slate-200 text-slate-600 text-[11px]">
            <div>Stock Real actual: <span class="font-bold text-slate-800">{{ productoACorregir.stock_real_periodo }}</span></div>
            <div>Debería Haber: <span class="font-bold text-slate-800">{{ productoACorregir.stock_inicial + productoACorregir.compras_periodo - productoACorregir.ventas_periodo }}</span></div>
          </div>
        </div>

        <!-- Nueva cantidad -->
        <div class="flex flex-col gap-1.5">
          <label for="cantidad-corregir" class="text-xs font-bold text-slate-600 uppercase tracking-wide">
            Nueva Cantidad en Inventario <span class="text-red-500">*</span>
          </label>
          <InputNumber
            id="cantidad-corregir"
            v-model="cantidadCorregir"
            :min="0"
            show-buttons
            class="w-full text-sm"
            @focus="$event => ($event.target as HTMLInputElement).select()"
          />
        </div>

        <!-- Motivo -->
        <div class="flex flex-col gap-1.5">
          <label for="motivo-corregir" class="text-xs font-bold text-slate-600 uppercase tracking-wide">
            Motivo / Razón del Ajuste <span class="text-red-500">*</span>
          </label>
          <Textarea
            id="motivo-corregir"
            v-model="motivoCorregir"
            rows="3"
            class="w-full text-xs"
            placeholder="Ej: Corregido por auditoría"
            :invalid="!motivoCorregir.trim()"
          />
          <small v-if="!motivoCorregir.trim()" class="text-rose-600 text-[10px] font-semibold">El motivo es obligatorio</small>
        </div>
      </div>

      <template #footer>
        <Button 
          label="Cancelar" 
          severity="secondary" 
          text 
          :disabled="productoACorregir ? corrigiendo[productoACorregir.id] : false" 
          @click="corregirModal = false" 
        />
        <Button
          label="Guardar Corrección"
          severity="success"
          :loading="productoACorregir ? corrigiendo[productoACorregir.id] : false"
          :disabled="!motivoCorregir.trim() || cantidadCorregir === null || cantidadCorregir === undefined"
          @click="confirmarCorreccion"
        />
      </template>
    </Dialog>
  </div>
</template>
