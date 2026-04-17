<script setup lang="ts">
import { ReceiptText, Ban, RotateCcw, FilePlus, CreditCard } from 'lucide-vue-next'
import type { Venta } from '~/types/database'

defineProps<{
  venta: Venta
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
    <!-- Banner ANULADA -->
    <div v-if="venta.anulada" class="bg-rose-50 border-2 border-rose-200 rounded-xl p-4">
      <div class="flex items-start gap-3">
        <Ban class="w-6 h-6 text-rose-600 flex-shrink-0 mt-0.5" />
        <div class="flex-1">
          <p class="text-rose-800 font-black uppercase tracking-widest text-xs mb-1">Venta anulada</p>
          <p class="text-sm text-rose-900 font-medium mb-2">{{ venta.motivo_anulacion }}</p>
          <p class="text-xs text-rose-700">
            Anulada por <b>{{ (venta as any).anulada_por_perfil?.nombre ?? 'Sistema' }}</b>
            el {{ formatDateTime(venta.anulada_at!) }}
          </p>
          <p v-if="(venta as any).reemplazo" class="text-xs text-rose-700 mt-2 flex items-center gap-1">
            <RotateCcw :size="12" />
            Reemplazada por venta <b>#{{ (venta as any).reemplazo.id.slice(0, 8).toUpperCase() }}</b> ({{ formatDate((venta as any).reemplazo.fecha) }})
          </p>
        </div>
      </div>
    </div>

    <!-- Banner CORRECCIÓN -->
    <div v-if="(venta as any).corrige" class="bg-amber-50 border border-amber-200 rounded-xl p-3">
      <div class="flex items-center gap-2 text-xs text-amber-900">
        <FilePlus :size="14" />
        Esta venta reemplaza a la venta anulada <b>#{{ (venta as any).corrige.id.slice(0, 8).toUpperCase() }}</b> ({{ formatDate((venta as any).corrige.fecha) }})
      </div>
    </div>

    <!-- Cabecera documento -->
    <div class="flex justify-between items-start bg-slate-50 p-4 rounded-xl border border-slate-200">
      <div>
        <p class="text-[10px] text-slate-400 font-bold uppercase tracking-widest mb-1">CLIENTE</p>
        <p class="font-black text-slate-800 text-lg leading-none">{{ (venta as any).clientes?.nombre ?? '-' }}</p>
      </div>
      <div class="text-right">
        <p class="text-[10px] text-slate-400 font-bold uppercase tracking-widest mb-1">N° TICKET</p>
        <p class="font-black text-slate-900">#{{ venta.id.slice(0, 8).toUpperCase() }}</p>
        <p class="text-[10px] text-slate-400 font-bold uppercase tracking-widest mt-3 mb-1">CAJERO</p>
        <p class="text-xs text-slate-600 font-bold">{{ (venta as any).vendedor?.nombre ?? 'Sistema' }}</p>
        <p class="text-xs text-slate-500 font-medium mt-1">Fecha: {{ formatDate(venta.fecha) }}</p>
      </div>
    </div>

    <!-- Items -->
    <div class="overflow-x-auto rounded-xl border border-slate-200">
      <table class="w-full text-left bg-white">
        <thead class="bg-slate-50 text-[10px] font-bold text-slate-400 uppercase tracking-widest border-b border-slate-200">
          <tr>
            <th class="p-3">PRODUCTO</th>
            <th class="p-3 w-20 text-center">CANT.</th>
            <th class="p-3 text-right">PRECIO U.</th>
            <th class="p-3 text-right pr-4">SUBTOTAL</th>
          </tr>
        </thead>
        <tbody class="text-sm border-b border-slate-100">
          <tr v-for="item in (venta.detalle_ventas as any)" :key="item.id" class="border-b border-slate-50 last:border-0 hover:bg-slate-50/50">
            <td class="p-3 align-top">
              <span class="block font-bold text-slate-700">{{ item.productos?.nombre }}</span>
              <span class="text-xs text-slate-400">{{ item.productos?.codigo_parte }}</span>
            </td>
            <td class="p-3 font-bold text-slate-600 align-top text-center">{{ item.cantidad }}</td>
            <td class="p-3 text-right text-slate-500 align-top">{{ formatCurrency(item.precio_unitario) }}</td>
            <td class="p-3 text-right font-bold text-slate-800 pr-4 align-top">{{ formatCurrency(item.cantidad * item.precio_unitario) }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Métodos de Pago -->
    <div v-if="venta.ventas_pagos && venta.ventas_pagos.length > 0">
      <p class="text-[10px] text-slate-400 font-bold uppercase tracking-widest mb-3 px-1">Resumen de Pagos</p>
      <div class="space-y-2">
        <div v-for="pago in (venta.ventas_pagos as any)" :key="pago.id" class="flex items-center justify-between p-3 bg-slate-50 border border-slate-100 rounded-lg">
          <div class="flex items-center gap-3">
            <div class="p-2 bg-white rounded-md border border-slate-200">
              <CreditCard class="w-4 h-4 text-slate-400" />
            </div>
            <div>
              <p class="text-sm font-bold text-slate-700 leading-none mb-1">{{ pago.metodos_pago?.nombre }}</p>
              <p v-if="pago.referencia" class="text-[10px] text-amber-600 font-bold uppercase tracking-wider mb-0.5">Ref: {{ pago.referencia }}</p>
              <p v-if="pago.tasa_aplicada > 1" class="text-[10px] text-slate-400 font-medium">Tasa: {{ pago.tasa_aplicada.toLocaleString() }} {{ pago.metodos_pago?.moneda }}/$</p>
            </div>
          </div>
          <div class="text-right">
            <p class="text-sm font-black text-slate-800 leading-none mb-1">{{ pago.monto_recibido.toLocaleString() }} {{ pago.metodos_pago?.moneda }}</p>
            <p class="text-[10px] text-slate-500 font-bold">({{ formatCurrency(pago.monto_usd) }})</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Total Footer -->
    <div class="flex justify-between items-center bg-emerald-50/50 p-4 rounded-xl border border-emerald-100 mt-4">
      <span class="text-xs font-bold text-emerald-600 uppercase tracking-widest">TOTAL DE LA VENTA</span>
      <span class="text-2xl font-black text-emerald-700">{{ formatCurrency(venta.total) }}</span>
    </div>
  </div>
</template>
