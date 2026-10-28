#!/usr/bin/env node
// Vectores de los perfiles de demostración: `rebaseProfile` + `migrate` de la web, a varias fechas de "hoy".
// Swift (DemoProfile.load) debe dar el mismo perfil.
//
//   node swift/tools/gen-demo-vectors.mjs
process.env.TZ = 'UTC';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { load } from './web-engine.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const out = join(root, 'swift/PlataCore/Tests/PlataCoreTests/Fixtures/demo.json');
const DEMOS = new Function(readFileSync(join(root, 'dev/app/src/demo_profiles.js'), 'utf8') + ';return DEMO_PROFILES')();
const ids = ['shawn', 'brenda', 'alessandro', 'andrea', 'kevin'];
const add = (iso, n) => new Date(Date.parse(iso + 'T00:00:00Z') + n * 864e5).toISOString().slice(0, 10);

const demos = {}, cases = [];
for (const id of ids) {
  demos[id] = DEMOS[id];
  const anchor = DEMOS[id].__anchor;
  for (const n of [0, 1, 9, 14, 20, 45, 100]) {
    const today = add(anchor, n);
    const { api } = load({ today, entry: ['rebaseProfile', 'migrate', 'clone'] });
    const want = api.migrate(api.rebaseProfile(api.clone(DEMOS[id])));
    if (!want.firstHalf) want.firstHalf = '2000-01';
    want.demo = true;
    cases.push({ id, today, want: JSON.parse(JSON.stringify(want)) });
  }
}
writeFileSync(out, JSON.stringify({ demos, cases }));
console.log('demo.json:', cases.length, 'casos');
