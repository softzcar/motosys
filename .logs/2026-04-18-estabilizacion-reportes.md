# Log de Estabilización de Reportes e Implementación de Imprimibles

Fecha: 18 de abril de 2026

## Mejoras Realizadas

### 1. Sistema Global de Reportes (Tamaño Carta)
- **Componentes Creados**: Se implementaron 3 nuevos reportes imprimibles (`InventarioChecklistReport`, `VentasResumenReport`, `ComprasResumenReport`) y `CierresHistorialReport`.
- **Estandarización**: Todos los reportes cumplen con la norma estricta de maquetación en tamaño carta (Alta densidad, fuentes pequeñas, diseño limpio en B/N).
- **Filtros Dinámicos**: Los reportes capturan automáticamente el rango de fechas global y los filtros de búsqueda locales aplicados en la interfaz antes de imprimir.

### 2. Estabilización de Navegación (Tabs)
- **Corrección de Error Crítico**: Se solucionó el error `nextSibling` que colapsaba la página al cambiar de pestañas en `/reportes`.
- **Estrategia**: Se aislaron los componentes de reporte fuera de los `TabPanel` y se sustituyó la directiva `v-if` por `v-show`. Esto evita que Vue destruya y recree nodos complejos en el DOM, garantizando una navegación instantánea y sin errores.
- **Sincronización Manual**: Se reemplazó el `v-model` por una asignación manual (`@update:value`) para evitar conflictos de estado interno en los componentes de PrimeVue.

### 3. Blindaje de Ejecución
- **Protección de Datos Nulos**: Se mejoró la función `formatCurrency` en todos los reportes para que sea defensiva frente a valores `undefined` o `null`, retornando `$0.00` y previniendo cierres inesperados.
- **Impresión Segura**: Se sustituyeron las llamadas inline a `window.print()` por una función dedicada en el script, resolviendo los errores `TypeError` en el entorno Nuxt.
- **Gestión de Ubicaciones**: Se corrigió el flujo de extracción de estantes en el inventario, derivando las ubicaciones dinámicamente desde los productos cargados y utilizando un arreglo simple de strings para asegurar compatibilidad con el selector.
