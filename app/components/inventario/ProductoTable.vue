<script setup lang="ts">
import { Pencil, Trash2 } from 'lucide-vue-next'
import { useDebounceFn } from '@vueuse/core'
import type { Producto, CategoriaProducto } from '~/types/database'

defineProps<{
  productos: Producto[]
  total: number
  loading: boolean
  sortField?: string
  sortOrder?: number
  categorias: CategoriaProducto[]
  selectedCategoriaId?: string | null
  soloActivos?: boolean
}>()

const emit = defineEmits<{
  page: [event: { page: number; rows: number }]
  edit: [producto: Producto]
  delete: [producto: Producto]
  search: [term: string]
  sort: [event: { sortField: string; sortOrder: number }]
  'filter-categoria': [id: string | null]
  'filter-activos': [value: boolean]
}>()

const { isAdmin } = usePerfil()

const search = ref('')

const onSearch = useDebounceFn(() => {
  emit('search', search.value)
}, 400)

const onCategoriaChange = (value: string | null) => {
  emit('filter-categoria', value)
}

const onActivosChange = (event: any) => {
  emit('filter-activos', event)
}
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex flex-wrap items-center gap-3 mb-4">
      <IconField class="flex-1 min-w-[200px] md:max-w-md">
        <InputIcon class="pi pi-search" />
        <InputText
          v-model="search"
          placeholder="Buscar por nombre o código..."
          class="w-full"
          @input="onSearch"
        />
      </IconField>
      <Select
        :model-value="selectedCategoriaId"
        :options="categorias"
        option-label="nombre"
        option-value="id"
        placeholder="Todas las categorías"
        show-clear
        class="w-full md:w-56"
        @update:model-value="onCategoriaChange"
      />
      <div class="flex items-center gap-2 px-3 py-2 bg-slate-50 border border-slate-200 rounded-lg">
        <ToggleSwitch :model-value="soloActivos" input-id="toggleActivos" @update:model-value="onActivosChange" />
        <label for="toggleActivos" class="text-xs font-bold text-slate-600 uppercase tracking-wide cursor-pointer select-none w-24">
          {{ soloActivos ? 'Solo activos' : 'Solo inactivos' }}
        </label>
      </div>
    </div>

    <DataTable
      :value="productos"
      :loading="loading"
      :total-records="total"
      :rows="20"
      lazy
      paginator
      :rows-per-page-options="[10, 20, 50]"
      striped-rows
      :sort-field="sortField"
      :sort-order="sortOrder"
      @page="emit('page', $event)"
      @sort="emit('sort', $event)"
    >
      <Column field="codigo_parte" header="Código" sortable />
      <Column field="nombre" header="Nombre" sortable />
      <Column header="Categoría" sortable field="categoria_id">
        <template #body="{ data }">
          <Tag
            v-if="data.categorias_productos?.nombre"
            :value="data.categorias_productos.nombre"
            severity="info"
          />
          <span v-else class="text-slate-400 text-sm">Sin categoría</span>
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
      <Column field="precio_venta" header="Precio" sortable>
        <template #body="{ data }">
          ${{ Number(data.precio_venta).toFixed(2) }}
        </template>
      </Column>
      <Column field="activo" header="Estado" sortable>
        <template #body="{ data }">
          <Tag
            :value="data.activo ? 'ACTIVO' : 'INACTIVO'"
            :severity="data.activo ? 'success' : 'secondary'"
          />
        </template>
      </Column>
      <Column v-if="isAdmin" header="Acciones" :exportable="false" style="width: 120px">
        <template #body="{ data }">
          <div class="flex gap-2">
            <Button
              text
              rounded
              severity="info"
              @click="emit('edit', data)"
              aria-label="Editar"
            >
              <Pencil :size="16" />
            </Button>
            <Button
              text
              rounded
              severity="danger"
              @click="emit('delete', data)"
              aria-label="Eliminar"
            >
              <Trash2 :size="16" />
            </Button>
          </div>
        </template>
      </Column>

      <template #empty>
        <div class="text-center py-8 text-slate-500">
          No se encontraron productos
        </div>
      </template>
    </DataTable>
  </div>
</template>
