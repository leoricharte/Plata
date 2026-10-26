# pdf.js (Mozilla) — versión 6.4.299, build "legacy"

Se usa **solo** para leer el texto de los estados de cuenta en PDF que la persona elige importar (Nazca, `dev/app/src/core/nazca/`).
Todo corre en el dispositivo: el PDF no se sube a ningún servidor. Se carga únicamente cuando se importa un PDF.

- Origen: `pdfjs-6.4.299-legacy-dist.zip` de https://github.com/mozilla/pdf.js/releases (build "legacy", funciona en iPhone más viejos).
- Archivos usados, sin modificar: `pdf.mjs` y `pdf.worker.mjs`. No se incluyen los mapas (`.map`) ni `pdf.sandbox.mjs` (JavaScript dentro de PDFs: no se usa ni se carga).
- Licencia: Apache 2.0 (`LICENSE`), con el aviso al inicio de cada archivo.
- sha256: `pdf.mjs` 630de0bd0092cf2e9d46a23c68596b736699035e08cce4e9c85537c8eba0fc8e · `pdf.worker.mjs` bb422f60804477de4a0b09091d8347a916a387755ed1cbad24ccaec1d09c78bf
- Para actualizar: reemplazar los dos archivos por los de la nueva versión, actualizar este texto y correr `node dev/tests/nazca.mjs`.
- `dev/web/build.sh` los copia a `dist-web/nazca/`.
