# Registro de Cambios - 07 de Mayo de 2026

## Persistencia de Compras (Borradores Locales)
- **Funcionalidad de Pausa y Resumen:** Se implementó un sistema de guardado automático local para el proceso de creación de compras, permitiendo a los usuarios interrumpir cargas de facturas largas sin perder datos.
- **IndexedDB (OfflineDB):**
    - Se actualizó el esquema de la base de datos local (Dexie) a la versión 5, añadiendo la tabla `compras_borradores`.
    - Se crearon métodos especializados (`saveCompraDraft`, `getCompraDraft`, `clearCompraDraft`) para gestionar el estado persistente de la sesión de compra.
- **Auto-Guardado (Nueva Compra):** 
    - Se integró un observador (`watcher`) con **debounce** en la página de creación de compras que respalda automáticamente el carrito y los datos de la factura en IndexedDB ante cualquier cambio.
    - Se implementó una exclusión automática para el modo "Corregir Compra Anulada", evitando que las correcciones pisen el borrador principal.
- **Gestión de Recuperación:**
    - Se añadió un **Banner de Detección** que aparece al entrar al módulo si existe un borrador previo.
    - El usuario puede optar por **"Continuar Compra"** (restaurando todo el estado previo) o **"Descartar"** el borrador para iniciar una carga limpia.
    - El borrador se purga automáticamente al registrar la compra con éxito en el servidor.
