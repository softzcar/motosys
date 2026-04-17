import type { Database } from '~/types/database'

export interface Cliente {
  id?: string
  cedula: string
  nombre: string
  telefono: string | null
  created_at?: string
  updated_at?: string
}

export const useClientes = () => {
  const client = useSupabaseClient()

  // Buscar todos paginados o con filtro
  const fetchClientes = async (opts?: {
    search?: string
    page?: number
    rows?: number
    sortField?: string
    sortOrder?: number
  }) => {
    const page = opts?.page ?? 0
    const rows = opts?.rows ?? 20
    const from = page * rows
    const to = from + rows - 1

    let query = client
      .from('clientes')
      .select('*', { count: 'exact' })
      .order(opts?.sortField || 'nombre', { ascending: opts?.sortOrder === 1 || !opts?.sortField })

    if (opts?.search) {
      query = query.or(`cedula.ilike.%${opts.search}%,nombre.ilike.%${opts.search}%`)
    }

    const { data, count, error } = await query.range(from, to)

    if (error) throw error
    return { data: data as Cliente[], total: count ?? 0 }
  }

  // Buscar por cédula específico (para el POS)
  const getClienteByCedula = async (cedula: string) => {
    const { data, error } = await client
      .from('clientes')
      .select('*')
      .eq('cedula', cedula)
      .maybeSingle()

    if (error) throw error
    return data as Cliente | null
  }

  // Crear nuevo cliente
  const crearCliente = async (cliente: Omit<Cliente, 'id' | 'created_at' | 'updated_at'>) => {
    const { data, error } = await client
      .from('clientes')
      .insert([cliente])
      .select()
      .single()

    if (error) throw error
    return data as Cliente
  }

  // Actualizar cliente
  const actualizarCliente = async (id: string, updates: Partial<Cliente>) => {
    const { data, error } = await client
      .from('clientes')
      .update(updates)
      .eq('id', id)
      .select()
      .single()

    if (error) throw error
    return data as Cliente
  }

  // Eliminar cliente (Fallará silenciosamente sin RLS o con error SQL si tiene facturas por la FK RESTRICT)
  const eliminarCliente = async (id: string) => {
    const { data, error } = await client
      .from('clientes')
      .delete()
      .eq('id', id)
      .select()

    if (error) {
       if (error.code === '23503') { // Fk violation
          throw new Error('No se puede eliminar el cliente porque tiene ventas asignadas.')
       }
       throw error
    }

    if (!data || data.length === 0) {
       throw new Error('No se pudo eliminar el cliente. (Permiso denegado o no encontrado)')
    }
  }

  return {
    fetchClientes,
    getClienteByCedula,
    crearCliente,
    actualizarCliente,
    eliminarCliente
  }
}
