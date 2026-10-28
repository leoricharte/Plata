#!/usr/bin/env node
// Genera los vectores de prueba de PlataCore ejecutando el código REAL de la web (dev/app/src/app.html):
// el cifrado (PCC) y la combinación de perfiles (mergeData). Swift debe dar exactamente lo mismo.
//
//   node swift/tools/gen-vectors.mjs
//
// Escribe en swift/PlataCore/Tests/PlataCoreTests/Fixtures/ y la lista de palabras en Sources/PlataCore/Wordlist.swift.
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const html = readFileSync(join(root, 'dev/app/src/app.html'), 'utf8');
const fx = join(root, 'swift/PlataCore/Tests/PlataCoreTests/Fixtures');

function between(a, b) {
  const i = html.indexOf(a); if (i < 0) throw new Error('no encuentro: ' + a);
  const j = html.indexOf(b, i); if (j < 0) throw new Error('no encuentro: ' + b);
  return html.slice(i, j);
}
const pccSrc = between('const PCC = (() => {', '/* Plata Cloud · combinar');
const mergeSrc = between('const MG_COLS', '/* Plata Cloud · motor');

const NOW = 1790000000000; // 2026-09-21: fijo, para que la caducidad de lápidas (90 días) sea reproducible
const realNow = Date.now; Date.now = () => NOW;
const { PCC, mergeData } = new Function(pccSrc + '\n' + mergeSrc + '\nreturn { PCC, mergeData };')();

// ---------- lista de palabras ----------
const WL = PCC.WL; if (WL.length !== 2048) throw new Error('la lista debe tener 2048 palabras');
const lines = []; for (let i = 0; i < WL.length; i += 12) lines.push('    ' + WL.slice(i, i + 12).map((w) => '"' + w + '"').join(', ') + ',');
writeFileSync(join(root, 'swift/PlataCore/Sources/PlataCore/Wordlist.swift'),
  '// Generado por swift/tools/gen-vectors.mjs a partir de la lista de la web (2048 palabras). No editar a mano.\n' +
  'enum Wordlist {\n    static let words: [String] = [\n' + lines.join('\n') + '\n    ]\n}\n');

// ---------- cifrado ----------
const hex = (u) => Array.from(u).map((b) => b.toString(16).padStart(2, '0')).join('');
const unhex = (s) => new Uint8Array(s.match(/../g).map((h) => parseInt(h, 16)));
const crypt = { seeds: [], blobs: [] };
for (const sh of ['000102030405060708090a0b0c0d0e0f', 'ffffffffffffffffffffffffffffffff', '00000000000000000000000000000000', '7f3a91c2d4e5f60718293a4b5c6d7e8f']) {
  const seed = unhex(sh);
  crypt.seeds.push({ seedHex: sh, phrase: (await PCC.toPhrase(seed)).join(' '), check: await PCC.keyCheck(seed), write: await PCC.writeKey(seed), seedB64u: PCC.b64u(seed) });
}
const seed0 = unhex(crypt.seeds[0].seedHex), key0 = await PCC.dataKey(seed0);
const sample = { version: 3, settings: { currency: 'USD', nick: 'Ñandú ✓' }, accounts: [{ id: 'bank', name: 'Cuenta principal', type: 'checking', cur: 'USD', balance: 1234.56 }], transactions: [{ id: 1, date: '2026-10-01', amount: -41.8, category: 'Comida', note: 'café ☕', acc: 'bank' }], cats: [], budget: {} };
crypt.blobs.push({ name: 'gzip+rev', rev: 7, plain: sample, blob: await PCC.seal(key0, sample, 7) });
{ const keep = globalThis.CompressionStream; globalThis.CompressionStream = undefined; // sin compresión (z = 0)
  try { crypt.blobs.push({ name: 'sin gzip+rev', rev: 3, plain: sample, blob: await PCC.seal(key0, sample, 3) }); } finally { globalThis.CompressionStream = keep; } }
crypt.blobs.push({ name: 'formato viejo (sin rev)', rev: 0, plain: sample, blob: await PCC.seal(key0, sample, 0) });
writeFileSync(join(fx, 'crypto.json'), JSON.stringify(crypt, null, 1));

// ---------- combinar perfiles ----------
let s = 20261028; const rnd = () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
const pick = (a) => a[Math.floor(rnd() * a.length)];
const T0 = NOW - 5 * 864e5;
const mk = () => ({
  version: 3, demo: false, fmod: {},
  settings: { currency: 'USD', cushion: 400, variable_weekly: 180, lang: 'es', nick: '' },
  accounts: [{ id: 'bank', name: 'Cuenta principal', type: 'checking', cur: 'USD', balance: 1000, mod: T0 }, { id: 'sav', name: 'Ahorros', type: 'savings', cur: 'USD', balance: 500, mod: T0 }],
  transactions: [1, 2, 3, 4, 5].map((i) => ({ id: i, date: '2026-10-0' + i, amount: -10 * i, category: 'Comida', note: 'n' + i, acc: 'bank', mod: T0 })),
  history: [{ month: '2026-09', income: 3000, expense: 2500 }],
  cards: [{ id: 'c1', kind: 'card', name: 'Visa', cur: 'USD', limit: 2000, balance: 300, apr: 24, due_day: 12, mod: T0 }],
  recurring: [{ name: 'Alquiler', amount: -1150, day: 1 }], subs: [{ id: 's1', name: 'Netflix', amount: 15.49, cur: 'USD', day: 3, mod: T0 }],
  savings: [{ id: 'g1', name: 'Viaje', goal: 2000, balance: 400, log: [{ date: '2026-09-01', amount: 400 }], mod: T0 }],
  budget: { Comida: 300, Ocio: 100 }, budgetSets: [], expected_income: [], expected_expense: [], planned: [], jobs: [], cats: [{ name: 'Comida', color: '#B98AE6' }], tomb: []
});
let nextId = 100;
function mutate(p, tm) {
  const n = 1 + Math.floor(rnd() * 4);
  for (let k = 0; k < n; k++) {
    const r = rnd();
    if (r < 0.25) { const it = pick(p.transactions); if (it) { it.amount = -Math.round(rnd() * 900) / 10; it.mod = tm; } }
    else if (r < 0.4) { p.transactions.push({ id: ++nextId, date: '2026-10-2' + Math.floor(rnd() * 9), amount: -Math.round(rnd() * 500) / 10, category: 'Ocio', note: 'nuevo', acc: 'bank', mod: tm }); }
    else if (r < 0.55) { if (p.transactions.length) { const i = Math.floor(rnd() * p.transactions.length), it = p.transactions[i]; p.transactions.splice(i, 1); p.tomb.push({ c: 'transactions', id: String(it.id), t: tm }); } }
    else if (r < 0.7) { const a = pick(p.accounts); a.balance = Math.round((a.balance + (rnd() * 200 - 100)) * 100) / 100; a.mod = tm; }
    else if (r < 0.78) { p.settings.nick = pick(['Ana', 'Leo', 'Sol']); p.fmod = Object.assign({}, p.fmod, { settings: tm }); }
    else if (r < 0.84) { p.budget.Comida = 100 + Math.floor(rnd() * 400); p.fmod = Object.assign({}, p.fmod, { budget: tm }); }
    else if (r < 0.9) { const g = p.savings[0]; if (g) { const amt = Math.floor(rnd() * 100) + 1; g.balance += amt; g.log = g.log.concat([{ date: '2026-10-1' + Math.floor(rnd() * 9), amount: amt }]); g.mod = tm; } }
    else if (r < 0.95) { p.subs.push({ id: 's' + (++nextId), name: 'Sub ' + nextId, amount: 5, cur: 'USD', day: 9, mod: tm }); }
    else { p.history = p.history.concat([{ month: '2026-10', income: Math.floor(rnd() * 3000), expense: Math.floor(rnd() * 2500) }]); p.fmod = Object.assign({}, p.fmod, { history: tm }); }
  }
}
const cases = [];
for (let i = 0; i < 90; i++) {
  const base = mk(), local = JSON.parse(JSON.stringify(base)), remote = JSON.parse(JSON.stringify(base));
  mutate(local, T0 + 1000 * (1 + Math.floor(rnd() * 5)) + 86400000 * Math.floor(rnd() * 2));
  mutate(remote, T0 + 1000 * (1 + Math.floor(rnd() * 5)) + 86400000 * Math.floor(rnd() * 2));
  if (i % 9 === 0) remote.tomb.push({ c: 'transactions', id: '1', t: NOW - 200 * 864e5 }); // lápida vieja: se descarta
  const useBase = i % 5 !== 0; // cada quinto caso: sin base (primera sincronización)
  cases.push({ base: useBase ? base : null, local, remote, expected: mergeData(useBase ? base : null, local, remote) });
}
writeFileSync(join(fx, 'merge.json'), JSON.stringify({ now: NOW, cases }));
Date.now = realNow;
console.log('Listo:', crypt.seeds.length, 'semillas,', crypt.blobs.length, 'blobs,', cases.length, 'casos de combinación,', WL.length, 'palabras.');
