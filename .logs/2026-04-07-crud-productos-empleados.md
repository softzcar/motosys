# 2026-04-07 — CRUD Productos & Empleados

## Productos
- **`app/components/ImagePlaceholder.vue`** *(nuevo)*: placeholder minimalista con icono `ImageOff` (lucide), fondo `slate-50`, borde punteado. Tamaño y rounded configurables.
- **`app/components/inventario/ProductoForm.vue`**: reescrito.
  - Validaciones: nombre (3–120), código (2–60), stock entero ≥0, precio >0.
  - Mensajes amigables por campo, marca `:invalid` en PrimeVue.
  - Selector de imagen opcional con preview, validación de tipo y peso (≤2 MB), botón "quitar imagen", flag `removeImagen`.
  - Estado `loading` y emit con payload `{ values, imagen, removeImagen }`.
- **`app/components/inventario/ProductoTable.vue`**: nueva columna (72px) con miniatura o `ImagePlaceholder` (48px).
- **`app/composables/useProductos.ts`**:
  - `uploadImagen` ahora envía `contentType` correcto, conserva extensión y agrega cache-bust `?v=timestamp`.
  - `removeImagen(url)` extrae el path del bucket y borra el objeto.
  - `friendlyError(e)` mapea `23505` → "código duplicado", `23514`, errores RLS, errores de red.
- **`app/pages/inventario/nuevo.vue`** y **`[id].vue`**: adaptados al nuevo payload del form, suben/borran imagen, muestran toasts amigables.

## Empleados (CRUD nuevo, solo admin)
- **`server/api/empleados/create.post.ts`**: verifica sesión + rol admin del solicitante, crea `auth.user` con `empresa_id` heredada (trigger crea el perfil), valida nombre/email/password, maneja duplicados (409).
- **`server/api/empleados/[id].delete.ts`**: verifica admin, prohíbe auto-eliminación, valida que el target esté en la misma empresa, borra `auth.user` (cascade elimina el perfil).
- **`app/composables/useEmpleados.ts`**: `fetchEmpleados`, `fetchEmpleado`, `createEmpleado` (server), `updateEmpleado` (RLS cliente: nombre/rol), `deleteEmpleado` (server), `friendlyError`.
- **`app/components/empleados/EmpleadoForm.vue`**: validado (nombre, email regex, password ≥8, confirmación, rol). En modo edición oculta email/contraseña.
- **`app/components/empleados/EmpleadoTable.vue`**: búsqueda con debounce, paginación lazy, tag de rol, botón eliminar deshabilitado para el usuario actual.
- **Páginas**: `app/pages/empleados/{index,nuevo,[id]}.vue` con guardas para no-admins.
- **`app/components/layout/AppSidebar.vue`**: nuevo item "Empleados" (icono `Users`), visible solo para admin.

## Notas / pendientes
- Update de empleado solo cubre nombre y rol (vía RLS). Cambio de email o reset de contraseña requeriría endpoint server con `admin.auth.admin.updateUserById`.
- Bucket `product-images` ya existe en `supabase/schema.sql` con policies por `empresa_id`.
- Requiere en `.env`: `SUPABASE_URL` y `NUXT_SUPABASE_SERVICE_ROLE_KEY` para que los endpoints server funcionen.
