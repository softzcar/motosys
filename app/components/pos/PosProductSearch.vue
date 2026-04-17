<script setup lang="ts">
import { Search, Barcode } from 'lucide-vue-next'
import { useDebounceFn } from '@vueuse/core'
import type { Producto } from '~/types/database'

const { fetchProductos, findByCodigo } = useProductos()
const cart = useCartStore()
const toast = useToast()

const search = ref('')
const resultados = ref<Producto[]>([])
const loading = ref(false)

const buscar = useDebounceFn(async () => {
  if (!search.value || search.value.length < 2) {
    resultados.value = []
    return
  }
  loading.value = true
  try {
    const { data } = await fetchProductos({ search: search.value, rows: 10, soloActivos: true })
    resultados.value = data
  } catch {
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
  }
}

// Barcode scanner
useBarcodeScanner(async (code) => {
  try {
    const producto = await findByCodigo(code)
    addToCart(producto)
  } catch {
    toast.add({ severity: 'error', summary: 'No encontrado', detail: `Código: ${code}`, life: 3000 })
  }
})
</script>

<template>
  <div class="bg-white rounded-xl shadow-sm flex flex-col h-full">
    <div class="p-4 border-b border-slate-200">
      <div class="flex items-center gap-2 mb-2">
        <Barcode :size="18" class="text-green-600" />
        <span class="text-xs text-green-600 font-medium">Scanner activo</span>
      </div>
      <IconField>
        <InputIcon class="pi pi-search" />
        <InputText
          v-model="search"
          placeholder="Buscar producto por nombre o código..."
          class="w-full"
          @input="buscar"
        />
      </IconField>
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
  </div>
</template>
