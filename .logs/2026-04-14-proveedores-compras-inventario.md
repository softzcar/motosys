# 2026-04-14 — Proveedores, Compras e Inventario

## Base de Datos (Supabase)
- **Tablas nuevas**:
  - `public.proveedores`: Almacena nombre, teléfono y dirección de los proveedores. RLS habilitado.
  - `public.compras`: Registro de facturas de compra (número, fecha, proveedor, total).
  - `public.detalle_compras`: Desglose de ítems por factura (producto, cantidad, costo unitario, subtotal).
- **Integración de Inventario**:
  - Implementado trigger `trigger_update_stock_after_purchase` y función `update_stock_after_purchase`.
  - El stock de la tabla `productos` se incrementa automáticamente al insertar registros en `detalle_compras`.

## Lógica del Frontend (Composables)
- **`app/composables/useProveedores.ts`**:
  - Métodos: `fetchProveedores`, `crearProveedor`, `actualizarProveedor`, `eliminarProveedor`.
  - Manejo de errores específicos (ej: violación de FK al eliminar).
- **`app/composables/useCompras.ts`**:
  - Métodos: `fetchCompras`, `registrarCompra`, `getCompraById`.
  - `registrarCompra` realiza una inserción doble (cabecera y detalle) con manejo de errores.

## Interfaz de Usuario
- **`app/pages/proveedores/index.vue`**:
  - CRUD completo para proveedores.
  - Tabla con búsqueda global, paginación lazy y diálogos de PrimeVue para edición/creación.
- **`app/pages/compras/index.vue`**:
  - Listado histórico de compras.
  - Muestra número de factura, fecha (formateada), nombre del proveedor y total de la compra.
- **`app/pages/compras/nueva.vue`**:
  - Formulario de registro de compra.
  - Selector de proveedor (Dropdown filtrable).
  - Buscador de productos con `AutoComplete`.
  - Carrito de compras local que calcula subtotales y total general.
  - Validación de campos obligatorios antes de guardar.
- **`app/components/layout/AppSidebar.vue`**:
  - Añadidos items de navegación: "Compras" (icono `FileText`) y "Proveedores" (icono `Truck`).

## Notas
- La actualización de stock es robusta al estar delegada a un trigger de base de datos, garantizando consistencia independientemente de fallos en el frontend después del registro del ítem.
- Los iconos utilizados provienen de `lucide-vue-next` para mantener la consistencia visual del proyecto.
