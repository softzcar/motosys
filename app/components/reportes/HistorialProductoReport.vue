<script setup lang="ts">
import type { HistorialProductoItem } from '~/composables/useHistorialProductos'

const props = defineProps<{
  items: HistorialProductoItem[]
  loading?: boolean
}>()

const formatDate = (dateStr: string | Date) => {
  if (!dateStr) return 'N/A'
  const date = new Date(dateStr)
  return date.toLocaleString('es-VE', { 
    day: '2-digit', 
    month: '2-digit', 
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

const formatCurrency = (val: number) => {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(val || 0)
}
</script>

<template>
  <div class="print-report hidden print:block bg-white text-black p-4 md:p-8 font-sans">
    <!-- Header del reporte obligatorio -->
    <div class="flex justify-between items-start border-b-2 border-slate-900 pb-4 mb-6">
      <div>
        <h1 class="text-2xl font-black uppercase tracking-tighter leading-none mb-2">
          Reporte de Historial de Productos
        </h1>
        <div class="flex flex-wrap gap-4 text-[10px] font-bold text-slate-600">
           <p>EMITIDO: {{ formatDate(new Date()) }}</p>
           <p>PRODUCTOS CONSULTADOS: {{ items.length }}</p>
        </div>
      </div>
      <div class="text-right">
         <p class="text-lg font-black leading-none">motosys</p>
         <p class="text-[10px] uppercase font-bold text-slate-500">Historial & Trazabilidad</p>
      </div>
    </div>

    <!-- Mensaje si está cargando o está vacío -->
    <div v-if="loading" class="py-12 text-center text-xs font-bold uppercase text-slate-500">
      Cargando historial de productos...
    </div>

    <div v-else-if="items.length === 0" class="py-12 text-center text-xs font-bold uppercase text-slate-500">
      No se encontraron datos para los productos especificados.
    </div>

    <!-- Iteración por cada Producto -->
    <div v-else v-for="item in items" :key="item.producto.id" class="mb-8 page-break-inside-avoid">
      <!-- Encabezado de Producto (Estilo carta) -->
      <div class="bg-slate-900 text-white px-3 py-2 flex justify-between items-center mb-2">
         <div>
           <span class="text-xs font-black uppercase tracking-wider">{{ item.producto.nombre }}</span>
           <span class="text-[9px] text-slate-300 font-bold ml-2">SKU: {{ item.producto.codigo_parte }}</span>
         </div>
         <div class="flex gap-4 text-[9px] font-bold">
           <span>STOCK ACTUAL: {{ item.producto.stock }}</span>
           <span v-if="item.producto.ubicacion">UBICACIÓN: {{ item.producto.ubicacion }}</span>
         </div>
      </div>

      <!-- Resumen Estadístico Condensado -->
      <div class="grid grid-cols-4 gap-2 mb-3 bg-slate-50 p-2 border border-slate-200 text-[9px]">
        <div>
          <span class="text-slate-500 font-bold block uppercase">Total Comprado</span>
          <span class="font-black text-slate-900">{{ item.resumen.totalComprado }} unidades</span>
        </div>
        <div>
          <span class="text-slate-500 font-bold block uppercase">Total Vendido</span>
          <span class="font-black text-slate-900">{{ item.resumen.totalVendido }} unidades</span>
        </div>
        <div>
          <span class="text-slate-500 font-bold block uppercase">Ajustes Netos</span>
          <span class="font-black" :class="item.resumen.totalAjustado >= 0 ? 'text-emerald-700' : 'text-rose-700'">
            {{ item.resumen.totalAjustado > 0 ? '+' : '' }}{{ item.resumen.totalAjustado }} unidades
          </span>
        </div>
        <div>
          <span class="text-slate-500 font-bold block uppercase">Stock en Sistema</span>
          <span class="font-black text-slate-900">{{ item.resumen.stockActual }} unidades</span>
        </div>
      </div>

      <!-- SECCIÓN 1: COMPRAS E INGRESO EN FACTURAS -->
      <div class="mb-4">
        <h3 class="text-[9px] font-black uppercase tracking-wider text-slate-800 border-b border-slate-300 pb-1 mb-1">
          1. Historial de Compras & Facturas ({{ item.compras.length }})
        </h3>
        <table v-if="item.compras.length > 0" class="w-full border-collapse border border-slate-300">
          <thead>
            <tr class="bg-slate-100 border-b border-slate-300">
              <th class="p-1 text-left text-[8px] font-black uppercase border-r border-slate-300 w-24">Fecha</th>
              <th class="p-1 text-left text-[8px] font-black uppercase border-r border-slate-300 w-20">N° Compra</th>
              <th class="p-1 text-left text-[8px] font-black uppercase border-r border-slate-300 w-24">N° Factura</th>
              <th class="p-1 text-left text-[8px] font-black uppercase border-r border-slate-300">Proveedor</th>
              <th class="p-1 text-center text-[8px] font-black uppercase border-r border-slate-300 w-16">Cantidad</th>
              <th class="p-1 text-right text-[8px] font-black uppercase w-20">Costo U.</th>
            </tr>
          </thead>
          <tbody>
            <tr 
              v-for="c in item.compras" 
              :key="c.id" 
              class="border-b border-slate-200 text-[8px]"
              :class="c.anulada ? 'bg-rose-50 text-rose-700 line-through' : ''"
            >
              <td class="p-1 border-r border-slate-200 font-bold">{{ formatDate(c.fecha) }}</td>
              <td class="p-1 border-r border-slate-200 font-bold">#{{ c.numero_compra }}</td>
              <td class="p-1 border-r border-slate-200">{{ c.numero_factura || 'Sin Factura' }}</td>
              <td class="p-1 border-r border-slate-200 font-medium">{{ c.proveedor_nombre }}</td>
              <td class="p-1 border-r border-slate-200 text-center font-black">{{ c.cantidad }}</td>
              <td class="p-1 text-right font-bold">{{ formatCurrency(c.costo_unitario) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="text-[8px] italic text-slate-400 p-1">Sin registros de compras.</p>
      </div>

      <!-- SECCIÓN 2: AJUSTES DE STOCK E INVENTARIO -->
      <div class="mb-4">
        <h3 class="text-[9px] font-black uppercase tracking-wider text-slate-800 border-b border-slate-300 pb-1 mb-1">
          2. Ajustes Manuales y Auditoría de Stock ({{ item.ajustes.length }})
        </h3>
        <table v-if="item.ajustes.length > 0" class="w-full border-collapse border border-slate-300">
          <thead>
            <tr class="bg-slate-100 border-b border-slate-300">
              <th class="p-1 text-left text-[8px] font-black uppercase border-r border-slate-300 w-24">Fecha</th>
              <th class="p-1 text-left text-[8px] font-black uppercase border-r border-slate-300 w-20">Acción</th>
              <th class="p-1 text-left text-[8px] font-black uppercase border-r border-slate-300 w-28">Usuario</th>
              <th class="p-1 text-left text-[8px] font-black uppercase border-r border-slate-300">Motivo / Descripción</th>
              <th class="p-1 text-center text-[8px] font-black uppercase border-r border-slate-300 w-16">Ant. &rarr; Nvo.</th>
              <th class="p-1 text-center text-[8px] font-black uppercase w-16">Diferencia</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="a in item.ajustes" :key="a.id" class="border-b border-slate-200 text-[8px]">
              <td class="p-1 border-r border-slate-200 font-bold">{{ formatDate(a.fecha) }}</td>
              <td class="p-1 border-r border-slate-200 uppercase font-black text-slate-700">{{ a.accion }}</td>
              <td class="p-1 border-r border-slate-200 font-medium">{{ a.usuario_nombre }}</td>
              <td class="p-1 border-r border-slate-200 italic">{{ a.motivo || 'Sin motivo especificado' }}</td>
              <td class="p-1 border-r border-slate-200 text-center font-bold">{{ a.stock_anterior }} &rarr; {{ a.stock_nuevo }}</td>
              <td class="p-1 text-center font-black" :class="a.diferencia >= 0 ? 'text-emerald-700' : 'text-rose-700'">
                {{ a.diferencia > 0 ? '+' : '' }}{{ a.diferencia }}
              </td>
            </tr>
          </tbody>
        </table>
        <p v-else class="text-[8px] italic text-slate-400 p-1">Sin registros de ajustes manuales de stock.</p>
      </div>

      <!-- SECCIÓN 3: VENTAS REALIZADAS -->
      <div class="mb-4">
        <h3 class="text-[9px] font-black uppercase tracking-wider text-slate-800 border-b border-slate-300 pb-1 mb-1">
          3. Historial de Ventas ({{ item.ventas.length }})
        </h3>
        <table v-if="item.ventas.length > 0" class="w-full border-collapse border border-slate-300">
          <thead>
            <tr class="bg-slate-100 border-b border-slate-300">
              <th class="p-1 text-left text-[8px] font-black uppercase border-r border-slate-300 w-24">Fecha</th>
              <th class="p-1 text-left text-[8px] font-black uppercase border-r border-slate-300 w-20">N° Venta</th>
              <th class="p-1 text-left text-[8px] font-black uppercase border-r border-slate-300">Cliente</th>
              <th class="p-1 text-center text-[8px] font-black uppercase border-r border-slate-300 w-16">Vendidos</th>
              <th class="p-1 text-right text-[8px] font-black uppercase border-r border-slate-300 w-20">Precio U.</th>
              <th class="p-1 text-right text-[8px] font-black uppercase w-20">Subtotal</th>
            </tr>
          </thead>
          <tbody>
            <tr 
              v-for="v in item.ventas" 
              :key="v.id" 
              class="border-b border-slate-200 text-[8px]"
              :class="v.anulada ? 'bg-rose-50 text-rose-700 line-through' : ''"
            >
              <td class="p-1 border-r border-slate-200 font-bold">{{ formatDate(v.fecha) }}</td>
              <td class="p-1 border-r border-slate-200 font-bold">#{{ v.numero_venta }}</td>
              <td class="p-1 border-r border-slate-200 font-medium">{{ v.cliente_nombre }}</td>
              <td class="p-1 border-r border-slate-200 text-center font-black">{{ v.cantidad }}</td>
              <td class="p-1 border-r border-slate-200 text-right font-bold">{{ formatCurrency(v.precio_unitario) }}</td>
              <td class="p-1 text-right font-black">{{ formatCurrency(v.subtotal) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="text-[8px] italic text-slate-400 p-1">Sin registros de ventas.</p>
      </div>
    </div>

    <!-- Footer estándar de reportes carta -->
    <div class="mt-8 pt-6 border-t border-slate-200 flex justify-between items-end text-[9px] font-bold text-slate-400">
       <div>
          <p>GUÍA DE TRABAJO Y TRAZABILIDAD DE PRODUCTOS DE INVENTARIO.</p>
          <p>DOCUMENTO GENERADO AUTOMÁTICAMENTE POR MOTOSYS.</p>
       </div>
       <div class="text-right">
          Página ____ de ____
       </div>
    </div>
  </div>
</template>

<style scoped>
@media screen {
  .print-report {
    display: none;
  }
}

@media print {
  .print-report {
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
