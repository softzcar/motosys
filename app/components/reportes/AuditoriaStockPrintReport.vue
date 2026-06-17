<script setup lang="ts">
import type { AuditoriaStockItem } from '~/composables/useAuditoria'

const props = defineProps<{
  items: AuditoriaStockItem[]
  filtros: {
    desde?: string
    hasta?: string
    search?: string
    categoria?: string | null
    marca?: string | null
    soloDiscrepancias?: boolean
    proveedor?: string | null
  }
}>()

const formatDateStr = (dateStr?: string) => {
  if (!dateStr) return 'N/A'
  return new Date(dateStr).toLocaleDateString('es-VE', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric'
  })
}

const formatDateTime = (date: Date) => {
  return date.toLocaleString('es-VE', { 
    day: '2-digit', 
    month: '2-digit', 
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

// Calcular totales
const totalItemsCount = computed(() => props.items.length)
const totalDiscrepancias = computed(() => props.items.filter(i => (i.stock_real_periodo - (i.stock_inicial + i.compras_periodo - i.ventas_periodo)) !== 0).length)

const totalCompras = computed(() => props.items.reduce((acc, i) => acc + i.compras_periodo, 0))
const totalVentas = computed(() => props.items.reduce((acc, i) => acc + i.ventas_periodo, 0))
const totalAjustes = computed(() => props.items.reduce((acc, i) => acc + i.ajustes_periodo, 0))
</script>

<template>
  <div class="print-report hidden print:block bg-white text-black p-4 md:p-8 font-sans">
    <!-- Header del reporte -->
    <div class="flex justify-between items-start border-b-2 border-slate-900 pb-4 mb-6">
      <div>
        <h1 class="text-2xl font-black uppercase tracking-tighter leading-none mb-2">Reporte de Auditoría de Inventario</h1>
        <div class="flex flex-wrap gap-4 text-[10px] font-bold text-slate-600">
           <p>EMITIDO: {{ formatDateTime(new Date()) }}</p>
           <p>
             PERIODO: 
             <span class="text-slate-900">
               {{ formatDateStr(filtros.desde) }} al {{ formatDateStr(filtros.hasta) }}
             </span>
           </p>
           <p>
             FILTROS: 
             <span v-if="filtros.categoria || filtros.marca || filtros.search || filtros.soloDiscrepancias || filtros.proveedor">
               {{ [
                 filtros.search ? `Búsqueda: "${filtros.search}"` : null,
                 filtros.categoria ? `Categoría: ${filtros.categoria}` : null,
                 filtros.marca ? `Marca: ${filtros.marca}` : null,
                 filtros.proveedor ? `Proveedor: ${filtros.proveedor}` : null,
                 filtros.soloDiscrepancias ? 'Solo Discrepancias' : null
               ].filter(Boolean).join(' | ') }}
             </span>
             <span v-else>Sin filtros adicionales</span>
           </p>
        </div>
      </div>
      <div class="text-right">
         <p class="text-lg font-black leading-none">motosys</p>
         <p class="text-[10px] uppercase font-bold text-slate-500">Auditoría General</p>
      </div>
    </div>

    <!-- Resumen de Datos -->
    <div class="grid grid-cols-4 gap-2 mb-6 text-[10px] bg-slate-50 p-3 rounded border border-slate-200">
      <div>
        <span class="font-bold text-slate-500 uppercase block">Total Items:</span>
        <span class="text-xs font-black text-slate-900">{{ totalItemsCount }}</span>
      </div>
      <div>
        <span class="font-bold text-slate-500 uppercase block">Discrepancias:</span>
        <span class="text-xs font-black text-rose-700">{{ totalDiscrepancias }}</span>
      </div>
      <div>
        <span class="font-bold text-slate-500 uppercase block">Movimientos:</span>
        <span class="text-xs font-black text-slate-900">
          Comp: +{{ totalCompras }} | Vent: -{{ totalVentas }} | Aj: {{ totalAjustes >= 0 ? '+' : '' }}{{ totalAjustes }}
        </span>
      </div>
      <div>
        <span class="font-bold text-slate-500 uppercase block">Estado de Auditoría:</span>
        <span class="text-xs font-black" :class="totalDiscrepancias > 0 ? 'text-rose-700' : 'text-emerald-700'">
          {{ totalDiscrepancias > 0 ? 'CON DISCREPANCIAS' : 'COMPLETAMENTE AUDITADO' }}
        </span>
      </div>
    </div>

    <!-- Cuerpo del reporte (Tabla condensada) -->
    <table class="w-full border-collapse border border-slate-300">
      <thead>
        <tr class="bg-slate-100 border-b border-slate-300">
          <th class="p-1 text-left text-[8px] font-black uppercase w-24 border-r border-slate-300">Código / SKU</th>
          <th class="p-1 text-left text-[8px] font-black uppercase border-r border-slate-300">Descripción del Producto</th>
          <th class="p-1 text-center text-[8px] font-black uppercase w-12 border-r border-slate-300">Stock Inicial</th>
          <th class="p-1 text-center text-[8px] font-black uppercase w-12 border-r border-slate-300">Compras (+)</th>
          <th class="p-1 text-center text-[8px] font-black uppercase w-12 border-r border-slate-300">Ventas (-)</th>
          <th class="p-1 text-center text-[8px] font-black uppercase w-12 border-r border-slate-300">Ajustes (+/-)</th>
          <th class="p-1 text-center text-[8px] font-black uppercase w-16 bg-blue-50 border-r border-slate-300">Debería Haber</th>
          <th class="p-1 text-center text-[8px] font-black uppercase w-16 bg-slate-50 border-r border-slate-300">Hay (Real)</th>
          <th class="p-1 text-center text-[8px] font-black uppercase w-16">Diferencia</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="p in items" :key="p.id" class="border-b border-slate-200 page-break-inside-avoid">
          <td class="p-1 text-[9px] font-bold text-slate-600 border-r border-slate-200">
             {{ p.codigo_parte }}
          </td>
          <td class="p-1 text-[9px] font-medium leading-tight border-r border-slate-200">
             {{ p.nombre }}
             <span v-if="p.marca_nombre" class="text-[7px] text-slate-900 font-bold uppercase ml-1">
                [{{ p.marca_nombre }}]
             </span>
             <span v-if="p.categoria_nombre" class="text-[7px] text-slate-400 font-bold uppercase ml-1">
                ({{ p.categoria_nombre }})
             </span>
          </td>
          <td class="p-1 text-center text-[9px] border-r border-slate-200">{{ p.stock_inicial }}</td>
          <td class="p-1 text-center text-[9px] text-emerald-700 font-bold border-r border-slate-200">
            {{ p.compras_periodo > 0 ? `+${p.compras_periodo}` : '0' }}
          </td>
          <td class="p-1 text-center text-[9px] text-rose-700 font-bold border-r border-slate-200">
            {{ p.ventas_periodo > 0 ? `-${p.ventas_periodo}` : '0' }}
          </td>
          <td class="p-1 text-center text-[9px] font-bold border-r border-slate-200" :class="p.ajustes_periodo > 0 ? 'text-blue-700' : p.ajustes_periodo < 0 ? 'text-amber-700' : 'text-slate-400'">
            {{ p.ajustes_periodo > 0 ? `+${p.ajustes_periodo}` : p.ajustes_periodo }}
          </td>
          <td class="p-1 text-center text-[10px] font-black bg-blue-50/20 border-r border-slate-200">
            {{ p.stock_inicial + p.compras_periodo - p.ventas_periodo }}
          </td>
          <td class="p-1 text-center text-[10px] font-black bg-slate-50/20 border-r border-slate-200">
            {{ p.stock_real_periodo }}
          </td>
          <td class="p-1 text-center text-[10px] font-black" :class="(p.stock_real_periodo - (p.stock_inicial + p.compras_periodo - p.ventas_periodo)) !== 0 ? 'text-rose-700 bg-rose-50' : 'text-slate-400'">
            {{ p.stock_real_periodo - (p.stock_inicial + p.compras_periodo - p.ventas_periodo) }}
          </td>
        </tr>
      </tbody>
    </table>

    <!-- Pie de página -->
    <div class="mt-8 pt-6 border-t border-slate-200 flex justify-between items-end text-[9px] font-bold text-slate-400">
       <div>
          <p>ESTE DOCUMENTO ES UN REGISTRO DE AUDITORÍA Y CONTROL INTERNO DE INVENTARIO MOTOSYS.</p>
          <p>VALORACIONES EXCLUSIVAS PARA CONTROL ADMINISTRATIVO.</p>
       </div>
       <div class="text-right">
          Página ____ de ____
       </div>
    </div>
  </div>
</template>

<style scoped>
@media screen {
  .print-container {
    display: none;
  }
}

@media print {
  .print-container {
    display: block !important;
    width: 100%;
    margin: 0;
    padding: 0;
  }

  table {
    page-break-inside: auto;
  }

  tr {
    page-break-inside: avoid;
    page-break-after: auto;
  }

  thead {
    display: table-header-group;
  }

  @page {
    size: letter;
    margin: 1cm;
  }

  * {
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }
}
</style>
