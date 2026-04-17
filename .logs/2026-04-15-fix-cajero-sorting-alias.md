# Log: Corrección de Ordenamiento por Cajero en Reportes
Fecha: 2026-04-15

## Problema
Al intentar ordenar por la columna "Cajero" en el reporte de ventas, el sistema devolvía el error: `'perfiles' is not an embedded resource in this request`. Esto se debía a que en la consulta de Supabase (`useVentas.ts`), la tabla `perfiles` estaba siendo consultada con el alias `vendedor`.

## Solución Realizada
1.  **Vistas Actualizadas:** Se modificó el campo de ordenamiento en `app/pages/reportes/index.vue` y `app/pages/reportes/ventas.vue`.
2.  **Cambio de Campo:** Se reemplazó `field="perfiles(nombre)"` por `field="vendedor(nombre)"` para que coincida exactamente con el alias definido en la consulta `.select()`.
3.  **Consistencia:** Esto asegura que Postgrest reconozca correctamente el recurso embebido al aplicar el `.order()`.

## Verificación
Se confirma que el ordenamiento por Ticket, Fecha, Cliente, Cajero y Monto ahora funciona sin errores de servidor.
