export interface DetalleCompra {
  id?: string
  id_compra?: string
  id_producto: string
  cantidad: number
  costo_unitario: number
  subtotal: number
}

export interface Compra {
  id?: string
  numero?: number
  numero_factura: string
  fecha: string
  id_proveedor: string
  subtotal: number
  iva: number
  total: number
  anulada?: boolean
  motivo_anulacion?: string | null
  anulada_por?: string | null
  anulada_at?: string | null
  corrige_compra_id?: string | null
  created_at?: string
  updated_at?: string
  proveedores?: { nombre: string }
  detalle_compras?: DetalleCompra[]
}

export const useCompras = () => {
  const client = useSupabaseClient()

  const fetchCompras = async (opts?: {
    search?: string
    page?: number
    rows?: number
    sortField?: string
    sortOrder?: number
    searchProveedor?: string
    desde?: string
    hasta?: string
    incluirAnuladas?: boolean
  }) => {
    const page = opts?.page ?? 0
    const rows = opts?.rows ?? 20
    const from = page * rows
    const to = from + rows - 1

    let query = client
      .from('compras')
      .select('*, proveedores!inner(nombre)', { count: 'exact' })

    const sortField = opts?.sortField || 'fecha'
    const isAscending = opts?.sortOrder === 1

    query = query.order(sortField, { ascending: isAscending })

    if (opts?.desde) query = query.gte('fecha', opts.desde)
    if (opts?.hasta) query = query.lte('fecha', opts.hasta)
    if (!opts?.incluirAnuladas) query = query.eq('anulada', false)

    if (opts?.search) {
      query = query.ilike('numero_factura', `%${opts.search}%`)
    }

    if (opts?.searchProveedor) {
      query = query.ilike('proveedores.nombre', `%${opts.searchProveedor}%`)
    }

    const { data, count, error } = await query.range(from, to)

    if (error) throw error
    return { data: data as Compra[], total: count ?? 0 }
  }

  const registrarCompra = async (
    compra: Omit<Compra, 'id' | 'created_at' | 'updated_at'>,
    detalles: DetalleCompra[]
  ) => {
    const { data: compraGuardada, error: errorCompra } = await client
      .from('compras')
      .insert([compra])
      .select()
      .single()

    if (errorCompra) throw errorCompra

    const detallesConId = detalles.map(d => ({
      ...d,
      id_compra: compraGuardada.id
    }))

    const { error: errorDetalles } = await client
      .from('detalle_compras')
      .insert(detallesConId)

    if (errorDetalles) {
      // Manual cleanup if details fail (since we aren't in a DB transaction here)
      await client.from('compras').delete().eq('id', compraGuardada.id)
      throw errorDetalles
    }

    return compraGuardada
  }

  const getCompraById = async (id: string) => {
    const { data, error } = await client
      .from('compras')
      .select(`
        *,
        proveedores(nombre, telefono, direccion),
        detalle_compras(*, productos(nombre, codigo_parte, stock)),
        anulada_por_perfil:perfiles!fk_compras_anulada_por_perfil(nombre)
      `)
      .eq('id', id)
      .single()

    if (error) throw error

    // Resolver compras enlazadas (origen y reemplazo) en queries separadas
    // para evitar embeds self-referenciales en PostgREST.
    const compra = data as any

    // Si está anulada, buscar posibles registros de auditoría de stock
    if (compra.anulada && compra.detalle_compras) {
      console.log('Buscando ajustes de seguridad para compra:', id)
      const { data: audits } = await client
        .from('inventario_auditoria')
        .select('producto_id, motivo')
        .ilike('motivo', `%${id}%`)
      
      console.log('Auditorías encontradas:', audits)

      if (audits && audits.length > 0) {
        compra.detalle_compras = compra.detalle_compras.map((d: any) => {
          const pId = d.id_producto || d.producto_id
          const audit = audits.find(a => 
            a.producto_id === pId && 
            (a.motivo.includes('AJUSTE_SEGURIDAD') || a.motivo.includes('ajuste'))
          )
          
          if (audit) {
            console.log('Ajuste detectado para producto:', pId)
            // Extraer el cálculo real del nuevo formato o del antiguo
            let valorReal = 'Stock insuficiente'
            if (audit.motivo.includes('|CALCULO:')) {
              valorReal = audit.motivo.split('|CALCULO:')[1]
            } else {
              const matches = audit.motivo.match(/\(Cálculo real: (.*?)\)/)
              if (matches) valorReal = matches[1]
            }
            
            return { ...d, ajuste_audit: `Ajuste: ${valorReal}` }
          }
          return d
        })
      }
    }

    let corrige = null
    if (compra.corrige_compra_id) {
      const { data: corrigeData } = await client
        .from('compras')
        .select('id, numero, fecha, numero_factura')
        .eq('id', compra.corrige_compra_id)
        .maybeSingle()
      corrige = corrigeData
    }

    const { data: reemplazoData } = await client
      .from('compras')
      .select('id, numero, fecha, numero_factura')
      .eq('corrige_compra_id', id)
      .maybeSingle()

    return { ...compra, corrige, reemplazo: reemplazoData }
  }

  const anularCompra = async (id: string, motivo: string) => {
    const { error } = await client.rpc('anular_compra', {
      p_compra_id: id,
      p_motivo: motivo
    })
    if (error) throw error
  }

  return {
    fetchCompras,
    registrarCompra,
    getCompraById,
    anularCompra
  }
}
