# PDF de prueba (inventados)

Imitan el diseño del «Estado de Cuenta de Ahorros Cuenta Digital BCP» y del «ESTADO DE CUENTA» de ahorros de Interbank: mismas columnas, fechas sin año (`30SET`), montos sin signo (cargo o abono según la columna), marcas `*` y `1`, `TOTAL MOVIMIENTO` y `SALDO` al final. **Nombres, cuentas y montos son falsos.** Nunca se agregan aquí estados de cuenta reales.

| Archivo | Para qué |
|---|---|
| `bcp-ahorros.pdf` | Marzo de 2026, 2 páginas, `28FEB` antes del periodo, comisión de 0.00, pares de ida y vuelta. Cuadra. |
| `bcp-ahorros-enero.pdf` | Enero de 2026 con `31DIC` (año anterior). Cuadra. |
| `bcp-no-cuadra.pdf` | Igual que el primero, pero el total de cargos impreso está mal: debe avisar que no cuadra. |
| `bcp-tarjeta.pdf` | Imita el «Estado de Cuenta Tarjeta VISA» del BCP: columnas Soles y Dólares, pago con `-` al final, «CUOTA DEL MES» y el plan de cuotas. Cuadra. |
| `bcp-tarjeta-no-cuadra.pdf` | El monto total facturado impreso está mal: debe avisar que no cuadra. |
| `bcp-ahorros-clave.pdf` | El primero con clave `12345678` (un DNI inventado). |
| `bcp-malicioso.pdf` | Descripciones con `<img onerror>` y `</script><script>`: se muestran como texto. |
| `interbank-ahorros.pdf` | Imita el «ESTADO DE CUENTA» de ahorros de Interbank: fecha completa, monto con signo, saldo por fila, `EMPEZASTE … CON` / `SALDO CONTABLE AL …` y una página-guía con movimientos de ejemplo que no se leen. Cuadra. |
| `interbank-enero.pdf` | Periodo de diciembre a enero (el año cambia). Cuadra. |
| `interbank-no-cuadra.pdf` | El total de gastos impreso está mal: debe avisar que no cuadra. |
| `interbank-tarjeta.pdf` | Imita el estado de cuenta de la TARJETA de Interbank: «Detalle de pago del mes» con columnas S/ y US$, deuda anterior, pago, cuotas del mes y seguro. Cuadra. |
| `interbank-tarjeta-consumos.pdf` | Con una sección «Tus consumos» y dos pagos (el diseño de esa sección es una suposición: no se ha visto en un estado real). Cuadra. |
| `interbank-tarjeta-no-cuadra.pdf` | El pago del mes impreso está mal: debe avisar que no cuadra. |
| `bbva-cuenta.pdf` | Imita el «MOVIMIENTO Y SALDO A LA FECHA» de una cuenta sueldo de BBVA Perú: fechas `dd-mm` sin año, cargo con `-` al final, saldo por fila, `SALDO ANTERIOR` y `SALDO A SU FAVOR`. Cuadra. |
| `bbva-enero.pdf` | Estado de enero con movimientos de diciembre (el año cambia) y un ITF aparte. Cuadra. |
| `bbva-no-cuadra.pdf` | El saldo final impreso está mal: debe avisar que no cuadra. |
| `bbva-dolares.pdf` | `MONEDA: DOLARES` → USD. |
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

- `bofa-cheques.pdf`, `bofa-no-cuadra.pdf`, `apple-card.pdf`, `apple-card-no-cuadra.pdf`, `community-bank.pdf`, `community-bank-no-cuadra.pdf`: estados inventados con el diseño de Bank of America (español), Apple Card y Community Bank; los "no-cuadra" traen el saldo final alterado. `../csv/prueba-apple-card.csv`: el CSV de Apple Card (se reconoce por sus columnas).
- `capital-one-cuenta.pdf`, `capital-one-cuenta-no-cuadra.pdf`: estados inventados de la cuenta Capital One 360 Checking (monto con signo, saldo corrido, descripciones de dos líneas).
- `capital-one-nuevo.pdf`, `capital-one-nuevo-no-cuadra.pdf`: estados inventados con el diseño actual de Capital One (Quicksilver/Savor): periodo sin título, "Transactions +", "Other Credits", intereses del resumen.
- `io-tarjeta.pdf`, `io-no-cuadra.pdf`, `io-tarjeta-clave.pdf`: estado inventado de la tarjeta iO (Perú); el último va cifrado con la clave `12345678` (como si fuera el DNI).
