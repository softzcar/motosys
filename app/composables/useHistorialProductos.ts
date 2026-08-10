import type { Producto } from '~/types/database'

export interface HistorialProductoCompra {
  id: string
  compra_id: string
  numero_compra: number
  numero_factura: string | null
  fecha: string
  proveedor_nombre: string
  cantidad: number
  costo_unitario: number
  anulada: boolean
}

export interface HistorialProductoAjuste {
  id: string
  fecha: string
  accion: string
  usuario_nombre: string
  motivo: string | null
  stock_anterior: number
  stock_nuevo: number
  diferencia: number
}

export interface HistorialProductoVenta {
  id: string
  venta_id: string
  numero_venta: number
  fecha: string
  cliente_nombre: string
  cantidad: number
  precio_unitario: number
  subtotal: number
  anulada: boolean
}

export interface HistorialProductoItem {
  producto: Producto
  compras: HistorialProductoCompra[]
  ajustes: HistorialProductoAjuste[]
  ventas: HistorialProductoVenta[]
  resumen: {
    totalComprado: number
    totalAjustado: number
    totalVendido: number
    stockActual: number
  }
}

export const useHistorialProductos = () => {
  const client = useSupabaseClient()

  const fetchHistorialProducto = async (productoId: string): Promise<{
    compras: HistorialProductoCompra[]
    ajustes: HistorialProductoAjuste[]
    ventas: HistorialProductoVenta[]
  }> => {
    // 1. Obtener Compras
    const { data: rawCompras, error: errorCompras } = await client
      .from('detalle_compras')
      .select(`
        id,
        cantidad,
        costo_unitario,
        compras:id_compra (
          id,
          numero,
          numero_factura,
          fecha,
          anulada,
          proveedores:id_proveedor (nombre)
        )
      `)
      .eq('id_producto', productoId)

    if (errorCompras) throw errorCompras

    const compras: HistorialProductoCompra[] = (rawCompras || [])
      .filter((d: any) => d.compras)
      .map((d: any) => ({
        id: d.id,
        compra_id: d.compras.id,
        numero_compra: d.compras.numero,
        numero_factura: d.compras.numero_factura,
        fecha: d.compras.fecha,
        proveedor_nombre: d.compras.proveedores?.nombre || 'Sin Proveedor',
        cantidad: d.cantidad || 0,
        costo_unitario: d.costo_unitario || 0,
        anulada: !!d.compras.anulada
      }))
      .sort((a, b) => new Date(b.fecha).getTime() - new Date(a.fecha).getTime())

    // 2. Obtener Ajustes de Auditoría
    const { data: rawAjustes, error: errorAjustes } = await client
      .from('inventario_auditoria')
      .select(`
        id,
        created_at,
        accion,
        motivo,
        valor_anterior,
        valor_nuevo,
        usuario:perfiles!fk_inventario_auditoria_usuario_perfil(nombre)
      `)
      .eq('producto_id', productoId)
      .order('created_at', { ascending: false })

    if (errorAjustes) throw errorAjustes

    const ajustes: HistorialProductoAjuste[] = (rawAjustes || []).map((a: any) => {
      const prevStock = a.valor_anterior?.stock ?? 0
      const nextStock = a.valor_nuevo?.stock ?? prevStock
      return {
        id: a.id,
        fecha: a.created_at,
        accion: a.accion,
        usuario_nombre: a.usuario?.nombre || 'Sistema',
        motivo: a.motivo,
        stock_anterior: prevStock,
        stock_nuevo: nextStock,
        diferencia: nextStock - prevStock
      }
    })

    // 3. Obtener Ventas
    const { data: rawVentas, error: errorVentas } = await client
      .from('detalle_ventas')
      .select(`
        id,
        cantidad,
        precio_unitario,
        ventas:venta_id (
          id,
          numero,
          fecha,
          anulada,
          clientes:cliente_id (nombre)
        )
      `)
      .eq('producto_id', productoId)

    if (errorVentas) throw errorVentas

    const ventas: HistorialProductoVenta[] = (rawVentas || [])
      .filter((v: any) => v.ventas)
      .map((v: any) => {
        const cant = v.cantidad || 0
        const precio = v.precio_unitario || 0
        return {
          id: v.id,
          venta_id: v.ventas.id,
          numero_venta: v.ventas.numero,
          fecha: v.ventas.fecha,
          cliente_nombre: v.ventas.clientes?.nombre || 'Cliente General',
          cantidad: cant,
          precio_unitario: precio,
          subtotal: cant * precio,
          anulada: !!v.ventas.anulada
        }
      })
      .sort((a, b) => new Date(b.fecha).getTime() - new Date(a.fecha).getTime())

    return { compras, ajustes, ventas }
  }

  return {
    fetchHistorialProducto
  }
}
