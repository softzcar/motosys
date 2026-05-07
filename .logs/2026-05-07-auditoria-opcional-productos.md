# Registro de Cambios - 07 de Mayo de 2026

## Flexibilización de Auditoría de Productos
- **Motivo Opcional:** Se modificó el proceso de edición de productos para que el motivo del cambio sea opcional, facilitando ediciones rápidas sin comprometer la trazabilidad.
- **Base de Datos (RPC):** Se actualizó la función `editar_producto_con_motivo` en el backend (PostgreSQL):
    - Se eliminó la restricción técnica de 10 caracteres mínimos.
    - Se implementó una lógica de respaldo que asigna el valor **"Sin motivo especificado"** si el campo se deja vacío.
- **Sincronización de Migraciones:** Se aplicó el cambio de forma consistente en todos los archivos SQL que definen o actualizan la función (`migration_inventario_auditoria.sql`, `20260429_create_marcas.sql` y scripts temporales).
- **Mejoras en UI:** 
    - El diálogo de "Motivo de cambio" ahora muestra explícitamente la etiqueta **"(Opcional)"**.
    - Se eliminaron las validaciones de bloqueo del botón "Guardar" y el contador de caracteres mínimos.
