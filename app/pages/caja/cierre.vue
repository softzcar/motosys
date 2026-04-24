<script setup lang="ts">
import { ClipboardList, Lock, ArrowLeft, Loader2, CheckCircle2, AlertTriangle } from 'lucide-vue-next'
import { useCierresCaja, type CierrePreview } from '~/composables/useCierresCaja'
import { useTasas, type TasaCambio } from '~/composables/useTasas'

const toast = useToast()
const confirm = useConfirm()
const { isAdmin, perfil } = usePerfil()

watch(perfil, (p) => {
  if (p && p.rol !== 'admin') navigateTo('/')
}, { immediate: true })

const { previewCierre, ejecutarCierre } = useCierresCaja()
const { fetchTasas, syncBcvRate } = useTasas()

const loading = ref(false)
const saving = ref(false)
const preview = ref<CierrePreview[]>([])
const tasas = ref<TasaCambio[]>([])
const contados = ref<Record<string, number>>({})
const observaciones = ref('')
const fechaCierre = ref(new Date())

const tasaParaMoneda = (moneda: string) => {
  if (moneda === 'USD') return 1
  if (moneda === 'COP') return tasas.value.find(t => t.codigo === 'COP')?.tasa || 1
  return tasas.value.find(t => t.codigo === 'BCV')?.tasa || 1
}

const filasCierre = computed(() => {
  return preview.value.map(p => {
    const contado = contados.value[p.metodo_pago_id] ?? 0
    const tasa = tasaParaMoneda(p.moneda)
    const contadoUsd = p.moneda === 'USD' ? contado : (tasa > 0 ? contado / tasa : 0)
    const diferencia = contado - Number(p.monto_sistema)
    const diferenciaUsd = contadoUsd - Number(p.monto_sistema_usd)
    return { ...p, contado, tasa, contadoUsd, diferencia, diferenciaUsd }
  })
})

const totalSistemaUsd = computed(() => filasCierre.value.reduce((acc, f) => acc + Number(f.monto_sistema_usd), 0))
const totalContadoUsd = computed(() => filasCierre.value.reduce((acc, f) => acc + f.contadoUsd, 0))
const totalDiferenciaUsd = computed(() => totalContadoUsd.value - totalSistemaUsd.value)

const loadPreview = async () => {
  loading.value = true
  try {
    await syncBcvRate().catch(() => {})
    const [p, t] = await Promise.all([previewCierre(), fetchTasas()])
    preview.value = p
    tasas.value = t
    contados.value = {}
    p.forEach(r => { contados.value[r.metodo_pago_id] = 0 })
  } catch (e: any) {
    toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 4000 })
  } finally {
    loading.value = false
  }
}

const ejecutar = () => {
  confirm.require({
    message: `¿Confirmas el cierre de caja del ${fechaCierre.value.toLocaleDateString('es')}? Esta acción congela las ventas y movimientos de este periodo.`,
    header: 'Confirmar cierre',
    icon: 'pi pi-exclamation-triangle',
    rejectProps: { label: 'Cancelar', severity: 'secondary', outlined: true },
    acceptProps: { label: 'Cerrar Caja', severity: 'danger' },
    accept: async () => {
      saving.value = true
      try {
        const detalles = filasCierre.value.map(f => ({
          metodo_pago_id: f.metodo_pago_id,
          monto_contado: Number(f.contado) || 0,
          tasa_referencia: Number(f.tasa) || 1
        }))
        const fechaIso = fechaCierre.value.toISOString().slice(0, 10)
        const id = await ejecutarCierre(fechaIso, detalles, observaciones.value.trim() || null)
        toast.add({ severity: 'success', summary: 'Cierre ejecutado', detail: `ID: ${id.slice(0, 8)}`, life: 3000 })
        navigateTo('/caja')
      } catch (e: any) {
        toast.add({ severity: 'error', summary: 'Error', detail: e.message, life: 5000 })
      } finally {
        saving.value = false
      }
    }
  })
}

const formatCurrency = (v: number) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(v)

onMounted(loadPreview)
</script>

<template>
  <div v-if="isAdmin">
    <!-- Header Responsivo -->
    <div class="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
      <div class="flex items-center gap-3">
        <NuxtLink to="/caja" class="p-2 rounded-lg hover:bg-slate-100 text-slate-500 shrink-0">
          <ArrowLeft :size="20" />
        </NuxtLink>
        <div class="p-2 bg-blue-100 text-blue-600 rounded-lg shrink-0">
          <ClipboardList :size="24" />
        </div>
        <div>
          <h1 class="text-2xl font-bold text-slate-800 tracking-tight">Cierre de Caja</h1>
          <p class="text-slate-500 text-sm">Confirma el efectivo contado contra el sistema.</p>
        </div>
      </div>
      <Button severity="danger" class="w-full md:w-auto flex items-center justify-center gap-2 font-black text-xs uppercase tracking-widest py-3" @click="ejecutar" :loading="saving" :disabled="loading">
        <Lock class="w-4 h-4" />
        Ejecutar Cierre
      </Button>
    </div>

    <div v-if="loading" class="flex justify-center p-20">
      <Loader2 class="animate-spin text-blue-500" :size="32" />
    </div>

    <div v-else class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <div class="lg:col-span-2 bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden flex flex-col">
        <div class="p-4 border-b border-slate-100 flex items-center gap-2">
          <ClipboardList class="w-4 h-4 text-slate-400" />
          <span class="text-xs font-bold text-slate-600 uppercase">Detalle por Método de Pago</span>
        </div>

        <!-- VISTA DESKTOP: Tabla Tradicional -->
        <div class="hidden md:block overflow-x-auto">
          <table class="w-full text-sm">
            <thead class="bg-slate-50 text-[10px] font-bold text-slate-400 uppercase tracking-wider">
              <tr>
                <th class="p-3 text-left">Método</th>
                <th class="p-3 text-right">Sistema</th>
                <th class="p-3 text-right">Contado</th>
                <th class="p-3 text-right">Tasa</th>
                <th class="p-3 text-right">Diferencia</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="filasCierre.length === 0">
                <td colspan="5" class="p-10 text-center text-slate-400 italic">Sin operaciones desde el último cierre.</td>
              </tr>
              <tr v-for="f in filasCierre" :key="f.metodo_pago_id" class="border-t border-slate-100">
                <td class="p-3">
                  <div class="font-bold text-slate-700">{{ f.nombre }}</div>
                  <div class="text-[10px] text-slate-400 font-bold uppercase">{{ f.moneda }}</div>
                </td>
                <td class="p-3 text-right">
                  <div class="font-bold text-slate-800">{{ Number(f.monto_sistema).toLocaleString() }}</div>
                  <div class="text-[10px] text-slate-400">{{ formatCurrency(Number(f.monto_sistema_usd)) }}</div>
                </td>
                <td class="p-3 text-right w-48">
                  <InputNumber v-model="contados[f.metodo_pago_id]" mode="decimal" :minFractionDigits="2" class="w-full" />
                  <div class="text-[10px] text-slate-400 mt-1">{{ formatCurrency(f.contadoUsd) }}</div>
                </td>
                <td class="p-3 text-right">
                  <span class="text-xs font-bold text-slate-500">{{ f.tasa.toLocaleString() }}</span>
                </td>
                <td class="p-3 text-right">
                  <div class="font-black" :class="f.diferencia === 0 ? 'text-slate-500' : f.diferencia > 0 ? 'text-emerald-700' : 'text-red-700'">
                    {{ f.diferencia >= 0 ? '+' : '' }}{{ f.diferencia.toLocaleString() }}
                  </div>
                  <div class="text-[10px]" :class="f.diferenciaUsd === 0 ? 'text-slate-400' : f.diferenciaUsd > 0 ? 'text-emerald-500' : 'text-red-500'">
                    {{ formatCurrency(f.diferenciaUsd) }}
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- VISTA MÓVIL: Lista de Tarjetas (Evita Scroll Horizontal) -->
        <div class="md:hidden divide-y divide-slate-100">
          <div v-if="filasCierre.length === 0" class="p-10 text-center text-slate-400 italic text-sm">
            Sin operaciones registradas.
          </div>
          <div v-for="f in filasCierre" :key="f.metodo_pago_id" class="p-4 space-y-4">
            <div class="flex justify-between items-start">
              <div>
                <div class="text-sm font-black text-slate-800 uppercase tracking-tight">{{ f.nombre }}</div>
                <div class="text-[10px] font-bold text-slate-400 uppercase bg-slate-50 px-2 py-0.5 rounded border border-slate-100 inline-block mt-1">{{ f.moneda }}</div>
              </div>
              <div class="text-right">
                <span class="text-[9px] font-black text-slate-400 uppercase block mb-1">Diferencia</span>
                <div class="text-sm font-black" :class="f.diferencia === 0 ? 'text-slate-500' : f.diferencia > 0 ? 'text-emerald-700' : 'text-red-700'">
                  {{ f.diferencia >= 0 ? '+' : '' }}{{ f.diferencia.toLocaleString() }}
                </div>
              </div>
            </div>

            <div class="grid grid-cols-2 gap-4">
              <div class="p-3 bg-slate-50 rounded-lg border border-slate-100">
                <span class="text-[9px] font-black text-slate-400 uppercase block mb-1">En Sistema</span>
                <div class="text-sm font-bold text-slate-700">{{ Number(f.monto_sistema).toLocaleString() }}</div>
                <div class="text-[10px] text-slate-400">{{ formatCurrency(Number(f.monto_sistema_usd)) }}</div>
              </div>
              <div class="p-3 bg-slate-50 rounded-lg border border-slate-100">
                <span class="text-[9px] font-black text-slate-400 uppercase block mb-1">Tasa Ref.</span>
                <div class="text-sm font-bold text-slate-600">{{ f.tasa.toLocaleString() }}</div>
              </div>
            </div>

            <div>
              <label class="text-[10px] font-black text-blue-600 uppercase block mb-1.5">Monto Contado en {{ f.moneda }}</label>
              <InputNumber v-model="contados[f.metodo_pago_id]" mode="decimal" :minFractionDigits="2" class="w-full h-12 text-lg" />
              <div class="flex justify-between items-center mt-2 px-1">
                <span class="text-[10px] font-bold text-slate-400 uppercase">Equivalente:</span>
                <span class="text-xs font-black text-slate-600">{{ formatCurrency(f.contadoUsd) }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="flex flex-col gap-4">
        <div class="bg-white rounded-xl border border-slate-200 shadow-sm p-5">
          <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-2">Fecha del Cierre</p>
          <DatePicker v-model="fechaCierre" dateFormat="dd/mm/yy" showIcon class="w-full" />
        </div>

        <div class="bg-white rounded-xl border border-slate-200 shadow-sm p-5 space-y-3">
          <div class="flex justify-between">
            <span class="text-xs text-slate-500 font-bold uppercase">Total Sistema</span>
            <span class="text-sm font-black text-slate-800">{{ formatCurrency(totalSistemaUsd) }}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-xs text-slate-500 font-bold uppercase">Total Contado</span>
            <span class="text-sm font-black text-slate-800">{{ formatCurrency(totalContadoUsd) }}</span>
          </div>
          <div class="pt-3 border-t border-slate-100 flex justify-between items-center">
            <span class="text-xs font-bold uppercase" :class="totalDiferenciaUsd === 0 ? 'text-slate-500' : totalDiferenciaUsd > 0 ? 'text-emerald-600' : 'text-red-600'">Diferencia</span>
            <div class="flex items-center gap-2">
              <CheckCircle2 v-if="totalDiferenciaUsd === 0" class="w-4 h-4 text-emerald-600" />
              <AlertTriangle v-else class="w-4 h-4" :class="totalDiferenciaUsd > 0 ? 'text-emerald-600' : 'text-red-600'" />
              <span class="text-lg font-black" :class="totalDiferenciaUsd === 0 ? 'text-slate-700' : totalDiferenciaUsd > 0 ? 'text-emerald-700' : 'text-red-700'">
                {{ formatCurrency(totalDiferenciaUsd) }}
              </span>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-xl border border-slate-200 shadow-sm p-5">
          <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-2">Observaciones</p>
          <Textarea v-model="observaciones" rows="4" class="w-full" placeholder="Notas sobre el cierre, faltantes, sobrantes..." />
        </div>
      </div>
    </div>

  </div>
  <div v-else class="flex items-center justify-center p-20 text-slate-400">
    <Loader2 class="animate-spin" :size="32" />
  </div>
</template>
