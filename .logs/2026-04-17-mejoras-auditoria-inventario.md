# Log: Mejoras en Auditoría de Inventario
**Fecha:** 2026-04-17

## Auditoría de Inventario
- **Privacidad y Claridad:** Se ocultó el campo `imagen_url` del modal de detalles para simplificar la información.
- **Identificación de Categorías:** Se implementó una lógica para resolver el ID de la categoría y mostrar el nombre real del departamento asignado al producto.
- **Filtro Avanzado:** 
  - Se añadió un selector específico por **Mes y Año** para la auditoría, independizándolo del rango de fechas global de reportes.
  - El sistema muestra por defecto los registros del mes en curso.
  - Se añadió un mensaje dinámico que indica qué período se está visualizando (ej: "Visualizando auditoría de Abril 2026").

## Archivos Modificados
- `app/pages/reportes/index.vue`
