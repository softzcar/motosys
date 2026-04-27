# Log de Cambios - 2026-04-27 - Consistencia Matemática en Cierre de Caja

## Objetivo
Eliminar discrepancias de redondeo y diferencias "fantasmas" causadas por la fluctuación de la tasa de cambio entre el momento de la venta y el momento del cierre.

## Problema Identificado
El sistema comparaba dólares históricos (calculados al momento de cada venta) contra dólares actuales (calculados a la tasa del cierre). Esto generaba diferencias de centavos o dólares incluso cuando el monto en la moneda principal (BS/COP) era exacto.

## Cambios Realizados
1.  **Lógica de Diferencia por Fila:** La diferencia en USD ahora se calcula estrictamente dividiendo la diferencia de la moneda principal por la tasa actual del cierre.
2.  **Lógica de Totales:** El resumen lateral ahora suma las diferencias individuales en lugar de restar totales valuados con bases distintas.
3.  **Montos Clicables:** Se habilitó la función de copiar el monto del sistema al input de contado con un solo click, facilitando el trabajo del administrador.

## Resultado
- Si el monto contado coincide con el del sistema, la diferencia es **$0.00** exactos, tanto en la fila como en el resumen total.
- Se eliminó la confusión visual por devaluación acumulada durante el periodo de caja.
