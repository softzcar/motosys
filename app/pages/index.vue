<script setup lang="ts">
// Redirección inmediata al Punto de Venta para optimizar el flujo de trabajo
definePageMeta({
  middleware: [
    function (to, from) {
      return navigateTo('/pos')
    }
  ]
})
</script>

<template>
  <div class="flex items-center justify-center min-h-[60vh]">
    <div class="flex flex-col items-center gap-4">
      <ProgressSpinner style="width: 40px; height: 40px" />
      <p class="text-slate-500 font-medium animate-pulse">Cargando sistema de ventas...</p>
    </div>
  </div>
</template>
