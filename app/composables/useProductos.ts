import type { Producto } from '~/types/database'

export const useProductos = () => {
  const client = useSupabaseClient()

  const fetchProductos = async (opts?: {
    search?: string
    page?: number
    rows?: number
    sortField?: string
    sortOrder?: number
    soloActivos?: boolean
    categoriaId?: string | null
    ubicacion?: string | null
    maxStock?: number
  }) => {
    const page = opts?.page ?? 0
    const rows = opts?.rows ?? 20
    const from = page * rows
    const to = from + rows - 1

    let query = client
      .from('productos')
      .select('*, categorias_productos(nombre)', { count: 'exact' })

    // Ordenamiento
    const sortField = opts?.sortField || 'nombre'
    const isAscending = opts?.sortOrder === 1
    query = query.order(sortField, { ascending: isAscending })

    if (opts?.soloActivos === true) {
      query = query.eq('activo', true)
    } else if (opts?.soloActivos === false) {
      query = query.eq('activo', false)
    }

    if (opts?.maxStock !== undefined) {
      query = query.lte('stock', opts.maxStock)
    }

    if (opts?.categoriaId) {
      query = query.eq('categoria_id', opts.categoriaId)
    }

    if (opts?.ubicacion) {
      query = query.eq('ubicacion', opts.ubicacion)
    }

    if (opts?.search) {
      query = query.or(
        `nombre.ilike.%${opts.search}%,codigo_parte.ilike.%${opts.search}%`
      )
    }

    const { data, count, error } = await query.range(from, to)
    if (error) throw error
    return { data: data as Producto[], total: count ?? 0 }
  }

  const fetchUbicaciones = async () => {
    const { data, error } = await client
      .from('productos')
      .select('ubicacion')
    
    if (error) throw error
    
    // Extraer valores únicos, eliminar nulos/vacíos y ordenar alfabéticamente
    const unique = Array.from(new Set(data.map(i => i.ubicacion)))
      .filter(val => val !== null && val !== undefined && val.trim() !== '')
      .sort((a, b) => a.localeCompare(b))
    
    return unique
  }

  const findByCodigo = async (codigo: string) => {
    const { data, error } = await client
      .from('productos')
      .select('*')
      .eq('codigo_parte', codigo)
      .eq('activo', true)
      .single()

    if (error) throw error
    return data as Producto
  }

  const createProducto = async (producto: Partial<Producto>) => {
    const { data, error } = await client
      .from('productos')
      .insert(producto)
      .select()
      .single()

    if (error) throw error
    return data as Producto
  }

  const updateProducto = async (id: string, updates: Partial<Producto>) => {
    const { data, error } = await client
      .from('productos')
      .update(updates)
      .eq('id', id)
      .select()
      .single()

    if (error) throw error
    return data as Producto
  }

  const softDeleteProducto = async (id: string) => {
    const { error } = await client
      .from('productos')
      .update({ activo: false })
      .eq('id', id)

    if (error) throw error
  }

  const updateProductoConMotivo = async (id: string, updates: Partial<Producto>, motivo: string) => {
    const { data, error } = await client.rpc('editar_producto_con_motivo', {
      p_id: id,
      p_data: updates,
      p_motivo: motivo
    })
    if (error) throw error
    return data as Producto
  }

  const eliminarProductoConMotivo = async (id: string, motivo: string) => {
    const { error } = await client.rpc('eliminar_producto_con_motivo', {
      p_id: id,
      p_motivo: motivo
    })
    if (error) throw error
  }

  const fetchInventarioAuditoria = async (opts?: {
    desde?: string
    hasta?: string
    page?: number
    rows?: number
    accion?: 'UPDATE' | 'DELETE'
    search?: string
  }) => {
    const page = opts?.page ?? 0
    const rows = opts?.rows ?? 20
    const from = page * rows
    const to = from + rows - 1

    let query = client
      .from('inventario_auditoria')
      .select('*, usuario:perfiles!fk_inventario_auditoria_usuario_perfil(nombre)', { count: 'exact' })
      .order('created_at', { ascending: false })
      .range(from, to)

    if (opts?.desde) query = query.gte('created_at', opts.desde)
    if (opts?.hasta) query = query.lte('created_at', opts.hasta)
    if (opts?.accion) query = query.eq('accion', opts.accion)
    if (opts?.search) {
      query = query.or(
        `nombre.ilike.%${opts.search}%,codigo_parte.ilike.%${opts.search}%`
      )
    }

    const { data, count, error } = await query
    if (error) throw error
    return { data: data as any[], total: count ?? 0 }
  }

  const fetchInventarioStats = async () => {
    let totalVenta = 0
    let bajoStockCount = 0
    let totalItems = 0

    // Bucle para iterar y traer todos los registros activos esquivando el paginador de Supabase
    let desde = 0
    const limit = 1000
    let hasMore = true

    while (hasMore) {
      const { data, error } = await client
        .from('productos')
        .select('stock, precio_venta')
        .eq('activo', true)
        .range(desde, desde + limit - 1)

      if (error) throw error

      if (data && data.length > 0) {
        for (const item of data) {
          const s = item.stock || 0
          const venta = item.precio_venta || 0

          totalVenta += (s * venta)
          totalItems += s
          
          if (s < 5) bajoStockCount++
        }
        
        desde += limit
        hasMore = data.length === limit
      } else {
        hasMore = false
      }
    }

    return {
      totalVenta,
      bajoStockCount,
      totalItems
    }
  }

  /**
   * Convierte errores crudos de Supabase/Postgres en mensajes amigables.
   */
  const friendlyError = (e: any): string => {
    const msg = e?.message || ''
    const code = e?.code || ''
    if (code === '23505' || /duplicate key|already exists/i.test(msg)) {
      return 'Ya existe un producto con ese código de parte'
    }
    if (code === '23514') return 'Algún valor numérico no cumple las restricciones (revisa stock y precio)'
    if (/row-level security/i.test(msg)) return 'No tienes permisos para realizar esta acción'
    if (/network|fetch/i.test(msg)) return 'Sin conexión con el servidor. Intenta de nuevo'
    return msg || 'Ocurrió un error inesperado'
  }

  return {
    fetchProductos,
    findByCodigo,
    createProducto,
    updateProducto,
    softDeleteProducto,
    updateProductoConMotivo,
    eliminarProductoConMotivo,
    fetchInventarioAuditoria,
    fetchInventarioStats,
    friendlyError
  }
}
