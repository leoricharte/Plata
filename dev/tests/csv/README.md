# CSV de prueba (inventados)

Ningún archivo de esta carpeta es una exportación real de un banco: los formatos imitan variantes comunes
(separadores, encabezados, signos, monedas, fechas) y los datos son ficticios. Cuando haya exportaciones reales
de un banco, con los datos borrados, se agregan aquí como `banco-<nombre>.csv` con su resultado esperado en `nazca.mjs`.

| Archivo | Qué prueba |
|---|---|
| `a-con-signo.csv` | Coma, UTF-8, líneas del banco antes de la tabla, monto con signo, miles con coma, comillas, columna de saldo y fila "Saldo final" |
| `b-cargo-abono.csv` | Punto y coma, Windows-1252, columnas separadas de cargo y abono, decimal con coma, dos columnas de fecha |
| `c-tipo-moneda.tsv` | Tabulador, monto sin signo + columna de tipo (D/C), columna de moneda mezclada, fechas como 25-oct-2026 |
| `d-tarjeta.csv` | Estado de tarjeta: consumos en positivo y pago en negativo (la pantalla ofrece invertir signos) |
| `e-sin-encabezado.csv` | Sin encabezado: se adivina por el contenido |
| `f-formato-eeuu.csv` | Fechas mes/día/año y montos como $1,234.56 |
| `g-malicioso.csv` | HTML y fórmulas en las descripciones, fila futura, filas ilegibles |
