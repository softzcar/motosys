<script setup lang="ts">
const { $pwa } = useNuxtApp()

const updateServiceWorker = () => {
  $pwa?.updateServiceWorker(true)
}
</script>

<template>
  <div
    v-if="$pwa?.needRefresh"
    class="fixed bottom-4 left-4 right-4 md:left-auto md:right-4 md:w-80 z-[9999] animate-in slide-in-from-bottom-4 duration-300"
  >
    <div class="bg-slate-900 text-white p-4 rounded-2xl shadow-2xl flex flex-col gap-3">
      <div class="flex items-center gap-3">
        <div class="bg-blue-500 p-2 rounded-lg">
          <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-refresh-cw"><path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/><path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M3 21v-5h5"/></svg>
        </div>
        <div>
          <p class="text-sm font-bold leading-tight">Nueva versión disponible</p>
          <p class="text-[11px] text-slate-400">Actualiza para recibir las últimas mejoras.</p>
        </div>
      </div>
      <div class="flex gap-2">
        <button
          @click="$pwa.needRefresh = false"
          class="flex-1 py-2 text-xs font-bold text-slate-400 hover:text-white transition-colors"
        >
          Más tarde
        </button>
        <button
          @click="updateServiceWorker"
          class="flex-1 py-2 bg-blue-600 hover:bg-blue-700 text-white text-xs font-bold rounded-lg transition-colors shadow-lg shadow-blue-900/20"
        >
          Actualizar ahora
        </button>
      </div>
    </div>
  </div>
</template>
