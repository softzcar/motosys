export const useAuth = () => {
  const client = useSupabaseClient()
  const user = useSupabaseUser()
  const { fetchPerfil, clearPerfil } = usePerfil()

  const login = async (email: string, password: string) => {
    const { data, error } = await client.auth.signInWithPassword({ email, password })
    if (error) throw error
    
    if (data.user) {
        await fetchPerfil(data.user.id)
    }
    
    await nextTick()
    await navigateTo('/')
  }

  const register = async (datos: {
    nombre: string
    email: string
    password: string
  }) => {
    const { error } = await $fetch('/api/empresa/create', {
      method: 'POST',
      body: datos
    }) as { error?: string }

    if (error) throw new Error(error)

    await login(datos.email, datos.password)
  }

  const logout = async () => {
    await client.auth.signOut()
    clearPerfil()
    await navigateTo('/login')
  }

  const recoverPassword = async (email: string) => {
    const { error } = await client.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password`
    })
    if (error) throw error
  }

  const updatePassword = async (password: string) => {
    const { error } = await client.auth.updateUser({ password })
    if (error) throw error
  }

  return { user, login, register, logout, recoverPassword, updatePassword }
}
