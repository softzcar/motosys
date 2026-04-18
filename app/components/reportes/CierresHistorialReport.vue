<script setup lang="ts">
const props = defineProps<{
  cierres: any[]
  filtros: {
    desde?: string
    hasta?: string
  }
}>()

const formatDate = (date: string | Date) => {
  return new Date(date).toLocaleString('es-VE', { 
    day: '2-digit', 
    month: '2-digit', 
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

const formatCurrency = (value: number) => {
  if (value === undefined || value === null) return '$0.00'
  return value.toLocaleString('es-VE', { style: 'currency', currency: 'USD' })
}

const totalEsperado = computed(() => props.cierres.reduce((acc, c) => acc + Number(c.total_ventas_usd), 0))
const totalCaja = computed(() => props.cierres.reduce((acc, c) => acc + Number(c.total_caja_usd), 0))
const totalDiferencia = computed(() => props.cierres.reduce((acc, c) => acc + Number(c.diferencia_usd), 0))
</script>

<template>
  <div class="print-report hidden print:block bg-white text-black p-4 md:p-8 font-sans">
    <!-- Header -->
    <div class="flex justify-between items-start border-b-2 border-slate-900 pb-4 mb-6">
      <div>
        <h1 class="text-2xl font-black uppercase tracking-tighter leading-none mb-2">Reporte de Cierres de Caja</h1>
        <div class="flex flex-wrap gap-4 text-[10px] font-bold text-slate-600">
           <p>EMITIDO: {{ formatDate(new Date()) }}</p>
           <p>PERIODO: {{ filtros.desde ? new Date(filtros.desde).toLocaleDateString('es-VE') : 'Inicio' }} AL {{ filtros.hasta ? new Date(filtros.hasta).toLocaleDateString('es-VE') : 'Hoy' }}</p>
        </div>
      </div>
      <div class="text-right">
         <p class="text-lg font-black leading-none">motosys</p>
         <p class="text-[10px] uppercase font-bold text-slate-500">Auditoría de Caja</p>
      </div>
    </div>

    <!-- Resumen -->
    <div class="grid grid-cols-3 gap-4 mb-6">
       <div class="border border-slate-200 p-2 rounded text-center">
          <p class="text-[8px] font-black text-slate-500 uppercase">Ventas Totales (USD)</p>
          <p class="text-lg font-black text-slate-900">{{ formatCurrency(totalEsperado) }}</p>
       </div>
       <div class="border border-slate-200 p-2 rounded text-center">
          <p class="text-[8px] font-black text-slate-500 uppercase">Efectivo en Caja</p>
          <p class="text-lg font-black text-slate-900">{{ formatCurrency(totalCaja) }}</p>
       </div>
       <div class="border border-slate-200 p-2 rounded text-center" :class="totalDiferencia < 0 ? 'bg-rose-50 border-rose-200' : 'bg-emerald-50 border-emerald-200'">
          <p class="text-[8px] font-black uppercase" :class="totalDiferencia < 0 ? 'text-rose-600' : 'text-emerald-600'">Diferencia Acumulada</p>
          <p class="text-lg font-black" :class="totalDiferencia < 0 ? 'text-rose-700' : 'text-emerald-700'">{{ formatCurrency(totalDiferencia) }}</p>
       </div>
    </div>

    <!-- Tabla -->
    <table class="w-full border-collapse border border-slate-300">
      <thead>
        <tr class="bg-slate-100 border-b border-slate-300">
          <th class="p-1.5 text-left text-[8px] font-black uppercase border-r border-slate-300">Fecha y Hora</th>
          <th class="p-1.5 text-left text-[8px] font-black uppercase border-r border-slate-300">Responsable</th>
          <th class="p-1.5 text-right text-[8px] font-black uppercase border-r border-slate-300">Ventas (USD)</th>
          <th class="p-1.5 text-right text-[8px] font-black uppercase border-r border-slate-300">Caja (USD)</th>
          <th class="p-1.5 text-right text-[8px] font-black uppercase w-24">Diferencia</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="c in cierres" :key="c.id" class="border-b border-slate-200 page-break-inside-avoid">
          <td class="p-1.5 text-[9px] text-slate-600 border-r border-slate-200">{{ formatDate(c.fecha) }}</td>
          <td class="p-1.5 text-[9px] font-bold text-slate-800 border-r border-slate-200">{{ c.responsable?.nombre }}</td>
          <td class="p-1.5 text-right text-[9px] text-slate-600 border-r border-slate-200">{{ formatCurrency(c.total_ventas_usd) }}</td>
          <td class="p-1.5 text-right text-[9px] text-slate-600 border-r border-slate-200">{{ formatCurrency(c.total_caja_usd) }}</td>
          <td class="p-1.5 text-right text-[10px] font-black" :class="Number(c.diferencia_usd) < 0 ? 'text-rose-600' : 'text-emerald-600'">
             {{ formatCurrency(c.diferencia_usd) }}
          </td>
        </tr>
      </tbody>
    </table>

    <!-- Footer -->
    <div class="mt-8 pt-6 border-t border-slate-200 flex justify-between items-end text-[9px] font-bold text-slate-400">
       <div>
          <p>ESTE DOCUMENTO ES UN REGISTRO DE AUDITORÍA DE CAJA MOTOSYS.</p>
       </div>
       <div class="text-right">
          Página ____ de ____
       </div>
    </div>
  </div>
</template>

<style scoped>
@page { size: letter; margin: 1cm; }
* { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
</style>
