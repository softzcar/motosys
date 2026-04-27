<script setup lang="ts">
import { useNetworkStore } from '~/stores/network'
import { useOfflineDb } from '~/composables/useOfflineDb'

const networkStore = useNetworkStore()
const { purgeOldData } = useOfflineDb()

// PRECARGA MAESTRA (Warm-up): 
// Asegura que los archivos críticos vivan en el caché local desde el inicio
onMounted(async () => {
  if (import.meta.client && typeof navigator !== 'undefined') {
    // 1. Limpieza de datos antiguos sincronizados
    await purgeOldData()

    if (navigator.onLine) {
      console.log('🚀 MotoSys: Calentando motores críticos...')
      
      // Descargar Layouts críticos
      import('~/layouts/default.vue').catch(() => {})
      import('~/layouts/auth.vue').catch(() => {})
      
      // Descargar Páginas críticas
      import('~/pages/login.vue').catch(() => {})
      import('~/pages/pos/index.vue').catch(() => {})
      import('~/pages/reportes/ventas.vue').catch(() => {})
      
      // Descargar Componentes del POS
      import('~/components/pos/PosProductSearch.vue').catch(() => {})
      import('~/components/pos/PosCart.vue').catch(() => {})
    }
  }
})
</script>

<template>
  <NuxtLayout>
    <NuxtPage />
    <PwaUpdate />
  </NuxtLayout>
</template>
