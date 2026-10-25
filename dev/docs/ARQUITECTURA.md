# Arquitectura de la app

Plata es una PWA de **un solo archivo** (`app/index.html`), sin framework ni dependencias externas. Se genera desde `dev/app/src/` con `python3 dev/app/build.py`. Todo funciona sin conexión; los datos viven en el dispositivo.

## Piezas

| Pieza | Dónde | Qué hace |
|---|---|---|
| Fuente de la app | `dev/app/src/app.html` | HTML + CSS + JS de la app (≈7.000 líneas) |
| Traducciones | `dev/app/src/tr/*.txt`, `i18n*.js` | Una frase por línea: `es ¦ en ¦ ja ¦ it ¦ fr ¦ hr` |
| Iconos | `icons_rmx.js` (Remix, Apache-2.0), `icons_sf.js` | SVG en objetos JS |
| Perfiles de demo | `demo_profiles.js` | Alessandro, Shawn, etc., con datos ficticios |
| Mapa | `worldmap.js` | Mapa del mundo para la pantalla de monedas |
| Compilador | `dev/app/build.py` | Sustituye los marcadores `/*__X__*/` y `__X_B64__` por el contenido real |
| Service worker | `app/sw.js` | Caché sin conexión (`finanzas-vNNN`) |
| Servidor | `dev/worker/worker.js` | Cloudflare Worker + KV (ver `WORKER.md`) |

## Cómo se organiza `app.html`

El archivo tiene tres bloques: `<style>` (líneas 28–~1000), el HTML de las pantallas y el `<script>` principal (desde ~1070). El script es una IIFE con `'use strict'` y secciones marcadas con `/* ---------- Título ---------- */`. Para ver el índice: `grep -n "^/\* ----------" dev/app/src/app.html`.

Orden del script:

1. **Datos de ejemplo y estado** (`makeSample`, `EMPTY`, `KEY`, `migrate`, `loadStored`, `persist`).
2. **Utilidades y monedas** (formato, fechas, conversión entre moneda principal y segunda).
3. **Plata Cloud** (cuenta, claves, sincronización, aprobación de dispositivos).
4. **Cálculos** (saldos, presupuesto, proyección semanal, deuda, ahorro) y **gráficos SVG**.
5. **Pantallas**: `renderResumen`, `renderPresupuesto`, `renderDeuda`, `renderAhorro`, `renderProyeccion`, `renderMovimientos`, `renderCuenta`. Cada una devuelve HTML como texto y lo inserta en su contenedor.
6. **Hojas y formularios** (nuevo movimiento, transferir, cuentas, suscripciones, simulaciones).
7. **Archivo (save file)**: exportar/importar JSON.
8. **Eventos**: un solo `click` delegado que lee `data-act="accion:argumento"` (ver abajo).
9. **Efectos** (Liquid Glass, lupa en bordes), **bienvenida** y **arranque**.
10. **Vista web (escritorio ≥ 900 px)**: ventanas flotantes y tablero Bento.

## Patrones que conviene respetar

- **Render por texto**: las pantallas son funciones que arman un string HTML; `renderAll()` las vuelve a pintar. No hay estado reactivo: tras cambiar `data`, llama a `persist()` y luego `renderAll()`.
- **Eventos delegados**: los botones llevan `data-act="nombre"` o `data-act="nombre:valor"`. El manejador central (sección *Eventos*) decide qué hacer. Para un botón nuevo, añade el `data-act` y su caso ahí.
- **Escapar siempre**: todo texto del usuario pasa por `esc()` antes de entrar a un string HTML.
- **Idiomas**: el texto de la interfaz está en español en el código y se traduce con el diccionario de `tr/`. Una frase nueva se añade a un `.txt` en los 6 idiomas; sin entrada, se muestra en español.
- **Temas**: variables CSS (`--card`, `--ink`…) con modo oscuro por `data-theme`; el bloque "Sin Liquid Glass" es el modo de vidrio esmerilado.
- **Sin dependencias**: no añadas librerías; si hace falta algo, se escribe a mano para mantener un único archivo.

## Almacenamiento local

| Clave | Contenido |
|---|---|
| `finanzas.v3` | El perfil completo (JSON, ver `DATOS.md`) |
| `finanzas.dirty`, `finanzas.lastsaved` | Cambios sin exportar y fecha del último guardado |
| `finanzas.welcomed` | Bienvenida ya vista |
| `plata.theme` | Tema claro/oscuro/sistema |

## Probar un enlace de demo

`app/?demo=alessandro&lang=es` abre la app con un perfil de demo y sin ventanas emergentes (lo usa la página `bcp.html`).

## Qué no hay (a propósito)

Ni analítica, ni rastreadores, ni cuentas obligatorias. Plata Cloud es opcional y cifra en el dispositivo (ver `../../arquitectura-seguridad.html`).
