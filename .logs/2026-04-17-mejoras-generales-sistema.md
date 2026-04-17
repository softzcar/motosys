# Log: Mejoras en Dashboard, POS, Seguridad y Gestión de Entidades
**Fecha:** 2026-04-17

## 1. Panel de Control (Dashboard)
- **Datos Reales:** Se reemplazaron todas las etiquetas de ejemplo por métricas en tiempo real (Ventas del día, Clientes nuevos, Bajo Stock).
- **Gráfico de Tendencia:** 
  - Ahora soporta vista **Semanal** y **Mensual**.
  - Corregido error de maquetación donde el tooltip del día con más ventas se cortaba (ajuste a 85% de altura máxima).
- **Tasas del Día:** 
  - Se reemplazó la tarjeta de stock por un monitor de divisas (BCV, Paralelo, COP).
  - Se creó el componente reutilizable `TasasForm.vue`.
  - Se implementó un modal para actualizar tasas directamente desde el inicio.
- **Actividad Reciente:** 
  - Se cambió la columna "Usuario" por "Cliente".
  - Se añadió botón de "ojo" para ver el detalle de la factura en un modal sin salir del inicio.
- **Navegación:** Las tarjetas de estadísticas ahora actúan como accesos directos a sus respectivos módulos.
- **Limpieza:** Se eliminó el botón "Descargar Reporte" no funcional.

## 2. Punto de Venta (POS)
- **UX del Carrito:** Se movió el **Total** y el botón **Procesar Venta** a la parte superior del carrito para que el cajero siempre tenga acceso a la acción principal sin importar el largo de la lista.

## 3. Seguridad y Roles
- **Acceso Restringido (Vendedor):** 
  - El Sidebar ahora solo muestra "Punto de Venta" para usuarios con rol 'vendedor'.
  - Se implementó redirección automática: si un vendedor intenta entrar al Inicio (`/`), el sistema lo lleva a `/pos`.

## 4. Gestión de Empleados (Mejoras Pro)
- **Sistema de Activación:**
  - Nueva columna `activo` en la tabla `perfiles` (vía migración SQL).
  - Capacidad de **Desactivar/Reactivar** empleados en lugar de borrarlos.
  - Filtro para "Ver Inactivos" en la tabla.
- **Borrado Seguro:** 
  - Se mejoró el backend y frontend para impedir el borrado permanente de empleados con historial de ventas, sugiriendo su desactivación.
  - Corregido error de modales anidados en la confirmación de eliminación.

## 5. Proveedores y Métodos de Pago
- **Borrado con Validación:** Se implementó el manejo de errores de integridad referencial. Si un proveedor o método de pago está en uso, el sistema notifica al usuario en lugar de fallar silenciosamente.
- **Correcciones UI:** Se añadió el componente `<Toast />` faltante en proveedores y se corrigió la visibilidad de notificaciones en errores de borrado.

## Archivos Modificados
- `app/pages/index.vue` (Dashboard completo)
- `app/components/pos/PosCart.vue` (Layout POS)
- `app/components/layout/AppSidebar.vue` (Permisos de menú)
- `app/components/configuracion/TasasForm.vue` (Nuevo componente)
- `app/components/empleados/EmpleadoTable.vue` (Toggle de estado)
- `app/composables/useEmpleados.ts`, `useMetodosPago.ts` (Nuevas funciones)
- `server/api/empleados/[id].delete.ts` (Manejo de errores mejorado)
- `app/pages/configuracion.vue`, `app/pages/proveedores/index.vue`, `app/pages/empleados/index.vue`
- `supabase/migrations/20260417_add_activo_to_perfiles.sql` (Base de datos)
