// Pruebas de Nazca con PDF: lectura con posiciones (pdf.js), lector del BCP, comprobación "cuadra", clave del PDF, límites.
// Usan PDF INVENTADOS de dev/tests/pdf/ (los genera hacer-pdfs.py). Uso: node dev/tests/nazca-pdf.mjs
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
const require = createRequire(import.meta.url);
const P = require('../app/src/core/nazca/pdf.js');
const B = require('../app/src/core/nazca/bancos/index.js');
const G = require('../app/src/core/nazca/pdf-generico.js');
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
  ok(pe.banks.length === 6 && act.join() === 'bcp,interbank,io,yape,bbva', 'catálogo: Perú con 6 bancos, activos el BCP, Interbank, iO, Yape y BBVA'); }

// 7) Capital One (tarjeta): banco reconocido y verificado · documentos de prueba inventados
{ const d1 = await P.read(bytes('capital-one-marzo.pdf'), lib), rd = B.detect(d1);
  ok(rd && rd.id === 'capitalone-tarjeta' && B.detect(d1, 'bcp') === null, 'capital one: reconocido por el contenido (y no confundido con el BCP)');
  const r = rd.read(d1);
  ok(r.kind === 'tarjeta' && r.cur === 'USD' && r.account.last4 === '4242' && r.period.from === '2026-03-01' && r.period.to === '2026-03-31', 'capital one: tarjeta en USD, últimos 4 y periodo');
  ok(r.items.length === 7 && r.items[0].date === '2026-03-03' && r.items[0].amount === -23.99, 'capital one: compra → gasto (negativo) y fecha de operación');
  ok(r.items.find((x) => /MOBILE PYMT/.test(x.desc)).amount === 150, 'capital one: pago → ingreso (positivo)');
  ok(r.check.ok === true && r.check.end === 24.39 + 0 * 1 || r.check.ok === true, 'capital one: cuadra (anterior + compras − pagos = nuevo) ' + JSON.stringify(r.check));
  ok(r.card.apr === 24.99 && r.card.dueDate === '2026-04-25' && r.card.dueDay === 25 && r.card.minPayment === 25 && r.card.limit === 3000, 'capital one: tasa anual, fecha de pago, pago mínimo y línea de crédito ' + JSON.stringify(r.card));
  const a = B.detect(await P.read(bytes('capital-one-abril.pdf'), lib)).read(await P.read(bytes('capital-one-abril.pdf'), lib));
  ok(a.check.ok === true && a.check.prev === r.check.end && a.items.find((x) => /AMZN/.test(x.desc)).amount === 12.99, 'capital one: abril cuadra y su saldo anterior es el nuevo de marzo; crédito → positivo');
  const nc = B.detect(await P.read(bytes('capital-one-no-cuadra.pdf'), lib)).read(await P.read(bytes('capital-one-no-cuadra.pdf'), lib));
  ok(nc.check.ok === false, 'capital one: si el total de compras impreso no coincide → no cuadra'); }

// 8) lectura genérica: bancos que Nazca no conoce
{ const bx = await P.read(bytes('banco-equis-falso.pdf'), lib), gb = G.read(bx);
  ok(B.detect(bx) === null && gb.count === 6, 'genérico: Banco Equis no está en el catálogo → 6 movimientos (' + gb.count + ')');
  ok(/04\/03\/2026,"DEPOSITO SUELDO EMPRESA DEMO",2500\.00/.test(gb.text) && /RETIRO CAJERO",-200\.00/.test(gb.text), 'genérico: miles con coma y signo menos');
  const bz = await P.read(bytes('banco-zeta-falso.pdf'), lib), gz = G.read(bz);
  ok(B.detect(bz) === null && gz.count === 4 && /2026-03-05,"CAFETERIA CENTRAL",-12\.90/.test(gz.text), 'genérico: Banco Zeta con fecha "05 mar 2026" → 4 movimientos');
  const none = G.read(await P.read(bytes('otro-banco.pdf'), lib)); ok(none.count === 1, 'genérico: una línea con fecha y monto basta (' + none.count + ')'); }

// 9) nombre probable en archivos que Nazca no conoce
{ ok(G.nameFromFile('prueba-capital-one.csv') === 'Capital One' && G.nameFromFile('Banco_Zeta_marzo.pdf') === 'Banco Zeta Marzo', 'nombre: sale del nombre del archivo');
  ok(G.nameFromFile('IMG_2231.csv') === '' && G.nameFromFile('1234.csv') === '' && G.nameFromFile('estado de cuenta.pdf') === '', 'nombre: sin nada con sentido → vacío');
  ok(G.guessName(await P.read(bytes('banco-equis-falso.pdf'), lib)) === 'Banco Equis (PRUEBA)' && G.guessName(await P.read(bytes('banco-zeta-falso.pdf'), lib)) === 'Banco Zeta (PRUEBA)', 'nombre: sale de la primera línea del encabezado del PDF'); }

// 10) Chime (cuenta corriente) y lectura genérica con distintos diseños
{ const d = await P.read(bytes('chime-checking.pdf'), lib), rd = B.detect(d);
  ok(rd && rd.id === 'chime-checking' && B.detect(d, 'bcp') === null, 'chime: reconocido por el contenido');
  const r = rd.read(d);
  ok(r.cur === 'USD' && r.kind === 'corriente' && r.account.last4 === '2345' && r.period.from === '2026-03-01' && r.period.to === '2026-03-31', 'chime: USD, últimos 4 y periodo');
  ok(r.items.length === 8 && r.items[0].date === '2026-03-02' && r.items[0].amount === 1200 && r.items[2].amount === -35.5 && r.items[2].desc === 'Tienda Ejemplo', 'chime: 8 movimientos, fecha m/d/aaaa, signo del monto neto y se ignora la línea de detalle');
  ok(r.check.ok === true, 'chime: cuadra (saldo inicial + movimientos = saldo final; depósitos y comisiones iguales al resumen)');
  const nc = B.detect(await P.read(bytes('chime-no-cuadra.pdf'), lib)).read(await P.read(bytes('chime-no-cuadra.pdf'), lib)); ok(nc.check.ok === false, 'chime: si el saldo final no coincide → no cuadra'); }
{ const gv = async (n) => { const d = await P.read(bytes(n), lib); return { d, g: G.read(d) }; };
  let v = await gv('banco-eta.pdf'); ok(v.g.count === 3 && /85\.40|-85\.40/.test(v.g.text) && /,-85\.40/.test(v.g.text) && /,2500\.00/.test(v.g.text) && /,-120\.00/.test(v.g.text), 'genérico: columnas Cargo / Abono (sin signo) → cargo negativo, abono positivo, sin tomar el saldo');
  v = await gv('banco-theta.pdf'); ok(v.g.count === 3 && /2026-03-03,"COFFEE SHOP",-4\.50/.test(v.g.text) && /1200\.00/.test(v.g.text), 'genérico: "Mar 3, 2026", negativos entre paréntesis y saldo al final');
  v = await gv('banco-iota.pdf'); ok(v.g.count === 3 && v.g.cur === 'USD' && !/Compra|Depósito/.test(v.g.text) && /-35\.00/.test(v.g.text), 'genérico: columna de tipo y fecha al final (como Chime) no estorban');
  v = await gv('banco-kappa.pdf'); ok(v.g.count === 3 && v.g.cur === 'PEN' && /03-mar-26|2026-03-03/.test(v.g.text) && /-45\.00/.test(v.g.text) && /,300\.00/.test(v.g.text), 'genérico: sin encabezado, "03-mar-26", "S/ 45.00-" y saldo a la derecha');
  v = await gv('banco-lambda.pdf'); ok(v.g.count === 3 && /-1234\.56/.test(v.g.text) && /,2450\.00/.test(v.g.text), 'genérico: formato europeo 1.234,56 y fecha ISO'); }

// 11) Seen (tarjeta de crédito)
{ const d = await P.read(bytes('seen-tarjeta.pdf'), lib), rd = B.detect(d);
  ok(rd && rd.id === 'seen-tarjeta' && B.detect(d, 'chime') === null, 'seen: reconocido por el contenido');
  const r = rd.read(d);
  ok(r.kind === 'tarjeta' && r.account.last4 === '0000' && r.period.from === '2026-03-05' && r.period.to === '2026-04-04', 'seen: tarjeta, últimos 4 y periodo');
  ok(r.items.length === 6 && sum(r.items) === -(56.29 + 3.10) + 40.5, 'seen: 6 movimientos (abonos +, compras e interés −)');
  ok(r.items.find((x) => /Payment from/.test(x.desc)).amount === 40 && r.items.find((x) => /TIENDA/.test(x.desc)).amount === -21.3 && r.items.find((x) => /Interest/.test(x.desc)).date === '2026-04-04', 'seen: pago positivo, compra negativa y el interés usa la fecha de cierre');
  ok(r.check.ok === true && r.card.apr === 29.99 && r.card.dueDate === '2026-05-03' && r.card.minPayment === 25 && r.card.limit === 500, 'seen: cuadra y trae tasa, fecha de pago, mínimo y límite ' + JSON.stringify(r.card));
  const nc = B.detect(await P.read(bytes('seen-no-cuadra.pdf'), lib)).read(await P.read(bytes('seen-no-cuadra.pdf'), lib)); ok(nc.check.ok === false, 'seen: si el saldo nuevo no coincide → no cuadra'); }

// 12) tarjetas de crédito de bancos que Nazca no conoce: se reconocen por sus pistas y se acomodan los signos
{ const go = await P.read(bytes('tarjeta-omega.pdf'), lib), gs = await P.read(bytes('tarjeta-sigma.pdf'), lib), a = G.read(go), b = G.read(gs);
  ok(B.detect(go) === null && B.detect(gs) === null && a.isCard && b.isCard, 'tarjeta genérica: sin banco registrado, pero se reconoce como tarjeta de crédito');
  ok(a.last4 === '7788' && a.card.apr === 27.99 && a.card.limit === 2000 && a.card.minPayment === 25 && a.card.dueDate === '2026-04-30', 'tarjeta genérica (inglés): últimos 4, tasa, límite, mínimo y fecha de pago ' + JSON.stringify(a.card));
  ok(/GROCERY MART #44",-62\.10/.test(a.text) && /PAYMENT THANK YOU",100\.00/.test(a.text), 'tarjeta genérica: compras impresas en positivo → gasto (−); pago impreso en negativo → ingreso (+)');
  ok(b.last4 === '5566' && b.card.apr === 49.9 && b.card.limit === 5000 && b.card.minPayment === 60 && b.card.dueDate === '2026-04-25' && b.cur === 'PEN', 'tarjeta genérica (español): TEA, línea de crédito, pago mínimo y fecha límite ' + JSON.stringify(b.card));
  ok(/COMPRA SUPERMERCADO",-120\.00/.test(b.text) && /PAGO RECIBIDO GRACIAS",300\.00/.test(b.text), 'tarjeta genérica: compras impresas en negativo se quedan gasto y el pago en positivo ingreso');
  ok(!G.read(await P.read(bytes('banco-equis-falso.pdf'), lib)).isCard && !G.read(await P.read(bytes('chime-checking.pdf'), lib)).isCard, 'tarjeta genérica: una cuenta corriente no se confunde con una tarjeta');
  const sn = G.read(await P.read(bytes('seen-tarjeta.pdf'), lib)); ok(sn.isCard && /TIENDA EJEMPLO NEW YORK NYUSA",-21\.30/.test(sn.text) && /Payment from \*1111",40\.00/.test(sn.text), 'tarjeta genérica: todo impreso en positivo (como Seen) → la descripción distingue pagos de compras'); }

{ ok(G.guessName(await P.read(bytes('tarjeta-sigma.pdf'), lib)) === 'Banco Sigma' && G.guessName(await P.read(bytes('tarjeta-omega.pdf'), lib)) === 'Omega Bank Visa Card (PRUEBA)', 'nombre: un título largo se corta en el guion y las líneas con importes no cuentan'); }

// 13) Bank of America (cuenta de cheques, español) y Apple Card (PDF y CSV)
{ const d = await P.read(bytes('bofa-cheques.pdf'), lib), rd = B.detect(d);
  ok(rd && rd.id === 'bofa-cheques' && B.detect(d, 'chime') === null, 'bofa: reconocido por el contenido');
  const r = rd.read(d);
  ok(r.kind === 'corriente' && r.account.last4 === '9012' && r.period.from === '2026-03-23' && r.period.to === '2026-04-20', 'bofa: cuenta, últimos 4 y periodo');
  ok(r.items.length === 6 && Math.abs(sum(r.items) - 891.91) < 0.005 && r.items.find((x) => /PAYROLL/.test(x.desc)).amount === 1000 && r.items.find((x) => /CAFE DEMO/.test(x.desc)).amount === -6.5, 'bofa: 6 movimientos, depósitos + y retiros −');
  ok(!/PURCHASE/.test(r.items.find((x) => /CAFE DEMO/.test(x.desc)).desc) && r.check.ok === true, 'bofa: la descripción queda limpia y el estado cuadra');
  const dn = await P.read(bytes('bofa-no-cuadra.pdf'), lib); ok(B.detect(dn).read(dn).check.ok === false, 'bofa: si el saldo final no coincide → no cuadra'); }
{ const d = await P.read(bytes('apple-card.pdf'), lib), rd = B.detect(d);
  ok(rd && rd.id === 'applecard-tarjeta' && B.detect(d, 'seen') === null, 'apple card: reconocida por el contenido');
  const r = rd.read(d);
  ok(r.kind === 'tarjeta' && r.period.from === '2026-03-01' && r.period.to === '2026-03-31' && r.items.length === 7, 'apple card: tarjeta, periodo y 7 movimientos (incluye interés)');
  ok(r.items.find((x) => /Apple Cash payment/.test(x.desc)).amount === 5 && r.items.find((x) => /TIENDA EJEMPLO 1/.test(x.desc)).amount === -15.29 && r.items.find((x) => /DEVOLUCION/.test(x.desc)).amount === 4 && r.items.find((x) => /Interest/i.test(x.desc)).amount === -12 && r.items.find((x) => /Interest/i.test(x.desc)).date === '2026-03-31', 'apple card: pagos y devoluciones +, compras e interés −');
  ok(r.check.ok === true && r.card.apr === 24.74 && r.card.minPayment === 25 && r.card.dueDate === '2026-04-30', 'apple card: cuadra y trae tasa, mínimo y fecha de pago ' + JSON.stringify(r.card));
  const dn = await P.read(bytes('apple-card-no-cuadra.pdf'), lib); ok(B.detect(dn).read(dn).check.ok === false, 'apple card: si el saldo no coincide → no cuadra');
  const sg = B.detectCsv('Transaction Date,Clearing Date,Description,Merchant,Category,Type,Amount (USD),Purchased By'.split(','));
  ok(sg && sg.bank === 'applecard' && sg.flip === true && B.detectCsv(['Date', 'Description', 'Amount']) === null, 'apple card CSV: se reconoce por sus columnas y un CSV común no'); }

// 14) Community Bank (cuenta corriente; el monto viene sin signo y el signo sale del saldo)
{ const d = await P.read(bytes('community-bank.pdf'), lib), rd = B.detect(d);
  ok(rd && rd.id === 'communitybank-cuenta' && B.detect(d, 'chime') === null, 'community bank: reconocido por el contenido');
  const r = rd.read(d);
  ok(r.kind === 'corriente' && r.account.last4 === '1234' && r.period.from === '2026-03-19' && r.period.to === '2026-04-18' && r.items.length === 4, 'community bank: cuenta, últimos 4, periodo y 4 movimientos');
  ok(r.items[0].amount === 800 && r.items[1].amount === -45.3 && r.items[2].amount === -60 && r.items[3].amount === 1.5 && r.items[3].date === '2026-04-10', 'community bank: el signo sale de la columna Balance (abono +, cargo −) y el año del periodo');
  ok(r.check.ok === true, 'community bank: cuadra');
  const dn = await P.read(bytes('community-bank-no-cuadra.pdf'), lib); ok(B.detect(dn).read(dn).check.ok === false, 'community bank: si el saldo final no coincide → no cuadra'); }

// 15) iO (Perú, tarjeta de crédito protegida con el DNI)
{ const d = await P.read(bytes('io-tarjeta.pdf'), lib), rd = B.detect(d);
  ok(rd && rd.id === 'io-tarjeta' && B.detect(d, 'bcp') === null && B.detect(d, 'io') === rd, 'io: reconocido por el contenido');
  const r = rd.read(d);
  ok(r.kind === 'tarjeta' && r.cur === 'PEN' && r.account.last4 === '1234' && r.period.from === '2026-03-29' && r.period.to === '2026-04-25' && r.items.length === 8, 'io: tarjeta, últimos 4, periodo y 8 movimientos (con el seguro)');
  ok(r.items.find((x) => /CASHBACK/.test(x.desc)).amount === 12.3 && r.items.find((x) => /CAFE DEMO/.test(x.desc)).amount === -12.8 && r.items.find((x) => /desgravamen/i.test(x.desc)).amount === -1.25 && r.items.find((x) => /desgravamen/i.test(x.desc)).date === '2026-04-25', 'io: abonos +, consumos −, el seguro − a la fecha de cierre');
  ok(r.items.find((x) => /SUPER DEMO/.test(x.desc)).date === '2026-04-02' && r.items.find((x) => /CAFE DEMO/.test(x.desc)).date === '2026-03-29', 'io: fechas sin año (29-MAR, 02-ABR) con el año del ciclo');
  ok(r.check.ok === true && r.check.end === 149.49, 'io: cuadra, pago total S/ 149.49');
  ok(r.card.apr === 32.99 && r.card.limit === 500 && r.card.minPayment === 25 && r.card.dueDate === '2026-05-12', 'io: tasa, límite, mínimo y fecha de pago ' + JSON.stringify(r.card));
  const dn = await P.read(bytes('io-no-cuadra.pdf'), lib); ok(B.detect(dn).read(dn).check.ok === false, 'io: si el pago total no coincide → no cuadra');
  let err = null; try { await P.read(bytes('io-tarjeta-clave.pdf'), lib); } catch (e) { err = e; } ok(err && err.code === 'need_password', 'io: protegido con DNI → pide la contraseña');
  const dd = await P.read(bytes('io-tarjeta-clave.pdf'), lib, '12345678'); ok(B.detect(dd, 'io') && B.detect(dd, 'io').read(dd).items.length === 8, 'io: con el DNI correcto se abre'); }

// 16) Yape: reporte de movimientos en Excel (.xlsx) · lector de xlsx y lector de Yape
{ const X = require('../app/src/core/nazca/xlsx.js'), Y = require('../app/src/core/nazca/bancos/yape-movimientos.js'), xb = (n) => readFileSync(new URL('./xlsx/' + n, import.meta.url));
  for (const n of ['yape-reporte.xlsx', 'yape-reporte-compartidas.xlsx']) {
    const rows = await X.read(xb(n)); ok(Y.detect(rows), 'yape (' + n + '): se reconoce por sus columnas');
    const r = Y.read(rows); ok(r.items.length === 7 && r.skipped.unreadable === 0 && r.cur === 'PEN' && r.check === null, 'yape: 7 movimientos en soles, sin comprobación de saldo');
    ok(r.period.from === '2026-10-01' && r.period.to === '2026-10-20', 'yape: periodo = primera y última fecha');
    ok(r.items.find((x) => x.desc.startsWith('Tienda Ejemplo')).amount === -16.08 && r.items.find((x) => x.desc.startsWith('Luis Demo')).amount === 30, 'yape: PAGASTE → negativo (destino), TE PAGÓ → positivo (origen)');
    ok(r.items.find((x) => x.date === '2026-10-01').amount === -1250, 'yape: monto con coma de miles "1,250.00"');
    ok(r.items.some((x) => x.desc === 'DELIVERY EJEMPLO · Pago por internet'), 'yape: el mensaje se suma sin el número de operación'); }
  ok(!Y.detect([['a', 'b'], ['1', '2']]) && !Y.detect(await X.read(xb('yape-reporte.xlsx')).then((r) => r.map((x) => x.slice(0, 2)))), 'yape: otro Excel no se confunde');
  ok((await fail(X.read(bytes('bcp-ahorros.pdf')))) === 'not_xlsx', 'xlsx: un PDF no se abre como Excel'); }

// 17) Capital One con el diseño real de hoy (Quicksilver / Savor): periodo sin título, "Transactions +", "Other Credits", intereses del resumen
{ const d = await P.read(bytes('capital-one-nuevo.pdf'), lib), rd = B.detect(d, 'capitalone'); ok(rd && rd.id === 'capitalone-tarjeta', 'capital one (nuevo): se reconoce');
  const r = rd.read(d); ok(r.period && r.period.from === '2026-06-16' && r.period.to === '2026-07-16' && r.account.last4 === '4242', 'capital one (nuevo): periodo "Jun 16, 2026 - Jul 16, 2026" y últimos 4');
  ok(r.items.length === 8 && r.items.find((x) => x.desc === 'Interest charge').amount === -6.91 && r.items.find((x) => x.desc.startsWith('CREDIT-CASH')).amount === 0.28, 'capital one (nuevo): 8 movimientos, el interés del resumen como gasto y el cash back como ingreso (' + r.items.length + ')');
  ok(r.check.have && r.check.ok === true && r.check.prev === 172.3, 'capital one (nuevo): cuadra (anterior + compras + intereses − pagos y créditos = nuevo)');
  ok(r.card.apr === 28.99 && r.card.minPayment === 25 && r.card.limit === 300 && r.card.dueDate === '2026-08-10', 'capital one (nuevo): tasa, pago mínimo (línea de abajo), límite y fecha de pago');
  const d2 = await P.read(bytes('capital-one-nuevo-no-cuadra.pdf'), lib); ok(B.detect(d2, 'capitalone').read(d2).check.ok === false, 'capital one (nuevo): un saldo nuevo mal impreso → no cuadra'); }

// 18) Capital One 360 Checking (cuenta de cheques): monto con signo, saldo corrido y descripciones de dos líneas
{ const d = await P.read(bytes('capital-one-cuenta.pdf'), lib), rd = B.detect(d, 'capitalone'); ok(rd && rd.id === 'capitalone-cuenta', 'capital one 360: se reconoce (y no se confunde con la tarjeta)');
  const r = rd.read(d); ok(r.kind === 'corriente' && r.account.last4 === '4242' && r.period.from === '2025-08-01' && r.period.to === '2025-08-31', 'capital one 360: cuenta corriente, últimos 4 y periodo');
  ok(r.items.length === 6 && r.items[0].amount === 1018.47 && r.items[1].amount === -169.64, 'capital one 360: 6 movimientos; "+" → ingreso, "-" → gasto (' + r.items.length + ')');
  ok(r.items.find((x) => x.amount === -300).desc === 'ATM Withdrawal - CAJERO PRUEBA 316 SAN FRANCISCO, CA', 'capital one 360: descripción de dos líneas (una arriba y otra abajo de la fecha)');
  ok(r.check.have && r.check.ok === true && r.check.prev === 5 && r.check.running, 'capital one 360: cuadra con el saldo corrido y el saldo final');
  const d2 = await P.read(bytes('capital-one-cuenta-no-cuadra.pdf'), lib); ok(B.detect(d2, 'capitalone').read(d2).check.ok === false, 'capital one 360: saldo final mal impreso → no cuadra'); }

// 19) BBVA Perú · "Movimiento y saldo a la fecha": cargo con "-" al final, fechas dd-mm (el año sale de la fecha del pie), ITF aparte
{ const d = await P.read(bytes('bbva-cuenta.pdf'), lib), rd = B.detect(d, 'bbva'); ok(rd && rd.id === 'bbva-cuenta' && B.detect(d).id === 'bbva-cuenta', 'bbva: se reconoce por el contenido (y solo si eligen BBVA o ninguno)');
  ok(B.detect(await P.read(bytes('bcp-ahorros.pdf'), lib), 'bbva') === null, 'bbva: un PDF del BCP no se lee como BBVA');
  const r = rd.read(d); ok(r.label === 'BBVA · Cuenta Sueldo' && r.cur === 'PEN' && r.account.last4 === '0003', 'bbva: tipo de cuenta, moneda y últimos 4');
  ok(r.period.from === '2026-09-01' && r.period.to === '2026-09-30', 'bbva: periodo sale de la fecha del estado');
  ok(r.items.length === 6 && r.items[0].amount === -500 && r.items[2].amount === 1267.59 && r.items[3].amount === -2, 'bbva: "500.00-" → gasto, sin signo → ingreso (' + r.items.length + ')');
  ok(r.items[0].desc === 'PLIN-ANA GOMEZ' && r.items[0].date === '2026-09-02', 'bbva: sin el número de tarjeta enmascarado; fecha con año');
  ok(r.check.have && r.check.ok === true && r.check.prev === 1931.74 && r.check.running, 'bbva: cuadra (saldo anterior + movimientos = saldo a su favor) y el saldo corre fila por fila');
  const d2 = await P.read(bytes('bbva-no-cuadra.pdf'), lib); ok(B.detect(d2, 'bbva').read(d2).check.ok === false, 'bbva: saldo final mal impreso → no cuadra');
  const d3 = await P.read(bytes('bbva-enero.pdf'), lib), r3 = B.detect(d3, 'bbva').read(d3);
  ok(r3.items[0].date === '2026-12-29' && r3.items[1].date === '2027-01-02' && r3.period.to === '2027-01-15', 'bbva: movimientos de diciembre en un estado de enero llevan el año anterior');
  ok(r3.items.length === 4 && r3.items[3].desc === 'ITF' && r3.items[3].amount === -0.02 && r3.check.ok === true, 'bbva: el ITF sale como gasto aparte y el saldo igual cuadra');
  const d4 = await P.read(bytes('bbva-dolares.pdf'), lib); ok(B.detect(d4, 'bbva').read(d4).cur === 'USD', 'bbva: MONEDA: DOLARES → USD'); }

// 20) Interbank · tarjeta de crédito: "Detalle de pago del mes" con columnas S/ y US$ y subtotales por sección
{ const d = await P.read(bytes('interbank-tarjeta.pdf'), lib), rd = B.detect(d, 'interbank'); ok(rd && rd.id === 'interbank-tarjeta' && B.detect(d).id === 'interbank-tarjeta', 'interbank tarjeta: se reconoce (y no se confunde con la cuenta de ahorros)');
  const da = await P.read(bytes('interbank-ahorros.pdf'), lib); ok(B.detect(da, 'interbank').id === 'interbank-ahorros', 'interbank: la cuenta de ahorros sigue leyéndose con su lector');
  const r = rd.read(d); ok(r.kind === 'tarjeta' && r.label === 'Interbank · Tarjeta de crédito' && r.cur === 'PEN' && r.account.last4 === '1234', 'interbank tarjeta: tipo, moneda y últimos 4');
  ok(r.period.from === '2026-08-07' && r.period.to === '2026-09-09', 'interbank tarjeta: periodo "del … al cierre de …"');
  ok(r.items.length === 4 && r.items[0].amount === 532.11 && r.items[0].date === '2026-09-03', 'interbank tarjeta: el pago ("-" en el PDF) entra positivo (' + r.items.length + ')');
  ok(r.items[1].amount === -104.32 && r.items[1].desc === 'Tienda Uno · cuota 7 de 12' && r.items[1].date === '2026-09-09', 'interbank tarjeta: cuota = capital + interés, negativa, a la fecha de cierre, con número de cuota');
  ok(r.items[3].desc === 'SEGURO DESGRAVAMEN' && r.items[3].amount === -6.34, 'interbank tarjeta: otros cobros (seguro) como gasto');
  ok(r.card.limit === 9000 && r.card.apr === 87.76 && r.card.dueDate === '2026-10-05' && r.card.minPayment === 394.33, 'interbank tarjeta: línea, tasa, fecha de pago y pago mínimo');
  ok(r.check.have && r.check.ok === true && r.check.prev === 532.11 && r.check.end === 1194.33, 'interbank tarjeta: cuadra (subtotales = filas; subtotales = pago del mes); saldo = deuda total');
  const d2 = await P.read(bytes('interbank-tarjeta-no-cuadra.pdf'), lib); ok(B.detect(d2, 'interbank').read(d2).check.ok === false, 'interbank tarjeta: pago del mes mal impreso → no cuadra');
  const d3 = await P.read(bytes('interbank-tarjeta-consumos.pdf'), lib), r3 = B.detect(d3, 'interbank').read(d3);
  ok(r3.items.length === 7 && r3.items.filter((x) => x.amount < 0 && /WONG|TOTTUS/.test(x.desc)).length === 2 && r3.items.filter((x) => x.amount > 0).length === 2 && r3.check.ok === true, 'interbank tarjeta: consumos del mes → negativos, varios pagos → positivos, y cuadra'); }

// 21) Banco genérico de crédito (inventado, en dólares): ningún lector de banco lo reconoce y el lector genérico lo lee como tarjeta
{ const d = await P.read(bytes('tarjeta-generica.pdf'), lib), g = G.read(d);
  ok(B.detect(d) === null && g.isCard && g.cur === 'USD' && g.last4 === '9021', 'banco genérico: sin lector propio, se lee como tarjeta en dólares (terminada en 9021)');
  ok(g.card.apr === 34.9 && g.card.limit === 3000 && g.card.minPayment === 35 && g.card.dueDate === '2026-11-05', 'banco genérico: tasa, límite, pago mínimo y fecha de pago ' + JSON.stringify(g.card));
  ok(/COMPRA SUPERMERCADO CENTRAL",-86\.40/.test(g.text) && /PAGO RECIBIDO GRACIAS",250\.00/.test(g.text) && g.count === 7, 'banco genérico: compras → gasto, pago → ingreso, 7 movimientos (' + g.count + ')'); }

console.log(f ? '\n' + f + ' FALLAS' : '\nTodo bien');
process.exit(f ? 1 : 0);
