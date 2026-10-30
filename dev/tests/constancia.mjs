// Pruebas del lector de constancias de Yape y Plin (dev/app/src/core/nazca/constancia.js) con los textos INVENTADOS de dev/tests/constancias.json.
// Uso: node dev/tests/constancia.mjs  · Cada prueba imprime OK/FALLA.
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
const require = createRequire(import.meta.url);
const K = require('../app/src/core/nazca/constancia.js');
const C = require('../app/src/core/nazca/csv.js');
const fx = JSON.parse(readFileSync(new URL('./constancias.json', import.meta.url), 'utf8'));
let f = 0;
const ok = (c, m) => { console.log((c ? 'OK    ' : 'FALLA ') + m); if (!c) f++; };

for (const c of fx.cases) {
  const e = c.expect, r = K.read(c.text, { today: fx.today });
  ok(K.detect(c.text) === e.detect, c.name + ': detect = ' + e.detect);
  if (e.error) { ok(r.error === e.error, c.name + ': ' + e.error); continue; }
  const it = r.items[0];
  ok(it.amount === e.amount && r.cur === e.cur && it.date === e.date, c.name + ': ' + e.amount + ' ' + e.cur + ' el ' + e.date + ' (' + it.amount + ' ' + r.cur + ' ' + it.date + ')');
  ok(it.desc === e.desc && (it.ref || '') === e.ref, c.name + ': "' + e.desc + '" ref ' + (e.ref || '—') + ' (' + it.desc + ' / ' + (it.ref || '—') + ')');
  ok((r.bank || '') === e.bank && r.brand === e.brand && r.flags.join() === e.flags.join() && r.auto === e.auto, c.name + ': banco "' + e.bank + '", banderas [' + e.flags + '], auto ' + e.auto);
}

// La forma que espera impFromPdf (igual que los lectores de bancos)
{ const r = K.read(fx.cases[0].text, { today: fx.today });
  ok(r.kind === 'corriente' && r.items.length === 1 && r.skipped.unreadable === 0 && r.check === null && r.period.from === r.period.to, 'forma: un movimiento, sin comprobación de saldo, periodo de un día'); }

// Repetidos: reenviar la misma constancia es "exact"; otro pago igual el mismo día con otro número de operación no lo es
{ const a = K.read('Yapeaste S/ 10\nDestino\nBodega Rosa\n02/10/2026 12:00\nN° de operación 12121212', { today: fx.today }).items;
  const b = K.read('Yapeaste S/ 10\nDestino\nBodega Rosa\n02/10/2026 12:00\nN° de operación 12121299', { today: fx.today }).items;
  const pa = C.fingerprints(a)[0], pb = C.fingerprints(b)[0];
  ok(pa !== pb, 'repetidos: dos pagos iguales con distinto número de operación tienen huellas distintas');
  const d = C.markDuplicates(a, [{ acc: 'x', date: '2026-10-02', amount: -10, imp: pa }], 'x');
  ok(d[0].dup === 'exact', 'repetidos: la misma constancia importada otra vez sale como "exact"');
  const sin = C.fingerprints([{ date: '2026-10-02', amount: -10, desc: 'Bodega Rosa' }])[0];
  ok(typeof sin === 'string' && sin.length > 0, 'repetidos: un movimiento sin ref sigue teniendo huella (nada cambia para los demás bancos)'); }

// Límites y basura
ok(K.read('', {}).error === 'no_amount' && K.detect(null) === 0 && K.detect(undefined) === 0, 'límite: vacío o nulo no es constancia');
ok(K.detect('S/ 5\n'.repeat(5000)) === 0 && K.read('x'.repeat(100000) + '\nYapeaste S/ 5', {}).error === 'no_amount', 'límite: el texto se corta en ' + K.MAX_CHARS + ' caracteres');

console.log(f ? '\n' + f + ' FALLAS' : '\nTodo bien');
process.exit(f ? 1 : 0);
