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

## Publicar una versión nueva de la app

1. En `dev/app/src/app.html` sube `APP_BUILD` (busca `const APP_BUILD`) y el mismo número en la pantalla de inicio (busca `class="sp-b"`).
2. Compila: `python3 dev/app/build.py`.
3. Copia el resultado: `cp dev/app/out/finanzas.html app/index.html`.
4. En `app/sw.js` sube `CACHE` (`finanzas-vNNN`) al mismo número; sin eso los usuarios siguen viendo la versión vieja por el caché.
5. En `README.md` (línea de "Compilación") pon el mismo número.
6. Haz commit y push a `main`. GitHub Pages publica en un par de minutos.

## El servidor (Cloudflare Worker)

El Worker se despliega **a mano**: Cloudflare → Workers & Pages → `plata-cloud` → Edit code → pegar `dev/worker/worker.js` → Deploy. (La carpeta `cloud/` del repo es una versión antigua solo de lista de espera.)

Variables y secretos (Settings → Variables and Secrets):

- `ADMIN_TOKEN`: contraseña del panel `plataapp.net/devtools-admin` y de las rutas de administración. Debe ser larga y aleatoria.
- `RL_SALT`: texto aleatorio para anonimizar las direcciones IP en los límites de uso.
- `RESEND_API_KEY`: para enviar correos (confirmación de lista de espera e invitaciones). Sin ella el Worker funciona pero no manda correos.
- KV namespace enlazado como `WAITLIST`.

Límites del plan gratis (por día): 100.000 lecturas, 1.000 escrituras y 1.000 listados de KV; 100 correos al día en Resend. Cada alta o envío de copia hace unas 3 escrituras.

## Panel de administración

`plataapp.net/devtools-admin` (entra con `ADMIN_TOKEN`):

- **Copias recibidas:** perfiles enviados por usuarios para análisis; descargar, marcar revisado, eliminar del servidor.
- **Novedades:** crear y editar artículos (el orden no cambia al editar).
- **Lista de espera:** autorizar, enviar invitación por correo, quitar acceso.
- **Textos de la web:** editar cualquier texto de las páginas públicas con un lápiz (también con 5 toques en el pie de página o `#editar`).

## Pruebas

No hay un ejecutor de pruebas incluido. Las pruebas se hicieron con Playwright contra una compilación con el gancho `window.__ev` (solo en `localhost`, **no** está en la compilación pública) y un servidor local que imita el Worker. Para reproducir algo, abre la app compilada en un navegador y usa los perfiles de demo (Ajustes → cargar demo).

## Reglas

- **Nunca subas perfiles reales** (archivos `.json` de usuarios) ni capturas con datos reales. El `.gitignore` bloquea `.json`.
- Textos y traducciones: la app y la web tienen español e inglés como mínimo.
- Solo iconos Remix; el diseño sigue el de la app (hojas con tirador, tarjetas redondeadas, verde `#22B573`).
