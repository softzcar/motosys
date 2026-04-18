# Log de Optimización de Experiencia de Usuario (POS)

Fecha: 18 de abril de 2026

## Mejoras Realizadas

### 1. Blindaje del Foco en Diálogo de Clientes
- **Enfoque Forzado**: Se implementó una ráfaga de enfoque agresiva que asegura que el cursor aparezca en el campo de "Cédula" inmediatamente al abrir el modal, superando cualquier interferencia de otros componentes.
- **Aislamiento de Tabulación**: Se desactivó la navegación por teclado (`tabindex="-1"`) y la interacción (`pointer-events-none`) de todos los elementos del carrito mientras el diálogo está abierto. Esto obliga al navegador a mantener el foco dentro del modal.
- **Flujo Inteligente**: 
    - El sistema detecta automáticamente si el cliente es nuevo o existente.
    - Dirige el foco al "Nombre" para registros nuevos o al botón "Continuar a Pago" para clientes frecuentes.
- **Botón de Reinicio**: Se añadió "Limpiar / Nuevo" en el footer para resetear rápidamente el formulario y devolver el foco a la cédula.

### 2. Agilidad en la Búsqueda de Productos
- **Limpieza Automática**: El campo de búsqueda y los resultados se vacían al instante tras añadir un producto al carrito.
- **Atajo F2**: Se implementó la tecla de función **F2** como acceso directo global para devolver el cursor al campo de búsqueda de productos desde cualquier punto del POS.

### 3. Precisión en Cobros
- **Cálculo en Tiempo Real**: El monto "PENDIENTE" se actualiza tecla a tecla (vía `@input`), eliminando la necesidad de que el campo pierda el foco para reflejar el saldo.
- **Validación Visual**: Los campos de monto se bloquean hasta que se selecciona un método de pago, y el campo de referencia se resalta en azul cuando es obligatorio.
- **Limpieza Post-Venta**: El POS se resetea completamente tras una factura exitosa, quedando listo para el siguiente cliente.
