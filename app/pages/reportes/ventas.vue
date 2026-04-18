<script setup lang="ts">
import type { Venta } from '~/types/database'
import { useNetworkStore } from '~/stores/network'

const { fetchVentas } = useVentas()
const networkStore = useNetworkStore()
const toast = useToast()

const ventas = ref<Venta[]>([])
const total = ref(0)
const loading = ref(false)
const expandedRows = ref<Record<string, boolean>>({})

const desde = ref(new Date(new Date().setDate(new Date().getDate() - 30)))
const hasta = ref(new Date())
const currentPage = ref(0)
const sortField = ref('fecha')
const sortOrder = ref(-1)

const loadVentas = async (event?: any) => {
  // Solo cargar si hay internet
  if (!networkStore.isOnline) return
  
  loading.value = true
  if (event?.page !== undefined) currentPage.value = event.page
  if (event?.sortField) {
    sortField.value = event.sortField
    sortOrder.value = event.sortOrder
  }
  try {
    // Normalizar fechas a ISO
    const start = new Date(desde.value)
    start.setHours(0, 0, 0, 0)
    const end = new Date(hasta.value)
    end.setHours(23, 59, 59, 999)

    const result = await fetchVentas({
      desde: start.toISOString(),
      hasta: end.toISOString(),
      page: currentPage.value,
      rows: 20,
      sortField: sortField.value,
      sortOrder: sortOrder.value
    })
    ventas.value = result.data
    total.value = result.total
  } catch (e: any) {
    console.error('Error cargando historial:', e)
    toast.add({ severity: 'error', summary: 'Error de carga', detail: e.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

// AUTO-REFRESCO AL RECONECTAR
watch(() => networkStore.isOnline, (online) => {
  if (online) {
    console.log('🔄 Reconexión detectada en Historial. Refrescando datos...')
    setTimeout(loadVentas, 2000)
  }
})

const handlePage = (event: { page: number }) => {
  loadVentas(event)
}

const handleSort = (event: { sortField: string; sortOrder: number }) => {
  loadVentas(event)
}

watch([desde, hasta], () => {
  currentPage.value = 0
  loadVentas()
})

onMounted(loadVentas)
</script>

<template>
  <div class="flex flex-col gap-4">
    <!-- Header de Acciones Rápidas -->
    <div class="flex items-center justify-end">
        <NuxtLink to="/pos">
           <Button 
             label="Volver al Punto de Venta" 
             icon="pi pi-shopping-cart" 
             severity="primary" 
             variant="text"
             size="small" 
             class="font-bold text-xs uppercase tracking-wider" 
           />
        </NuxtLink>
    </div>

    <div class="flex items-center justify-between mb-2">
      <h1 class="text-2xl font-bold text-slate-800">Historial de Ventas</h1>
      <div class="flex items-center gap-3">
        <DatePicker v-model="desde" date-format="dd/mm/yy" placeholder="Desde" show-icon />
        <DatePicker v-model="hasta" date-format="dd/mm/yy" placeholder="Hasta" show-icon />
      </div>
    </div>

    <DataTable
      v-model:expanded-rows="expandedRows"
      :value="ventas"
      :loading="loading"
      :total-records="total"
      :rows="20"
      lazy
      paginator
      striped-rows
      data-key="id"
      :sort-field="sortField"
      :sort-order="sortOrder"
      @page="handlePage"
      @sort="handleSort"
    >
      <Column expander style="width: 3rem" />
      <Column field="numero" header="Ticket" sortable>
        <template #body="{ data }">
          <span class="font-bold text-primary">#{{ data.numero }}</span>
        </template>
      </Column>
      <Column header="Fecha" sortable>
        <template #body="{ data }">
          {{ new Date(data.fecha).toLocaleString('es') }}
        </template>
      </Column>
      <Column field="clientes(nombre)" header="Cliente" sortable>
        <template #body="{ data }">
          {{ data.clientes?.nombre ?? 'Cliente General' }}
        </template>
      </Column>
      <Column field="vendedor(nombre)" header="Vendedor" sortable>
        <template #body="{ data }">
          {{ data.perfiles?.nombre ?? 'N/A' }}
        </template>
      </Column>
      <Column field="total" header="Total" sortable>
        <template #body="{ data }">
          <span class="font-semibold">${{ Number(data.total).toFixed(2) }}</span>
        </template>
      </Column>

      <template #expansion="{ data }">
        <div class="p-4 bg-white rounded-lg shadow-inner">
          <ReportesVentaReciboDetalle :venta="data" />
        </div>
      </template>

      <template #empty>
        <div class="text-center py-8 text-slate-500">
          No se encontraron ventas en el rango seleccionado
        </div>
      </template>
    </DataTable>
  </div>
</template>
