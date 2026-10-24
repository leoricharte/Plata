# Plata para escritorio (Tauri)

Envuelve la misma app web (`app/index.html`) en una ventana nativa. No tiene código propio de la app.

- `dist/` se genera en la compilación copiando `app/index.html` (no se versiona).
- Los íconos se generan desde `press/plata-icono-1024.png` con `npx tauri icon`.
- Compilar: Actions → «Plata para escritorio (Windows)» → Run workflow. El instalador queda en Releases.
- Origen que usa en Windows: `http://tauri.localhost` (`https://tauri.localhost` si se activa useHttpsScheme).
  El worker de Plata Cloud ya lo tiene permitido en `ORIGINS`.
- Sin firma de código: Windows SmartScreen mostrará un aviso en la primera instalación.
