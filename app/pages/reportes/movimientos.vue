<script setup lang="ts">
import { BarChart3, ArrowLeft, Loader2, ArrowDownCircle, ArrowUpCircle } from 'lucide-vue-next'
import { useMovimientosCaja, type TipoMovimiento, type MovimientoCaja } from '~/composables/useMovimientosCaja'
import { useMetodosPago, type MetodoPago } from '~/composables/useMetodosPago'

const toast = useToast()
const { isAdmin, perfil } = usePerfil()

watch(perfil, (p) => {
  if (p && p.rol !== 'admin') navigateTo('/reportes')
}, { immediate: true })

const { fetchMovimientos } = useMovimientosCaja()
const { fetchMetodosPago } = useMetodosPago()

const movimientos = ref<MovimientoCaja[]>([])
const metodos = ref<MetodoPago[]>([])
const loading = ref(false)
const totalRecords = ref(0)
const page = ref(0)
const rows = ref(15)
const sortField = ref('fecha')
const sortOrder = ref(-1)

const desde = ref(new Date(new Date().setDate(new Date().getDate() - 30)))
const hasta = ref(new Date())
const filterTipo = ref<TipoMovimiento | null>(null)
const filterMetodo = ref<string | null>(null)

const load = async (event?: any) => {
  loading.value = true
  try {
    const p = event?.first !== undefined ? event.first / event.rows : page.value
    if (event?.rows) rows.value = event.rows
    page.value = p
    if (event?.sortField) {
      sortField.value = event.sortField
      sortOrder.value = event.sortOrder
    }
    const { data, total } = await fetchMovimientos({
      desde: desde.value.toISOString(),
      hasta: hasta.value.toISOString(),
      page: page.value,
      rows: rows.value,
      sortField: sortField.value,
      sortOrder: sortOrder.value,
      tipo: filterTipo.value || undefined,
      metodoPagoId: filterMetodo.value || undefined
    })
    movimientos.value = data
    totalRecords.value = total
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

const totalIngresos = computed(() => movimientos.value.filter(m => m.tipo === 'ingreso').reduce((acc, m) => acc + Number(m.monto_usd), 0))
const totalEgresos = computed(() => movimientos.value.filter(m => m.tipo === 'egreso').reduce((acc, m) => acc + Number(m.monto_usd), 0))

const loadMetodos = async () => {
  try {
    metodos.value = await fetchMetodosPago()
  } catch (e) {
    console.error(e)
  }
}

const formatCurrency = (v: number) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(Number(v))
const formatDate = (v: string) => new Date(v).toLocaleString('es')

onMounted(async () => {
  await loadMetodos()
  await load()
})
</script>

<template>
  <div v-if="isAdmin">
    <div class="flex items-center gap-3 mb-6">
      <NuxtLink to="/reportes" class="p-2 rounded-lg hover:bg-slate-100 text-slate-500">
        <ArrowLeft :size="20" />
      </NuxtLink>
      <div class="p-2 bg-indigo-100 text-indigo-600 rounded-lg">
        <BarChart3 :size="24" />
      </div>
      <div>
        <h1 class="text-2xl font-bold text-slate-800">Reporte de Movimientos</h1>
        <p class="text-slate-500">Notas de crédito y débito (ingresos y egresos manuales de caja).</p>
      </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
      <div class="bg-white border border-slate-200 rounded-xl p-5 flex items-center gap-4">
        <div class="p-3 bg-emerald-100 text-emerald-600 rounded-lg">
          <ArrowDownCircle :size="24" />
        </div>
        <div>
          <p class="text-[10px] font-bold text-slate-400 uppercase">Total Ingresos (pág. actual)</p>
          <p class="text-2xl font-black text-emerald-700">{{ formatCurrency(totalIngresos) }}</p>
        </div>
      </div>
      <div class="bg-white border border-slate-200 rounded-xl p-5 flex items-center gap-4">
        <div class="p-3 bg-red-100 text-red-600 rounded-lg">
          <ArrowUpCircle :size="24" />
        </div>
        <div>
          <p class="text-[10px] font-bold text-slate-400 uppercase">Total Egresos (pág. actual)</p>
          <p class="text-2xl font-black text-red-700">{{ formatCurrency(totalEgresos) }}</p>
        </div>
      </div>
    </div>

    <div class="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
      <div class="p-4 border-b border-slate-100 flex flex-wrap items-end gap-4">
        <div class="flex flex-col gap-1">
          <label class="text-[10px] font-bold text-slate-400 uppercase">Desde</label>
          <DatePicker v-model="desde" dateFormat="dd/mm/yy" showIcon @update:modelValue="load()" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-[10px] font-bold text-slate-400 uppercase">Hasta</label>
          <DatePicker v-model="hasta" dateFormat="dd/mm/yy" showIcon @update:modelValue="load()" />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-[10px] font-bold text-slate-400 uppercase">Tipo</label>
          <Select
            v-model="filterTipo"
            :options="[
              { label: 'Todos', value: null },
              { label: 'Ingresos', value: 'ingreso' },
              { label: 'Egresos', value: 'egreso' }
            ]"
            optionLabel="label"
            optionValue="value"
            class="w-40"
            @change="load()"
          />
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-[10px] font-bold text-slate-400 uppercase">Método</label>
          <Select
            v-model="filterMetodo"
            :options="[{ id: null, nombre: 'Todos' }, ...metodos]"
            optionLabel="nombre"
            optionValue="id"
            class="w-52"
            @change="load()"
          />
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
        @page="load($event)"
        @sort="load($event)"
        stripedRows
        class="p-datatable-sm"
      >
        <Column field="fecha" header="Fecha" sortable>
          <template #body="{ data }">
            <span class="text-xs text-slate-600">{{ formatDate(data.fecha) }}</span>
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
        <Column header="Método">
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
        <Column header="Monto" field="monto_usd" sortable>
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
      </DataTable>
    </div>
  </div>
  <div v-else class="flex items-center justify-center p-20 text-slate-400">
    <Loader2 class="animate-spin" :size="32" />
  </div>
</template>
