# API del servidor (Cloudflare Worker)

Código: `dev/worker/worker.js`. Configuración: `dev/worker/wrangler.toml`. Se despliega con `cd dev/worker && npx wrangler deploy` (el Durable Object `Gate` necesita wrangler; el editor del panel de Cloudflare no crea migraciones).

Almacenamiento:

- **KV `WAITLIST`**: datos que viven mucho (lista de espera, usuarios, sesiones, copias cifradas, Novedades, textos).
- **Durable Object `Gate`**: todo lo que se cuenta o se consume (códigos de 6 dígitos y sus intentos, límites de uso, fallos del admin, estado de la aprobación de dispositivos). KV no es atómico y acepta 1 escritura por segundo por clave: con peticiones en paralelo, un contador de "leer, sumar, guardar" dejaba pasar cientos de intentos. El Gate atiende las peticiones de cada contador de una en una, y no gasta escrituras de KV (así nadie puede agotar el cupo diario para tumbar el servicio).

## Orígenes (CORS)

- Rutas públicas y de cuenta: `web.plataapp.net` (la app), `plataapp.net` (el sitio y la app vieja durante la mudanza) y la app de escritorio (Tauri).
- Rutas de administración: solo los orígenes de `ADMIN_ORIGINS` (el panel privado) y, con `DEV=1`, `localhost`. Desde cualquier otro origen del navegador responden 403, aunque el token sea correcto.

## Claves del KV

| Prefijo | Contenido |
|---|---|
| `w:` | Lista de espera (correo → fecha, origen, idioma, plataforma, autorizado) |
| `u:` | Usuario de Plata Cloud (correo, comprobación de clave `kc`, hash de la llave de escritura `wh`, versión de sesión `sv`) |
| `s:` | Sesión (hash del token, versión `sv`, 90 días) |
| `d:` / `p:` | Copia cifrada actual y la anterior (máx. 1.500.000 bytes) |
| `n:` | Última revisión antes de borrar la copia (la revisión nunca retrocede) |
| `rv:` | Copias enviadas voluntariamente para análisis (texto plano, caducan a los 30 días) |
| `rvl:` | Espera creciente entre envíos de copias por IP anonimizada |
| `po:`, `pi:`, `ct:` | Novedades, sus imágenes y textos editados de la web |

## Nombres en el Gate

| Nombre | Contenido |
|---|---|
| `c:<usuario>` / `c2:<usuario>` | Código de entrada / de confirmación (hash, 10 min, máx. 5 intentos) |
| `link:<usuario>` | Estado de la aprobación de un dispositivo nuevo (10 min) |
| `rl:…`, `af:…` | Límites de uso por IP anonimizada o por usuario, y fallos del admin |
| `rl:vf:<usuario>:<día>` | Fallos de código de entrada en el día (máx. 15; después, 429 hasta el día siguiente) |
| `rl:pub:<día>` | Escrituras de rutas públicas en el día (máx. 150 altas o copias), para no agotar el cupo de KV de la sincronización |

## Rutas

**Públicas**
- `GET /health`
- `POST /waitlist`
- `GET /posts`, `GET /posts/img`, `GET /content`
- `POST /review`, `GET /review/status`

**Cuenta de Plata Cloud** (sesión `Authorization: Bearer <token>`)
- `POST /auth/start`, `POST /auth/verify`, `POST /auth/logout`
- `POST /auth/logout-all`: cierra todas las demás sesiones y devuelve una nueva para este dispositivo. Pide la llave de escritura.
- `GET /me`, `PUT /me/key` (fija `kc` y la llave de escritura al crear la cuenta)
- `GET /sync` (incluye `next`, la revisión que tendrá la próxima copia), `PUT /sync`, `DELETE /sync`, `POST /sync/confirm`, `POST /sync/check`
- `DELETE /account` (código del correo)

**Llave de escritura** (`X-Plata-Write`): sale de la frase (HKDF, rama `write`). El servidor guarda solo su hash y la exige en `PUT /sync`, `DELETE /sync` y `POST /auth/logout-all`. Quien solo tiene acceso al correo puede leer el texto cifrado, pero no pisarlo ni borrarlo. Las cuentas creadas antes de la compilación 421 la fijan la primera vez que escriben.

**Revisión dentro del cifrado**: la app cifra `{ plata: 2, rev, d }` y manda `next` en `PUT /sync`. Si `next` no es la revisión que se asignaría, responde 409. Al abrir, la app exige que la revisión cifrada coincida con la que dice el servidor y que nunca retroceda.

**Aprobación de dispositivo** (comparación numérica con compromiso previo):

| Paso | Quién | Ruta | Estado |
|---|---|---|---|
| 1. Clave efímera `pkN` | nuevo | `POST /link/start` | `p` |
| 2. Compromiso `c = SHA-256(pkA ‖ nA)` | activo | `POST /link/step {step:'commit'}` | `c` |
| 3. Aleatorio `nN` | nuevo | `POST /link/poll {step:'nonce'}` | `n` |
| 4. Revela `pkA`, `nA` | activo | `POST /link/step {step:'reveal'}` | `r` |
| 5. Semilla cifrada (si la persona aprueba) | activo | `POST /link/step {step:'answer'}` | `a` / `d` |

El nuevo consulta con `POST /link/poll` y el activo con `GET /link/pending`. Ambos muestran un código de 6 dígitos derivado de `pkN ‖ pkA ‖ nA ‖ nN`.

**Envíos de Nazca** (`POST /nazca` público): solo PDF, XLSX o CSV que lo sean de verdad (se revisan los primeros bytes), 12 intentos por hora y 5 envíos por día por conexión, y 60 envíos al día en total, con contadores del Gate (no gastan el cupo de la lista de espera). Admin: `GET /nazca/list`, `GET /nazca/get`, `POST /nazca/delete`.

**Copias para análisis** (admin): `POST /review/mark`, `POST /review/delete`, `GET /review/list`, `GET /review/get`.

**Sesiones de administración**: `POST /admin/session` (con `Authorization: Bearer ADMIN_TOKEN` o `MOD_TOKEN`) devuelve `{ session, role, exp }`: un token aleatorio que vive 1 hora (Gate `as:…`, sin renovación). Todas las rutas de administración usan `Authorization: Bearer <session>`. `POST /admin/logout` la revoca. Cada persona tiene su token (`plt_<id>.<secreto>`, solo se guarda su hash en `au:<id>`): `GET|POST /admin/users`, `POST /admin/users/revoke?id=…[&undo=1]` (dev; revocar cierra sus sesiones al instante). `GET /admin/audit?n=…` (dev) lista el registro `al:…` (90 días, el evento va en los metadatos de KV). Roles: **dev** (todo) y **mod** (solo `POST|DELETE /content` y `/posts`, que quedan como propuesta `pr:…` 14 días; un dev las ve en `GET /admin/proposals` y decide con `POST /admin/proposals/decide?id=…&do=approve|reject`). `ADMIN_LEGACY=1` vuelve a aceptar `ADMIN_TOKEN` directo (no recomendado).

**Administración** (sesión dev, solo desde `ADMIN_ORIGINS`, o localhost con `DEV=1`)
- `GET /content/ping`, `POST|DELETE /content` (solo `<b>`, `<i>`, `<em>`, `<strong>`, `<br>` y `<a href>` seguros), `POST|DELETE /posts`, `POST /admin/invite`, `GET /waitlist/export`.
- Comparación del token en tiempo constante y bloqueo por IP tras 5 fallos en 15 minutos (HTTP 429), con contador atómico.

## Variables y secretos

- `ADMIN_TOKEN` (secreto, **mínimo 32 caracteres**; si es más corto, el admin queda desactivado), `MOD_TOKEN` (secreto opcional, 32+ caracteres: rol mod), `RL_SALT` (secreto, **obligatorio**: sin él, las rutas que anonimizan responden 503; no cambiarlo: de él salen los identificadores de las cuentas), `RESEND_API_KEY` (secreto).
- `ADMIN_ORIGINS` (variable): origen del panel privado, por ejemplo `https://plata-dev.pages.dev`.
- `CLOUD_TESTERS`, `CLOUD_OPEN` (variables, como antes).
- `REVIEW_OFF = 1` (variable, opcional): desactiva el envío de copias para análisis (por ejemplo, durante un piloto). Así no entra nada legible al servidor.
- KV `WAITLIST` y Durable Object `GATE` (en `wrangler.toml`). Sin `GATE`, las rutas que lo necesitan responden 503 (`config`): fallan cerradas.

## Límites del plan gratis

KV: 100.000 lecturas, 1.000 escrituras y 1.000 listados al día. Durable Objects (SQLite): 100.000 peticiones al día. Resend: 100 correos al día.
