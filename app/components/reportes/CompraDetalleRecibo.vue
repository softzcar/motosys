<script setup lang="ts">
import { ReceiptText, Ban, RotateCcw, FilePlus, Package, AlertTriangle } from 'lucide-vue-next'

defineProps<{
  compra: any
}>()

const formatCurrency = (value: number) => {
  return value.toLocaleString('es-VE', { style: 'currency', currency: 'USD' })
}

const formatDate = (dateString: string) => {
  return new Date(dateString).toLocaleDateString('es-VE')
}

const formatDateTime = (dateString: string) => {
  return new Date(dateString).toLocaleString('es-VE')
}
</script>

<template>
  <div class="space-y-6 pt-2">
    <!-- Banner COMPRA ANULADA -->
    <div v-if="compra.anulada" class="bg-rose-50 border-2 border-rose-200 rounded-xl p-4">
      <div class="flex items-start gap-3">
        <Ban class="w-6 h-6 text-rose-600 flex-shrink-0 mt-0.5" />
        <div class="flex-1">
          <p class="text-rose-800 font-black uppercase tracking-widest text-xs mb-1">Compra Anulada</p>
          <p class="text-sm text-rose-900 font-medium mb-2">{{ compra.motivo_anulacion }}</p>
          <p class="text-xs text-rose-700">
            Anulada por <b>{{ compra.anulada_por_perfil?.nombre ?? 'Sistema' }}</b>
            el {{ formatDateTime(compra.anulada_at!) }}
          </p>
          <p v-if="compra.reemplazo" class="text-xs text-rose-700 mt-2 flex items-center gap-1">
            <RotateCcw :size="12" />
            Reemplazada por compra <b>#{{ compra.reemplazo.numero }}</b> ({{ formatDate(compra.reemplazo.fecha) }})
          </p>
        </div>
      </div>
    </div>

    <!-- Alertas de ajuste de stock (IMPORTANTE) -->
    <div v-if="compra.anulada && compra.detalle_compras?.some((d: any) => d.ajuste_audit)" class="bg-amber-50 border border-amber-200 rounded-xl p-4">
      <div class="flex items-start gap-3">
        <AlertTriangle class="w-5 h-5 text-amber-600 mt-0.5" />
        <div class="flex-1">
          <p class="text-[11px] font-black text-amber-800 uppercase tracking-wider mb-1">Ajustes de Seguridad Aplicados</p>
          <p class="text-xs text-amber-700 leading-tight mb-2">Durante la anulación, el sistema detectó que algunos productos ya no tenían stock suficiente. Se aplicaron los siguientes ajustes:</p>
          <ul class="text-[11px] space-y-1">
            <template v-for="item in compra.detalle_compras" :key="item.id">
              <li v-if="item.ajuste_audit" class="text-amber-900 flex items-center gap-2">
                <span class="w-1.5 h-1.5 rounded-full bg-amber-400"></span>
                <b>{{ item.productos?.nombre }}</b>: {{ item.ajuste_audit }}
              </li>
            </template>
          </ul>
        </div>
      </div>
    </div>

    <!-- Banner CORRECCIÓN -->
    <div v-if="compra.corrige" class="bg-amber-50 border border-amber-200 rounded-xl p-3">
      <div class="flex items-center gap-2 text-xs text-amber-900">
        <FilePlus :size="14" />
        Esta compra reemplaza a la compra anulada <b>#{{ compra.corrige.numero }}</b> ({{ formatDate(compra.corrige.fecha) }})
      </div>
    </div>

    <!-- Cabecera documento -->
    <div class="flex justify-between items-start bg-slate-50 p-4 rounded-xl border border-slate-200">
      <div>
        <p class="text-[10px] text-slate-400 font-bold uppercase tracking-widest mb-1">PROVEEDOR</p>
        <p class="font-black text-slate-800 text-lg leading-none">{{ compra.proveedores?.nombre ?? '-' }}</p>
        <p class="text-xs text-slate-500 mt-1">Tel: {{ compra.proveedores?.telefono ?? '-' }}</p>
      </div>
      <div class="text-right">
        <p class="text-[10px] text-slate-400 font-bold uppercase tracking-widest mb-1">N° FACTURA</p>
        <p class="font-black text-slate-900">{{ compra.numero_factura }}</p>
        <p class="text-xs text-slate-500 font-medium mt-1">Fecha: {{ formatDate(compra.fecha) }}</p>
      </div>
    </div>

    <!-- Items -->
    <div class="overflow-x-auto rounded-xl border border-slate-200">
      <table class="w-full text-left bg-white">
        <thead class="bg-slate-50 text-[10px] font-bold text-slate-400 uppercase tracking-widest border-b border-slate-200">
          <tr>
            <th class="p-3">PRODUCTO</th>
            <th class="p-3 w-20 text-center">CANT.</th>
            <th class="p-3 text-right">COSTO U.</th>
            <th class="p-3 text-right pr-4">SUBTOTAL</th>
          </tr>
        </thead>
        <tbody class="text-sm border-b border-slate-100">
          <tr v-for="item in (compra.detalle_compras as any)" :key="item.id" class="border-b border-slate-50 last:border-0">
            <td class="p-3 align-top">
              <span class="block font-bold text-slate-700">{{ item.productos?.nombre }}</span>
              <span class="text-xs text-slate-400">{{ item.productos?.codigo_parte }}</span>
            </td>
            <td class="p-3 font-bold text-slate-600 align-top text-center">{{ item.cantidad }}</td>
            <td class="p-3 text-right text-slate-500 align-top">{{ formatCurrency(item.costo_unitario) }}</td>
            <td class="p-3 text-right font-bold text-slate-800 pr-4 align-top">{{ formatCurrency(item.subtotal) }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Resumen Totales -->
    <div class="space-y-1 px-1">
       <div class="flex justify-between text-xs text-slate-500">
          <span>SUBTOTAL</span>
          <span>{{ formatCurrency(compra.subtotal) }}</span>
       </div>
       <div class="flex justify-between text-xs text-slate-500">
          <span>IVA</span>
          <span>{{ formatCurrency(compra.iva) }}</span>
       </div>
       <div class="flex justify-between items-center pt-2 border-t border-slate-100 mt-2">
          <span class="text-xs font-black text-blue-600 uppercase tracking-widest">TOTAL FACTURA</span>
          <span class="text-2xl font-black text-blue-700">{{ formatCurrency(compra.total) }}</span>
       </div>
    </div>
  </div>
</template>
