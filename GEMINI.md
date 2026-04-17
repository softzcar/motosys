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
- **Estilo:** `severity="success"` + `class="aspect-square"` (botón cuadrado verde sólido). **NO** usar `outlined` ni `rounded`.

