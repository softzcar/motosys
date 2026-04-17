# Log de Cambio de Tema y Compactación de Interfaz

Fecha: 17 de abril de 2026

## Cambios Realizados

### 1. Transición de Tema Aura a Lara (`nuxt.config.ts`)
- **Motivo**: El tema Aura proporcionaba una interfaz demasiado "espaciada" para un sistema con alta densidad de datos y controles.
- **Acción**: Se cambió el preset de PrimeVue a **Lara**, el cual ofrece un diseño más compacto, denso y profesional, ideal para paneles de gestión y puntos de venta.

### 2. Reducción de Escala Global (`app/assets/css/main.css`)
- **Acción**: Se estableció el `font-size` base del `html` en **14px** (anteriormente 16px).
- **Resultado**: Gracias al uso de unidades `rem` en PrimeVue, todos los componentes (paddings, gaps, tamaños de fuente, iconos) se redujeron proporcionalmente en un **12.5%**, permitiendo visualizar significativamente más información en la misma pantalla sin perder legibilidad.

### 3. Ajuste de Sidebar Móvil (Finalización)
- **Corrección Estética**: Se eliminó definitivamente el recuadro blanco residual del `Drawer` mediante el uso de directivas `!important` y la propiedad `pt` (Passthrough) de PrimeVue 4, logrando una integración visual perfecta con el fondo oscuro del sidebar.
