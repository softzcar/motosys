<script setup lang="ts">
import { DollarSign, ShoppingCart, TrendingUp, Package, Users, ReceiptText, Eye, Search, AlertTriangle, Layers, ClipboardList, Wallet, Ban, RotateCcw, FilePlus, History, Pencil, Trash2 } from 'lucide-vue-next'
import { useDebounceFn } from '@vueuse/core'
import { useVentas } from '~/composables/useVentas'
import { useProductos } from '~/composables/useProductos'
import { useCategoriasProductos } from '~/composables/useCategoriasProductos'
import { useCompras } from '~/composables/useCompras'
import { useCierresCaja, type CierreCaja } from '~/composables/useCierresCaja'

const client = useSupabaseClient()
const toast = useToast()
const { fetchVentas, fetchVentaById, fetchVendedoresConVentas, anularVenta } = useVentas()
const { fetchProductos } = useProductos()
const { fetchAllCategorias } = useCategoriasProductos()
const { fetchCompras, getCompraById } = useCompras()
const { fetchCierres, getCierreById } = useCierresCaja()
const { isAdmin } = usePerfil()

// --- ESTADOS ---
const activeTab = ref('ventas')

// Filtros Globales (Periodo)
const range = ref<Date[]>([])
const defaultRange = () => {
  const hoy = new Date()
  const inicio = new Date(hoy.getFullYear(), hoy.getMonth(), 1)
  return [inicio, hoy]
}

// Inicializar rango si no existe
onMounted(() => {
  if (range.value.length === 0) {
    range.value = defaultRange()
  }
  loadAll()
})

const dateRangeStr = computed(() => {
  if (range.value.length === 2 && range.value[0] && range.value[1]) {
    return {
      desde: range.value[0].toISOString(),
      hasta: new Date(range.value[1].setHours(23, 59, 59, 999)).toISOString()
    }
  }
  return null
})

// Estado de Ventas
const ventas = ref<any[]>([])
const loadingVentas = ref(false)
const totalVentasRecords = ref(0)
const sortFieldVentas = ref('fecha')
const sortOrderVentas = ref(-1)
const searchCliente = ref('')
const incluirVentasAnuladas = ref(false)
const ventasStats = ref({ total: 0, count: 0, promedio: 0 })
const loadingVentasStats = ref(false)

const detailsModal = ref(false)
const loadingDetails = ref(false)
const selectedVenta = ref<any>(null)

// Estado de Inventario
const inventario = ref<any[]>([])
const loadingInventario = ref(false)
const totalInventarioRecords = ref(0)
const sortFieldInventario = ref('stock')
const sortOrderInventario = ref(1)
const searchProducto = ref('')
const categoriaId = ref<string | null>(null)
const categorias = ref<any[]>([])
const inventarioStats = ref({ totalValor: 0, itemsBajoStock: 0 })

// Estado de Compras
const compras = ref<any[]>([])
const loadingCompras = ref(false)
const totalComprasRecords = ref(0)
const sortFieldCompras = ref('fecha')
const sortOrderCompras = ref(-1)
const searchProveedor = ref('')
const incluirComprasAnuladas = ref(false)
const comprasStats = ref({ totalGastado: 0, totalFacturas: 0 })
const loadingComprasStats = ref(false)

const purchaseDetailsModal = ref(false)
const loadingPurchaseDetails = ref(false)
const selectedPurchase = ref<any>(null)

// Estado de Cierres de Caja
const cierres = ref<CierreCaja[]>([])
const loadingCierres = ref(false)
const totalCierresRecords = ref(0)
const sortFieldCierres = ref('fecha')
const sortOrderCierres = ref(-1)

const closureDetailsModal = ref(false)
const loadingClosureDetails = ref(false)
const selectedClosure = ref<any>(null)

// Estado de Auditoría (Incidencias)
const auditoria = ref<any[]>([])
const loadingAuditoria = ref(false)
const totalAuditoriaRecords = ref(0)
const searchAuditoria = ref('')

const auditoriaDetailModal = ref(false)
const selectedAuditoria = ref<any>(null)

// Estado de Clientes (Reporte por Cliente)
const ventasCliente = ref<any[]>([])
const loadingVentasCliente = ref(false)
const totalVentasClienteRecords = ref(0)
const searchVentasCliente = ref('')
const sortFieldVentasCliente = ref('fecha')
const sortOrderVentasCliente = ref(-1)

// --- MÉTODOS DE CARGA ---

const loadAll = () => {
  loadVentas()
  loadVentasStats()
  loadInventario()
  loadInventarioStats()
  loadCompras()
  loadComprasStats()
  loadCierres()
  loadAuditoria()
  loadCategorias()
  loadVentasPorCliente()
}

const loadVentasPorCliente = async (event?: any) => {
  // En este reporte no aplicamos el filtro de fecha global por defecto si hay una búsqueda,
  // para permitir ver todo el historial del cliente.
  loadingVentasCliente.value = true
  const rows = event?.rows ?? 10
  const page = event?.page ?? 0
  
  try {
    const { data, total } = await fetchVentas({
      page,
      rows,
      sortField: sortFieldVentasCliente.value,
      sortOrder: sortOrderVentasCliente.value,
      searchCliente: searchVentasCliente.value,
      incluirAnuladas: true // En el reporte de clientes solemos querer ver todo
    })
    ventasCliente.value = data
    totalVentasClienteRecords.value = total
  } finally {
    loadingVentasCliente.value = false
  }
}

const loadVentas = async () => {
  if (!dateRangeStr.value) return
  loadingVentas.value = true
  try {
    const { data, total } = await fetchVentas({
      desde: dateRangeStr.value.desde,
      hasta: dateRangeStr.value.hasta,
      page: 0,
      rows: 100,
      sortField: sortFieldVentas.value,
      sortOrder: sortOrderVentas.value,
      searchCliente: searchCliente.value,
      incluirAnuladas: incluirVentasAnuladas.value
    })
    ventas.value = data
    totalVentasRecords.value = total
  } finally {
    loadingVentas.value = false
  }
}

const loadVentasStats = async () => {
  if (!dateRangeStr.value) return
  loadingVentasStats.value = true
  try {
    let query = client
      .from('ventas')
      .select('total', { count: 'exact' })
      .gte('fecha', dateRangeStr.value.desde)
      .lte('fecha', dateRangeStr.value.hasta)

    if (!incluirVentasAnuladas.value) {
      query = query.eq('anulada', false)
    }

    const { data, count, error } = await query
    if (error) throw error

    const sum = data.reduce((acc, v) => acc + Number(v.total), 0)
    ventasStats.value = {
      total: sum,
      count: count ?? 0,
      promedio: count ? sum / count : 0
    }
  } finally {
    loadingVentasStats.value = false
  }
}

const loadInventario = async () => {
  loadingInventario.value = true
  try {
    const { data, total } = await fetchProductos({
      search: searchProducto.value,
      categoriaId: categoriaId.value,
      sortField: sortFieldInventario.value,
      sortOrder: sortOrderInventario.value,
      rows: 100
    })
    inventario.value = data
    totalInventarioRecords.value = total
  } finally {
    loadingInventario.value = false
  }
}

const loadInventarioStats = async () => {
  const { data } = await client.from('productos').select('stock, precio_venta').eq('activo', true)
  if (data) {
    inventarioStats.value = {
      totalValor: data.reduce((acc, p) => acc + (p.stock * Number(p.precio_venta)), 0),
      itemsBajoStock: data.filter(p => p.stock < 5).length
    }
  }
}

const loadCompras = async () => {
  if (!dateRangeStr.value) return
  loadingCompras.value = true
  try {
    const { data, total } = await fetchCompras({
      desde: dateRangeStr.value.desde,
      hasta: dateRangeStr.value.hasta,
      searchProveedor: searchProveedor.value,
      incluirAnuladas: incluirComprasAnuladas.value,
      sortField: sortFieldCompras.value,
      sortOrder: sortOrderCompras.value,
      rows: 100
    })
    compras.value = data
    totalComprasRecords.value = total
  } finally {
    loadingCompras.value = false
  }
}

const loadComprasStats = async () => {
  if (!dateRangeStr.value) return
  loadingComprasStats.value = true
  try {
    let query = client
      .from('compras')
      .select('total', { count: 'exact' })
      .gte('fecha', dateRangeStr.value.desde)
      .lte('fecha', dateRangeStr.value.hasta)

    if (!incluirComprasAnuladas.value) {
      query = query.eq('anulada', false)
    }

    const { data, count, error } = await query
    if (error) throw error

    comprasStats.value = {
      totalGastado: data.reduce((acc, c) => acc + Number(c.total), 0),
      totalFacturas: count ?? 0
    }
  } catch {
    // Silently handle error for stats
  } finally {
    loadingComprasStats.value = false
  }
}

const loadCierres = async () => {
  if (!dateRangeStr.value) return
  loadingCierres.value = true
  try {
    const { data, total } = await fetchCierres({
      desde: dateRangeStr.value.desde,
      hasta: dateRangeStr.value.hasta,
      sortField: sortFieldCierres.value,
      sortOrder: sortOrderCierres.value,
      rows: 100
    })
    cierres.value = data
    totalCierresRecords.value = total
  } finally {
    loadingCierres.value = false
  }
}

const loadAuditoria = async () => {
  if (!dateRangeStr.value) return
  loadingAuditoria.value = true
  try {
    let query = client
      .from('inventario_auditoria')
      .select('*, usuario:perfiles!fk_inventario_auditoria_usuario_perfil(nombre)', { count: 'exact' })
      .gte('created_at', dateRangeStr.value.desde)
      .lte('created_at', dateRangeStr.value.hasta)
      .order('created_at', { ascending: false })

    if (searchAuditoria.value) {
      query = query.or(`nombre.ilike.%${searchAuditoria.value}%,codigo_parte.ilike.%${searchAuditoria.value}%`)
    }

    const { data, count, error } = await query
    if (error) throw error

    auditoria.value = data
    totalAuditoriaRecords.value = count ?? 0
  } finally {
    loadingAuditoria.value = false
  }
}

const loadCategorias = async () => {
  categorias.value = await fetchAllCategorias()
}

// --- HANDLERS ---

const openDetails = async (venta: any) => {
  detailsModal.value = true
  loadingDetails.value = true
  try {
    const fullVenta = await fetchVentaById(venta.id)
    selectedVenta.value = fullVenta
  } catch (error: any) {
    toast.add({ severity: 'error', summary: 'Error al obtener el detalle', detail: error.message, life: 3000 })
    detailsModal.value = false
  } finally {
    loadingDetails.value = false
  }
}

const openPurchaseDetails = async (compra: any) => {
  purchaseDetailsModal.value = true
  loadingPurchaseDetails.value = true
  try {
    const fullCompra = await getCompraById(compra.id)
    selectedPurchase.value = fullCompra
  } catch (error: any) {
    toast.add({ severity: 'error', summary: 'Error al obtener el detalle', detail: error.message, life: 3000 })
    purchaseDetailsModal.value = false
  } finally {
    loadingPurchaseDetails.value = false
  }
}

const openCierreDetails = async (cierre: any) => {
  closureDetailsModal.value = true
  loadingClosureDetails.value = true
  try {
    const fullCierre = await getCierreById(cierre.id)
    selectedClosure.value = fullCierre
  } catch (error: any) {
    toast.add({ severity: 'error', summary: 'Error al obtener el detalle', detail: error.message, life: 3000 })
    closureDetailsModal.value = false
  } finally {
    loadingClosureDetails.value = false
  }
}

const openAuditoriaDetail = (item: any) => {
  selectedAuditoria.value = item
  auditoriaDetailModal.value = true
}

const irACorreccionVenta = (ventaId: string) => {
  navigateTo(`/pos?corrigiendo=${ventaId}`)
}

const imprimirReporte = () => {
  window.print()
}

// Anulación de venta
const anularVentaModal = ref(false)
const ventaAAnular = ref<any>(null)
const motivoAnulacionVenta = ref('')
const anulandoVenta = ref(false)

const openAnularVentaModal = (venta: any) => {
  ventaAAnular.value = venta
  motivoAnulacionVenta.value = ''
  anularVentaModal.value = true
}

const confirmarAnularVenta = async () => {
  if (!ventaAAnular.value || motivoAnulacionVenta.value.trim().length < 10) return
  anulandoVenta.value = true
  try {
    await anularVenta(ventaAAnular.value.id, motivoAnulacionVenta.value.trim())
    toast.add({ 
       severity: 'success', 
       summary: 'Venta Anulada', 
       detail: 'El stock fue revertido y el estado actualizado.', 
       life: 4000 
    })
    anularVentaModal.value = false
    loadVentas()
    loadVentasStats()
    
    toast.add({
       severity: 'info',
       summary: '¿Corregir Venta?',
       detail: 'Se ha habilitado la opción de crear una corrección en el POS.',
       group: 'pos-correccion',
       life: 10000,
       data: { ventaId: ventaAAnular.value.id }
    })
  } catch (error: any) {
    toast.add({ severity: 'error', summary: 'Error al anular', detail: error.message, life: 4000 })
  } finally {
    anulandoVenta.value = false
  }
}

// Debounces
const debouncedSearchVentas = useDebounceFn(loadVentas, 500)
const debouncedSearchInventario = useDebounceFn(loadInventario, 500)
const debouncedSearchCompras = useDebounceFn(loadCompras, 500)
const debouncedSearchAuditoria = useDebounceFn(loadAuditoria, 500)
const debouncedSearchVentasCliente = useDebounceFn(loadVentasPorCliente, 500)

const formatCurrency = (value: number) => {
  if (value === undefined || value === null) return '$0.00'
  return value.toLocaleString('es-VE', { style: 'currency', currency: 'USD' })
}

const formatDate = (dateString: string) => {
  return new Date(dateString).toLocaleDateString('es-VE')
}

const formatDateTime = (dateString: string) => {
  return new Date(dateString).toLocaleString('es-VE')
}
</script>

<template>
  <div class="space-y-6">
    <!-- Header con Filtro de Fecha Global -->
    <div class="flex flex-wrap items-center justify-between gap-4 bg-white p-5 rounded-xl shadow-sm border border-slate-200">
      <div>
        <h1 class="text-2xl font-bold text-slate-800 m-0">Reportes y Auditoría</h1>
        <p class="text-slate-400 text-xs mt-1 italic">Visualiza el rendimiento y la trazabilidad del sistema</p>
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
          @update:model-value="loadAll"
        />
        <Button icon="pi pi-refresh" severity="secondary" text rounded @click="loadAll" v-tooltip.top="'Refrescar datos'" />
      </div>
    </div>

    <!-- Pestañas de Reportes -->
    <Tabs :value="activeTab" @update:value="(val) => activeTab = val">
      <TabList>
        <Tab value="ventas" class="flex items-center gap-2">
          <TrendingUp :size="16" /> Ventas e Ingresos
        </Tab>
        <Tab value="cierres" class="flex items-center gap-2">
          <ClipboardList :size="16" /> Cierres de Caja
        </Tab>
        <Tab value="inventario" class="flex items-center gap-2">
          <Package :size="16" /> Inventario y Stock
        </Tab>
        <Tab value="compras" class="flex items-center gap-2">
          <ShoppingCart :size="16" /> Proveedores y Compras
        </Tab>
        <Tab value="clientes" class="flex items-center gap-2">
          <Users :size="16" /> Clientes
        </Tab>
        <Tab value="auditoria" class="flex items-center gap-2">
          <History :size="16" /> Auditoría
        </Tab>
      </TabList>

      <TabPanels class="mt-4">
        <!-- 1. VENTAS E INGRESOS -->
        <TabPanel value="ventas">
           <div class="space-y-6">
             <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
               <div class="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex items-center gap-4">
                 <div class="p-3 bg-emerald-50 rounded-lg text-emerald-600">
                   <DollarSign :size="24" />
                 </div>
                 <div>
                   <span class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-0.5">Total Ingresos</span>
                   <span class="text-xl font-black text-slate-800">{{ formatCurrency(ventasStats.total) }}</span>
                 </div>
               </div>
               <div class="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex items-center gap-4">
                 <div class="p-3 bg-blue-50 rounded-lg text-blue-600">
                   <ReceiptText :size="24" />
                 </div>
                 <div>
                   <span class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-0.5">Ventas Totales</span>
                   <span class="text-xl font-black text-slate-800">{{ ventasStats.count }}</span>
                 </div>
               </div>
               <div class="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex items-center gap-4">
                 <div class="p-3 bg-amber-50 rounded-lg text-amber-600">
                   <Layers :size="24" />
                 </div>
                 <div>
                   <span class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-0.5">Ticket Promedio</span>
                   <span class="text-xl font-black text-slate-800">{{ formatCurrency(ventasStats.promedio) }}</span>
                 </div>
               </div>
             </div>

             <div class="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
                <div class="p-4 border-b border-slate-100 bg-slate-50/50 flex flex-wrap items-center justify-between gap-4">
                   <div class="flex items-center gap-4">
                      <h3 class="text-sm font-bold text-slate-700 m-0 uppercase tracking-tight">Historial de Ventas</h3>
                      <Button label="Imprimir Reporte" icon="pi pi-print" severity="info" outlined size="small" @click="imprimirReporte" class="h-8 shadow-sm" />
                   </div>
                   <div class="flex items-center gap-3">
                     <IconField class="w-64">
                       <InputIcon class="pi pi-search" />
                       <InputText v-model="searchCliente" placeholder="Buscar cliente..." class="w-full" @input="debouncedSearchVentas" />
                     </IconField>
                     <div class="flex items-center gap-2 px-3 py-1.5 bg-white border border-slate-200 rounded-lg">
                        <ToggleSwitch v-model="incluirVentasAnuladas" inputId="swVentasAnuladas" @change="loadVentas(); loadVentasStats()" />
                        <label for="swVentasAnuladas" class="text-[10px] font-bold text-slate-500 uppercase tracking-widest whitespace-nowrap cursor-pointer select-none">Mostrar Anuladas</label>
                     </div>
                   </div>
                </div>

                <DataTable 
                   :value="ventas" 
                   lazy paginator :rows="10" :totalRecords="totalVentasRecords" :loading="loadingVentas"
                   @sort="e => { sortFieldVentas = e.sortField; sortOrderVentas = e.sortOrder; loadVentas() }"
                   :sortField="sortFieldVentas" :sortOrder="sortOrderVentas"
                   stripedRows class="p-datatable-sm"
                >
                   <Column field="numero" header="N° Ticket" sortable>
                       <template #body="slotProps">
                         <span class="font-bold text-primary">#{{ slotProps.data.numero }}</span>
                       </template>
                   </Column>
                   <Column field="fecha" header="Fecha" sortable>
                       <template #body="slotProps">
                         {{ formatDateTime(slotProps.data.fecha) }}
                       </template>
                   </Column>
                   <Column field="clientes.nombre" sortField="clientes(nombre)" header="Cliente" sortable>
                       <template #body="slotProps">
                         {{ slotProps.data.clientes?.nombre ?? '-' }}
                       </template>
                   </Column>
                   <Column field="vendedor.nombre" sortField="vendedor(nombre)" header="Cajero" sortable>
                       <template #body="slotProps">
                         <span class="text-xs text-slate-500">{{ slotProps.data.vendedor?.nombre ?? 'Sistema' }}</span>
                       </template>
                   </Column>
                   <Column field="total" header="Monto" sortable>
                       <template #body="slotProps">
                         <span class="font-black text-slate-800" :class="{'line-through text-slate-400': slotProps.data.anulada}">
                            {{ formatCurrency(slotProps.data.total) }}
                         </span>
                       </template>
                   </Column>
                   <Column field="anulada" header="Estado" sortable>
                     <template #body="slotProps">
                       <Tag v-if="slotProps.data.anulada" severity="danger" value="ANULADA" />
                       <Tag v-else-if="slotProps.data.cierre_id" severity="info" value="En cierre" />
                       <Tag v-else severity="success" value="Vigente" />
                     </template>
                   </Column>
                   <Column :exportable="false" header="Acciones">
                       <template #body="slotProps">
                         <div class="flex items-center gap-1">
                           <Button severity="secondary" text rounded @click="openDetails(slotProps.data)" class="text-blue-500 hover:bg-blue-50 p-2" v-tooltip.top="'Ver detalle'">
                             <Eye class="w-5 h-5" />
                           </Button>
                           <Button
                             v-if="isAdmin && !slotProps.data.anulada && !slotProps.data.cierre_id"
                             severity="secondary" text rounded @click="openAnularVentaModal(slotProps.data)" class="text-rose-600 hover:bg-rose-50 p-2" v-tooltip.top="'Anular venta'"
                           >
                             <Ban class="w-5 h-5" />
                           </Button>
                         </div>
                       </template>
                    </Column>
                </DataTable>
             </div>
           </div>
        </TabPanel>

        <!-- 2. CIERRES DE CAJA -->
        <TabPanel value="cierres">
           <div class="space-y-6">
              <div class="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
                 <div class="p-4 border-b border-slate-100 bg-slate-50/50 flex items-center justify-between">
                    <h3 class="text-sm font-bold text-slate-700 m-0 uppercase tracking-tight">Historial de Cierres de Caja</h3>
                    <Button label="Imprimir Reporte" icon="pi pi-print" severity="info" outlined size="small" @click="imprimirReporte" class="h-8 shadow-sm" />
                 </div>
                 <DataTable 
                    :value="cierres" lazy paginator :rows="10" :totalRecords="totalCierresRecords" :loading="loadingCierres"
                    @sort="e => { sortFieldCierres = e.sortField; sortOrderCierres = e.sortOrder; loadCierres() }"
                    :sortField="sortFieldCierres" :sortOrder="sortOrderCierres"
                    stripedRows class="p-datatable-sm"
                 >
                    <Column field="fecha" header="Fecha de Cierre" sortable>
                       <template #body="slotProps">
                          {{ formatDateTime(slotProps.data.fecha) }}
                       </template>
                    </Column>
                    <Column field="responsable.nombre" header="Cajero">
                       <template #body="slotProps">
                          <span class="font-bold text-slate-700">{{ slotProps.data.responsable?.nombre }}</span>
                       </template>
                    </Column>
                    <Column field="total_ventas_usd" header="Total Ventas (USD)">
                       <template #body="slotProps">
                          {{ formatCurrency(slotProps.data.total_ventas_usd) }}
                       </template>
                    </Column>
                    <Column field="total_caja_usd" header="Efectivo en Caja">
                       <template #body="slotProps">
                          {{ formatCurrency(slotProps.data.total_caja_usd) }}
                       </template>
                    </Column>
                    <Column field="diferencia_usd" header="Diferencia">
                       <template #body="slotProps">
                          <span :class="Number(slotProps.data.diferencia_usd) < 0 ? 'text-rose-600' : 'text-emerald-600'" class="font-black">
                             {{ formatCurrency(slotProps.data.diferencia_usd) }}
                          </span>
                       </template>
                    </Column>
                    <Column :exportable="false" header="Ver">
                       <template #body="slotProps">
                          <Button severity="secondary" text rounded @click="openCierreDetails(slotProps.data)" class="text-blue-500 hover:bg-blue-50 p-2">
                             <Eye class="w-5 h-5" />
                          </Button>
                       </template>
                    </Column>
                 </DataTable>
              </div>
           </div>
        </TabPanel>

        <!-- 3. INVENTARIO Y STOCK -->
        <TabPanel value="inventario">
           <div class="space-y-6">
             <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
               <div class="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex items-center gap-4">
                 <div class="p-3 bg-blue-50 rounded-lg text-blue-600">
                   <Wallet :size="24" />
                 </div>
                 <div>
                   <span class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-0.5">Valorización Inventario (Venta)</span>
                   <span class="text-xl font-black text-slate-800">{{ formatCurrency(inventarioStats.totalValor) }}</span>
                 </div>
               </div>
               <div class="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex items-center gap-4">
                 <div class="p-3 bg-rose-50 rounded-lg text-rose-600">
                   <AlertTriangle :size="24" />
                 </div>
                 <div>
                   <span class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-0.5">Productos con bajo Stock</span>
                   <span class="text-xl font-black text-rose-600">{{ inventarioStats.itemsBajoStock }}</span>
                 </div>
               </div>
             </div>

             <div class="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
                <div class="p-4 border-b border-slate-100 bg-slate-50/50 flex flex-wrap items-center justify-between gap-4">
                   <div class="flex items-center gap-4">
                      <h3 class="text-sm font-bold text-slate-700 m-0 uppercase tracking-tight">Estado de Almacén</h3>
                      <Button label="Imprimir Planilla" icon="pi pi-print" severity="info" outlined size="small" @click="imprimirReporte" class="h-8 shadow-sm" />
                   </div>
                   <div class="flex items-center gap-3">
                     <IconField class="w-64">
                       <InputIcon class="pi pi-search" />
                       <InputText v-model="searchProducto" placeholder="Buscar producto o código..." class="w-full" @input="debouncedSearchInventario" />
                     </IconField>
                     <Select
                        v-model="categoriaId" :options="categorias" optionLabel="nombre" optionValue="id"
                        placeholder="Categoría..." showClear class="w-48" @change="loadInventario"
                     />
                   </div>
                </div>

                <DataTable 
                   :value="inventario" lazy paginator :rows="20" :totalRecords="totalInventarioRecords" :loading="loadingInventario"
                   @sort="e => { sortFieldInventario = e.sortField; sortOrderInventario = e.sortOrder; loadInventario() }"
                   :sortField="sortFieldInventario" :sortOrder="sortOrderInventario"
                   stripedRows class="p-datatable-sm"
                >
                   <Column field="codigo_parte" header="Código" sortable></Column>
                   <Column field="nombre" header="Producto" sortable></Column>
                   <Column field="stock" header="Existencia" sortable>
                     <template #body="slotProps">
                       <Tag :severity="slotProps.data.stock < 5 ? 'danger' : slotProps.data.stock < 15 ? 'warn' : 'success'" :value="String(slotProps.data.stock)" />
                     </template>
                   </Column>
                   <Column field="precio_venta" header="Venta U." sortable>
                     <template #body="slotProps">
                       <span class="font-medium text-slate-700">{{ formatCurrency(slotProps.data.precio_venta) }}</span>
                     </template>
                   </Column>
                   <Column field="activo" header="Estado" sortable>
                     <template #body="slotProps">
                       <Tag :value="slotProps.data.activo ? 'ACTIVO' : 'INACTIVO'" :severity="slotProps.data.activo ? 'success' : 'secondary'" />
                     </template>
                   </Column>
                </DataTable>
             </div>
           </div>
        </TabPanel>

        <!-- 4. PROVEEDORES Y COMPRAS -->
        <TabPanel value="compras">
           <div class="space-y-6">
             <div class="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
                <div class="p-4 border-b border-slate-100 bg-slate-50/50 flex flex-wrap items-center justify-between gap-4">
                   <div class="flex items-center gap-4">
                      <h3 class="text-sm font-bold text-slate-700 m-0 uppercase tracking-tight">Historial de Compras y Suministros</h3>
                      <Button label="Imprimir Reporte" icon="pi pi-print" severity="info" outlined size="small" @click="imprimirReporte" class="h-8 shadow-sm" />
                   </div>
                   <div class="flex items-center gap-3">
                     <IconField class="w-64">
                       <InputIcon class="pi pi-search" />
                       <InputText v-model="searchProveedor" placeholder="Buscar proveedor..." class="w-full" @input="debouncedSearchCompras" />
                     </IconField>
                     <div class="flex items-center gap-2 px-3 py-1.5 bg-white border border-slate-200 rounded-lg">
                        <ToggleSwitch v-model="incluirComprasAnuladas" inputId="swComprasAnuladas" @change="loadCompras()" />
                        <label for="swComprasAnuladas" class="text-[10px] font-bold text-slate-500 uppercase tracking-widest whitespace-nowrap cursor-pointer select-none">Mostrar Anuladas</label>
                     </div>
                   </div>
                </div>

                <DataTable 
                   :value="compras" lazy paginator :rows="10" :totalRecords="totalComprasRecords" :loading="loadingCompras"
                   @sort="e => { sortFieldCompras = e.sortField; sortOrderCompras = e.sortOrder; loadCompras() }"
                   :sortField="sortFieldCompras" :sortOrder="sortOrderCompras"
                   stripedRows class="p-datatable-sm"
                >
                   <Column field="numero" header="N° Ticket" sortable>
                       <template #body="slotProps">
                         <span class="font-bold text-primary">#{{ slotProps.data.numero }}</span>
                       </template>
                   </Column>
                   <Column field="fecha" header="Fecha" sortable>
                        <template #body="slotProps">
                           {{ formatDate(slotProps.data.fecha) }}
                        </template>
                   </Column>
                   <Column field="numero_factura" header="Factura #"></Column>
                   <Column field="proveedores.nombre" sortField="proveedores(nombre)" header="Proveedor" sortable>
                        <template #body="slotProps">
                           {{ slotProps.data.proveedores?.nombre }}
                        </template>
                   </Column>
                   <Column field="total" header="Monto Total" sortable>
                     <template #body="slotProps">
                       <span class="font-black text-slate-800" :class="{ 'line-through': slotProps.data.anulada }">{{ formatCurrency(slotProps.data.total) }}</span>
                     </template>
                   </Column>
                   <Column :exportable="false" header="Acciones">
                       <template #body="slotProps">
                         <Button severity="secondary" text rounded @click="openPurchaseDetails(slotProps.data)" class="text-blue-500 hover:bg-blue-50 p-2">
                           <Eye class="w-5 h-5" />
                         </Button>
                       </template>
                    </Column>
                </DataTable>
             </div>
           </div>
        </TabPanel>

        <!-- 5. CLIENTES Y SUS FACTURAS -->
        <TabPanel value="clientes">
           <div class="space-y-6">
              <div class="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
                 <div class="p-4 border-b border-slate-100 bg-slate-50/50 flex flex-wrap items-center justify-between gap-4">
                    <div class="flex items-center gap-4">
                       <h3 class="text-sm font-bold text-slate-700 m-0 uppercase tracking-tight">Historial de Facturación por Cliente</h3>
                    </div>
                    <div class="flex items-center gap-3">
                       <IconField class="w-80">
                          <InputIcon class="pi pi-search" />
                          <InputText v-model="searchVentasCliente" placeholder="Buscar por Nombre, Cédula o Teléfono..." class="w-full" @input="debouncedSearchVentasCliente" />
                       </IconField>
                    </div>
                 </div>

                 <DataTable 
                    :value="ventasCliente" lazy paginator :rows="10" :totalRecords="totalVentasClienteRecords" :loading="loadingVentasCliente"
                    @page="loadVentasPorCliente"
                    @sort="e => { sortFieldVentasCliente = e.sortField; sortOrderVentasCliente = e.sortOrder; loadVentasPorCliente() }"
                    :sortField="sortFieldVentasCliente" :sortOrder="sortOrderVentasCliente"
                    stripedRows class="p-datatable-sm"
                 >
                    <Column field="numero" header="N° Factura" sortable>
                        <template #body="slotProps">
                          <span class="font-bold text-primary">#{{ slotProps.data.numero }}</span>
                        </template>
                    </Column>
                    <Column field="fecha" header="Fecha" sortable>
                        <template #body="slotProps">
                          {{ formatDateTime(slotProps.data.fecha) }}
                        </template>
                    </Column>
                    <Column field="clientes.nombre" sortField="clientes(nombre)" header="Nombre del Cliente" sortable>
                        <template #body="slotProps">
                          <div class="flex flex-col">
                             <span class="font-bold text-slate-800">{{ slotProps.data.clientes?.nombre ?? '-' }}</span>
                             <span class="text-[10px] text-slate-400 font-medium">{{ slotProps.data.clientes?.cedula }}</span>
                          </div>
                        </template>
                    </Column>
                    <Column field="total" header="Monto" sortable>
                        <template #body="slotProps">
                          <span class="font-black text-slate-800" :class="{'line-through text-slate-400': slotProps.data.anulada}">
                             {{ formatCurrency(slotProps.data.total) }}
                          </span>
                        </template>
                    </Column>
                    <Column field="anulada" header="Estado" sortable>
                      <template #body="slotProps">
                        <Tag v-if="slotProps.data.anulada" severity="danger" value="ANULADA" />
                        <Tag v-else severity="success" value="Vigente" />
                      </template>
                    </Column>
                    <Column :exportable="false" header="Acciones">
                        <template #body="slotProps">
                          <Button severity="secondary" text rounded @click="openDetails(slotProps.data)" class="text-blue-500 hover:bg-blue-50 p-2" v-tooltip.top="'Ver detalle'">
                            <Eye class="w-5 h-5" />
                          </Button>
                        </template>
                     </Column>
                 </DataTable>
              </div>
           </div>
        </TabPanel>

        <!-- 6. AUDITORÍA (INCIDENCIAS) -->
        <TabPanel value="auditoria">
           <div class="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
              <div class="p-4 border-b border-slate-100 bg-slate-50/50 flex flex-wrap items-center justify-between gap-4">
                 <h3 class="text-sm font-bold text-slate-700 m-0 uppercase tracking-tight">Log de Incidencias y Cambios</h3>
                 <IconField class="w-64">
                   <InputIcon class="pi pi-search" />
                   <InputText v-model="searchAuditoria" placeholder="Producto o código..." class="w-full" @input="debouncedSearchAuditoria" />
                 </IconField>
              </div>

              <DataTable 
                 :value="auditoria" lazy paginator :rows="15" :totalRecords="totalAuditoriaRecords" :loading="loadingAuditoria"
                 stripedRows class="p-datatable-sm text-xs"
              >
                 <Column field="created_at" header="Fecha">
                    <template #body="slotProps">
                       {{ formatDateTime(slotProps.data.created_at) }}
                    </template>
                 </Column>
                 <Column field="usuario.nombre" header="Usuario"></Column>
                 <Column field="accion" header="Acción">
                    <template #body="slotProps">
                       <Tag :severity="slotProps.data.accion === 'DELETE' ? 'danger' : 'warn'" :value="slotProps.data.accion" />
                    </template>
                 </Column>
                 <Column field="nombre" header="Producto"></Column>
                 <Column :exportable="false" header="Detalle">
                    <template #body="slotProps">
                       <Button severity="secondary" text rounded @click="openAuditoriaDetail(slotProps.data)" class="text-blue-500 hover:bg-blue-50 p-2">
                          <Eye class="w-5 h-5" />
                       </Button>
                    </template>
                 </Column>
              </DataTable>
           </div>
        </TabPanel>
      </TabPanels>
    </Tabs>

    <!-- --- DIÁLOGOS --- -->
    <Dialog v-model:visible="detailsModal" modal header="Detalle de Venta" :style="{ width: '750px' }">
       <div v-if="loadingDetails" class="flex flex-col items-center justify-center p-12">
          <span class="w-10 h-10 border-4 border-slate-200 border-t-blue-500 rounded-full animate-spin mb-4"></span>
          <span class="text-slate-500 font-medium">Cargando factura...</span>
       </div>
       <div v-else-if="selectedVenta" class="pt-2">
          <ReportesVentaReciboDetalle :venta="selectedVenta" />
       </div>
       <template #footer>
          <Button label="Cerrar" text severity="secondary" @click="detailsModal = false" class="mt-2" />
       </template>
    </Dialog>

    <Dialog v-model:visible="purchaseDetailsModal" modal header="Detalle de Compra" :style="{ width: '700px' }">
      <div v-if="loadingPurchaseDetails" class="flex flex-col items-center justify-center p-12">
        <span class="w-10 h-10 border-4 border-slate-200 border-t-blue-500 rounded-full animate-spin mb-4"></span>
        <span class="text-slate-500 font-medium">Cargando factura...</span>
      </div>
      <ReportesCompraDetalleRecibo v-else-if="selectedPurchase" :compra="selectedPurchase" />
      <template #footer>
        <Button label="Cerrar" text severity="secondary" @click="purchaseDetailsModal = false" class="mt-2" />
      </template>
    </Dialog>

     <Dialog v-model:visible="closureDetailsModal" :style="{ width: '750px' }" modal header="Detalle de Cierre">
        <div v-if="loadingClosureDetails" class="flex flex-col items-center justify-center p-12">
           <span class="w-10 h-10 border-4 border-slate-200 border-t-blue-500 rounded-full animate-spin mb-4"></span>
           <span class="text-slate-500 font-medium">Cargando reporte...</span>
        </div>
        <div v-else-if="selectedClosure" class="space-y-6 pt-2">
           <div class="grid grid-cols-2 gap-3 p-4 bg-slate-50 rounded-xl border border-slate-200">
              <div>
                 <p class="text-[10px] text-slate-400 font-bold uppercase mb-1">Responsable</p>
                 <p class="font-bold text-slate-800">{{ selectedClosure.responsable?.nombre }}</p>
              </div>
              <div class="text-right">
                 <p class="text-[10px] text-slate-400 font-bold uppercase mb-1">Fecha</p>
                 <p class="font-bold text-slate-800">{{ formatDateTime(selectedClosure.fecha) }}</p>
              </div>
           </div>
           <div class="bg-blue-50 p-4 rounded-xl border border-blue-100 flex justify-between items-center">
              <span class="text-xs font-bold text-blue-600 uppercase">Ventas totales registradas</span>
              <span class="text-xl font-black text-blue-700">{{ formatCurrency(selectedClosure.total_ventas_usd) }}</span>
           </div>
        </div>
        <template #footer>
           <Button label="Cerrar" text severity="secondary" @click="closureDetailsModal = false" />
        </template>
     </Dialog>

     <Dialog v-model:visible="auditoriaDetailModal" :style="{ width: '600px' }" modal header="Detalle de Auditoría">
        <div v-if="selectedAuditoria" class="space-y-4 pt-2">
           <div class="p-3 bg-slate-50 rounded-lg border border-slate-200">
              <p class="text-xs font-bold text-slate-400 uppercase mb-2">Producto Afectado</p>
              <div class="flex justify-between items-center">
                 <span class="font-black text-slate-800">{{ selectedAuditoria.nombre }}</span>
                 <span class="text-xs px-2 py-0.5 bg-slate-200 rounded font-bold">{{ selectedAuditoria.codigo_parte }}</span>
              </div>
           </div>
           <div class="p-3 bg-white rounded-lg border border-slate-200">
              <p class="text-xs font-bold text-slate-400 uppercase mb-1">Motivo Registrado</p>
              <p class="text-sm text-slate-700 italic">"{{ selectedAuditoria.motivo }}"</p>
           </div>
        </div>
        <template #footer>
           <Button label="Cerrar" text severity="secondary" @click="auditoriaDetailModal = false" />
        </template>
     </Dialog>

     <Dialog v-model:visible="anularVentaModal" :style="{ width: '560px' }" modal header="Anular venta">
        <div v-if="ventaAAnular" class="space-y-4 pt-2">
           <div class="bg-slate-50 border border-slate-200 rounded-lg p-3 text-sm">
              <p class="text-slate-700">Venta <b>#{{ ventaAAnular.id.slice(0,8).toUpperCase() }}</b></p>
           </div>
           <div>
              <label for="motivoAnularVenta" class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1">Motivo de anulación *</label>
              <Textarea id="motivoAnularVenta" v-model="motivoAnulacionVenta" rows="3" class="w-full" placeholder="Describe el motivo (mínimo 10 caracteres)" />
           </div>
        </div>
        <template #footer>
           <Button label="Cancelar" text severity="secondary" @click="anularVentaModal = false" />
           <Button label="Anular venta" severity="danger" @click="confirmarAnularVenta" :disabled="motivoAnulacionVenta.trim().length < 10" />
        </template>
     </Dialog>

     <!-- REPORTES IMPRIMIBLES -->
     <div class="hidden print:block">
         <div v-show="activeTab === 'ventas'">
             <ReportesVentasResumenReport 
                :ventas="ventas" 
                :filtros="{ desde: dateRangeStr?.desde, hasta: dateRangeStr?.hasta, search: searchCliente }" 
             />
         </div>
         <div v-show="activeTab === 'cierres'">
             <ReportesCierresHistorialReport 
                :cierres="cierres" 
                :filtros="{ desde: dateRangeStr?.desde, hasta: dateRangeStr?.hasta }" 
             />
         </div>
         <div v-show="activeTab === 'inventario'">
             <InventarioChecklistReport 
                :productos="inventario" 
                :filtros="{ search: searchProducto, categoria: categorias.find(c => c.id === categoriaId)?.nombre }" 
             />
         </div>
         <div v-show="activeTab === 'compras'">
             <ReportesComprasResumenReport 
                :compras="compras" 
                :filtros="{ desde: dateRangeStr?.desde, hasta: dateRangeStr?.hasta, search: searchProveedor }" 
             />
         </div>
     </div>
  </div>
</template>
