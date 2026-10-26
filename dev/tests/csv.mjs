// Pruebas del importador de CSV (dev/app/src/core/csv.js) con los archivos inventados de dev/tests/csv/.
// Uso: node dev/tests/csv.mjs   · Cada prueba imprime OK/FALLA.
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
const require = createRequire(import.meta.url);
const C = require('../app/src/core/csv.js');
const dir = new URL('./csv/', import.meta.url);
let f = 0;
const ok = (c, m) => { console.log((c ? 'OK    ' : 'FALLA ') + m); if (!c) f++; };
const load = (name) => { const a = C.analyze(C.decode(readFileSync(new URL(name, dir)))); return { a, ...C.extract(a) }; };
const sum = (items) => Math.round(items.reduce((s, x) => s + x.amount, 0) * 100) / 100;

// a) coma, preámbulo, monto con signo, miles, comillas, saldo, fila de total
{ const { a, items, skipped } = load('a-con-signo.csv');
  ok(a.delim === ',' && a.headers.join('|') === 'Fecha|Descripción|Monto|Saldo', 'a: separador coma y encabezado encontrado tras las líneas del banco');
  ok(items.length === 7 && skipped.total === 1, 'a: 7 movimientos y la fila "Saldo final" se omite (' + items.length + ', total ' + skipped.total + ')');
  ok(items[0].desc === 'SUELDO ESTUDIO, OCTUBRE' && items[0].amount === 3503, 'a: comillas con coma dentro y monto positivo');
  ok(items[6].amount === -1234.56 && items[6].balance === 1592.64, 'a: "-1,234.56" y saldo "1,592.64"');
  ok(items[0].date === '2026-10-01' && items[6].date === '2026-10-10', 'a: fechas dd/mm/aaaa'); }

// b) punto y coma, Windows-1252, cargo/abono, decimal con coma, dos fechas (usa la de operación)
{ const { a, items } = load('b-cargo-abono.csv');
  ok(a.delim === ';' && a.dec === ',', 'b: punto y coma y decimal con coma');
  ok(items[0].desc === 'TRANSF. RECIBIDA JOSÉ PÉREZ', 'b: tildes de Windows-1252 bien leídas (' + items[0].desc + ')');
  ok(items[0].amount === 250 && items[1].amount === -80.5 && items[3].amount === -1045.9, 'b: abono positivo, cargo negativo, "1.045,90"');
  ok(items[0].date === '2026-10-01', 'b: usa la fecha de operación, no la de proceso (' + items[0].date + ')'); }

// c) tabulador, tipo D/C, moneda por fila, fechas con mes en letras
{ const { a, items } = load('c-tipo-moneda.tsv');
  ok(a.delim === '\t' && a.cols.type >= 0 && a.cols.currency >= 0, 'c: tabulador, columna de tipo y de moneda');
  ok(items.map((x) => x.amount).join(',') === '500,-19.9,-25,-15.3', 'c: el tipo D/C da el signo');
  ok(items.map((x) => x.cur).join(',') === 'PEN,PEN,USD,PEN', 'c: moneda por fila (PEN, USD, "Soles" → PEN)');
  ok(items[0].date === '2026-10-01', 'c: "01-oct-2026"'); }

// d) estado de tarjeta: consumos positivos (la pantalla ofrece invertir)
{ const { items } = load('d-tarjeta.csv');
  ok(items.length === 3 && items.filter((x) => x.amount > 0).length === 2, 'd: consumos en positivo, como vienen (la pantalla decide invertir)'); }

// e) sin encabezado
{ const { a, items } = load('e-sin-encabezado.csv');
  ok(a.headerRow === -1 && items.length === 3 && items[2].amount === 45 && items[1].desc === 'STARBUCKS JOCKEY', 'e: sin encabezado, columnas adivinadas por el contenido'); }

// f) formato EE. UU.
{ const { a, items } = load('f-formato-eeuu.csv');
  ok(a.order === 'mdy' && items[0].date === '2026-10-13' && items[2].date === '2026-10-02', 'f: mes/día/año detectado por "10/13/2026"');
  ok(items[0].amount === -1234.56 && items[1].amount === 2000, 'f: "-$1,234.56" y "$2,000.00"'); }

// g) contenido malicioso y filas raras
{ const { items, skipped } = load('g-malicioso.csv');
  ok(items.length === 4, 'g: 4 filas válidas (incluida la futura, que la pantalla excluye) · ' + items.length);
  ok(items[0].desc === '<img src=x onerror=alert(1)>', 'g: el texto se guarda tal cual (se escapa al mostrarlo, no aquí)');
  ok(skipped.unreadable === 2, 'g: fila rota y monto cero se omiten (' + skipped.unreadable + ')'); }

// Números y fechas sueltos
ok(C.parseAmount('(12.50)', '.') === -12.5 && C.parseAmount('12.50-', '.') === -12.5 && C.parseAmount('S/ 1,234.56', '.') === 1234.56 && C.parseAmount('1 234,56', ',') === 1234.56, 'números: paréntesis, signo al final, S/ y espacio de miles');
ok(C.parseAmount('abc', '.') === null && C.parseAmount('1.2.3', '.') === null, 'números: texto o puntos de más → nada');
ok(C.parseDate('31/02/2026', 'dmy') === null && C.parseDate('29/02/2028', 'dmy') === '2028-02-29' && C.parseDate('25/10/26', 'dmy') === '2026-10-25' && C.parseDate('20261025') === '2026-10-25', 'fechas: 31 de febrero no existe, bisiesto, año corto, AAAAMMDD');

// Categorías: aprendidas de tus movimientos, nombres propios y palabras clave
{ const cats = [{ name: 'Comida' }, { name: 'Transporte' }, { name: 'Ocio' }, { name: 'Alquiler' }, { name: 'Mascotas' }, { name: 'Otros' }];
  const cat = C.categorizer(cats, [{ amount: -30, note: 'VET SAN BORJA 123', category: 'Mascotas' }]);
  ok(cat('COMPRA TAMBO+ MIRAFLORES', -12.5) === 'Comida' && cat('UBER *TRIP LIMA', -23.4) === 'Transporte' && cat('NETFLIX.COM', -44.9) === 'Ocio', 'categorías: palabras clave');
  ok(cat('VET SAN BORJA 456', -40) === 'Mascotas', 'categorías: aprende de lo que ya registraste');
  ok(cat('SUELDO', 3503) === 'Ingreso' && cat('ALGO RARO', -1) === 'Otros', 'categorías: ingreso y "Otros" por defecto');
  const sinComida = C.categorizer([{ name: 'Casa' }, { name: 'Otros' }], []);
  ok(sinComida('TAMBO', -5) === 'Otros', 'categorías: no inventa categorías que la persona no tiene'); }

// Repetidos
{ const { items } = load('a-con-signo.csv');
  const prints = C.fingerprints(items);
  ok(prints[1] !== prints[5], 'repetidos: dos compras iguales el mismo archivo tienen huellas distintas (no se fusionan)');
  const existing = [{ acc: 'a', date: '2026-10-03', amount: -23.4, note: 'Uber' }, { acc: 'a', date: '2026-10-07', amount: -44.9, imp: prints[4] }, { acc: 'otra', date: '2026-10-02', amount: -12.5 }];
  const d = C.markDuplicates(items, existing, 'a');
  ok(d[2].dup === 'near' && d[4].dup === 'exact' && d[1].dup === '' && d.filter((x) => x.dup).length === 2, 'repetidos: uno anotado a mano (fecha ±2 días) y uno ya importado; otra cuenta no cuenta'); }

// Límites
{ let big = 'Fecha,Descripción,Monto\n'; for (let i = 0; i < 6000; i++) big += '01/10/2026,X' + i + ',-1.00\n';
  const a = C.analyze(big); ok(a.rows.length === C.MAX_ROWS && a.truncated, 'límite: como máximo ' + C.MAX_ROWS + ' filas, y avisa que cortó'); }

console.log(f ? '\n' + f + ' FALLAS' : '\nTodo bien');
process.exit(f ? 1 : 0);
