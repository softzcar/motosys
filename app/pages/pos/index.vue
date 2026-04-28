<script setup lang="ts">
import { User, Search, ShoppingCart, CreditCard, Banknote, Plus, Trash2, CheckCircle2, RotateCcw, X, Loader2 } from 'lucide-vue-next'
import { useTasas } from '~/composables/useTasas'
import { useMetodosPago } from '~/composables/useMetodosPago'
import { useOfflineDb, db } from '~/composables/useOfflineDb'
import { useNetworkStore } from '~/stores/network'

const cart = useCartStore()
const { perfil } = usePerfil() // INYECTAR PERFIL
const { procesarVenta } = useVentas()
const { fetchVentaById, fetchProductos } = useProductos()
const { getClienteByCedula, crearCliente, fetchClientes } = useClientes()
const { isOnline, cacheProductos, cacheClientes, cacheTasas, cacheMetodos, registrarVentaOffline } = useOfflineDb()
const networkStore = useNetworkStore()
const toast = useToast()
const confirm = useConfirm()
const route = useRoute()
const router = useRouter()
const { syncBcvRate, fetchTasas } = useTasas()
const { fetchMetodosPago } = useMetodosPago()
const client = useSupabaseClient()

const procesando = ref(false)
const lastVentaId = ref<string | null>(null)
const activeTab = ref<'search' | 'cart'>('search')

// Corrección de venta anulada
const ventaOrigen = ref<any>(null)
const corrigeVentaId = ref<string | null>(null)
const cargandoOrigen = ref(false)
const openingCheckout = ref(false)

const cargarPrefillDesde = async (id: string) => {
  cargandoOrigen.value = true
  try {
    const data = await fetchVentaById(id)
    if (!data.anulada) {
      toast.add({ severity: 'warn', summary: 'No se puede corregir', detail: 'La venta origen no está anulada', life: 4000 })
      return
    }
    
    ventaOrigen.value = data
    corrigeVentaId.value = id
    
    // Llenar el carrito
    cart.clear()
    data.detalle_ventas?.forEach((d: any) => {
      cart.addItem({
        ...d.productos,
        precio_venta: Number(d.precio_unitario)
      }, d.cantidad)
    })

    toast.add({ severity: 'info', summary: 'Datos prellenados', detail: `Corrigiendo venta anulada #${data.numero}`, life: 5000 })
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'No se pudo cargar la venta', detail: e.message ?? 'Error desconocido', life: 4000 })
  } finally {
    cargandoOrigen.value = false
  }
}

const cancelarCorreccion = () => {
  ventaOrigen.value = null
  corrigeVentaId.value = null
  cart.clear()
  router.replace('/pos')
}

const handleGlobalKeys = (e: KeyboardEvent) => {
  if (e.key === 'F3' && cart.itemCount > 0 && !isClientDialogVisible.value && !isCheckoutDialogVisible.value) {
    e.preventDefault()
    handleCheckout()
  }
}

onMounted(() => {
  window.addEventListener('keydown', handleGlobalKeys)
  
  const fromId = route.query.from
  if (typeof fromId === 'string' && fromId) {
    cargarPrefillDesde(fromId)
  }
})

onUnmounted(() => {
  window.removeEventListener('keydown', handleGlobalKeys)
})

// Datos Maestros
const tasas = ref<any[]>([])
const metodos = ref<any[]>([])

// Client Dialog State
const isClientDialogVisible = ref(false)
const searchingClient = ref(false)
const clientFound = ref<any>(null)
const clientForm = ref({
  cedula: '',
  nombre: '',
  telefono: ''
})

const isCheckoutDialogVisible = ref(false)
const selectedTasaCodigo = ref('BCV')
const currentTasaValue = computed(() => {
    return tasas.value.find(t => t.codigo === selectedTasaCodigo.value)?.tasa || 1
})
const copTasaValue = computed(() => {
    return tasas.value.find(t => t.codigo === 'COP')?.tasa || 1
})

const pagos = ref<any[]>([])
const selectedMetodoId = ref(null)
const montoAbono = ref(0)
const referenciaAbono = ref('')

const selectedMetodo = computed(() => {
    if (!selectedMetodoId.value) return null
    return metodos.value.find(m => m.id === selectedMetodoId.value) || null
})

const requiereReferencia = computed(() => !!selectedMetodo.value?.requiere_detalle)

const totalPagadoUsd = computed(() => {
    return pagos.value.reduce((acc, p) => acc + p.monto_usd, 0)
})

const montoAbonoEnUsd = computed(() => {
    if (!selectedMetodoId.value || montoAbono.value <= 0) return 0
    const metodo = metodos.value.find(m => m.id === selectedMetodoId.value)
    if (!metodo) return 0
    if (metodo.moneda === 'USD') return montoAbono.value
    const tasa = metodo.moneda === 'COP' ? copTasaValue.value : currentTasaValue.value
    return montoAbono.value / tasa
})

const faltanteUsd = computed(() => {
    const diff = cart.total - totalPagadoUsd.value
    return diff > 0 ? diff : 0
})

const vueltoUsd = computed(() => {
    const diff = totalPagadoUsd.value - cart.total
    return diff > 0 ? diff : 0
})

const faltanteVisualUsd = computed(() => {
    const diff = cart.total - totalPagadoUsd.value - montoAbonoEnUsd.value
    return diff > 0 ? diff : 0
})

const vueltoVisualUsd = computed(() => {
    const diff = (totalPagadoUsd.value + montoAbonoEnUsd.value) - cart.total
    return diff > 0 ? diff : 0
})

const canFinish = computed(() => {
    return faltanteUsd.value <= 0.01 && cart.itemCount > 0
})

watch(isClientDialogVisible, (val) => {
  if (val) {
    for (let i = 1; i <= 5; i++) {
      setTimeout(() => {
        const el = document.getElementById('cedulaInput')
        if (el) el.focus()
      }, i * 100)
    }
  }
})

const handleCheckout = async () => {
  if (openingCheckout.value) return
  openingCheckout.value = true
  
  try {
    clientForm.value = { cedula: '', nombre: '', telefono: '' }
    clientFound.value = null
    isClientDialogVisible.value = true
    await syncBcvRate()
  } catch (e) {
    console.error('Error sincronizando tasa:', e)
  } finally {
    openingCheckout.value = false
  }
}

const resetCliente = () => {
  clientForm.value = { cedula: '', nombre: '', telefono: '' }
  clientFound.value = null
  searchingClient.value = false
  setTimeout(() => {
    const el = document.getElementById('cedulaInput')
    el?.focus()
  }, 100)
}

const cedulaInput = ref<HTMLInputElement | null>(null)
const nombreInput = ref<HTMLInputElement | null>(null)
const continuarPagoBtn = ref<any>(null)

const buscarCliente = async () => {
  const cedula = clientForm.value.cedula.trim()
  if (!cedula) return

  searchingClient.value = true
  try {
    let existing = null
    if (networkStore.isOnline) {
      existing = await getClienteByCedula(cedula)
    } else {
      existing = await db.clientes.where('cedula').equals(cedula).first()
    }

    if (existing) {
      clientFound.value = existing
      clientForm.value.nombre = existing.nombre
      clientForm.value.telefono = existing.telefono || ''
      toast.add({ severity: 'info', summary: 'Cliente encontrado', life: 2000 })
      
      // FORZAR FOCO AL BOTÓN DE PAGO
      setTimeout(() => {
        const btn = document.getElementById('continuarPagoBtn')
        btn?.focus()
      }, 100)
    } else {
      clientFound.value = false 
      clientForm.value.nombre = ''
      clientForm.value.telefono = ''
      const msg = networkStore.isOnline ? 'Cliente nuevo' : 'Cliente no encontrado localmente'
      toast.add({ severity: 'info', summary: msg, detail: 'Complete los datos para registrarlo', life: 3000 })
      
      // FOCO AL NOMBRE PARA REGISTRO
      setTimeout(() => {
        const input = document.getElementById('nombreInput')
        input?.focus()
      }, 100)
    }
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error buscando cliente', detail: e.message, life: 3000 })
  } finally {
    searchingClient.value = false
  }
}

const proceedToPayment = async () => {
  // Si el usuario presiona "Continuar a Pago" sin haber buscado la cédula previamente (clientFound === null)
  if (clientFound.value === null && clientForm.value.cedula.trim()) {
    await buscarCliente()
    // Si después de buscar se encontró al cliente, detenemos para que el usuario verifique
    if (clientFound.value) {
      toast.add({ severity: 'success', summary: 'Cliente verificado', detail: 'Revise el nombre y presione continuar de nuevo.', life: 3000 })
      return 
    }
    // Si NO se encontró, buscarCliente ya muestra el toast de "Cliente nuevo" y pone foco en nombre, así que paramos
    return
  }

  if (!clientForm.value.cedula || !clientForm.value.nombre) {
    toast.add({ severity: 'warn', summary: 'Faltan datos', detail: 'La cédula y el nombre son obligatorios', life: 3000 })
    return
  }

  isClientDialogVisible.value = false
  
  try {
      if (networkStore.isOnline) {
        tasas.value = await fetchTasas()
        metodos.value = (await fetchMetodosPago()).filter(m => m.activo)
      } else {
        tasas.value = await db.tasas.toArray()
        metodos.value = await db.metodos_pago.toArray()
      }
      
      if (metodos.value.length === 0) {
        toast.add({ severity: 'error', summary: 'Sin configuración', detail: 'No hay métodos de pago disponibles offline', life: 5000 })
        return
      }

      pagos.value = []
      selectedMetodoId.value = null
      montoAbono.value = 0
      referenciaAbono.value = ''
      selectedTasaCodigo.value = 'BCV'
      isCheckoutDialogVisible.value = true
  } catch (e: any) {
      toast.add({ severity: 'error', summary: 'Error de carga', detail: 'No se pudieron cargar los datos de pago', life: 3000 })
  }
}

const agregarPago = () => {
    if (!selectedMetodoId.value) {
        toast.add({ severity: 'warn', summary: 'Atención', detail: 'Debe seleccionar un método de pago', life: 3000 })
        return
    }
    if (Number(montoAbono.value) <= 0) {
        toast.add({ severity: 'warn', summary: 'Atención', detail: 'El monto debe ser mayor a cero', life: 3000 })
        return
    }

    const metodo = metodos.value.find(m => m.id === selectedMetodoId.value)
    if (!metodo) return

    // VALIDACIÓN: Evitar duplicados del mismo método de pago
    const yaExiste = pagos.value.some(p => p.metodo_pago_id === metodo.id)
    if (yaExiste) {
        toast.add({ 
            severity: 'warn', 
            summary: 'Método duplicado', 
            detail: `Ya has añadido un pago con ${metodo.nombre}. Elimina el anterior si deseas cambiar el monto.`, 
            life: 4000 
        })
        return
    }

    const referenciaTrim = referenciaAbono.value.trim()
    if (metodo.requiere_detalle && !referenciaTrim) {
        toast.add({ severity: 'warn', summary: 'Referencia requerida', detail: `${metodo.nombre} requiere número de referencia`, life: 3000 })
        return
    }

    let montoUsd = 0
    let tasaUsada = 1

    if (metodo.moneda === 'USD') {
        montoUsd = montoAbono.value
        tasaUsada = 1
    } else if (metodo.moneda === 'COP') {
        montoUsd = montoAbono.value / copTasaValue.value
        tasaUsada = copTasaValue.value
    } else {
        montoUsd = montoAbono.value / currentTasaValue.value
        tasaUsada = currentTasaValue.value
    }

    pagos.value.push({
        metodo_pago_id: metodo.id,
        nombre: metodo.nombre,
        moneda: metodo.moneda,
        monto_recibido: montoAbono.value,
        tasa_aplicada: tasaUsada,
        monto_usd: montoUsd,
        referencia: referenciaTrim || null
    })

    montoAbono.value = 0
    referenciaAbono.value = ''
    selectedMetodoId.value = null // Limpiar selector para evitar confusión
}

const eliminarPago = (index: number) => {
    pagos.value.splice(index, 1)
}

const finalizarVenta = async () => {
    procesando.value = true
    try {
        let clientId = null

        if (networkStore.isOnline) {
          if (clientFound.value === false || clientFound.value === null) {
            try {
              const newClient = await crearCliente({
                cedula: clientForm.value.cedula,
                nombre: clientForm.value.nombre,
                telefono: clientForm.value.telefono
              })
              clientId = newClient.id
            } catch(err: any) {
               if (err.code !== '23505') throw err;
               const existing = await getClienteByCedula(clientForm.value.cedula)
               clientId = existing?.id
            }
          } else {
            clientId = clientFound.value.id
          }
        } else {
          clientId = clientFound.value?.id || null
        }

        const items = cart.toRpcPayload()
        const payloadPagos = pagos.value.map(p => ({
            metodo_pago_id: p.metodo_pago_id,
            monto_recibido: p.monto_recibido,
            tasa_aplicada: p.tasa_aplicada,
            monto_usd: p.monto_usd,
            referencia: p.referencia ?? null
        }))

        let ventaId = null
        let numFactura = '---'

        if (networkStore.isOnline) {
          // --- MODO ONLINE: Supabase ---
          const vendedorId = perfil.value?.id
          if (!vendedorId) throw new Error('Sesión de vendedor no detectada. Por favor, refresque la página.')

          ventaId = await procesarVenta(
            items, 
            payloadPagos, 
            clientId!, 
            corrigeVentaId.value ?? undefined,
            vendedorId
          )
  const { data: nuevaVenta } = await client.from('ventas').select('numero').eq('id', ventaId).single()
          numFactura = nuevaVenta?.numero ?? '---'
          lastVentaId.value = ventaId
        } else {
          const idTemporal = await registrarVentaOffline({
            items,
            pagos: payloadPagos,
            cliente_id: clientId || undefined,
            client_data: !clientId ? { ...clientForm.value } : null,
            fecha: new Date().toISOString(),
            total: cart.total
          })
          ventaId = idTemporal
          numFactura = `OFFLINE`
        }

        cart.clear()
        isCheckoutDialogVisible.value = false
        clientForm.value = { cedula: '', nombre: '', telefono: '' }
        clientFound.value = null
        pagos.value = []
        selectedMetodoId.value = null
        montoAbono.value = 0
        referenciaAbono.value = ''
        activeTab.value = 'search'

        const fueCorreccion = !!corrigeVentaId.value
        ventaOrigen.value = null
        corrigeVentaId.value = null
        if (fueCorreccion) router.replace('/pos')

        toast.add({
          severity: networkStore.isOnline ? 'success' : 'info',
          summary: networkStore.isOnline ? (fueCorreccion ? 'Corrección registrada' : 'Venta Procesada') : 'Venta Guardada Offline',
          detail: networkStore.isOnline 
            ? (fueCorreccion ? `La factura #${numFactura} quedó enlazada.` : `Factura #${numFactura} registrada con éxito.`)
            : `Venta guardada localmente. Se sincronizará al recuperar conexión.`,
          life: 5000
        })

      } catch (e: any) {
        toast.add({ severity: 'error', summary: 'Error al procesar', detail: e.message || 'Error desconocido', life: 5000 })
      } finally {
        procesando.value = false
      }
}

const setMontoAbono = (val: number) => {
    montoAbono.value = Number(val.toFixed(2))
}

const formatCurrency = (val: number) => {
    return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(val)
}
const handleHistoryClick = () => {
  if (!networkStore.isOnline) {
    toast.add({
      severity: 'warn',
      summary: 'Acceso No Disponible',
      detail: 'El historial requiere conexión a internet.',
      life: 3000
    })
    return
  }
  router.push('/reportes/ventas')
}
</script>

<template>
  <div class="p-4 md:p-6 bg-slate-50 min-h-screen flex flex-col gap-4">
    <!-- Header de Acciones Rápidas -->
    <div class="hidden lg:flex items-center justify-end">
        <Button 
          label="Historial de Ventas" 
          icon="pi pi-history" 
          severity="success" 
          variant="text"
          size="small" 
          class="font-bold text-xs uppercase tracking-wider" 
          @click="handleHistoryClick"
        />
    </div>

    <div v-if="ventaOrigen" class="mb-0 bg-amber-50 border border-amber-200 rounded-lg p-3 flex items-center justify-between shadow-sm">
        <div class="flex items-center gap-3">
            <RotateCcw class="text-amber-600 animate-spin-slow" :size="20" />
            <div>
                <p class="text-xs font-bold text-amber-800 uppercase tracking-wider">Corrigiendo venta anulada #{{ ventaOrigen.numero }}</p>
                <p class="text-[10px] text-amber-600">Al procesar esta factura, se marcará como reemplazo de la anterior.</p>
            </div>
        </div>
        <Button severity="secondary" text size="small" label="Cancelar corrección" @click="cancelarCorreccion" />
    </div>

    <div v-if="cargandoOrigen" class="mb-4 bg-slate-50 border border-slate-200 rounded-lg p-6 flex flex-col items-center justify-center gap-2">
        <Loader2 class="animate-spin text-blue-500" :size="24" />
        <span class="text-xs text-slate-500 font-medium">Recuperando datos de venta...</span>
    </div>

    <div class="pos-grid flex-1 overflow-hidden relative">
      <div class="lg:hidden flex mb-4 bg-slate-100 p-1 rounded-xl">
        <button 
          @click="activeTab = 'search'" 
          class="flex-1 py-2 rounded-lg text-sm font-bold transition-all flex items-center justify-center gap-2"
          :class="activeTab === 'search' ? 'bg-white shadow-sm text-blue-600' : 'text-slate-500'"
        >
          <Search :size="16" /> Buscar
        </button>
        <button 
          @click="activeTab = 'cart'" 
          class="flex-1 py-2 rounded-lg text-sm font-bold transition-all flex items-center justify-center gap-2 relative"
          :class="activeTab === 'cart' ? 'bg-white shadow-sm text-blue-600' : 'text-slate-500'"
        >
          <ShoppingCart :size="16" /> Carrito
          <span v-if="cart.itemCount > 0" class="absolute -top-1 -right-1 flex h-4 w-4 items-center justify-center rounded-full bg-red-500 text-[10px] text-white font-bold">
            {{ cart.itemCount }}
          </span>
        </button>
      </div>

      <div :class="{'hidden lg:block': activeTab !== 'search'}" class="h-full overflow-hidden">
        <PosProductSearch />
      </div>
      <div :class="{'hidden lg:block': activeTab !== 'cart'}" class="h-full overflow-hidden">
        <PosCart :disabled="isClientDialogVisible" @checkout="handleCheckout" />
      </div>
    </div>

    <Dialog 
      v-model:visible="isClientDialogVisible" 
      header="Información del Cliente" 
      modal 
      class="w-full max-w-md"
      :focusOnShow="false"
      :blockScroll="true"
    >
      <div class="space-y-4 pt-4">
        <div class="bg-blue-50 p-3 rounded-lg flex gap-3 text-sm text-blue-800 mb-4">
          <User class="w-5 h-5 shrink-0" />
          <p>Ingrese la cédula para buscar al cliente. Si no existe, se registrará automáticamente al procesar la venta.</p>
        </div>

        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Cédula</label>
          <div class="relative">
            <input 
              id="cedulaInput"
              v-model="clientForm.cedula" 
              @keyup.enter="buscarCliente"
              type="text" 
              placeholder="Ej. 12345678"
              tabindex="1"
              class="w-full pl-3 pr-10 py-2 border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 transition-opacity"
              :disabled="clientFound !== null || searchingClient"
              :class="clientFound !== null ? 'opacity-60 bg-slate-50' : ''"
            />
            <button @click="buscarCliente" type="button" class="absolute right-2 top-1/2 -translate-y-1/2 p-1 text-slate-400 hover:text-blue-600 transition" :disabled="searchingClient || clientFound !== null">
              <span v-if="searchingClient" class="w-4 h-4 border-2 border-slate-300 border-t-blue-600 rounded-full animate-spin inline-block"></span>
              <Search v-else class="w-4 h-4" />
            </button>
          </div>
        </div>

        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Nombre y Apellido</label>
          <input 
            id="nombreInput" 
            v-model="clientForm.nombre" 
            type="text" 
            tabindex="2"
            class="w-full px-3 py-2 border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors" 
            :class="clientFound !== false ? 'bg-slate-50 text-slate-600' : ''" 
            :disabled="clientFound !== false" 
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1">Teléfono</label>
          <input 
            id="telefonoInput"
            v-model="clientForm.telefono" 
            type="text" 
            tabindex="3"
            class="w-full px-3 py-2 border border-slate-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors" 
            :class="clientFound !== false ? 'bg-slate-50 text-slate-600' : ''" 
            :disabled="clientFound !== false" 
          />
        </div>
      </div>
      
      <template #footer>
        <div class="flex justify-end gap-2 mt-4 w-full">
          <button @click="resetCliente" type="button" tabindex="5" class="mr-auto px-4 py-2 text-blue-600 hover:bg-blue-50 rounded-lg transition flex items-center gap-2 font-bold text-xs uppercase">
            <RotateCcw :size="14" /> Limpiar / Nuevo
          </button>
          <button @click="isClientDialogVisible = false" tabindex="6" class="px-4 py-2 text-slate-600 hover:bg-slate-100 rounded-lg transition text-sm">Volver</button>
          <button 
            id="continuarPagoBtn"
            @click="proceedToPayment" 
            tabindex="4"
            class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition flex items-center gap-2 text-sm font-bold shadow-md"
          >
            Continuar a Pago
          </button>
        </div>
      </template>
    </Dialog>

    <Dialog v-model:visible="isCheckoutDialogVisible" header="Finalizar Cobro" modal class="w-full max-w-2xl" :closable="!procesando">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 pt-4">
            <div class="flex flex-col gap-4">
                <div class="p-4 bg-slate-50 rounded-xl border border-slate-200">
                    <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-2">Total a cobrar</p>
                    <div class="flex items-end gap-2">
                        <span class="text-3xl font-black text-slate-800">{{ formatCurrency(cart.total) }}</span>
                        <span class="text-sm font-bold text-slate-400 mb-1">USD</span>
                    </div>
                    <div class="mt-4 pt-4 border-t border-slate-200">
                        <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-3">Tasa de cambio operativa</p>
                        <SelectButton v-model="selectedTasaCodigo" :options="['BCV', 'PARALELO']" class="w-full" />
                        <div class="flex justify-between items-center mt-3 px-1">
                            <span class="text-xs font-bold text-slate-500">Valor Tasa:</span>
                            <span class="text-sm font-black text-blue-600">{{ currentTasaValue.toFixed(2) }} Bs/$</span>
                        </div>
                        <div class="mt-2 p-3 bg-blue-50/50 rounded-lg flex justify-between items-center cursor-pointer hover:bg-blue-100/50 transition-colors group" @click="setMontoAbono(cart.total * currentTasaValue)">
                            <span class="text-xs font-bold text-blue-700 group-hover:underline">Total en Bs:</span>
                            <span class="text-lg font-black text-blue-800">{{ (cart.total * currentTasaValue).toLocaleString('es') }} Bs</span>
                        </div>
                    </div>
                </div>

                <div class="flex flex-col gap-3">
                    <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest px-1">Registrar Pago</p>
                    <div class="flex flex-col gap-2">
                        <Select v-model="selectedMetodoId" :options="metodos" optionLabel="nombre" optionValue="id" placeholder="Seleccione Método" class="w-full" />
                        <InputText v-if="requiereReferencia" v-model="referenciaAbono" placeholder="Número de referencia" class="w-full border-blue-500 ring-1 ring-blue-500/20 bg-blue-50/10" />
                        <div class="flex gap-2">
                            <InputNumber :model-value="montoAbono" @input="(e) => montoAbono = e.value ?? 0" mode="decimal" :minFractionDigits="2" placeholder="Monto" class="flex-1" :disabled="!selectedMetodoId" @focus="$event => ($event.target as HTMLInputElement).select()" />
                            <Button @click="agregarPago" severity="success" class="aspect-square !p-0 flex items-center justify-center" :disabled="!selectedMetodoId"><Plus class="w-5 h-5" /></Button>
                        </div>
                    </div>
                </div>
            </div>

            <div class="flex flex-col gap-4">
                <div class="flex-1 border border-slate-200 rounded-xl overflow-hidden flex flex-col bg-white">
                    <div class="p-3 bg-slate-50 border-b border-slate-200 flex items-center gap-2">
                        <CreditCard class="w-4 h-4 text-slate-400" />
                        <span class="text-xs font-bold text-slate-600 uppercase">Resumen</span>
                    </div>
                    <div class="flex-1 overflow-auto max-h-[220px]">
                        <table class="w-full text-xs">
                            <thead class="bg-slate-50 text-slate-400 font-bold sticky top-0">
                                <tr>
                                    <th class="p-2 text-left">Método</th>
                                    <th class="p-2 text-right">Monto</th>
                                    <th class="p-3 text-center w-10"></th>
                                </tr>
                            </thead>
                            <tbody>
                                <tr v-for="(pago, i) in pagos" :key="i" class="border-b border-slate-100">
                                    <td class="p-2 font-bold text-slate-700">{{ pago.nombre }}</td>
                                    <td class="p-2 text-right">
                                        <div class="font-bold">{{ (pago.monto_recibido || 0).toLocaleString() }} {{ pago.moneda }}</div>
                                        <div class="text-[9px] text-slate-400">($ {{ (pago.monto_usd || 0).toFixed(2) }})</div>
                                    </td>
                                    <td class="p-2 text-center text-red-400 hover:text-red-600 cursor-pointer" @click="eliminarPago(i)"><Trash2 class="w-3.5 h-3.5 mx-auto" /></td>
                                </tr>
                                <tr v-if="pagos.length === 0"><td colspan="3" class="p-10 text-center text-slate-400 italic">No hay pagos registrados</td></tr>
                            </tbody>
                        </table>
                    </div>
                    <div class="p-4 bg-slate-50 border-t border-slate-200 space-y-2">
                        <div class="flex justify-between items-center text-sm">
                            <span class="font-bold text-slate-500">Recibido:</span>
                            <span class="font-black text-slate-800">{{ formatCurrency(totalPagadoUsd) }}</span>
                        </div>
                        <div v-if="faltanteVisualUsd > 0" class="flex flex-col p-2 bg-orange-50 rounded border border-orange-100 transition-colors" :class="{'ring-2 ring-orange-400': montoAbono > 0}">
                            <div class="flex justify-between items-center">
                                <span class="text-xs font-bold text-orange-600">PENDIENTE:</span>
                                <span class="text-sm font-black text-orange-700">{{ formatCurrency(faltanteVisualUsd) }}</span>
                            </div>
                            <div class="flex justify-end gap-4 mt-1.5 pt-1.5 border-t border-orange-200">
                                <span 
                                    class="text-xs font-bold text-orange-600 cursor-pointer hover:underline" 
                                    @click="setMontoAbono(faltanteVisualUsd * currentTasaValue)"
                                >
                                    {{ (faltanteVisualUsd * currentTasaValue).toLocaleString('es', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }} Bs
                                </span>
                                <span 
                                    class="text-xs font-bold text-orange-600 cursor-pointer hover:underline" 
                                    @click="setMontoAbono(faltanteVisualUsd * copTasaValue)"
                                >
                                    {{ (faltanteVisualUsd * copTasaValue).toLocaleString('es', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }} COP
                                </span>
                            </div>
                        </div>
                        <div v-else-if="vueltoVisualUsd > 0" class="flex flex-col p-2 bg-green-50 rounded border border-green-100 transition-colors" :class="{'ring-2 ring-green-400': montoAbono > 0 && faltanteUsd > 0}">
                            <div class="flex justify-between items-center">
                                <span class="text-xs font-bold text-green-600">VUELTO / CAMBIO:</span>
                                <span class="text-sm font-black text-green-700">{{ formatCurrency(vueltoVisualUsd) }}</span>
                            </div>
                            <div class="flex justify-end gap-4 mt-1.5 pt-1.5 border-t border-green-200">
                                <span 
                                    class="text-xs font-bold text-green-700 cursor-pointer hover:underline" 
                                    @click="setMontoAbono(vueltoVisualUsd * currentTasaValue)"
                                >
                                    {{ (vueltoVisualUsd * currentTasaValue).toLocaleString('es', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }} Bs
                                </span>
                                <span 
                                    class="text-xs font-bold text-green-700 cursor-pointer hover:underline" 
                                    @click="setMontoAbono(vueltoVisualUsd * copTasaValue)"
                                >
                                    {{ (vueltoVisualUsd * copTasaValue).toLocaleString('es', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }} COP
                                </span>
                            </div>
                        </div>
                        <div v-else-if="canFinish || (faltanteVisualUsd === 0 && cart.itemCount > 0)" class="flex justify-center p-2 bg-green-100 rounded border border-green-200 transition-colors" :class="{'ring-2 ring-green-500': montoAbono > 0 && faltanteUsd > 0}">
                             <span class="text-xs font-black text-green-700 flex items-center gap-2">
                                 <CheckCircle2 class="w-4 h-4" /> {{ canFinish ? 'PAGO COMPLETADO' : 'MONTO EXACTO ALCANZADO' }}
                             </span>
                        </div>
                    </div>
                </div>
                <Button @click="finalizarVenta" :disabled="!canFinish || procesando" :loading="procesando" class="h-14 font-black text-lg" :severity="canFinish ? 'success' : 'secondary'" label="PROCESAR FACTURA" />
            </div>
        </div>
    </Dialog>
  </div>
</template>
