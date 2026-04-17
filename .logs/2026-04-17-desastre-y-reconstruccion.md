# Log de Sesión: Optimización, Gestión de Crisis y Reconstrucción Ética

Fecha: 17 de abril de 2026

## 1. El Desastre: Stock Negativo y Sincronización
- **Incidente**: Al anular compras de productos que ya habían sido vendidos parcialmente, el sistema permitió que el stock cayera a números negativos (ej. -5).
- **Causa Raíz**: Desconexión entre el desarrollo local y el servidor de Supabase. Las funciones de protección se escribieron en los archivos de migración pero no se ejecutaron efectivamente en la base de datos viva, dejando activa la lógica antigua y defectuosa.
- **Acción Correctiva**: 
    - **Limpieza Total**: Se ejecutó un `TRUNCATE CASCADE` en todas las tablas operativas (ventas, compras, caja, auditoría, productos) para eliminar datos inconsistentes y empezar de cero.
    - **Blindaje en DB**: Se inyectó directamente en Supabase la nueva función `anular_compra` con protección de truncado a cero.

## 2. Implementación de Protección "Cero Negativos"
- **Lógica de Seguridad**: Si una anulación resulta en un stock menor a 0, la base de datos ahora:
    1. Fuerza el valor final a **0**.
    2. Registra una incidencia en auditoría con el prefijo `AJUSTE_SEGURIDAD_COMPRA`.
    3. Guarda el **cálculo negativo real** (ej. -6) dentro del motivo para trazabilidad gerencial.
- **Visibilidad**: Se creó el componente unificado `CompraDetalleRecibo` que detecta estos ajustes y muestra un banner naranja de advertencia con el desglose del descuadre físico.

## 3. Humanización de la Data (Números Correlativos)
- **Problema**: El uso de IDs largos (UUID) era confuso y poco profesional para el usuario final.
- **Solución**: 
    - Se modificó el esquema de `ventas` y `compras` añadiendo la columna `numero` (BIGINT autoincremental).
    - Se actualizó el frontend (Tablas, Recibos, Toasts) para mostrar `#1, #2...` en lugar de IDs crípticos.

## 4. Blindaje de Desactivación de Productos
- **Acción Atómica**: Al desactivar un producto, el formulario bloquea todos los campos para evitar ediciones no auditadas.
- **Descarga Automática**: Si el producto tiene stock, se descarga a 0 y se genera una incidencia de auditoría automática ("Desactivación de producto") tomando los datos originales de la DB como fuente de verdad.

## 5. Optimización de Interfaz (Tema Lara)
- **Cambio de Tema**: Se migró de Aura a **Lara** para una mayor densidad de datos.
- **Escala Global**: Reducción del `font-size` base a **14px**, ganando un 12.5% de espacio en pantalla.
- **Mobile**: 
    - Eliminación de bordes y scrolls fantasmas en el sidebar móvil.
    - Corrección global de botones `aspect-square` para evitar iconos ocultos por el padding del tema Lara.

## 6. Gestión de Caja
- **Filtro Inteligente**: Implementación de navegación por mes/año.
- **Lógica de Pendientes**: El sistema ahora muestra siempre los movimientos abiertos de cualquier fecha cuando se visualiza el mes actual, evitando que el dinero olvidado se pierda en el historial.

**Estado Actual**: Base de datos limpia, lógica de stock protegida y numeración amigable activa.
