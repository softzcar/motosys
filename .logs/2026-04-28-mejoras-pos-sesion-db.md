# Log de Cambios - 28 de Abril de 2026

## 1. Corrección de Sesión y Autenticación
- **Middleware de Autenticación:** Se ajustó `auth.global.ts` para que el sistema utilice el perfil local inmediatamente si Supabase tarda en responder tras un refresco de página.
- **Sincronización Global:** Se añadió un observador (watcher) en `app.vue` que refresca el perfil online en cuanto el usuario de Supabase está disponible, asegurando consistencia de datos.

## 2. Optimización de Base de Datos Offline (Dexie)
- **Purga de Datos:** Se refactorizó la función `purgeOldData` en `useOfflineDb.ts` para evitar errores de `IDBKeyRange` (IndexedDB) al limpiar registros antiguos sincronizados.
- **Resiliencia:** Ahora la purga es una operación silenciosa que no bloquea el arranque de la aplicación en caso de errores en la base de datos local.

## 3. Implementación de Explorador de Categorías en POS
- **Nuevo Componente:** Se creó `PosCategorySelector.vue`, un panel lateral (Drawer) que permite navegar por categorías y añadir productos al carrito sin cerrar el explorador.
- **Soporte Offline:** Las categorías ahora se cachean en Dexie para permitir la navegación por categorías sin conexión a internet.
- **Integración:** Se añadió el botón de acceso rápido en el buscador del POS.

## 4. Mejoras de UX en Punto de Venta (POS)
- **Identificación de Clientes:** El botón "Continuar a Pago" ahora realiza una búsqueda automática si el cajero olvidó presionar "Buscar", mejorando la fluidez del proceso.
- **Gestión de Pagos:** 
  - Se implementó la limpieza automática del selector de moneda tras añadir un pago.
  - Se añadió validación para evitar métodos de pago duplicados en la misma factura.

## 5. Estabilización de Tasas de Cambio
- **Migración SQL:** Se creó la migración formal para la tabla `tasas_cambio`.
- **Autocuración:** El composable `useTasas.ts` ahora inicializa automáticamente las tasas base (BCV, Paralelo, COP) si detecta que la tabla está vacía, garantizando que el POS siempre pueda calcular precios.

## 6. Ajustes Técnicos
- **PWA Dev Mode:** Se desactivó el Service Worker en modo desarrollo para evitar problemas de caché (versiones obsoletas de la app) y se silenciaron advertencias de glob patterns en `nuxt.config.ts`.
