<script setup lang="ts">
const { fetchPerfil, perfil } = usePerfil()
const user = useSupabaseUser()
const { syncBcvRate } = useTasas()
const { isOnline } = useOfflineDb()
const { syncPendingSales, syncMasterData } = useSync()
const networkStore = useNetworkStore()

const sidebarVisible = ref(false)

watch(() => user.value?.id || (user.value as any)?.sub, async (uid) => {
  if (uid && !perfil.value) await fetchPerfil()
}, { immediate: true })

// MOTOR DE SINCRONIZACIÓN AUTOMÁTICO
watch(() => networkStore.isOnline, (online) => {
  if (online) {
    console.log('🌐 Conexión recuperada. Sincronizando...')
    // Usamos un pequeño delay para que Supabase esté 100% listo
    setTimeout(() => {
      fetchPerfil() // Refrescar perfil para asegurar rol correcto
      syncMasterData()
      syncPendingSales()
    }, 1000)
  }
})

onMounted(async () => {
  // Iniciar vigilancia única de red
  networkStore.startHeartbeat()
  
  // Recuperación de perfil offline si es necesario
  if (!networkStore.isOnline) {
    const { getLocalPerfil } = useOfflineDb()
    const local = await getLocalPerfil()
    if (local && !perfil.value) {
      console.log('👤 Perfil restaurado desde caché local (Inicio Offline)')
      perfil.value = local
    }
  }

  // Sincronización inicial si hay conexión
  if (networkStore.isOnline) {
    syncMasterData()
    syncPendingSales()

    // CALENTAMIENTO DE CACHÉ
    if (import.meta.client) {
      import('~/pages/pos/index.vue').catch(() => {})
    }
  }
  
  syncBcvRate()
})
</script>

<template>
  <div class="flex h-screen overflow-hidden bg-slate-50">
    <!-- Sidebar desktop -->
    <div class="hidden lg:flex">
      <LayoutAppSidebar />
    </div>

    <!-- Sidebar mobile -->
    <Drawer 
      v-model:visible="sidebarVisible" 
      :show-close-icon="false"
      class="!p-0 !border-none !bg-slate-900"
      :pt="{
        root: { class: '!p-0 !border-none !bg-slate-900 !rounded-none !h-full' },
        content: { class: '!p-0 !h-full !overflow-hidden !bg-slate-900' },
        header: { class: '!hidden' },
        mask: { class: 'backdrop-blur-sm' }
      }"
    >
      <LayoutAppSidebar @close="sidebarVisible = false" />
    </Drawer>

    <!-- Main content -->
    <div class="flex-1 flex flex-col overflow-hidden">
      <LayoutAppTopbar @toggle-sidebar="sidebarVisible = !sidebarVisible" />

      <main class="flex-1 overflow-auto p-6">
        <slot />
      </main>
    </div>

    <!-- Componentes Globales de PrimeVue -->
    <ConfirmDialog />
    <Toast />
  </div>
</template>
