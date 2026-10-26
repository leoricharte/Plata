// Pruebas de Nazca con PDF: lectura con posiciones (pdf.js), lector del BCP, comprobación "cuadra", clave del PDF, límites.
// Usan PDF INVENTADOS de dev/tests/pdf/ (los genera hacer-pdfs.py). Uso: node dev/tests/nazca-pdf.mjs
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
const require = createRequire(import.meta.url);
const P = require('../app/src/core/nazca/pdf.js');
const B = require('../app/src/core/nazca/bancos/index.js');
const dir = new URL('./pdf/', import.meta.url);
let f = 0;
const ok = (c, m) => { console.log((c ? 'OK    ' : 'FALLA ') + m); if (!c) f++; };
// pdf.js avisa por consola que no tiene canvas (no lo necesitamos: solo lee texto); se silencia ese aviso.
const warn = console.warn; console.warn = (...a) => { if (!/canvas|DOMMatrix|Path2D|polyfill/i.test(String(a[0]))) warn(...a); };
const lib = await P.load(pathToFileURL(new URL('../vendor/pdfjs/', import.meta.url).pathname).href);
const bytes = (n) => readFileSync(new URL(n, dir));
const fail = async (p) => { try { await p; return null; } catch (e) { return e.code || String(e); } };
const sum = (it) => Math.round(it.reduce((s, x) => s + x.amount, 0) * 100) / 100;

// 1) estado de ahorros del BCP (marzo 2026, varias páginas)
{ const doc = await P.read(bytes('bcp-ahorros.pdf'), lib);
  ok(doc.pages.length === 2 && doc.pages[0].items.length > 50, 'pdf: lee las 2 páginas con el texto y su posición');
  const rd = B.detect(doc); ok(rd && rd.id === 'bcp-ahorros', 'banco: reconoce el BCP por el contenido');
  const r = rd.read(doc);
  ok(r.label === 'BCP · Cuenta de ahorros' && r.cur === 'PEN' && r.account.last4 === '8045', 'bcp: tipo, moneda (SOLES → PEN) y últimos 4 de la cuenta');
  ok(r.period.from === '2026-03-01' && r.period.to === '2026-03-31', 'bcp: periodo sale del encabezado');
  ok(r.items.length === 21 && r.skipped.zero === 1 && r.skipped.unreadable === 0, 'bcp: 21 movimientos y la comisión de 0.00 se omite (' + r.items.length + ')');
  ok(r.items[0].date === '2026-02-28' && r.items[0].desc === 'ABON PLIN-Ana Gomez' && r.items[0].amount === 70, 'bcp: 28FEB cae en febrero y el * no entra en la descripción');
  ok(r.items[2].amount === -370 && r.items[3].amount === -1.7, 'bcp: cargo → negativo (columna CARGOS)');
  ok(r.items.find((x) => x.desc === 'SUELDO MARZO').amount === 1850.5, 'bcp: abono → positivo (columna ABONOS)');
  const man = r.items.find((x) => /MANTEN/.test(x.desc)); ok(man.date === '2026-03-31' && man.amount === -4.5, 'bcp: usa la fecha de proceso (31MAR), no la valor (15MAR)');
  ok(r.check.have && r.check.ok === true && r.check.prev === 120.3 && r.check.end === 1459.4, 'bcp: CUADRA (saldo anterior + abonos − cargos = saldo final)');
  ok(r.check.totalCharges === 1160.3 && r.check.sumCharges === 1160.3 && r.check.totalCredits === 2499.4 && r.check.sumCredits === 2499.4, 'bcp: totales del banco = suma de lo leído');
  ok(r.items.at(-1).balance === 1459.4 && r.items.slice(0, -1).every((x) => x.balance === null), 'bcp: el saldo final queda en el último movimiento');
  ok(sum(r.items) === Math.round((2499.4 - 1160.3) * 100) / 100, 'bcp: abonos − cargos de lo leído'); }

// 2) cambio de año: 31DIC en un estado de enero
{ const r = B.detect(await P.read(bytes('bcp-ahorros-enero.pdf'), lib)).read(await P.read(bytes('bcp-ahorros-enero.pdf'), lib));
  ok(r.items[0].date === '2025-12-31' && r.items[2].date === '2026-01-02', 'bcp: 31DIC de un estado de enero es del año anterior');
  ok(r.check.ok === true && r.items.length === 6, 'bcp: enero también cuadra'); }

// 3) no cuadra → lo dice
{ const doc = await P.read(bytes('bcp-no-cuadra.pdf'), lib); const r = B.detect(doc).read(doc);
  ok(r.check.have && r.check.ok === false && r.items.length === 21, 'bcp: si el total del banco no coincide con lo leído, check.ok = false'); }

// 4) PDF con clave (el DNI en el BCP)
{ ok(await fail(P.read(bytes('bcp-ahorros-clave.pdf'), lib)) === 'need_password', 'clave: sin clave pide la clave');
  ok(await fail(P.read(bytes('bcp-ahorros-clave.pdf'), lib, '00000000')) === 'bad_password', 'clave: clave equivocada se distingue');
  const doc = await P.read(bytes('bcp-ahorros-clave.pdf'), lib, '12345678'); const r = B.detect(doc).read(doc);
  ok(r.items.length === 21 && r.check.ok === true, 'clave: con la clave correcta se lee igual');
  ok(!JSON.stringify(r).includes('12345678'), 'clave: la clave no aparece en el resultado'); }

// 5) lo que no es del BCP o no se puede leer
{ const doc = await P.read(bytes('otro-banco.pdf'), lib);
  ok(B.detect(doc) === null && B.detect(doc, 'bcp') === null, 'banco: un PDF de otro banco no se reconoce');
  ok(await fail(P.read(bytes('sin-texto.pdf'), lib)) === 'no_text', 'pdf: sin texto (foto escaneada) → no_text');
{ // algunos bancos anteponen bytes antes de "%PDF-": el estándar lo permite (hasta 1024 bytes)
  const src = bytes('bcp-ahorros.pdf'), pre = new TextEncoder().encode('\xEF\xBB\xBF\r\n'.replace(/\\x/g, '') + 'basura previa\r\n');
  const joined = new Uint8Array(pre.length + src.length); joined.set(pre); joined.set(src, pre.length);
  const doc = await P.read(joined, lib); ok(doc.pages.length === 2 && B.detect(doc), 'pdf: acepta bytes antes de la marca %PDF-');
  const far = new Uint8Array(3000 + src.length); far.set(src, 3000);
  ok(await fail(P.read(far, lib)) === 'not_pdf', 'pdf: la marca más allá de 1024 bytes → not_pdf'); }
  ok(await fail(P.read(new TextEncoder().encode('Fecha,Monto\n01/03/2026,-5\n'), lib)) === 'not_pdf', 'pdf: un CSV no es PDF → not_pdf');
  const big = new Uint8Array(P.MAX_BYTES + 1); big.set(new TextEncoder().encode('%PDF-1.4'));
  ok(await fail(P.read(big, lib)) === 'too_big', 'pdf: más de 15 MB → too_big');
  const roto = new TextEncoder().encode('%PDF-1.4\nesto no es un pdf de verdad'); ok(await fail(P.read(roto, lib)) === 'invalid', 'pdf: archivo dañado → invalid'); }

// 5b) texto malicioso dentro del PDF: se guarda tal cual (la pantalla lo escapa al mostrarlo) y no rompe la lectura
{ const doc = await P.read(bytes('bcp-malicioso.pdf'), lib); const r = B.detect(doc).read(doc);
  ok(r.items.length === 3 && r.items[0].desc === '<img src=x onerror=alert(1)>' && r.items[1].desc === '</script><script>alert(2)</script>' && r.check.ok === true, 'malicioso: HTML dentro de la descripción queda como texto y el estado igual cuadra'); }

// 5c) Interbank · ahorros: fechas completas, montos con signo, saldo por fila, y una página-guía con ejemplos que se ignora
{ const doc = await P.read(bytes('interbank-ahorros.pdf'), lib); const rd = B.detect(doc);
  ok(rd && rd.id === 'interbank-ahorros' && doc.pages.length === 2, 'interbank: reconoce el estado por el contenido (2 páginas: datos + guía)');
  ok(B.detect(doc, 'bcp') === null && B.detect(await P.read(bytes('bcp-ahorros.pdf'), lib), 'interbank') === null, 'interbank: el BCP y Interbank no se confunden');
  const r = rd.read(doc);
  ok(r.items.length === 9 && r.cur === 'PEN' && r.account.last4 === '0123' && r.label === 'Interbank · Cuenta Simple', 'interbank: 9 movimientos, soles, últimos 4 y producto (' + r.items.length + ')');
  ok(r.period.from === '2026-02-28' && r.period.to === '2026-03-27', 'interbank: el periodo toma el año de las fechas (' + r.period.from + ' → ' + r.period.to + ')');
  ok(r.items[0].date === '2026-03-02' && r.items[0].amount === 150 && r.items[2].amount === -44.9 && r.items[2].desc === 'Netflix', 'interbank: + es ingreso y − es gasto, con fecha completa');
  ok(r.items.every((i) => i.balance !== null) && r.items[0].balance === 370.4 && r.items[8].balance === 1768.56, 'interbank: cada fila trae su saldo (primera 370.40, última 1,768.56)');
  ok(r.check.ok === true && r.check.running === true && r.check.sumCredits === r.check.totalCredits, 'interbank: cuadra con los totales y el saldo corre fila por fila');
  ok(!r.items.some((i) => i.date.startsWith('2021')) && !r.items.some((i) => i.desc === 'Pago mi TC'), 'interbank: ignora los movimientos de EJEMPLO de la página-guía'); }
{ const doc = await P.read(bytes('interbank-enero.pdf'), lib); const r = B.detect(doc).read(doc);
  ok(r.items[0].date === '2025-12-30' && r.period.from === '2025-12-29' && r.period.to === '2026-01-27' && r.check.ok === true, 'interbank: periodo de diciembre a enero (' + r.period.from + ' → ' + r.period.to + ')'); }
{ const doc = await P.read(bytes('interbank-no-cuadra.pdf'), lib); const r = B.detect(doc).read(doc);
  ok(r.check.ok === false && r.items.length === 9, 'interbank: un total mal impreso → no cuadra'); }
{ const doc = await P.read(bytes('interbank-dolares.pdf'), lib); const r = B.detect(doc).read(doc);
  ok(r.cur === 'USD' && r.items.every((i) => i.cur === 'USD') && r.period.from === '2026-11-01' && r.check.ok === true, 'interbank: cuenta en dólares y periodo "DEL 1 AL 30 DE NOVIEMBRE"'); }

// 6) catálogo: el BCP y Interbank están activos
{ const pe = B.CATALOG.find((c) => c.id === 'PE'); const act = pe.banks.filter((b) => b.active).map((b) => b.id);
  ok(pe.banks.length === 4 && act.join() === 'bcp,interbank', 'catálogo: Perú con 4 bancos, activos el BCP e Interbank'); }

console.log(f ? '\n' + f + ' FALLAS' : '\nTodo bien');
process.exit(f ? 1 : 0);
