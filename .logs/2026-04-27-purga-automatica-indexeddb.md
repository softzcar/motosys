# Log de Cambios - 2026-04-27 - Purga Automática de IndexedDB

## Objetivo
Implementar un sistema de limpieza automática para la base de datos local (IndexedDB) que elimine registros antiguos ya sincronizados para prevenir el crecimiento excesivo del almacenamiento en la PWA.

## Cambios Realizados

### 1. Motor de Purga en `useOfflineDb.ts`
- Se implementó la función `purgeOldData(tables, ttlDays)`.
- **Escalabilidad:** Permite definir qué tablas limpiar y cuántos días mantener los datos (TTL).
- **Lógica:** Filtra registros donde `sincronizada === true` y la `fecha` es anterior al umbral de días definido (por defecto 7 días).

### 2. Persistencia Temporal en `useSync.ts`
- Se modificó el motor de sincronización para que no elimine las ventas inmediatamente después de subirlas con éxito.
- Ahora las ventas permanecen en IndexedDB con `sincronizada: true`, permitiendo un historial local reciente.
- Se integró la llamada a `purgeOldData()` al finalizar ciclos de sincronización de catálogo y de facturas.

### 3. Ejecución al Inicio en `app.vue`
- Se añadió la llamada a `purgeOldData()` en el `onMounted` de la aplicación principal para asegurar limpieza periódica incluso si no hay ventas pendientes.

## Impacto
- **Rendimiento:** Mantiene la base de datos ligera.
- **UX:** Permite que el usuario vea facturas recientes en modo offline aunque ya hayan sido sincronizadas.
- **Robustez:** Evita errores de almacenamiento lleno en dispositivos móviles con cuotas de IndexedDB limitadas.
