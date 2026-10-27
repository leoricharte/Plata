# Plata para escritorio (Tauri)

Envuelve la misma app web (`app/index.html`) en una ventana nativa. No tiene código propio de la app.

- `dist/` se genera en la compilación copiando `app/index.html` (no se versiona).
- Los íconos se generan desde `press/plata-icono-1024.png` con `npx tauri icon`.
- Compilar: Actions → «Plata para escritorio (Windows)» → Run workflow (la etiqueta puede quedar vacía). El instalador queda en Releases.
- La versión sale de `APP_BUILD` (dev/app/src/app.html): la compilación 452 genera la versión 3.0.452. El workflow la escribe solo; no hace falta editar los tres archivos a mano.
- Origen que usa en Windows: `http://tauri.localhost` (`https://tauri.localhost` si se activa useHttpsScheme).
  El worker de Plata Cloud ya lo tiene permitido en `ORIGINS`.
- Sin firma de código: Windows SmartScreen mostrará un aviso en la primera instalación.
