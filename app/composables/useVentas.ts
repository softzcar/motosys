import type { Venta } from '~/types/database'

export const useVentas = () => {
  const client = useSupabaseClient()

  const procesarVenta = async (
    items: { producto_id: string; cantidad: number; precio_unitario: number }[],
    pagos: { metodo_pago_id: string; monto_recibido: number; tasa_aplicada: number; monto_usd: number; referencia?: string | null }[],
    clienteId?: string,
    corrigeVentaId?: string
  ) => {
    const payload: any = {
        p_items: items,
        p_pagos: pagos
    }
    if (clienteId) {
      payload.p_cliente_id = clienteId
    }
    if (corrigeVentaId) {
      payload.p_corrige_venta_id = corrigeVentaId
    }

    const { data, error } = await client.rpc('procesar_venta', payload)

    if (error) throw error
    return data as string
  }

  const anularVenta = async (id: string, motivo: string) => {
    const { error } = await client.rpc('anular_venta', {
      p_venta_id: id,
      p_motivo: motivo
    })
    if (error) throw error
  }

  const fetchVentas = async (opts?: {
    desde?: string
    hasta?: string
    page?: number
    rows?: number
    sortField?: string
    sortOrder?: number
    searchCliente?: string
    vendedorId?: string
    incluirAnuladas?: boolean
  }) => {
    const page = opts?.page ?? 0
    const rows = opts?.rows ?? 20
    const from = page * rows
    const to = from + rows - 1

    const selectStr = opts?.searchCliente
      ? '*, clientes!inner(*), vendedor:perfiles!fk_ventas_vendedor(nombre), detalle_ventas(*, productos(nombre, codigo_parte)), ventas_pagos(*, metodos_pago(*))'
      : '*, clientes(*), vendedor:perfiles!fk_ventas_vendedor(nombre), detalle_ventas(*, productos(nombre, codigo_parte)), ventas_pagos(*, metodos_pago(*))'

    const sortField = opts?.sortField || 'fecha'
    const isAscending = opts?.sortOrder === 1

    let query = client
      .from('ventas')
      .select(selectStr, { count: 'exact' })
      .order(sortField, { ascending: isAscending })
      .range(from, to)

    if (opts?.desde) query = query.gte('fecha', opts.desde)
    if (opts?.hasta) query = query.lte('fecha', opts.hasta)
    if (!opts?.incluirAnuladas) query = query.eq('anulada', false)

    if (opts?.searchCliente) {
      query = query.ilike('clientes.nombre', `%${opts.searchCliente}%`)
    }

    if (opts?.vendedorId) {
      query = query.eq('vendedor_id', opts.vendedorId)
    }

    const { data, count, error } = await query
    if (error) throw error
    return { data: data as Venta[], total: count ?? 0 }
  }

  const fetchVentaById = async (id: string) => {
    const { data, error } = await client
      .from('ventas')
      .select(`
        *,
        clientes(*),
        vendedor:perfiles!fk_ventas_vendedor(nombre),
        detalle_ventas(*, productos(nombre, codigo_parte, precio_venta, stock)),
        ventas_pagos(*, metodos_pago(*)),
        anulada_por_perfil:perfiles!fk_ventas_anulada_por_perfil(nombre)
      `)
      .eq('id', id)
      .single()

    if (error) throw error

    // Resolver ventas enlazadas (origen y reemplazo) en queries separadas
    // para evitar embeds self-referenciales en PostgREST.
    const venta = data as any

    let corrige = null
    if (venta.corrige_venta_id) {
      const { data: corrigeData } = await client
        .from('ventas')
        .select('id, fecha, total')
        .eq('id', venta.corrige_venta_id)
        .maybeSingle()
      corrige = corrigeData
    }

    const { data: reemplazoData } = await client
      .from('ventas')
      .select('id, fecha, total')
      .eq('corrige_venta_id', id)
      .maybeSingle()

    return { ...venta, corrige, reemplazo: reemplazoData } as Venta
  }

  const fetchVendedoresConVentas = async (desde: string, hasta: string) => {
    // Obtenemos los perfiles de los vendedores que tienen al menos una venta en el rango
    const { data, error } = await client
      .from('ventas')
      .select('vendedor_id, vendedor:perfiles!fk_ventas_vendedor(id, nombre)')
      .gte('fecha', desde)
      .lte('fecha', hasta)
      .not('vendedor_id', 'is', null)

    if (error) throw error

    // Deduplicamos por ID de vendedor
    const uniqueVendedores = new Map()
    data.forEach((v: any) => {
      if (v.vendedor) {
        uniqueVendedores.set(v.vendedor.id, v.vendedor)
      }
    })

    return Array.from(uniqueVendedores.values())
  }

  return { procesarVenta, anularVenta, fetchVentas, fetchVentaById, fetchVendedoresConVentas }
}
