# Log: Corrección Spinner Infinito en Edición de Inventario
Fecha: 2026-04-15

## Problema
Al intentar editar un producto en la página de inventario (`/inventario/[id]`), la página se quedaba con un spinner de carga infinito. Esto se debía a que la función `loadProducto`, encargada de buscar los detalles del producto en la base de datos, estaba definida pero no se invocaba al cargar la página.

## Solución
Se modificó `app/pages/inventario/[id].vue`:
- Se añadió la llamada `onMounted(loadProducto)` para asegurar que la carga de datos se dispare automáticamente cuando el usuario entra a la página de edición.

## Verificación
Con este cambio, la página ahora llama correctamente a Supabase, obtiene los datos del producto y desactiva el estado `loading`, permitiendo que el formulario de edición se muestre correctamente.
