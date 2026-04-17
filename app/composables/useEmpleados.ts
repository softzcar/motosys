import type { Perfil } from '~/types/database'

export const useEmpleados = () => {
  const client = useSupabaseClient()

  const fetchEmpleados = async (opts?: {
    search?: string
    page?: number
    rows?: number
    sortField?: string
    sortOrder?: number
    incluirInactivos?: boolean
  }) => {
    const page = opts?.page ?? 0
    const rows = opts?.rows ?? 20
    const from = page * rows
    const to = from + rows - 1

    let query = client
      .from('perfiles')
      .select('*', { count: 'exact' })
      .order(opts?.sortField || 'nombre', { ascending: opts?.sortOrder === 1 || !opts?.sortField })
      .range(from, to)

    if (opts?.search) {
      query = query.ilike('nombre', `%${opts.search}%`)
    }

    if (!opts?.incluirInactivos) {
      query = query.eq('activo', true)
    }

    const { data, count, error } = await query
    if (error) throw error
    return { data: data as Perfil[], total: count ?? 0 }
  }

  const fetchEmpleado = async (id: string) => {
    const { data, error } = await client.from('perfiles').select('*').eq('id', id).single()
    if (error) throw error
    return data as Perfil
  }

  const createEmpleado = async (payload: { nombre: string; email: string; password: string; rol: 'admin' | 'vendedor' }) => {
    return await $fetch('/api/empleados/create', { method: 'POST', body: payload })
  }

  const updateEmpleado = async (id: string, updates: { nombre?: string; email?: string; password?: string; rol?: 'admin' | 'vendedor' }) => {
    return await $fetch(`/api/empleados/${id}`, { method: 'PUT', body: updates })
  }

  const actualizarEstado = async (id: string, activo: boolean) => {
    const { data, error } = await client
      .from('perfiles')
      .update({ activo })
      .eq('id', id)
      .select()
      .single()

    if (error) throw error
    return data as Perfil
  }

  const deleteEmpleado = async (id: string) => {
    return await $fetch(`/api/empleados/${id}`, { method: 'DELETE' })
  }

  const friendlyError = (e: any): string => {
    const msg = e?.data?.message || e?.statusMessage || e?.message || ''
    if (/ya existe un usuario/i.test(msg)) return 'Ya existe un usuario con ese correo'
    if (/row-level security/i.test(msg)) return 'No tienes permisos para realizar esta acción'
    if (/network|fetch/i.test(msg)) return 'Sin conexión con el servidor. Intenta de nuevo'
    return msg || 'Ocurrió un error inesperado'
  }

  return { fetchEmpleados, fetchEmpleado, createEmpleado, updateEmpleado, actualizarEstado, deleteEmpleado, friendlyError }
}
