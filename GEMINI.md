# Instrucciones para Gemini (Antigravity)

## Credenciales de Acceso
- **Email:** `softzcar@gmail.com`
- **Password:** `510530_m`

## Reglas de Interfaz (UI)
- **Tema:** Siempre utilizar el **tema claro** (Light Mode) al momento de crear o modificar componentes de la interfaz. Evitar overrides de modo oscuro a menos que sea estrictamente necesario.

## Entorno de Pruebas
- **Servidor de Pruebas:** El servidor de desarrollo corre en `http://localhost:3001/`.
- **Importante:** No es necesario levantar un nuevo servidor de desarrollo (npm run dev) a menos que se indique lo contrario; utilizar siempre el que está corriendo en el puerto 3001.

## Estándares de Tablas (DataTable)
- **Ordenamiento (Sorting):** Todas las tablas `DataTable` que utilicen carga perezosa (`lazy`) deben implementar la lógica de ordenamiento tanto en el componente (manejando `@sort`) como en el composable (pasando `sortField` y `sortOrder` a la consulta de Supabase).
- **Consistencia:** Utilizar siempre el patrón de pasar un objeto de opciones `{ search, page, rows, sortField, sortOrder }` a los métodos `fetch` de los composables.

## Estándares de Botones de Añadir (+)
- **Patrón:** Todos los botones con función de añadir/agregar un item deben seguir el mismo estilo del botón "+" del Punto de Venta (POS). El patrón es:
  ```html
  <Button severity="success" class="aspect-square" @click="handler">
    <Plus class="w-5 h-5" />
  </Button>
  ```
- **Icono:** Usar siempre `Plus` de `lucide-vue-next` con clases `w-5 h-5`. **NO** usar PrimeIcons (`pi pi-plus`) ya que no están disponibles en el proyecto.
## Estándares de Reportes Imprimibles (Carta)
- **Maquetación Obligatoria:** Todos los reportes diseñados para hojas tamaño carta deben seguir estrictamente el patrón establecido en `InventarioChecklistReport.vue`. No se permiten variaciones de estilo o estructura.
- **Clase de Contenedor:** Utilizar siempre la clase `.print-report` (definida en `main.css`) para el contenedor principal.
- **Header:** Debe incluir título en mayúsculas negritas, fecha/hora de emisión y el detalle de los filtros aplicados (o "Todos los productos" si no hay filtros).
- **Cuerpo:** 
  - **Densidad:** Utilizar fuentes pequeñas (`8px` a `10px`) y espaciados reducidos para maximizar la información por página.
  - **Tablas:** Bordes en `slate-300`, encabezados con fondo `slate-100` y tipografía `font-black text-[8px]`.
  - **Agrupación:** Si los datos tienen una jerarquía (ej. estantes), utilizar separadores de sección con fondo `slate-900` y texto blanco.
- **Footer:** Debe incluir un descargo de responsabilidad ("GUÍA DE TRABAJO...") y numeración de páginas en el formato "Página ____ de ____".
- **CSS de Impresión:** Asegurar que `@page { size: letter; margin: 1cm; }` y `-webkit-print-color-adjust: exact !important;` estén presentes en el componente.

