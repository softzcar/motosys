<script setup lang="ts">
import { useProveedores } from '~/composables/useProveedores'
import { useProductos } from '~/composables/useProductos'
import { useCompras, type DetalleCompra } from '~/composables/useCompras'
import { useToast } from 'primevue/usetoast'
import ProductoForm from '~/components/inventario/ProductoForm.vue'
import { Plus, ArrowLeft, Save, Trash2, ShoppingBag, PackageSearch, Package, RotateCcw } from 'lucide-vue-next'

const { fetchProveedores, crearProveedor } = useProveedores()
const { fetchProductos, createProducto, friendlyError } = useProductos()
const { registrarCompra, getCompraById } = useCompras()
const supabase = useSupabaseClient()
const toast = useToast()
const router = useRouter()
const route = useRoute()

const corrigeCompraId = ref<string | null>(null)
const compraOrigen = ref<any>(null)

const proveedores = ref<any[]>([])
const productos = ref<any[]>([])
const loadingProveedores = ref(false)
const loadingProductos = ref(false)

const purchase = ref({
  numero_factura: '',
  fecha: new Date().toISOString().split('T')[0],
  id_proveedor: null,
  subtotal: 0,
  iva: 0,
  total: 0
})

const empresaIvaConfig = ref(16)
const isIvaManual = ref(false)

const cart = ref<(DetalleCompra & { nombre: string, codigo_parte: string })[]>([])
const selectedProducto = ref<any>(null)
const itemCantidad = ref(1)
const itemCosto = ref(0)

const productoDialog = ref(false)
const savingProducto = ref(false)

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
    selectedProducto.value = nuevo
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
    const { data } = await fetchProductos({ search: event.query, rows: 10 })
    productos.value = data
  } finally {
    loadingProductos.value = false
  }
}

const addItem = () => {
  if (!selectedProducto.value || itemCantidad.value <= 0) return

  const subtotal = itemCantidad.value * itemCosto.value
  cart.value.push({
    id_producto: selectedProducto.value.id,
    nombre: selectedProducto.value.nombre,
    codigo_parte: selectedProducto.value.codigo_parte,
    cantidad: itemCantidad.value,
    costo_unitario: itemCosto.value,
    subtotal
  })

  selectedProducto.value = null
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
  item.cantidad = cantidad
  item.costo_unitario = costo
  item.subtotal = cantidad * costo
  calculateTotal()
}

const calculateTotal = () => {
  purchase.value.subtotal = cart.value.reduce((acc, item) => acc + item.subtotal, 0)
  
  if (!isIvaManual.value) {
    purchase.value.iva = purchase.value.subtotal * (empresaIvaConfig.value / 100)
  }
  
  purchase.value.total = purchase.value.subtotal + purchase.value.iva
}

watch(isIvaManual, (manual) => {
  if (!manual) {
    purchase.value.iva = purchase.value.subtotal * (empresaIvaConfig.value / 100)
    calculateTotal()
  }
})

watch(() => purchase.value.iva, () => {
  if (isIvaManual.value) {
    purchase.value.total = purchase.value.subtotal + purchase.value.iva
  }
})

const onSave = async () => {
  if (!purchase.value.id_proveedor || !purchase.value.numero_factura || cart.value.length === 0) {
    toast.add({ severity: 'warn', summary: 'Atención', detail: 'Complete todos los campos y agregue productos', life: 3000 })
    return
  }

  try {
    const detalles: DetalleCompra[] = cart.value.map(({ nombre, codigo_parte, ...rest }) => rest)
    await registrarCompra({
      numero_factura: purchase.value.numero_factura,
      fecha: purchase.value.fecha,
      id_proveedor: purchase.value.id_proveedor,
      subtotal: purchase.value.subtotal,
      iva: purchase.value.iva,
      total: purchase.value.total,
      ...(corrigeCompraId.value ? { corrige_compra_id: corrigeCompraId.value } : {})
    } as any, detalles)

    toast.add({ severity: 'success', summary: 'Éxito', detail: 'Compra registrada e inventario actualizado', life: 3000 })
    router.push('/compras')
  } catch (error: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: error.message, life: 3000 })
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

const cargarPrefillDesde = async (id: string) => {
  try {
    const original = await getCompraById(id)
    if (!original.anulada) {
      toast.add({
        severity: 'warn',
        summary: 'No se puede corregir',
        detail: 'La compra origen no está anulada.',
        life: 4000
      })
      return
    }
    corrigeCompraId.value = id
    compraOrigen.value = original
    purchase.value.id_proveedor = original.id_proveedor
    purchase.value.numero_factura = original.numero_factura
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
    toast.add({
      severity: 'info',
      summary: 'Datos prellenados',
      detail: `Corrigiendo compra anulada #${original.numero}. Ajusta lo necesario y guarda.`,
      life: 5000
    })
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 4000 })
  }
}

onMounted(async () => {
  loadEmpresaConfig()
  await loadProveedores()
  const fromId = route.query.from
  if (typeof fromId === 'string' && fromId) {
    await cargarPrefillDesde(fromId)
  }
})

const formatCurrency = (value: number) => {
  return value.toLocaleString('en-US', { style: 'currency', currency: 'USD' })
}
</script>

<template>
  <div class="max-w-7xl mx-auto p-4 md:p-6 bg-slate-50 min-h-screen">
    <!-- Header -->
    <div class="flex items-center justify-between mb-6 bg-white p-5 rounded-xl shadow-sm border border-slate-200">
      <div class="flex items-center gap-4">
        <NuxtLink to="/compras" class="p-2 hover:bg-slate-50 rounded-lg transition-colors">
          <ArrowLeft class="w-5 h-5 text-slate-500" />
        </NuxtLink>
        <div>
          <h1 class="text-xl font-bold text-slate-900 m-0 leading-tight">Nueva Compra</h1>
          <p class="text-slate-400 text-xs mt-0.5">Gestión de facturas e ingresos de stock</p>
        </div>
      </div>
      <div class="flex items-center gap-6">
        <div class="text-right hidden sm:block">
          <span class="block text-[9px] text-slate-400 uppercase font-bold tracking-widest">Total Factura</span>
          <span class="text-2xl font-black text-blue-600 leading-none">{{ formatCurrency(purchase.total) }}</span>
        </div>
        <Button label="Guardar Registro" icon="pi pi-save" severity="primary" @click="onSave" :disabled="cart.length === 0" class="shadow-md" />
      </div>
    </div>

    <!-- Banner de corrección -->
    <div v-if="compraOrigen" class="mb-6 bg-amber-50 border border-amber-300 rounded-xl p-4 flex items-start gap-3">
      <RotateCcw class="w-5 h-5 text-amber-700 flex-shrink-0 mt-0.5" />
      <div class="flex-1 text-sm">
        <p class="font-black text-amber-800 uppercase tracking-wide text-xs mb-1">Corrigiendo compra anulada</p>
        <p class="text-amber-900">
          Esta compra reemplazará a la compra <b>#{{ compraOrigen.numero }}</b> ({{ compraOrigen.numero_factura }}) anulada el
          {{ new Date(compraOrigen.anulada_at).toLocaleDateString('es-VE') }}.
          Ajusta los campos que estaban erróneos y guarda.
        </p>
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
                <Dropdown 
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
              <Calendar v-model="purchase.fecha" dateFormat="yy-mm-dd" showIcon class="w-full" />
            </div>

            <!-- Total display for tablet/small screens inside sidebar -->
            <div class="mt-4 p-4 bg-slate-50 rounded-lg border border-slate-100 flex flex-col gap-2">
               <div class="flex justify-between items-center bg-white p-2 rounded border border-slate-100">
                  <span class="text-[10px] font-bold text-slate-500">SUBTOTAL</span>
                  <span class="text-sm font-bold text-slate-800">{{ formatCurrency(purchase.subtotal) }}</span>
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
                     <InputNumber v-model="purchase.iva" mode="currency" currency="USD" locale="en-US" :minFractionDigits="2" class="w-full" :min="0" />
                  </div>
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
                  />
                  <Button severity="secondary" outlined @click="productoDialog = true" class="border-slate-200">
                    <Plus class="w-4 h-4" />
                  </Button>
               </InputGroup>
            </div>

            <!-- Fila 2: Cantidad, Costo y Botón -->
            <div class="flex flex-col sm:flex-row gap-4 items-end">
               <div class="flex-1 w-full sm:w-auto">
                 <label class="block text-[10px] font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Cantidad</label>
                 <InputNumber v-model="itemCantidad" :min="1" class="w-full" />
               </div>
               <div class="flex-1 w-full sm:w-auto">
                 <label class="block text-[10px] font-bold text-slate-500 mb-1.5 uppercase tracking-wide">Costo Unitario ($)</label>
                 <InputNumber v-model="itemCosto" mode="currency" currency="USD" locale="en-US" :minFractionDigits="2" class="w-full" />
               </div>
               <div class="w-full sm:w-auto">
                 <Button 
                   label="Agregar" 
                   severity="success" 
                   @click="addItem" 
                   :disabled="!selectedProducto" 
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

        <!-- TABLA DE DETALLES -->
        <div class="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
          <DataTable :value="cart" class="p-datatable-sm" responsiveLayout="scroll" stripedRows>
            <Column field="codigo_parte" header="CÓDIGO" class="text-[9px] text-slate-400 font-bold"></Column>
            <Column field="nombre" header="PRODUCTO" class="font-bold text-slate-600 text-sm"></Column>
            <Column header="CANT." headerClass="!text-center" style="width: 90px">
              <template #body="slotProps">
                <InputNumber
                  v-model="slotProps.data.cantidad"
                  :min="1"
                  :inputStyle="{ width: '4rem', textAlign: 'center' }"
                  @update:modelValue="recalcItem(slotProps.index)"
                  class="cart-qty"
                />
              </template>
            </Column>
            <Column header="COSTO U." headerClass="!text-right" style="width: 140px">
              <template #body="slotProps">
                <InputNumber
                  v-model="slotProps.data.costo_unitario"
                  mode="currency"
                  currency="USD"
                  locale="en-US"
                  :minFractionDigits="2"
                  :min="0"
                  @update:modelValue="recalcItem(slotProps.index)"
                  :inputStyle="{ textAlign: 'right', width: '100%' }"
                  class="cart-cost"
                />
              </template>
            </Column>
            <Column header="SUBTOTAL" headerClass="!text-right">
              <template #body="slotProps">
                <span class="font-bold text-slate-900">{{ formatCurrency(slotProps.data.subtotal) }}</span>
              </template>
            </Column>
            <Column style="width: 3.5rem" headerClass="!text-center" bodyClass="!text-center">
              <template #body="slotProps">
                <Button
                  text
                  severity="danger"
                  @click="removeItem(slotProps.index)"
                  class="p-2"
                  v-tooltip.top="'Eliminar'"
                >
                  <Trash2 class="w-4 h-4" />
                </Button>
              </template>
            </Column>
            <template #empty>
              <div class="p-12 text-center text-slate-300 italic text-sm border-2 border-dashed border-slate-100 rounded-xl m-4">
                No hay productos en la lista de compra
              </div>
            </template>
          </DataTable>
        </div>
      </div>
    </div>

    <!-- Modals -->
    <Dialog v-model:visible="productoDialog" header="Crear Nuevo Producto" :modal="true" :style="{ width: '500px' }" class="p-fluid">
      <div class="mt-4">
        <ProductoForm @submit="onProductoSubmit" @cancel="productoDialog = false" :loading="savingProducto" />
      </div>
    </Dialog>

    <Dialog v-model:visible="proveedorModal" header="Crear Nuevo Proveedor" :modal="true" :style="{ width: '450px' }" class="p-fluid">
      <div class="flex flex-col gap-4 py-4 pt-5">
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-bold text-slate-500 uppercase">Nombre / Razón Social *</label>
          <InputText v-model.trim="nuevoProveedor.nombre" required autofocus />
        </div>
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-bold text-slate-500 uppercase">Teléfono</label>
          <InputText v-model.trim="nuevoProveedor.telefono" />
        </div>
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-bold text-slate-500 uppercase">Dirección</label>
          <Textarea v-model="nuevoProveedor.direccion" rows="3" class="resize-none" />
        </div>
      </div>
      <template #footer>
        <div class="flex justify-end gap-2 border-t pt-4 mt-2">
           <Button label="Cancelar" text severity="secondary" @click="proveedorModal = false" />
           <Button label="Guardar Proveedor" severity="primary" @click="onProveedorSubmit" :loading="guardandoProveedor" />
        </div>
      </template>
    </Dialog>
  </div>
</template>

<style scoped>
@reference "tailwindcss";

:deep(.p-dropdown), :deep(.p-autocomplete), :deep(.p-inputtext), :deep(.p-calendar), :deep(.p-inputnumber) {
  @apply rounded-lg border-slate-200 shadow-none hover:border-blue-400 focus:border-blue-500 transition-all;
}

:deep(.p-dropdown-label), :deep(.p-inputtext) {
  @apply py-2;
}

:deep(.p-datatable-thead > tr > th) {
  text-transform: uppercase;
  letter-spacing: 0.1em;
  font-weight: 800;
  font-size: 9px;
  color: #94a3b8;
  padding: 14px 16px;
  background-color: #f8fafc;
  border-bottom: 1px solid #f1f5f9;
}

:deep(.p-datatable-tbody > tr > td) {
  padding: 12px 16px;
  border-bottom: 1px solid #f8fafc;
}

:deep(.cart-qty .p-inputnumber-input) {
  padding: 4px 6px;
  font-weight: 700;
}
:deep(.cart-qty .p-inputnumber-button) {
  width: 1.5rem;
}
:deep(.cart-cost .p-inputnumber-input) {
  padding: 4px 8px;
  color: #64748b;
  font-size: 0.8125rem;
}
</style>
