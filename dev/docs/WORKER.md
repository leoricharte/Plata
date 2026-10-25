# API del servidor (Cloudflare Worker)

Código: `dev/worker/worker.js`. Almacenamiento: un KV llamado `WAITLIST`. Solo acepta orígenes de `plataapp.net` y de la app de escritorio (CORS). Se despliega a mano (ver `dev/README.md`).

## Claves del KV

| Prefijo | Contenido |
|---|---|
| `w:` | Lista de espera (correo → fecha, origen, idioma, plataforma, autorizado) |
| `u:` | Usuario de Plata Cloud (correo, verificación de clave) |
| `s:` | Sesión (hash del token, 90 días) |
| `c:` / `c2:` | Códigos de verificación (hash, 10 min, máx. 5 intentos) |
| `d:` | Datos cifrados del usuario (máx. 1.500.000 bytes) |
| `rl:` | Límite de uso por IP anonimizada |
| `af:` | Intentos fallidos de administrador por IP (15 min) |
| `rv:` | Copias enviadas voluntariamente para análisis |
| `po:`, `pi:`, `ct:` | Novedades, sus imágenes y textos editados de la web |

## Rutas

**Públicas**
- `GET /health`
- `POST /waitlist` · `GET /waitlist/export` (admin)
- `GET /posts`, `GET /posts/img`, `GET /content`

**Cuenta de Plata Cloud** (sesión `Authorization: Bearer <token>`)
- `POST /auth/start`, `POST /auth/verify`, `POST /auth/logout`
- `GET /me`, `PUT /me/key`
- `GET|PUT|DELETE /sync`, `POST /sync/confirm`, `POST /sync/check`
- `DELETE /account`
- Aprobación de dispositivo: `POST /link/start`, `POST /link/poll`, `GET /link/pending`, `POST /link/answer`

**Copias para análisis**: `POST /review`, `GET /review/status`, `POST /review/delete`; admin: `POST /review/mark`, `GET /review/list`, `GET /review/get`.

**Administración** (`Authorization: Bearer ADMIN_TOKEN`)
- `GET /content/ping`, `POST|DELETE /content`, `POST|DELETE /posts`, `POST /admin/invite`, lista de espera y copias.
- La comparación del token es en tiempo constante y hay un bloqueo por IP tras 5 fallos en 15 minutos (HTTP 429).

## Variables y secretos

`ADMIN_TOKEN` (larga y aleatoria, ≥ 32 bytes), `RL_SALT`, `RESEND_API_KEY`, y el KV `WAITLIST`.

## Límites del plan gratis

100.000 lecturas, 1.000 escrituras y 1.000 listados de KV al día; 100 correos al día en Resend.
