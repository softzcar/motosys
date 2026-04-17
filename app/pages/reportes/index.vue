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
const router = useRouter()
const { fetchProductos, fetchInventarioStats, fetchInventarioAuditoria } = useProductos()
const { fetchAllCategorias } = useCategoriasProductos()
const { fetchCompras, getCompraById } = useCompras()
const { fetchCierres, fetchCierreById } = useCierresCaja()
const { isAdmin } = usePerfil()

const desde = ref(new Date(new Date().setDate(new Date().getDate() - 30)))
const hasta = ref(new Date())

const stats = ref({ totalVentas: 0, totalIngresos: 0, promedioVenta: 0 })
const loading = ref(false)

const ventas = ref<any[]>([])
const loadingVentas = ref(false)
const totalVentasRecords = ref(0)
const ventasPage = ref(0)
const sortFieldVentas = ref('fecha')
const sortOrderVentas = ref(-1)

const detailsModal = ref(false)
const loadingDetails = ref(false)
const selectedVenta = ref<any>(null)

// Filtros Adicionales
const searchCliente = ref('')
const selectedVendedor = ref<any>(null)
const vendedoresConVentas = ref<any[]>([])
const loadingVendedores = ref(false)
const incluirVentasAnuladas = ref(false)

// Anulación de ventas
const anularVentaModal = ref(false)
const ventaAAnular = ref<any>(null)
const motivoAnulacionVenta = ref('')
const anulandoVenta = ref(false)

// Estado de Inventario
const invStats = ref({ totalVenta: 0, bajoStockCount: 0, totalItems: 0 })
const loadingInvStats = ref(false)
const productos = ref<any[]>([])
const loadingProductos = ref(false)
const totalProductosRecords = ref(0)
const sortFieldProductos = ref('nombre')
const sortOrderProductos = ref(1)

// Filtros Inventario
const searchProducto = ref('')
const selectedCategoria = ref<string | null>(null)
const categoriasList = ref<any[]>([])
const soloBajoStock = ref(false)

// Estado de Compras
const fechaFiltroCompras = ref(new Date())
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
const selectedClosure = ref<CierreCaja | null>(null)

// Auditoría de Inventario
const auditoriaInv = ref<any[]>([])
const loadingAuditoriaInv = ref(false)
const totalAuditoriaInv = ref(0)
const searchAuditoria = ref('')
const accionAuditoria = ref<'UPDATE' | 'DELETE' | null>(null)
const auditoriaDetailModal = ref(false)
const selectedAuditoria = ref<any>(null)
const fechaFiltroAuditoria = ref(new Date())

const loadCategorias = async () => {
    try {
        categoriasList.value = await fetchAllCategorias()
    } catch (e) {
        console.error(e)
    }
}

const loadVendedores = async () => {
  loadingVendedores.value = true
  try {
    const data = await fetchVendedoresConVentas(
      desde.value.toISOString(),
      hasta.value.toISOString()
    )
    vendedoresConVentas.value = data
  } catch (error: any) {
    console.error('Error al cargar vendedores:', error)
  } finally {
    loadingVendedores.value = false
  }
}

const onSearchCliente = useDebounceFn(() => {
  loadVentasData()
}, 500)

const loadVentasData = async (event?: any) => {
  loadingVentas.value = true
  try {
    const page = event?.first !== undefined ? event.first / event.rows : 0
    ventasPage.value = page
    
    if (event?.sortField) {
      sortFieldVentas.value = event.sortField
      sortOrderVentas.value = event.sortOrder
    }

    const result = await fetchVentas({
      desde: desde.value.toISOString(),
      hasta: hasta.value.toISOString(),
      page: page,
      rows: event?.rows ?? 10,
      sortField: sortFieldVentas.value,
      sortOrder: sortOrderVentas.value,
      searchCliente: searchCliente.value,
      vendedorId: selectedVendedor.value?.id,
      incluirAnuladas: incluirVentasAnuladas.value
    })
    ventas.value = result.data
    totalVentasRecords.value = result.total
  } catch (error: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: error.message, life: 3000 })
  } finally {
    loadingVentas.value = false
  }
}

const loadStats = async () => {
  loading.value = true
  try {
    const { data, error } = await client
      .from('ventas')
      .select('total')
      .gte('fecha', desde.value.toISOString())
      .lte('fecha', hasta.value.toISOString())

    if (error) throw error

    const v = data ?? []
    stats.value.totalVentas = v.length
    stats.value.totalIngresos = v.reduce((sum, item) => sum + Number(item.total), 0)
    stats.value.promedioVenta = v.length > 0
      ? stats.value.totalIngresos / v.length
      : 0
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

watch([desde, hasta], () => {
    loadStats()
    loadVendedores()
    loadVentasData()
    loadCierresData()
    loadAuditoriaInv()
})

watch([searchCliente], () => {
    onSearchCliente()
})

watch([selectedVendedor, incluirVentasAnuladas], () => {
    loadVentasData()
})

const openAnularVentaModal = (venta: any) => {
  ventaAAnular.value = venta
  motivoAnulacionVenta.value = ''
  anularVentaModal.value = true
}

const confirmarAnularVenta = async () => {
  if (!ventaAAnular.value) return
  const motivo = motivoAnulacionVenta.value.trim()
  if (motivo.length < 10) {
    toast.add({ severity: 'warn', summary: 'Motivo requerido', detail: 'Explique el motivo en al menos 10 caracteres.', life: 3500 })
    return
  }
  anulandoVenta.value = true
  try {
    const ventaId = ventaAAnular.value.id
    await anularVenta(ventaId, motivo)
    anularVentaModal.value = false
    toast.add({
      severity: 'success',
      summary: 'Venta anulada',
      detail: 'Stock repuesto. Puede crear una nueva factura corregida desde el POS.',
      life: 6000
    })
    setTimeout(() => {
      toast.add({
        severity: 'info',
        summary: 'Crear corrección',
        detail: 'Abrir POS para registrar factura corregida',
        life: 8000,
        closable: true,
        group: 'correccion-venta',
        data: { ventaId }
      })
    }, 200)
    loadVentasData()
    loadStats()
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'No se pudo anular', detail: e.message ?? 'Error desconocido', life: 5000 })
  } finally {
    anulandoVenta.value = false
  }
}

const irACorreccionVenta = (ventaId: string) => {
  router.push(`/pos?from=${ventaId}`)
}


const loadInventarioStats = async () => {
  loadingInvStats.value = true
  try {
     const stats = await fetchInventarioStats()
     invStats.value = stats
  } catch (e: any) {
     toast.add({ severity: 'error', summary: 'Error', detail: 'No se pudieron cargar las estadísticas de inventario', life: 3000 })
  } finally {
     loadingInvStats.value = false
  }
}

const loadInventarioData = async (event?: any) => {
  loadingProductos.value = true
  try {
    const page = event?.first !== undefined ? event.first / event.rows : 0
    if (event?.sortField) {
       sortFieldProductos.value = event.sortField
       sortOrderProductos.value = event.sortOrder
    }
    const result = await fetchProductos({
      search: searchProducto.value,
      categoriaId: selectedCategoria.value,
      maxStock: soloBajoStock.value ? 5 : undefined,
      page: page,
      rows: event?.rows ?? 10,
      sortField: sortFieldProductos.value,
      sortOrder: sortOrderProductos.value
    })
    productos.value = result.data
    totalProductosRecords.value = result.total
  } catch (error: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: error.message, life: 3000 })
  } finally {
    loadingProductos.value = false
  }
}

const onSearchProducto = useDebounceFn(() => {
  loadInventarioData()
}, 500)

watch([searchProducto], () => onSearchProducto())
watch([selectedCategoria, soloBajoStock], () => loadInventarioData())

const loadComprasStats = async () => {
  loadingComprasStats.value = true
  try {
     const month = fechaFiltroCompras.value.getMonth()
     const year = fechaFiltroCompras.value.getFullYear()
     const desde = new Date(year, month, 1).toISOString()
     const hasta = new Date(year, month + 1, 0, 23, 59, 59).toISOString()

     const { data } = await fetchCompras({ desde, hasta, rows: 1000 })
     comprasStats.value.totalFacturas = data.length
     comprasStats.value.totalGastado = data.reduce((sum, item) => sum + Number(item.total), 0)
  } catch (e) {
     console.error(e)
  } finally {
     loadingComprasStats.value = false
  }
}

const loadComprasData = async (event?: any) => {
  loadingCompras.value = true
  try {
    const page = event?.first !== undefined ? event.first / event.rows : 0
    if (event?.sortField) {
       sortFieldCompras.value = event.sortField
       sortOrderCompras.value = event.sortOrder
    }
    
    const month = fechaFiltroCompras.value.getMonth()
    const year = fechaFiltroCompras.value.getFullYear()
    const desde = new Date(year, month, 1).toISOString()
    const hasta = new Date(year, month + 1, 0, 23, 59, 59).toISOString()

    const result = await fetchCompras({
      desde,
      hasta,
      page: page,
      rows: event?.rows ?? 10,
      sortField: sortFieldCompras.value,
      sortOrder: sortOrderCompras.value,
      searchProveedor: searchProveedor.value,
      incluirAnuladas: incluirComprasAnuladas.value
    })
    compras.value = result.data
    totalComprasRecords.value = result.total
  } catch (error: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: error.message, life: 3000 })
  } finally {
    loadingCompras.value = false
  }
}

const onSearchProveedor = useDebounceFn(() => {
    loadComprasData()
}, 500)

watch([fechaFiltroCompras], () => {
    loadComprasData()
    loadComprasStats()
})

watch([searchProveedor], () => onSearchProveedor())
watch([incluirComprasAnuladas], () => loadComprasData())

onMounted(() => {
    loadStats()
    loadVendedores()
    loadVentasData()
    loadCategorias()
    loadInventarioStats()
    loadInventarioData()
    loadComprasData()
    loadComprasStats()
    loadCierresData()
    if (isAdmin.value) loadAuditoriaInv()
})

const loadCierresData = async (event?: any) => {
  loadingCierres.value = true
  try {
    const page = event?.first !== undefined ? event.first / event.rows : 0
    if (event?.sortField) {
      sortFieldCierres.value = event.sortField
      sortOrderCierres.value = event.sortOrder
    }
    
    const result = await fetchCierres({
      desde: desde.value.toISOString(),
      hasta: hasta.value.toISOString(),
      page: page,
      rows: event?.rows ?? 10,
      sortField: sortFieldCierres.value,
      sortOrder: sortOrderCierres.value
    })
    cierres.value = result.data
    totalCierresRecords.value = result.total
  } catch (error: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: error.message, life: 3000 })
  } finally {
    loadingCierres.value = false
  }
}

const openCierreDetails = async (cierre: any) => {
  closureDetailsModal.value = true
  loadingClosureDetails.value = true
  try {
    const fullCierre = await fetchCierreById(cierre.id)
    selectedClosure.value = fullCierre
  } catch (error: any) {
    toast.add({ severity: 'error', summary: 'Error al obtener el detalle', detail: error.message, life: 3000 })
    closureDetailsModal.value = false
  } finally {
    loadingClosureDetails.value = false
  }
}

const formatDateTime = (dateString: string) => {
  return new Date(dateString).toLocaleString('es-VE')
}

const loadAuditoriaInv = async (event?: any) => {
  loadingAuditoriaInv.value = true
  try {
    const month = fechaFiltroAuditoria.value.getMonth()
    const year = fechaFiltroAuditoria.value.getFullYear()
    const startDate = new Date(year, month, 1).toISOString()
    const endDate = new Date(year, month + 1, 0, 23, 59, 59).toISOString()

    const page = event?.first !== undefined ? event.first / event.rows : 0
    const result = await fetchInventarioAuditoria({
      desde: startDate,
      hasta: endDate,
      page,
      rows: event?.rows ?? 10,
      accion: accionAuditoria.value ?? undefined,
      search: searchAuditoria.value || undefined
    })
    auditoriaInv.value = result.data
    totalAuditoriaInv.value = result.total
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 3000 })
  } finally {
    loadingAuditoriaInv.value = false
  }
}

const onSearchAuditoria = useDebounceFn(() => loadAuditoriaInv(), 500)
watch([searchAuditoria, fechaFiltroAuditoria], () => loadAuditoriaInv())
watch([accionAuditoria], () => loadAuditoriaInv())

const periodLabelAuditoria = computed(() => {
  const months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre']
  return `${months[fechaFiltroAuditoria.value.getMonth()]} ${fechaFiltroAuditoria.value.getFullYear()}`
})

const openAuditoriaDetail = (row: any) => {
  selectedAuditoria.value = row
  auditoriaDetailModal.value = true
}

const getCategoriaNombre = (id: string | null) => {
  if (!id) return null
  const cat = categoriasList.value.find(c => c.id === id)
  return cat ? cat.nombre : id
}

const auditoriaCampos = computed(() => {
  const row = selectedAuditoria.value
  if (!row) return []
  const antes = row.valor_anterior || {}
  const despues = row.valor_nuevo || {}
  
  // Mapeo de campos a mostrar con su etiqueta
  const labels: Record<string, string> = {
    nombre: 'Nombre',
    codigo_parte: 'Código',
    stock: 'Stock',
    precio_venta: 'Precio venta',
    // imagen_url: 'Imagen URL', // Ocultado según requerimiento
    categoria_id: 'Categoría',
    activo: 'Activo'
  }
  
  const keys = Object.keys(labels)
  return keys.map(k => {
    let valAntes = antes[k]
    let valDespues = row.accion === 'DELETE' ? null : despues[k]

    // Formatear categorías si es necesario
    if (k === 'categoria_id') {
      valAntes = getCategoriaNombre(valAntes)
      valDespues = getCategoriaNombre(valDespues)
    }

    return {
      key: k,
      label: labels[k],
      antes: valAntes,
      despues: valDespues,
      cambio: row.accion === 'DELETE' ? false : JSON.stringify(antes[k]) !== JSON.stringify(despues[k])
    }
  })
})


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

const formatCurrency = (value: number) => {
  return value.toLocaleString('es-VE', { style: 'currency', currency: 'USD' })
}

const formatDate = (dateString: string) => {
  return new Date(dateString).toLocaleDateString('es-VE')
}

const cards = computed(() => [
  { label: 'Total Ventas', value: stats.value.totalVentas, icon: ShoppingCart, color: 'text-blue-600', bg: 'bg-blue-100' },
  { label: 'Ingresos', value: `$${stats.value.totalIngresos.toFixed(2)}`, icon: DollarSign, color: 'text-emerald-600', bg: 'bg-emerald-100' },
  { label: 'Promedio/Venta', value: `$${stats.value.promedioVenta.toFixed(2)}`, icon: TrendingUp, color: 'text-purple-600', bg: 'bg-purple-100' }
])
</script>

<template>
  <div class="flex flex-col gap-6">
    <!-- Header Global de Reportes -->
    <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">
      <div class="flex items-center gap-3 flex-wrap">
        <h1 class="text-2xl font-bold text-slate-800 m-0">Centro de Reportes</h1>
        <NuxtLink to="/reportes/cierres">
          <Button severity="secondary" outlined size="small" class="bg-white flex items-center gap-2">
            <ClipboardList class="w-4 h-4" />
            Cierres de Caja
          </Button>
        </NuxtLink>
        <NuxtLink to="/reportes/movimientos">
          <Button severity="secondary" outlined size="small" class="bg-white flex items-center gap-2">
            <Wallet class="w-4 h-4" />
            Movimientos
          </Button>
        </NuxtLink>
      </div>
      <div class="flex items-end gap-3">
        <label class="text-xs font-bold text-slate-500 uppercase mb-2">Período:</label>
        <div class="flex flex-col gap-1">
            <span class="text-[10px] text-slate-400 font-bold uppercase">Fecha Inicio</span>
            <DatePicker v-model="desde" date-format="dd/mm/yy" placeholder="Desde" show-icon />
        </div>
        <span class="text-slate-400 mb-2">-</span>
        <div class="flex flex-col gap-1">
            <span class="text-[10px] text-slate-400 font-bold uppercase">Fecha Fin</span>
            <DatePicker v-model="hasta" date-format="dd/mm/yy" placeholder="Hasta" show-icon />
        </div>
      </div>
    </div>

    <!-- Navegación por Pestañas -->
    <Tabs value="ventas">
      <TabList class="mb-4">
        <Tab value="ventas">
          <div class="flex items-center gap-2 font-medium">
             <DollarSign class="w-4 h-4" /> Ventas e Ingresos
          </div>
        </Tab>
        <Tab value="cierres">
          <div class="flex items-center gap-2 font-medium">
             <ClipboardList class="w-4 h-4" /> Cierres de Caja
          </div>
        </Tab>
        <Tab value="inventario">
          <div class="flex items-center gap-2 font-medium">
             <Package class="w-4 h-4" /> Inventario y Stock
          </div>
        </Tab>
        <Tab value="proveedores">
          <div class="flex items-center gap-2 font-medium">
             <Users class="w-4 h-4" /> Proveedores y Compras
          </div>
        </Tab>
        <Tab v-if="isAdmin" value="auditoria">
          <div class="flex items-center gap-2 font-medium">
             <History class="w-4 h-4" /> Auditoría Inventario
          </div>
        </Tab>
      </TabList>

      <TabPanels>
        <!-- PANEL: VENTAS -->
        <TabPanel value="ventas">
          <div class="flex flex-col gap-6">
            <!-- KPIs -->
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div
                v-for="card in cards"
                :key="card.label"
                class="bg-white rounded-xl shadow-sm border border-slate-200 p-6 flex items-center gap-5"
              >
                <div :class="[card.bg, card.color, 'w-14 h-14 rounded-full flex items-center justify-center']">
                  <component :is="card.icon" class="w-7 h-7" />
                </div>
                <div>
                  <p class="text-xs font-bold text-slate-400 uppercase tracking-widest">{{ card.label }}</p>
                  <p class="text-2xl font-black text-slate-800 mt-1">{{ card.value }}</p>
                </div>
              </div>
            </div>

            <!-- Detalle Analítico de Ventas -->
            <div class="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
                <div class="px-4 py-3 border-b border-slate-100 flex flex-col gap-1">
                  <h3 class="font-bold text-slate-800 flex items-center gap-2">
                     <ReceiptText class="w-4 h-4 text-slate-400" />
                      Detalle Analítico de Ventas
                  </h3>
                  <p class="text-xs text-slate-500">Consulta el historial de tickets, montos y responsables de venta dentro del rango de fechas establecido.</p>
                </div>

                <!-- Barra de Filtros -->
                <div class="p-4 bg-slate-50/50 border-b border-slate-100 flex flex-col md:flex-row gap-4">
                  <div class="flex-1">
                    <IconField>
                      <InputIcon>
                        <Search class="w-4 h-4 text-slate-400" />
                      </InputIcon>
                      <InputText
                        v-model="searchCliente"
                        placeholder="Buscar por cliente..."
                        class="w-full"
                      />
                    </IconField>
                  </div>
                  <div class="w-full md:w-64">
                    <Select
                      v-model="selectedVendedor"
                      :options="vendedoresConVentas"
                      optionLabel="nombre"
                      placeholder="Filtrar por vendedor"
                      showClear
                      class="w-full"
                      :loading="loadingVendedores"
                    >
                      <template #option="slotProps">
                        <div class="flex items-center gap-2">
                          <div class="w-2 h-2 rounded-full bg-blue-400"></div>
                          <span>{{ slotProps.option.nombre }}</span>
                        </div>
                      </template>
                    </Select>
                  </div>
                  <div class="flex items-center gap-2 px-3 py-2 bg-white border border-slate-200 rounded-lg">
                    <ToggleSwitch v-model="incluirVentasAnuladas" inputId="toggleVentasAnuladas" />
                    <label for="toggleVentasAnuladas" class="text-[10px] font-bold text-slate-500 uppercase tracking-widest whitespace-nowrap cursor-pointer select-none">
                      Mostrar anuladas
                    </label>
                  </div>
                </div>

                <div class="p-4">
                 <DataTable
                   :value="ventas"
                   dataKey="id"
                   :paginator="true"
                   :rows="10"
                   :totalRecords="totalVentasRecords"
                   :loading="loadingVentas"
                   @page="loadVentasData"
                   @sort="loadVentasData"
                   :sortField="sortFieldVentas"
                   :sortOrder="sortOrderVentas"
                   lazy
                   stripedRows
                   class="p-datatable-sm"
                   :rowClass="(data: any) => data.anulada ? 'opacity-60' : ''"
                 >
                   <Column field="id" header="Ticket" sortable>
                     <template #body="slotProps">
                       <span class="font-bold text-primary" :class="{ 'line-through': slotProps.data.anulada }">#{{ slotProps.data.id.slice(0, 8).toUpperCase() }}</span>
                     </template>
                   </Column>
                   <Column field="fecha" header="Fecha" sortable>
                     <template #body="slotProps">
                       {{ formatDate(slotProps.data.fecha) }}
                     </template>
                   </Column>
                   <Column field="clientes(nombre)" header="Cliente" sortable>
                       <template #body="slotProps">
                         {{ slotProps.data.clientes?.nombre ?? '-' }}
                       </template>
                   </Column>
                   <Column field="vendedor(nombre)" header="Cajero" sortable>
                       <template #body="slotProps">
                         <span class="text-xs text-slate-500">{{ slotProps.data.vendedor?.nombre ?? 'Sistema' }}</span>
                       </template>
                   </Column>
                   <Column field="total" header="Monto" sortable>
                     <template #body="slotProps">
                       <span class="font-bold text-slate-800" :class="{ 'line-through': slotProps.data.anulada }">{{ formatCurrency(slotProps.data.total) }}</span>
                     </template>
                   </Column>
                   <Column header="Estado">
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
                            severity="secondary"
                            text
                            rounded
                            @click="openAnularVentaModal(slotProps.data)"
                            class="text-rose-600 hover:bg-rose-50 p-2"
                            v-tooltip.top="'Anular venta'"
                          >
                            <Ban class="w-5 h-5" />
                          </Button>
                        </div>
                      </template>
                    </Column>
                   <template #empty>
                     <div class="flex flex-col items-center justify-center py-10 text-slate-400">
                       <Search class="w-10 h-10 mb-2 opacity-20" />
                       <p class="font-medium">No se encontraron ventas con los filtros aplicados</p>
                     </div>
                   </template>
                 </DataTable>
               </div>
            </div>
          </div>
        </TabPanel>

        <!-- PANEL: INVENTARIO -->
        <TabPanel value="inventario">
          <div class="flex flex-col gap-6">
            <!-- KPIs -->
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div class="bg-white rounded-xl shadow-sm border border-slate-200 p-6 flex items-center gap-5">
                <div class="bg-blue-100 text-blue-600 w-14 h-14 rounded-full flex items-center justify-center">
                  <Package class="w-7 h-7" />
                </div>
                <div>
                  <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Unidades en Stock</p>
                  <p class="text-xl font-black text-slate-800 mt-1" v-if="!loadingInvStats">{{ invStats.totalItems.toLocaleString() }} Items</p>
                  <Skeleton v-else width="5rem" height="1.5rem" class="mt-1" />
                </div>
              </div>
              
              <div class="bg-white rounded-xl shadow-sm border border-slate-200 p-6 flex items-center gap-5">
                <div class="bg-emerald-100 text-emerald-600 w-14 h-14 rounded-full flex items-center justify-center">
                  <DollarSign class="w-7 h-7" />
                </div>
                <div>
                  <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Valor Venta Stock</p>
                  <p class="text-xl font-black text-slate-800 mt-1" v-if="!loadingInvStats">{{ formatCurrency(invStats.totalVenta) }}</p>
                  <Skeleton v-else width="5rem" height="1.5rem" class="mt-1" />
                </div>
              </div>

              <div class="bg-white rounded-xl shadow-sm border border-slate-200 p-6 flex items-center gap-5">
                <div class="bg-red-100 text-red-600 w-14 h-14 rounded-full flex items-center justify-center">
                  <AlertTriangle class="w-7 h-7" />
                </div>
                <div>
                  <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Alertas Stock &lt; 5</p>
                  <p class="text-xl font-black text-slate-800 mt-1" v-if="!loadingInvStats">{{ invStats.bajoStockCount }} Prods</p>
                  <Skeleton v-else width="3rem" height="1.5rem" class="mt-1" />
                </div>
              </div>
            </div>

            <!-- Tabla de Inventario -->
            <div class="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
                <div class="px-4 py-3 border-b border-slate-100 flex flex-col gap-1">
                  <h3 class="font-bold text-slate-800 flex items-center gap-2">
                     <Layers class="w-4 h-4 text-slate-400" />
                      Valoración de Capital por Item
                  </h3>
                  <p class="text-xs text-slate-500">Listado de productos activos con su valor proyectado de venta y estado actual de existencias.</p>
                </div>

                <!-- Barra de Filtros -->
                <div class="p-4 bg-slate-50/50 border-b border-slate-100 flex flex-col md:flex-row gap-4 items-center">
                  <div class="flex-1 w-full">
                    <IconField>
                      <InputIcon>
                        <Search class="w-4 h-4 text-slate-400" />
                      </InputIcon>
                      <InputText 
                        v-model="searchProducto" 
                        placeholder="Buscar producto o código..." 
                        class="w-full"
                      />
                    </IconField>
                  </div>
                  <div class="w-full md:w-64">
                    <Select 
                      v-model="selectedCategoria" 
                      :options="categoriasList" 
                      optionValue="id"
                      optionLabel="nombre" 
                      placeholder="Todas las Categorías" 
                      showClear
                      class="w-full"
                    />
                  </div>
                  <div class="flex items-center gap-2">
                    <ToggleButton v-model="soloBajoStock" onLabel="Bajo Stock" offLabel="Bajo Stock" onIcon="pi pi-exclamation-triangle" offIcon="pi pi-box" class="w-full md:w-auto" />
                  </div>
                </div>

                <div class="p-4">
                 <DataTable 
                   :value="productos" 
                   dataKey="id" 
                   :paginator="true" 
                   :rows="10" 
                   :totalRecords="totalProductosRecords"
                   :loading="loadingProductos"
                   @page="loadInventarioData"
                   @sort="loadInventarioData"
                   :sortField="sortFieldProductos"
                   :sortOrder="sortOrderProductos"
                   lazy
                   stripedRows
                   class="p-datatable-sm"
                 >
                   <Column field="codigo_parte" header="Código" sortable>
                     <template #body="slotProps">
                       <span class="font-mono text-xs text-slate-500">{{ slotProps.data.codigo_parte }}</span>
                     </template>
                   </Column>
                   <Column field="nombre" header="Producto" sortable>
                     <template #body="slotProps">
                       <span class="font-bold text-slate-800">{{ slotProps.data.nombre }}</span>
                     </template>
                   </Column>
                   <Column field="categoria_id" header="Categoría" sortable>
                       <template #body="slotProps">
                         <Tag v-if="slotProps.data.categorias_productos" :value="slotProps.data.categorias_productos.nombre" severity="info" />
                         <span v-else class="text-xs text-slate-400">Genérica</span>
                       </template>
                   </Column>
                   <Column field="stock" header="Stock" sortable>
                       <template #body="{ data }">
                         <Tag
                           :value="String(data.stock)"
                           :severity="data.stock < 5 ? 'danger' : data.stock < 20 ? 'warn' : 'success'"
                         />
                       </template>
                   </Column>
                   <Column field="precio_venta" header="Venta U." sortable>
                     <template #body="slotProps">
                       <span class="font-medium text-slate-700">{{ formatCurrency(slotProps.data.precio_venta) }}</span>
                     </template>
                   </Column>
                   <template #empty>
                     <div class="flex flex-col items-center justify-center py-10 text-slate-400">
                       <Package class="w-10 h-10 mb-2 opacity-20" />
                       <p class="font-medium">No se encontraron productos en el inventario</p>
                     </div>
                   </template>
                 </DataTable>
               </div>
            </div>
          </div>
        </TabPanel>

        <!-- PANEL: PROVEEDORES Y COMPRAS -->
        <TabPanel value="proveedores">
          <div class="flex flex-col gap-6">
            <!-- KPIs -->
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div class="bg-white rounded-xl shadow-sm border border-slate-200 p-6 flex items-center gap-5">
                <div class="bg-orange-100 text-orange-600 w-14 h-14 rounded-full flex items-center justify-center">
                  <ReceiptText class="w-7 h-7" />
                </div>
                <div>
                  <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Facturas del Mes</p>
                  <p class="text-xl font-black text-slate-800 mt-1" v-if="!loadingComprasStats">{{ comprasStats.totalFacturas }} Facturas</p>
                  <Skeleton v-else width="4rem" height="1.5rem" class="mt-1" />
                </div>
              </div>
              
              <div class="bg-white rounded-xl shadow-sm border border-slate-200 p-6 flex items-center gap-5">
                <div class="bg-blue-100 text-blue-600 w-14 h-14 rounded-full flex items-center justify-center">
                  <DollarSign class="w-7 h-7" />
                </div>
                <div>
                  <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Gasto Total Mes</p>
                  <p class="text-xl font-black text-slate-800 mt-1" v-if="!loadingComprasStats">{{ formatCurrency(comprasStats.totalGastado) }}</p>
                  <Skeleton v-else width="6rem" height="1.5rem" class="mt-1" />
                </div>
              </div>

              <div class="bg-white rounded-xl shadow-sm border border-slate-200 p-6 flex items-center gap-5">
                <div class="bg-indigo-100 text-indigo-600 w-14 h-14 rounded-full flex items-center justify-center">
                  <Users class="w-7 h-7" />
                </div>
                <div>
                  <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Proveedores Activos</p>
                  <p class="text-xl font-black text-slate-800 mt-1">Suministros MotoSys</p>
                </div>
              </div>
            </div>

            <!-- Tabla de Compras -->
            <div class="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
                <div class="px-4 py-3 border-b border-slate-100 flex flex-col gap-1">
                  <h3 class="font-bold text-slate-800 flex items-center gap-2">
                     <ShoppingCart class="w-4 h-4 text-slate-400" />
                      Historial de Compras a Proveedores
                  </h3>
                  <p class="text-xs text-slate-500">Listado cronológico de facturas de compra y abastecimiento.</p>
                </div>

                <!-- Barra de Filtros -->
                <div class="p-4 bg-slate-50/50 border-b border-slate-100 flex flex-col md:flex-row gap-4 items-center">
                  <div class="flex-1 w-full">
                    <IconField>
                      <InputIcon>
                        <Search class="w-4 h-4 text-slate-400" />
                      </InputIcon>
                      <InputText
                        v-model="searchProveedor"
                        placeholder="Buscar por nombre de proveedor..."
                        class="w-full"
                      />
                    </IconField>
                  </div>
                  <div class="flex items-center gap-2 px-3 py-2 bg-white border border-slate-200 rounded-lg">
                    <ToggleSwitch v-model="incluirComprasAnuladas" inputId="toggleCompAnuladas" />
                    <label for="toggleCompAnuladas" class="text-[10px] font-bold text-slate-500 uppercase tracking-widest whitespace-nowrap cursor-pointer select-none">
                      Mostrar anuladas
                    </label>
                  </div>
                  <div class="flex items-center gap-3">
                    <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest whitespace-nowrap">Mes:</label>
                    <DatePicker
                      v-model="fechaFiltroCompras"
                      view="month"
                      dateFormat="mm/yy"
                      placeholder="Mes"
                      showIcon
                      class="w-full md:w-40"
                    />
                  </div>
                </div>

                <div class="p-4">
                 <DataTable
                   :value="compras"
                   dataKey="id"
                   :paginator="true"
                   :rows="10"
                   :totalRecords="totalComprasRecords"
                   :loading="loadingCompras"
                   @page="loadComprasData"
                   @sort="loadComprasData"
                   :sortField="sortFieldCompras"
                   :sortOrder="sortOrderCompras"
                   lazy
                   stripedRows
                   class="p-datatable-sm"
                   :rowClass="(data: any) => data.anulada ? 'opacity-60' : ''"
                 >
                   <Column field="numero_factura" header="N° Factura" sortable>
                     <template #body="slotProps">
                       <span class="font-bold text-indigo-600 uppercase" :class="{ 'line-through': slotProps.data.anulada }">{{ slotProps.data.numero_factura }}</span>
                     </template>
                   </Column>
                   <Column field="proveedores(nombre)" header="Proveedor" sortable>
                     <template #body="slotProps">
                       <span class="font-medium text-slate-700">{{ slotProps.data.proveedores?.nombre ?? 'Desconocido' }}</span>
                     </template>
                   </Column>
                   <Column field="fecha" header="Fecha Compra" sortable>
                       <template #body="slotProps">
                         {{ formatDate(slotProps.data.fecha) }}
                       </template>
                   </Column>
                   <Column field="total" header="Monto Total" sortable>
                     <template #body="slotProps">
                       <span class="font-black text-slate-800" :class="{ 'line-through': slotProps.data.anulada }">{{ formatCurrency(slotProps.data.total) }}</span>
                     </template>
                   </Column>
                   <Column header="Estado">
                     <template #body="slotProps">
                       <Tag v-if="slotProps.data.anulada" severity="danger" value="ANULADA" />
                       <Tag v-else severity="success" value="Vigente" />
                     </template>
                   </Column>
                   <Column :exportable="false" header="Acciones">
                      <template #body="slotProps">
                        <Button severity="secondary" text rounded @click="openPurchaseDetails(slotProps.data)" class="text-blue-500 hover:bg-blue-50 p-2">
                          <Eye class="w-5 h-5" />
                        </Button>
                      </template>
                    </Column>
                   <template #empty>
                     <div class="flex flex-col items-center justify-center py-10 text-slate-400">
                       <ShoppingCart class="w-10 h-10 mb-2 opacity-20" />
                       <p class="font-medium">No se registraron compras en este período</p>
                     </div>
                   </template>
                 </DataTable>
               </div>
            </div>
          </div>
        </TabPanel>

        <!-- PANEL: CIERRES DE CAJA -->
        <TabPanel value="cierres">
          <div class="flex flex-col gap-6">
            <div class="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
                <div class="px-4 py-3 border-b border-slate-100 flex flex-col gap-1">
                  <h3 class="font-bold text-slate-800 flex items-center gap-2">
                     <ClipboardList class="w-4 h-4 text-slate-400" />
                      Historial de Cierres de Caja
                  </h3>
                  <p class="text-xs text-slate-500">Consulta los cierres realizados, responsables y diferencias detectadas.</p>
                </div>

                <div class="p-4">
                  <DataTable 
                    :value="cierres" 
                    dataKey="id" 
                    :paginator="true" 
                    :rows="10" 
                    :totalRecords="totalCierresRecords"
                    :loading="loadingCierres"
                    @page="loadCierresData"
                    @sort="loadCierresData"
                    :sortField="sortFieldCierres"
                    :sortOrder="sortOrderCierres"
                    lazy
                    stripedRows
                    class="p-datatable-sm"
                  >
                    <Column field="fecha" header="Fecha" sortable>
                      <template #body="slotProps">
                        <span class="font-bold text-slate-700">{{ formatDate(slotProps.data.fecha) }}</span>
                      </template>
                    </Column>
                    <Column header="Cerrado el">
                      <template #body="slotProps">
                        <span class="text-xs text-slate-500">{{ formatDateTime(slotProps.data.fecha_hora_cierre) }}</span>
                      </template>
                    </Column>
                    <Column header="Responsable">
                      <template #body="slotProps">
                        <span class="text-sm font-medium">{{ slotProps.data.responsable?.nombre ?? '-' }}</span>
                      </template>
                    </Column>
                    <Column field="total_sistema_usd" header="Sistema" sortable>
                      <template #body="slotProps">
                        <span class="font-medium">{{ formatCurrency(slotProps.data.total_sistema_usd) }}</span>
                      </template>
                    </Column>
                    <Column field="total_contado_usd" header="Contado" sortable>
                      <template #body="slotProps">
                        <span class="font-medium">{{ formatCurrency(slotProps.data.total_contado_usd) }}</span>
                      </template>
                    </Column>
                    <Column field="diferencia_usd" header="Diferencia" sortable>
                      <template #body="{ data }">
                        <span class="font-bold" :class="Number(data.diferencia_usd) === 0 ? 'text-slate-500' : Number(data.diferencia_usd) > 0 ? 'text-emerald-600' : 'text-red-600'">
                          {{ formatCurrency(data.diferencia_usd) }}
                        </span>
                      </template>
                    </Column>
                    <Column field="observaciones" header="Observaciones">
                      <template #body="slotProps">
                        <span class="text-xs text-slate-500 truncate block max-w-[150px] italic">
                          {{ slotProps.data.observaciones || 'Sin notas' }}
                        </span>
                      </template>
                    </Column>
                    <Column :exportable="false" header="Acciones">
                      <template #body="slotProps">
                        <Button severity="secondary" text rounded @click="openCierreDetails(slotProps.data)" class="text-blue-500 hover:bg-blue-50 p-2">
                          <Eye class="w-5 h-5" />
                        </Button>
                      </template>
                    </Column>
                    <template #empty>
                      <div class="flex flex-col items-center justify-center py-10 text-slate-400">
                        <ClipboardList class="w-10 h-10 mb-2 opacity-20" />
                        <p class="font-medium">No hay cierres registrados en este período</p>
                      </div>
                    </template>
                  </DataTable>
                </div>
            </div>
          </div>
        </TabPanel>

        <!-- PANEL: AUDITORÍA INVENTARIO -->
        <TabPanel v-if="isAdmin" value="auditoria">
          <div class="flex flex-col gap-6">
            <div class="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
                <div class="px-4 py-3 border-b border-slate-100 flex flex-col gap-1">
                  <h3 class="font-bold text-slate-800 flex items-center gap-2">
                     <History class="w-4 h-4 text-slate-400" />
                      Cambios y eliminaciones de inventario
                  </h3>
                  <p class="text-xs text-slate-500">Registro de ediciones y eliminaciones de productos con motivo, valor anterior y nuevo valor.</p>
                </div>

                <div class="p-4 bg-slate-50/50 border-b border-slate-100 flex flex-col md:flex-row gap-3 items-center">
                  <div class="flex-1 w-full">
                    <IconField>
                      <InputIcon>
                        <Search class="w-4 h-4 text-slate-400" />
                      </InputIcon>
                      <InputText v-model="searchAuditoria" placeholder="Buscar por código o nombre..." class="w-full" />
                    </IconField>
                  </div>
                  <Select
                    v-model="accionAuditoria"
                    :options="[{ label: 'Todas', value: null }, { label: 'Ediciones', value: 'UPDATE' }, { label: 'Eliminaciones', value: 'DELETE' }]"
                    optionLabel="label"
                    optionValue="value"
                    placeholder="Todas las acciones"
                    class="w-full md:w-56"
                  />
                  <div class="flex items-center gap-2">
                    <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest whitespace-nowrap">Mes:</label>
                    <DatePicker
                      v-model="fechaFiltroAuditoria"
                      view="month"
                      dateFormat="mm/yy"
                      placeholder="Mes"
                      showIcon
                      class="w-full md:w-40"
                    />
                  </div>
                </div>

                <div class="px-4 py-2 bg-blue-50/30 border-b border-slate-100">
                  <p class="text-[10px] font-bold text-blue-600 uppercase tracking-widest m-0 text-center md:text-left">
                    Visualizando auditoría de <span class="text-blue-800">{{ periodLabelAuditoria }}</span>
                  </p>
                </div>

                <div class="p-4">
                  <DataTable
                    :value="auditoriaInv"
                    dataKey="id"
                    :paginator="true"
                    :rows="10"
                    :totalRecords="totalAuditoriaInv"
                    :loading="loadingAuditoriaInv"
                    @page="loadAuditoriaInv"
                    lazy
                    stripedRows
                    class="p-datatable-sm"
                  >
                    <Column header="Fecha">
                      <template #body="slotProps">
                        <span class="text-xs text-slate-500">{{ formatDateTime(slotProps.data.created_at) }}</span>
                      </template>
                    </Column>
                    <Column header="Acción">
                      <template #body="slotProps">
                        <Tag
                          v-if="slotProps.data.accion === 'DELETE'"
                          severity="danger"
                          value="ELIMINADO"
                          :icon="undefined"
                        >
                          <div class="flex items-center gap-1 px-1">
                            <Trash2 class="w-3 h-3" />
                            <span>ELIMINADO</span>
                          </div>
                        </Tag>
                        <Tag v-else severity="warn">
                          <div class="flex items-center gap-1 px-1">
                            <Pencil class="w-3 h-3" />
                            <span>EDITADO</span>
                          </div>
                        </Tag>
                      </template>
                    </Column>
                    <Column header="Producto">
                      <template #body="slotProps">
                        <div class="flex flex-col">
                          <span class="font-bold text-indigo-600 uppercase text-xs">{{ slotProps.data.codigo_parte }}</span>
                          <span class="text-sm text-slate-700">{{ slotProps.data.nombre }}</span>
                        </div>
                      </template>
                    </Column>
                    <Column header="Usuario">
                      <template #body="slotProps">
                        <span class="text-sm">{{ slotProps.data.usuario?.nombre ?? '—' }}</span>
                      </template>
                    </Column>
                    <Column header="Motivo">
                      <template #body="slotProps">
                        <span class="text-xs text-slate-600 italic truncate block max-w-[280px]">
                          {{ slotProps.data.motivo }}
                        </span>
                      </template>
                    </Column>
                    <Column :exportable="false" header="Detalle">
                      <template #body="slotProps">
                        <Button severity="secondary" text rounded @click="openAuditoriaDetail(slotProps.data)" class="text-blue-500 hover:bg-blue-50 p-2">
                          <Eye class="w-5 h-5" />
                        </Button>
                      </template>
                    </Column>
                    <template #empty>
                      <div class="flex flex-col items-center justify-center py-10 text-slate-400">
                        <History class="w-10 h-10 mb-2 opacity-20" />
                        <p class="font-medium">Sin registros de auditoría en el período</p>
                      </div>
                    </template>
                  </DataTable>
                </div>
            </div>
          </div>
        </TabPanel>
      </TabPanels>
    </Tabs>

    <!-- Modal Detalle Venta -->
    <Dialog v-model:visible="detailsModal" :style="{ width: '700px' }" modal :closable="!loadingDetails" class="p-fluid">
       <template #header>
          <div class="flex items-center gap-2">
             <ReceiptText class="w-6 h-6 text-slate-500" />
             <h2 class="font-bold text-xl text-slate-800 m-0">Detalle de Venta</h2>
          </div>
       </template>
       
       <div v-if="loadingDetails" class="flex flex-col items-center justify-center p-12">
          <span class="w-10 h-10 border-4 border-slate-200 border-t-blue-500 rounded-full animate-spin mb-4"></span>
          <span class="text-slate-500 font-medium">Cargando recibo...</span>
       </div>
       
       <div v-else-if="selectedVenta" class="space-y-6 pt-2">
          <!-- Banner ANULADA -->
          <div v-if="selectedVenta.anulada" class="bg-rose-50 border-2 border-rose-200 rounded-xl p-4">
             <div class="flex items-start gap-3">
                <Ban class="w-6 h-6 text-rose-600 flex-shrink-0 mt-0.5" />
                <div class="flex-1">
                   <p class="text-rose-800 font-black uppercase tracking-widest text-xs mb-1">Venta anulada</p>
                   <p class="text-sm text-rose-900 font-medium mb-2">{{ selectedVenta.motivo_anulacion }}</p>
                   <p class="text-xs text-rose-700">
                      Anulada por <b>{{ selectedVenta.anulada_por_perfil?.nombre ?? 'Sistema' }}</b>
                      el {{ formatDateTime(selectedVenta.anulada_at) }}
                   </p>
                   <p v-if="selectedVenta.reemplazo" class="text-xs text-rose-700 mt-2 flex items-center gap-1">
                      <RotateCcw :size="12" />
                      Reemplazada por venta <b>#{{ selectedVenta.reemplazo.id.slice(0, 8).toUpperCase() }}</b> ({{ formatDate(selectedVenta.reemplazo.fecha) }})
                   </p>
                </div>
             </div>
          </div>

          <!-- Banner CORRECCIÓN -->
          <div v-if="selectedVenta.corrige" class="bg-amber-50 border border-amber-200 rounded-xl p-3">
             <div class="flex items-center gap-2 text-xs text-amber-900">
                <FilePlus :size="14" />
                Esta venta reemplaza a la venta anulada <b>#{{ selectedVenta.corrige.id.slice(0, 8).toUpperCase() }}</b> ({{ formatDate(selectedVenta.corrige.fecha) }})
             </div>
          </div>

          <!-- Cabecera documento -->
          <div class="flex justify-between items-start bg-slate-50 p-4 rounded-xl border border-slate-200">
             <div>
                <p class="text-[10px] text-slate-400 font-bold uppercase tracking-widest mb-1">CLIENTE</p>
                <p class="font-black text-slate-800 text-lg leading-none">{{ selectedVenta.clientes?.nombre ?? '-' }}</p>
             </div>
             <div class="text-right">
                <p class="text-[10px] text-slate-400 font-bold uppercase tracking-widest mb-1">N° TICKET</p>
                <p class="font-black text-slate-900">#{{ selectedVenta.id.slice(0, 8).toUpperCase() }}</p>
                <p class="text-[10px] text-slate-400 font-bold uppercase tracking-widest mt-3 mb-1">CAJERO</p>
                <p class="text-xs text-slate-600 font-bold">{{ selectedVenta.vendedor?.nombre ?? 'Sistema' }}</p>
                <p class="text-xs text-slate-500 font-medium mt-1">Fecha: {{ formatDate(selectedVenta.fecha) }}</p>
             </div>
          </div>

          <!-- Items -->
          <div class="overflow-x-auto rounded-xl border border-slate-200">
             <table class="w-full text-left bg-white">
                <thead class="bg-slate-50 text-[10px] font-bold text-slate-400 uppercase tracking-widest border-b border-slate-200">
                   <tr>
                      <th class="p-3">PRODUCTO</th>
                      <th class="p-3 w-20 text-center">CANT.</th>
                      <th class="p-3 text-right">PRECIO U.</th>
                      <th class="p-3 text-right pr-4">SUBTOTAL</th>
                   </tr>
                </thead>
                <tbody class="text-sm border-b border-slate-100">
                   <tr v-for="item in (selectedVenta.detalle_ventas as any)" :key="item.id" class="border-b border-slate-50 last:border-0 hover:bg-slate-50/50">
                      <td class="p-3 align-top">
                         <span class="block font-bold text-slate-700">{{ item.productos?.nombre }}</span>
                         <span class="text-xs text-slate-400">{{ item.productos?.codigo_parte }}</span>
                      </td>
                      <td class="p-3 font-bold text-slate-600 align-top text-center">{{ item.cantidad }}</td>
                      <td class="p-3 text-right text-slate-500 align-top">{{ formatCurrency(item.precio_unitario) }}</td>
                      <td class="p-3 text-right font-bold text-slate-800 pr-4 align-top">{{ formatCurrency(item.cantidad * item.precio_unitario) }}</td>
                   </tr>
                </tbody>
             </table>
          </div>

          <!-- Métodos de Pago -->
          <div v-if="selectedVenta.ventas_pagos && selectedVenta.ventas_pagos.length > 0">
             <p class="text-[10px] text-slate-400 font-bold uppercase tracking-widest mb-3 px-1">Resumen de Pagos</p>
             <div class="space-y-2">
                <div v-for="pago in (selectedVenta.ventas_pagos as any)" :key="pago.id" class="flex items-center justify-between p-3 bg-slate-50 border border-slate-100 rounded-lg">
                   <div class="flex items-center gap-3">
                      <div class="p-2 bg-white rounded-md border border-slate-200">
                         <CreditCard class="w-4 h-4 text-slate-400" />
                      </div>
                      <div>
                         <p class="text-sm font-bold text-slate-700 leading-none mb-1">{{ pago.metodos_pago?.nombre }}</p>
                         <p v-if="pago.referencia" class="text-[10px] text-amber-600 font-bold uppercase tracking-wider mb-0.5">Ref: {{ pago.referencia }}</p>
                         <p v-if="pago.tasa_aplicada > 1" class="text-[10px] text-slate-400 font-medium">Tasa: {{ pago.tasa_aplicada.toLocaleString() }} {{ pago.metodos_pago?.moneda }}/$</p>
                      </div>
                   </div>
                   <div class="text-right">
                      <p class="text-sm font-black text-slate-800 leading-none mb-1">{{ pago.monto_recibido.toLocaleString() }} {{ pago.metodos_pago?.moneda }}</p>
                      <p class="text-[10px] text-slate-500 font-bold">({{ formatCurrency(pago.monto_usd) }})</p>
                   </div>
                </div>
             </div>
          </div>

          <!-- Total Footer -->
          <div class="flex justify-between items-center bg-emerald-50/50 p-4 rounded-xl border border-emerald-100 mt-4">
             <span class="text-xs font-bold text-emerald-600 uppercase tracking-widest">TOTAL DE LA VENTA</span>
             <span class="text-2xl font-black text-emerald-700">{{ formatCurrency(selectedVenta.total) }}</span>
          </div>
       </div>

       <template #footer>
          <Button label="Cerrar" text severity="secondary" @click="detailsModal = false" class="mt-2" />
       </template>
    </Dialog>

    <!-- Modal Detalle Compra -->
    <Dialog v-model:visible="purchaseDetailsModal" :style="{ width: '700px' }" modal :closable="!loadingPurchaseDetails" class="p-fluid">
       <template #header>
          <div class="flex items-center gap-2">
             <ReceiptText class="w-6 h-6 text-slate-500" />
             <h2 class="font-bold text-xl text-slate-800 m-0">Detalle de Compra</h2>
          </div>
       </template>
       
       <div v-if="loadingPurchaseDetails" class="flex flex-col items-center justify-center p-12">
          <span class="w-10 h-10 border-4 border-slate-200 border-t-blue-500 rounded-full animate-spin mb-4"></span>
          <span class="text-slate-500 font-medium">Cargando recibo...</span>
       </div>
       
       <div v-else-if="selectedPurchase" class="space-y-6 pt-2">
          <!-- Banner ANULADA -->
          <div v-if="selectedPurchase.anulada" class="bg-rose-50 border-2 border-rose-200 rounded-xl p-4">
             <div class="flex items-start gap-3">
                <Ban class="w-6 h-6 text-rose-600 flex-shrink-0 mt-0.5" />
                <div class="flex-1">
                   <p class="text-rose-800 font-black uppercase tracking-widest text-xs mb-1">Compra anulada</p>
                   <p class="text-sm text-rose-900 font-medium mb-2">{{ selectedPurchase.motivo_anulacion }}</p>
                   <p class="text-xs text-rose-700">
                      Anulada por <b>{{ selectedPurchase.anulada_por_perfil?.nombre ?? 'Sistema' }}</b>
                      el {{ formatDateTime(selectedPurchase.anulada_at) }}
                   </p>
                   <p v-if="selectedPurchase.reemplazo" class="text-xs text-rose-700 mt-2 flex items-center gap-1">
                      <RotateCcw :size="12" />
                      Reemplazada por compra <b>#{{ selectedPurchase.reemplazo.numero }}</b> ({{ formatDate(selectedPurchase.reemplazo.fecha) }})
                   </p>
                </div>
             </div>
          </div>

          <!-- Banner CORRECCIÓN -->
          <div v-if="selectedPurchase.corrige" class="bg-amber-50 border border-amber-200 rounded-xl p-3">
             <div class="flex items-center gap-2 text-xs text-amber-900">
                <FilePlus :size="14" />
                Esta compra reemplaza a la compra anulada <b>#{{ selectedPurchase.corrige.numero }}</b> ({{ formatDate(selectedPurchase.corrige.fecha) }})
             </div>
          </div>

          <!-- Cabecera documento -->
          <div class="flex justify-between items-start bg-slate-50 p-4 rounded-xl border border-slate-200">
             <div>
                <p class="text-[10px] text-slate-400 font-bold uppercase tracking-widest mb-1">PROVEEDOR</p>
                <p class="font-black text-slate-800 text-lg leading-none">{{ selectedPurchase.proveedores?.nombre }}</p>
                <p class="text-xs text-slate-500 mt-1">
                   <span v-if="selectedPurchase.proveedores?.telefono">Tel: {{ selectedPurchase.proveedores.telefono }}</span>
                </p>
             </div>
             <div class="text-right">
                <p class="text-[10px] text-slate-400 font-bold uppercase tracking-widest mb-1">N° FACTURA</p>
                <p class="font-black text-slate-900">{{ selectedPurchase.numero_factura }}</p>
                <p class="text-xs text-slate-500 font-medium mt-1">Fecha: {{ formatDate(selectedPurchase.fecha) }}</p>
             </div>
          </div>

          <!-- Items -->
          <div class="overflow-x-auto rounded-xl border border-slate-200">
             <table class="w-full text-left bg-white">
                <thead class="bg-slate-50 text-[10px] font-bold text-slate-400 uppercase tracking-widest border-b border-slate-200">
                   <tr>
                      <th class="p-3">PRODUCTO</th>
                      <th class="p-3 w-20 text-center">CANT.</th>
                      <th class="p-3 text-right">COSTO U.</th>
                      <th class="p-3 text-right pr-4">SUBTOTAL</th>
                   </tr>
                </thead>
                <tbody class="text-sm border-b border-slate-100">
                   <tr v-for="item in selectedPurchase.detalle_compras" :key="item.id" class="border-b border-slate-50 last:border-0 hover:bg-slate-50/50">
                      <td class="p-3 align-top">
                         <span class="block font-bold text-slate-700">{{ item.productos?.nombre }}</span>
                         <span class="text-xs text-slate-400">{{ item.productos?.codigo_parte }}</span>
                      </td>
                      <td class="p-3 font-bold text-slate-600 align-top text-center">{{ item.cantidad }}</td>
                      <td class="p-3 text-right text-slate-500 align-top">{{ formatCurrency(item.costo_unitario) }}</td>
                      <td class="p-3 text-right font-bold text-slate-800 pr-4 align-top">{{ formatCurrency(item.subtotal) }}</td>
                   </tr>
                </tbody>
             </table>
          </div>

          <!-- Total Footer -->
          <div class="flex flex-col gap-2 bg-blue-50/50 p-4 rounded-xl border border-blue-100 mt-4">
             <div class="flex justify-between items-center text-sm" v-if="selectedPurchase.subtotal">
                <span class="text-slate-500 font-bold uppercase">Subtotal</span>
                <span class="font-bold text-slate-700">{{ formatCurrency(selectedPurchase.subtotal) }}</span>
             </div>
             <div class="flex justify-between items-center text-sm border-b border-blue-200/50 pb-2" v-if="selectedPurchase.iva !== undefined">
                <span class="text-slate-500 font-bold uppercase">IVA</span>
                <span class="font-bold text-slate-700">{{ formatCurrency(selectedPurchase.iva) }}</span>
             </div>
             <div class="flex justify-between items-center pt-1">
                <span class="text-xs font-bold text-blue-600 uppercase tracking-widest">TOTAL FACTURA</span>
                <span class="text-2xl font-black text-blue-700">{{ formatCurrency(selectedPurchase.total) }}</span>
             </div>
          </div>
       </div>

        <template #footer>
          <Button label="Cerrar" text severity="secondary" @click="purchaseDetailsModal = false" />
        </template>
     </Dialog>

     <!-- Modal Detalle Cierre -->
     <Dialog v-model:visible="closureDetailsModal" :style="{ width: '750px' }" modal :closable="!loadingClosureDetails" class="p-fluid">
        <template #header>
           <div class="flex items-center gap-2">
              <ClipboardList class="w-6 h-6 text-slate-500" />
              <h2 class="font-bold text-xl text-slate-800 m-0">Detalle de Cierre</h2>
           </div>
        </template>
        
        <div v-if="loadingClosureDetails" class="flex flex-col items-center justify-center p-12">
           <span class="w-10 h-10 border-4 border-slate-200 border-t-blue-500 rounded-full animate-spin mb-4"></span>
           <span class="text-slate-500 font-medium">Cargando reporte...</span>
        </div>
        
        <div v-else-if="selectedClosure" class="space-y-6 pt-2">
           <!-- Resumen -->
           <div class="grid grid-cols-2 md:grid-cols-4 gap-4 p-4 bg-slate-50 rounded-xl border border-slate-200">
              <div>
                 <p class="text-[10px] text-slate-400 font-bold uppercase tracking-widest mb-1">FECHA CIERRE</p>
                 <p class="font-black text-slate-800 leading-none">{{ formatDate(selectedClosure.fecha) }}</p>
              </div>
              <div>
                 <p class="text-[10px] text-slate-400 font-bold uppercase tracking-widest mb-1">HORA REGISTRO</p>
                 <p class="text-sm font-bold text-slate-700 leading-none">{{ formatDateTime(selectedClosure.fecha_hora_cierre) }}</p>
              </div>
              <div>
                 <p class="text-[10px] text-slate-400 font-bold uppercase tracking-widest mb-1">RESPONSABLE</p>
                 <p class="text-sm font-bold text-slate-700 leading-none">{{ selectedClosure.responsable?.nombre ?? '-' }}</p>
              </div>
              <div class="text-right">
                 <p class="text-[10px] text-slate-400 font-bold uppercase tracking-widest mb-1">DIFERENCIA TOTAL</p>
                 <p class="font-black leading-none" :class="Number(selectedClosure.diferencia_usd) === 0 ? 'text-slate-700' : Number(selectedClosure.diferencia_usd) > 0 ? 'text-emerald-700' : 'text-red-700'">
                    {{ formatCurrency(selectedClosure.diferencia_usd) }}
                 </p>
              </div>
           </div>

           <!-- Tabla detalle -->
           <div class="overflow-hidden bg-white rounded-xl border border-slate-200 shadow-sm">
             <table class="w-full text-sm">
               <thead class="bg-slate-50 text-[10px] font-bold text-slate-400 uppercase tracking-wider">
                 <tr>
                   <th class="p-3 text-left">Método de Pago</th>
                   <th class="p-3 text-right">Sistema</th>
                   <th class="p-3 text-right">Contado</th>
                   <th class="p-3 text-right">Tasa</th>
                   <th class="p-3 text-right">Diferencia</th>
                 </tr>
               </thead>
               <tbody class="divide-y divide-slate-100">
                 <tr v-for="d in selectedClosure.cierres_caja_detalle" :key="d.id">
                   <td class="p-3">
                     <span class="font-bold text-slate-700">{{ d.metodos_pago?.nombre }}</span>
                     <span class="text-[9px] font-black text-slate-300 ml-1 uppercase">{{ d.metodos_pago?.moneda }}</span>
                   </td>
                   <td class="p-3 text-right">
                     <div class="font-medium text-slate-800">{{ Number(d.monto_sistema).toLocaleString('es', {minimumFractionDigits:2}) }}</div>
                     <div class="text-[9px] text-slate-400">{{ formatCurrency(d.monto_sistema_usd) }}</div>
                   </td>
                   <td class="p-3 text-right">
                     <div class="font-bold text-slate-900">{{ Number(d.monto_contado).toLocaleString('es', {minimumFractionDigits:2}) }}</div>
                     <div class="text-[9px] text-slate-400">{{ formatCurrency(d.monto_contado_usd) }}</div>
                   </td>
                   <td class="p-3 text-right text-xs text-slate-500 font-bold">
                     {{ Number(d.tasa_referencia).toLocaleString('es', {minimumFractionDigits:2}) }}
                   </td>
                   <td class="p-3 text-right">
                     <div class="font-black" :class="Number(d.diferencia) === 0 ? 'text-slate-400' : Number(d.diferencia) > 0 ? 'text-emerald-700' : 'text-red-700'">
                       {{ Number(d.diferencia) > 0 ? '+' : '' }}{{ Number(d.diferencia).toLocaleString('es', {minimumFractionDigits:2}) }}
                     </div>
                   </td>
                 </tr>
               </tbody>
             </table>
           </div>

           <!-- Observaciones -->
           <div v-if="selectedClosure.observaciones" class="p-4 bg-amber-50 rounded-xl border border-amber-200">
             <p class="text-[10px] font-black text-amber-700 uppercase tracking-widest mb-1">Observaciones del Cierre</p>
             <p class="text-sm text-amber-900 whitespace-pre-wrap">{{ selectedClosure.observaciones }}</p>
           </div>
        </div>

        <template #footer>
          <Button label="Cerrar Reporte" text severity="secondary" @click="closureDetailsModal = false" />
        </template>
     </Dialog>

     <!-- Modal Anular Venta -->
     <Dialog v-model:visible="anularVentaModal" :style="{ width: '500px' }" modal :closable="!anulandoVenta" :closeOnEscape="!anulandoVenta">
        <template #header>
           <div class="flex items-center gap-2">
              <Ban class="w-5 h-5 text-rose-600" />
              <h2 class="font-bold text-lg text-slate-800 m-0">Anular venta</h2>
           </div>
        </template>

        <div v-if="ventaAAnular" class="space-y-4">
           <div class="bg-rose-50 border border-rose-200 rounded-lg p-3 text-xs text-rose-900">
              <p class="font-bold mb-1 uppercase tracking-wider text-rose-700">Acción irreversible</p>
              <p>Al anular la venta se repondrá el stock de los productos y la factura quedará marcada como anulada. Para corregirla, registra una nueva venta desde el POS.</p>
           </div>

           <div class="bg-slate-50 border border-slate-200 rounded-lg p-3 text-sm">
              <div class="flex justify-between mb-1">
                 <span class="text-slate-500 text-xs uppercase tracking-wider font-bold">Ticket</span>
                 <span class="font-bold text-slate-800">#{{ ventaAAnular.id.slice(0, 8).toUpperCase() }}</span>
              </div>
              <div class="flex justify-between mb-1">
                 <span class="text-slate-500 text-xs uppercase tracking-wider font-bold">Fecha</span>
                 <span class="text-slate-700">{{ formatDate(ventaAAnular.fecha) }}</span>
              </div>
              <div class="flex justify-between">
                 <span class="text-slate-500 text-xs uppercase tracking-wider font-bold">Total</span>
                 <span class="font-bold text-slate-800">{{ formatCurrency(ventaAAnular.total) }}</span>
              </div>
           </div>

           <div>
              <label for="motivoAnularVenta" class="block text-xs font-bold text-slate-600 uppercase tracking-wider mb-1">
                 Motivo de anulación <span class="text-rose-600">*</span>
              </label>
              <Textarea
                 id="motivoAnularVenta"
                 v-model="motivoAnulacionVenta"
                 rows="3"
                 class="w-full"
                 placeholder="Describe el motivo (mínimo 10 caracteres)"
                 :disabled="anulandoVenta"
              />
              <p class="text-[10px] text-slate-400 mt-1">
                 {{ motivoAnulacionVenta.trim().length }} / 10 caracteres mínimo
              </p>
           </div>
        </div>

        <template #footer>
           <Button label="Cancelar" text severity="secondary" @click="anularVentaModal = false" :disabled="anulandoVenta" />
           <Button
              label="Anular venta"
              severity="danger"
              @click="confirmarAnularVenta"
              :loading="anulandoVenta"
              :disabled="motivoAnulacionVenta.trim().length < 10"
           />
        </template>
     </Dialog>

     <!-- Modal detalle auditoría inventario -->
     <Dialog v-model:visible="auditoriaDetailModal" :style="{ width: '720px' }" modal>
        <template #header>
           <div class="flex items-center gap-2">
              <History class="w-5 h-5 text-slate-500" />
              <h2 class="font-bold text-lg text-slate-800 m-0">Detalle de auditoría</h2>
           </div>
        </template>

        <div v-if="selectedAuditoria" class="space-y-4">
           <div class="grid grid-cols-2 gap-3 text-sm">
              <div>
                 <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Fecha</p>
                 <p class="text-slate-800">{{ formatDateTime(selectedAuditoria.created_at) }}</p>
              </div>
              <div>
                 <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Usuario</p>
                 <p class="text-slate-800">{{ selectedAuditoria.usuario?.nombre ?? '—' }}</p>
              </div>
              <div>
                 <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Acción</p>
                 <Tag
                    :severity="selectedAuditoria.accion === 'DELETE' ? 'danger' : 'warn'"
                    :value="selectedAuditoria.accion === 'DELETE' ? 'ELIMINADO' : 'EDITADO'"
                 />
              </div>
              <div>
                 <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Producto</p>
                 <p class="text-slate-800"><span class="font-bold text-indigo-600">{{ selectedAuditoria.codigo_parte }}</span> — {{ selectedAuditoria.nombre }}</p>
              </div>
           </div>

           <div class="bg-amber-50 border border-amber-200 rounded-lg p-3">
              <p class="text-[10px] font-bold text-amber-700 uppercase tracking-widest mb-1">Motivo</p>
              <p class="text-sm text-amber-900 whitespace-pre-wrap">{{ selectedAuditoria.motivo }}</p>
           </div>

           <div class="border border-slate-200 rounded-lg overflow-hidden">
              <div class="grid grid-cols-3 bg-slate-100 text-[10px] font-bold text-slate-500 uppercase tracking-widest">
                 <div class="px-3 py-2">Campo</div>
                 <div class="px-3 py-2">Valor anterior</div>
                 <div class="px-3 py-2">{{ selectedAuditoria.accion === 'DELETE' ? '—' : 'Valor nuevo' }}</div>
              </div>
              <div
                 v-for="campo in auditoriaCampos"
                 :key="campo.key"
                 class="grid grid-cols-3 text-sm border-t border-slate-100"
                 :class="campo.cambio ? 'bg-amber-50/60' : ''"
              >
                 <div class="px-3 py-2 font-medium text-slate-600">{{ campo.label }}</div>
                 <div class="px-3 py-2 text-slate-800 break-all">
                    <span v-if="campo.antes === null || campo.antes === undefined || campo.antes === ''" class="text-slate-400 italic">vacío</span>
                    <span v-else>{{ campo.antes }}</span>
                 </div>
                 <div class="px-3 py-2 break-all" :class="campo.cambio ? 'text-amber-800 font-semibold' : 'text-slate-800'">
                    <span v-if="selectedAuditoria.accion === 'DELETE'" class="text-slate-400 italic">—</span>
                    <span v-else-if="campo.despues === null || campo.despues === undefined || campo.despues === ''" class="text-slate-400 italic">vacío</span>
                    <span v-else>{{ campo.despues }}</span>
                 </div>
              </div>
           </div>
        </div>

        <template #footer>
           <Button label="Cerrar" text severity="secondary" @click="auditoriaDetailModal = false" />
        </template>
     </Dialog>

     <Toast />
     <Toast position="bottom-right" group="correccion-venta">
        <template #message="{ message, closeCallback }">
           <div class="flex flex-col gap-2 w-full">
              <div class="flex items-start gap-2">
                 <FilePlus class="w-5 h-5 text-indigo-600 flex-shrink-0 mt-0.5" />
                 <div class="flex-1">
                    <p class="font-bold text-slate-800 text-sm">{{ message.summary }}</p>
                    <p class="text-xs text-slate-600">{{ message.detail }}</p>
                 </div>
              </div>
              <div class="flex justify-end gap-2">
                 <Button label="Ahora no" text size="small" @click="closeCallback" />
                 <Button label="Abrir POS" size="small" severity="info" @click="irACorreccionVenta((message as any).data.ventaId); closeCallback()" />
              </div>
           </div>
        </template>
     </Toast>
  </div>
</template>
