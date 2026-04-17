<script setup lang="ts">
import type { Venta } from '~/types/database'

const { fetchVentas } = useVentas()
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
  loading.value = true
  if (event?.page !== undefined) currentPage.value = event.page
  if (event?.sortField) {
    sortField.value = event.sortField
    sortOrder.value = event.sortOrder
  }
  try {
    const result = await fetchVentas({
      desde: desde.value.toISOString(),
      hasta: hasta.value.toISOString(),
      page: currentPage.value,
      rows: 20,
      sortField: sortField.value,
      sortOrder: sortOrder.value
    })
    ventas.value = result.data
    total.value = result.total
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

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
  <div>
    <div class="flex items-center justify-between mb-6">
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
      <Column field="id" header="Ticket" sortable>
        <template #body="{ data }">
          <span class="font-mono text-sm">#{{ data.id.slice(0, 8).toUpperCase() }}</span>
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

    <Toast />
  </div>
</template>
