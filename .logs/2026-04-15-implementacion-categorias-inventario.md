# Log: Implementación de Sistema de Categorías de Inventario

**Fecha:** 2026-04-15
**Autor:** Antigravity

## Contexto
El usuario solicitó la capacidad de categorizar los items del inventario. Esto implica la creación de un catálogo de categorías, la vinculación de productos a estas categorías y la mejora de la UI para permitir la gestión y el filtrado por categoría.

## Cambios Realizados

### 1. Base de Datos (Supabase)
- **Migración:** Se creó la tabla `public.categorias_productos`.
  - Columnas: `id` (uuid), `nombre` (text, unique), `created_at`, `updated_at`.
- **Relación:** Se añadió la columna `categoria_id` (uuid) a la tabla `public.productos` como llave foránea.
- **Seguridad (RLS):**
  - Lectura permitida para todos los usuarios autenticados.
  - Escritura (Insert/Update/Delete) restringida solo a usuarios con rol 'admin'.

### 2. Capa de Datos (Composables y Tipos)
- **Tipos:** Se actualizó `app/types/database.ts` para incluir la interfaz `CategoriaProducto` y actualizar `Producto`.
- **Nuevo Composable:** `app/composables/useCategoriasProductos.ts`.
  - Implementa CRUD completo para categorías.
  - Manejo de errores específicos (ej. impedir borrar categorías con productos asociados).
- **Actualización Composable:** `app/composables/useProductos.ts`.
  - Se modificó `fetchProductos` para incluir un JOIN con `categorias_productos` y soportar el filtro por `categoriaId`.

### 3. Interfaz de Usuario (UI)
- **Gestión de Categorías:** Nueva página en `app/pages/inventario/categorias/index.vue` con tabla CRUD y modales de edición.
- **Formulario de Producto:** Actualizado `app/components/inventario/ProductoForm.vue`.
  - Se añadió selector de categoría.
  - **Función Inline:** Botón "+" (verde sólido, cuadrado) para añadir categorías sin salir del formulario. Auto-selección automática al crear.
- **Tabla de Inventario:** Actualizado `app/components/inventario/ProductoTable.vue`.
  - Nueva columna "Categoría" con etiquetas visuales.
  - Nuevo filtro desplegable en el toolbar para filtrar por categoría.
- **Standard UI:** Se documentó en `GEMINI.md` el estándar para botones de añadir ("+") para mantener consistencia en todo el proyecto.

## Verificación
- Se verificó el flujo completo: creación de categoría -> asignación a producto -> filtrado en tabla principal.
- Se confirmó la protección de integridad referencial (no borrar categorías en uso).
- Se validó el diseño de los botones conforme a los estándares acordados.

## Archivos Involucrados
- `supabase/migrations/...` (vía `mcp_supabase_apply_migration`)
- `app/types/database.ts`
- `app/composables/useCategoriasProductos.ts`
- `app/composables/useProductos.ts`
- `app/components/inventario/ProductoForm.vue`
- `app/components/inventario/ProductoTable.vue`
- `app/pages/inventario/index.vue`
- `app/pages/inventario/categorias/index.vue`
- `GEMINI.md`
