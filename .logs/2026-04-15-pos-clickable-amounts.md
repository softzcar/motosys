# Log: Montos Clicables en POS
Fecha: 2026-04-15

## Problema
El proceso de cobro multimoneda requería que el cajero transcribiera manualmente los montos calculados en Bs o COP mostrados en el resumen del modal "Finalizar Cobro".

## Solución
Se modificó `app/pages/pos/index.vue` para permitir la copia rápida de montos:
- Se implementó la función `setMontoAbono(val)` que redondea a 2 decimales y actualiza el estado `montoAbono`.
- Se añadieron manejadores `@click` a las etiquetas del Total en Bs, PENDIENTE (Bs/COP) y VUELTO (Bs/COP).
- Se aplicaron estilos de cursor (`cursor-pointer`) y subrayado en hover para mejorar la usabilidad.

## Verificación
La lógica fue integrada en el componente principal del POS y se verificó que la actualización del estado `montoAbono` se refleja correctamente en el componente `InputNumber` de PrimeVue.
