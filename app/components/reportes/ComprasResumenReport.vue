<script setup lang="ts">
const props = defineProps<{
  compras: any[]
  filtros: {
    desde?: string
    hasta?: string
    search?: string
  }
}>()

const formatDate = (date: string | Date) => {
  return new Date(date).toLocaleString('es-VE', { 
    day: '2-digit', 
    month: '2-digit', 
    year: 'numeric'
  })
}

const formatCurrency = (value: number) => {
  if (value === undefined || value === null) return '$0.00'
  return value.toLocaleString('es-VE', { style: 'currency', currency: 'USD' })
}

const totalMonto = computed(() => props.compras.reduce((acc, c) => acc + (c.anulada ? 0 : Number(c.total)), 0))
const totalFacturas = computed(() => props.compras.filter(c => !c.anulada).length)
const totalAnuladas = computed(() => props.compras.filter(c => c.anulada).length)
</script>

<template>
  <div class="print-report hidden print:block bg-white text-black p-4 md:p-8 font-sans">
    <!-- Header -->
    <div class="flex justify-between items-start border-b-2 border-slate-900 pb-4 mb-6">
      <div>
        <h1 class="text-2xl font-black uppercase tracking-tighter leading-none mb-2">Reporte de Compras y Suministros</h1>
        <div class="flex flex-wrap gap-4 text-[10px] font-bold text-slate-600">
           <p>EMITIDO: {{ new Date().toLocaleString('es-VE') }}</p>
           <p>PERIODO: {{ filtros.desde ? new Date(filtros.desde).toLocaleDateString('es-VE') : 'Inicio' }} AL {{ filtros.hasta ? new Date(filtros.hasta).toLocaleDateString('es-VE') : 'Hoy' }}</p>
           <p v-if="filtros.search">PROVEEDOR: "{{ filtros.search }}"</p>
        </div>
      </div>
      <div class="text-right">
         <p class="text-lg font-black leading-none">motosys</p>
         <p class="text-[10px] uppercase font-bold text-slate-500">Gestión de Compras</p>
      </div>
    </div>

    <!-- Resumen -->
    <div class="grid grid-cols-3 gap-4 mb-6">
       <div class="border border-slate-200 p-2 rounded text-center">
          <p class="text-[8px] font-black text-slate-500 uppercase">Inversión Total</p>
          <p class="text-lg font-black text-slate-900">{{ formatCurrency(totalMonto) }}</p>
       </div>
       <div class="border border-slate-200 p-2 rounded text-center">
          <p class="text-[8px] font-black text-slate-500 uppercase">Facturas Recibidas</p>
          <p class="text-lg font-black text-slate-900">{{ totalFacturas }}</p>
       </div>
       <div class="border border-slate-200 p-2 rounded text-center">
          <p class="text-[8px] font-black text-slate-500 uppercase">Facturas Anuladas</p>
          <p class="text-lg font-black text-slate-900">{{ totalAnuladas }}</p>
       </div>
    </div>

    <!-- Tabla -->
    <table class="w-full border-collapse border border-slate-300">
      <thead>
        <tr class="bg-slate-100 border-b border-slate-300">
          <th class="p-1.5 text-left text-[8px] font-black uppercase w-20 border-r border-slate-300">N° Ticket</th>
          <th class="p-1.5 text-left text-[8px] font-black uppercase border-r border-slate-300">Factura Prov.</th>
          <th class="p-1.5 text-left text-[8px] font-black uppercase border-r border-slate-300">Fecha</th>
          <th class="p-1.5 text-left text-[8px] font-black uppercase border-r border-slate-300">Proveedor</th>
          <th class="p-1.5 text-center text-[8px] font-black uppercase w-20 border-r border-slate-300">Estado</th>
          <th class="p-1.5 text-right text-[8px] font-black uppercase w-24">Monto Total</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="c in compras" :key="c.id" class="border-b border-slate-200 page-break-inside-avoid">
          <td class="p-1.5 text-[9px] font-bold text-slate-700 border-r border-slate-200">#{{ c.numero }}</td>
          <td class="p-1.5 text-[9px] text-slate-600 border-r border-slate-200">{{ c.numero_factura }}</td>
          <td class="p-1.5 text-[9px] text-slate-600 border-r border-slate-200">{{ formatDate(c.fecha) }}</td>
          <td class="p-1.5 text-[9px] text-slate-800 border-r border-slate-200">{{ c.proveedores?.nombre ?? '-' }}</td>
          <td class="p-1.5 text-center border-r border-slate-200">
             <span class="text-[7px] font-black uppercase">{{ c.anulada ? 'ANULADA' : 'VIGENTE' }}</span>
          </td>
          <td class="p-1.5 text-right text-[10px] font-black" :class="c.anulada ? 'text-slate-300 line-through' : 'text-slate-900'">
             {{ formatCurrency(c.total) }}
          </td>
        </tr>
      </tbody>
    </table>

    <!-- Footer -->
    <div class="mt-8 pt-6 border-t border-slate-200 flex justify-between items-end text-[9px] font-bold text-slate-400">
       <div>
          <p>ESTE DOCUMENTO ES UN REGISTRO DE SUMINISTROS MOTOSYS.</p>
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
