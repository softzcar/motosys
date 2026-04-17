<script setup lang="ts">
import { BarChart3, Eye, ArrowLeft, Loader2 } from 'lucide-vue-next'
import { useCierresCaja, type CierreCaja } from '~/composables/useCierresCaja'

const toast = useToast()
const { isAdmin, perfil } = usePerfil()

watch(perfil, (p) => {
  if (p && p.rol !== 'admin') navigateTo('/reportes')
}, { immediate: true })

const { fetchCierres } = useCierresCaja()

const cierres = ref<CierreCaja[]>([])
const loading = ref(false)
const totalRecords = ref(0)
const page = ref(0)
const rows = ref(10)
const sortField = ref('fecha')
const sortOrder = ref(-1)

const desde = ref(new Date(new Date().setDate(new Date().getDate() - 30)))
const hasta = ref(new Date())

const detailModal = ref(false)
const selected = ref<CierreCaja | null>(null)

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
    const desdeIso = desde.value.toISOString().slice(0, 10)
    const hastaIso = hasta.value.toISOString().slice(0, 10)
    const { data, total } = await fetchCierres({
      desde: desdeIso,
      hasta: hastaIso,
      page: page.value,
      rows: rows.value,
      sortField: sortField.value,
      sortOrder: sortOrder.value
    })
    cierres.value = data
    totalRecords.value = total
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

const verDetalle = (c: CierreCaja) => {
  selected.value = c
  detailModal.value = true
}

const formatCurrency = (v: number) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(Number(v))
const formatDate = (v: string) => new Date(v).toLocaleDateString('es')
const formatDateTime = (v: string) => new Date(v).toLocaleString('es')

onMounted(load)
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
        <h1 class="text-2xl font-bold text-slate-800">Reporte de Cierres de Caja</h1>
        <p class="text-slate-500">Histórico de cierres diarios con diferencias y responsables.</p>
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
      </div>

      <DataTable
        :value="cierres"
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
            <span class="font-bold text-slate-700">{{ formatDate(data.fecha) }}</span>
          </template>
        </Column>
        <Column header="Cerrado el">
          <template #body="{ data }">
            <span class="text-xs text-slate-500">{{ formatDateTime(data.fecha_hora_cierre) }}</span>
          </template>
        </Column>
        <Column header="Responsable">
          <template #body="{ data }">
            <span class="text-sm font-bold text-slate-600">{{ data.responsable?.nombre ?? '—' }}</span>
          </template>
        </Column>
        <Column header="Sistema" sortable field="total_sistema_usd">
          <template #body="{ data }">
            <span class="text-sm font-bold text-slate-700">{{ formatCurrency(data.total_sistema_usd) }}</span>
          </template>
        </Column>
        <Column header="Contado" sortable field="total_contado_usd">
          <template #body="{ data }">
            <span class="text-sm font-bold text-slate-700">{{ formatCurrency(data.total_contado_usd) }}</span>
          </template>
        </Column>
        <Column header="Diferencia" sortable field="diferencia_usd">
          <template #body="{ data }">
            <span
              class="text-sm font-black"
              :class="Number(data.diferencia_usd) === 0 ? 'text-slate-500' : Number(data.diferencia_usd) > 0 ? 'text-emerald-700' : 'text-red-700'"
            >
              {{ formatCurrency(data.diferencia_usd) }}
            </span>
          </template>
        </Column>
        <Column header="" :exportable="false">
          <template #body="{ data }">
            <Button text rounded severity="secondary" @click="verDetalle(data)" class="text-blue-500 hover:bg-blue-50">
              <Eye class="w-4 h-4" />
            </Button>
          </template>
        </Column>
      </DataTable>
    </div>

    <Dialog v-model:visible="detailModal" header="Detalle del Cierre" modal :style="{ width: '720px' }">
      <div v-if="selected" class="space-y-4 pt-2">
        <div class="grid grid-cols-2 gap-3 p-4 bg-slate-50 rounded-xl border border-slate-200">
          <div>
            <p class="text-[10px] text-slate-400 font-bold uppercase">Fecha</p>
            <p class="font-black text-slate-800">{{ formatDate(selected.fecha) }}</p>
          </div>
          <div>
            <p class="text-[10px] text-slate-400 font-bold uppercase">Cerrado</p>
            <p class="text-sm font-bold text-slate-700">{{ formatDateTime(selected.fecha_hora_cierre) }}</p>
          </div>
          <div>
            <p class="text-[10px] text-slate-400 font-bold uppercase">Responsable</p>
            <p class="text-sm font-bold text-slate-700">{{ selected.responsable?.nombre ?? '—' }}</p>
          </div>
          <div>
            <p class="text-[10px] text-slate-400 font-bold uppercase">Diferencia</p>
            <p class="font-black" :class="Number(selected.diferencia_usd) === 0 ? 'text-slate-700' : Number(selected.diferencia_usd) > 0 ? 'text-emerald-700' : 'text-red-700'">
              {{ formatCurrency(selected.diferencia_usd) }}
            </p>
          </div>
        </div>

        <div class="overflow-x-auto rounded-xl border border-slate-200">
          <table class="w-full text-sm">
            <thead class="bg-slate-50 text-[10px] font-bold text-slate-400 uppercase tracking-wider">
              <tr>
                <th class="p-3 text-left">Método</th>
                <th class="p-3 text-right">Sistema</th>
                <th class="p-3 text-right">Contado</th>
                <th class="p-3 text-right">Diferencia</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="d in selected.cierres_caja_detalle" :key="d.id" class="border-t border-slate-100">
                <td class="p-3">
                  <div class="font-bold text-slate-700">{{ d.metodos_pago?.nombre }}</div>
                  <div class="text-[10px] text-slate-400 uppercase">{{ d.metodos_pago?.moneda }}</div>
                </td>
                <td class="p-3 text-right">
                  <div class="font-bold">{{ Number(d.monto_sistema).toLocaleString() }}</div>
                  <div class="text-[10px] text-slate-400">{{ formatCurrency(d.monto_sistema_usd) }}</div>
                </td>
                <td class="p-3 text-right">
                  <div class="font-bold">{{ Number(d.monto_contado).toLocaleString() }}</div>
                  <div class="text-[10px] text-slate-400">{{ formatCurrency(d.monto_contado_usd) }}</div>
                </td>
                <td class="p-3 text-right">
                  <span class="font-black" :class="Number(d.diferencia) === 0 ? 'text-slate-500' : Number(d.diferencia) > 0 ? 'text-emerald-700' : 'text-red-700'">
                    {{ Number(d.diferencia).toLocaleString() }}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div v-if="selected.observaciones" class="p-4 bg-amber-50 border border-amber-200 rounded-xl">
          <p class="text-[10px] text-amber-700 font-bold uppercase mb-1">Observaciones</p>
          <p class="text-sm text-amber-900 whitespace-pre-wrap">{{ selected.observaciones }}</p>
        </div>
      </div>

      <template #footer>
        <Button label="Cerrar" text severity="secondary" @click="detailModal = false" />
      </template>
    </Dialog>

    <Toast />
  </div>
  <div v-else class="flex items-center justify-center p-20 text-slate-400">
    <Loader2 class="animate-spin" :size="32" />
  </div>
</template>
