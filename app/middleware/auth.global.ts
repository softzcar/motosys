import { useOfflineDb } from '~/composables/useOfflineDb'
import { useNetworkStore } from '~/stores/network'

export default defineNuxtRouteMiddleware(async (to) => {
  const user = useSupabaseUser()
  const networkStore = useNetworkStore()
  const { getLocalPerfil } = useOfflineDb()
  
  const publicRoutes = ['/login', '/register', '/forgot-password', '/reset-password', '/forbidden']
  const isPublic = publicRoutes.includes(to.path)

  // 1. Verificación Offline (Misión Crítica)
  if (!networkStore.isOnline) {
    const localPerfil = await getLocalPerfil()
    
    // Rutas permitidas en modo offline
    const allowedOffline = ['/pos', '/login', '/forbidden']
    const isAllowedOffline = allowedOffline.some(route => to.path.startsWith(route))

    // Si no hay perfil local y no es una ruta pública, al login
    if (!localPerfil && !isPublic) {
      return navigateTo('/login')
    }
    
    // Si estamos offline y la ruta no está permitida, bloqueamos
    if (!isAllowedOffline && !isPublic) {
       return navigateTo('/pos') 
    }

    // Si hay perfil local y estamos en login, pal POS
    if (localPerfil && isPublic && to.path !== '/forbidden') {
      return navigateTo('/pos')
    }

    // RBAC Offline para Vendedores (Adicional)
    if (localPerfil && localPerfil.rol === 'vendedor') {
       const allowedVendorRoutes = ['/pos', '/reportes/ventas', '/forbidden']
       const isAllowed = allowedVendorRoutes.some(route => to.path.startsWith(route))
       if (!isAllowed) return navigateTo('/forbidden')
    }

    return // Permitir navegación offline si pasó las reglas anteriores
  }

  // 2. Verificación Online (Comportamiento estándar Supabase)
  if (!user.value && !isPublic) {
    // BRECHA DE SEGURIDAD: Si estamos online pero Supabase aún no carga el user,
    // verificamos si hay un perfil local para evitar la expulsión inmediata.
    const localPerfil = await getLocalPerfil()
    if (localPerfil) {
      console.log('[Middleware] Usuario no detectado online, pero se permite acceso por perfil local persistente.')
      return
    }
    
    return navigateTo('/login')
  }

  if (user.value && isPublic && to.path !== '/forbidden') {
    return navigateTo('/')
  }

  // Protección de rutas por rol (RBAC Online)
  if (user.value) {
    const { fetchPerfil, perfil } = usePerfil()
    try {
      await fetchPerfil()
    } catch (e) {
      console.error('[Middleware] Error al cargar perfil:', e)
      // Si falla y no tenemos perfil local ni online, podríamos estar en un limbo
      // Pero no bloqueamos la navegación para evitar pantalla en blanco
    }

    if (perfil.value && perfil.value.rol === 'vendedor') {
      // Especial: Si el vendedor entra a la raíz, lo mandamos al POS
      if (to.path === '/') return navigateTo('/pos')

      const allowedVendorRoutes = ['/pos', '/reportes/ventas', '/forbidden']
      const isAllowed = allowedVendorRoutes.some(route => to.path.startsWith(route))
      
      if (!isAllowed) {
        return navigateTo('/forbidden')
      }
    }
  }
})
