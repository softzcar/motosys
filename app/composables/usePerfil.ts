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

    // 1. INTENTO INSTANTÁNEO OFFLINE (Si ya sabemos que no hay red)
    if (import.meta.client) {
      const { isOnline } = useOfflineDb()
      if (!isOnline.value) {
        const { getLocalPerfil } = useOfflineDb()
        const local = await getLocalPerfil()
        if (local && local.id === uid) {
          console.log('[usePerfil] Modo Offline: Usando caché local inmediatamente')
          perfil.value = local
          return
        }
      }
    }
    
    loading.value = true
    try {
      // 2. INTENTO ONLINE (Solo si hay red o no se encontró local)
      const { data, error } = await client
        .from('perfiles')
        .select('*')
        .eq('id', uid)
        .maybeSingle()

      if (error) {
        // Recuperación de emergencia
        if (import.meta.client) {
          const { getLocalPerfil } = useOfflineDb()
          const local = await getLocalPerfil()
          if (local && local.id === uid) {
            perfil.value = local
            return
          }
        }
        throw error
      }
      
      const pData = data as Perfil

      // Enriquecer perfil con el email para login offline
      if (pData && user.value?.email) {
        pData.email = user.value.email
      }

      perfil.value = pData ?? null

      // Guardar en caché local solo en el cliente
      if (import.meta.client && pData) {
        const { cachePerfil } = useOfflineDb()
        await cachePerfil(pData)
      }
      
    } catch (e) {
      console.error('[usePerfil] fetchPerfil error:', e)
      
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

  const isAdmin = computed(
    () =>
      perfil.value?.rol === 'admin' ||
      (user.value?.user_metadata as any)?.rol === 'admin'
  )
  const clearPerfil = () => {
    perfil.value = null
  }

  return { perfil, loading, fetchPerfil, clearPerfil, isAdmin }
}
