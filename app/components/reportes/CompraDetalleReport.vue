<script setup lang="ts">
const props = defineProps<{
  compra: any
}>()

const formatCurrency = (value: number) => {
  if (value === undefined || value === null) return '$0.00'
  return value.toLocaleString('es-VE', { style: 'currency', currency: 'USD' })
}

const formatDate = (dateString: string) => {
  if (!dateString) return '-'
  return new Date(dateString).toLocaleDateString('es-VE')
}

const formatDateTime = (dateString: string) => {
  if (!dateString) return '-'
  return new Date(dateString).toLocaleString('es-VE')
}
</script>

<template>
  <div class="print-report hidden print:block bg-white text-black p-4 md:p-8 font-sans">
    <!-- Header -->
    <div class="flex justify-between items-start border-b-2 border-slate-900 pb-4 mb-6">
      <div>
        <h1 class="text-2xl font-black uppercase tracking-tighter leading-none mb-2">Detalle de Compra y Suministro</h1>
        <div class="flex flex-wrap gap-4 text-[10px] font-bold text-slate-600">
           <p>EMITIDO: {{ new Date().toLocaleString('es-VE') }}</p>
           <p>PROVEEDOR: {{ compra.proveedores?.nombre ?? '-' }}</p>
           <p>FACTURA N°: {{ compra.numero_factura ?? '-' }}</p>
        </div>
      </div>
      <div class="text-right">
         <p class="text-lg font-black leading-none">motosys</p>
         <p class="text-[10px] uppercase font-bold text-slate-500">Gestión de Compras</p>
      </div>
    </div>

    <!-- Información adicional del ticket -->
    <div class="mb-4 text-[10px] bg-slate-50 p-2 rounded border border-slate-200 grid grid-cols-3 gap-2">
      <div><span class="font-bold uppercase text-slate-500">Ticket N°:</span> #{{ compra.numero }}</div>
      <div><span class="font-bold uppercase text-slate-500">Fecha de Compra:</span> {{ formatDate(compra.fecha) }}</div>
      <div><span class="font-bold uppercase text-slate-500">Estado:</span> {{ compra.anulada ? 'ANULADA' : 'VIGENTE' }}</div>
      <div v-if="compra.proveedores?.telefono"><span class="font-bold uppercase text-slate-500">Teléfono Prov:</span> {{ compra.proveedores.telefono }}</div>
      <div v-if="compra.anulada && compra.anulada_at"><span class="font-bold uppercase text-slate-500">Fecha Anulación:</span> {{ formatDateTime(compra.anulada_at) }}</div>
      <div v-if="compra.anulada && compra.anulada_por_perfil?.nombre"><span class="font-bold uppercase text-slate-500">Anulado por:</span> {{ compra.anulada_por_perfil.nombre }}</div>
    </div>

    <!-- Banner de anulación (si aplica) -->
    <div v-if="compra.anulada" class="mb-4 p-2 bg-rose-50 border border-rose-200 rounded text-[9px] text-rose-900">
      <p class="font-bold uppercase text-[10px] text-rose-800 mb-1">Motivo de Anulación:</p>
      <p>{{ compra.motivo_anulacion }}</p>
    </div>

    <!-- Ajustes de Seguridad de Inventario (si aplica) -->
    <div v-if="compra.anulada && compra.detalle_compras?.some((d: any) => d.ajuste_audit)" class="mb-4 p-2 bg-amber-50 border border-amber-200 rounded text-[9px] text-amber-900">
      <p class="font-bold uppercase text-[10px] text-amber-800 mb-1">Ajustes de Seguridad Aplicados:</p>
      <ul class="list-disc list-inside">
        <template v-for="item in compra.detalle_compras" :key="item.id">
          <li v-if="item.ajuste_audit">
            <b>{{ item.productos?.nombre }}</b>: {{ item.ajuste_audit }}
          </li>
        </template>
      </ul>
    </div>

    <!-- Tabla de Productos -->
    <table class="w-full border-collapse border border-slate-300 mb-6">
      <thead>
        <tr class="bg-slate-100 border-b border-slate-300">
          <th class="p-1.5 text-left text-[8px] font-black uppercase w-24 border-r border-slate-300">Código</th>
          <th class="p-1.5 text-left text-[8px] font-black uppercase border-r border-slate-300">Descripción del Producto</th>
          <th class="p-1.5 text-center text-[8px] font-black uppercase w-16 border-r border-slate-300">Cant.</th>
          <th class="p-1.5 text-right text-[8px] font-black uppercase w-24 border-r border-slate-300">Costo U.</th>
          <th class="p-1.5 text-right text-[8px] font-black uppercase w-24">Subtotal</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="item in compra.detalle_compras" :key="item.id" class="border-b border-slate-200 page-break-inside-avoid">
          <td class="p-1.5 text-[9px] font-bold text-slate-600 border-r border-slate-200">{{ item.productos?.codigo_parte }}</td>
          <td class="p-1.5 text-[9px] font-medium leading-tight border-r border-slate-200">{{ item.productos?.nombre }}</td>
          <td class="p-1.5 text-center text-[9px] font-medium border-r border-slate-200">{{ item.cantidad }}</td>
          <td class="p-1.5 text-right text-[9px] font-medium border-r border-slate-200">{{ formatCurrency(item.costo_unitario) }}</td>
          <td class="p-1.5 text-right text-[9px] font-black text-slate-800">{{ formatCurrency(item.subtotal) }}</td>
        </tr>
      </tbody>
    </table>

    <!-- Totales -->
    <div class="w-64 ml-auto space-y-1 text-[10px] mb-6">
       <div class="flex justify-between text-slate-600">
          <span>SUBTOTAL:</span>
          <span class="font-bold">{{ formatCurrency(compra.subtotal) }}</span>
       </div>
       <div v-if="Number(compra.descuento || 0) > 0" class="flex justify-between text-red-600 font-bold">
          <span>DESCUENTO ({{ Number(compra.descuento) }}%):</span>
          <span>-{{ formatCurrency(compra.subtotal * (Number(compra.descuento) / 100)) }}</span>
       </div>
       <div class="flex justify-between text-slate-600">
          <span>IVA:</span>
          <span class="font-bold">{{ formatCurrency(compra.iva) }}</span>
       </div>
       <div class="flex justify-between items-center pt-2 border-t border-slate-300 mt-2 text-slate-900 font-black">
          <span class="text-[9px] uppercase tracking-widest">TOTAL FACTURA:</span>
          <span class="text-sm font-black">{{ formatCurrency(compra.total) }}</span>
       </div>
    </div>

    <!-- Footer -->
    <div class="mt-8 pt-6 border-t border-slate-200 flex justify-between items-end text-[9px] font-bold text-slate-400">
       <div>
          <p>REGISTRO DE SUMINISTRO Y RECEPCIÓN DE MERCANCÍA EN ALMACÉN - MOTOSYS.</p>
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
