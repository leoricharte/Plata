# Excel de prueba

Archivos **inventados** (nombres, comercios y montos de mentira, marcados "DOCUMENTO DE PRUEBA"). Nunca se suben reportes reales.
Los genera `python3 dev/tests/xlsx/hacer-xlsx.py`.

- `yape-reporte.xlsx`: reporte de movimientos de Yape con el mismo formato que baja la app (textos en línea).
- `yape-reporte-compartidas.xlsx`: mismo contenido hecho con openpyxl (textos compartidos), para probar las dos formas de guardar texto en un .xlsx.

Los usa la sección 16 de `dev/tests/nazca-pdf.mjs`.
