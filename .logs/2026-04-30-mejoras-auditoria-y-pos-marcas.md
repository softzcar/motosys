# Registro de Cambios - 30 de Abril de 2026

## Cambios Realizados

### Auditoría de Inventario
- **Mejora del Detalle de Auditoría:** Se restauró y potenció la visualización de cambios en los productos dentro de la pestaña de incidencias.
  - Implementación de lógica comparativa campo por campo entre `valor_anterior` y `valor_nuevo`.
  - Mapeo de IDs de categorías y marcas a sus nombres reales para facilitar la lectura.
  - Diseño de UI mejorado con resaltado de cambios (rojo para anterior, verde para nuevo) y visualización de metadatos (usuario, fecha, motivo).
  - Soporte para visualización completa del estado previo en registros de eliminación (`DELETE`).

### Punto de Venta (POS)
- **Selector de Marcas (F5):**
  - Creación del componente `PosBrandSelector.vue` para navegación visual por marcas.
  - Asignación del atajo de teclado **F5** para el acceso rápido a marcas.
  - Unificación visual del buscador:
    - Botón de Categorías (**F4**) actualizado a color azul (`info`) para coincidir con su etiqueta.
    - Nuevo botón de Marcas (**F5**) en color ámbar para distinción visual clara.
  - Integración de filtrado por marca tanto en modo online como offline (vía Dexie).
- **Simplificación de Interfaz:**
  - Diálogo de cliente: "Limpiar / Nuevo" simplificado a "Limpiar".
  - Diálogo de cliente: "Continuar a Pago" simplificado a "Pagar".

## Archivos Afectados
- `app/pages/reportes/index.vue`
- `app/components/pos/PosBrandSelector.vue` (Nuevo)
- `app/components/pos/PosProductSearch.vue`
- `app/pages/pos/index.vue`
