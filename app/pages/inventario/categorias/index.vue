<script setup lang="ts">
import { Pencil, Trash2 } from 'lucide-vue-next'
import { useDebounceFn } from '@vueuse/core'
import type { CategoriaProducto } from '~/types/database'

const { fetchCategorias, createCategoria, updateCategoria, deleteCategoria, friendlyError } = useCategoriasProductos()
const toast = useToast()
const confirm = useConfirm()

const categorias = ref<CategoriaProducto[]>([])
const total = ref(0)
const loading = ref(false)
const currentPage = ref(0)
const currentSearch = ref('')
const sortField = ref('nombre')
const sortOrder = ref(1)

// Modal state
const showModal = ref(false)
const editingCategoria = ref<CategoriaProducto | null>(null)
const formNombre = ref('')
const saving = ref(false)
const formError = ref('')

const loadCategorias = async () => {
  loading.value = true
  try {
    const result = await fetchCategorias({
      search: currentSearch.value,
      page: currentPage.value,
      rows: 20,
      sortField: sortField.value,
      sortOrder: sortOrder.value
    })
    categorias.value = result.data
    total.value = result.total
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

const handlePage = (event: { page: number; rows: number }) => {
  currentPage.value = event.page
  loadCategorias()
}

const handleSort = (event: { sortField: string; sortOrder: number }) => {
  sortField.value = event.sortField
  sortOrder.value = event.sortOrder
  loadCategorias()
}

const search = ref('')
const onSearch = useDebounceFn(() => {
  currentSearch.value = search.value
  currentPage.value = 0
  loadCategorias()
}, 400)

// Modal actions
const openCreate = () => {
  editingCategoria.value = null
  formNombre.value = ''
  formError.value = ''
  showModal.value = true
}

const openEdit = (cat: CategoriaProducto) => {
  editingCategoria.value = cat
  formNombre.value = cat.nombre
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
    if (editingCategoria.value) {
      await updateCategoria(editingCategoria.value.id, nombre)
      toast.add({ severity: 'success', summary: 'Categoría actualizada', life: 2000 })
    } else {
      await createCategoria(nombre)
      toast.add({ severity: 'success', summary: 'Categoría creada', life: 2000 })
    }
    showModal.value = false
    await loadCategorias()
  } catch (e: any) {
    formError.value = friendlyError(e)
  } finally {
    saving.value = false
  }
}

const handleDelete = (cat: CategoriaProducto) => {
  confirm.require({
    message: `¿Eliminar la categoría "${cat.nombre}"?`,
    header: 'Confirmar eliminación',
    acceptLabel: 'Eliminar',
    rejectLabel: 'Cancelar',
    accept: async () => {
      try {
        await deleteCategoria(cat.id)
        toast.add({ severity: 'success', summary: 'Categoría eliminada', life: 2000 })
        await loadCategorias()
      } catch (e: any) {
        toast.add({ severity: 'error', summary: 'No se pudo eliminar', detail: friendlyError(e), life: 4000 })
      }
    }
  })
}

onMounted(loadCategorias)
</script>

<template>
  <div>
    <div class="flex flex-wrap items-center justify-between gap-4 mb-6">
      <div class="flex items-center gap-3">
        <NuxtLink to="/inventario">
          <Button icon="pi pi-arrow-left" text rounded severity="secondary" aria-label="Volver" />
        </NuxtLink>
        <h1 class="m-0 text-2xl font-bold text-slate-800">Categorías de Productos</h1>
      </div>
      <Button label="Nueva Categoría" icon="pi pi-plus" severity="success" class="shadow-sm" @click="openCreate" />
    </div>

    <div class="flex flex-col gap-4">
      <div class="flex items-center mb-4">
        <IconField class="flex-1 w-full md:max-w-md">
          <InputIcon class="pi pi-search" />
          <InputText
            v-model="search"
            placeholder="Buscar categoría..."
            class="w-full"
            @input="onSearch"
          />
        </IconField>
      </div>

      <DataTable
        :value="categorias"
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
            No se encontraron categorías
          </div>
        </template>
      </DataTable>
    </div>

    <!-- Modal crear/editar -->
    <Dialog
      v-model:visible="showModal"
      :header="editingCategoria ? 'Editar Categoría' : 'Nueva Categoría'"
      modal
      :style="{ width: '28rem' }"
      :closable="!saving"
    >
      <div class="flex flex-col gap-4">
        <div class="flex flex-col gap-1.5">
          <label for="cat-nombre" class="text-sm font-medium text-slate-700">
            Nombre <span class="text-red-500">*</span>
          </label>
          <InputText
            id="cat-nombre"
            v-model="formNombre"
            placeholder="Ej: Aceites y Lubricantes"
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
          :label="editingCategoria ? 'Guardar cambios' : 'Crear'"
          :loading="saving"
          @click="handleSave"
        />
      </template>
    </Dialog>

  </div>
</template>
