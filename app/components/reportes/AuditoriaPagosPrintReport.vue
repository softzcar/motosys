<script setup lang="ts">
const props = defineProps<{
  items: any[]
  filtros: {
    desde?: string
    hasta?: string
    search?: string
    metodoPagoId?: string | null
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

const formatDateTime = (dateStr: string) => {
  if (!dateStr) return 'N/A'
  return new Date(dateStr).toLocaleString('es-VE', { 
    day: '2-digit', 
    month: '2-digit', 
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

const formatCurrency = (val: number, currency: string = 'USD') => {
  const formatted = new Intl.NumberFormat('es-VE', { 
    minimumFractionDigits: 2,
    maximumFractionDigits: 2
  }).format(val)
  
  if (currency === 'USD' || currency === '$') {
    return `${formatted} $`
  } else if (currency === 'VES' || currency === 'Bs' || currency === 'Bs.F') {
    return `${formatted} Bs.`
  } else {
    return `${formatted} ${currency}`
  }
}

// Totales agrupados por moneda
const totalPorMoneda = computed(() => {
  const totals: Record<string, number> = {}
  props.items.forEach(p => {
    if (p.ventas?.anulada) return // Excluir ventas anuladas de los totales
    const moneda = p.metodos_pago?.moneda || 'USD'
    const monto = Number(p.monto_recibido) || 0
    totals[moneda] = (totals[moneda] || 0) + monto
  })
  return totals
})

// Total general en USD
const totalUsd = computed(() => {
  return props.items.reduce((acc, p) => {
    if (p.ventas?.anulada) return acc
    return acc + (Number(p.monto_usd) || 0)
  }, 0)
})

// Totales agrupados por método de pago
const totalPorMetodo = computed(() => {
  const totals: Record<string, { total: number; moneda: string }> = {}
  props.items.forEach(p => {
    if (p.ventas?.anulada) return
    const metodo = p.metodos_pago?.nombre || 'Desconocido'
    const moneda = p.metodos_pago?.moneda || 'USD'
    const monto = Number(p.monto_recibido) || 0
    if (!totals[metodo]) {
      totals[metodo] = { total: 0, moneda }
    }
    totals[metodo].total += monto
  })
  return totals
})
</script>

<template>
  <div class="print-report hidden print:block bg-white text-black p-4 md:p-8 font-sans">
    <!-- Header del reporte -->
    <div class="flex justify-between items-start border-b-2 border-slate-900 pb-4 mb-6">
      <div>
        <h1 class="text-2xl font-black uppercase tracking-tighter leading-none mb-2">Reporte de Auditoría de Pagos</h1>
        <div class="flex flex-wrap gap-4 text-[10px] font-bold text-slate-600">
           <p>EMITIDO: {{ formatDateTime(new Date().toISOString()) }}</p>
           <p>
             PERIODO: 
             <span class="text-slate-900">
               {{ formatDateStr(filtros.desde) }} al {{ formatDateStr(filtros.hasta) }}
             </span>
           </p>
           <p>
             FILTROS: 
             <span v-if="filtros.search || filtros.metodoPagoId">
               {{ [
                 filtros.search ? `Búsqueda: "${filtros.search}"` : null,
                 filtros.metodoPagoId ? 'Filtrado por método' : null
               ].filter(Boolean).join(' | ') }}
             </span>
             <span v-else>Sin filtros adicionales</span>
           </p>
        </div>
      </div>
      <div class="text-right">
         <p class="text-lg font-black leading-none">motosys</p>
         <p class="text-[10px] uppercase font-bold text-slate-500">Auditoría de Pagos</p>
      </div>
    </div>

    <!-- Resumen de Totales por Moneda y Método -->
    <div class="mb-6 p-3 bg-slate-50 rounded border border-slate-200">
      <div class="grid grid-cols-2 gap-4">
        <div>
          <h3 class="text-[8px] font-black uppercase tracking-wider text-slate-500 mb-1.5">Resumen por Moneda (Vigentes)</h3>
          <div class="flex flex-wrap gap-4 items-center">
            <div v-for="(monto, moneda) in totalPorMoneda" :key="moneda" class="text-[10px]">
              <span class="font-bold text-slate-600 mr-1">{{ moneda }}:</span>
              <span class="font-black text-slate-950">{{ formatCurrency(monto, moneda) }}</span>
            </div>
            <div class="text-[10px] border-l border-slate-300 pl-4">
              <span class="font-bold text-slate-600 mr-1">Total Ref. USD:</span>
              <span class="font-black text-blue-700">{{ formatCurrency(totalUsd, 'USD') }}</span>
            </div>
          </div>
        </div>
        
        <div class="border-l border-slate-200 pl-4">
          <h3 class="text-[8px] font-black uppercase tracking-wider text-slate-500 mb-1.5">Resumen por Método de Pago (Vigentes)</h3>
          <div class="flex flex-wrap gap-x-4 gap-y-1">
            <div v-for="(info, metodo) in totalPorMetodo" :key="metodo" class="text-[10px]">
              <span class="font-bold text-slate-600 mr-1">{{ metodo }}:</span>
              <span class="font-black text-slate-950">{{ formatCurrency(info.total, info.moneda) }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Tabla de Detalles de Transacciones -->
    <table class="w-full border-collapse border border-slate-300">
      <thead>
        <tr class="bg-slate-100 border-b border-slate-300">
          <th class="p-1 text-left text-[8px] font-black uppercase w-28 border-r border-slate-300">Fecha / Hora</th>
          <th class="p-1 text-left text-[8px] font-black uppercase w-16 border-r border-slate-300">Venta #</th>
          <th class="p-1 text-left text-[8px] font-black uppercase border-r border-slate-300">Método de Pago</th>
          <th class="p-1 text-center text-[8px] font-black uppercase w-16 border-r border-slate-300">Moneda</th>
          <th class="p-1 text-right text-[8px] font-black uppercase w-20 border-r border-slate-300">Monto Recibido</th>
          <th class="p-1 text-right text-[8px] font-black uppercase w-16 border-r border-slate-300">Tasa</th>
          <th class="p-1 text-right text-[8px] font-black uppercase w-20 border-r border-slate-300">Equiv. USD</th>
          <th class="p-1 text-left text-[8px] font-black uppercase w-36 border-r border-slate-300">Referencia / Detalle</th>
          <th class="p-1 text-center text-[8px] font-black uppercase w-16">Estado</th>
        </tr>
      </thead>
      <tbody>
        <tr 
          v-for="p in items" 
          :key="p.id" 
          class="border-b border-slate-200 page-break-inside-avoid"
          :class="{'line-through text-slate-400 bg-red-50/10': p.ventas?.anulada}"
        >
          <td class="p-1 text-[8px] font-medium border-r border-slate-200">
             {{ formatDateTime(p.created_at) }}
          </td>
          <td class="p-1 text-[8px] font-bold text-center border-r border-slate-200">
             {{ p.ventas?.numero || 'N/A' }}
          </td>
          <td class="p-1 text-[8px] font-medium border-r border-slate-200">
             {{ p.metodos_pago?.nombre || 'N/A' }}
          </td>
          <td class="p-1 text-center text-[8px] font-bold border-r border-slate-200">
             {{ p.metodos_pago?.moneda || 'USD' }}
          </td>
          <td class="p-1 text-right text-[8px] font-black border-r border-slate-200">
             {{ formatCurrency(Number(p.monto_recibido), p.metodos_pago?.moneda) }}
          </td>
          <td class="p-1 text-right text-[8px] border-r border-slate-200">
             {{ Number(p.tasa_aplicada).toLocaleString('es-VE', { minimumFractionDigits: 2 }) }}
          </td>
          <td class="p-1 text-right text-[8px] font-black text-slate-700 border-r border-slate-200">
             {{ formatCurrency(Number(p.monto_usd), 'USD') }}
          </td>
          <td class="p-1 text-[8px] font-medium border-r border-slate-200 truncate max-w-[150px]">
             {{ p.referencia || 'Sin detalle' }}
          </td>
          <td class="p-1 text-center text-[8px] font-bold">
            <span v-if="p.ventas?.anulada" class="text-rose-700">ANULADA</span>
            <span v-else class="text-emerald-700">VIGENTE</span>
          </td>
        </tr>
      </tbody>
    </table>

    <!-- Pie de página -->
    <div class="mt-8 pt-6 border-t border-slate-200 flex justify-between items-end text-[9px] font-bold text-slate-400">
       <div>
          <p>ESTE DOCUMENTO ES UN REGISTRO DE AUDITORÍA Y CONTROL FINANCIERO INTERNO MOTOSYS.</p>
          <p>VALORACIONES EXCLUSIVAS PARA CONTROL DE CAJA GENERAL.</p>
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
