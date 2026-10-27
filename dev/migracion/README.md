# Mudanza: plataapp.net/app → web.plataapp.net

Los datos de cada persona (perfil, sesión de Plata Cloud y frase) viven en el navegador **por dominio**. Si solo movemos la app,
cada usuario abre una app vacía. Por eso la mudanza tiene un puente:

1. La app nueva, la primera vez que abre en `web.plataapp.net` **sin datos**, carga invisible `https://plataapp.net/app/puente.html`.
2. El puente le pasa los datos con `postMessage`, **solo** al origen `https://web.plataapp.net`. Un sitio ajeno que lo enmarque no recibe nada.
3. La app guarda los datos y le pide al puente que borre la copia vieja (y su service worker). Desde entonces no queda ninguna frase
   en el dominio del sitio público.
4. Si la app nueva ya tiene datos, no pisa nada.

Si un navegador aislara el almacenamiento entre subdominios y el puente no viera los datos, la persona puede abrir
`plataapp.net/app/?exportar` para descargar su archivo de perfil y cargarlo en la app nueva.

Probado con Chromium simulando los dominios reales: los datos llegan, la copia vieja se borra y un sitio ajeno no recibe nada.

## Pasos, en este orden

**1. Servidor y app, juntos.** La app nueva y el servidor nuevo no son compatibles con sus versiones viejas (la app manda la cabecera
`X-Plata-Write`, que el servidor viejo no permite; el servidor nuevo exige esa cabecera para escribir). Prepara todo, mezcla la rama
a `main` (GitHub Pages publica la app en 1–2 minutos) y despliega el Worker justo después (`dev/README.md` → El servidor).

**2. App en Cloudflare Pages (gratis).**
- Workers & Pages → Create → Pages → conecta este repo (`leoricharte/Plata`).
- Build command: `sh dev/web/build.sh` · Build output directory: `dist-web`.
- Custom domains → `web.plataapp.net`. Cloudflare te dirá qué CNAME crear; agrégalo en tu proveedor de DNS actual
  (`web` → `<proyecto>.pages.dev`). No hace falta mover el DNS.
- `dev/web/_headers` agrega las cabeceras que una etiqueta `<meta>` no puede poner (bloqueo de iframes, HSTS, etc.).

**3. Probar** en `https://web.plataapp.net` con un perfil de prueba. Ojo: si abres la app nueva en tu navegador de siempre, tus datos
de `plataapp.net/app` se mudan y se borran de allá (es lo esperado).

**4. Cambio (un solo commit, en el repo del sitio):**
```
cp dev/migracion/app-index.html app/index.html     # plataapp.net/app ahora redirige a web.plataapp.net
cp dev/migracion/sw.js app/sw.js                   # el service worker viejo se da de baja y borra su caché
```
`app/puente.html` ya está en el repo; debe seguir publicado al menos unos meses.
Luego cambia los enlaces "Probar Plata" del sitio (`href="app/"`) a `https://web.plataapp.net/` (la redirección los cubre igual).

**5. Panel privado.** Está en el repo privado `plata-dev` (ver su README). Cuando funcione, agrega su origen en `ADMIN_ORIGINS`.

## Qué cambia para las personas

- Quien abra `plataapp.net/app` (o el ícono en su pantalla de inicio) llega a `web.plataapp.net` con sus datos.
- En iPhone, el ícono viejo seguirá abriendo la dirección vieja, que redirige. Conviene sugerir "Agregar a pantalla de inicio" de nuevo.
- Con Plata Cloud no cambia nada: la sesión y la frase se mudan con lo demás.

## La demo del sitio

`demo/app.html` (la vista previa de `try.js`) es una compilación vieja que comparte almacenamiento con `plataapp.net`.
Después de la mudanza ese almacenamiento queda vacío de datos reales, así que la demo deja de convivir con ellos.
Conviene recompilarla desde `dev/app/src` para que tenga las correcciones.
