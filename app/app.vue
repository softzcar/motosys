<script setup lang="ts">
import { useNetworkStore } from '~/stores/network'
import { useOfflineDb } from '~/composables/useOfflineDb'

const networkStore = useNetworkStore()
const { purgeOldData } = useOfflineDb()
const supabase = useSupabaseClient()

const isStandalone = ref(false)
const soloPwaConfig = ref(false)
const loadingConfig = ref(true)

// Detección de modo Standalone mejorada
const checkStandalone = () => {
  if (import.meta.client && typeof window !== 'undefined') {
    // 1. Media Query (Estándar)
    const mqStandalone = window.matchMedia('(display-mode: standalone)').matches
    const mqMinimalUi = window.matchMedia('(display-mode: minimal-ui)').matches
    
    // 2. Parámetro en URL (Nuestro trigger en nuxt.config)
    const urlStandalone = window.location.search.includes('mode=pwa') || window.location.search.includes('standalone=true')
    
    // 3. Detección por dimensiones (PC)
    // En una PWA instalada en PC, no hay barra de direcciones ni de marcadores.
    // La diferencia entre la ventana exterior e interior suele ser muy pequeña (< 100px).
    const isPwaHeight = (window.outerHeight - window.innerHeight) < 100 && (window.outerHeight - window.innerHeight) > 0

    // 4. Bypass para desarrollo (Localhost)
    const isLocal = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
    
    isStandalone.value = mqStandalone || mqMinimalUi || urlStandalone || isPwaHeight || isLocal

    console.log('[PWA Debug]', { 
      mqStandalone, 
      mqMinimalUi, 
      urlStandalone, 
      isPwaHeight, 
      isLocal,
      url: window.location.href,
      final: isStandalone.value 
    })
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
  // Si estamos en localhost y no queremos splash para desarrollo, podríamos añadir un bypass
  // Pero para el usuario seguiremos su regla:
  return soloPwaConfig.value && !isStandalone.value && !loadingConfig.value
})

// PRECARGA MAESTRA (Warm-up): 
onMounted(async () => {
  checkStandalone()
  fetchConfig()

  // Escuchar cambios en el modo de pantalla (por si se instala sin recargar)
  if (import.meta.client && typeof window !== 'undefined') {
    window.matchMedia('(display-mode: standalone)').addEventListener('change', (e) => {
      isStandalone.value = e.matches
    })
  }

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
  <div v-if="showSplash" class="fixed inset-0 bg-white flex flex-col items-center justify-center p-6 text-center z-[9999]">
    <div class="flex flex-col items-center gap-4">
      <img src="/android-icon-192x192.png" alt="motosys logo" class="w-32 h-32 rounded-3xl shadow-xl shadow-slate-200" />
      <h1 class="text-4xl font-black text-slate-800 tracking-tighter uppercase italic">motosys</h1>
    </div>
  </div>

  <NuxtLayout v-else>
    <NuxtPage />
    <PwaUpdate />
  </NuxtLayout>
</template>
