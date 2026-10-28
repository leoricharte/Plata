// Carga el motor de cálculo REAL de la web (dev/app/src/app.html) en un contexto de Node, sin navegador.
// Extrae las declaraciones de primer nivel (function / const / let), calcula cuáles hacen falta a partir de unas funciones de entrada
// y las ejecuta en orden dentro de `vm`. Así los vectores de prueba de Swift salen de la lógica de la web, no de una copia.
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const html = readFileSync(join(root, 'dev/app/src/app.html'), 'utf8');

// La app es el <script> más largo del archivo
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
const src = scripts.sort((a, b) => b.length - a.length)[0];
const lines = src.split('\n');

// ---- trozos de primer nivel ----
const DECL = /^(async function\s+([A-Za-z_$][\w$]*)|function\s+([A-Za-z_$][\w$]*)|(?:const|let|var)\s+([A-Za-z_$][\w$]*))/;
const chunks = []; // { name, text, start }
let cur = null;
for (let i = 0; i < lines.length; i++) {
  const ln = lines[i];
  const m = DECL.exec(ln);
  if (m) { cur = { name: m[2] || m[3] || m[4], start: i, lines: [ln] }; chunks.push(cur); continue; }
  if (cur && (ln === '' || /^[\s})\]]/.test(ln) || /^\/\//.test(ln) && false)) { cur.lines.push(ln); continue; }
  cur = null; // sentencia de primer nivel que no es declaración (try, document.add…, comentarios): se ignora
}
chunks.forEach((c) => { c.text = c.lines.join('\n'); });
const byName = new Map(); chunks.forEach((c) => { if (!byName.has(c.name)) byName.set(c.name, c); });
// declaraciones en cadena: `const PAY = ..., XFER = ..., isPay = ...;` define varios nombres con un solo trozo
chunks.forEach((c) => { if (/^(const|let|var)\s/.test(c.lines[0])) for (const m of c.lines[0].matchAll(/,\s*([A-Za-z_$][\w$]*)\s*=(?![=>])/g)) if (!byName.has(m[1])) byName.set(m[1], c); });

// ---- cierre de dependencias ----
const SKIP = new Set(['data', 'ui', 'loadStored']); // se definen a mano
export function load({ today, entry, prelude = '' }) {
  const need = new Set(), stack = [...entry];
  while (stack.length) {
    const n = stack.pop(); if (need.has(n) || SKIP.has(n)) continue;
    const c = byName.get(n); if (!c) continue; need.add(n);
    for (const id of c.text.match(/[A-Za-z_$][\w$]*/g) || []) if (byName.has(id) && !need.has(id) && !SKIP.has(id)) stack.push(id);
  }
  const needChunks = new Set([...need].map((n) => byName.get(n)));
  const ordered = chunks.filter((c) => needChunks.has(c));
  const ctx = vm.createContext({ console, Math, Date, JSON, Number, String, Array, Object, Set, Map, Intl, RegExp, parseInt, parseFloat, isFinite, isNaN,
    location: { search: today ? '?today=' + today : '', hostname: 'node' }, navigator: { languages: ['es'], language: 'es' },
    localStorage: { getItem: () => null, setItem() {}, removeItem() {} }, sessionStorage: { getItem: () => null, setItem() {}, removeItem() {} },
    document: { documentElement: { classList: { contains: () => false } }, querySelector: () => null, querySelectorAll: () => [], addEventListener() {} },
    window: {}, setTimeout() {}, clearTimeout() {} });
  const boot = 'var data = null, ui = { variable: true, bsel: null, itemId: null, tab: "resumen" };\n' + prelude + '\n';
  // `const`/`let` de un solo contexto: se ejecutan juntos para que se vean entre sí
  const code = boot + ordered.map((c) => c.text).join('\n') + '\n;globalThis.__api = { ' + entry.join(', ') + ', setData(d){ data = d; }, getData(){ return data; }, setUi(u){ Object.assign(ui, u); } };';
  vm.runInContext(code, ctx, { filename: 'app.html (motor)' });
  return { api: ctx.__api, names: ordered.map((c) => c.name) };
}
export { byName };
