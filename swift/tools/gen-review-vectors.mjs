#!/usr/bin/env node
// Vectores de Revisión: perfiles con movimientos que disparan cada tipo de tarjeta (transferencia, pago, repetido, monto alto,
// recurrentes, estados faltantes…) y lo que `revScan` de la WEB devuelve. Swift (Engine.reviewScan) debe dar lo mismo.
//   node swift/tools/gen-review-vectors.mjs
process.env.TZ = 'UTC';
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { load } from './web-engine.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const out = join(root, 'swift/PlataCore/Tests/PlataCoreTests/Fixtures/review.json');
let seed = 20261029;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
const ri = (a, b) => a + Math.floor(rnd() * (b - a + 1));
const pick = (a) => a[Math.floor(rnd() * a.length)];
const chance = (p) => rnd() < p;
const money = (lo, hi) => Math.round((lo + rnd() * (hi - lo)) * 100) / 100;
const pad = (n) => String(n).padStart(2, '0');
const isoOf = (d) => d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate());
const addD = (d, n) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);

const TODAYS = ['2026-10-28', '2026-03-15', '2026-12-31', '2027-02-28', '2026-07-04'];
const BRAND_NOTES = ['NETFLIX.COM 866-579', 'SPOTIFY P3A12', 'Disney Plus', 'GITHUB.COM', 'OPENAI *CHATGPT SUBSCR', 'Apple.com/bill'];
const FIX_NOTES = ['Gym Membership Planet', 'Cuota Colegio San Pedro', 'Internet Fibra Hogar', 'Seguro Vehicular Rimac'];
const JOB_NOTES = ['PAYROLL ACME CORP', 'Sueldo Estudio Gamma', 'ACH DEPOSIT HOLDINGS LLC'];
const CATS = ['Comida', 'Ocio', 'Transporte', 'Servicios', 'Hogar', 'Otros', 'Salud'];
const OWN = ['Moved to Secured Deposit Account', 'Transfer to Savings', 'Online banking transfer from SAV 1234', 'Transfer from x1234 to x9876', 'Transfer to Apple Pay Visa 4411'];

function profile(today) {
  const T = new Date(today + 'T00:00:00');
  const cur2 = chance(0.5) ? 'PEN' : '';
  const settings = { currency: 'USD', currency2: cur2, ...(cur2 ? { fx: pick([3.7, 3.85]) } : {}) };
  const accounts = [{ id: 'a1', name: 'Chase', type: 'checking', cur: 'USD', balance: money(100, 4000) }, { id: 'a2', name: 'Ahorros', type: 'savings', cur: cur2 && chance(0.5) ? cur2 : 'USD', balance: money(100, 4000) }];
  const cards = [{ id: 'k1', kind: 'card', name: 'Visa', cur: 'USD', limit: 3000, balance: pick([0, 340.5, 1200]), apr: 24, payment: pick([0, 85, 120]), due_day: 12 }];
  let id = 0;
  const tx = (date, amount, category, note, acc, extra) => ({ id: ++id, date: isoOf(date), amount, category, note, acc, ...(extra || {}) });
  const T0 = (n) => addD(T, -n);
  const L = [];
  // movimientos de fondo (todos recientes para que `ref` esté cerca de hoy)
  for (let i = 0; i < ri(12, 30); i++) L.push(tx(T0(ri(0, 100)), -money(2, 90), pick(CATS), 'compra ' + i, pick(['a1', 'a1', 'a2'])));
  L.push(tx(T0(0), -money(3, 20), 'Comida', 'hoy', 'a1'));
  // transferencias
  for (let i = 0; i < ri(0, 5); i++) {
    const d = T0(ri(3, 100)), a = money(20, 800), g = pick([0, 0, 1, 2, 3, 5, 7]), fx = chance(0.3) ? money(-1.5, 1.5) : 0;
    L.push(tx(d, -a, pick(['Otros', 'Ocio']), pick(['', 'envio', 'Zelle']), 'a1'));
    L.push(tx(addD(d, g), a + fx, 'Ingreso', pick(['', 'recibido', 'deposito']), 'a2'));
  }
  // pago de tarjeta suelto + gasto de cuenta
  for (let i = 0; i < ri(0, 3); i++) {
    const d = T0(ri(3, 100)), a = money(30, 600), g = pick([0, 1, 2, 3]);
    L.push(tx(d, -a, 'Otros', 'pago visa', 'a1'));
    L.push(tx(addD(d, g), a, pick(['Pago de crédito', 'Ingreso']), 'payment thank you', 'k1'));
  }
  // repetidos (a mano + importado)
  for (let i = 0; i < ri(0, 3); i++) {
    const d = T0(ri(3, 100)), a = -money(5, 200), acc = pick(['a1', 'a2']);
    L.push(tx(d, a, 'Comida', 'cena', acc)); L.push(tx(addD(d, pick([0, 1, 2])), a, 'Comida', 'CENA RESTAURANTE', acc, { imp: 1 }));
  }
  // movimientos de otra cuenta propia
  if (chance(0.6)) { const n = pick(OWN); for (let i = 0; i < ri(2, 4); i++) L.push(tx(T0(ri(2, 100)), chance(0.5) ? -money(20, 300) : money(20, 300), 'Otros', n + ' ' + i, 'a1')); }
  // gasto que coincide con la cuota o el saldo de una tarjeta
  if (chance(0.6)) { const k = cards[0]; const v = k.payment > 0 ? k.payment : k.balance; if (v > 0) L.push(tx(T0(ri(3, 100)), -(v + (chance(0.5) ? 0.4 : 0)), 'Otros', 'pago', 'a1')); }
  // monto muy alto en su categoría
  if (chance(0.6)) { const c = pick(CATS); for (let i = 0; i < 7; i++) L.push(tx(T0(ri(5, 100)), -money(8, 22), c, 'x' + i, 'a1')); L.push(tx(T0(ri(1, 80)), -money(400, 900), c, 'raro', 'a1')); }
  // recurrentes
  const monthly = (note, amt, n, acc, jitter, extra) => { const dy = ri(1, 27); for (let i = 0; i < n; i++) { const d = new Date(T.getFullYear(), T.getMonth() - i, dy); L.push(tx(d, typeof amt === 'function' ? amt(i) : amt, extra && extra.cat || 'Servicios', note, acc)); } };
  if (chance(0.8)) monthly(pick(BRAND_NOTES), -money(5, 30), ri(2, 5), pick(['a1', 'a2']), 0);
  if (chance(0.7)) monthly(pick(FIX_NOTES), -money(40, 200), ri(3, 5), 'a1', 0, { cat: pick(['Servicios', 'Hogar', 'Otros']) });
  if (chance(0.5)) { const b = money(40, 150); monthly('Luz del Sur ' + ri(1, 9), (i) => -(b + (i % 2) * b * 0.2), ri(3, 5), 'a1', 0, { cat: 'Servicios' }); }
  if (chance(0.7)) { const note = pick(JOB_NOTES), a = money(900, 2400), dy = ri(1, 27), n = ri(3, 5); for (let i = 0; i < n; i++) L.push(tx(new Date(T.getFullYear(), T.getMonth() - i, dy), a, 'Ingreso', note, 'a1')); }
  if (chance(0.5)) { const note = 'PAYCHECK GLOBEX ' + ri(1, 3), a = money(500, 1500); for (let i = 0; i < 6; i++) L.push(tx(addD(T, -i * 14 - ri(0, 1)), a, 'Ingreso', note, 'a1')); }
  if (chance(0.4)) { const a = money(300, 800); for (let i = 0; i < 6; i++) { const m = new Date(T.getFullYear(), T.getMonth() - i, 1); L.push(tx(addD(m, chance(0.5) ? 14 : 14), a, 'Ingreso', 'PAGO QUINCENA ACME', 'a1')); L.push(tx(new Date(m.getFullYear(), m.getMonth() + 1, 0), a, 'Ingreso', 'PAGO QUINCENA ACME', 'a1')); } }
  // venmo (p2p) no es recurrente
  if (chance(0.4)) monthly('Venmo cashout', -money(20, 60), 4, 'a1', 0);
  // estados faltantes: cuenta hecha solo de importaciones con un mes vacío
  if (chance(0.6)) {
    const acc = { id: 'a3', name: 'Importada', type: 'checking', cur: 'USD', balance: money(0, 3000) }; accounts.push(acc);
    for (let i = 0; i < 24; i++) { const m = i % 6; if (m === 3 && chance(0.9)) continue; L.push(tx(new Date(T.getFullYear(), T.getMonth() - m, ri(1, 27)), chance(0.3) ? money(10, 500) : -money(3, 90), pick(CATS), 'imp ' + i, 'a3', { imp: 1 })); }
  }
  // algunos ya vinculados
  L.forEach((t) => { if (chance(0.04)) t.pair = 'p' + t.id; else if (chance(0.03)) t.job = 'jobx'; });
  const subs = chance(0.4) ? [{ id: 's1', name: 'Netflix', amount: 15.49, cur: 'USD', day: 5, acc: 'a1' }] : [];
  const expected_expense = chance(0.3) ? [{ id: 'e1', name: 'Gym Membership', amount: -60, acc: 'a1', date: isoOf(addD(T, 5)), repeat: 'm', cat: 'Salud' }] : [];
  const jobs = chance(0.3) ? [{ id: 'job1', name: 'Payroll Acme', sim: 0, mode: 's', rate: 1500, hours: 0, tax: 0, freq: 'm', start: isoOf(addD(T, 3)), acc: 'a1' }] : [];
  L.forEach((t) => { if (t.job === 'jobx') delete t.job; });
  return { version: 3, settings, accounts, transactions: L, history: [], cards, recurring: [], subs, savings: [], budget: {}, budgetSets: [], expected_income: [], expected_expense, planned: [], jobs };
}

const cases = [];
for (let n = 0; n < 60; n++) {
  const today = TODAYS[n % TODAYS.length], raw = profile(today);
  const { api } = load({ today, entry: ['revScan', 'migrate', 'clone', 'syncCats', 'subBrand', 'REC_NAME', 'recTitle'] });
  let data; try { data = api.migrate(api.clone(raw)); } catch (e) { continue; }
  api.setData(data); api.syncCats();
  const snap = JSON.parse(JSON.stringify(data));
  const brands = {};
  const names = [].concat(data.transactions.map((t) => t.note), data.subs.map((x) => x.name), data.expected_expense.map((x) => x.name), data.expected_income.map((x) => x.name), data.jobs.map((x) => x.name), (data.recurring || []).map((x) => x.name));
  names.forEach((n0) => { const nm = String(n0 || ''); if (nm && !(nm in brands)) { const b = api.subBrand({ name: nm }); brands[nm] = b ? { id: b.i, key0: b.keys[0], name: api.REC_NAME[b.i] || null } : null; } });
  const shape = (list) => list.map((r) => ({ kind: r.kind, k: r.k, txs: r.txs.map((x) => String(x.id)), score: r.score, hi: !!r.hi, far: !!r.far, label: r.label || null, cur: r.cur == null ? null : r.cur, out: r.out == null ? null : r.out, inn: r.inn == null ? null : r.inn, med: r.med == null ? null : r.med, card: r.card || null, acc: r.acc || null, miss: r.miss || null, diff: r.diff == null ? null : r.diff,
    type: r.type || null, name: r.kind === 'rec' ? r.name : null, amt: r.kind === 'rec' ? r.amt : null, fixed: r.kind === 'rec' ? !!r.fixed : null, cad: r.cad || null, neg: r.kind === 'rec' ? !!r.neg : null, q: r.q || null, brand: r.brand ? r.brand.i : null }));
  const first = shape(api.revScan());
  const skip = first.length ? [first[0].k, ...(first.length > 3 ? [first[3].k] : [])] : [];
  data.settings.rv_off = skip; api.setData(data); // la caché de la web depende de rv_off.length
  const second = shape(api.revScan());
  cases.push({ today, profile: snap, brands, skip, first, second });
}
const kinds = {}; cases.forEach((c) => c.first.forEach((r) => { const k = r.kind === 'rec' ? 'rec_' + r.type : r.kind; kinds[k] = (kinds[k] || 0) + 1; }));
writeFileSync(out, JSON.stringify({ cases }));
console.log('Revisión:', cases.length, 'casos →', out.split('/').slice(-2).join('/'), JSON.stringify(kinds));
