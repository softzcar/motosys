<script setup lang="ts">
import { Banknote, RefreshCw, Loader2 } from 'lucide-vue-next'
import { useTasas, type TasaCambio } from '~/composables/useTasas'

const emit = defineEmits(['updated'])
const toast = useToast()
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
        emit('updated')
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
        emit('updated')
    } catch (e: any) {
        toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 3000 })
    } finally {
        savingTasas.value = false
    }
}

onMounted(() => {
    loadTasas()
})
</script>

<template>
  <div class="bg-white rounded-xl overflow-hidden">
     <div class="p-4 border-b border-slate-100 flex items-center justify-between bg-slate-50">
        <h3 class="font-bold text-slate-800 flex items-center gap-2 text-sm md:text-base">
           <Banknote class="w-4 h-4 text-slate-400" />
           Monitor de Divisas
        </h3>
        <div class="flex gap-2">
            <Button label="Sincronizar" @click="executeSyncBcv" :loading="syncingTasa" severity="secondary" outlined size="small" class="shadow-sm bg-white">
               <template #icon>
                  <RefreshCw class="w-4 h-4 mr-1 md:mr-2" :class="{'animate-spin': syncingTasa}" />
               </template>
            </Button>
            <Button label="Guardar" @click="saveManualRates" :loading="savingTasas" severity="success" size="small" icon="pi pi-save" />
        </div>
     </div>
     <div class="p-4 md:p-6">
        <div v-if="loadingTasas" class="flex justify-center p-10">
           <Loader2 class="animate-spin text-blue-500" :size="32" />
        </div>
        <div v-else class="grid grid-cols-1 md:grid-cols-3 gap-6">
           <div v-for="tasa in tasas" :key="tasa.codigo" class="border border-slate-200 rounded-xl p-4 bg-slate-50 flex flex-col gap-4">
              <div class="min-h-[2.5rem] flex flex-col justify-center">
                 <div class="flex items-center justify-between mb-1 gap-2">
                    <span class="font-bold text-slate-700 text-sm leading-tight">{{ tasa.nombre }}</span>
                    <span v-if="tasa.is_auto" class="bg-blue-100 text-blue-700 text-[9px] font-black uppercase tracking-wider px-2 py-0.5 rounded-full shrink-0">Bot</span>
                    <span v-else class="bg-slate-200 text-slate-600 text-[9px] font-black uppercase tracking-wider px-2 py-0.5 rounded-full shrink-0">Manual</span>
                 </div>
                 <p class="text-[10px] text-slate-400 font-medium">Últ. act: {{ new Date(tasa.updated_at).toLocaleString('es') }}</p>
              </div>

              <div class="relative">
                 <InputNumber 
                    v-model="tasa.tasa" 
                    :disabled="tasa.is_auto" 
                    mode="decimal" 
                    :minFractionDigits="2" 
                    :maxFractionDigits="4" 
                    fluid
                    :input-class="['pr-12 text-sm font-semibold', { 'bg-slate-100 opacity-70': tasa.is_auto }]"
                    @focus="$event => ($event.target as HTMLInputElement).select()"
                    />                 <span class="absolute right-3 top-1/2 -translate-y-1/2 text-[10px] font-bold text-slate-400 pointer-events-none uppercase">
                    {{ tasa.codigo === 'COP' ? 'COP' : 'Bs' }}
                 </span>
              </div>
              
              <div class="min-h-[1rem]">
                <p v-if="tasa.is_auto" class="text-[9px] text-slate-400 text-center italic">
                   Tasa bloqueada. Sincroniza desde el botón superior.
                </p>
              </div>
           </div>
        </div>
     </div>
  </div>
</template>
