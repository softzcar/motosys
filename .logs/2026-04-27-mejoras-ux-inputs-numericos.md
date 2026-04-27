# Log de Cambios - 2026-04-27 - Mejora de UX en Inputs Numéricos

## Objetivo
Corregir el comportamiento inconsistente de los campos numéricos (`InputNumber`) al recibir el foco mediante clicks del ratón, asegurando que el contenido se seleccione automáticamente para facilitar su edición.

## Cambios Realizados

### 1. Estandarización de `selectOnFocus`
- Se añadió la propiedad `selectOnFocus` a todos los componentes `InputNumber` en los módulos críticos del sistema:
  - **POS:** Entrada de abonos y montos de pago.
  - **Compras:** Edición de costos, cantidades e IVA.
  - **Cierre de Caja:** Entrada de montos contados físicos.
  - **Inventario:** Edición de precios y stock en el formulario de productos.
  - **Configuración:** Edición de tasas de cambio y porcentaje de IVA.

## Impacto
- **Velocidad de Operación:** Los usuarios ya no necesitan borrar manualmente el valor por defecto ("0.00") al hacer click; cualquier tecla presionada sobreescribirá el valor seleccionado.
- **Consistencia:** El comportamiento al hacer click ahora es idéntico al comportamiento al usar la tecla Tabulador, eliminando la fricción en la entrada de datos.
