# Log de Cambios - 24 de Abril de 2026

## Tareas Realizadas

### 1. Interfaz y Navegación (Sidebar)
- **Reorganización del Menú:** Se renombró la opción "Inicio" por "Resumen Gerencial" y se movió debajo de "Punto de Venta" para priorizar el flujo operativo.
- **Corrección de Infinite Loop:** Se aplicó `markRaw()` a todos los iconos de Lucide en `AppSidebar.vue` y `index.vue`. Esto soluciona el error `Maximum call stack size exceeded` que ocurría al intentar hacer reactivos componentes de iconos complejos.
- **Control de Acceso:** Se implementó una redirección automática para vendedores: si intentan entrar a la raíz (`/`), el sistema los envía directamente al POS.

### 2. Nuevo Tablero: Resumen Gerencial (`/`)
- **Dashboard Administrativo:** Se creó una nueva página de inicio para administradores que incluye:
  - Tarjetas de estadísticas (Ventas del día, Cierres, Stock bajo, Clientes nuevos).
  - Lista de actividad reciente del sistema.
  - Accesos rápidos a funciones críticas (POS, Inventario, Reportes).
- **Optimización de Componentes:** Se ajustaron los botones de PrimeVue para usar el prop `text` (estándar del proyecto) en lugar de `variant="text"`.

### 3. Estabilidad y Resiliencia Offline
- **Blindaje de Perfil:** Se añadió un **Timeout de 5 segundos** a la carga de perfil online para evitar pantallas en blanco por latencia de red.
- **Silent Errors:** Se silenciaron los mensajes de error técnicos (`Failed to fetch`) durante el modo offline en el Middleware y Composables, mejorando la UX en dispositivos móviles.
- **Refresco Automático:** Al recuperar la conexión, el sistema ahora refresca el perfil del usuario automáticamente para asegurar que el rol (admin/vendedor) sea el correcto.

### 4. Optimización PWA y Móvil
- **Pantalla Completa:** Se configuró el manifiesto para modo `standalone` y `viewport-fit=cover`.
- **Integración Visual:** Se ajustaron los colores de fondo y de tema (`#0f172a`) para que la pantalla de carga y la barra de estado se integren perfectamente en Android e iOS.
