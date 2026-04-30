<script setup lang="ts">
import { Tag as TagIcon, ChevronRight, ChevronLeft, PackageSearch, ShoppingCart } from 'lucide-vue-next'
import { useMarcas } from '~/composables/useMarcas'
import { useOfflineDb, db } from '~/composables/useOfflineDb'
import type { Marca, Producto } from '~/types/database'

const props = defineProps<{
  visible: boolean
}>()

const emit = defineEmits<{
  'update:visible': [value: boolean]
}>()

const { fetchAllMarcas } = useMarcas()
const { fetchProductos } = useProductos()
const { isOnline } = useOfflineDb()
const cart = useCartStore()
const toast = useToast()

const marcas = ref<Marca[]>([])
const productos = ref<Producto[]>([])
const marcaSeleccionada = ref<Marca | null>(null)

const loading = ref(false)
const loadingProds = ref(false)

const loadMarcas = async () => {
  loading.value = true
  try {
    if (isOnline.value) {
      const data = await fetchAllMarcas()
      marcas.value = data
      // Nota: Si en el futuro agregamos marcas a Dexie, cachearíamos aquí
    } else {
      // Intento de carga offline (solo funcionará si se agrega la tabla a Dexie)
      if ((db as any).marcas) {
        marcas.value = await (db as any).marcas.toArray()
      } else {
        // Fallback: tratar de extraer marcas únicas de los productos cacheados
        const localProds = await db.productos.toArray()
        const uniqueMarcaIds = [...new Set(localProds.map(p => p.marca_id).filter(Boolean))]
        // Esto es limitado porque no tenemos los nombres de las marcas offline sin la tabla
        toast.add({ severity: 'warn', summary: 'Offline', detail: 'Marcas no disponibles sin conexión', life: 3000 })
      }
    }
  } catch (e) {
    console.error('Error cargando marcas:', e)
  } finally {
    loading.value = false
  }
}

const selectMarca = async (marca: Marca) => {
  marcaSeleccionada.value = marca
  loadingProds.value = true
  try {
    let prods: Producto[] = []
    if (isOnline.value) {
      const { data } = await fetchProductos({ marcaId: marca.id, rows: 200, soloActivos: true })
      prods = data
    } else {
      prods = await db.productos.where('marca_id').equals(marca.id).toArray()
    }
    productos.value = prods
  } catch (e) {
    console.error('Error cargando productos:', e)
  } finally {
    loadingProds.value = false
  }
}

const addToCart = (p: Producto) => {
  const added = cart.addItem(p)
  if (!added) {
    toast.add({ severity: 'warn', summary: 'Sin Stock', detail: p.nombre, life: 2000 })
  } else {
    toast.add({ severity: 'success', summary: 'Agregado', detail: p.nombre, life: 1000 })
  }
}

const volverAMarcas = () => {
  marcaSeleccionada.value = null
  productos.value = []
}

watch(() => props.visible, (newVal) => {
  if (newVal && marcas.value.length === 0) {
    loadMarcas()
  }
  if (!newVal) {
    volverAMarcas()
  }
})
</script>

<template>
  <Drawer
    :visible="visible"
    @update:visible="emit('update:visible', $event)"
    position="left"
    class="w-full md:w-[400px]"
  >
    <template #header>
       <div class="flex items-center gap-3">
          <button 
            v-if="marcaSeleccionada" 
            @click="volverAMarcas"
            class="p-2 hover:bg-slate-100 rounded-lg text-slate-500 transition-colors"
          >
            <ChevronLeft :size="20" />
          </button>
          <div v-else class="p-2 bg-amber-50 text-amber-600 rounded-lg">
            <TagIcon :size="20" />
          </div>
          <div>
            <h3 class="font-bold text-slate-700 uppercase tracking-tight leading-none">
              {{ marcaSeleccionada ? marcaSeleccionada.nombre : 'Marcas' }}
            </h3>
            <p v-if="marcaSeleccionada" class="text-[9px] font-bold text-slate-400 uppercase mt-1">
              {{ productos.length }} Productos encontrados
            </p>
          </div>
       </div>
    </template>

    <div class="flex flex-col h-full overflow-hidden">
      <!-- VISTA 1: LISTA DE MARCAS -->
      <div v-if="!marcaSeleccionada" class="flex-1 overflow-y-auto pr-2">
        <div v-if="loading" class="flex flex-col items-center justify-center py-20 gap-3 text-slate-400">
          <ProgressSpinner style="width: 40px; height: 40px" />
          <span class="text-[10px] font-black uppercase tracking-widest">Cargando...</span>
        </div>

        <div v-else class="grid grid-cols-1 gap-1">
          <button
            v-for="m in marcas"
            :key="m.id"
            class="flex items-center justify-between p-4 rounded-xl border border-slate-100 hover:border-amber-200 hover:bg-amber-50 transition-all group"
            @click="selectMarca(m)"
          >
            <span class="text-sm font-bold text-slate-600 group-hover:text-amber-700 uppercase tracking-tight">{{ m.nombre }}</span>
            <ChevronRight :size="16" class="text-slate-300 group-hover:text-amber-400" />
          </button>
          
          <div v-if="!loading && marcas.length === 0" class="text-center py-20 text-slate-400">
             <TagIcon :size="48" class="mx-auto mb-3 opacity-20" />
             <p class="text-xs font-bold uppercase">No hay marcas disponibles</p>
          </div>
        </div>
      </div>

      <!-- VISTA 2: LISTA DE PRODUCTOS -->
      <div v-else class="flex-1 overflow-y-auto pr-2">
        <div v-if="loadingProds" class="flex flex-col items-center justify-center py-20 gap-3 text-slate-400">
          <ProgressSpinner style="width: 40px; height: 40px" />
          <span class="text-[10px] font-black uppercase tracking-widest">Buscando productos...</span>
        </div>

        <div v-else-if="productos.length === 0" class="flex flex-col items-center justify-center py-20 gap-3 text-slate-400">
          <PackageSearch :size="48" class="opacity-20" />
          <span class="text-xs font-bold uppercase">Sin productos</span>
        </div>

        <div v-else class="grid grid-cols-1 gap-1">
          <button
            v-for="p in productos"
            :key="p.id"
            class="w-full flex items-center gap-3 p-3 rounded-xl border border-slate-50 hover:border-emerald-200 hover:bg-emerald-50 transition-all group text-left"
            @click="addToCart(p)"
          >
            <div class="flex-1 min-w-0">
              <p class="text-sm font-bold text-slate-700 group-hover:text-emerald-800 truncate leading-tight">{{ p.nombre }}</p>
              <p class="text-[10px] font-bold text-slate-400 group-hover:text-emerald-600 uppercase">{{ p.codigo_parte }}</p>
            </div>
            <div class="text-right shrink-0">
              <p class="text-sm font-black text-slate-800">${{ Number(p.precio_venta).toFixed(2) }}</p>
              <span 
                class="text-[9px] font-black px-1.5 py-0.5 rounded uppercase"
                :class="p.stock <= 0 ? 'bg-red-100 text-red-600' : 'bg-slate-100 text-slate-500'"
              >
                Stock: {{ p.stock }}
              </span>
            </div>
            <div class="p-2 bg-slate-50 group-hover:bg-emerald-500 group-hover:text-white rounded-lg transition-colors">
              <ShoppingCart :size="16" />
            </div>
          </button>
        </div>
      </div>
    </div>

    <template #footer>
      <div class="p-4 border-t border-slate-100">
        <Button 
          severity="secondary" 
          text 
          fluid 
          class="font-bold text-xs uppercase tracking-widest"
          @click="emit('update:visible', false)"
        >
          Cerrar Explorador
        </Button>
      </div>
    </template>
  </Drawer>
</template>
