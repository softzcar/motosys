import { useSupabaseClient } from '#imports'

export type TipoMovimiento = 'ingreso' | 'egreso'

export interface MovimientoCaja {
  id: string
  tipo: TipoMovimiento
  metodo_pago_id: string
  monto: number
  tasa_aplicada: number
  monto_usd: number
  motivo: string
  referencia: string | null
  responsable_id: string
  cierre_id: string | null
  fecha: string
  created_at: string
  metodos_pago?: { id: string; nombre: string; moneda: string }
  responsable?: { id: string; nombre: string }
}

export const useMovimientosCaja = () => {
  const client = useSupabaseClient()

  const registrarMovimiento = async (payload: {
    tipo: TipoMovimiento
    metodo_pago_id: string
    monto: number
    tasa_aplicada: number
    motivo: string
    referencia?: string | null
  }) => {
    const { data, error } = await client.rpc('registrar_movimiento_caja', {
      p_tipo: payload.tipo,
      p_metodo_pago_id: payload.metodo_pago_id,
      p_monto: payload.monto,
      p_tasa_aplicada: payload.tasa_aplicada,
      p_motivo: payload.motivo,
      p_referencia: payload.referencia ?? null
    })
    if (error) throw error
    return data as string
  }

  const fetchMovimientos = async (opts?: {
    desde?: string
    hasta?: string
    tipo?: TipoMovimiento
    metodoPagoId?: string
    responsableId?: string
    cierreId?: string | null
    page?: number
    rows?: number
    sortField?: string
    sortOrder?: number
    soloAbiertosOMesActual?: boolean
  }) => {
    const page = opts?.page ?? 0
    const rows = opts?.rows ?? 20
    const from = page * rows
    const to = from + rows - 1

    let query = client
      .from('movimientos_caja')
      .select(
        '*, metodos_pago(id, nombre, moneda), responsable:perfiles(id, nombre)',
        { count: 'exact' }
      )
      .order(opts?.sortField || 'fecha', { ascending: opts?.sortOrder === 1 })

    if (opts?.soloAbiertosOMesActual) {
      const desde = opts.desde || new Date(0).toISOString()
      const hasta = opts.hasta || new Date().toISOString()
      query = query.or(`cierre_id.is.null,and(fecha.gte.${desde},fecha.lte.${hasta})`)
    } else {
      if (opts?.desde) query = query.gte('fecha', opts.desde)
      if (opts?.hasta) query = query.lte('fecha', opts.hasta)
    }

    if (opts?.tipo) query = query.eq('tipo', opts.tipo)
    if (opts?.metodoPagoId) query = query.eq('metodo_pago_id', opts.metodoPagoId)
    if (opts?.responsableId) query = query.eq('responsable_id', opts.responsableId)
    if (opts?.cierreId === null) query = query.is('cierre_id', null)
    else if (opts?.cierreId) query = query.eq('cierre_id', opts.cierreId)

    const { data, count, error } = await query.range(from, to)
    if (error) throw error
    return { data: (data ?? []) as MovimientoCaja[], total: count ?? 0 }
  }

  return { registrarMovimiento, fetchMovimientos }
}
