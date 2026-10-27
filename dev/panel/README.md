# Panel privado de Plata (dev)

Este panel administra la lista de espera, las copias enviadas para análisis, Novedades y los textos de la web.
**No se publica en plataapp.net ni en la app**: vive en su propio dominio y detrás de Cloudflare Access.

## Por qué está separado

- Si el sitio público tuviera un fallo (un texto mal escrito, una dependencia), no podría leer el token de administrador.
- El token nunca se escribe en `plataapp.net`.
- Una copia maliciosa enviada a `/review` ya no puede ejecutar código en el mismo dominio donde los usuarios guardan su frase.

## Publicarlo (gratis)

1. Corre `sh dev/panel/build.sh` (empaqueta el motor de Nazca en `dev/panel/nazca/`). Crea un repo **privado** (por ejemplo `plata-dev`) y copia esta carpeta completa (`index.html`, `nazca-panel.js`, `nazca/`, `_headers`, `README.md`).
2. Cloudflare → Workers & Pages → Create → Pages → conecta el repo. Sin comando de compilación; carpeta de salida: `/`.
   Queda en `https://plata-dev.pages.dev` (o el nombre que elijas).
3. Cloudflare → Zero Trust (plan Free, hasta 50 personas) → Access → Applications → Add → Self-hosted:
   - Domain: `plata-dev.pages.dev`, subdominio `*` (protege también las vistas previas).
   - Política "Allow": Emails → tu correo. Método de acceso: One-time PIN.
4. En el Worker (Settings → Variables), agrega `ADMIN_ORIGINS = https://plata-dev.pages.dev`.
   Las rutas de administración rechazan cualquier otro origen del navegador.

¿Quieres `dev.plataapp.net` en lugar de `plata-dev.pages.dev`? Con Access, eso requiere que el DNS de plataapp.net esté en Cloudflare
(también gratis). Sin moverlo, usa la dirección `.pages.dev`.

## Pestaña Nazca

Usa el mismo token. Panel (lectores y bancos, submissions pendientes) · Aportar manualmente (cargas un PDF o CSV, pones la contraseña si la pide, ves cómo lo lee Nazca y descargas la extracción sin contraseña, con enmascarado opcional) · Revisar submissions (`/nazca/list`, abrir en el analizador, descargar, eliminar) · Insertar nuevo banco (genera el esqueleto del lector, la entrada del catálogo y los pasos). El archivo se lee en tu navegador; no se sube a ningún servidor. Cada vez que cambie un lector, vuelve a correr `build.sh`.

## Usarlo en tu computadora

```
cd dev/panel && python3 -m http.server 8788
# abre http://localhost:8788  (para un Worker local: http://localhost:8788/?api=http://localhost:8787)
```

El Worker acepta las rutas de administración desde `localhost` sin configurar nada más. El token sigue siendo obligatorio.
