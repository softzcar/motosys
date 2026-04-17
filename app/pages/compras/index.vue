<script setup lang="ts">
import { useCompras, type Compra } from '~/composables/useCompras'
import { useToast } from 'primevue/usetoast'
import { FilterMatchMode } from '@primevue/core/api'
import { Eye, ReceiptText, Ban, AlertTriangle, FilePlus, RotateCcw, Plus } from 'lucide-vue-next'

const { fetchCompras, getCompraById, anularCompra } = useCompras()
const toast = useToast()
const router = useRouter()
const { isAdmin } = usePerfil()

const compras = ref<Compra[]>([])
const loading = ref(true)
const totalRecords = ref(0)
const filters = ref({
  global: { value: null, matchMode: FilterMatchMode.CONTAINS }
})
const sortField = ref('fecha')
const sortOrder = ref(-1)
const incluirAnuladas = ref(false)

const detailsModal = ref(false)
const loadingDetails = ref(false)
const selectedCompra = ref<any>(null)

const anularModal = ref(false)
const anularLoading = ref(false)
const compraToAnular = ref<any>(null)
const motivoAnulacion = ref('')
const motivoSubmitted = ref(false)

const loadCompras = async (event?: any) => {
  loading.value = true
  try {
    const page = event?.first !== undefined ? event.first / event.rows : 0
    if (event?.sortField) {
      sortField.value = event.sortField
      sortOrder.value = event.sortOrder
    }
    const { data, total } = await fetchCompras({
      search: filters.value.global.value ?? undefined,
      page,
      rows: event?.rows ?? 10,
      sortField: sortField.value,
      sortOrder: sortOrder.value,
      incluirAnuladas: incluirAnuladas.value
    })
    compras.value = data
    totalRecords.value = total
  } catch (error: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: error.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

const openDetails = async (compra: Compra) => {
  detailsModal.value = true
  loadingDetails.value = true
  try {
    const fullCompra = await getCompraById(compra.id!)
    selectedCompra.value = fullCompra
  } catch (error: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: error.message, life: 3000 })
    detailsModal.value = false
  } finally {
    loadingDetails.value = false
  }
}

const openAnular = async (compra: Compra) => {
  anularLoading.value = false
  motivoAnulacion.value = ''
  motivoSubmitted.value = false
  // Carga el detalle para poder mostrar advertencia de stock
  try {
    compraToAnular.value = await getCompraById(compra.id!)
    anularModal.value = true
  } catch (error: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: error.message, life: 3000 })
  }
}

const stockInsuficienteItems = computed(() => {
  if (!compraToAnular.value?.detalle_compras) return []
  return compraToAnular.value.detalle_compras.filter(
    (d: any) => Number(d.productos?.stock ?? 0) < Number(d.cantidad)
  )
})

const motivoTrim = computed(() => motivoAnulacion.value.trim())
const motivoValido = computed(() => motivoTrim.value.length >= 10)

const confirmarAnulacion = async () => {
  motivoSubmitted.value = true
  if (!motivoValido.value || !compraToAnular.value?.id) return
  anularLoading.value = true
  try {
    await anularCompra(compraToAnular.value.id, motivoTrim.value)
    toast.add({
      severity: 'success',
      summary: 'Compra anulada',
      detail: 'El stock fue revertido correctamente.',
      life: 4000
    })
    const idAnulada = compraToAnular.value.id
    anularModal.value = false
    compraToAnular.value = null
    await loadCompras()
    // Sugerir crear corrección
    setTimeout(() => {
      toast.add({
        severity: 'info',
        summary: '¿Crear corrección?',
        detail: 'Puedes registrar una nueva compra prellenada con los datos de la anulada.',
        life: 8000,
        group: 'crear-correccion',
        // @ts-ignore - propiedad usada por nuestro template
        compraId: idAnulada
      } as any)
    }, 200)
  } catch (error: any) {
    toast.add({ severity: 'error', summary: 'No se pudo anular', detail: error.message, life: 5000 })
  } finally {
    anularLoading.value = false
  }
}

const irACorreccion = (compraId: string) => {
  router.push(`/compras/nueva?from=${compraId}`)
}

const onFilter = () => {
  loadCompras()
}

watch(incluirAnuladas, () => loadCompras())

onMounted(() => {
  loadCompras()
})

const formatCurrency = (value: number) => {
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
  <div class="card p-4">
    <div class="flex flex-wrap items-center justify-between gap-4 mb-6">
      <h1 class="m-0 text-2xl font-bold text-slate-800">Registro de Compras</h1>
      <div class="flex items-center gap-3">
        <div class="flex items-center gap-2 px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg">
          <ToggleSwitch v-model="incluirAnuladas" inputId="toggleAnuladas" />
          <label for="toggleAnuladas" class="text-xs font-bold text-slate-600 uppercase tracking-wide cursor-pointer select-none">
            Mostrar anuladas
          </label>
        </div>
        <NuxtLink to="/compras/nueva">
          <Button severity="success" class="shadow-sm flex items-center gap-2">
            <Plus :size="16" />
            Registrar Compra
          </Button>
        </NuxtLink>
      </div>
    </div>

    <DataTable
      v-model:filters="filters"
      :value="compras"
      dataKey="id"
      :paginator="true"
      :rows="10"
      :totalRecords="totalRecords"
      :loading="loading"
      @page="loadCompras"
      @sort="loadCompras"
      :sortField="sortField"
      :sortOrder="sortOrder"
      lazy
      stripedRows
      class="p-datatable-sm"
      :rowClass="(data: any) => data.anulada ? 'opacity-60' : ''"
    >
      <Column field="numero" header="N° Registro" sortable>
        <template #body="slotProps">
          <span class="font-bold text-primary">#{{ slotProps.data.numero }}</span>
        </template>
      </Column>
      <Column field="numero_factura" header="Factura Prov." sortable>
        <template #body="slotProps">
          <span :class="{ 'line-through': slotProps.data.anulada }">{{ slotProps.data.numero_factura }}</span>
        </template>
      </Column>
      <Column field="fecha" header="Fecha" sortable>
        <template #body="slotProps">
          {{ formatDate(slotProps.data.fecha) }}
        </template>
      </Column>
      <Column field="proveedores.nombre" sortField="proveedores(nombre)" header="Proveedor" sortable></Column>
      <Column field="total" header="Total" sortable>
        <template #body="slotProps">
          <span class="font-bold text-slate-800" :class="{ 'line-through': slotProps.data.anulada }">{{ formatCurrency(slotProps.data.total) }}</span>
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
          <div class="flex items-center gap-1">
            <button
              @click="openDetails(slotProps.data)"
              class="p-2 text-slate-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition"
              title="Ver detalle"
            >
              <Eye :size="18" />
            </button>
            <button
              v-if="isAdmin && !slotProps.data.anulada"
              @click="openAnular(slotProps.data)"
              class="p-2 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition"
              title="Anular compra"
            >
              <Ban :size="18" />
            </button>
          </div>
        </template>
      </Column>
    </DataTable>

    <!-- Modal Detalle Compra (UNIFICADO) -->
    <Dialog 
      v-model:visible="detailsModal" 
      modal 
      header="Detalle de Compra" 
      :style="{ width: '700px' }"
      :breakpoints="{ '1199px': '75vw', '575px': '90vw' }"
    >
      <div v-if="loadingDetails" class="flex flex-col items-center justify-center p-12">
        <span class="w-10 h-10 border-4 border-slate-200 border-t-blue-500 rounded-full animate-spin mb-4"></span>
        <span class="text-slate-500 font-medium">Cargando factura...</span>
      </div>

      <ReportesCompraDetalleRecibo v-else-if="selectedCompra" :compra="selectedCompra" />

      <template #footer>
        <Button label="Cerrar" text severity="secondary" @click="detailsModal = false" class="mt-2" />
      </template>
    </Dialog>

    <!-- Modal Anular Compra -->
    <Dialog v-model:visible="anularModal" :style="{ width: '560px' }" modal :closable="!anularLoading" class="p-fluid">
      <template #header>
        <div class="flex items-center gap-2">
          <Ban class="w-6 h-6 text-rose-600" />
          <h2 class="font-bold text-xl text-slate-800 m-0">Anular compra</h2>
        </div>
      </template>

      <div v-if="compraToAnular" class="space-y-4 pt-2">
        <div class="bg-slate-50 border border-slate-200 rounded-lg p-3 text-sm">
          <p class="text-slate-700">
            Compra <b>#{{ compraToAnular.numero }}</b> — Factura <b>{{ compraToAnular.numero_factura }}</b>
          </p>
          <p class="text-slate-500 text-xs mt-1">
            {{ compraToAnular.proveedores?.nombre }} · {{ formatDate(compraToAnular.fecha) }} · {{ formatCurrency(compraToAnular.total) }}
          </p>
        </div>

        <div v-if="stockInsuficienteItems.length > 0" class="bg-amber-50 border border-amber-300 rounded-lg p-3">
          <div class="flex items-start gap-2">
            <AlertTriangle class="w-5 h-5 text-amber-600 flex-shrink-0 mt-0.5" />
            <div class="text-sm flex-1">
              <p class="font-black text-amber-800 uppercase tracking-wide text-xs mb-1">Atención: stock ya movido</p>
              <p class="text-amber-900 mb-2">
                Algunos productos de esta compra ya se vendieron. Al anular, su stock quedará en negativo y deberás registrar el ajuste correspondiente.
              </p>
              <ul class="text-xs text-amber-900 list-disc pl-4 space-y-0.5">
                <li v-for="item in stockInsuficienteItems" :key="item.id">
                  <b>{{ item.productos?.nombre }}</b>: stock actual {{ item.productos?.stock }}, esta compra agregó {{ item.cantidad }}
                </li>
              </ul>
            </div>
          </div>
        </div>

        <div>
          <label class="block text-xs font-bold text-slate-600 uppercase tracking-wide mb-1.5">
            Motivo de la anulación <span class="text-rose-600">*</span>
          </label>
          <Textarea
            v-model="motivoAnulacion"
            rows="3"
            class="w-full"
            placeholder="Describe el motivo (mínimo 10 caracteres). Ej: Error en el monto del IVA, se duplicó el ingreso, etc."
            :class="{ 'p-invalid': motivoSubmitted && !motivoValido }"
          />
          <p v-if="motivoSubmitted && !motivoValido" class="text-xs text-rose-600 mt-1">
            El motivo es obligatorio y debe tener al menos 10 caracteres.
          </p>
          <p v-else class="text-[11px] text-slate-400 mt-1">
            {{ motivoTrim.length }} / 10 caracteres mínimo. Esta acción queda registrada con tu usuario y la fecha.
          </p>
        </div>
      </div>

      <template #footer>
        <Button label="Cancelar" text severity="secondary" @click="anularModal = false" :disabled="anularLoading" />
        <Button
          severity="danger"
          @click="confirmarAnulacion"
          :loading="anularLoading"
          class="flex items-center gap-2"
        >
          <Ban :size="16" />
          Confirmar anulación
        </Button>
      </template>
    </Dialog>

    <!-- Toast con CTA "Crear corrección" -->
    <Toast position="bottom-right" group="crear-correccion">
      <template #message="{ message }">
        <div class="flex flex-col gap-2 w-full">
          <div class="flex items-center gap-2">
            <FilePlus :size="18" class="text-blue-600" />
            <span class="font-bold text-slate-800">{{ message.summary }}</span>
          </div>
          <p class="text-xs text-slate-600">{{ message.detail }}</p>
          <Button
            size="small"
            severity="primary"
            class="mt-1 w-full flex items-center justify-center gap-2"
            @click="irACorreccion((message as any).compraId)"
          >
            <FilePlus :size="14" />
            Crear corrección ahora
          </Button>
        </div>
      </template>
    </Toast>
  </div>
</template>
