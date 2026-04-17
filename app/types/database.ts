export interface Perfil {
  id: string
  nombre: string
  rol: 'admin' | 'vendedor'
  activo: boolean
  created_at: string
  updated_at: string
}

export interface CategoriaProducto {
  id: string
  nombre: string
  created_at: string
  updated_at: string
}

export interface Producto {
  id: string
  nombre: string
  codigo_parte: string
  stock: number
  precio_venta: number
  imagen_url: string | null
  activo: boolean
  categoria_id: string | null
  categorias_productos?: CategoriaProducto
  created_at: string
  updated_at: string
}

export interface Venta {
  id: string
  vendedor_id: string
  total: number
  fecha: string
  perfiles?: Perfil
  detalle_ventas?: DetalleVenta[]
}

export interface DetalleVenta {
  id: string
  venta_id: string
  producto_id: string
  cantidad: number
  precio_unitario: number
  productos?: Producto
}

export interface CartItem {
  producto: Producto
  cantidad: number
  precio_unitario: number
}
