import type { Perfil } from '~/types/database'

export const usePerfil = () => {
  const perfil = useState<Perfil | null>('perfil', () => null)
  const client = useSupabaseClient()
  const user = useSupabaseUser()
  const loading = useState('perfil-loading', () => false)

  const fetchPerfil = async (providedUid?: string) => {
    const uid = providedUid || user.value?.id || (user.value as any)?.sub
    
    if (!uid) {
      perfil.value = null
      return
    }

    // Evitar múltiples llamadas simultáneas
    if (loading.value) return

    // 1. INTENTO INSTANTÁNEO CACHÉ (Misión Crítica para UI rápida)
    if (import.meta.client) {
      const { getLocalPerfil } = useOfflineDb()
      const local = await getLocalPerfil()
      if (local && local.id === uid) {
        perfil.value = local
        // Si no hay red, ya terminamos. Si hay, seguimos en segundo plano
        // para refrescar datos pero ya la UI puede pintar.
        const { isOnline } = useOfflineDb()
        if (!isOnline.value) return
      }
    }
    
    loading.value = true
    try {
      // 2. INTENTO ONLINE con Timeout de seguridad
      const onlinePromise = client
        .from('perfiles')
        .select('*')
        .eq('id', uid)
        .maybeSingle()

      // Timeout de 5 segundos para evitar que la app se quede en blanco
      const timeoutPromise = new Promise((_, reject) => 
        setTimeout(() => reject(new Error('Timeout cargando perfil online')), 5000)
      )

      const result = await Promise.race([onlinePromise, timeoutPromise]) as any
      const data = result?.data
      const error = result?.error

      if (error) {
        console.error('[usePerfil] Error Supabase:', error)
        if (perfil.value) return // Mantener el que tenemos
        throw error
      }
      
      if (!data) {
        // Si no hay data online, pero tenemos local, no borramos (podría ser un desinc de Supabase)
        if (perfil.value) return
        perfil.value = null
        return
      }

      const pData = data as Perfil
      // Enriquecer perfil con el email para login offline
      if (pData && user.value?.email) {
        pData.email = user.value.email
      }

      perfil.value = pData

      // Guardar en caché local solo en el cliente
      if (import.meta.client && pData) {
        const { cachePerfil } = useOfflineDb()
        await cachePerfil(pData)
      }
      
    } catch (e) {
      console.warn('[usePerfil] Fallo fetch online, usando fallback local si existe.')
      if (import.meta.client) {
        const { getLocalPerfil } = useOfflineDb()
        const local = await getLocalPerfil()
        if (local && local.id === uid) {
          perfil.value = local
        }
      }
    } finally {
      loading.value = false
    }
  }

  const isAdmin = computed(() => {
    // Prioridad 1: Perfil cargado (es lo más real)
    if (perfil.value) return perfil.value.rol === 'admin'
    // Prioridad 2: Metadata de Supabase (si perfil aún no carga)
    if ((user.value?.user_metadata as any)?.rol === 'admin') return true
    // Fallback: Si no hay nada, no es admin
    return false
  })
  const clearPerfil = () => {
    perfil.value = null
  }

  return { perfil, loading, fetchPerfil, clearPerfil, isAdmin }
}
