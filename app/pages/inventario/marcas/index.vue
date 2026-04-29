<script setup lang="ts">
import { Pencil, Trash2 } from 'lucide-vue-next'
import { useDebounceFn } from '@vueuse/core'
import type { Marca } from '~/types/database'

const { fetchMarcas, createMarca, updateMarca, deleteMarca, friendlyError } = useMarcas()
const toast = useToast()
const confirm = useConfirm()

const marcas = ref<Marca[]>([])
const total = ref(0)
const loading = ref(false)
const currentPage = ref(0)
const currentSearch = ref('')
const sortField = ref('nombre')
const sortOrder = ref(1)

// Modal state
const showModal = ref(false)
const editingMarca = ref<Marca | null>(null)
const formNombre = ref('')
const saving = ref(false)
const formError = ref('')

const loadMarcas = async () => {
  loading.value = true
  try {
    const result = await fetchMarcas({
      search: currentSearch.value,
      page: currentPage.value,
      rows: 20,
      sortField: sortField.value,
      sortOrder: sortOrder.value
    })
    marcas.value = result.data
    total.value = result.total
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

const handlePage = (event: { page: number; rows: number }) => {
  currentPage.value = event.page
  loadMarcas()
}

const handleSort = (event: { sortField: string; sortOrder: number }) => {
  sortField.value = event.sortField
  sortOrder.value = event.sortOrder
  loadMarcas()
}

const search = ref('')
const onSearch = useDebounceFn(() => {
  currentSearch.value = search.value
  currentPage.value = 0
  loadMarcas()
}, 400)

// Modal actions
const openCreate = () => {
  editingMarca.value = null
  formNombre.value = ''
  formError.value = ''
  showModal.value = true
}

const openEdit = (marca: Marca) => {
  editingMarca.value = marca
  formNombre.value = marca.nombre
  formError.value = ''
  showModal.value = true
}

const handleSave = async () => {
  const nombre = formNombre.value.trim()
  if (!nombre) {
    formError.value = 'El nombre es obligatorio'
    return
  }
  if (nombre.length < 2) {
    formError.value = 'Debe tener al menos 2 caracteres'
    return
  }

  saving.value = true
  formError.value = ''
  try {
    if (editingMarca.value) {
      await updateMarca(editingMarca.value.id, nombre)
      toast.add({ severity: 'success', summary: 'Marca actualizada', life: 2000 })
    } else {
      await createMarca(nombre)
      toast.add({ severity: 'success', summary: 'Marca creada', life: 2000 })
    }
    showModal.value = false
    await loadMarcas()
  } catch (e: any) {
    formError.value = friendlyError(e)
  } finally {
    saving.value = false
  }
}

const handleDelete = (marca: Marca) => {
  confirm.require({
    message: `¿Eliminar la marca "${marca.nombre}"?`,
    header: 'Confirmar eliminación',
    acceptLabel: 'Eliminar',
    rejectLabel: 'Cancelar',
    accept: async () => {
      try {
        await deleteMarca(marca.id)
        toast.add({ severity: 'success', summary: 'Marca eliminada', life: 2000 })
        await loadMarcas()
      } catch (e: any) {
        toast.add({ severity: 'error', summary: 'No se pudo eliminar', detail: friendlyError(e), life: 4000 })
      }
    }
  })
}

onMounted(loadMarcas)
</script>

<template>
  <div>
    <div class="flex flex-wrap items-center justify-between gap-4 mb-6">
      <div class="flex items-center gap-3">
        <NuxtLink to="/inventario">
          <Button icon="pi pi-arrow-left" text rounded severity="secondary" aria-label="Volver" />
        </NuxtLink>
        <h1 class="m-0 text-2xl font-bold text-slate-800">Marcas de Productos</h1>
      </div>
      <Button label="Nueva Marca" icon="pi pi-plus" severity="success" class="shadow-sm" @click="openCreate" />
    </div>

    <div class="flex flex-col gap-4">
      <div class="flex items-center mb-4">
        <IconField class="flex-1 w-full md:max-w-md">
          <InputIcon class="pi pi-search" />
          <InputText
            v-model="search"
            placeholder="Buscar marca..."
            class="w-full"
            @input="onSearch"
          />
        </IconField>
      </div>

      <DataTable
        :value="marcas"
        :loading="loading"
        :total-records="total"
        :rows="20"
        lazy
        paginator
        :rows-per-page-options="[10, 20, 50]"
        striped-rows
        :sort-field="sortField"
        :sort-order="sortOrder"
        @page="handlePage"
        @sort="handleSort"
      >
        <Column field="nombre" header="Nombre" sortable />
        <Column header="Acciones" :exportable="false" style="width: 120px">
          <template #body="{ data }">
            <div class="flex gap-2">
              <Button text rounded severity="info" @click="openEdit(data)" aria-label="Editar">
                <Pencil :size="16" />
              </Button>
              <Button text rounded severity="danger" @click="handleDelete(data)" aria-label="Eliminar">
                <Trash2 :size="16" />
              </Button>
            </div>
          </template>
        </Column>

        <template #empty>
          <div class="text-center py-8 text-slate-500">
            No se encontraron marcas
          </div>
        </template>
      </DataTable>
    </div>

    <!-- Modal crear/editar -->
    <Dialog
      v-model:visible="showModal"
      :header="editingMarca ? 'Editar Marca' : 'Nueva Marca'"
      modal
      :style="{ width: '28rem' }"
      :closable="!saving"
    >
      <div class="flex flex-col gap-4">
        <div class="flex flex-col gap-1.5">
          <label for="marca-nombre" class="text-sm font-medium text-slate-700">
            Nombre <span class="text-red-500">*</span>
          </label>
          <InputText
            id="marca-nombre"
            v-model="formNombre"
            placeholder="Ej: Honda, Yamaha, Suzuki..."
            :invalid="!!formError"
            @keyup.enter="handleSave"
            autofocus
          />
          <small v-if="formError" class="text-red-600">{{ formError }}</small>
        </div>
      </div>

      <template #footer>
        <Button label="Cancelar" severity="secondary" :disabled="saving" @click="showModal = false" />
        <Button
          :label="editingMarca ? 'Guardar cambios' : 'Crear'"
          :loading="saving"
          @click="handleSave"
        />
      </template>
    </Dialog>

  </div>
</template>
