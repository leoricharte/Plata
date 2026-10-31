// Pruebas de la sesión de reconocimiento (dev/app/src/core/nazca/ejemplo.js). Son las mismas de swift/PlataCore/Tests/PlataCoreTests/NazcaExampleTests.swift.
// Uso: node dev/tests/ejemplo.mjs  · Cada prueba imprime OK/FALLA.
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const E = require('../app/src/core/nazca/ejemplo.js');
const today = '2026-10-30';
let f = 0;
const ok = (c, m) => { console.log((c ? 'OK    ' : 'FALLA ') + m); if (!c) f++; };
const eq = (a, b, m) => ok(JSON.stringify(a) === JSON.stringify(b), m + (JSON.stringify(a) === JSON.stringify(b) ? '' : '  → ' + JSON.stringify(a) + ' ≠ ' + JSON.stringify(b)));
const B = (text, x, y, w, h, tone = 0) => ({ text, x, y, w, h, tone });
const ex = (desc, amount, date, cur = '') => ({ desc, amount, date, cur });

// dinero
eq(E.parseMoney('S/ 25.50').value, 25.5, 'S/ 25.50');
eq(E.parseMoney('- S/ 1,234.50').marker, -1, 'signo menos');
eq(E.parseMoney('+$12.00').marker, 1, 'signo más');
eq(E.parseMoney('1.234,50').value, 1234.5, 'formato europeo');
eq(E.parseMoney('1.234').value, 1234, 'miles con punto');
eq(E.parseMoney('25,5').value, 25.5, 'coma decimal');
eq(E.parseMoney('Pago de luz'), null, 'texto no es monto');
eq(E.parseMoney('12 oct'), null, 'fecha no es monto');
eq([E.parseMoney('($229.80)').value, E.parseMoney('($229.80)').marker], [229.8, -1], 'paréntesis = gasto');
eq([E.parseMoney('35.00-').value, E.parseMoney('35.00-').marker], [35, -1], 'menos al final = gasto');
eq(E.parseMoney('(3)'), null, '(3) no es dinero');
eq(E.parseMoney('-'), null, 'un guion solo no es dinero');
eq(E.parseMoney('229.80 USD').cur, 'USD', 'USD al final');

// fechas
const d = (t) => E.parseDate(t, today);
eq(d('12/10/2026'), '2026-10-12', 'd/m/a'); eq(d('12 oct'), '2026-10-12', '12 oct'); eq(d('12 de octubre de 2025'), '2025-10-12', 'completa con año');
eq(d('Oct 12'), '2026-10-12', 'Oct 12'); eq(d('Hoy'), today, 'Hoy'); eq(d('Ayer'), '2026-10-29', 'Ayer'); eq(d('20 dic'), '2025-12-20', 'dic sin año va al año pasado'); eq(d('Netflix'), null, 'Netflix no es fecha');
eq(d('Friday, October 23rd'), '2026-10-23', 'Friday, October 23rd'); eq(d('Wednesday, October 21st'), '2026-10-21', '21st'); eq(d('Thursday, October 22nd'), '2026-10-22', '22nd');
eq(d('Saturday, October 24th'), '2026-10-24', '24th'); eq(d('3rd March 2026'), '2026-03-03', '3rd March 2026'); eq(d('4:42 PM • Deposit'), null, 'hora no es fecha'); eq(d('Gusto, Payroll'), null, 'Gusto no es fecha');
eq(d('10/23'), '2026-10-23', '10/23'); eq(d('23/10'), '2026-10-23', '23/10'); eq(d('10/23/2026'), '2026-10-23', '10/23/2026'); eq(d('Vie 23/10'), '2026-10-23', 'Vie 23/10');
eq(d('5/11'), '2026-05-11', '5/11 ambiguo → el de este año'); eq(d('23 de octubre'), '2026-10-23', '23 de octubre'); eq(d('5 items 23 oct'), '2026-10-23', '5 items 23 oct');
eq(d('Friday'), '2026-10-30', 'Friday'); eq(d('Sábado'), '2026-10-24', 'Sábado'); eq(d('Mon.'), '2026-10-26', 'Mon.'); eq(d('Sunday Bakery'), null, 'Sunday Bakery no es fecha'); eq(d('12.50'), null, '12.50 no es fecha');

// encabezado de fecha y monto a la derecha con signo en el texto
const rowH = (y, t, a) => [B(t, 0.08, y, 0.4, 0.02), B(a, 0.7, y, 0.22, 0.02)];
const headerLayout = () => [B('12 oct', 0.05, 0.10, 0.15, 0.02), ...rowH(0.15, 'Netflix', '- S/ 44.90'), ...rowH(0.20, 'Sueldo', '+ S/ 3,000.00'),
  B('11 oct', 0.05, 0.27, 0.15, 0.02), ...rowH(0.32, 'Bodega Lupe', '- S/ 18.00'), ...rowH(0.37, 'Uber', '- S/ 9.50')];
{
  const r = E.learn([ex('Netflix', -44.9, '2026-10-12'), ex('Bodega Lupe', -18, '2026-10-11')], headerLayout(), today);
  ok(r.ok && r.template.dateMode === 'header', 'encabezado: aprende el modo header');
  const x = E.extract(r.template, headerLayout(), today);
  eq(x.items.map((i) => i.amount), [-44.9, 3000, -18, -9.5], 'encabezado: montos'); eq(x.items.map((i) => i.date), ['2026-10-12', '2026-10-12', '2026-10-11', '2026-10-11'], 'encabezado: fechas');
  eq(x.items[1].desc, 'Sueldo', 'encabezado: nombre'); eq(x.flags, [], 'encabezado: sin banderas');
  const st = E.statement(x, { institution: 'bcp', name: 'BCP' });
  ok(st.bank === null && st.name === 'BCP' && st.kind === 'corriente', 'la institución nombra la cuenta sin sello de banco');
  ok(E.statement(x, { institution: 'applecard', name: 'Apple Card' }).kind === 'tarjeta', 'Apple Card es tarjeta');
  const json = JSON.stringify(r.template); ok(!['Netflix', 'Bodega', '44.9', '2026'].some((s) => json.includes(s)), 'la plantilla no guarda datos de la persona');
}
// descripción arriba, fecha debajo, signo por color
{
  const row = (y, t, date, a, tone) => [B(t, 0.08, y, 0.4, 0.02), B(date, 0.08, y + 0.03, 0.2, 0.015), B(a, 0.72, y, 0.2, 0.02, tone)];
  const boxes = [...row(0.1, 'Starbucks', '3 oct', 'S/ 15.00', -1), ...row(0.2, 'Pago recibido', '2 oct', 'S/ 200.00', 1), ...row(0.3, 'Farmacia', '1 oct', 'S/ 32.00', -1)];
  const r = E.learn([ex('Starbucks', -15, '2026-10-03'), ex('Pago recibido', 200, '2026-10-02')], boxes, today);
  eq(r.template.signMode, { tone: { expense: -1, income: 1 } }, 'color: signo por tono'); eq(r.template.dateMode, { row: 1 }, 'color: fecha en la fila de abajo');
  const x = E.extract(r.template, boxes, today);
  eq([x.items.length, x.items[2].amount, x.items[2].date], [3, -32, '2026-10-01'], 'color: tres movimientos');
}
// uno de los dos no aparece: parcial; ninguno: falla
{
  const r = E.learn([ex('Netflix', -44.9, '2026-10-12'), ex('Nada que ver', -999, '2026-10-11')], headerLayout(), today);
  ok(r.ok && r.template.partial === true, 'falta uno: aprende parcial');
  const r0 = E.learn([ex('Nada', -999, '2026-10-12'), ex('Tampoco', -998, '2026-10-11')], headerLayout(), today);
  ok(!r0.ok && r0.error === 'notFound' && r0.index === 0, 'faltan los dos: notFound(0)');
}
// por monto y fecha, sin nombre parecido
{
  const r = E.learn([ex('Suscripción de video', -44.9, '2026-10-12'), ex('Bodega Lupe', -18, '2026-10-11')], headerLayout(), today);
  ok(r.ok && r.template.soft === 1 && r.template.dateMode === 'header', 'soft: un ejemplo por monto y fecha');
  eq(E.extract(r.template, headerLayout(), today).items.length, 4, 'soft: lee los cuatro');
}
// el caso de Chime: fechas en inglés como encabezado y nombres distintos a los anotados
{
  const row = (y, t, a, sub) => [B(t, 0.2, y, 0.4, 0.02), B(a, 0.72, y, 0.2, 0.02), B(sub, 0.2, y + 0.03, 0.3, 0.015)];
  const head = (y, t) => [B(t, 0.05, y, 0.3, 0.015)];
  const boxes = [...head(0.10, 'Saturday, October 24th'), ...head(0.16, 'Friday, October 23rd'), ...row(0.22, 'Gusto, Payroll', '+$229.80', '4:42 PM • Deposit'),
    ...head(0.30, 'Thursday, October 22nd'), ...row(0.36, 'Wsmg22 Allcmicar, Payroll', '+$420.32', '1:09 AM • Deposit'), ...head(0.44, 'Wednesday, October 21st'),
    ...row(0.50, 'MyPay repayment', '-$35.00', '12:47 AM • MyPay'), ...row(0.58, 'Gusto, Payroll', '+$602.14', '12:47 AM • Deposit')];
  const r = E.learn([ex('Bonus Generations', 229.8, '2026-10-23'), ex('Generations', 602.14, '2026-10-21')], boxes, today);
  ok(r.ok && r.template.soft === 2 && r.template.dateMode === 'header', 'Chime: los dos ejemplos por monto y fecha');
  const x = E.extract(r.template, boxes, today);
  eq(x.items.map((i) => i.amount), [229.8, 420.32, -35, 602.14], 'Chime: montos'); eq(x.items.map((i) => i.date), ['2026-10-23', '2026-10-22', '2026-10-21', '2026-10-21'], 'Chime: fechas');
  eq(x.items[0].desc, 'Gusto, Payroll', 'Chime: nombre');
}
// una fila sin fecha propia toma el encabezado
{
  const t = { amountX: 0.92, rightAligned: true, tol: 0.06, descDy: 0, descLeft: 0.05, dateMode: { row: -2 }, signMode: { marker: 1 }, cur: '', confidence: 1 };
  const x = E.extract(t, [B('Friday, October 23rd', 0.05, 0.10, 0.3, 0.015), B('Gusto', 0.05, 0.16, 0.2, 0.02), B('+$229.80', 0.72, 0.16, 0.2, 0.02)], today);
  eq(x.items[0].date, '2026-10-23', 'la fila toma la fecha del encabezado');
}
// selección: una fila (parcial), toda la lista (dos con signo distinto), cuadro vacío
{
  const row = (y, t, a) => [B(t, 0.05, y, 0.4, 0.02), B(a, 0.72, y, 0.2, 0.02)];
  const boxes = [B('Friday, October 23rd', 0.05, 0.10, 0.3, 0.015), ...row(0.20, 'Gusto, Payroll', '+$229.80'), ...row(0.30, 'Starbucks', '-$5.40'), ...row(0.40, 'Uber', '-$12.00')];
  const one = { x: 0, y: 0.19, w: 1, h: 0.05 };
  eq(E.rows(one, boxes).length, 1, 'cuadro: una fila');
  const e1 = E.examples(one, boxes, today);
  eq([e1.length, e1[0].amount, e1[0].desc, e1[0].date], [1, 229.8, 'Gusto, Payroll', '2026-10-23'], 'cuadro: ejemplo de una fila');
  const r1 = E.learn(e1, boxes, today);
  ok(r1.ok && r1.template.partial === true, 'cuadro: una fila es parcial'); eq(E.extract(r1.template, boxes, today).items.length, 3, 'cuadro: una fila lee las tres');
  const all = E.listRegion(boxes);
  eq(E.rows(all, boxes).length, 3, 'cuadro: toda la lista tiene tres filas');
  const e2 = E.examples(all, boxes, today);
  ok(e2.length === 2 && (e2[0].amount < 0) !== (e2[1].amount < 0), 'cuadro: dos ejemplos con signo distinto');
  const r2 = E.learn(e2, boxes, today); ok(r2.ok && !r2.template.partial, 'cuadro: varias filas no son parciales');
  const x2 = E.extract(r2.template, boxes, today);
  eq(x2.items.map((i) => i.amount), [229.8, -5.4, -12], 'cuadro: montos'); eq([...new Set(x2.items.map((i) => i.date))], ['2026-10-23'], 'cuadro: fecha del encabezado');
  eq(E.examples({ x: 0, y: 0, w: 1, h: 0.05 }, boxes, today), [], 'cuadro sin montos: sin ejemplos');
}
console.log(f ? '\n' + f + ' FALLAS' : '\nTodo bien');
process.exit(f ? 1 : 0);
