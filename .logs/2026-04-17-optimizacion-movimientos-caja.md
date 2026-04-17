# Log de Optimización de Carga y Filtrado de Caja

Fecha: 17 de abril de 2026

## Cambios Realizados

### 1. Filtrado Dinámico por Periodo (`app/pages/caja/index.vue`)
- Se sustituyó el interruptor de "Mes en curso" por un selector de mes/año (`DatePicker`).
- Se implementó el cálculo automático del rango de fechas basado en el periodo seleccionado.
- Se corrigieron errores de referencia a variables no definidas.

### 2. Lógica de Consulta Mejorada (`app/composables/useMovimientosCaja.ts`)
- Se refinó la consulta a Supabase para permitir un filtrado híbrido:
    - Recupera movimientos dentro del rango de fechas del periodo seleccionado.
    - **Siempre recupera movimientos sin cerrar** (`cierre_id is null`), garantizando que los pendientes de meses anteriores permanezcan visibles hasta que se procesen.
- Se optimizó el uso del operador `.or()` para manejar estas condiciones de forma eficiente en una sola petición.

### 3. Usabilidad
- El diseño del filtro de caja ahora es consistente con el resto del sistema, utilizando el mismo patrón visual que la sección de Reportes.
