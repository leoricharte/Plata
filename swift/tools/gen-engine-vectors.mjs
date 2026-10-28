#!/usr/bin/env node
// Vectores del motor de cálculo: perfiles de entrada (algo desordenados, como los archivos reales) y lo que la WEB calcula con ellos
// (migrate, calc, genEvents, projection, dailySeries, simImpact, payoff, pendingItems, nextIncome).
// Swift debe dar los mismos números. Ejecuta el código real de dev/app/src/app.html (ver web-engine.mjs).
//
//   node swift/tools/gen-engine-vectors.mjs
process.env.TZ = 'UTC';
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { load } from './web-engine.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const out = join(root, 'swift/PlataCore/Tests/PlataCoreTests/Fixtures/engine.json');

let seed = 20261028;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
const ri = (a, b) => a + Math.floor(rnd() * (b - a + 1));
const pick = (a) => a[Math.floor(rnd() * a.length)];
const chance = (p) => rnd() < p;
const money = (lo, hi) => Math.round((lo + rnd() * (hi - lo)) * 100) / 100;
const pad = (n) => String(n).padStart(2, '0');
const isoOf = (d) => d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate());
const addD = (d, n) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);

const TODAYS = ['2026-10-28', '2026-01-31', '2026-03-01', '2026-12-15', '2027-02-28', '2026-06-30', '2026-09-15'];
const NAMES = ['Netflix', 'Spotify', 'Música Pro', 'Gimnasio', 'iCloud', 'Café Ñandú'];
const CATS = ['Comida', 'Proyectos', 'Alquiler', 'Ocio', 'Transporte', 'Otros', 'Ingreso', 'Pago de crédito', 'Transferencia', 'Mascotas', 'Salud'];

function rawProfile(today) {
  const T = new Date(today + 'T00:00:00');
  const cur = pick(['USD', 'USD', 'PEN', 'EUR', 'MXN']);
  const c2 = chance(0.3) ? undefined : (chance(0.5) ? (cur === 'USD' ? 'PEN' : 'USD') : '');
  const settings = { currency: cur, cushion: ri(0, 600), variable_weekly: ri(0, 300) };
  if (c2 !== undefined) settings.currency2 = c2;
  if (chance(0.7)) settings.fx = chance(0.5) ? money(0.5, 5) : 3.7;
  if (chance(0.2)) settings.nick = 'Ana <b>"x"</b>';
  const curs = [cur].concat(c2 ? [c2] : []);
  const accounts = Array.from({ length: ri(1, 3) }, (_, i) => ({ ...(chance(0.8) ? { id: pick(['bank', 'sav', 'cash', 'a-' + i]) + i } : {}), name: 'Cuenta ' + i, type: pick(['checking', 'savings', 'cash']), cur: chance(0.1) ? 'XXX' : pick(curs), balance: money(-200, 5000), color: chance(0.2) ? 'rojo!' : '#22B573' }));
  const cards = Array.from({ length: ri(0, 3) }, (_, i) => ({ ...(chance(0.85) ? { id: 'card' + i } : {}), kind: chance(0.7) ? 'card' : 'loan', name: 'Tarjeta ' + i, cur: pick(curs), limit: ri(500, 5000), balance: chance(0.15) ? 0 : money(0, 3000), apr: money(0, 36), payment: chance(0.4) ? 0 : ri(20, 300), due_day: chance(0.9) ? ri(1, 31) : 0 }));
  cards.forEach((c) => { if (c.id && chance(0.35) && c.due_day > 0) c.auto = { next: isoOf(addD(T, ri(-10, 20))) }; });
  const accIds = accounts.map((a, i) => a.id || 'a' + i), cardIds = cards.map((c, i) => c.id || 'c' + i), anyAcc = () => pick(accIds.concat(chance(0.2) ? cardIds : []));
  const subs = Array.from({ length: ri(0, 4) }, (_, i) => ({ ...(chance(0.9) ? { id: 'sub' + i } : {}), name: NAMES[i % NAMES.length], amount: money(2, 60), cur: pick(curs), day: ri(1, 31) }));
  const savings = Array.from({ length: ri(0, 2) }, (_, i) => ({ ...(chance(0.9) ? { id: 'sv' + i } : {}), name: 'Meta ' + i, goal: ri(500, 9000), balance: money(0, 4000), monthly: ri(0, 400), cur: pick(curs), log: chance(0.5) ? [{ date: isoOf(addD(T, -ri(1, 60))), amount: ri(10, 300) }] : [] }));
  const monthStart = new Date(T.getFullYear(), T.getMonth(), 1);
  const transactions = Array.from({ length: ri(8, 45) }, (_, i) => {
    const d = addD(monthStart, ri(-45, Math.max(0, T.getDate() - 1))); const cat = pick(CATS), income = cat === 'Ingreso' || (cat !== 'Pago de crédito' && cat !== 'Transferencia' && chance(0.1));
    const sub = subs.length && chance(0.15) ? pick(subs) : null;
    return { ...(chance(0.95) ? { id: i + 1 } : {}), date: isoOf(d), amount: income ? money(50, 3000) : -money(1, 400), category: sub ? 'Otros' : cat, note: sub ? (chance(0.5) ? sub.name.toUpperCase() : sub.name.normalize('NFD').replace(/[̀-ͯ]/g, '')) : 'nota ' + i, acc: anyAcc(), ...(sub && sub.id && chance(0.4) ? { sub: sub.id } : {}), ...(chance(0.2) ? { est: money(1, 400) } : {}) };
  });
  const rep = () => pick([0, 0, 7, 14, 'm', 'm', 'q10,25', 'q1,15', '7', 30]);
  const expected_income = Array.from({ length: ri(0, 3) }, (_, i) => ({ ...(chance(0.9) ? { id: 'in' + i } : {}), name: 'Sueldo ' + i, amount: ri(300, 3000), acc: chance(0.9) ? pick(accIds) : undefined, date: isoOf(addD(T, ri(-20, 60))), repeat: rep(), ...(chance(0.3) ? { until: isoOf(addD(T, ri(30, 300))) } : {}), ...(chance(0.1) ? { snooze: isoOf(addD(T, 3)) } : {}) }));
  const expected_expense = Array.from({ length: ri(0, 3) }, (_, i) => ({ ...(chance(0.9) ? { id: 'ex' + i } : {}), name: 'Gasto ' + i, amount: -ri(20, 900), acc: pick(accIds), date: isoOf(addD(T, ri(-20, 90))), repeat: rep(), cat: pick(CATS.slice(0, 6)), ...(cards.length && chance(0.3) ? { card: pick(cardIds) } : {}), ...(chance(0.25) ? { until: isoOf(addD(T, ri(30, 300))) } : {}) }));
  const planned = Array.from({ length: ri(0, 3) }, (_, i) => ({ ...(chance(0.9) ? { id: 'pl' + i } : {}), name: 'Simulado ' + i, date: isoOf(addD(T, ri(-5, 120))), amount: chance(0.8) ? -ri(20, 1200) : ri(20, 800), ...(chance(0.3) ? { on: false } : {}), ...(chance(0.3) ? { until: isoOf(addD(T, ri(10, 160))) } : {}) }));
  const jobs = Array.from({ length: ri(0, 2) }, (_, i) => ({ id: 'job' + i, name: 'Trabajo ' + i, sim: chance(0.7), mode: pick(['h', 's']), rate: ri(8, 40), hours: ri(10, 40), tax: ri(0, 30), freq: pick(['w', 'b', 'q', 'm']), q1: ri(1, 14), q2: ri(15, 31), start: isoOf(addD(T, ri(-30, 30))), acc: pick(accIds), ...(chance(0.3) ? { until: isoOf(addD(T, ri(30, 300))) } : {}) }));
  const recurring = Array.from({ length: ri(0, 3) }, (_, i) => ({ name: 'Fijo ' + i, amount: chance(0.8) ? -ri(20, 1200) : ri(20, 500), day: chance(0.9) ? ri(1, 31) : 0 }));
  const budget = {}; ['Comida', 'Ocio', 'Transporte', 'Mascotas'].forEach((k) => { if (chance(0.7)) budget[k] = ri(50, 600); });
  const budgetSets = chance(0.35) ? [{ id: 'bs1', name: 'Viaje', from: isoOf(addD(T, -3)), to: isoOf(addD(T, 20)), budget: { Comida: ri(100, 900), Ocio: ri(50, 300) } }] : [];
  const history = Array.from({ length: ri(0, 7) }, (_, i) => ({ month: isoOf(new Date(T.getFullYear(), T.getMonth() - 1 - i, 1)).slice(0, 7), income: ri(1000, 4000), expense: ri(800, 3800) }));
  const p = { version: 3, settings, accounts, transactions, history, cards, recurring, subs, savings, budget, budgetSets, expected_income, expected_expense, planned, jobs };
  if (chance(0.6)) p.cats = [{ name: 'Comida', color: '#B98AE6' }, { name: 'Ocio', color: 'malo' }, { name: 'Mascotas', color: '#123456', icon: 'paw' }];
  if (chance(0.1)) p.analysis = { v: 1, id: 'abcd1234', at: '2026-10-01' };
  return p;
}

const cases = [];
for (let n = 0; n < 70; n++) {
  const today = TODAYS[n % TODAYS.length], variable = chance(0.8), raw = rawProfile(today);
  const { api } = load({ today, entry: ['calc', 'genEvents', 'projection', 'dailySeries', 'simImpact', 'payoff', 'pendingItems', 'nextIncome', 'migrate', 'clone', 'syncCats', 'iso'] });
  let data;
  try { data = api.migrate(api.clone(raw)); } catch (e) { continue; }
  api.setData(data); api.syncCats(); api.setUi({ variable });
  // ovr: se editan/saltan algunos eventos reales
  const evs = api.genEvents(api.calc().today);
  const ovr = {}; evs.filter((e) => e.key && e.type !== 'sim').slice(0, 40).forEach((e) => { if (chance(0.12)) ovr[e.key] = pick([{ skip: true }, { amt: money(1, 700) }, { date: isoOf(addD(e.date, ri(-5, 9))) }, { amt: money(1, 300), date: isoOf(addD(e.date, ri(1, 4))) }]); });
  raw.ovr = ovr;
  data = api.migrate(api.clone(raw)); api.setData(data); api.syncCats(); api.setUi({ variable });
  const migrated = JSON.parse(JSON.stringify(data)); // justo después de migrate: calc() y pendingItems() modifican `data` (subHist, auto)
  const c = api.calc(), P = api.projection(), D = api.dailySeries({});
  const dt = (d) => api.iso(d);
  const ev = (list) => list.map((e) => ({ date: dt(e.date), name: e.name, amt: e.amt, type: e.type, key: e.key || null, pending: !!e.pending, skipped: !!e.skipped, edited: !!e.edited }));
  const calc = { mk: c.mk, dim: c.dim, income: c.income, expense: c.expense, incomeCount: c.incomeCount, cats: c.cats, catTot: c.catTot, months: c.months, balance: c.balance,
    cards: c.cards.map((k) => ({ id: k.id, ub: k.ub, color: k.color, util: k.util, interest: k.interest })), debt: c.debt, interest: c.interest,
    savings: c.savings.map((s) => ({ id: s.id, ub: s.ub, color: s.color })), saved: c.saved, savedMonthly: c.savedMonthly, budgetTotal: c.budgetTotal, subsTotal: c.subsTotal, expV: c.expV, subSpent: c.subSpent,
    txIds: c.tx.map((t) => String(t.id)), monthTxIds: c.monthTx.map((t) => String(t.id)), subHist: data.subHist[c.mk] };
  const projection = { V: P.V, minV: P.minV, firstRed: P.firstRed ? P.series.indexOf(P.firstRed) : -1, series: P.series.map((s) => ({ date: dt(s.date), v: s.v })),
    timeline: P.timeline.map((t) => ({ name: t.name, date: t.date, amt: t.amt, type: t.type, key: t.key || null, edited: t.edited, skipped: t.skipped, after: t.after })) };
  const simImpact = {}; (data.planned || []).forEach((p) => { const r = api.simImpact(p); simImpact[p.id] = r ? { start: r.start, end: r.end, withMin: r.withMin, withDate: dt(r.withDate), withoutMin: r.withoutMin, status: r.status } : null; });
  const payoff = {}; for (const k of [undefined, 'all', 'card', 'loan']) for (const x of [0, 50, 200]) payoff[String(k) + '|' + x] = api.payoff(x, k);
  const pend = api.pendingItems().map((x) => ({ k: x.k, id: x.e.id, date: x.e.date }));
  const ni = api.nextIncome();
  cases.push({ today, variable, raw, migrated, calc, events: ev(api.genEvents(c.today)), keepSkipped: ev(api.genEvents(c.today, { keepSkipped: true })).filter((e) => e.skipped), noSim: (() => { const l = api.genEvents(c.today, { noSim: true }); return { count: l.length, sum: l.reduce((s, e) => s + e.amt, 0) }; })(),
    projection, daily: D.map((d) => d.v), simImpact, payoff, pending: pend, nextIncome: ni ? { id: ni.id, date: ni.date, amount: ni.amount } : null });
}
writeFileSync(out, JSON.stringify({ cases }));
console.log('Listo:', cases.length, 'casos del motor →', out.replace(root + '/', ''));

// ---------- tabla de monedas (Sources/PlataCore/Currencies.swift) ----------
{
  const { api } = load({ today: '2026-10-28', entry: ['CURRENCIES', 'DEF_CATS'] });
  const esc = (s) => String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"');
  const rows = Object.entries(api.CURRENCIES).map(([code, c]) => `        "${esc(code)}": Currency(sym: "${esc(c.sym)}", name: "${esc(c.name)}", rate: ${c.rate}, k: ${c.k}${c.dec != null ? ', dec: ' + c.dec : ''}),`);
  const cats = api.DEF_CATS.map((c) => `        ("${esc(c.name)}", "${esc(c.color)}"),`);
  writeFileSync(join(root, 'swift/PlataCore/Sources/PlataCore/Currencies.swift'),
    '// Generado por swift/tools/gen-engine-vectors.mjs a partir de CURRENCIES y DEF_CATS de la web. No editar a mano.\n' +
    'public struct Currency: Equatable, Sendable {\n    public let sym: String, name: String, rate: Double, k: Double\n    public let dec: Int?\n' +
    '    init(sym: String, name: String, rate: Double, k: Double, dec: Int? = nil) { self.sym = sym; self.name = name; self.rate = rate; self.k = k; self.dec = dec }\n}\n\n' +
    'public enum Currencies {\n    public static let table: [String: Currency] = [\n' + rows.join('\n') + '\n    ]\n' +
    '    /// Categorías por defecto (DEF_CATS).\n    static let defaultCategories: [(name: String, color: String)] = [\n' + cats.join('\n') + '\n    ]\n}\n');
  console.log('Currencies.swift:', rows.length, 'monedas');
}
