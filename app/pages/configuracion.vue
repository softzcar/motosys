<script setup lang="ts">
import { Store, Save, Loader2, Building, CreditCard, Plus, Pencil, Trash2, Check, X, Banknote, RefreshCw } from 'lucide-vue-next'
import { useMetodosPago } from '~/composables/useMetodosPago'
import { useTasas, type TasaCambio } from '~/composables/useTasas'
import { useConfirm } from 'primevue/useconfirm'

const supabase = useSupabaseClient()
const { isAdmin, perfil } = usePerfil()
const toast = useToast()
const confirm = useConfirm()

// Redirección de seguridad al estilo del proyecto
watch(perfil, (p) => {
  if (p && p.rol !== 'admin') navigateTo('/')
}, { immediate: true })

const loading = ref(true)
const saving = ref(false)

const empresa = ref({
  id: '',
  nombre: 'Motorepuestos Accesorios y Lubricantes Parra',
  rif: '',
  direccion: '',
  whatsapp: '',
  instagram: '',
  sitio_web: '',
  iva: 16
})

const fetchEmpresa = async () => {
  loading.value = true
  try {
    const { data } = await supabase.from('empresa').select('*').limit(1).single()
    if (data) empresa.value = { ...empresa.value, ...data }
  } catch (e) {
    console.error('Error fetching empresa:', e)
  } finally {
    loading.value = false
  }
}

const saveEmpresa = async () => {
  if (!isAdmin.value) return
  saving.value = true
  
  try {
    const { error } = await supabase
      .from('empresa')
      .update({
        rif: empresa.value.rif,
        direccion: empresa.value.direccion,
        whatsapp: empresa.value.whatsapp,
        instagram: empresa.value.instagram,
        sitio_web: empresa.value.sitio_web,
        iva: empresa.value.iva,
        updated_at: new Date()
      })
      .eq('id', empresa.value.id)

    if (error) throw error
    toast.add({ severity: 'success', summary: 'Éxito', detail: 'Configuración guardada', life: 3000 })
  } catch (error) {
    toast.add({ severity: 'error', summary: 'Error', detail: 'No se pudo guardar', life: 3000 })
  } finally {
    saving.value = false
  }
}

// Métodos de Pago
const { fetchMetodosPago, createMetodoPago, updateMetodoPago, deleteMetodoPago } = useMetodosPago()
const metodos = ref<any[]>([])
const loadingMetodos = ref(false)

const metodoDialog = ref(false)
const modalMetodoTitle = ref('Nuevo Método de Pago')
const savingMetodo = ref(false)
const formMetodo = ref({ id: '', nombre: '', moneda: 'Bs', activo: true, requiere_detalle: false })

const loadMetodos = async () => {
  loadingMetodos.value = true
  try {
    metodos.value = await fetchMetodosPago()
  } catch (error: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: error.message, life: 3000 })
  } finally {
    loadingMetodos.value = false
  }
}

const openNewMetodo = () => {
  formMetodo.value = { id: '', nombre: '', moneda: 'Bs', activo: true, requiere_detalle: false }
  modalMetodoTitle.value = 'Nuevo Método de Pago'
  metodoDialog.value = true
}

const editMetodo = (m: any) => {
  formMetodo.value = { ...m }
  modalMetodoTitle.value = 'Editar Método de Pago'
  metodoDialog.value = true
}

const saveMetodo = async () => {
  if (!formMetodo.value.nombre.trim()) {
      toast.add({ severity: 'warn', summary: 'Advertencia', detail: 'El nombre es obligatorio', life: 3000 })
      return
  }
  savingMetodo.value = true
  try {
    if (formMetodo.value.id) {
      await updateMetodoPago(formMetodo.value.id, {
        nombre: formMetodo.value.nombre,
        moneda: formMetodo.value.moneda,
        activo: formMetodo.value.activo,
        requiere_detalle: formMetodo.value.requiere_detalle
      })
      toast.add({ severity: 'success', summary: 'Éxito', detail: 'Método actualizado', life: 3000 })
    } else {
      await createMetodoPago({
        nombre: formMetodo.value.nombre,
        moneda: formMetodo.value.moneda,
        activo: formMetodo.value.activo,
        requiere_detalle: formMetodo.value.requiere_detalle
      })
      toast.add({ severity: 'success', summary: 'Éxito', detail: 'Método creado', life: 3000 })
    }
    metodoDialog.value = false
    loadMetodos()
  } catch (error: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: error.message, life: 3000 })
  } finally {
    savingMetodo.value = false
  }
}

const toggleMetodoStatus = async (m: any) => {
  try {
     await updateMetodoPago(m.id, { activo: m.activo })
     toast.add({ severity: 'success', summary: 'Éxito', detail: `Método ${m.activo ? 'activado' : 'desactivado'}`, life: 3000 })
  } catch (error: any) {
     m.activo = !m.activo // revert on failure
     toast.add({ severity: 'error', summary: 'Error', detail: error.message, life: 3000 })
  }
}

const deleteMetodo = (m: any) => {
  confirm.require({
    message: `¿Estás seguro de eliminar el método "${m.nombre}"? Esta acción no se puede deshacer.`,
    header: 'Confirmar Eliminación',
    icon: 'pi pi-exclamation-triangle',
    rejectLabel: 'Cancelar',
    acceptLabel: 'Eliminar',
    rejectClass: 'p-button-secondary p-button-outlined',
    acceptClass: 'p-button-danger',
    accept: async () => {
      try {
        await deleteMetodoPago(m.id)
        toast.add({ severity: 'success', summary: 'Éxito', detail: 'Método eliminado correctamente', life: 3000 })
        loadMetodos()
      } catch (error: any) {
        if (error.code === '23503') {
           toast.add({ severity: 'error', summary: 'Error', detail: 'No se puede eliminar porque ya tiene transacciones asociadas. Te sugerimos desactivarlo.', life: 5000 })
        } else {
           toast.add({ severity: 'error', summary: 'Error', detail: error.message, life: 3000 })
        }
      }
    }
  })
}

// Tasas de Cambio
const { fetchTasas, syncBcvRate, updateTasa } = useTasas()
const tasas = ref<TasaCambio[]>([])
const loadingTasas = ref(false)
const syncingTasa = ref(false)
const savingTasas = ref(false)

const loadTasas = async () => {
    loadingTasas.value = true
    try {
        tasas.value = await fetchTasas()
    } catch (error: any) {
        toast.add({ severity: 'error', summary: 'Error', detail: error.message, life: 3000 })
    } finally {
        loadingTasas.value = false
    }
}

const executeSyncBcv = async () => {
    syncingTasa.value = true
    try {
        await syncBcvRate()
        toast.add({ severity: 'success', summary: 'Actualizado', detail: 'Tasa BCV obtenida exitosamente.', life: 3000 })
        await loadTasas()
    } catch (e) {
        toast.add({ severity: 'error', summary: 'Error', detail: 'Fallo al conectar con la API del Dólar Oficial.', life: 3000 })
    } finally {
        syncingTasa.value = false
    }
}

const saveManualRates = async () => {
    savingTasas.value = true
    try {
        const manualRates = tasas.value.filter(t => !t.is_auto)
        for (const rate of manualRates) {
            await updateTasa(rate.codigo, Number(rate.tasa))
        }
        toast.add({ severity: 'success', summary: 'Éxito', detail: 'Tasas manuales actualizadas correctamente', life: 3000 })
        await loadTasas()
    } catch (e: any) {
        toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 3000 })
    } finally {
        savingTasas.value = false
    }
}

onMounted(() => {
    fetchEmpresa()
    loadMetodos()
    loadTasas()
})
</script>

<template>
  <div v-if="isAdmin">
    <div class="flex items-center gap-3 mb-6">
      <div class="p-2 bg-blue-100 text-blue-600 rounded-lg">
        <Store :size="24" />
      </div>
      <div>
        <h1 class="text-2xl font-bold text-slate-800">Configuración</h1>
        <p class="text-slate-500">Administra los datos públicos y legales de la empresa y flujos de caja.</p>
      </div>
    </div>

    <div v-if="loading" class="flex justify-center p-20">
      <Loader2 class="animate-spin text-blue-500" :size="32" />
    </div>

    <div v-else class="flex flex-col gap-6">
      <Tabs value="empresa">
        <TabList class="mb-4">
          <Tab value="empresa">
            <div class="flex items-center gap-2 font-medium">
               <Building class="w-4 h-4" /> Datos Empresariales
            </div>
          </Tab>
          <Tab value="tasas">
            <div class="flex items-center gap-2 font-medium">
               <Banknote class="w-4 h-4" /> Tasas de Cambio
            </div>
          </Tab>
          <Tab value="metodos">
            <div class="flex items-center gap-2 font-medium">
               <CreditCard class="w-4 h-4" /> Métodos de Pago
            </div>
          </Tab>
        </TabList>

        <TabPanels>
           <!-- EMPRESA TAB -->
           <TabPanel value="empresa">
              <div class="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
                <div class="p-6 bg-slate-50 border-b border-slate-200">
                  <label class="block text-sm font-semibold text-slate-700 mb-1">Nombre de la Empresa</label>
                  <div class="text-lg font-bold text-slate-900">{{ empresa.nombre }}</div>
                </div>

                <div class="p-6 grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div class="flex flex-col gap-2">
                    <label class="text-sm font-semibold text-slate-700">RIF</label>
                    <InputText v-model="empresa.rif" placeholder="Ej: J-12345678-9" />
                  </div>

                  <div class="flex flex-col gap-2">
                    <label class="text-sm font-semibold text-slate-700">WhatsApp</label>
                    <InputText v-model="empresa.whatsapp" placeholder="Ej: +58..." />
                  </div>

                  <div class="flex flex-col gap-2 md:col-span-2">
                    <label class="text-sm font-semibold text-slate-700">Dirección</label>
                    <Textarea v-model="empresa.direccion" rows="3" placeholder="Dirección completa del negocio" />
                  </div>

                  <div class="flex flex-col gap-2">
                    <label class="text-sm font-semibold text-slate-700">Instagram</label>
                    <InputText v-model="empresa.instagram" placeholder="@usuario" />
                  </div>

                  <div class="flex flex-col gap-2">
                    <label class="text-sm font-semibold text-slate-700">Sitio Web</label>
                    <InputText v-model="empresa.sitio_web" placeholder="https://..." />
                  </div>

                  <div class="flex flex-col gap-2">
                    <label class="text-sm font-semibold text-slate-700">IVA (%)</label>
                    <InputNumber v-model="empresa.iva" mode="decimal" :minFractionDigits="1" :maxFractionDigits="2" suffix="%" placeholder="Ej: 16" @focus="$event => ($event.target as HTMLInputElement).select()" />
                  </div>
                </div>

                <div class="p-6 bg-slate-50 border-t border-slate-200 flex justify-end">
                  <Button @click="saveEmpresa" :loading="saving" label="Guardar Cambios" icon="pi pi-save" />
                </div>
              </div>
           </TabPanel>

           <!-- TASAS DE CAMBIO TAB -->
           <TabPanel value="tasas">
              <div class="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
                 <div class="p-4 border-b border-slate-100 flex items-center justify-between bg-slate-50">
                    <h3 class="font-bold text-slate-800 flex items-center gap-2">
                       <Banknote class="w-4 h-4 text-slate-400" />
                       Monitor de Divisas
                    </h3>
                    <div class="flex gap-2">
                        <Button label="Sincronizar Oficial" @click="executeSyncBcv" :loading="syncingTasa" severity="secondary" outlined class="shadow-sm bg-white">
                           <template #icon>
                              <RefreshCw class="w-4 h-4 mr-2" :class="{'animate-spin': syncingTasa}" />
                           </template>
                        </Button>
                        <Button label="Guardar Tasas Manuales" @click="saveManualRates" :loading="savingTasas" severity="success" icon="pi pi-save" />
                    </div>
                 </div>
                 <div class="p-6">
                    <div v-if="loadingTasas" class="flex justify-center p-10">
                       <Loader2 class="animate-spin text-blue-500" :size="32" />
                    </div>
                    <div v-else class="grid grid-cols-1 md:grid-cols-3 gap-6">
                       <div v-for="tasa in tasas" :key="tasa.codigo" class="border border-slate-200 rounded-xl p-4 bg-slate-50 flex flex-col justify-between">
                          <div class="mb-4">
                             <div class="flex items-center justify-between mb-1">
                                <span class="font-bold text-slate-700">{{ tasa.nombre }}</span>
                                <span v-if="tasa.is_auto" class="bg-blue-100 text-blue-700 text-[10px] font-black uppercase tracking-wider px-2 py-0.5 rounded-full">Bot</span>
                                <span v-else class="bg-slate-200 text-slate-600 text-[10px] font-black uppercase tracking-wider px-2 py-0.5 rounded-full">Manual</span>
                             </div>
                             <p class="text-xs text-slate-400 font-medium">Últ. act: {{ new Date(tasa.updated_at).toLocaleString('es') }}</p>
                          </div>
                          <div class="flex items-center gap-2">
                             <InputNumber v-model="tasa.tasa" :disabled="tasa.is_auto" mode="decimal" :minFractionDigits="2" :maxFractionDigits="4" class="w-full" :class="{'opacity-70': tasa.is_auto}" @focus="$event => ($event.target as HTMLInputElement).select()" />                             <span class="text-sm font-bold text-slate-400 w-12 text-center">{{ tasa.codigo === 'COP' ? 'COP' : 'Bs' }}</span>
                          </div>
                          <p v-if="tasa.is_auto" class="text-[10px] text-slate-400 mt-2 text-center">Tasa bloqueada. Sincroniza desde el botón superior.</p>
                       </div>
                    </div>
                 </div>
              </div>
           </TabPanel>

           <!-- MÉTODOS DE PAGO TAB -->
           <TabPanel value="metodos">
              <div class="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
                 <div class="p-4 border-b border-slate-100 flex items-center justify-between">
                    <h3 class="font-bold text-slate-800 flex items-center gap-2">
                       <CreditCard class="w-4 h-4 text-slate-400" />
                       Medios de Recepción de Dinero
                    </h3>
                    <Button label="Nuevo Método" @click="openNewMetodo" severity="success" class="shadow-sm">
                       <template #icon>
                          <Plus class="w-4 h-4 mr-2" />
                       </template>
                    </Button>
                 </div>
                 <div class="p-4">
                    <DataTable :value="metodos" :loading="loadingMetodos" stripedRows class="p-datatable-sm">
                       <Column field="nombre" header="Nombre del Método">
                          <template #body="{ data }">
                             <div class="font-bold text-slate-700">{{ data.nombre }}</div>
                          </template>
                       </Column>
                       <Column field="moneda" header="Moneda">
                          <template #body="{ data }">
                             <span class="px-2 py-1 bg-slate-100 text-slate-600 rounded text-xs font-bold">{{ data.moneda }}</span>
                          </template>
                       </Column>
                       <Column field="requiere_detalle" header="Referencia">
                          <template #body="{ data }">
                             <span v-if="data.requiere_detalle" class="px-2 py-1 bg-amber-100 text-amber-700 rounded text-[10px] font-black uppercase tracking-wider">Requerida</span>
                             <span v-else class="px-2 py-1 bg-slate-100 text-slate-500 rounded text-[10px] font-bold uppercase">No</span>
                          </template>
                       </Column>
                       <Column field="activo" header="Estado">
                          <template #body="{ data }">
                             <div class="flex items-center gap-2">
                                <ToggleSwitch v-model="data.activo" @change="toggleMetodoStatus(data)" />
                                <span :class="data.activo ? 'text-green-600' : 'text-slate-400'" class="text-xs font-bold uppercase">
                                   {{ data.activo ? 'Activo' : 'Inactivo' }}
                                </span>
                             </div>
                          </template>
                       </Column>
                       <Column header="Acciones" :exportable="false">
                          <template #body="{ data }">
                             <div class="flex gap-2">
                                <Button text rounded severity="secondary" @click="editMetodo(data)" class="text-blue-500 hover:bg-blue-50">
                                   <template #icon>
                                      <Pencil class="w-4 h-4" />
                                   </template>
                                </Button>
                                <Button text rounded severity="danger" @click="deleteMetodo(data)" class="hover:bg-rose-50">
                                   <template #icon>
                                      <Trash2 class="w-4 h-4" />
                                   </template>
                                </Button>
                             </div>
                          </template>
                       </Column>
                    </DataTable>
                 </div>
              </div>
           </TabPanel>
        </TabPanels>
      </Tabs>
    </div>

    <Dialog v-model:visible="metodoDialog" :header="modalMetodoTitle" :style="{ width: '450px' }" modal class="p-fluid">
       <div class="flex flex-col gap-4 pt-2">
          <div class="flex flex-col gap-2">
             <label for="nombre" class="text-xs font-bold text-slate-500 uppercase">Nombre (Ej: Zelle, Pago Móvil Banesco)</label>
             <InputText id="nombre" v-model="formMetodo.nombre" required autofocus />
          </div>
          <div class="flex flex-col gap-2">
             <label for="moneda" class="text-xs font-bold text-slate-500 uppercase">Moneda</label>
             <Select id="moneda" v-model="formMetodo.moneda" :options="['Bs', 'USD', 'COP', 'EUR']" />
          </div>
          <div class="flex items-center gap-3 bg-slate-50 p-3 rounded-lg border border-slate-200 mt-2">
             <ToggleSwitch v-model="formMetodo.activo" inputId="activo" />
             <label for="activo" class="font-semibold text-slate-700 cursor-pointer">Método Activo y Visible</label>
          </div>
          <div class="flex items-start gap-3 bg-amber-50 p-3 rounded-lg border border-amber-200">
             <ToggleSwitch v-model="formMetodo.requiere_detalle" inputId="requiere_detalle" class="mt-0.5" />
             <label for="requiere_detalle" class="flex flex-col cursor-pointer">
                <span class="font-semibold text-slate-700">Requiere Referencia</span>
                <span class="text-[11px] text-slate-500 leading-tight">Solicitar número de referencia/transacción al cobrar (ej: Zelle, Pago Móvil).</span>
             </label>
          </div>
       </div>
       <template #footer>
          <Button label="Cancelar" text severity="secondary" @click="metodoDialog = false" icon="pi pi-times" />
          <Button label="Guardar" @click="saveMetodo" severity="success" icon="pi pi-check" :loading="savingMetodo" />
       </template>
    </Dialog>
  </div>
</template>
