<script setup lang="ts">
import { useNetworkStore } from '~/stores/network'
import { useOfflineDb } from '~/composables/useOfflineDb'

const networkStore = useNetworkStore()
const { purgeOldData } = useOfflineDb()
const supabase = useSupabaseClient()

const isStandalone = ref(false)
const soloPwaConfig = ref(false)
const loadingConfig = ref(true)

// Detección de modo Standalone
const checkStandalone = () => {
  if (import.meta.client && typeof window !== 'undefined') {
    isStandalone.value = window.matchMedia('(display-mode: standalone)').matches 
                         || (window.navigator as any).standalone 
                         || document.referrer.includes('android-app://')
                         || window.location.search.includes('mode=pwa')
  }
}

const fetchConfig = async () => {
  try {
    const { data } = await supabase.from('empresa').select('solo_pwa').limit(1).single()
    if (data) soloPwaConfig.value = data.solo_pwa
  } catch (e) {
    console.error('Error fetching PWA config:', e)
  } finally {
    loadingConfig.value = false
  }
}

// Mostrar Splash si:
// 1. La configuración está activa
// 2. NO estamos en modo standalone
// 3. Ya terminó de cargar la configuración
const showSplash = computed(() => {
  return soloPwaConfig.value && !isStandalone.value && !loadingConfig.value
})

// PRECARGA MAESTRA (Warm-up): 
onMounted(async () => {
  checkStandalone()
  fetchConfig()

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
    }
  }
})
</script>

<template>
  <div v-if="showSplash" class="fixed inset-0 bg-slate-900 flex flex-col items-center justify-center p-6 text-center">
    <div class="mb-8 animate-pulse">
      <!-- Logo placeholder o imagen real si existe -->
      <div class="w-24 h-24 bg-blue-600 rounded-2xl flex items-center justify-center shadow-2xl shadow-blue-500/20 mb-4">
        <span class="text-white text-4xl font-black italic">M</span>
      </div>
      <h1 class="text-4xl font-black text-white tracking-tighter uppercase italic">motosys</h1>
      <div class="h-1 w-12 bg-blue-500 mx-auto mt-2 rounded-full"></div>
    </div>
    
    <p class="text-slate-400 text-sm font-medium max-w-xs leading-relaxed">
      Para acceder al sistema, por favor instale la aplicación desde su navegador.
    </p>
  </div>

  <NuxtLayout v-else>
    <NuxtPage />
    <PwaUpdate />
  </NuxtLayout>
</template>
