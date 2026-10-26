# PDF de prueba (inventados)

Imitan el diseño del «Estado de Cuenta de Ahorros Cuenta Digital BCP»: mismas columnas, fechas sin año (`30SET`), montos sin signo (cargo o abono según la columna), marcas `*` y `1`, `TOTAL MOVIMIENTO` y `SALDO` al final. **Nombres, cuentas y montos son falsos.** Nunca se agregan aquí estados de cuenta reales.

| Archivo | Para qué |
|---|---|
| `bcp-ahorros.pdf` | Marzo de 2026, 2 páginas, `28FEB` antes del periodo, comisión de 0.00, pares de ida y vuelta. Cuadra. |
| `bcp-ahorros-enero.pdf` | Enero de 2026 con `31DIC` (año anterior). Cuadra. |
| `bcp-no-cuadra.pdf` | Igual que el primero, pero el total de cargos impreso está mal: debe avisar que no cuadra. |
| `bcp-ahorros-clave.pdf` | El primero con clave `12345678` (un DNI inventado). |
| `bcp-malicioso.pdf` | Descripciones con `<img onerror>` y `</script><script>`: se muestran como texto. |
| `otro-banco.pdf` | No es del BCP: no se reconoce. |
| `sin-texto.pdf` | Sin texto (como una foto escaneada). |

Se regeneran con `python3 dev/tests/pdf/hacer-pdfs.py` (necesita `reportlab` y `qpdf`); no hace falta para correr las pruebas. Para sumar un banco: un PDF inventado con su diseño, su lector en `dev/app/src/core/nazca/bancos/` y sus pruebas en `nazca-pdf.mjs`.
