# Desarrollo de Plata

Guía para seguir el desarrollo sin depender de nadie. Todo lo necesario para compilar, probar y publicar está en esta carpeta.

## Cómo está armado

- **La app** es un solo archivo, `app/index.html`, que se **genera** desde `dev/app/src/`. No lo edites a mano: edita las fuentes y vuelve a compilar.
- **La web** (`*.html`, `site.css`, `pages.css`, `nav.js`, `content.js`...) son archivos estáticos que se editan directamente. Se sirven con GitHub Pages (dominio en `CNAME`).
- **El servidor** es un Cloudflare Worker (`dev/worker/worker.js`). Sirve la lista de espera, Plata Cloud (cuentas y sincronización cifrada), las copias enviadas para análisis, los artículos de Novedades y los textos editados de la web. Guarda todo en un KV llamado `WAITLIST`.

## Compilar la app

Requiere solo Python 3.

```
python3 dev/app/build.py          # genera dev/app/out/finanzas.html
CHANNEL=alpha python3 dev/app/build.py   # variante con icono blanco
```

`dev/app/src/` contiene:

- `app.html`: la app (HTML + CSS + JS). Todo el código está aquí.
- `tr/*.txt`: traducciones, una por línea: `es ¦ en ¦ ja ¦ it ¦ fr ¦ hr`. Una frase nueva en la app se agrega aquí en los 6 idiomas.
- `i18n*.js`, `icons_rmx.js` (Remix Icon, Apache-2.0), `icons_sf.js`, `demo_profiles.js`, `worldmap.js`.
- `../assets/`: la fuente Inter, la fuente de números de tarjeta y los iconos. Se incrustan en el archivo final.

## Tres dominios

| Dominio | Qué es | Dónde vive |
|---|---|---|
| `plataapp.net` | El sitio informativo | GitHub Pages (este repo) |
| `web.plataapp.net` | La app | Cloudflare Pages (este repo, `sh dev/web/build.sh` → `dist-web/`) |
| panel privado | Herramientas del equipo | Repo privado `dev-estudio22` + Cloudflare Pages + Cloudflare Access (no está en este repo) |

Los datos de cada persona viven en el navegador **por dominio**: un fallo en el sitio público no puede leer la frase de la app, y el token del admin nunca se escribe en un dominio público. La mudanza de `plataapp.net/app` a `web.plataapp.net` está en `dev/migracion/README.md`.

## Publicar una versión nueva de la app

1. En `dev/app/src/app.html` sube `APP_BUILD` (busca `const APP_BUILD`). El número de la pantalla de inicio sale de ahí.
2. Compila: `python3 dev/app/build.py`. La compilación agrega la Content-Security-Policy con el hash de cada script; si alguien agrega un `onclick="…"` o un `<script src>`, la compilación se detiene.
3. Sube `CACHE` (`finanzas-vNNN`) al mismo número en `dev/web/sw.js`.
4. En `README.md` (línea de "Compilación") pon el mismo número.
5. Commit y push a `main`. Cloudflare Pages compila `web.plataapp.net` solo; GitHub Pages publica el sitio.

`app/index.html` ya no es la app: desde la mudanza es la página que redirige a `web.plataapp.net` (y `app/puente.html` pasa los datos). No copies la app ahí.

## El servidor (Cloudflare Worker)

Desde la compilación 421 se despliega con wrangler (el Durable Object `Gate` lo necesita). Despliégalo **justo después** de publicar la app 421: la app y el servidor nuevos no funcionan con sus versiones anteriores.

```
cd dev/worker
# una vez: pon el ID del KV WAITLIST en wrangler.toml
npx wrangler deploy
```

Los secretos que ya están en el panel se conservan. Revisa:

- `ADMIN_TOKEN`: mínimo 32 caracteres (con menos, el admin queda desactivado). Genera uno con `openssl rand -base64 48`.
- `MOD_TOKEN` (opcional, mínimo 32 caracteres): rol mod del panel; lo que guarda queda como propuesta hasta que un dev la apruebe. `RL_SALT` es obligatorio: sin él el Worker responde 503.
- `RL_SALT`: **no lo cambies**; de él salen los identificadores de las cuentas.
- `RESEND_API_KEY`: correos.
- Nueva variable `ADMIN_ORIGINS`: el origen del panel privado (por ejemplo `https://dev-estudio22.pages.dev`).

Detalle de rutas, claves y del protocolo de aprobación: [`docs/WORKER.md`](docs/WORKER.md). (La carpeta `cloud/` es una versión antigua solo de lista de espera; no se usa.)

## Panel de administración

El panel del equipo **no está en este repo**: vive en un repo privado (`dev-estudio22`) detrás de Cloudflare Access. Aquí queda lo que se audita: el Worker (`dev/worker/`), que es quien guarda y protege los datos y define las rutas de administración, sus roles, las sesiones de 1 hora, los tokens por persona y el registro de actividad (descritos en [`docs/WORKER.md`](docs/WORKER.md) y probados en `dev/tests/`), la app y los lectores de Nazca. El panel solo es una pantalla que llama a esas rutas: no tiene acceso a nada que el Worker no permita, así que no hace falta publicarlo para auditar.

- **Copias recibidas:** perfiles enviados por usuarios para análisis; descargar, marcar revisado, eliminar. Caducan solas a los 30 días.
- **Novedades:** crear y editar artículos.
- **Lista de espera:** autorizar, invitar, quitar acceso.
- **Textos de la web:** lista de los textos de cada página, con buscador; se editan en español e inglés. El sitio solo muestra `<b>`, `<i>`, `<em>`, `<strong>`, `<br>` y enlaces.

## Pruebas

Pruebas de seguridad en [`tests/`](tests/README.md): carrera contra los códigos, llave de escritura, revisiones, sesiones, admin y un fuzz de XSS que recorre la app con un perfil malicioso.

## Reglas

- **Nunca subas perfiles reales** (archivos `.json` de usuarios) ni capturas con datos reales. El `.gitignore` bloquea `.json`.
- Textos y traducciones: la app y la web tienen español e inglés como mínimo.
- Solo iconos Remix; el diseño sigue el de la app (hojas con tirador, tarjetas redondeadas, verde `#22B573`).

- **Novedades automáticas:** `python3 dev/changelog.py [fecha]` publica en `novedades.html` el registro de cambios de la última versión de `CHANGELOG.md`, firmado por el equipo de Plata. Se ejecuta en cada versión nueva.

## Documentación

- [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md): cómo está organizada la app y qué patrones seguir.
- [`docs/DATOS.md`](docs/DATOS.md): formato del save file y del cifrado.
- [`docs/WORKER.md`](docs/WORKER.md): rutas, claves del KV y variables del servidor.
