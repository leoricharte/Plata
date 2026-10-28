# Pruebas de seguridad

Corren sin conexión, con Node 20 o más reciente. No tocan producción.

| Archivo | Qué prueba |
|---|---|
| `carrera.mjs` | 300 intentos simultáneos contra un código de 6 dígitos. Con contadores en KV entraba el #251; con el Gate (Durable Object) no. |
| `cors.mjs` | Orígenes: el panel puede usar el admin; el sitio y orígenes ajenos no. |
| `servidor-local.mjs` | Levanta `dev/worker/worker.js` en `localhost:8787` con KV y Durable Objects simulados. Los correos quedan en `GET /__mails`. |
| `servidor.mjs` | Llave de escritura, revisiones, cerrar sesiones, origen y bloqueo del admin, textos con HTML peligroso. Requiere `servidor-local.mjs` corriendo. |
| `servidor-2.mjs` | Tope diario de fallos por correo, llave de escritura que no se reemplaza, tope global de escrituras públicas. Requiere `servidor-local.mjs` (reinícialo antes). |
| `panel-seguro.mjs` | Sesiones de admin de 1 h, tokens por persona (crear, revocar al instante), registro de auditoría sin tokens, roles dev/mod/auditor (solo lectura, sin abrir datos de usuarios), tablero del proyecto, propuestas (aprobar y rechazar), cierre de sesión que revoca, `/nazca` (tipo real, topes por conexión y globales) y que sin `RL_SALT` falle cerrado. Requiere `servidor-local.mjs` (reinícialo antes). |
| `nazca.mjs` | Nazca, el motor de importación (CSV): separadores, codificación, encabezados, cargo/abono, tipo D/C, monedas, fechas y números, categorías, repetidos, límites. Usa los archivos inventados de `csv/`. |
| `nazca-pdf.mjs` | Nazca con PDF: lectura con posiciones (pdf.js), lector del BCP (cargo/abono por columna, año de las fechas, 31DIC en enero), lector de Interbank (montos con signo, saldo por fila, página-guía ignorada, dólares), comprobación «cuadra», PDF con clave, PDF de otro banco, sin texto, dañado, demasiado grande. Usa los PDF inventados de `pdf/`. |
| `cliente-nativo.mjs` | La app de iOS (sin cabecera `Origin`): entrar, fijar la llave, subir y bajar la copia, pedir aprobar un dispositivo y cerrar sesiones; un origen de navegador ajeno sigue rechazado. Requiere `servidor-local.mjs` corriendo. |
| `frase.mjs` | Frase de recuperación en español (sin tildes ni eñes) o inglés: misma llave, 4 letras bastan, mayúsculas y tildes se perdonan. Usa el código real de la app. |
| `fuzz-perfil.js` | Carga un perfil donde cada texto es HTML malicioso y recorre la app (móvil y escritorio). Debe dar `HITS 0`. Requiere Playwright. |

```
node dev/tests/carrera.mjs
node dev/tests/nazca.mjs
node dev/tests/nazca-pdf.mjs
node dev/tests/cors.mjs
node dev/tests/frase.mjs
node dev/tests/servidor-local.mjs &   # en otra terminal
node dev/tests/servidor.mjs
python3 -m http.server 8770 &          # desde la raíz del repo
node dev/tests/fuzz-perfil.js http://localhost:8770/app/
```
