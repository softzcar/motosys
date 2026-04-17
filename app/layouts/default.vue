<script setup lang="ts">
const { fetchPerfil, perfil } = usePerfil()
const user = useSupabaseUser()
const { syncBcvRate } = useTasas()

const sidebarVisible = ref(false)

watch(() => user.value?.id || (user.value as any)?.sub, async (uid) => {
  if (uid && !perfil.value) await fetchPerfil()
}, { immediate: true })

onMounted(() => {
  // Auto-sincronizar la tasa oficial del banco central de forma silenciosa al cargar la web
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
  </div>
</template>
