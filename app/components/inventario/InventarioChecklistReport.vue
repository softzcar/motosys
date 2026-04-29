<script setup lang="ts">
import type { Producto, CategoriaProducto } from '~/types/database'

const props = defineProps<{
  productos: Producto[]
  filtros: {
    search?: string
    categoria?: string | null
    marca?: string | null
    ubicacion?: string | null
  }
  loading?: boolean
}>()

const formatDate = (date: Date) => {
  return date.toLocaleString('es-VE', { 
    day: '2-digit', 
    month: '2-digit', 
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

// Agrupar por estante (ubicación)
const productosAgrupados = computed(() => {
  const grupos: Record<string, Producto[]> = {}
  
  // Clonar y ordenar antes de agrupar
  const sorted = [...props.productos].sort((a, b) => {
    const uA = a.ubicacion || 'Z_SIN_UBICACION'
    const uB = b.ubicacion || 'Z_SIN_UBICACION'
    if (uA !== uB) return uA.localeCompare(uB)
    return a.nombre.localeCompare(b.nombre)
  })

  sorted.forEach(p => {
    const u = p.ubicacion || 'Sin Ubicación Asignada'
    if (!grupos[u]) grupos[u] = []
    grupos[u].push(p)
  })

  return grupos
})
</script>

<template>
  <div class="print-report hidden print:block bg-white text-black p-4 md:p-8 font-sans">
    <!-- Header del reporte -->
    <div class="flex justify-between items-start border-b-2 border-slate-900 pb-4 mb-6">
      <div>
        <h1 class="text-2xl font-black uppercase tracking-tighter leading-none mb-2">Planilla de Chequeo de Inventario</h1>
        <div class="flex flex-wrap gap-4 text-[10px] font-bold text-slate-600">
           <p>EMITIDO: {{ formatDate(new Date()) }}</p>
           <p>
             FILTRO: 
             <span v-if="filtros.categoria || filtros.marca || filtros.ubicacion || filtros.search">
               {{ [
                 filtros.search ? `Búsqueda: "${filtros.search}"` : null,
                 filtros.categoria ? `Categoría: ${filtros.categoria}` : null,
                 filtros.marca ? `Marca: ${filtros.marca}` : null,
                 filtros.ubicacion ? `Ubicación: ${filtros.ubicacion}` : null
               ].filter(Boolean).join(' | ') }}
             </span>
             <span v-else>Todos los productos</span>
           </p>
        </div>
      </div>
      <div class="text-right">
         <p class="text-lg font-black leading-none">motosys</p>
         <p class="text-[10px] uppercase font-bold text-slate-500">Gestión de Stock</p>
      </div>
    </div>

    <!-- Filtros aplicados detalle -->
    <div v-if="filtros.categoria || filtros.marca || filtros.ubicacion || filtros.search" class="mb-4 text-[10px] bg-slate-50 p-2 rounded border border-slate-200">
      <span class="font-bold uppercase mr-2">Filtros Activos:</span>
      <span v-if="filtros.search" class="mr-3">Búsqueda: "{{ filtros.search }}"</span>
      <span v-if="filtros.categoria" class="mr-3">Categoría: {{ filtros.categoria }}</span>
      <span v-if="filtros.marca" class="mr-3">Marca: {{ filtros.marca }}</span>
      <span v-if="filtros.ubicacion" class="mr-3">Ubicación: {{ filtros.ubicacion }}</span>
    </div>

    <!-- Cuerpo del reporte (Tabla condensada) -->
    <div v-for="(items, estante) in productosAgrupados" :key="estante" class="mb-8">
      <div class="bg-slate-900 text-white px-3 py-1.5 flex justify-between items-center mb-0">
         <h2 class="text-xs font-black uppercase tracking-widest">{{ estante }}</h2>
         <span class="text-[9px] opacity-80">{{ items.length }} productos</span>
      </div>

      <table class="w-full border-collapse border border-slate-300">
        <thead>
          <tr class="bg-slate-100 border-b border-slate-300">
            <th class="p-1 text-left text-[8px] font-black uppercase w-24 border-r border-slate-300">Código / SKU</th>
            <th class="p-1 text-left text-[8px] font-black uppercase border-r border-slate-300">Descripción del Producto</th>
            <th class="p-1 text-center text-[8px] font-black uppercase w-16 bg-blue-50 border-r border-slate-300">Sistema</th>
            <th class="p-1 text-center text-[8px] font-black uppercase w-24">Conteo Real</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="p in items" :key="p.id" class="border-b border-slate-200 page-break-inside-avoid">
            <td class="p-1 text-[9px] font-bold text-slate-600 border-r border-slate-200">{{ p.codigo_parte }}</td>
            <td class="p-1 text-[10px] font-medium leading-tight border-r border-slate-200">
               {{ p.nombre }}
               <span v-if="!filtros.marca && p.marcas?.nombre" class="text-[7px] text-slate-900 font-bold uppercase ml-1">
                  [{{ p.marcas.nombre }}]
               </span>
               <span v-if="!filtros.categoria && p.categorias_productos?.nombre" class="text-[7px] text-slate-400 font-bold uppercase ml-1">
                  ({{ p.categorias_productos.nombre }})
               </span>
            </td>
            <td class="p-1 text-center text-xs font-black bg-blue-50/20 border-r border-slate-200">{{ p.stock }}</td>
            <td class="p-1 text-center">
               <div class="h-5 border border-slate-300 rounded mx-auto w-16 bg-white"></div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Pie de página -->
    <div class="mt-8 pt-6 border-t border-slate-200 flex justify-between items-end text-[9px] font-bold text-slate-400">
       <div>
          <p>ESTE DOCUMENTO ES UNA GUÍA DE TRABAJO PARA CONTROL DE ALMACÉN.</p>
          <p>PROHIBIDA SU REVENTA O USO NO AUTORIZADO.</p>
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
    display: none; /* Ocultar en pantalla normal */
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

  /* Optimizar para tamaño carta */
  @page {
    size: letter;
    margin: 1cm;
  }

  /* Evitar colores de fondo desaparecidos en algunos navegadores */
  * {
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }
}
</style>
