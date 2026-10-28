// Genera los vectores de prueba de Nazca (PDF) para PlataCore ejecutando el código REAL de la web (pdf.js + los lectores de banco) sobre los PDF de dev/tests/pdf.
// Escribe Fixtures/nazca_pdf.json (los textos con su posición que ve pdf.js, y lo que leen los lectores) y copia los PDF a Fixtures/pdf/.
// Uso: node swift/tools/gen-nazca-pdf.mjs
import { createRequire } from 'node:module';
import { readFileSync, writeFileSync, mkdirSync, readdirSync, copyFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url)), root = join(here, '..', '..');
const require = createRequire(import.meta.url);
const P = require(join(root, 'dev/app/src/core/nazca/pdf.js'));
const B = require(join(root, 'dev/app/src/core/nazca/bancos/index.js'));
const G = require(join(root, 'dev/app/src/core/nazca/pdf-generico.js'));
const warn = console.warn; console.warn = (...a) => { if (!/canvas|DOMMatrix|Path2D|polyfill/i.test(String(a[0]))) warn(...a); };
const lib = await P.load(pathToFileURL(join(root, 'dev/vendor/pdfjs') + '/').href);
const src = join(root, 'dev/tests/pdf'), fx = join(here, '..', 'PlataCore/Tests/PlataCoreTests/Fixtures');
mkdirSync(join(fx, 'pdf'), { recursive: true });
const KEYS = { 'bcp-ahorros-clave.pdf': '12345678', 'io-tarjeta-clave.pdf': '12345678' };
const num = (v) => (typeof v === 'number' && isFinite(v) ? v : null);

function simple(r) {
  if (!r) return null;
  const c = r.check;
  return { bank: r.bank, kind: r.kind, label: r.label, cur: r.cur, last4: (r.account && r.account.last4) || '', error: r.error || null,
    period: r.period ? { from: r.period.from, to: r.period.to } : null,
    items: (r.items || []).map((i) => ({ line: i.line, date: i.date, desc: i.desc, amount: i.amount, cur: i.cur || '', balance: num(i.balance) })),
    skipped: { unreadable: (r.skipped && r.skipped.unreadable) || 0, zero: (r.skipped && r.skipped.zero) || 0 },
    check: c ? { ok: c.ok === undefined ? null : c.ok, end: num(c.end) } : null,
    card: r.card ? { limit: num(r.card.limit), apr: num(r.card.apr), minPayment: num(r.card.minPayment), dueDay: num(r.card.dueDay), dueDate: r.card.dueDate || null } : null };
}

const docs = [];
for (const name of readdirSync(src).filter((f) => f.endsWith('.pdf')).sort()) {
  copyFileSync(join(src, name), join(fx, 'pdf', name));
  const bytes = readFileSync(join(src, name));
  const e = { name, key: KEYS[name] || null };
  let doc = null;
  try { doc = await P.read(bytes, lib, e.key || undefined); } catch (x) { e.error = x.code || 'invalid'; }
  if (doc) {
    e.pages = doc.pages.map((p) => ({ w: p.w, h: p.h, items: p.items.map((i) => [i.str, i.x, i.y, i.w]) }));
    e.total = doc.total; e.truncated = !!doc.truncated;
    const hit = B.READERS.filter((r) => r.detect(doc) >= 1).map((r) => r.id);
    e.detects = hit;
    const rd = B.detect(doc, null);
    e.reader = rd ? rd.id : null;
    e.read = rd ? simple(rd.read(doc)) : null;
    let g = null; try { g = G.read(doc); } catch (x) { g = null; }
    e.gen = g ? { text: g.text, count: g.count, cur: g.cur, name: g.name, isCard: g.isCard, last4: g.last4,
      card: { limit: num(g.card.limit), apr: num(g.card.apr), minPayment: num(g.card.minPayment), dueDay: num(g.card.dueDay), dueDate: g.card.dueDate || null } } : null;
  }
  docs.push(e);
}
const names = ['', 'prueba-capital-one.csv', 'estado_bcp_octubre.pdf', 'Mi Banco 2026.csv', 'IMG_2031.pdf', 'whatsapp-doc.pdf', 'tarjeta visa copia.csv'];
const fromFile = names.map((n) => ({ v: n, out: G.nameFromFile(n) }));
writeFileSync(join(fx, 'nazca_pdf.json'), JSON.stringify({ docs, fromFile }));
console.log('Listo:', docs.length, 'PDF,', docs.filter((d) => d.read).length, 'leídos por un banco,', docs.filter((d) => d.gen && d.gen.count).length, 'con lectura genérica.');
