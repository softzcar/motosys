# Log de Cambios - 28 de Abril de 2026 (Parte 2)

## 1. Corrección de Despliegue (Vercel/Build)
- **Fix Nuxt Config:** Se eliminó la propiedad inválida `suppressWarnings: true` de la configuración de Workbox en `nuxt.config.ts`. Esta propiedad causaba un error fatal en el validador de Workbox durante el build, impidiendo el despliegue en Vercel.
- **Validación Local:** Se verificó la construcción exitosa mediante `npm run build`.

## 2. Blindaje de Arranque Offline
- **Middleware Global:** Se reestructuró `auth.global.ts` para evitar llamadas a `useSupabaseUser()` cuando el sistema detecta que está offline.
- **Resolución de Pantalla en Blanco:** Al diferir la inicialización de Supabase, se eliminó el bloqueo por error de red (petición JWKS fallida), permitiendo que la aplicación cargue instantáneamente usando el perfil local de IndexedDB.

## 3. Mejoras en Punto de Venta (POS)
- **Atajos de Teclado:** Se implementó la tecla **F4** como acceso rápido para abrir/cerrar el Explorador de Categorías (`PosCategorySelector.vue`).
- **Interfaz:** Se añadió una leyenda visual en el buscador del POS indicando el nuevo atajo (**F4: Categorías**).

## 4. Estado de Git
- Cambios confirmados y listos para `git push`.
