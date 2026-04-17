# Log: Solución Error Doble Clic en Login
Fecha: 2026-04-15

## Problema
En la página de inicio de sesión (`/login`), era necesario hacer clic dos veces en el botón "Entrar" para enviar los datos. Esto ocurría debido a que el primer clic activaba el estado `loading` del botón de PrimeVue, lo que podía interrumpir la propagación del evento de envío del formulario nativo del navegador.

## Solución
Se modificó `app/components/auth/LoginForm.vue` para desacoplar el evento de clic de la sumisión automática del formulario:
- Se eliminó `type="submit"` del componente `<Button>`.
- Se añadió `@click="handleLogin"` directamente al `<Button>`.
- Se mantuvo `@submit.prevent="handleLogin"` en la etiqueta `<form>` para asegurar que la tecla **Enter** siga funcionando correctamente en los campos de entrada.

## Verificación
Se verificó el funcionamiento con un solo clic utilizando las credenciales de prueba proporcionadas, logrando un inicio de sesión exitoso y redirección al dashboard al primer intento.
