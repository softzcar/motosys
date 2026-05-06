# Registro de Cambios - 06 de Mayo de 2026

## 1. Estándar Decimal Global
- **Configuración PrimeVue:** Se forzó el uso del punto (`.`) como separador decimal y la coma (`,`) como separador de miles en todos los componentes `InputNumber` del sistema.
- **Implementación:** Se aplicó la propiedad `locale="en-US"` de forma explícita en formularios de Inventario, Configuración, Caja, Compras y POS para garantizar consistencia absoluta independientemente del navegador.

## 2. Mejoras en la Selección de Productos (Compras)
- **Visualización:** Se añadió un **Tag Informativo** que muestra el SKU y Nombre del producto seleccionado, liberando el buscador para nuevas entradas.
- **Scanner Infrarrojo:** 
    - Al escanear un código existente, el producto se selecciona automáticamente y se muestra en el tag.
    - Si el código no existe, se abre automáticamente el modal de "Crear Nuevo Producto" con un aviso informativo.
- **Validación UX:** Los campos de Cantidad y Costo se inhabilitan y limpian automáticamente si no hay un producto confirmado en el tag.

## 3. Optimización de Escaneo en Punto de Venta (POS)
- **Carga Directa:** Al escanear un código de barras en el POS, el producto se añade directamente al carrito si existe y hay stock.
- **Limpieza de Interfaz:** El buscador manual y los resultados previos se limpian automáticamente tras un escaneo exitoso para mantener la pantalla despejada.

## 4. Corrección de Reporte de Compras
- **Restauración de Visibilidad:** Se eliminaron filtros de fecha restrictivos que impedían visualizar las compras registradas.
- **Sincronización:** Se alineó la lógica de carga con la página principal de compras (`/compras`), garantizando que los datos se rendericen correctamente.
- **Estadísticas:** Se añadieron tarjetas de resumen para "Total Inversión" y "Facturas Recibidas" en la pestaña de reportes.

## 5. Formulario de Producto (Contextual)
- **Campo Stock Inteligente:** El campo "Stock Inicial" ahora se oculta automáticamente cuando el producto se crea desde el módulo de Compras (ya que el stock lo asigna la factura), pero se mantiene visible en el módulo de Inventario para ajustes manuales.
- **Categoría y Marca:** Se reemplazaron los selectores simples por componentes de búsqueda `AutoComplete` (typehead) para una selección más fluida.
