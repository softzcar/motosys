import { useSupabaseClient } from '#imports'

export interface CierrePreview {
  metodo_pago_id: string
  nombre: string
  moneda: string
  monto_sistema: number
  monto_sistema_usd: number
  total_ventas: number
  total_ingresos: number
  total_egresos: number
}

export interface CierreCaja {
  id: string
  fecha: string
  fecha_hora_cierre: string
  responsable_id: string
  total_sistema_usd: number
  total_contado_usd: number
  diferencia_usd: number
  observaciones: string | null
  created_at: string
  responsable?: { id: string; nombre: string }
  cierres_caja_detalle?: CierreDetalle[]
}

export interface CierreDetalle {
  id: string
  cierre_id: string
  metodo_pago_id: string
  monto_sistema: number
  monto_contado: number
  diferencia: number
  monto_sistema_usd: number
  monto_contado_usd: number
  tasa_referencia: number
  metodos_pago?: { id: string; nombre: string; moneda: string }
}

export const useCierresCaja = () => {
  const client = useSupabaseClient()

  const previewCierre = async () => {
    const { data, error } = await client.rpc('preview_cierre_caja')
    if (error) throw error
    return (data ?? []) as CierrePreview[]
  }

  const ejecutarCierre = async (
    fecha: string,
    detalles: { metodo_pago_id: string; monto_contado: number; tasa_referencia: number }[],
    observaciones?: string | null
  ) => {
    const { data, error } = await client.rpc('ejecutar_cierre_caja', {
      p_fecha: fecha,
      p_detalles: detalles,
      p_observaciones: observaciones ?? null
    })
    if (error) throw error
    return data as string
  }

  const fetchCierres = async (opts?: {
    desde?: string
    hasta?: string
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
      .from('cierres_caja')
      .select('*, responsable:perfiles(id, nombre), cierres_caja_detalle(*, metodos_pago(id, nombre, moneda))', {
        count: 'exact'
      })
      .order(opts?.sortField || 'fecha', { ascending: opts?.sortOrder === 1 })
      .range(from, to)

    if (opts?.desde) query = query.gte('fecha', opts.desde)
    if (opts?.hasta) query = query.lte('fecha', opts.hasta)

    const { data, count, error } = await query
    if (error) throw error
    return { data: (data ?? []) as CierreCaja[], total: count ?? 0 }
  }

  const fetchCierreById = async (id: string) => {
    const { data, error } = await client
      .from('cierres_caja')
      .select('*, responsable:perfiles(id, nombre), cierres_caja_detalle(*, metodos_pago(id, nombre, moneda))')
      .eq('id', id)
      .single()
    if (error) throw error
    return data as CierreCaja
  }

  return { previewCierre, ejecutarCierre, fetchCierres, fetchCierreById }
}
