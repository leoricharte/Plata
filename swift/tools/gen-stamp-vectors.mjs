#!/usr/bin/env node
// Vectores del sellado de ediciones (syncStamp de la web): marcas `mod`, lápidas `tomb` y `fmod`.
// Cada caso es una secuencia de ediciones; tras cada una se guarda el perfil ANTES de sellar y lo que la web produjo DESPUÉS.
// Swift debe dar lo mismo, partiendo del mismo estado y reloj.
//
//   node swift/tools/gen-stamp-vectors.mjs
process.env.TZ = 'UTC';
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { load } from './web-engine.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const out = join(root, 'swift/PlataCore/Tests/PlataCoreTests/Fixtures/stamp.json');
let seed = 77123;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
const ri = (a, b) => a + Math.floor(rnd() * (b - a + 1));
const pick = (a) => a[Math.floor(rnd() * a.length)];
const chance = (p) => rnd() < p;
const money = (lo, hi) => Math.round((lo + rnd() * (hi - lo)) * 100) / 100;
const DAY = 864e5;

function base() {
  return {
    version: 3, settings: { currency: 'USD', cushion: 100 },
    accounts: [{ id: 'bank', name: 'Cuenta', type: 'checking', cur: 'USD', balance: 500 }, { id: 'sav', name: 'Ahorro', type: 'savings', cur: 'USD', balance: 50 }],
    cards: [{ id: 'c1', name: 'Tarjeta', kind: 'card', cur: 'USD', balance: 120, limit: 1000, apr: 20, payment: 30, due_day: 5 }],
    transactions: Array.from({ length: ri(3, 10) }, (_, i) => ({ id: 100 + i, date: '2026-10-' + String(ri(1, 27)).padStart(2, '0'), amount: -money(1, 90), category: 'Comida', note: 'n' + i, acc: 'bank' })),
    subs: [{ id: 's1', name: 'Netflix', amount: 9.99, cur: 'USD', day: 3 }], savings: [{ id: 'v1', name: 'Meta', goal: 1000, balance: 100, monthly: 50, cur: 'USD', log: [] }],
    expected_income: [{ id: 'i1', name: 'Sueldo', amount: 1000, acc: 'bank', date: '2026-11-01', repeat: 'm', until: '' }], expected_expense: [], planned: [], jobs: [],
    budget: { Comida: 200 }, budgetSets: [], history: [], recurring: [], cats: [{ name: 'Comida', color: '#B98AE6', icon: '' }, { name: 'Otros', color: '#C9CBD1', icon: '' }], ovr: {}, halfSnaps: {}, firstHalf: '',
  };
}

const cases = [];
for (let n = 0; n < 40; n++) {
  const { api } = load({ today: '2026-10-28', entry: ['syncStamp', 'migrate', 'clone'], prelude: 'var __now = 0; Date.now = () => __now;' });
  const data = api.migrate(api.clone(base()));
  api.setData(data);
  let now = 1_790_000_000_000;
  const removed = [];
  const steps = [];
  const stepN = ri(4, 12);
  for (let s = 0; s < stepN; s++) {
    now += chance(0.15) ? ri(60, 130) * DAY : ri(1, 5000) * 1000;
    const d = api.getData();
    const act = pick(['addTx', 'addTx', 'editTx', 'delTx', 'delTx', 'addAcc', 'editAcc', 'delAcc', 'settings', 'budget', 'readd', 'noop', 'savlog', 'cat', 'oldTomb', 'ovr', 'halfSnap', 'dupId']);
    if (act === 'addTx') d.transactions.push({ id: 1000 + ri(0, 5000), date: '2026-10-' + String(ri(1, 28)).padStart(2, '0'), amount: -money(1, 50), category: 'Comida', note: 'x', acc: 'bank' });
    else if (act === 'editTx' && d.transactions.length) pick(d.transactions).amount = -money(1, 99);
    else if (act === 'delTx' && d.transactions.length) { const i = ri(0, d.transactions.length - 1); removed.push(['transactions', d.transactions[i]]); d.transactions.splice(i, 1); }
    else if (act === 'addAcc') d.accounts.push({ id: 'acc' + ri(0, 9999), name: 'Nueva', type: 'checking', cur: 'USD', balance: money(0, 300) });
    else if (act === 'editAcc') pick(d.accounts).balance = money(0, 900);
    else if (act === 'delAcc' && d.accounts.length > 1) { const i = ri(0, d.accounts.length - 1); removed.push(['accounts', d.accounts[i]]); d.accounts.splice(i, 1); }
    else if (act === 'settings') { d.settings.currency = pick(['USD', 'EUR', 'PEN']); if (chance(0.5)) d.settings.nick = 'N' + ri(0, 9); }
    else if (act === 'budget') d.budget.Comida = ri(10, 500);
    else if (act === 'readd' && removed.length) { const [col, it] = removed.pop(); d[col].push(it); }
    else if (act === 'savlog') d.savings[0].log.push({ date: '2026-10-' + String(ri(1, 28)).padStart(2, '0'), amount: ri(1, 90) });
    else if (act === 'cat') d.cats.push({ name: 'C' + ri(0, 99), color: '#112233', icon: '' });
    else if (act === 'oldTomb') d.tomb.push({ c: 'cards', id: 'old' + ri(0, 9), t: now - ri(60, 140) * DAY });
    else if (act === 'ovr') d.ovr['rec:0:2026-11-0' + ri(1, 9)] = { amt: ri(1, 50) };
    else if (act === 'halfSnap') d.halfSnaps['2026-10'] = { letter: pick(['A', 'B', 'C']), score: ri(40, 99) };
    else if (act === 'dupId' && d.transactions.length) d.transactions.push({ ...d.transactions[0], amount: -money(1, 9) });
    const before = JSON.parse(JSON.stringify(d));
    api.setNow(now);
    api.syncStamp();
    steps.push({ now, before, after: JSON.parse(JSON.stringify(api.getData())) });
  }
  cases.push({ steps });
}
writeFileSync(out, JSON.stringify({ cases }));
console.log('Listo:', cases.length, 'casos de sellado →', out.replace(root + '/', ''));
