# Motor de Plata

La lógica de la app que no dibuja pantallas: fechas, repeticiones, números… Cada archivo es un módulo de verdad (`import`/`export`),
se prueba solo en Node (`node dev/tests/motor.mjs`) y no toca el DOM ni el estado de la app (`data`, `ui`).

La app no carga estos archivos directamente: `npm run motor` (desde `dev/`) los empaqueta con esbuild en
`src/js/00-motor.js`, que va primero en la compilación y expone todo como `Motor`. Los archivos de `src/js/` toman de ahí lo
que usan (`const { iso, pd } = Motor;`), así que el resto del código no cambia.

- Edita aquí, nunca `src/js/00-motor.js` (se regenera).
- Después de editar: `npm run motor --prefix dev`. El CI falla si `00-motor.js` no coincide con lo que generan estos archivos.
- Lo que entra aquí tiene que poder probarse sin navegador. Si algo necesita `data` o el DOM, se queda en `src/js/` o recibe lo que necesita como parámetro.
