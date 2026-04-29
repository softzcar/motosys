import type { Marca } from '~/types/database'

export const useMarcas = () => {
  const client = useSupabaseClient()

  /**
   * Fetch all brands (for dropdowns / selects).
   */
  const fetchAllMarcas = async () => {
    const { data, error } = await client
      .from('marcas')
      .select('*')
      .order('nombre', { ascending: true })

    if (error) throw error
    return data as Marca[]
  }

  /**
   * Paginated / searchable fetch for the CRUD table.
   */
  const fetchMarcas = async (opts?: {
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
      .from('marcas')
      .select('*', { count: 'exact' })
      .order(opts?.sortField || 'nombre', { ascending: opts?.sortOrder === 1 })
      .range(from, to)

    if (opts?.search) {
      query = query.ilike('nombre', `%${opts.search}%`)
    }

    const { data, count, error } = await query
    if (error) throw error
    return { data: data as Marca[], total: count ?? 0 }
  }

  const createMarca = async (nombre: string) => {
    const { data, error } = await client
      .from('marcas')
      .insert({ nombre: nombre.trim() })
      .select()
      .single()

    if (error) throw error
    return data as Marca
  }

  const updateMarca = async (id: string, nombre: string) => {
    const { data, error } = await client
      .from('marcas')
      .update({ nombre: nombre.trim(), updated_at: new Date().toISOString() })
      .eq('id', id)
      .select()
      .single()

    if (error) throw error
    return data as Marca
  }

  const deleteMarca = async (id: string) => {
    const { error } = await client
      .from('marcas')
      .delete()
      .eq('id', id)

    if (error) throw error
  }

  /**
   * Friendly error messages for brand operations.
   */
  const friendlyError = (e: any): string => {
    const msg = e?.message || ''
    const code = e?.code || ''
    if (code === '23505' || /duplicate key|already exists/i.test(msg)) {
      return 'Ya existe una marca con ese nombre'
    }
    if (code === '23503' || /foreign key|still referenced/i.test(msg)) {
      return 'No se puede eliminar: hay productos asignados a esta marca'
    }
    if (/row-level security/i.test(msg)) return 'No tienes permisos para realizar esta acción'
    if (/network|fetch/i.test(msg)) return 'Sin conexión con el servidor. Intenta de nuevo'
    return msg || 'Ocurrió un error inesperado'
  }

  return {
    fetchAllMarcas,
    fetchMarcas,
    createMarca,
    updateMarca,
    deleteMarca,
    friendlyError
  }
}
