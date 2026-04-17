# Log de Optimización para Dispositivos Móviles y PWA

Fecha: 17 de abril de 2026

## Cambios Realizados

### 1. Configuración de Metadatos y PWA (`nuxt.config.ts`)
- **Viewport**: Se añadió `viewport-fit=cover` para aprovechar toda la pantalla en dispositivos con notch (iPhone, etc.) y `user-scalable=0` para evitar zooms accidentales en inputs.
- **Soporte iOS**: Se incluyeron etiquetas `apple-mobile-web-app-capable`, `apple-mobile-web-app-status-bar-style: black-translucent` y `apple-mobile-web-app-title`.
- **Manifiesto PWA**: Se actualizaron los iconos para incluir la propiedad `purpose: 'any maskable'`, asegurando una visualización correcta en diversos lanzadores de aplicaciones (especialmente Android).

### 2. Mejora de UX en Punto de Venta (`app/pages/pos/index.vue`)
- **Sistema de Pestañas**: Se implementó una interfaz de tabs (Búsqueda / Carrito) exclusiva para la vista móvil.
- **Badge de Carrito**: Se añadió un contador visual en la pestaña del carrito para que el usuario sepa cuántos productos lleva sin necesidad de cambiar de vista.
- **Optimización de Espacio**: Se eliminó la necesidad de scroll vertical excesivo al apilar componentes, permitiendo una operación más rápida.

### 3. Gestión de Actualizaciones (`app/components/PwaUpdate.vue` y `app/app.vue`)
- **Notificación de Versión**: Se creó un componente dedicado que detecta cuando hay una nueva versión del Service Worker lista para ser instalada.
- **Botón de Recarga**: Permite al usuario actualizar la aplicación de forma instantánea sin perder el estado de la sesión, mejorando la fiabilidad de la PWA instalada.
