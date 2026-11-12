// Pruebas del motor de Plata (dev/app/src/motor/): fechas, repeticiones y montos, sin navegador.
// Uso: node dev/tests/motor.mjs   · Cada prueba imprime OK/FALLA.
// Que dev/app/src/js/00-motor.js esté al día con los módulos lo revisa el CI (lo regenera y compara con git).
import * as M from '../app/src/motor/index.mjs';

let f = 0;
const ok = (c, m) => { console.log((c ? 'OK    ' : 'FALLA ') + m); if (!c) f++; };
const D = (s) => M.pd(s), S = (d) => M.iso(d);

// --- números
ok(M.round2(1.005) === 1 && M.round2(2.675) === 2.68 && M.round2(-12.345) === -12.34, 'round2: redondea a céntimos como hasta ahora (el error de coma flotante de 1.005 incluido)');
ok(M.clampAmt(5e12) === M.MAXAMT && M.clampAmt(-5e12) === -M.MAXAMT, 'clampAmt: tope de ±999,999,999');
ok(M.clampAmt(NaN) === 0 && M.clampAmt(Infinity) === 0 && M.clampAmt(-Infinity) === 0, 'clampAmt: NaN e Infinity pasan a 0');
ok(M.clampAmt('12') === '12' && M.clampAmt(null) === null && M.clampAmt(-42.5) === -42.5, 'clampAmt: lo que no es número no se toca; un monto normal tampoco');
ok(M.sum([{ a: 1 }, { a: 2.5 }], (x) => x.a) === 3.5 && M.sum([], (x) => x) === 0, 'sum');

// --- fechas (siempre hora local)
ok(S(D('2026-11-12')) === '2026-11-12' && S(D('2024-02-29')) === '2024-02-29', 'iso/pd: ida y vuelta');
ok(D('2026-03-08').getHours() === 0 && D('2026-11-01').getDate() === 1, 'pd: medianoche local, también en cambio de horario');
ok(S(M.addDays(D('2026-12-31'), 1)) === '2027-01-01' && S(M.addDays(D('2026-03-01'), -1)) === '2026-02-28', 'addDays: cruza mes y año');
ok(S(M.addMonths(D('2026-01-31'), 1)) === '2026-02-01' && S(M.addMonths(D('2026-11-15'), 2)) === '2027-01-01', 'addMonths: siempre al día 1');
ok(M.pad(3) === '03' && M.pad(12) === '12', 'pad');

// --- repeticiones
ok(M.isQ('q15,30') && !M.isQ('m') && !M.isQ(14), 'isQ');
ok(M.qDays('q30,15').join() === '15,30' && M.qDays('q0,40').join() === '1,31' && M.qDays('basura').join() === '15,30', 'qDays: ordena, limita a 1–31 y usa 15/30 por defecto');
ok(M.qMake(30, 15) === 'q15,30', 'qMake');
ok(M.repN('m') === 'm' && M.repN('q1,15') === 'q1,15' && M.repN('14') === 14 && M.repN('x') === 0 && M.repN(undefined) === 0, 'repN');
ok(S(M.qNext(D('2026-11-12'), 'q15,30', false)) === '2026-11-15', 'qNext: el próximo día de quincena del mes');
ok(S(M.qNext(D('2026-11-15'), 'q15,30', false)) === '2026-11-30' && S(M.qNext(D('2026-11-15'), 'q15,30', true)) === '2026-11-15', 'qNext: con incl, el mismo día cuenta');
ok(S(M.qNext(D('2026-02-20'), 'q15,30', false)) === '2026-02-28', 'qNext: el 30 en febrero cae el 28');
ok(S(M.qNext(D('2026-11-30'), 'q15,30', false)) === '2026-12-15', 'qNext: después del segundo día, pasa al mes siguiente');
ok(S(M.nextRep(D('2026-01-31'), 'm')) === '2026-02-28' && S(M.nextRep(D('2026-03-15'), 'm')) === '2026-04-15', 'nextRep mensual: el día 31 cae en el último día de febrero');
ok(S(M.nextRep(D('2026-11-12'), 7)) === '2026-11-19' && S(M.nextRep(D('2026-11-12'), 14)) === '2026-11-26', 'nextRep: semanal y cada 2 semanas');
ok(S(M.nextRep(D('2026-11-12'), 0)) === '2026-11-19', 'nextRep: sin repetición válida, una semana (como antes)');
ok(S(M.nextRep(D('2026-12-20'), 'q1,15')) === '2027-01-01', 'nextRep quincenal: cruza de año');

console.log(f ? '\n' + f + ' FALLA(S)' : '\nTodo bien');
process.exit(f ? 1 : 0);
