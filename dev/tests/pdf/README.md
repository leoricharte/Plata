# PDF de prueba (inventados)

Imitan el diseño del «Estado de Cuenta de Ahorros Cuenta Digital BCP» y del «ESTADO DE CUENTA» de ahorros de Interbank: mismas columnas, fechas sin año (`30SET`), montos sin signo (cargo o abono según la columna), marcas `*` y `1`, `TOTAL MOVIMIENTO` y `SALDO` al final. **Nombres, cuentas y montos son falsos.** Nunca se agregan aquí estados de cuenta reales.

| Archivo | Para qué |
|---|---|
| `bcp-ahorros.pdf` | Marzo de 2026, 2 páginas, `28FEB` antes del periodo, comisión de 0.00, pares de ida y vuelta. Cuadra. |
| `bcp-ahorros-enero.pdf` | Enero de 2026 con `31DIC` (año anterior). Cuadra. |
| `bcp-no-cuadra.pdf` | Igual que el primero, pero el total de cargos impreso está mal: debe avisar que no cuadra. |
| `bcp-ahorros-clave.pdf` | El primero con clave `12345678` (un DNI inventado). |
| `bcp-malicioso.pdf` | Descripciones con `<img onerror>` y `</script><script>`: se muestran como texto. |
| `interbank-ahorros.pdf` | Imita el «ESTADO DE CUENTA» de ahorros de Interbank: fecha completa, monto con signo, saldo por fila, `EMPEZASTE … CON` / `SALDO CONTABLE AL …` y una página-guía con movimientos de ejemplo que no se leen. Cuadra. |
| `interbank-enero.pdf` | Periodo de diciembre a enero (el año cambia). Cuadra. |
| `interbank-no-cuadra.pdf` | El total de gastos impreso está mal: debe avisar que no cuadra. |
| `interbank-dolares.pdf` | Cuenta en dólares y periodo «DEL 1 AL 30 DE NOVIEMBRE». |
| `otro-banco.pdf` | No es del BCP: no se reconoce. |
| `sin-texto.pdf` | Sin texto (como una foto escaneada). |

Se regeneran con `python3 dev/tests/pdf/hacer-pdfs.py` (necesita `reportlab` y `qpdf`); no hace falta para correr las pruebas. Para sumar un banco: un PDF inventado con su diseño, su lector en `dev/app/src/core/nazca/bancos/` y sus pruebas en `nazca-pdf.mjs`.

## Documentos de prueba de bancos que Nazca no conoce
`capital-one-falso.pdf` (tarjeta de crédito, estilo estadounidense, USD) y `banco-equis-falso.pdf` (cuenta corriente). Son INVENTADOS, dicen "DOCUMENTO DE PRUEBA" y no copian ningún diseño real. Sirven para probar la lectura genérica (`pdf-generico.js`): se importan como "Archivo PDF", sin sello de verificado y sin la comprobación "Cuadra".

`capital-one-marzo.pdf`, `capital-one-abril.pdf`, `capital-one-no-cuadra.pdf`: tarjeta Capital One INVENTADA (lector `capitalone-tarjeta.js`, verificado). `banco-equis-falso.pdf` y `banco-zeta-falso.pdf`: bancos que Nazca no conoce (lectura genérica, sin verificado). `dev/tests/csv/prueba-*.csv`: 3 CSV de prueba.

`chime-checking.pdf`, `chime-no-cuadra.pdf`: cuenta corriente Chime INVENTADA (lector `chime-checking.js`). `banco-eta/theta/iota/kappa/lambda.pdf`: distintos diseños de bancos desconocidos para probar el lector genérico. `sin-movimientos.pdf`: texto sin movimientos.

`seen-tarjeta.pdf`, `seen-no-cuadra.pdf`: tarjeta Seen INVENTADA (lector `seen-tarjeta.js`).

`tarjeta-omega.pdf` (inglés, compras en positivo) y `tarjeta-sigma.pdf` (español, compras en negativo): tarjetas de crédito de bancos que Nazca no conoce, para probar el reconocimiento por pistas.
