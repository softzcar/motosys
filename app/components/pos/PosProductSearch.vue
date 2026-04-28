<script setup lang="ts">
import { Search, Barcode, LayoutGrid, X } from 'lucide-vue-next'
import { useDebounceFn } from '@vueuse/core'
import { useOfflineDb, db } from '~/composables/useOfflineDb'
import type { Producto } from '~/types/database'

const { fetchProductos, findByCodigo } = useProductos()
const { isOnline } = useOfflineDb()
const cart = useCartStore()
const toast = useToast()

const search = ref('')
const resultados = ref<Producto[]>([])
const loading = ref(false)
const searchInput = ref<any>(null)
const showCategories = ref(false)

const buscar = useDebounceFn(async () => {
  if (!search.value || search.value.length < 2) {
    resultados.value = []
    return
  }
  loading.value = true
  
  try {
    if (isOnline.value) {
      const { data } = await fetchProductos({ search: search.value, rows: 10, soloActivos: true })
      resultados.value = data
    } else {
      // Búsqueda Offline en Dexie
      console.log('🔍 Buscando en DB Local...')
      const term = search.value.toLowerCase()
      const localResults = await db.productos
        .filter(p => 
          p.nombre.toLowerCase().includes(term) || 
          p.codigo_parte.toLowerCase().includes(term)
        )
        .limit(10)
        .toArray()
      resultados.value = localResults
    }
  } catch (e) {
    console.error('Error en búsqueda:', e)
    resultados.value = []
  } finally {
    loading.value = false
  }
}, 300)

const addToCart = (producto: Producto) => {
  const added = cart.addItem(producto)
  if (!added) {
    toast.add({ severity: 'warn', summary: 'Stock insuficiente', detail: `"${producto.nombre}" sin stock disponible`, life: 2000 })
  } else {
    toast.add({ severity: 'success', summary: 'Agregado', detail: producto.nombre, life: 1000 })
    // Limpiar búsqueda y resultados al agregar con éxito
    search.value = ''
    resultados.value = []
  }
}

// Barcode scanner
useBarcodeScanner(async (code) => {
  try {
    let producto = null
    if (isOnline.value) {
      producto = await findByCodigo(code)
    } else {
      // Búsqueda Offline en Dexie
      producto = await db.productos.where('codigo_parte').equals(code).first()
    }
    
    if (producto) addToCart(producto)
    else toast.add({ severity: 'warn', summary: 'No encontrado', detail: `Código: ${code}`, life: 3000 })
    
  } catch (e) {
    console.error('Error escaneando:', e)
    toast.add({ severity: 'error', summary: 'Error de escaneo', life: 3000 })
  }
})

// Shortcut F2 para buscar y F4 para categorías
const handleGlobalKey = (e: KeyboardEvent) => {
  // Solo si no hay un modal abierto (para evitar conflictos)
  if (e.key === 'F2') {
    e.preventDefault()
    searchInput.value?.$el?.focus?.() || searchInput.value?.focus?.()
  }
  if (e.key === 'F4') {
    e.preventDefault()
    showCategories.value = !showCategories.value
  }
}

onMounted(() => window.addEventListener('keydown', handleGlobalKey))
onUnmounted(() => window.removeEventListener('keydown', handleGlobalKey))
</script>

<template>
  <div class="bg-white rounded-xl shadow-sm flex flex-col h-full">
    <div class="p-4 border-b border-slate-200">
      <div class="flex items-center justify-between mb-2">
        <div class="flex items-center gap-2">
          <Barcode :size="18" class="text-green-600" />
          <span class="text-xs text-green-600 font-medium">Scanner activo</span>
        </div>
        <div class="flex gap-1.5">
          <span class="text-[9px] font-bold text-slate-400 bg-slate-100 px-2 py-0.5 rounded uppercase tracking-tighter">F2: Buscar</span>
          <span class="text-[9px] font-bold text-blue-400 bg-blue-50 px-2 py-0.5 rounded border border-blue-100 uppercase tracking-tighter">F4: Categorías</span>
        </div>
      </div>
      
      <div class="flex gap-2">
        <IconField class="flex-1">
          <InputIcon class="pi pi-search" />
          <InputText
            ref="searchInput"
            v-model="search"
            placeholder="Nombre o código..."
            class="w-full"
            @input="buscar"
          />
        </IconField>
        
        <Button 
          severity="secondary" 
          outlined 
          class="aspect-square" 
          title="Explorar por Categorías"
          @click="showCategories = true"
        >
          <LayoutGrid :size="20" />
        </Button>
      </div>
    </div>

    <div class="flex-1 overflow-auto">
      <div v-if="loading" class="flex justify-center py-8">
        <ProgressSpinner style="width: 32px; height: 32px" />
      </div>

      <div v-else-if="resultados.length > 0" class="divide-y divide-slate-100">
        <button
          v-for="p in resultados"
          :key="p.id"
          class="w-full text-left p-4 hover:bg-slate-50 transition-colors flex items-center gap-3"
          @click="addToCart(p)"
        >
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-slate-800 truncate">{{ p.nombre }}</p>
            <p class="text-xs text-slate-500">{{ p.codigo_parte }}</p>
          </div>
          <div class="text-right shrink-0">
            <p class="text-sm font-semibold text-slate-800">${{ Number(p.precio_venta).toFixed(2) }}</p>
            <Tag
              :value="`Stock: ${p.stock}`"
              :severity="p.stock < 5 ? 'danger' : 'success'"
              class="text-xs"
            />
          </div>
        </button>
      </div>

      <div v-else-if="search.length >= 2" class="text-center py-12 text-slate-400">
        <Search :size="32" class="mx-auto mb-2 opacity-50" />
        <p class="text-sm">Sin resultados</p>
      </div>

      <div v-else class="text-center py-12 text-slate-400">
        <Search :size="32" class="mx-auto mb-2 opacity-50" />
        <p class="text-sm">Escanea un código o escribe para buscar</p>
      </div>
    </div>

    <!-- Selector de Categorías -->
    <PosCategorySelector 
      v-model:visible="showCategories" 
    />
  </div>
</template>
