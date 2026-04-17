<script setup lang="ts">
import { Wallet, ArrowDownCircle, ArrowUpCircle, Loader2, ClipboardList, RefreshCw, TrendingUp, TrendingDown, Minus } from 'lucide-vue-next'
import { useMovimientosCaja, type TipoMovimiento, type MovimientoCaja } from '~/composables/useMovimientosCaja'
import { useMetodosPago, type MetodoPago } from '~/composables/useMetodosPago'
import { useTasas, type TasaCambio } from '~/composables/useTasas'
import { useCierresCaja, type CierrePreview } from '~/composables/useCierresCaja'

const toast = useToast()
const { isAdmin, perfil } = usePerfil()

watch(perfil, (p) => {
  if (p && p.rol !== 'admin') navigateTo('/')
}, { immediate: true })

const { fetchMovimientos, registrarMovimiento } = useMovimientosCaja()
const { fetchMetodosPago } = useMetodosPago()
const { fetchTasas, syncBcvRate } = useTasas()
const { previewCierre } = useCierresCaja()

const movimientos = ref<MovimientoCaja[]>([])
const metodos = ref<MetodoPago[]>([])
const tasas = ref<TasaCambio[]>([])
const saldos = ref<CierrePreview[]>([])

const loading = ref(false)
const loadingSaldos = ref(false)
const totalRecords = ref(0)
const page = ref(0)
const rows = ref(10)
const sortField = ref('fecha')
const sortOrder = ref(-1)

const filterTipo = ref<TipoMovimiento | null>(null)
const filterMetodo = ref<string | null>(null)
const fechaFiltro = ref(new Date())

const dialogVisible = ref(false)
const savingMov = ref(false)
const form = ref({
  tipo: 'ingreso' as TipoMovimiento,
  metodo_pago_id: '' as string,
  monto: 0,
  motivo: '',
  referencia: ''
})

const selectedMetodo = computed(() => metodos.value.find(m => m.id === form.value.metodo_pago_id) || null)

const tasaParaMoneda = (moneda: string) => {
  if (moneda === 'USD') return 1
  if (moneda === 'COP') return tasas.value.find(t => t.codigo === 'COP')?.tasa || 1
  return tasas.value.find(t => t.codigo === 'BCV')?.tasa || 1
}

const tasaAplicada = computed(() => selectedMetodo.value ? tasaParaMoneda(selectedMetodo.value.moneda) : 1)
const montoUsdCalc = computed(() => {
  if (!selectedMetodo.value || !form.value.monto) return 0
  return form.value.monto / tasaAplicada.value
})

const totalSistemaUsd = computed(() => saldos.value.reduce((acc, s) => acc + Number(s.monto_sistema_usd), 0))

const loadSaldos = async () => {
  loadingSaldos.value = true
  try {
    saldos.value = await previewCierre()
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error saldos', detail: e.message, life: 3000 })
  } finally {
    loadingSaldos.value = false
  }
}

const loadMovimientos = async (event?: any) => {
  loading.value = true
  try {
    const p = event?.first !== undefined ? event.first / event.rows : page.value
    if (event?.rows) rows.value = event.rows
    page.value = p

    if (event?.sortField) {
      sortField.value = event.sortField
      sortOrder.value = event.sortOrder
    }

    // Calcular rango del mes seleccionado
    const selectedDate = new Date(fechaFiltro.value)
    const year = selectedDate.getFullYear()
    const month = selectedDate.getMonth()
    const desde = new Date(year, month, 1).toISOString()
    const hasta = new Date(year, month + 1, 0, 23, 59, 59).toISOString()

    // Solo activar lógica de 'pendientes siempre visibles' si estamos viendo el mes actual real
    const hoy = new Date()
    const esMesActual = year === hoy.getFullYear() && month === hoy.getMonth()

    const { data, total } = await fetchMovimientos({
      page: page.value,
      rows: rows.value,
      sortField: sortField.value,
      sortOrder: sortOrder.value,
      tipo: filterTipo.value || undefined,
      metodoPagoId: filterMetodo.value || undefined,
      desde,
      hasta,
      soloAbiertosOMesActual: esMesActual
    })
    movimientos.value = data
    totalRecords.value = total
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

// Observar cambios en filtros para recargar automáticamente
watch([fechaFiltro, filterTipo, filterMetodo], () => {
  page.value = 0
  loadMovimientos()
})

const loadMetodos = async () => {
  try {
    const data = await fetchMetodosPago()
    metodos.value = data.filter(m => m.activo)
  } catch (e) {
    console.error(e)
  }
}

const loadTasas = async () => {
  try {
    tasas.value = await fetchTasas()
  } catch (e) {
    console.error(e)
  }
}

const openDialog = (tipo: TipoMovimiento) => {
  form.value = { tipo, metodo_pago_id: '', monto: 0, motivo: '', referencia: '' }
  dialogVisible.value = true
}

const saveMovimiento = async () => {
  if (!form.value.metodo_pago_id) {
    toast.add({ severity: 'warn', summary: 'Atención', detail: 'Seleccione un método de pago', life: 3000 })
    return
  }
  if (form.value.monto <= 0) {
    toast.add({ severity: 'warn', summary: 'Atención', detail: 'El monto debe ser mayor a cero', life: 3000 })
    return
  }
  if (!form.value.motivo.trim()) {
    toast.add({ severity: 'warn', summary: 'Atención', detail: 'El motivo es obligatorio', life: 3000 })
    return
  }
  if (selectedMetodo.value?.requiere_detalle && !form.value.referencia.trim()) {
    toast.add({ severity: 'warn', summary: 'Atención', detail: 'Este método requiere referencia', life: 3000 })
    return
  }

  savingMov.value = true
  try {
    await registrarMovimiento({
      tipo: form.value.tipo,
      metodo_pago_id: form.value.metodo_pago_id,
      monto: form.value.monto,
      tasa_aplicada: tasaAplicada.value,
      motivo: form.value.motivo.trim(),
      referencia: form.value.referencia.trim() || null
    })
    toast.add({ severity: 'success', summary: 'Registrado', detail: `${form.value.tipo === 'ingreso' ? 'Ingreso' : 'Egreso'} guardado`, life: 2500 })
    dialogVisible.value = false
    await Promise.all([loadMovimientos(), loadSaldos()])
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 4000 })
  } finally {
    savingMov.value = false
  }
}

const formatCurrency = (v: number) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(v)
const formatDate = (v: string) => new Date(v).toLocaleString('es')

onMounted(async () => {
  await syncBcvRate().catch(() => {})
  await Promise.all([loadMetodos(), loadTasas()])
  await Promise.all([loadMovimientos(), loadSaldos()])
})
</script>

<template>
  <div v-if="isAdmin">
    <!-- Header -->
    <div class="flex items-center justify-between gap-3 mb-6">
      <div class="flex items-center gap-3">
        <div class="p-2 bg-emerald-100 text-emerald-600 rounded-lg">
          <Wallet :size="24" />
        </div>
        <div>
          <h1 class="text-2xl font-bold text-slate-800">Caja</h1>
          <p class="text-slate-500">Saldos actuales y registro de movimientos manuales.</p>
        </div>
      </div>
      <div class="flex gap-2">
        <NuxtLink to="/caja/cierre">
          <Button severity="secondary" outlined class="shadow-sm bg-white flex items-center gap-2">
            <ClipboardList class="w-4 h-4" />
            Cierre del Día
          </Button>
        </NuxtLink>
        <Button severity="success" class="flex items-center gap-2" @click="openDialog('ingreso')">
          <ArrowDownCircle class="w-4 h-4" />
          Ingreso
        </Button>
        <Button severity="danger" class="flex items-center gap-2" @click="openDialog('egreso')">
          <ArrowUpCircle class="w-4 h-4" />
          Egreso
        </Button>
      </div>
    </div>

    <!-- Saldos actuales por método de pago -->
    <div class="mb-6">
      <div class="flex items-center justify-between mb-3">
        <h2 class="text-xs font-black text-slate-400 uppercase tracking-widest">Saldo actual por método de pago</h2>
        <button
          class="flex items-center gap-1 text-xs text-slate-400 hover:text-slate-600 transition-colors"
          :class="{ 'animate-spin pointer-events-none': loadingSaldos }"
          @click="loadSaldos"
        >
          <RefreshCw class="w-3 h-3" :class="{ 'animate-spin': loadingSaldos }" />
          <span v-if="!loadingSaldos">Actualizar</span>
        </button>
      </div>

      <div v-if="loadingSaldos" class="flex justify-center p-8">
        <Loader2 class="animate-spin text-slate-400" :size="24" />
      </div>

      <div v-else-if="saldos.length === 0" class="bg-white rounded-xl border border-slate-200 shadow-sm p-6 text-center text-slate-400 italic text-sm">
        Sin operaciones desde el último cierre.
      </div>

      <div v-else class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-3">
        <!-- Card total general -->
        <div class="bg-gradient-to-br from-slate-700 to-slate-900 text-white rounded-xl shadow-sm p-4 flex flex-col gap-1">
          <span class="text-[10px] font-black uppercase tracking-widest text-slate-300">Total general</span>
          <span class="text-xl font-black">{{ formatCurrency(totalSistemaUsd) }}</span>
          <span class="text-[10px] text-slate-400">en USD equivalente</span>
        </div>

        <!-- Card por método -->
        <div
          v-for="s in saldos"
          :key="s.metodo_pago_id"
          class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 flex flex-col gap-2"
        >
          <div class="flex items-center justify-between">
            <span class="text-xs font-black text-slate-700">{{ s.nombre }}</span>
            <span class="text-[10px] font-bold text-slate-400 uppercase bg-slate-100 px-2 py-0.5 rounded">{{ s.moneda }}</span>
          </div>

          <div class="text-lg font-black" :class="Number(s.monto_sistema) >= 0 ? 'text-slate-800' : 'text-red-600'">
            {{ Number(s.monto_sistema).toLocaleString('es', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }}
          </div>
          <div class="text-[11px] text-slate-400">{{ formatCurrency(Number(s.monto_sistema_usd)) }}</div>

          <!-- Desglose -->
          <div class="border-t border-slate-100 pt-2 flex flex-col gap-1 text-[10px]">
            <div class="flex justify-between items-center text-emerald-700">
              <span class="flex items-center gap-1"><TrendingUp class="w-3 h-3" /> Ventas</span>
              <span class="font-bold">{{ Number(s.total_ventas).toLocaleString('es', {minimumFractionDigits:2}) }}</span>
            </div>
            <div class="flex justify-between items-center text-blue-600">
              <span class="flex items-center gap-1"><ArrowDownCircle class="w-3 h-3" /> Ingresos</span>
              <span class="font-bold">{{ Number(s.total_ingresos).toLocaleString('es', {minimumFractionDigits:2}) }}</span>
            </div>
            <div class="flex justify-between items-center text-red-600">
              <span class="flex items-center gap-1"><ArrowUpCircle class="w-3 h-3" /> Egresos</span>
              <span class="font-bold">{{ Number(s.total_egresos).toLocaleString('es', {minimumFractionDigits:2}) }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Tabla movimientos manuales -->
    <div class="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
      <div class="p-4 border-b border-slate-100 flex flex-wrap items-center justify-between gap-3">
        <span class="text-xs font-black text-slate-400 uppercase tracking-widest">Movimientos manuales</span>
        <div class="flex items-center gap-3">
          <div class="flex items-center gap-2">
            <span class="text-xs font-bold text-slate-400 uppercase">Tipo:</span>
            <Select
              v-model="filterTipo"
              :options="[
                { label: 'Todos', value: null },
                { label: 'Ingresos', value: 'ingreso' },
                { label: 'Egresos', value: 'egreso' }
              ]"
              optionLabel="label"
              optionValue="value"
              class="w-36"
              @change="loadMovimientos()"
            />
          </div>
          <div class="flex items-center gap-2">
            <span class="text-xs font-bold text-slate-400 uppercase">Método:</span>
            <Select
              v-model="filterMetodo"
              :options="[{ id: null, nombre: 'Todos' }, ...metodos]"
              optionLabel="nombre"
              optionValue="id"
              class="w-48"
              @change="loadMovimientos()"
            />
          </div>
          <div class="flex items-center gap-2 px-3 py-1.5 bg-slate-50 border border-slate-200 rounded-lg ml-2">
            <label for="fechaFiltro" class="text-[10px] font-bold text-slate-400 uppercase tracking-widest whitespace-nowrap">Periodo:</label>
            <DatePicker 
              v-model="fechaFiltro" 
              view="month" 
              dateFormat="mm/yy" 
              placeholder="Mes" 
              showIcon 
              class="w-40" 
              @date-select="loadMovimientos()" 
            />
          </div>
        </div>
      </div>

      <DataTable
        :value="movimientos"
        :loading="loading"
        lazy
        paginator
        :rows="rows"
        :totalRecords="totalRecords"
        :first="page * rows"
        :sortField="sortField"
        :sortOrder="sortOrder"
        @page="loadMovimientos($event)"
        @sort="loadMovimientos($event)"
        class="p-datatable-sm"
        stripedRows
      >
        <Column field="fecha" header="Fecha" sortable>
          <template #body="{ data }">
            <span class="text-sm text-slate-600">{{ formatDate(data.fecha) }}</span>
          </template>
        </Column>
        <Column field="tipo" header="Tipo" sortable>
          <template #body="{ data }">
            <span
              :class="data.tipo === 'ingreso' ? 'bg-emerald-100 text-emerald-700' : 'bg-red-100 text-red-700'"
              class="px-2 py-1 rounded text-[10px] font-black uppercase tracking-wider"
            >
              {{ data.tipo }}
            </span>
          </template>
        </Column>
        <Column header="Método / Referencia">
          <template #body="{ data }">
            <div class="text-sm font-bold text-slate-700">{{ data.metodos_pago?.nombre }}</div>
            <div v-if="data.referencia" class="text-[10px] text-amber-600 font-bold uppercase">Ref: {{ data.referencia }}</div>
          </template>
        </Column>
        <Column header="Motivo">
          <template #body="{ data }">
            <span class="text-sm text-slate-600">{{ data.motivo }}</span>
          </template>
        </Column>
        <Column header="Monto" sortable field="monto">
          <template #body="{ data }">
            <div class="text-right">
              <div class="font-black" :class="data.tipo === 'ingreso' ? 'text-emerald-700' : 'text-red-700'">
                {{ data.tipo === 'ingreso' ? '+' : '-' }}{{ Number(data.monto).toLocaleString() }} {{ data.metodos_pago?.moneda }}
              </div>
              <div class="text-[10px] text-slate-400">{{ formatCurrency(data.monto_usd) }}</div>
            </div>
          </template>
        </Column>
        <Column header="Responsable">
          <template #body="{ data }">
            <span class="text-xs text-slate-600 font-bold">{{ data.responsable?.nombre ?? '—' }}</span>
          </template>
        </Column>
        <Column header="Cierre">
          <template #body="{ data }">
            <span v-if="data.cierre_id" class="text-[10px] px-2 py-1 bg-slate-100 text-slate-600 rounded font-bold uppercase">Cerrado</span>
            <span v-else class="text-[10px] px-2 py-1 bg-blue-100 text-blue-700 rounded font-bold uppercase">Abierto</span>
          </template>
        </Column>

        <template #empty>
          <div class="flex flex-col items-center justify-center py-12 text-slate-400">
            <Wallet class="w-12 h-12 mb-3 opacity-20" />
            <p class="font-medium text-sm">No se encontraron movimientos para el periodo seleccionado</p>
          </div>
        </template>
      </DataTable>
    </div>

    <Dialog
      v-model:visible="dialogVisible"
      :header="form.tipo === 'ingreso' ? 'Registrar Ingreso' : 'Registrar Egreso'"
      modal
      :style="{ width: '500px' }"
      class="p-fluid"
    >
      <div class="flex flex-col gap-4 pt-2">
        <div class="flex flex-col gap-2">
          <label class="text-xs font-bold text-slate-500 uppercase">Método / Cuenta</label>
          <Select v-model="form.metodo_pago_id" :options="metodos" optionLabel="nombre" optionValue="id" placeholder="Seleccione..." />
        </div>

        <div v-if="selectedMetodo?.requiere_detalle" class="flex flex-col gap-2">
          <label class="text-xs font-bold text-slate-500 uppercase">Referencia</label>
          <InputText v-model="form.referencia" placeholder="N° de transacción" />
        </div>

        <div class="flex flex-col gap-2">
          <label class="text-xs font-bold text-slate-500 uppercase">Monto {{ selectedMetodo ? `(${selectedMetodo.moneda})` : '' }}</label>
          <InputNumber v-model="form.monto" mode="decimal" :minFractionDigits="2" />
          <div v-if="selectedMetodo && form.monto > 0" class="flex justify-between text-[11px] text-slate-500 px-1">
            <span>Tasa aplicada: <b>{{ tasaAplicada.toLocaleString() }}</b></span>
            <span>Equivale a <b>{{ formatCurrency(montoUsdCalc) }}</b></span>
          </div>
        </div>

        <div class="flex flex-col gap-2">
          <label class="text-xs font-bold text-slate-500 uppercase">Motivo</label>
          <Textarea v-model="form.motivo" rows="3" placeholder="Justificación del movimiento" />
        </div>
      </div>
      <template #footer>
        <Button label="Cancelar" text severity="secondary" @click="dialogVisible = false" :disabled="savingMov" />
        <Button
          :label="form.tipo === 'ingreso' ? 'Registrar Ingreso' : 'Registrar Egreso'"
          :severity="form.tipo === 'ingreso' ? 'success' : 'danger'"
          @click="saveMovimiento"
          :loading="savingMov"
        />
      </template>
    </Dialog>

    <Toast />
  </div>
  <div v-else class="flex items-center justify-center p-20 text-slate-400">
    <Loader2 class="animate-spin" :size="32" />
  </div>
</template>
