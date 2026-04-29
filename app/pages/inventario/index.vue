<script setup lang="ts">
import type { Producto, CategoriaProducto, Marca } from '~/types/database'

const { fetchProductos, fetchUbicaciones, eliminarProductoConMotivo, friendlyError } = useProductos()
const { fetchAllCategorias } = useCategoriasProductos()
const { fetchAllMarcas } = useMarcas()
const { isAdmin } = usePerfil()
const toast = useToast()

const productos = ref<Producto[]>([])
const total = ref(0)
const loading = ref(false)
const currentPage = ref(0)
const currentSearch = ref('')
const sortField = ref('nombre')
const sortOrder = ref(1)
const categorias = ref<CategoriaProducto[]>([])
const marcas = ref<Marca[]>([])
const selectedCategoriaId = ref<string | null>(null)
const selectedMarcaId = ref<string | null>(null)
const selectedUbicacion = ref<string | null>(null)
const ubicaciones = ref<string[]>([])
const soloActivos = ref(true)

const actualizarUbicacionesDesdeProductos = (items: Producto[]) => {
  const currentSet = new Set(ubicaciones.value)
  items.forEach(p => {
    if (p.ubicacion && p.ubicacion.trim()) {
      currentSet.add(p.ubicacion.trim())
    }
  })
  ubicaciones.value = Array.from(currentSet).sort((a, b) => a.localeCompare(b))
}

const loadCategorias = async () => {
  try {
    categorias.value = await fetchAllCategorias()
  } catch {
    categorias.value = []
  }
}

const loadMarcas = async () => {
  try {
    marcas.value = await fetchAllMarcas()
  } catch {
    marcas.value = []
  }
}

const loadProductos = async () => {
  loading.value = true
  try {
    const result = await fetchProductos({
      search: currentSearch.value,
      page: currentPage.value,
      rows: 20,
      sortField: sortField.value,
      sortOrder: sortOrder.value,
      categoriaId: selectedCategoriaId.value,
      marcaId: selectedMarcaId.value,
      ubicacion: selectedUbicacion.value,
      soloActivos: soloActivos.value
    })
    productos.value = result.data
    total.value = result.total
    
    // Extraer automáticamente estantes de los datos actuales
    actualizarUbicacionesDesdeProductos(result.data)
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 3000 })
  } finally {
    loading.value = false
  }
}

const handlePage = (event: { page: number; rows: number }) => {
  currentPage.value = event.page
  loadProductos()
}

const handleSearch = (term: string) => {
  currentSearch.value = term
  currentPage.value = 0
  loadProductos()
}

const handleSort = (event: { sortField: string; sortOrder: number }) => {
  sortField.value = event.sortField
  sortOrder.value = event.sortOrder
  loadProductos()
}

const handleFilterCategoria = (id: string | null) => {
  selectedCategoriaId.value = id
  currentPage.value = 0
  loadProductos()
}

const handleFilterMarca = (id: string | null) => {
  selectedMarcaId.value = id
  currentPage.value = 0
  loadProductos()
}

const handleFilterUbicacion = (val: string | null) => {
  selectedUbicacion.value = val
  currentPage.value = 0
  loadProductos()
}

const handleFilterActivos = (value: boolean) => {
  soloActivos.value = value
  currentPage.value = 0
  loadProductos()
}

const handleEdit = (producto: Producto) => {
  navigateTo(`/inventario/${producto.id}`)
}

const imprimirReporte = () => {
  window.print()
}

const eliminarModal = ref(false)
const productoAEliminar = ref<Producto | null>(null)
const motivoEliminacion = ref('')
const eliminando = ref(false)

const handleDelete = (producto: Producto) => {
  productoAEliminar.value = producto
  motivoEliminacion.value = ''
  eliminarModal.value = true
}

const confirmarEliminacion = async () => {
  if (!productoAEliminar.value) return
  if (motivoEliminacion.value.trim().length < 10) {
    toast.add({ severity: 'warn', summary: 'Motivo requerido', detail: 'Mínimo 10 caracteres', life: 3000 })
    return
  }
  eliminando.value = true
  try {
    await eliminarProductoConMotivo(productoAEliminar.value.id, motivoEliminacion.value.trim())
    toast.add({ severity: 'success', summary: 'Producto eliminado', life: 2000 })
    eliminarModal.value = false
    await loadProductos()
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'No se puede eliminar', detail: friendlyError(e), life: 6000 })
  } finally {
    eliminando.value = false
  }
}

onMounted(async () => {
  await Promise.all([
    loadCategorias(),
    loadMarcas()
  ])
  await loadProductos()
})
</script>

<template>
  <div>
    <div class="flex flex-wrap items-center justify-between gap-4 mb-6">
      <h1 class="m-0 text-2xl font-bold text-slate-800">Inventario</h1>
      <div v-if="isAdmin" class="flex gap-2">
        <Button label="Imprimir Planilla" icon="pi pi-print" severity="info" outlined @click="imprimirReporte" class="shadow-sm" />
        <NuxtLink to="/inventario/marcas">
          <Button label="Marcas" icon="pi pi-bookmark" severity="secondary" outlined class="shadow-sm" />
        </NuxtLink>
        <NuxtLink to="/inventario/categorias">
          <Button label="Categorías" icon="pi pi-tags" severity="secondary" outlined class="shadow-sm" />
        </NuxtLink>
        <NuxtLink to="/inventario/nuevo">
          <Button label="Nuevo Producto" icon="pi pi-plus" severity="success" class="shadow-sm" />
        </NuxtLink>
      </div>
    </div>

    <InventarioProductoTable
      :productos="productos"
      :total="total"
      :loading="loading"
      :sort-field="sortField"
      :sort-order="sortOrder"
      :categorias="categorias"
      :marcas="marcas"
      :selected-categoria-id="selectedCategoriaId"
      :selected-marca-id="selectedMarcaId"
      :ubicaciones="ubicaciones"
      :selected-ubicacion="selectedUbicacion"
      :solo-activos="soloActivos"
      @page="handlePage"
      @search="handleSearch"
      @sort="handleSort"
      @edit="handleEdit"
      @delete="handleDelete"
      @filter-categoria="handleFilterCategoria"
      @filter-marca="handleFilterMarca"
      @filter-ubicacion="handleFilterUbicacion"
      @filter-activos="handleFilterActivos"
    />

    <Dialog
      v-model:visible="eliminarModal"
      modal
      header="Eliminar producto"
      :style="{ width: '500px' }"
      :closable="!eliminando"
    >
      <div v-if="productoAEliminar" class="space-y-3">
        <div class="bg-red-50 border border-red-200 rounded-lg p-3">
          <p class="text-sm text-red-800 font-medium">
            Vas a eliminar permanentemente:
          </p>
          <p class="text-sm text-red-700 mt-1">
            <strong>{{ productoAEliminar.codigo_parte }}</strong> — {{ productoAEliminar.nombre }}
          </p>
        </div>
        <p class="text-xs text-slate-600">
          Si el producto tiene ventas o compras registradas, no podrá eliminarse para preservar el historial.
          Indica el motivo de la eliminación (quedará en auditoría):
        </p>
        <Textarea
          v-model="motivoEliminacion"
          rows="4"
          class="w-full"
          placeholder="Ej: Producto duplicado creado por error, sin movimientos"
          :disabled="eliminando"
        />
        <div class="text-xs text-slate-500">
          {{ motivoEliminacion.trim().length }} / 10 mínimo
        </div>
      </div>
      <template #footer>
        <Button label="Cancelar" severity="secondary" text :disabled="eliminando" @click="eliminarModal = false" />
        <Button
          label="Eliminar"
          severity="danger"
          :loading="eliminando"
          :disabled="motivoEliminacion.trim().length < 10"
          @click="confirmarEliminacion"
        />
      </template>
    </Dialog>


    <!-- Reporte Imprimible (Oculto en pantalla) -->
    <InventarioChecklistReport 
      :productos="productos" 
      :filtros="{
        search: currentSearch,
        categoria: categorias.find(c => c.id === selectedCategoriaId)?.nombre,
        marca: marcas.find(m => m.id === selectedMarcaId)?.nombre,
        ubicacion: selectedUbicacion
      }"
    />
  </div>
</template>
