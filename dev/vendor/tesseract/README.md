# Tesseract OCR (tesseract.js 5.1.1) — solo para leer capturas de constancias de Yape/Plin

Se usa **solo** cuando la persona elige una captura de una constancia (Nazca, `dev/app/src/core/nazca/ocr.js`). Todo corre en el dispositivo:
la imagen no se sube a ningún servidor. Se descarga una sola vez y solo en ese momento (~6 MB).

- Origen: paquetes de npm `tesseract.js@5.1.1`, `tesseract.js-core@5.1.1` y `@tesseract.js-data/spa@1.0.0` (`4.0.0_best_int`). Licencia Apache 2.0 (`LICENSE`).
- Archivos usados, sin modificar: `tesseract.min.js`, `worker.min.js`, `tesseract-core-simd-lstm.wasm.js`, `tesseract-core-lstm.wasm.js` (respaldo sin SIMD), `spa.traineddata.gz`.
- sha256:
  - tesseract.min.js a8e29918d098b2b06e1012bdaeffb4aec0445c5d5654709023e0bd1f442a80e8
  - worker.min.js aca1229639fc9907d86f96e825955a2b7c5716d17f3bc3acd71f9c7ab66181fc
  - tesseract-core-simd-lstm.wasm.js ce20eda9533cbed1e6c2b4276fbae1e0adc61b6754b5513084be601787b457cf
  - tesseract-core-lstm.wasm.js 8f04aa0cc81e7bde33f80e92fa01a7a665f0b4884d098acf5de9c7104a11dfaa
  - spa.traineddata.gz 40be52f97b5d4eb7460073dc1f94cd546b27150333c0bf854ed7e7132db6bceb
- El motor corre en un Web Worker del mismo origen (`worker-src 'self'`, sin blobs): la CSP de la página no cambia.
- `dev/web/build.sh` los copia a `dist-web/nazca/ocr/`.
