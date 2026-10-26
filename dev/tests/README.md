# Pruebas de seguridad

Corren sin conexión, con Node 20 o más reciente. No tocan producción.

| Archivo | Qué prueba |
|---|---|
| `carrera.mjs` | 300 intentos simultáneos contra un código de 6 dígitos. Con contadores en KV entraba el #251; con el Gate (Durable Object) no. |
| `cors.mjs` | Orígenes: el panel puede usar el admin; el sitio y orígenes ajenos no. |
| `servidor-local.mjs` | Levanta `dev/worker/worker.js` en `localhost:8787` con KV y Durable Objects simulados. Los correos quedan en `GET /__mails`. |
| `servidor.mjs` | Llave de escritura, revisiones, cerrar sesiones, origen y bloqueo del admin, textos con HTML peligroso. Requiere `servidor-local.mjs` corriendo. |
| `servidor-2.mjs` | Tope diario de fallos por correo, llave de escritura que no se reemplaza, tope global de escrituras públicas. Requiere `servidor-local.mjs` (reinícialo antes). |
| `fuzz-perfil.js` | Carga un perfil donde cada texto es HTML malicioso y recorre la app (móvil y escritorio). Debe dar `HITS 0`. Requiere Playwright. |

```
node dev/tests/carrera.mjs
node dev/tests/cors.mjs
node dev/tests/servidor-local.mjs &   # en otra terminal
node dev/tests/servidor.mjs
python3 -m http.server 8770 &          # desde la raíz del repo
node dev/tests/fuzz-perfil.js http://localhost:8770/app/
```
