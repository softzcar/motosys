# Log de Cambios - 24 de Abril de 2026 (Parte 3)

## Tareas Realizadas: Blindaje de Estabilidad y Modo Offline

### 1. Protección de Navegación Offline
- **Middleware Global:** Se ha endurecido el middleware `auth.global.ts` para bloquear **cualquier ruta** que no sea `/pos`, `/login` o `/forbidden` cuando el sistema detecta que está offline. Esto evita que el usuario intente cargar páginas que requieren base de datos online.
- **Sidebar Endurecido:** Se añadió `e.stopPropagation()` en `AppSidebar.vue` para detener el motor de Nuxt antes de que intente cambiar de página si no hay conexión, eliminando intentos de carga fallidos.

### 2. Silenciamiento de Errores Técnicos
- **usePerfil:** Se silenciaron los errores de tipo `fetch` o conexión en el composable de perfil. Ahora estos errores se registran como advertencias en la consola (`console.warn`) pero no disparan notificaciones Toast rojas, mejorando la limpieza visual en condiciones de red inestable.

### 3. Corrección de Error Crítico en POS
- **Inyección de Perfil:** Se corrigió un fallo en `app/pages/pos/index.vue` donde se intentaba acceder a la variable `perfil` sin haberla inyectado, lo que causaba el bloqueo del proceso al emitir facturas.
- **Validación de Vendedor:** Se añadió una validación explícita en el proceso de venta online para asegurar que el ID del vendedor esté presente. Si por alguna razón no se detecta la sesión, el sistema pide refrescar la página en lugar de generar una factura sin autor.

### 4. Consistencia Online/Offline
- Se mejoró la recuperación de sesión al pasar de offline a online, asegurando que el sistema refresque los permisos de administrador/vendedor sin perder el estado actual del carrito o del cliente seleccionado.
