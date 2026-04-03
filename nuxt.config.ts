export default defineNuxtConfig({
  modules: [
    '@vite-pwa/nuxt',
    '@nuxtjs/supabase',
    '@pinia/nuxt',
    'primevue/nuxt-module'
  ],
  pwa: {
    registerType: 'autoUpdate',
    manifest: {
      name: 'MotoSys Inventario',
      short_name: 'MotoSys',
      description: 'Control de inventario para tiendas de repuestos de motos',
      theme_color: '#ffffff',
      icons: [
        {
          src: 'pwa-192x192.png',
          sizes: '192x192',
          type: 'image/png'
        },
        {
          src: 'pwa-512x512.png',
          sizes: '512x512',
          type: 'image/png'
        }
      ]
    },
    workbox: {
      navigateFallback: '/',
      globPatterns: ['**/*.{js,css,html,png,svg,ico}']
    },
    client: {
      installPrompt: true, // Esto ayuda a mostrar el botón de instalación
    }
  }
})