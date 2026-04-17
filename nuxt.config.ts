import Lara from '@primevue/themes/lara'
import tailwindcss from '@tailwindcss/vite'

// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  future: {
    compatibilityVersion: 4,
  },

  compatibilityDate: '2024-04-03',

  devServer: {
    port: 3001
  },

  vite: {
    plugins: [tailwindcss()]
  },

  modules: [
    '@vite-pwa/nuxt',
    '@nuxtjs/supabase',
    '@pinia/nuxt',
    '@primevue/nuxt-module'
  ],

  css: ['~/assets/css/main.css'],

  supabase: {
    redirect: false,
    types: false
  },

  runtimeConfig: {
    supabaseServiceRoleKey: ''
  },

  primevue: {
    options: {
      ripple: true,
      theme: {
        preset: Lara,
        options: {
          darkModeSelector: '.fake-dark',
          cssLayer: {
            name: 'primevue',
            order: 'theme, base, primevue'
          }
        }
      }
    }
  },

  app: {
    head: {
      title: 'motosys',
      meta: [
        { name: 'viewport', content: 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=0, viewport-fit=cover' },
        { name: 'apple-mobile-web-app-capable', content: 'yes' },
        { name: 'apple-mobile-web-app-status-bar-style', content: 'black-translucent' },
        { name: 'apple-mobile-web-app-title', content: 'motosys' },
        { name: 'format-detection', content: 'telephone=no' },
        { name: 'msapplication-TileColor', content: '#ffffff' },
        { name: 'msapplication-TileImage', content: '/ms-icon-144x144.png' },
        { name: 'theme-color', content: '#0f172a' }
      ],
      link: [
        { rel: 'icon', type: 'image/x-icon', href: '/favicon.ico' },
        { rel: 'apple-touch-icon', sizes: '57x57', href: '/apple-icon-57x57.png' },
        { rel: 'apple-touch-icon', sizes: '60x60', href: '/apple-icon-60x60.png' },
        { rel: 'apple-touch-icon', sizes: '72x72', href: '/apple-icon-72x72.png' },
        { rel: 'apple-touch-icon', sizes: '76x76', href: '/apple-icon-76x76.png' },
        { rel: 'apple-touch-icon', sizes: '114x114', href: '/apple-icon-114x114.png' },
        { rel: 'apple-touch-icon', sizes: '120x120', href: '/apple-icon-120x120.png' },
        { rel: 'apple-touch-icon', sizes: '144x144', href: '/apple-icon-144x144.png' },
        { rel: 'apple-touch-icon', sizes: '152x152', href: '/apple-icon-152x152.png' },
        { rel: 'apple-touch-icon', sizes: '180x180', href: '/apple-icon-180x180.png' },
        { rel: 'icon', type: 'image/png', sizes: '192x192', href: '/android-icon-192x192.png' },
        { rel: 'icon', type: 'image/png', sizes: '32x32', href: '/favicon-32x32.png' },
        { rel: 'icon', type: 'image/png', sizes: '96x96', href: '/favicon-96x96.png' },
        { rel: 'icon', type: 'image/png', sizes: '16x16', href: '/favicon-16x16.png' }
      ]
    }
  },

  // @ts-ignore
  pwa: {
    registerType: 'autoUpdate',
    manifest: {
      name: 'motosys',
      short_name: 'motosys',
      description: 'Sistema de Gestión motosys',
      theme_color: '#0f172a',
      background_color: '#ffffff',
      display: 'standalone',
      orientation: 'portrait',
      icons: [
        { src: 'android-icon-36x36.png', sizes: '36x36', type: 'image/png' },
        { src: 'android-icon-48x48.png', sizes: '48x48', type: 'image/png' },
        { src: 'android-icon-72x72.png', sizes: '72x72', type: 'image/png' },
        { src: 'android-icon-96x96.png', sizes: '96x96', type: 'image/png' },
        { src: 'android-icon-144x144.png', sizes: '144x144', type: 'image/png', purpose: 'any maskable' },
        { src: 'android-icon-192x192.png', sizes: '192x192', type: 'image/png', purpose: 'any maskable' },
        { src: 'apple-icon-180x180.png', sizes: '180x180', type: 'image/png' }
      ]
    },
    workbox: {
      navigateFallback: '/',
      runtimeCaching: [
        {
          urlPattern: /^https:\/\/.*\.supabase\.co\/rest\/v1\/.*/,
          handler: 'NetworkFirst',
          options: { cacheName: 'api-cache', expiration: { maxEntries: 100, maxAgeSeconds: 300 } }
        },
        {
          urlPattern: /^https:\/\/.*\.supabase\.co\/storage\/.*/,
          handler: 'StaleWhileRevalidate',
          options: { cacheName: 'image-cache', expiration: { maxEntries: 200, maxAgeSeconds: 86400 } }
        }
      ]
    },
    devOptions: {
      enabled: true,
      type: 'module'
    }
  }
})
