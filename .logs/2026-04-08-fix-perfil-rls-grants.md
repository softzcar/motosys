# 2026-04-08 — Depuración acceso al CRUD de empleados

## Contexto inicial
El usuario reportó que el CRUD de empleados creado el día anterior no aparecía en el sidebar. El item existía en `app/components/layout/AppSidebar.vue:13` pero estaba condicionado a `isAdmin`, y `isAdmin` se evaluaba como `false` aun cuando la fila de `perfiles` tenía `rol = 'admin'`.

## Problemas encontrados y resueltos

### 1. `usePerfil.fetchPerfil` frágil
- **Síntoma:** el fetch fallaba en silencio (`catch` vacío) y `perfil.value` quedaba `null`.
- **Causa:** no filtraba por `id = user.id` (dependía 100% de RLS) y usaba `.single()` con join `empresas(*)`, que lanza error si el join devuelve 0/≠1 filas.
- **Fix** (`app/composables/usePerfil.ts`):
  - Filtrar explícitamente `.eq('id', uid)`.
  - Cambiar a `.maybeSingle()`.
  - Loguear el error en consola en vez de tragárselo.

### 2. Columna `productos.activo` inexistente
- **Síntoma:** error `column productos.activo does not exist` al cargar inventario.
- **Causa:** la base de datos en Supabase tenía un schema desactualizado respecto a `supabase/schema.sql`.
- **Fix:** el usuario hizo `DROP SCHEMA public CASCADE; CREATE SCHEMA public;` y reaplicó `schema.sql` completo.

### 3. `permission denied for schema public` tras el rebuild
- **Causa:** `DROP SCHEMA public CASCADE` borra los `GRANT` por defecto que Supabase otorga a `anon`, `authenticated`, `service_role`.
- **Fix:** ejecutar script de `GRANT USAGE / ALL` sobre schema, tablas, secuencias y funciones, más `ALTER DEFAULT PRIVILEGES`.
- **Lección a futuro:** evitar `DROP SCHEMA public CASCADE`. Preferir `DROP TABLE ... CASCADE` por tabla para conservar grants.

### 4. Confusión sobre el flujo de registro
- El usuario se había suscrito directamente desde el panel Authentication de Supabase, saltándose `/api/empresa/create`. Resultado: usuario en `auth.users` sin `empresa_id` en `user_metadata` → trigger `handle_new_user` falla o crea perfil incompleto.
- **Resolución:** registrarse desde `/register` (formulario de 2 pasos), que llama al endpoint y crea empresa + usuario admin con metadata correcta.

### 5. `id=eq.undefined` en la query a `perfiles`
- **Síntoma:** request `…/perfiles?id=eq.undefined` → error `invalid input syntax for type uuid`.
- **Causa:** el `watch(user, …)` en `app/layouts/default.vue` disparaba `fetchPerfil` antes de que `user.value.id` estuviera hidratado.
- **Fix:**
  - `app/composables/usePerfil.ts`: guard `const uid = user.value?.id; if (!uid) return`.
  - `app/layouts/default.vue`: `watch(() => user.value?.id, …)` en vez de observar el objeto user completo.

### 6. Sidebar seguía sin mostrar "Empleados" pese a JWT con `rol=admin`
- **Causa raíz sospechada:** la policy RLS sobre `perfiles` usa `get_my_empresa_id()`; tras el rebuild del schema esta función `SECURITY DEFINER` quedó sin `EXECUTE` para `authenticated`, devuelve NULL, y ninguna fila pasa el filtro → `fetchPerfil` retorna `null` sin error.
- **Workaround inmediato** (`app/composables/usePerfil.ts`): `isAdmin` y `empresaId` ahora hacen fallback a `user.value.user_metadata`, que ya viene en el JWT desde el login. Esto desbloquea el sidebar sin depender del fetch.
- **Fix de raíz pendiente** (a ejecutar en Supabase SQL editor):
  ```sql
  GRANT EXECUTE ON FUNCTION public.get_my_empresa_id() TO anon, authenticated, service_role;
  GRANT EXECUTE ON FUNCTION public.is_admin()         TO anon, authenticated, service_role;
  ```
  Sin esto, productos, ventas, reportes y la propia tabla de empleados también devolverán listas vacías por RLS.

### 7. Click en "Empleados" del sidebar no navegaba
- **Causa:** `app/pages/empleados/index.vue` declaraba `definePageMeta({ middleware: ['auth.global'] })`. `auth.global.ts` es middleware **global** (se aplica solo a todas las rutas) y no se puede referenciar por nombre — Nuxt lanza "Unknown route middleware" y aborta la navegación.
- **Fix:** eliminada esa línea de `definePageMeta`.

## Aclaración de modelo de datos
El usuario preguntó cómo se asocian las acciones de un admin si "no es empleado". Aclarado: no hay dos entidades separadas. La tabla `perfiles` ES la de empleados; cada fila es un usuario que puede iniciar sesión, y `rol` decide permisos. El admin registrado vía `/register` ya es una fila de `perfiles`, por lo que sus ventas se asocian a su `auth.uid()` igual que las de cualquier vendedor. El CRUD de "Empleados" es la UI sobre `perfiles` para que el admin dé de alta vendedores adicionales.

## Estado al cerrar la sesión
- Sidebar muestra "Empleados" y "Configuración" para admin. ✓
- Navegación a `/empleados` funciona. ✓
- Tabla de empleados se ve vacía — pendiente ejecutar los GRANTs sobre `get_my_empresa_id()` e `is_admin()` para que RLS deje pasar las filas.

## Archivos modificados hoy
- `app/composables/usePerfil.ts`
- `app/layouts/default.vue`
- `app/pages/empleados/index.vue`
