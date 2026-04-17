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
    loading.value = true
    try {
      const { data, error } = await client
        .from('perfiles')
        .select('*')
        .eq('id', uid)
        .maybeSingle()

      if (error) throw error
      perfil.value = (data as Perfil) ?? null
    } catch (e) {
      console.error('[usePerfil] fetchPerfil error:', e)
      perfil.value = null
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
