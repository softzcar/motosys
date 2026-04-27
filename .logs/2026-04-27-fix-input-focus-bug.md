# Log de Cambios - 2026-04-27 - Corrección Bug de Foco en Inputs

## Objetivo
Resolver el fallo donde al hacer click en un `InputNumber` el cursor se posicionaba al final del texto, impidiendo la sobreescritura rápida.

## Cambios Realizados
- **Eliminación de `selectOnFocus`:** Se eliminó la propiedad nativa de PrimeVue debido a su comportamiento inconsistente con el evento `click`.
- **Implementación de `@focus` Manual:** Se aplicó `@focus="$event => ($event.target as HTMLInputElement).select()"` en todos los campos numéricos del sistema (POS, Compras, Caja, Inventario, Configuración).

## Resultado
- Al hacer click en cualquier parte de un campo numérico, todo el contenido se resalta inmediatamente, permitiendo escribir el nuevo valor sin borrar manualmente el anterior.
