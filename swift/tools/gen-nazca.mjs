#!/usr/bin/env node
// Genera lo que Swift necesita para igualar a Nazca (dev/app/src/core/nazca/csv.js) ejecutando el código REAL de la web:
//   1. Sources/PlataCore/Nazca/NazcaTables.swift — las tablas (reglas de encabezado y catálogo de comercios) copiadas tal cual.
//   2. Tests/.../Fixtures/nazca_csv.json — los resultados esperados para cada archivo de dev/tests/csv y para muchos casos sueltos.
//   3. Tests/.../Fixtures/csv/* — copias de los archivos de prueba.
//
//   node swift/tools/gen-nazca.mjs
import { readFileSync, writeFileSync, mkdirSync, readdirSync, copyFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const require = createRequire(import.meta.url);
const src = readFileSync(join(root, 'dev/app/src/core/nazca/csv.js'), 'utf8')
  .replace('return { decode,', 'return { CATALOG, ROLES, STOP, CUR_RE, decode,');
const mod = { exports: {} };
new Function('module', src)(mod);
const N = mod.exports;

// ---- 1. Tablas ----
const raw = (re) => 'Rx(#"' + re.source + '"#' + (re.flags.includes('i') ? ', ci: true' : '') + ')';
let out = '// GENERADO por swift/tools/gen-nazca.mjs a partir de dev/app/src/core/nazca/csv.js. No editar a mano.\nimport Foundation\n\nextension Nazca {\n';
out += '    static let roleNames = ' + JSON.stringify(Object.keys(N.ROLES)) + '\n';
out += '    static let roleRules: [String: (re: Rx, prefer: Rx?, avoid: Rx?)] = [\n';
for (const [k, v] of Object.entries(N.ROLES)) out += `        "${k}": (${raw(v.re)}, ${v.prefer ? raw(v.prefer) : 'nil'}, ${v.avoid ? raw(v.avoid) : 'nil'}),\n`;
out += '    ]\n';
out += '    static let catalog: [(String, [String], Rx)] = [\n';
for (const [n, cats, re] of N.CATALOG) out += `        (${JSON.stringify(n)}, ${JSON.stringify(cats)}, ${raw(re)}),\n`;
out += '    ]\n';
out += `    static let stopRx = ${raw(N.STOP)}\n`;
out += '}\n';
writeFileSync(join(root, 'swift/PlataCore/Sources/PlataCore/Nazca/NazcaTables.swift'), out);

// ---- 2/3. Vectores ----
const fx = join(root, 'swift/PlataCore/Tests/PlataCoreTests/Fixtures');
const csvDir = join(root, 'dev/tests/csv');
mkdirSync(join(fx, 'csv'), { recursive: true });
const files = readdirSync(csvDir).filter((f) => /\.(csv|tsv)$/.test(f)).sort();
const round = (x) => x;
const fileCases = files.map((name) => {
  copyFileSync(join(csvDir, name), join(fx, 'csv', name));
  const a = N.analyze(N.decode(readFileSync(join(csvDir, name))));
  const e = N.extract(a);
  return { name, delim: a.delim, headerRow: a.headerRow, headers: a.headers, width: a.width, cols: a.cols, dec: a.dec, order: a.order, rows: a.rows.length, truncated: a.truncated, items: e.items, skipped: e.skipped };
});

const amounts = ['(12.50)', '12.50-', 'S/ 1,234.56', '1 234,56', 'abc', '1.2.3', '', '  ', '-', '+5', '+ 5.5', '−7.25', '–7,25', '12.5 DB', '12.50DB', '12.5 cr', '99 CR', '12,5', '1,234', '1.234', '1,234,567.89', '1.234.567,89', '$ 45.00', 'US$ 45.00', 'USD 45', '€ 3,50', '(S/ 20.00)', '-(5)', '(5)-', '0', '0.00', '.5', '5.', '1,2,3', '1.234,5', '12 345,67', '100%', 'S/. 10.00', 'PEN 10', 'soles 30', '1e5', '0,005', '2.675', '1.005', '-1.005', '3.14159', '123456789.126', '12.5 dr', 'abc 12', '12 abc'];
const amountCases = [];
for (const v of amounts) for (const d of ['.', ',']) amountCases.push({ v, dec: d, out: N.parseAmount(v, d) });

const dates = ['25/10/2026', '2026-10-25', '25-oct-2026', '10/25/2026', '31/02/2026', '29/02/2028', '29/02/2026', '25/10/26', '20261025', '2026/10/25', '2026.10.25 10:30', '2026-10-25T10:30:00', '1/2/2026', '01/02/2026 12:00', '25 oct 2026', '25 Oct. 2026', 'Oct 25, 2026', 'oct 25 2026', 'October 25, 2026', '25 de octubre de 2026', '', 'abc', '1989-01-01', '2101-01-01', '00/00/2026', '32/01/2026', '12/31/2026', '25.10.2026', '25-10-26', '5 set 2026', '5 sep 2026', '5 dic 2026', '5 dec 2026', '5 ene 2026', '5 xyz 2026', '2026-13-01', '2026-02-30', '31/12/1999', '2026-10-25 '];
const dateCases = [];
for (const v of dates) for (const o of ['dmy', 'mdy']) dateCases.push({ v, order: o, out: N.parseDate(v, o), parts: N.dateParts(v) });

const norms = ['Hola Mundo', 'ÁÉÍÓÚ ñandú', '  UBER *TRIP  LIMA ', 'S/ 12.50', 'US$ 4', 'a-b_c', 'Café – Niño', 'COMPRA 123/ABC', '$$', '', 'İstanbul', 'ｆｕｌｌ', 'tab\there', 'x́y'];
const normCases = norms.map((v) => ({ v, out: N.norm(v) }));
const curs = ['PEN', 'S/', 'S/.', 'soles', 'Soles', 'USD', 'US$', '$', 'dolares', 'Dólares', 'EUR', '€', 'Euro', 'MN', 'ME', 'GBP', 'cop', 'xx', '', 'S', 'nuevos soles', 'US'];
const curCases = curs.map((v) => ({ v, out: N.curOf(v) }));
const roleCases = ['Fecha', 'Fecha de operación', 'Fecha proceso', 'Descripción', 'Concepto', 'Monto', 'Importe', 'Cargo', 'Abono', 'Saldo', 'Moneda', 'Tipo', 'D/C', 'Debe', 'Haber', 'Money out', 'Posted Date', 'Transaction Date', 'Amount', 'Memo', 'Valor', 'Nombre', 'Movimiento', 'Operación', 'xyz', '', 'Saldo disponible', 'Cargo/Abono', 'Total'].map((v) => ({ v, out: N.roleOf(v) }));

const cats12 = ['Comida', 'Transporte', 'Ocio', 'Salud', 'Compras', 'Servicios', 'Viajes', 'Hogar', 'Suscripciones', 'Educación', 'Mascotas', 'Otros'];
const catSets = [
  { cats: cats12, hist: [] },
  { cats: ['Comida', 'Transporte', 'Ocio', 'Otros'], hist: [] },
  { cats: ['Comida', 'Transporte', 'Ocio', 'Alquiler', 'Mascotas', 'Otros'], hist: [{ amount: -30, note: 'VET SAN BORJA 123', category: 'Mascotas' }, { amount: -12, note: 'TAMBO MIRAFLORES', category: 'Ocio' }] },
  { cats: ['Casa', 'Otros'], hist: [] },
  { cats: ['Casa', 'Auto'], hist: [] },
  { cats: [], hist: [] },
];
const descs = ['COMPRA TAMBO+ MIRAFLORES', 'UBER *TRIP LIMA', 'NETFLIX.COM', 'VET SAN BORJA 456', 'SUELDO', 'ALGO RARO', 'UBER EATS 8005928996 CA', 'WALGREENS #5231 SAN FRANCISCO', 'AMZN Mktp US*2K4', 'AMAZON PRIME VIDEO', 'SHELL OIL 57444', 'CHICK-FIL-A #02211', 'T-MOBILE AUTOPAY', 'COMPRA INKAFARMA SURCO', 'PAGO LUZ DEL SUR', 'CONSUMO SAGA FALABELLA', 'LATAM AIRLINES PE', 'ICLOUD.COM/BILL', 'SODIMAC SAN BORJA', 'COURSERA.ORG', 'HOTEL LIABILITY INSURANCE', 'TRANSFER TO MONEY MARKET', 'PAYPAL *JUAN', 'ALQUILER OCTUBRE', 'Casa de la abuela', 'SPOTIFY P1234', 'COSTCO WHSE #123', 'STARBUCKS JOCKEY', 'PLAZA VEA SAN MIGUEL', 'PAGO TARJETA VISA'];
const catCases = [];
catSets.forEach((s, si) => { const f = N.categorizer(s.cats.map((name) => ({ name })), s.hist); descs.forEach((d) => [-10, 10].forEach((am) => catCases.push({ set: si, d, am, out: f(d, am) }))); });
const merchants = descs.map((d) => ({ d, out: N.merchant(d) }));

const fileItems = fileCases.find((c) => c.name === 'a-con-signo.csv').items;
const fp = N.fingerprints(fileItems);
const existing = [{ acc: 'a', date: '2026-10-03', amount: -23.4, note: 'Uber' }, { acc: 'a', date: '2026-10-07', amount: -44.9, imp: fp[4] }, { acc: 'otra', date: '2026-10-02', amount: -12.5 }, { acc: 'a', date: '2026-10-09', amount: 100 }];
const dups = N.markDuplicates(fileItems, existing, 'a');
const dupsMix = N.markDuplicates(fileItems, existing, 'otra');

// ---- 4. Excel (.xlsx) y Yape ----
const X = require(join(root, 'dev/app/src/core/nazca/xlsx.js')), Y = require(join(root, 'dev/app/src/core/nazca/bancos/yape-movimientos.js'));
mkdirSync(join(fx, 'xlsx'), { recursive: true });
const xlsxDir = join(root, 'dev/tests/xlsx');
const xlsxCases = [];
for (const name of readdirSync(xlsxDir).filter((f) => f.endsWith('.xlsx')).sort()) {
  copyFileSync(join(xlsxDir, name), join(fx, 'xlsx', name));
  const rows = await X.read(readFileSync(join(xlsxDir, name)));
  xlsxCases.push({ name, rows, detect: Y.detect(rows), yape: Y.read(rows) });
}
const yapeMoney = [['Tipo de Transacción', 'Origen', 'Destino', 'Monto', 'Mensaje', 'Fecha de operación'],
  ['PAGASTE', 'Yo', 'Tambo+ Miraflores', 'S/ 16.08', 'Compra Nº 12345678', '20/10/2026 13:10:26'],
  ['TE PAGÓ', 'Sara Ron*', 'Yo', '1,250.50', '', '21/10/2026'],
  ['te yapeó', 'Juan P*', 'Yo', '10,5', 'gracias: N° ABCD-1234 listo', '5/1/2026 09:00'],
  ['OTRO', 'x', 'y', '5', '', '01/01/2026'], ['PAGASTE', 'Yo', 'Cero', '0.00', '', '02/01/2026'], ['PAGASTE', 'Yo', 'Sin fecha', '5', '', 'mañana'], ['', '', '', '', '', ''],
  ['Recargaste', 'Yo', '', '20', 'x'.repeat(120), '31/02/2026']];
const yapeSynth = { rows: yapeMoney, detect: Y.detect(yapeMoney), yape: Y.read(yapeMoney) };
const yapeNo = [Y.detect([['a', 'b'], ['1', '2']]), Y.detect([])];

console.log('Listo:', fileCases.length, 'archivos,', amountCases.length, 'montos,', dateCases.length, 'fechas,', catCases.length, 'categorías.');

writeFileSync(join(fx, 'nazca_csv.json'), JSON.stringify({ files: fileCases, amounts: amountCases, dates: dateCases, norms: normCases, curs: curCases, roles: roleCases, cats: catSets, descs, categories: catCases, merchants, fp: { items: fileItems, prints: fp, existing, dups, dupsMix }, xlsx: xlsxCases, yapeSynth, yapeNo }));
