#!/usr/bin/env node
// Genera lo que Swift necesita para igualar al lector de constancias de Yape y Plin (dev/app/src/core/nazca/constancia.js) ejecutando el código REAL de la web:
//   1. Sources/PlataCore/Nazca/NazcaConstanciaTables.swift — las reglas (expresiones regulares y meses) copiadas tal cual.
//   2. Tests/.../Fixtures/nazca_constancia.json — lo que lee la web para los textos INVENTADOS de dev/tests/constancias.json y para muchas combinaciones.
//
//   node swift/tools/gen-nazca-constancia.mjs
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const require = createRequire(import.meta.url);
const K = require(join(root, 'dev/app/src/core/nazca/constancia.js'));
const T = K.TABLES;

// ---- 1. Tablas ----
const raw = (re) => 'Rx(#"' + re.source + '"#' + (re.flags.includes('i') ? ', ci: true' : '') + ')';
const names = { NEG: 'neg', POS: 'pos', KEY: 'key', BAD: 'bad', AMT: 'amt', LABEL_TO: 'labelTo', LABEL_FROM: 'labelFrom', LABEL_MSG: 'labelMsg', LABELISH: 'labelish', INLINE_NEG: 'inlineNeg', INLINE_POS: 'inlinePos', OP: 'op', DATE_ISO: 'dateIso', DATE_WORDS: 'dateWords', DATE_NUM: 'dateNum', TIME_RE: 'timeRe' };
let out = '// GENERADO por swift/tools/gen-nazca-constancia.mjs a partir de dev/app/src/core/nazca/constancia.js. No editar a mano.\nimport Foundation\n\nextension NazcaConstancia {\n';
for (const [k, v] of Object.entries(names)) out += `    static let ${v} = ${raw(T[k])}\n`;
out += '    static let months: [String: Int] = [' + Object.entries(T.MONTHS).map(([k, v]) => `"${k}": ${v}`).join(', ') + ']\n';
out += `    static let maxChars = ${K.MAX_CHARS}\n    static let maxLines = ${K.MAX_LINES}\n`;
out += '}\n';
writeFileSync(join(root, 'swift/PlataCore/Sources/PlataCore/Nazca/NazcaConstanciaTables.swift'), out);

// ---- 2. Vectores ----
const base = JSON.parse(readFileSync(join(root, 'dev/tests/constancias.json'), 'utf8'));
const today = base.today;
const texts = base.cases.map((c) => c.text);

// Combinaciones (determinista): monto × fecha × encabezado × destinatario × operación
let seed = 20261029; const rnd = (n) => { seed = (Math.imul(seed, 1103515245) + 12345) >>> 0; return seed % n; };
const amounts = ['S/ 18', 'S/. 18.50', 'S/1,234.50', 'S/ 1.234,50', 'S/ 0.50', 'PEN 20', 'US$ 5.00', '$ 12', '5/ 7.25', 'S/ 12,5', 'S/ 1 234.50', 'S/ 0', 'S/ 1,234', 'S/ 99999999', 'S/ 3.', 'S/ abc'];
const dates = ['29 oct. 2026 - 02:15 p. m.', '29/10/2026 14:15', '2026-10-29 08:05', '3 de noviembre de 2026', '12 SET 2026 06:40 PM', '31/04/2026', '5/10/26', '29 Oct 2026 12:00 am', '1 ene 2026 12:30 a. m.', '15 de mayo de 2026 11:59 pm', ''];
const heads = ['Yapeaste', '¡Yapeaste!', 'Plin enviado', 'Te yapearon', 'Sara te yapeó', 'Constancia de pago', 'Recibiste', 'Plineaste', 'Yape', 'Pagaste'];
const whos = ['Destino\nJuan Pérez V.', 'Enviado a: MARIA LOPEZ', 'Origen\nAna Z.', '', 'Para: ***  *** 123', 'Nombre del destinatario\nÑandú Pérez Gómez', 'Remitente: LUIS', 'Destinatario\nCelular\n*** 456', 'Beneficiario: Tienda Úrsula\nMensaje\nalmuerzo del lunes'];
const ops = ['N° de operación 01234567', 'Código de operación: AB-123', 'Operación 12', '', 'Nro. de operación\n99887766', 'Número de operación: 55-66-77', 'ID de operación X9Y8Z7W6'];
const vias = ['', '', '', 'Interbank', 'BCP', 'BBVA', 'Banco de Crédito'];
const combos = [];
for (let i = 0; i < 220; i++) {
  const a = amounts[rnd(amounts.length)], d = dates[rnd(dates.length)], h = heads[rnd(heads.length)], w = whos[rnd(whos.length)], o = ops[rnd(ops.length)], v = vias[rnd(vias.length)];
  const order = rnd(3);
  const parts = order === 0 ? [h + ' ' + a, d, w, o, v] : order === 1 ? [h, 'Monto', a, w, d, o, v] : [v, h, w, a, d, o];
  combos.push(parts.filter(Boolean).join('\n'));
}
const extras = ['', '   ', '\n\n', 'S/', 'S/ 5', 'Yape S/ 5', 'yape\r\nYapeaste S/ 5\r\n10/10/2026\r\nOperación 1234567', 'Plin y Yape\nPlineaste S/ 7\n2026-01-02', 'Te pagó S/ 60 Yape\n2026-02-30', 'Yapeaste S/ 10\nS/ 12\nS/ 14\n2026-03-03 Operación 11223344',
  'Comisión S/ 0.50\nSaldo S/ 120.00\nPlin enviado S/ 20.00\n04/05/2026', 'x'.repeat(7000) + '\nYapeaste S/ 5', 'Yapeaste S/ 5\n' + 'línea\n'.repeat(100) + '10/10/2026 Operación 12345678'];
const all = texts.concat(combos, extras);
const R = (r) => r.error ? { error: r.error } : { bank: r.bank || '', kind: r.kind, label: r.label, name: r.name, cur: r.cur, period: r.period, items: r.items.map((i) => ({ line: i.line, date: i.date, desc: i.desc, amount: i.amount, cur: i.cur, ref: i.ref || '' })), brand: r.brand, op: r.op, time: r.time, flags: r.flags, auto: r.auto };
const cases = all.flatMap((text) => [0, 1, -1].map((sign) => ({ text, sign, detect: K.detect(text), read: R(K.read(text, { today, sign })) })));
const fx = join(root, 'swift/PlataCore/Tests/PlataCoreTests/Fixtures');
mkdirSync(fx, { recursive: true });
writeFileSync(join(fx, 'nazca_constancia.json'), JSON.stringify({ today, cases }));
const kinds = {}; cases.forEach((c) => { const k = c.read.error ? 'error' : c.read.brand || 'sin marca'; kinds[k] = (kinds[k] || 0) + 1; });
console.log(cases.length + ' casos', JSON.stringify(kinds));
