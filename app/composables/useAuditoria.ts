export interface AuditoriaStockItem {
  id: string
  codigo_parte: string
  nombre: string
  stock_actual: number
  stock_inicial: number
  compras_periodo: number
  ventas_periodo: number
  ajustes_periodo: number
  stock_real_periodo: number
  categoria_nombre: string | null
  marca_nombre: string | null
  categoria_id: string | null
  marca_id: string | null
}

export const useAuditoria = () => {
  const client = useSupabaseClient()

  const fetchAuditoriaStock = async (desde: string, hasta: string) => {
    const { data, error } = await client.rpc('obtener_auditoria_inventario', {
      p_desde: desde,
      p_hasta: hasta
    })

    if (error) {
      console.error('Error fetching auditoria stock:', error)
      throw error
    }

    return (data || []) as AuditoriaStockItem[]
  }

  const fetchAuditoriaPagos = async (desde: string, hasta: string) => {
    const { data, error } = await client
      .from('ventas_pagos')
      .select('*, metodos_pago:metodo_pago_id(*), ventas:venta_id(*)')
      .gte('created_at', desde)
      .lte('created_at', hasta)
      .order('created_at', { ascending: false })

    if (error) {
      console.error('Error fetching auditoria pagos:', error)
      throw error
    }

    return data as any[]
  }

  return {
    fetchAuditoriaStock,
    fetchAuditoriaPagos
  }
}
