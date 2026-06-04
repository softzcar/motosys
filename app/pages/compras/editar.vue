<script setup lang="ts">
import { useProveedores } from '~/composables/useProveedores'
import { useProductos } from '~/composables/useProductos'
import { useCompras, type DetalleCompra } from '~/composables/useCompras'
import { useToast } from 'primevue/usetoast'
import ProductoForm from '~/components/inventario/ProductoForm.vue'
import { useBarcodeScanner } from '~/composables/useBarcodeScanner'
import { Plus, ArrowLeft, Save, Trash2, ShoppingBag, Package, XCircle, Tag, Pencil } from 'lucide-vue-next'

const { fetchProveedores, crearProveedor } = useProveedores()
const { fetchProductos, createProducto, getProductoByCodigo, friendlyError } = useProductos()
const { getCompraById, actualizarCompra } = useCompras()
const supabase = useSupabaseClient()
const toast = useToast()
const router = useRouter()
const route = useRoute()

const compraId = ref<string | null>(null)
const compraNumero = ref<number | null>(null)
const loadingData = ref(true)
const saving = ref(false)

const proveedores = ref<any[]>([])
const productos = ref<any[]>([])
const loadingProveedores = ref(false)
const loadingProductos = ref(false)

const purchase = ref({
  numero_factura: '',
  fecha: '',
  id_proveedor: null as string | null,
  descuento: 0,
  subtotal: 0,
  iva: 0,
  total: 0
})

const empresaIvaConfig = ref(16)
const isIvaManual = ref(false)

const cart = ref<(DetalleCompra & { nombre: string, codigo_parte: string })[]>([])

const selectedProducto = ref<any>(null)
const confirmedProducto = ref<any>(null)
const itemCantidad = ref(1)
const itemCosto = ref(0)

// Watcher para confirmar selección y limpiar buscador
watch(selectedProducto, (newVal) => {
  if (newVal && typeof newVal === 'object' && newVal.id) {
    confirmedProducto.value = newVal
    nextTick(() => {
      selectedProducto.value = null
    })
  }
})

// Watcher para limpiar campos al deseleccionar producto
watch(confirmedProducto, (newVal) => {
  if (!newVal) {
    itemCantidad.value = 1
    itemCosto.value = 0
  }
})

const productoDialog = ref(false)
const savingProducto = ref(false)

// Manejo de escaneo de código de barras
const handleScan = async (code: string) => {
  console.log('Código escaneado:', code)
  loadingProductos.value = true
  try {
    const prod = await getProductoByCodigo(code)
    if (prod) {
      confirmedProducto.value = prod
      toast.add({ severity: 'success', summary: 'Producto detectado', detail: prod.nombre, life: 2000 })
    } else {
      toast.add({ 
        severity: 'info', 
        summary: 'Producto no encontrado', 
        detail: `El código ${code} no existe. Crea el producto nuevo.`, 
        life: 3000 
      })
      productoDialog.value = true
    }
  } catch (err) {
    console.error('Error buscando producto escaneado:', err)
  } finally {
    loadingProductos.value = false
  }
}

// Inicializar el escuchador de código de barras
useBarcodeScanner(handleScan)

const proveedorModal = ref(false)
const nuevoProveedor = ref({ nombre: '', telefono: '', direccion: '' })
const validatingProveedor = ref(false)
const guardandoProveedor = ref(false)

const openNuevoProveedor = () => {
  nuevoProveedor.value = { nombre: '', telefono: '', direccion: '' }
  validatingProveedor.value = false
  proveedorModal.value = true
}

const onProveedorSubmit = async () => {
  validatingProveedor.value = true
  if (!nuevoProveedor.value.nombre.trim()) return

  guardandoProveedor.value = true
  try {
    const creado = await crearProveedor(nuevoProveedor.value)
    toast.add({ severity: 'success', summary: 'Éxito', detail: 'Proveedor creado', life: 3000 })
    proveedorModal.value = false
    proveedores.value.push(creado)
    purchase.value.id_proveedor = creado.id
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 3000 })
  } finally {
    guardandoProveedor.value = false
  }
}

const onProductoSubmit = async (data: { values: any }) => {
  savingProducto.value = true
  try {
    const nuevo = await createProducto(data.values)
    toast.add({ severity: 'success', summary: 'Éxito', detail: 'Producto creado exitosamente', life: 3000 })
    productoDialog.value = false
    confirmedProducto.value = nuevo
  } catch (err: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: friendlyError(err), life: 3000 })
  } finally {
    savingProducto.value = false
  }
}

const loadProveedores = async (query = '') => {
  loadingProveedores.value = true
  try {
    const { data } = await fetchProveedores({ search: query, rows: 100 })
    proveedores.value = data
  } finally {
    loadingProveedores.value = false
  }
}

const searchProductos = async (event: any) => {
  loadingProductos.value = true
  try {
    const { data } = await fetchProductos({ search: event.query, rows: 200, soloActivos: true })
    productos.value = data
  } finally {
    loadingProductos.value = false
  }
}

const addItem = () => {
  if (!confirmedProducto.value || itemCantidad.value <= 0) return

  const subtotal = itemCantidad.value * itemCosto.value
  cart.value.push({
    id_producto: confirmedProducto.value.id,
    nombre: confirmedProducto.value.nombre,
    codigo_parte: confirmedProducto.value.codigo_parte,
    cantidad: itemCantidad.value,
    costo_unitario: itemCosto.value,
    subtotal
  })

  confirmedProducto.value = null
  itemCantidad.value = 1
  itemCosto.value = 0
  calculateTotal()
}

const removeItem = (index: number) => {
  cart.value.splice(index, 1)
  calculateTotal()
}

const recalcItem = (index: number) => {
  const item = cart.value[index]
  if (!item) return
  const cantidad = Math.max(1, Number(item.cantidad) || 0)
  const costo = Math.max(0, Number(item.costo_unitario) || 0)
  item.page = undefined // eliminar propiedades raras
  item.cantidad = cantidad
  item.costo_unitario = costo
  item.subtotal = cantidad * costo
  calculateTotal()
}

const calculateTotal = () => {
  const subtotalItems = cart.value.reduce((acc, item) => acc + item.subtotal, 0)
  purchase.value.subtotal = subtotalItems
  
  const descPorcentaje = Number(purchase.value.descuento) || 0
  const montoDescuento = subtotalItems * (descPorcentaje / 100)
  const baseImponible = subtotalItems - montoDescuento
  
  if (!isIvaManual.value) {
    purchase.value.iva = baseImponible * (empresaIvaConfig.value / 100)
  }
  
  purchase.value.total = baseImponible + purchase.value.iva
}

watch(isIvaManual, (manual) => {
  if (!manual) {
    calculateTotal()
  }
})

watch(() => purchase.value.iva, () => {
  if (isIvaManual.value) {
    calculateTotal()
  }
})

const onSave = async () => {
  if (!compraId.value) return
  
  if (!purchase.value.id_proveedor || !purchase.value.numero_factura || cart.value.length === 0) {
    toast.add({ severity: 'warn', summary: 'Atención', detail: 'Complete todos los campos y agregue productos', life: 3000 })
    return
  }

  saving.value = true
  try {
    const detalles: DetalleCompra[] = cart.value.map(({ nombre, codigo_parte, ...rest }) => rest)
    
    const fechaFinal = purchase.value.fecha instanceof Date 
      ? (purchase.value.fecha as Date).toISOString().split('T')[0]
      : purchase.value.fecha
    
    await actualizarCompra(compraId.value, {
      numero_factura: purchase.value.numero_factura,
      fecha: fechaFinal,
      id_proveedor: purchase.value.id_proveedor,
      descuento: purchase.value.descuento,
      subtotal: purchase.value.subtotal,
      iva: purchase.value.iva,
      total: purchase.value.total
    }, detalles)

    toast.add({ severity: 'success', summary: 'Éxito', detail: 'Factura de compra actualizada e inventario ajustado', life: 3000 })
    router.push('/compras')
  } catch (error: any) {
    console.error('Error al actualizar compra:', error)
    toast.add({ severity: 'error', summary: 'Error', detail: error.message || 'Error al actualizar', life: 5000 })
  } finally {
    saving.value = false
  }
}

const loadEmpresaConfig = async () => {
  try {
    const { data } = await supabase.from('empresa').select('iva').single()
    if (data && data.iva !== null) {
      empresaIvaConfig.value = Number(data.iva)
    }
  } catch (e) {
    console.error('Error fetching empresa IVA', e)
  }
}

const cargarDatosCompra = async (id: string) => {
  loadingData.value = true
  try {
    const original = await getCompraById(id)
    if (original.anulada) {
      toast.add({
        severity: 'warn',
        summary: 'No se puede editar',
        detail: 'La factura ya se encuentra anulada. Debes corregirla desde una nueva compra.',
        life: 5000
      })
      router.push('/compras')
      return
    }
    
    compraId.value = id
    compraNumero.value = original.numero
    purchase.value.id_proveedor = original.id_proveedor
    purchase.value.numero_factura = original.numero_factura
    purchase.value.fecha = original.fecha
    purchase.value.descuento = Number(original.descuento ?? 0)
    isIvaManual.value = true
    purchase.value.iva = Number(original.iva ?? 0)

    cart.value = (original.detalle_compras ?? []).map((d: any) => ({
      id_producto: d.id_producto,
      nombre: d.productos?.nombre ?? '',
      codigo_parte: d.productos?.codigo_parte ?? '',
      cantidad: Number(d.cantidad),
      costo_unitario: Number(d.costo_unitario),
      subtotal: Number(d.subtotal)
    }))
    calculateTotal()
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error al cargar compra', detail: e.message, life: 4000 })
    router.push('/compras')
  } finally {
    loadingData.value = false
  }
}

onMounted(async () => {
  loadEmpresaConfig()
  await loadProveedores()
  const id = route.query.id
  if (typeof id === 'string' && id) {
    await cargarDatosCompra(id)
  } else {
    toast.add({ severity: 'error', summary: 'Error', detail: 'ID de compra no especificado', life: 3000 })
    router.push('/compras')
  }
})

const formatCurrency = (value: number) => {
  return value.toLocaleString('en-US', { style: 'currency', currency: 'USD' })
}
</script>

<template>
  <div class="max-w-7xl mx-auto p-4 md:p-6 bg-slate-50 min-h-screen">
    <!-- Spinner de carga -->
    <div v-if="loadingData" class="flex flex-col items-center justify-center p-24 bg-white rounded-2xl shadow-sm border border-slate-200 min-h-[500px]">
      <span class="w-12 h-12 border-4 border-slate-200 border-t-blue-500 rounded-full animate-spin mb-4"></span>
      <span class="text-slate-600 font-semibold text-base">Cargando datos de la factura...</span>
    </div>

    <div v-else>
      <!-- Header -->
      <div class="flex items-center justify-between mb-6 bg-white p-5 rounded-xl shadow-sm border border-slate-200">
        <div class="flex items-center gap-4">
          <NuxtLink to="/compras" class="p-2 hover:bg-slate-50 rounded-lg transition-colors">
            <ArrowLeft class="w-5 h-5 text-slate-500" />
          </NuxtLink>
          <div>
            <h1 class="text-xl font-bold text-slate-900 m-0 leading-tight">Editar Compra #{{ compraNumero }}</h1>
            <p class="text-slate-400 text-xs mt-0.5">Modificación de factura y recalculo de inventario</p>
          </div>
        </div>
        <div class="flex items-center gap-6">
          <div class="text-right hidden sm:block">
            <span class="block text-[9px] text-slate-400 uppercase font-bold tracking-widest">Total Factura</span>
            <span class="text-2xl font-black text-blue-600 leading-none">{{ formatCurrency(purchase.total) }}</span>
          </div>
          <Button 
            label="Actualizar Factura" 
            icon="pi pi-save" 
            severity="primary" 
            @click="onSave" 
            :disabled="cart.length === 0" 
            :loading="saving"
            class="shadow-md" 
          />
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-12 gap-6">
        <!-- 1. DATOS DE FACTURA (SIDEBAR) -->
        <div class="lg:col-span-4 flex flex-col gap-6">
          <div class="bg-white p-6 rounded-xl shadow-sm border border-slate-200 h-full">
            <div class="flex items-center gap-2 mb-6 text-slate-700">
              <div class="p-1.5 bg-blue-50 rounded-md">
                <ShoppingBag class="w-4 h-4 text-blue-600" />
              </div>
              <h2 class="font-bold text-sm uppercase tracking-tight">Datos de Factura</h2>
            </div>

            <div class="flex flex-col gap-5">
              <div class="field">
                <label class="block text-[10px] font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Proveedor</label>
                <InputGroup>
                  <Select 
                    v-model="purchase.id_proveedor" 
                    :options="proveedores" 
                    optionLabel="nombre" 
                    optionValue="id" 
                    placeholder="Seleccionar..."
                    filter
                    :loading="loadingProveedores"
                    class="flex-1"
                  />
                  <Button severity="secondary" outlined @click="openNuevoProveedor" class="border-slate-200">
                    <Plus class="w-4 h-4" />
                  </Button>
                </InputGroup>
              </div>

              <div class="field">
                <label class="block text-[10px] font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Número de Factura</label>
                <InputText v-model="purchase.numero_factura" placeholder="Ej: F-000123" class="w-full" />
              </div>

              <div class="field">
                <label class="block text-[10px] font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Fecha Emisión</label>
                <DatePicker v-model="purchase.fecha" dateFormat="yy-mm-dd" showIcon class="w-full" />
              </div>

              <div class="field">
                <label class="block text-[10px] font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Porcentaje Descuento (%)</label>
                <InputNumber v-model="purchase.descuento" :min="0" :max="100" suffix="%" class="w-full" :minFractionDigits="2" :maxFractionDigits="2" @update:modelValue="calculateTotal" @focus="$event => ($event.target as HTMLInputElement).select()" />
              </div>

              <!-- Total display for tablet/small screens inside sidebar -->
              <div class="mt-4 p-4 bg-slate-50 rounded-lg border border-slate-100 flex flex-col gap-2">
                 <div class="flex justify-between items-center bg-white p-2 rounded border border-slate-100">
                    <span class="text-[10px] font-bold text-slate-500">SUBTOTAL</span>
                    <span class="text-sm font-bold text-slate-800">{{ formatCurrency(purchase.subtotal) }}</span>
                 </div>

                 <div v-if="purchase.descuento > 0" class="flex justify-between items-center bg-white p-2 rounded border border-slate-100">
                    <span class="text-[10px] font-bold text-red-500">DESCUENTO ({{ purchase.descuento }}%)</span>
                    <span class="text-sm font-bold text-red-600">-{{ formatCurrency(purchase.subtotal * (purchase.descuento / 100)) }}</span>
                 </div>
                 
                 <div class="flex flex-col gap-2 bg-white p-2 rounded border border-slate-100">
                    <div class="flex justify-between items-center w-full">
                       <span class="text-[10px] font-bold text-slate-500">IVA</span>
                       <div class="flex items-center gap-2">
                          <span class="text-[9px] text-slate-400">¿Ingresar Manual?</span>
                          <ToggleSwitch v-model="isIvaManual" class="scale-75" />
                       </div>
                    </div>
                    <div v-if="isIvaManual" class="w-full">
                       <InputNumber v-model="purchase.iva" mode="currency" currency="USD" locale="en-US" :minFractionDigits="2" class="w-full" :min="0" @focus="$event => ($event.target as HTMLInputElement).select()" />                  </div>
                    <div v-else class="text-right">
                       <span class="text-sm font-bold text-slate-800">{{ formatCurrency(purchase.iva) }}</span>
                       <span class="text-[9px] text-slate-400 ml-2">(Auto: {{ empresaIvaConfig }}%)</span>
                    </div>
                 </div>

                 <div class="flex justify-between items-center bg-blue-50 p-2 rounded border border-blue-100 mt-2">
                    <span class="text-xs font-black text-blue-700">TOTAL</span>
                    <span class="text-xl font-black text-blue-700">{{ formatCurrency(purchase.total) }}</span>
                 </div>
              </div>
            </div>
          </div>
        </div>

        <!-- 2. AGREGAR PRODUCTOS Y TABLA (MAIN) -->
        <div class="lg:col-span-8 flex flex-col gap-6">
          <!-- FORMULARIO DE INGRESO (Vertical-ish) -->
          <div class="bg-white p-6 rounded-xl shadow-sm border border-slate-200">
            <div class="flex items-center gap-2 mb-6">
              <div class="p-1.5 bg-slate-50 rounded-md">
                <Package class="w-4 h-4 text-slate-500" />
              </div>
              <h2 class="font-bold text-sm uppercase tracking-tight">Agregar ítems de compras</h2>
            </div>

            <!-- LAYOUT EN DOS FILAS PARA EVITAR DESBORDE -->
            <div class="flex flex-col gap-6">
              <!-- Fila 1: Producto -->
              <div class="w-full">
                 <label class="block text-[10px] font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Producto</label>
                 <InputGroup>
                    <AutoComplete 
                      v-model="selectedProducto" 
                      :suggestions="productos" 
                      @complete="searchProductos" 
                      optionLabel="nombre"
                      placeholder="Busca por nombre o código de parte..."
                      forceSelection
                      class="flex-1"
                      data-barcode-input="true"
                    />
                    <Button severity="secondary" outlined @click="productoDialog = true" class="border-slate-200">
                      <Plus class="w-4 h-4" />
                    </Button>
                 </InputGroup>
                 
                 <!-- Tag de producto seleccionado -->
                 <div v-if="confirmedProducto" class="mt-2 flex items-center gap-2 p-2 bg-emerald-50 border border-emerald-100 rounded-lg animate-in fade-in slide-in-from-top-1 duration-300">
                    <div class="p-1 bg-emerald-100 rounded">
                      <Tag class="w-3.5 h-3.5 text-emerald-600" />
                    </div>
                    <div class="flex-1 overflow-hidden">
                      <p class="text-[11px] font-black text-emerald-800 leading-none truncate uppercase tracking-tight">
                        {{ confirmedProducto.nombre }}
                      </p>
                      <p class="text-[9px] text-emerald-600 font-bold mt-0.5">
                        SKU: {{ confirmedProducto.codigo_parte }}
                      </p>
                    </div>
                    <Button 
                      icon="pi pi-times" 
                      severity="secondary" 
                      text 
                      rounded 
                      size="small" 
                      @click="confirmedProducto = null" 
                      class="!p-1 h-6 w-6"
                    >
                      <XCircle class="w-3.5 h-3.5 text-emerald-400" />
                    </Button>
                 </div>
              </div>

              <!-- Fila 2: Cantidad, Costo y Botón -->
              <div class="flex flex-col sm:flex-row gap-4 items-end">
                 <div class="flex-1 w-full sm:w-auto">
                   <label class="block text-[10px] font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Cantidad</label>
                   <InputNumber v-model="itemCantidad" :min="1" class="w-full" :disabled="!confirmedProducto" @focus="$event => ($event.target as HTMLInputElement).select()" />
                 </div>
                 <div class="flex-1 w-full sm:w-auto">
                   <label class="block text-[10px] font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Costo Unitario ($)</label>
                   <InputNumber v-model="itemCosto" mode="currency" currency="USD" locale="en-US" :minFractionDigits="2" class="w-full" :disabled="!confirmedProducto" @focus="$event => ($event.target as HTMLInputElement).select()" />
                 </div>
                 <div class="w-full sm:w-auto">
                   <Button 
                     label="Agregar" 
                     severity="success" 
                     @click="addItem" 
                     :disabled="!confirmedProducto" 
                     class="w-full px-8 h-[42px] font-bold" 
                   >
                     <template #icon>
                       <ShoppingBag class="w-4 h-4 mr-2" />
                     </template>
                   </Button>
                 </div>
              </div>
            </div>
          </div>

          <!-- DETALLES DE COMPRA / TABLA -->
          <div class="bg-white p-6 rounded-xl shadow-sm border border-slate-200">
            <div class="flex items-center gap-2 mb-6">
              <div class="p-1.5 bg-slate-50 rounded-md">
                <ShoppingBag class="w-4 h-4 text-slate-500" />
              </div>
              <h2 class="font-bold text-sm uppercase tracking-tight">Ítems de la Factura</h2>
            </div>

            <div class="overflow-x-auto">
              <table class="w-full text-left border-collapse">
                <thead>
                  <tr class="border-b border-slate-100 text-slate-400 text-[10px] font-bold uppercase tracking-wider">
                    <th class="py-3 px-4">Producto</th>
                    <th class="py-3 px-4 text-center w-24">Cantidad</th>
                    <th class="py-3 px-4 text-right w-36">Costo Unitario ($)</th>
                    <th class="py-3 px-4 text-right w-36">Subtotal ($)</th>
                    <th class="py-3 px-4 text-center w-16"></th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-slate-50">
                  <tr v-if="cart.length === 0">
                    <td colspan="5" class="py-8 text-center text-slate-400 text-sm">
                      No se han agregado productos a la factura todavía
                    </td>
                  </tr>
                  <tr v-for="(item, index) in cart" :key="index" class="hover:bg-slate-50/50 text-slate-700 text-xs transition-colors">
                    <td class="py-3 px-4 font-medium">
                      <div>
                        <p class="font-bold text-slate-800">{{ item.nombre }}</p>
                        <p class="text-[10px] text-slate-400 font-medium">SKU: {{ item.codigo_parte }}</p>
                      </div>
                    </td>
                    <td class="py-3 px-4 text-center">
                      <InputNumber 
                        v-model="item.cantidad" 
                        :min="1" 
                        @update:modelValue="recalcItem(index)"
                        class="p-inputtext-sm text-center w-20 mx-auto"
                        @focus="$event => ($event.target as HTMLInputElement).select()"
                      />
                    </td>
                    <td class="py-3 px-4 text-right">
                      <InputNumber 
                        v-model="item.costo_unitario" 
                        mode="currency" 
                        currency="USD" 
                        locale="en-US" 
                        :minFractionDigits="2" 
                        @update:modelValue="recalcItem(index)"
                        class="p-inputtext-sm text-right w-28 ml-auto"
                        @focus="$event => ($event.target as HTMLInputElement).select()"
                      />
                    </td>
                    <td class="py-3 px-4 text-right font-black text-slate-900">
                      {{ formatCurrency(item.subtotal) }}
                    </td>
                    <td class="py-3 px-4 text-center">
                      <Button 
                        severity="secondary" 
                        text 
                        rounded 
                        size="small" 
                        @click="removeItem(index)" 
                        class="!p-2 text-rose-500 hover:bg-rose-50 hover:text-rose-600 h-8 w-8"
                      >
                        <Trash2 class="w-4 h-4" />
                      </Button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modal para crear Proveedor Rápido -->
    <Dialog v-model:visible="proveedorModal" header="Nuevo Proveedor" modal :style="{ width: '450px' }">
      <form @submit.prevent="onProveedorSubmit" class="space-y-4 pt-2">
        <div class="field">
          <label class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Nombre o Razón Social</label>
          <InputText v-model="nuevoProveedor.nombre" placeholder="Ej: Repuestos XYZ C.A." class="w-full" :class="{ 'p-invalid': validatingProveedor && !nuevoProveedor.nombre }" />
          <small v-if="validatingProveedor && !nuevoProveedor.nombre" class="p-error">El nombre es requerido.</small>
        </div>
        <div class="field">
          <label class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Teléfono</label>
          <InputText v-model="nuevoProveedor.telefono" placeholder="Ej: +58 412-1234567" class="w-full" />
        </div>
        <div class="field">
          <label class="block text-xs font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Dirección</label>
          <Textarea v-model="nuevoProveedor.direccion" rows="3" placeholder="Ej: Calle principal, Local 4..." class="w-full" />
        </div>
        <div class="flex justify-end gap-2 pt-2">
          <Button label="Cancelar" text severity="secondary" @click="proveedorModal = false" />
          <Button label="Guardar" type="submit" severity="success" :loading="guardandoProveedor" />
        </div>
      </form>
    </Dialog>

    <!-- Modal para crear Producto Rápido -->
    <Dialog v-model:visible="productoDialog" header="Crear Producto Nuevo" modal :style="{ width: '650px' }">
      <ProductoForm 
        :submit-label="savingProducto ? 'Creando...' : 'Crear Producto'" 
        @submit="onProductoSubmit" 
        @cancel="productoDialog = false" 
      />
    </Dialog>
  </div>
</template>

<style scoped>
:deep(.p-select) {
  border-color: #cbd5e1;
}
:deep(.p-inputtext) {
  border-color: #cbd5e1;
}
:deep(.p-datepicker-input) {
  border-color: #cbd5e1;
}
:deep(.p-inputnumber-input) {
  border-color: #cbd5e1;
}
</style>
