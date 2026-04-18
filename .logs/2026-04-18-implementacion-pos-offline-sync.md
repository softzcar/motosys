# Log de Implementación: Resiliencia Offline y Sincronización Global

## Contexto
Se detectó la necesidad de permitir la operación del Punto de Venta (POS) durante caídas de internet, garantizando la integridad de los datos y la sincronización automática posterior.

## Cambios Realizados

### 1. Motor de Base de Datos Local (IndexedDB)
- **Tecnología**: Dexie.js.
- **Esquema (v1)**:
  - `productos`: Caché de catálogo (1000 items).
  - `clientes`: Caché de clientes frecuentes.
  - `tasas`: Sincronización de códigos BCV/PARALELO/COP.
  - `metodos_pago`: Configuración de cobro disponible offline.
  - `ventas_pendientes`: Cola de despacho de facturas.

### 2. Composables y Stores
- **`useNetworkStore` (Pinia)**: Centraliza el estado de red y sincronización. Implementa un 'Heartbeat' (latido) cada 30s para verificar conexión real con Supabase.
- **`useOfflineDb`**: Provee métodos para cachear datos maestros y registrar ventas en local.
- **`useSync`**: Motor global que procesa la cola de ventas, registra clientes nuevos creados offline y sube facturas a la nube.

### 3. Punto de Venta (POS)
- **Búsqueda Híbrida**: Implementada en `PosProductSearch.vue` y búsqueda de clientes. Cambia a modo local instantáneamente ante desconexión.
- **Guardado Híbrido**: La función `finalizarVenta` detecta el estado de red y decide si enviar a RPC `procesar_venta` o guardar en Dexie.
- **Blindaje de Foco**: Restaurada y protegida la lógica de ráfaga de enfoque para rapidez de operación con teclado.

### 4. Interfaz Global
- **Barra Superior**: Añadido indicador dinámico de conexión y mensaje de "Sincronizando..." con icono animado.
- **Notificaciones**: Eliminación masiva de componentes `<Toast />` y `<ConfirmDialog />` locales para centralizar el flujo de mensajes en el Layout Global.

## Resultados
- Operación 100% funcional sin conexión para ventas y consultas.
- Sincronización automática de clientes y facturas al recuperar red.
- Experiencia de usuario limpia con notificaciones únicas y feedback de red constante.
