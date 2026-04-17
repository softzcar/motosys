# Log de Ajustes de Interfaz para Tema Lara y Escala 14px

Fecha: 17 de abril de 2026

## Cambios Realizados

### 1. Unificación de Detalle de Ventas
- Se implementó el componente `ReportesVentaReciboDetalle` en todo el sistema (Dashboard, Historial de Ventas y Reporte Analítico).
- Se eliminó la funcionalidad de impresión y sus componentes asociados (`PrintTicket.vue`, `VentaDetalle.vue`).

### 2. Activación de Ordenamiento en Tablas
- **Ventas**: Activado ordenamiento por "Estado" (`anulada`), "Cajero" y "Cliente" usando sintaxis de relaciones de Supabase.
- **Compras**: Activado ordenamiento por "Proveedor" (`proveedores(nombre)`), "Total" y "Estado".

### 3. Optimización Global de Componentes (CSS)
- **Escala base**: Establecida en `14px` para mayor densidad de datos.
- **Botones Cuadrados**: Se creó una regla global para `.p-button.aspect-square` que elimina el padding y centra los iconos. Esto soluciona el error donde los iconos desaparecían en el tema Lara debido al espaciado por defecto.
- **Accesibilidad**: Se garantizó un tamaño mínimo de `2.5rem` para botones de acción, optimizando la experiencia táctil en móviles.
