<script setup lang="ts">
import { Pencil, Trash2, UserMinus, UserCheck, Plus } from 'lucide-vue-next'
import { useDebounceFn } from '@vueuse/core'
import type { Perfil } from '~/types/database'

defineProps<{
  empleados: Perfil[]
  total: number
  loading: boolean
  currentUserId?: string
  sortField?: string
  sortOrder?: number
  mostrarInactivos: boolean
}>()

const emit = defineEmits<{
  page: [event: { page: number; rows: number }]
  edit: [empleado: Perfil]
  delete: [empleado: Perfil]
  search: [term: string]
  sort: [event: { sortField: string; sortOrder: number }]
  'toggle-inactivos': [val: boolean]
  'toggle-estado': [empleado: Perfil]
}>()

const search = ref('')
const onSearch = useDebounceFn(() => emit('search', search.value), 400)
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="flex flex-wrap items-center gap-4">
      <IconField class="flex-1">
        <InputIcon class="pi pi-search" />
        <InputText v-model="search" placeholder="Buscar por nombre..." class="w-full" @input="onSearch" />
      </IconField>
      
      <div class="flex items-center gap-2 bg-slate-50 px-3 py-2 rounded-lg border border-slate-200">
        <label for="sw-inactivos" class="text-sm font-medium text-slate-600">Ver Inactivos</label>
        <ToggleSwitch 
          id="sw-inactivos" 
          :model-value="mostrarInactivos" 
          @update:model-value="emit('toggle-inactivos', $event)" 
        />
      </div>

      <NuxtLink to="/empleados/nuevo">
        <Button severity="success" class="aspect-square">
          <Plus class="w-5 h-5" />
        </Button>
      </NuxtLink>
    </div>

    <DataTable
      :value="empleados"
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
      class="p-datatable-sm"
    >
      <Column field="nombre" header="Nombre" sortable />
      <Column field="rol" header="Rol" sortable>
        <template #body="{ data }">
          <Tag
            :value="data.rol === 'admin' ? 'Administrador' : 'Vendedor'"
            :severity="data.rol === 'admin' ? 'info' : 'secondary'"
          />
        </template>
      </Column>
      <Column field="activo" header="Estado">
        <template #body="{ data }">
          <Tag
            :value="data.activo ? 'Activo' : 'Inactivo'"
            :severity="data.activo ? 'success' : 'danger'"
            size="small"
          />
        </template>
      </Column>
      <Column header="Acciones" :exportable="false" style="width: 140px">
        <template #body="{ data }">
          <div class="flex gap-2">
            <Button text rounded severity="info" @click="emit('edit', data)" v-tooltip.top="'Editar'">
              <Pencil :size="16" />
            </Button>
            
            <Button
              v-if="data.activo"
              text
              rounded
              severity="danger"
              :disabled="data.id === currentUserId"
              @click="emit('delete', data)"
              v-tooltip.top="'Desactivar / Eliminar'"
            >
              <UserMinus :size="16" />
            </Button>

            <Button
              v-else
              text
              rounded
              severity="success"
              @click="emit('toggle-estado', data)"
              v-tooltip.top="'Reactivar Empleado'"
            >
              <UserCheck :size="16" />
            </Button>
          </div>
        </template>
      </Column>

      <template #empty>
        <div class="text-center py-8 text-slate-500">No se encontraron empleados</div>
      </template>
    </DataTable>
  </div>
</template>
