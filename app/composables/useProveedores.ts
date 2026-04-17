export interface Proveedor {
  id?: string
  nombre: string
  telefono: string | null
  direccion: string | null
  activo?: boolean
  created_at?: string
  updated_at?: string
}

export const useProveedores = () => {
  const client = useSupabaseClient()

  const fetchProveedores = async (opts?: {
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
      .from('proveedores')
      .select('*', { count: 'exact' })
      .order(opts?.sortField || 'nombre', { ascending: opts?.sortOrder === 1 || !opts?.sortField })

    if (opts?.search) {
      query = query.ilike('nombre', `%${opts.search}%`)
    }

    const { data, count, error } = await query.range(from, to)

    if (error) throw error
    return { data: data as Proveedor[], total: count ?? 0 }
  }

  const crearProveedor = async (proveedor: Omit<Proveedor, 'id' | 'created_at' | 'updated_at' | 'activo'>) => {
    const { data, error } = await client
      .from('proveedores')
      .insert([proveedor])
      .select()
      .single()

    if (error) throw error
    return data as Proveedor
  }

  const actualizarProveedor = async (id: string, updates: Partial<Proveedor>) => {
    const { data, error } = await client
      .from('proveedores')
      .update(updates)
      .eq('id', id)
      .select()
      .single()

    if (error) throw error
    return data as Proveedor
  }

  const eliminarProveedor = async (id: string) => {
    const { data, error } = await client
      .from('proveedores')
      .delete()
      .eq('id', id)
      .select()

    if (error) {
       if (error.code === '23503') {
          throw new Error('No se puede eliminar el proveedor porque tiene compras asociadas.')
       }
       throw error
    }
  }

  return {
    fetchProveedores,
    crearProveedor,
    actualizarProveedor,
    eliminarProveedor
  }
}
