# Log de Cambios - 29 de Abril de 2026

## Tarea: Corrección de Interfaz POS y Optimización PWA

### Cambios Realizados

#### 1. Estilos Globales (`app/assets/css/main.css`)
- Se redefinió `.pos-grid` para utilizar `grid-template-rows: auto 1fr` en dispositivos móviles (antes `height: auto`).
- Esto evita que los botones de navegación ("Buscar" y "Carrito") se estiren verticalmente para llenar la pantalla.
- Se cambió la altura de `calc(100vh - 5rem)` a `100%` para una mejor integración con el contenedor padre.

#### 2. Página POS (`app/pages/pos/index.vue`)
- Se reemplazó `min-h-screen` por `h-full` y se añadió `overflow-hidden` al contenedor principal.
- Se eliminó el relleno (`p-4 md:p-6`) que causaba doble scroll al sumarse al padding del layout base.
- Se eliminó el margen inferior (`mb-4`) en el selector de pestañas móvil para optimizar el espacio vertical.

### Resultados
- Los botones de navegación móvil ahora tienen un tamaño proporcional y estético.
- Desapareció el scroll innecesario en la versión instalada (PWA) y en escritorio.
- El POS ahora ocupa exactamente el área disponible entre la Topbar y el borde inferior.
