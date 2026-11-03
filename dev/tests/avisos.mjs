// Avisos de la app de Android (dev/app/src/js/36-android.js): el plan de recordatorios, pagos de mañana y nota del mes. Es el mismo plan que Reminders.swift del iPhone.
// Función pura: no necesita teléfono ni navegador. Usa el código REAL de la app.   Uso: node dev/tests/avisos.mjs
process.env.TZ = 'UTC';
import { readFileSync } from 'node:fs';
const src = readFileSync(new URL('../app/src/js/36-android.js', import.meta.url), 'utf8');
const i0 = src.indexOf('const AV_TIERS'), i1 = src.indexOf('const AVK =');
const { avisosPlan, avId } = new Function(src.slice(i0, i1) + '\nreturn { avisosPlan, avId };')();
let f = 0; const ok = (c, m) => { console.log((c ? 'OK    ' : 'FALLA ') + m); if (!c) f++; };
const eq = (a, b, m) => ok(JSON.stringify(a) === JSON.stringify(b), m + (JSON.stringify(a) === JSON.stringify(b) ? '' : '  → ' + JSON.stringify(a) + ' ≠ ' + JSON.stringify(b)));
const D = (s) => new Date(s), iso = (d) => d.toISOString().slice(0, 16).replace('T', ' ');
const now = D('2026-11-03T10:00:00Z');
const base = { now, lang: 0, txs: [], events: [], fmt: (n) => '$' + n, insights: true, monthName: (d) => new Intl.DateTimeFormat('es', { month: 'long' }).format(d) };
const plan = (o) => avisosPlan(Object.assign({}, base, o));
const keys = (p) => p.map((x) => x.key);

ok(avisosPlan(Object.assign({}, base, { prefs: { inact: false, up: false, amt: false, ins: false } })).length === 0, 'con todo apagado no hay avisos');
ok(avId('a') > 0 && avId('a') === avId('a') && avId('a') !== avId('b'), 'los ids son enteros positivos y estables');

// Si llevas días sin anotar: desde el último movimiento (o desde que se encendió), a las 19:00, como máximo 3
let p = plan({ prefs: { inact: true, since: D('2026-10-30T12:00:00Z').getTime() } });
eq(keys(p), ['inact1', 'inact2', 'inact3'], 'sin movimientos: cuenta desde que se encendió (30 oct); el de 2 días ya pasó');
eq(p.map((x) => iso(x.at)), ['2026-11-04 19:00', '2026-11-08 19:00', '2026-11-15 19:00'], 'a las 19:00 de los días 5, 9 y 16');
p = plan({ prefs: { inact: true, since: D('2026-10-01T00:00:00Z').getTime() }, txs: [{ date: '2026-11-02' }, { date: '2026-10-20' }, { date: '2026-11-20' }] });
eq(keys(p), ['inact0', 'inact1', 'inact2'], 'cuenta desde el último movimiento que ya pasó (el de noviembre 20 no cuenta)');
eq(iso(p[0].at), '2026-11-04 19:00', 'dos días después del 2 de noviembre');
ok(p[0].title.length > 0 && p[0].body.length > 0 && !/\{mes\}/.test(p[0].title + p[0].body), 'cada aviso trae título y texto');

// Nota del mes (día 1) y half-time (día 15), a las 9:00, con el nombre del mes que se evalúa
p = plan({ prefs: { ins: true } });
eq(keys(p), ['insh-2026-11', 'insm-2026-12', 'insh-2026-12', 'insm-2027-01', 'insh-2027-01'], 'half-time de este mes y los próximos dos cierres');
eq(iso(p[1].at), '2026-12-01 09:00', 'la nota sale el día 1 a las 9:00');
eq([p[1].title, p[1].body], ['Ding: nueva evaluación', 'Revisa tus insights de noviembre antes de que se enfríen.'], 'el cierre de diciembre nombra noviembre');
eq(p[3].title, 'Salió tu evaluación de diciembre', 'y el de enero nombra diciembre');
eq(plan({ prefs: { ins: true }, insights: false }).length, 0, 'sin insights no hay nota ni half-time');

// Pagos, cobros e ingresos: el día antes a las 9:00; si ya pasó, el mismo día a las 8:00
const ev = (date, name, amt, type) => ({ date: D(date + 'T00:00:00Z'), name, amt, type });
p = plan({ prefs: { up: true, amt: true }, events: [ev('2026-11-10', 'Pago Visa', -100, 'card'), ev('2026-11-04', 'Netflix', -15.5, 'sub'), ev('2026-11-20', 'Sueldo', 1500, 'in'),
  ev('2026-11-24', 'Alquiler', -900, 'exp'), ev('2026-11-25', 'Un día de más', -5, 'exp'), ev('2026-12-10', 'Lejano', -5, 'exp'), ev('2026-11-12', 'Simulado', -50, 'sim'), ev('2026-11-03', 'Hoy mismo', -20, 'exp')] });
eq(p.length, 4, 'cuatro avisos: tarjeta, suscripción, ingreso y gasto (no el de hoy, ni el simulado, ni los de más de 21 días: el 24 sí entra y el 25 no)');
const byName = (n) => p.find((x) => (x.title + x.body).includes(n));
eq(iso(byName('Pago Visa').at), '2026-11-09 09:00', 'tarjeta: el día anterior a las 9:00');
ok(/tarjeta/i.test(byName('Pago Visa').title) && byName('Pago Visa').body.startsWith('Pago Visa · $100. '), 'tarjeta: título de tarjeta y el monto delante');
eq([iso(byName('Netflix').at), byName('Netflix').title], ['2026-11-04 08:00', 'Hoy se cobra Netflix'], 'suscripción: la víspera ya pasó, avisa el mismo día a las 8:00');
ok(byName('Sueldo').body.startsWith('Sueldo · $1500. ') && iso(byName('Sueldo').at) === '2026-11-19 09:00', 'ingreso: el día anterior, con el monto');
ok(byName('Alquiler') && /pago|pagar/i.test(byName('Alquiler').title), 'gasto: aviso de pago');
p = plan({ prefs: { up: true, amt: false }, events: [ev('2026-11-10', 'Pago Visa', -100, 'card')] });
ok(!/\$/.test(p[0].body) && p[0].body.startsWith('Pago Visa. '), 'sin «mostrar montos» no sale el monto');

// Inglés
p = plan({ lang: 1, prefs: { up: true, ins: true }, events: [ev('2026-11-04', 'Netflix', -15, 'sub')], monthName: (d) => new Intl.DateTimeFormat('en', { month: 'long' }).format(d) });
ok(p.some((x) => x.title === 'Netflix charges you today'), 'inglés: «Netflix charges you today»');
ok(p.some((x) => x.title === 'Ding: new grade' && x.body === 'Check your November insights while they\'re hot.'), 'inglés: la nota del mes con el mes en inglés');
// el mismo plan dos veces da lo mismo (se reprograma seguido)
eq(JSON.stringify(plan({ prefs: { inact: true, up: true, ins: true, since: now.getTime() } })), JSON.stringify(plan({ prefs: { inact: true, up: true, ins: true, since: now.getTime() } })), 'el plan es estable');
console.log(f ? '\n' + f + ' FALLAS' : '\nTodo bien');
process.exit(f ? 1 : 0);
