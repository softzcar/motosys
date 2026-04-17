import type { Producto, CartItem } from '~/types/database'

export const useCartStore = defineStore('cart', () => {
  const items = ref<CartItem[]>([])

  const addItem = (producto: Producto): boolean => {
    const existing = items.value.find(i => i.producto.id === producto.id)

    if (existing) {
      if (existing.cantidad >= producto.stock) return false
      existing.cantidad++
    } else {
      if (producto.stock < 1) return false
      items.value.push({
        producto,
        cantidad: 1,
        precio_unitario: Number(producto.precio_venta)
      })
    }
    return true
  }

  const removeItem = (productoId: string) => {
    items.value = items.value.filter(i => i.producto.id !== productoId)
  }

  const updateQuantity = (productoId: string, cantidad: number) => {
    const item = items.value.find(i => i.producto.id === productoId)
    if (!item) return
    if (cantidad <= 0) return removeItem(productoId)
    if (cantidad > item.producto.stock) return
    item.cantidad = cantidad
  }

  const total = computed(() =>
    items.value.reduce((sum, i) => sum + i.cantidad * i.precio_unitario, 0)
  )

  const itemCount = computed(() =>
    items.value.reduce((sum, i) => sum + i.cantidad, 0)
  )

  const toRpcPayload = () =>
    items.value.map(i => ({
      producto_id: i.producto.id,
      cantidad: i.cantidad,
      precio_unitario: i.precio_unitario
    }))

  const clear = () => {
    items.value = []
  }

  const seedItem = (producto: Producto, cantidad: number, precioUnitario: number) => {
    items.value.push({
      producto,
      cantidad,
      precio_unitario: precioUnitario
    })
  }

  return { items, addItem, removeItem, updateQuantity, total, itemCount, toRpcPayload, clear, seedItem }
})
