/* ---------- Estado ---------- */

/* ---------- Debug: perfiles por calificación ---------- */
const DBG = {
  S: { nick: 'Leo', first: 'Leonardo', last: 'Richarte', gender: 'm', k: 1, ki: 1, contrib: true },
  A: { nick: 'Romina', first: 'Romina', last: '', gender: 'f', k: 1.75, ki: 0.9, contrib: true },
  B: { nick: 'Mariana', first: 'Mariana', last: '', gender: 'f', k: 2, ki: 0.9, contrib: true },
  C: { nick: 'Carlos', first: 'Carlos', last: '', gender: 'm', k: 2.4, ki: 0.95, contrib: false },
  D: { nick: 'Declan', first: 'Declan', last: '', gender: 'm', k: 2.55, ki: 0.9, contrib: false },
  H: { nick: 'Valeria', first: 'Valeria', last: '', gender: 'f', k: 1.9, ki: 0.92, contrib: true, half: true },
  X: { nick: 'Yu Wei', first: 'Yu Wei', last: '', gender: 'n', fresh: true },
  F: { nick: 'Dean', first: 'Dean', last: '', gender: 'm', k: 3.4, ki: 0.95, contrib: false }
};
/* Perfiles de demostración en soles (todo se convierte a S/ al tipo de cambio de 3.7) */
function toSoles(o) {
  const fx = 3.7, n2 = (v) => { const x = (Number(v) || 0) * fx; return Math.abs(x) >= 100 ? Math.round(x) : Math.round(x * 100) / 100; };
  const usdAcc = (id) => { const a = o.accounts.find((x) => x.id === id) || (o.cards || []).find((x) => x.id === id) || o.accounts[0]; return !!a && a.cur === 'USD'; };
  (o.transactions || []).forEach((t) => { if (usdAcc(t.acc)) { t.amount = n2(t.amount); if (t.est != null) t.est = n2(t.est); } });
  ['expected_income', 'expected_expense', 'planned'].forEach((k) => (o[k] || []).forEach((e) => { if (usdAcc(e.acc)) e.amount = n2(e.amount); }));
  (o.savings || []).forEach((sv) => { if (sv.cur === 'USD') { sv.balance = n2(sv.balance); sv.goal = n2(sv.goal); sv.monthly = n2(sv.monthly); (sv.log || []).forEach((l) => { l.amount = n2(l.amount); }); } });
  (o.subs || []).forEach((x) => { if (x.cur === 'USD') x.amount = n2(x.amount); });
  (o.cards || []).forEach((c) => { if (c.cur === 'USD') { c.limit = n2(c.limit); c.balance = n2(c.balance); c.payment = n2(c.payment); } });
  (o.accounts || []).forEach((a) => { if (a.cur === 'USD') a.balance = n2(a.balance); });
  (o.history || []).forEach((h) => { h.income = n2(h.income); h.expense = n2(h.expense); });
  (o.recurring || []).forEach((r) => { r.amount = n2(r.amount); });
  Object.keys(o.budget || {}).forEach((k) => { o.budget[k] = n2(o.budget[k]); });
  [].concat(o.accounts || [], o.cards || [], o.subs || [], o.savings || []).forEach((x) => { x.cur = 'PEN'; });
  o.settings = Object.assign({}, o.settings, { currency: 'PEN', currency2: 'USD', fx: Number((1 / fx).toPrecision(4)), cushion: n2((o.settings || {}).cushion), variable_weekly: n2((o.settings || {}).variable_weekly) });
  return o;
}
function makeFresh(P) {
  const T = getToday(), off = (n) => iso(addDays(T, n)), o = clone(EMPTY);
  o.settings = Object.assign({}, o.settings, { first: P.first, last: P.last, nick: P.nick, gender: P.gender });
  o.accounts[0].balance = 1240;
  const rows = [[-9, 1420, 'Ingreso', 'Sueldo'], [-8, -45, 'Comida', 'Supermercado'], [-6, -60, 'Transporte', 'Gasolina'], [-4, -32.5, 'Comida', 'Almuerzo'], [-2, -18, 'Ocio', 'Cine'], [-1, -64, 'Comida', 'Supermercado']];
  o.transactions = rows.map((r, i) => ({ id: i + 1, date: off(r[0]), amount: r[1], category: r[2], note: r[3], acc: 'bank' }));
  o.budget = { Comida: 300, Transporte: 120, Ocio: 100 };
  return o;
}
function makeSampleG(g) {
  const P0 = DBG[g] || DBG.S, L = resolveLang(), pk = DEMO_PACK[L]; if (P0.fresh) return pk ? localizeDemo(makeFresh(P0), L) : toSoles(makeFresh(P0));
  const o = pk ? localizeDemo(makeSample(), L) : ((g === 'D' || g === 'F') ? makeSample() : toSoles(makeSample())), P = (pk && g === 'S') ? Object.assign({}, P0, pk.me) : P0, mk = iso(getToday()).slice(0, 7);
  o.settings = Object.assign({}, o.settings, { first: P.first, last: P.last, nick: P.nick, gender: P.gender });
  if (P.half) o.settings.forceHalf = true;
  o.transactions.forEach((t) => {
    if (t.date.slice(0, 7) !== mk || isPay(t)) return;
    if (t.amount < 0 && t.category !== 'Alquiler') t.amount = round2(t.amount * P.k);
    else if (t.amount > 0) t.amount = round2(t.amount * P.ki);
  });
  if (!P.contrib) o.savings.forEach((sv) => { sv.log = (sv.log || []).filter((l) => !l.date || l.date.slice(0, 7) !== mk); });
  return o;
}
/*__DEMOS__*/
const DEMO_LIST = [
  { id: 'shawn', name: 'Shawn', city: 'San Francisco, CA', age: 24, line: 'Sueldo por hora y vida social activa', color: '#22B573', icon: 'goblet-line' },
  { id: 'brenda', name: 'Brenda', city: 'Lima, PE', age: 21, line: 'De EE. UU. a la universidad', color: '#2EC4B6', icon: 'graduation-cap-line' },
  { id: 'alessandro', name: 'Alessandro', city: 'Lima, PE', age: 23, line: 'Primer empleo y vive con su familia', color: '#FF9F0A', icon: 'home-heart-line' },
  { id: 'andrea', name: 'Andrea', city: 'Lake Placid, NY', age: 52, line: 'Dueña de un hotel con mucho capital', color: '#8E6BD8', icon: 'hotel-line' },
  { id: 'kevin', name: 'Kevin', city: 'Lima, PE', age: 14, line: 'Ayuda en el taller de su papá y ahorra para una PS5', color: '#5B8DEF', icon: 'rocket-2-line' }
];
function rebaseProfile(d) {
  const a = pd(d.__anchor), t = getToday(), dd = Math.round((t - a) / 86400000), mm = (t.getFullYear() * 12 + t.getMonth()) - (a.getFullYear() * 12 + a.getMonth());
  delete d.__anchor; if (!dd) return d;
  const sh = (x) => (x ? iso(addDays(pd(x), dd)) : x);
  /* Movimientos: se mueven por meses completos (las notas de cada mes no cambian); el mes actual se corre unos días y lo futuro se descarta */
  const shm = (x) => { if (!x) return x; const p = pd(x), n = p.getFullYear() * 12 + p.getMonth() + mm, y = Math.floor(n / 12), mo = n % 12; return iso(new Date(y, mo, Math.min(p.getDate(), new Date(y, mo + 1, 0).getDate()))); };
  const tm = iso(t).slice(0, 7), dl = Math.max(0, t.getDate() - a.getDate()), tt = iso(t);
  const shx = (x) => { let r = shm(x); if (r && r.slice(0, 7) === tm && dl) r = iso(addDays(pd(r), dl)); return r; };
  const sn = new Set((d.subs || []).map((x) => String(x.name || '').toLowerCase()));   /* los cobros de una suscripción mantienen su día del mes (si no, el último mes parecería cobrado tarde) */
  d.transactions.forEach((x) => { x.date = x.note && sn.has(String(x.note).toLowerCase()) ? shm(x.date) : shx(x.date); });
  d.transactions = d.transactions.filter((x) => x.date <= tt);
  d.savings.forEach((s) => { (s.log || []).forEach((l) => { l.date = shx(l.date); }); if (s.log) s.log = s.log.filter((l) => l.date <= tt); });
  ['expected_income', 'expected_expense'].forEach((k) => d[k].forEach((e) => { e.date = sh(e.date); e.until = sh(e.until); if (isQ(e.repeat)) e.date = iso(qNext(t, e.repeat, true)); }));
  d.planned.forEach((p) => { p.date = sh(p.date); p.until = sh(p.until); });
  (d.budgetSets || []).forEach((b) => { b.from = shm(b.from); b.to = shm(b.to); });
  d.cards.forEach((c) => { if (c.auto) c.auto.next = sh(c.auto.next); });
  d.history.forEach((h) => { const q = h.month.split('-').map(Number), n = q[0] * 12 + (q[1] - 1) + mm; h.month = Math.floor(n / 12) + '-' + String(n % 12 + 1).padStart(2, '0'); });
  return d;
}
const STASH_KEY = 'plata.stash';
const demoHasReal = () => hasData() || ui.dirty > 0 || (data.accounts || []).length > 1 || (data.accounts || []).some((a) => +a.balance);
function demoEnter() { if (data && !data.demo && demoHasReal()) { try { localStorage.setItem(STASH_KEY, JSON.stringify({ data: data, dirty: ui.dirty, t: Date.now() })); } catch (e) { /* sin espacio: se reemplaza como antes */ } } }
function demoExit() {
  let st = null; try { st = JSON.parse(localStorage.getItem(STASH_KEY)); } catch (e) { /* sin copia */ }
  if (!(st && st.data)) wMark(false);
  data = migrate(clone(st && st.data ? st.data : EMPTY)); ui.dirty = st && st.data ? (st.dirty || 0) : 0; ui.week = 8; ui.calMonth = 0; ui.calSel = null;
  try { localStorage.removeItem(STASH_KEY); } catch (e) { /* sin almacenamiento */ }
  persist(); closeSheet(); leaveSettings(); renderAll(); document.querySelectorAll('.screen').forEach((sc) => { sc.scrollTop = 0; }); setTab('resumen');
  if (st && st.data) toast('Datos restaurados'); else showWelcome();
}
const syncAllowed = () => !(data && data.demo);
function loadDemo(id) {
  demoEnter();
  const src = DEMO_PROFILES[id]; if (!src) return;
  const keep = (data && data.settings && data.settings.lang) || '';
  data = migrate(rebaseProfile(clone(src))); data.demo = true; if (keep) data.settings.lang = keep;
  if (!data.firstHalf) data.firstHalf = '2000-01';
  ui.dirty = 0; ui.week = 8; ui.calMonth = 0; ui.calSel = null; ui.bsel = null; persist();
}
const demoCards = (act) => DEMO_LIST.map((p) => '<button class="wopt wdemo" data-act="' + act + ':' + p.id + '">' + tile(p.color, RMI(p.icon, 24, '#fff')) +
  '<span style="flex:1;min-width:0"><span class="dt"><b>' + p.name + '</b> <span class="dsub"><span>' + p.city + '</span><span class="age">' + p.age + '</span></span></span><span class="s dl">' + p.line + '</span></span>' + ICON.chev + '</button>').join('');
const demoSheetHTML = () => sheetHead('Perfiles de demostración', null, null) + '<div class="sub" style="font-size:14px;padding:0 8px 12px">Elige uno para ver Plata con datos de ejemplo.</div>' + demoCards('demopick');
function demoData(g) { const keep = (data && data.settings && data.settings.lang) || '', o = makeSampleG(g); if (keep) o.settings.lang = keep; return o; }
/* Marca de "archivo analizado" (transparencia): vive en varios sitios a la vez y se vuelve a sellar en cada carga */
const AN_ID = /^[0-9a-f]{8}$/, AN_AT = /^\d{4}-\d{2}-\d{2}$/, AN_LISTS = ['transactions', 'accounts', 'cards', 'subs', 'savings', 'jobs'];
function anRead(o) {
  if (!o || typeof o !== 'object') return null;
  let id = '', at = '';
  const take = (m) => { if (m && typeof m === 'object') { if (!id && AN_ID.test(String(m.id || ''))) id = m.id; if (!at && AN_AT.test(String(m.at || ''))) at = m.at; } };
  take(o.analysis); take(o.meta && o.meta.analysis); take(o.settings && o.settings.an);
  AN_LISTS.forEach((k) => { if (!id && Array.isArray(o[k])) { const r = o[k].find((x) => x && AN_ID.test(String(x.an || ''))); if (r) id = r.an; } });
  if (!id && !at) return null;
  if (!id) { let h = 5381; for (const ch of at) h = ((h * 33) ^ ch.charCodeAt(0)) >>> 0; id = ('00000000' + h.toString(16)).slice(-8); }
  return { id: id, at: at };
}
function anStamp(out, m) {
  if (!m) return;
  out.analysis = { v: 1, id: m.id, at: m.at };
  out.settings = out.settings || {}; out.settings.an = { id: m.id, at: m.at };
  AN_LISTS.forEach((k) => { if (Array.isArray(out[k])) out[k].forEach((x) => { if (x && typeof x === 'object') x.an = m.id; }); });
}
const anDate = (at) => { if (!AN_AT.test(at || '')) return ''; const d = pd(at); return d.getDate() + ' ' + MON[d.getMonth()] + ' ' + d.getFullYear(); };
function anNoteHTML(m, cls, part) {
  if (!m) return '';
  const l1 = '<div class="anl1">' + RMI('file-search-line', 15, 'currentColor') + '<span>Analizado</span> ' + (anDate(m.at) ? '<b>' + anDate(m.at) + '</b> ' : '') + '<span>por</span> <span class="annw"><b class="g">El equipo de Plata</b><i class="anv">' + RMI('verified-badge-fill', 16, 'currentColor') + '</i></span></div>',
    l2 = '<div>Una copia de este archivo fue analizada para entender cómo se usa Plata y mejorarla. <button type="button" class="anmore" data-act="transp">Conoce más…</button></div>';
  return '<div class="annote' + (cls ? ' ' + cls : '') + '">' + (part === 1 ? l1 : part === 2 ? l2 : l1 + l2) + '</div>';
}
function migrate(o) {
  try { let ls = null; try { ls = localStorage.getItem('plata.theme'); } catch (e) { /* sin almacenamiento */ } if (o && o.settings && /^(light|dark)$/.test(o.settings.theme) && !ls) window.__applyTheme(o.settings.theme); } catch (e) { /* sin tema */ }
  if (!o || typeof o !== 'object') throw new Error('formato');
  if (!Array.isArray(o.transactions) && !Array.isArray(o.cards) && !Array.isArray(o.accounts)) throw new Error('vacío');
  const old = !(o.version >= 3), D = old ? makeSample() : null;
  const pick = (k) => (Array.isArray(o[k]) ? o[k] : (old ? D[k] : []));
  const out = {
    version: 3,
    demo: o.demo === true,
    settings: Object.assign({ currency: 'USD', fx: 3.5, cushion: 300, variable_weekly: 230 }, o.settings || {}),
    accounts: Array.isArray(o.accounts) && o.accounts.length ? o.accounts : [{ id: 'bank', name: 'Cuenta principal', type: 'checking', cur: (o.settings && CURRENCIES[o.settings.currency]) ? o.settings.currency : 'USD', balance: 0 }],
    transactions: Array.isArray(o.transactions) ? o.transactions : [],
    history: Array.isArray(o.history) ? o.history : [],
    cards: Array.isArray(o.cards) ? o.cards : [],
    recurring: Array.isArray(o.recurring) ? o.recurring : [],
    subs: pick('subs'),
    savings: pick('savings'),
    budget: o.budget && typeof o.budget === 'object' ? o.budget : (old ? D.budget : {}),
    budgetSets: (Array.isArray(o.budgetSets) ? o.budgetSets : []).filter((b) => b && b.id && /^\d{4}-\d{2}-\d{2}$/.test(b.from || '') && /^\d{4}-\d{2}-\d{2}$/.test(b.to || '')).map((b) => ({ id: String(b.id), name: String(b.name || 'Set').slice(0, 40), from: b.from, to: b.to, cur: typeof b.cur === 'string' ? b.cur : '', budget: b.budget && typeof b.budget === 'object' ? b.budget : {}, mod: b.mod })),
    expected_income: Array.isArray(o.expected_income) ? o.expected_income : [],
    planned: Array.isArray(o.planned) ? o.planned : [],
    tomb: (Array.isArray(o.tomb) ? o.tomb : []).filter((x) => x && x.c && x.id != null && Number(x.t) > 0).map((x) => ({ c: String(x.c), id: String(x.id), t: Number(x.t) })),
    fmod: o.fmod && typeof o.fmod === 'object' && !Array.isArray(o.fmod) ? o.fmod : {},
    jobs: (Array.isArray(o.jobs) ? o.jobs : []).filter((j) => j && j.id),
    ovr: o.ovr && typeof o.ovr === 'object' && !Array.isArray(o.ovr) ? o.ovr : {},
    firstHalf: typeof o.firstHalf === 'string' ? o.firstHalf : '',
    halfSnaps: (() => { const out = {}, src = o.halfSnaps && typeof o.halfSnaps === 'object' ? o.halfSnaps : {}; Object.keys(src).forEach((k) => { const v = src[k]; if (v && v.letter) out[k] = { letter: String(v.letter), score: Number(v.score) || 0 }; }); if (o.halfSnap && o.halfSnap.mk && o.halfSnap.letter && !out[o.halfSnap.mk]) out[String(o.halfSnap.mk)] = { letter: String(o.halfSnap.letter), score: Number(o.halfSnap.score) || 0 }; return out; })()
  };
  delete out.settings.demo_today;
  anStamp(out, anRead(o));
  out.settings.customCur = regCustom(out.settings.customCur);
  if (old && out.accounts.length === 1) out.accounts.push(D.accounts[1]);
  if (old && !out.cards.some((c) => c.kind === 'loan')) out.cards.push(D.cards[3]);
  const st0 = out.settings, hasPEN = [].concat(out.accounts, out.cards, out.subs, out.savings).some((x) => x && x.cur === 'PEN');
  if (!CURRENCIES[st0.currency]) st0.currency = 'USD';
  if (st0.currency2 === undefined) st0.currency2 = hasPEN && st0.currency !== 'PEN' ? 'PEN' : '';
  if (!CURRENCIES[st0.currency2] || st0.currency2 === st0.currency) st0.currency2 = '';
  const okC = (c) => (c === st0.currency || (st0.currency2 && c === st0.currency2) ? c : st0.currency);
  out.accounts.forEach((a, i) => { a.id = a.id || 'a' + i; a.cur = okC(a.cur); a.type = a.type || 'checking'; });
  out.cards.forEach((c, i) => { c.id = c.id || 'c' + i; c.kind = c.kind || 'card'; c.cur = okC(c.cur); });
  out.subs.forEach((s, i) => { s.id = s.id || 's' + i; s.cur = okC(s.cur); });
  out.savings.forEach((s, i) => { s.id = s.id || 'v' + i; s.cur = okC(s.cur); });
  out.planned.forEach((p, i) => { p.id = p.id || 'p' + i; if (p.on == null) p.on = true; });
  out.expected_income = out.expected_income.map((e, i) => ({
    id: e.id || 'i' + i, name: e.name, amount: e.amount, acc: e.acc || out.accounts[0].id,
    date: e.date || e.next, repeat: e.repeat != null ? e.repeat : (e.every_days || 0), until: e.until || '', snooze: e.snooze, job: e.job || undefined, jstart: e.jstart || undefined, mod: e.mod
  }));
  out.expected_expense = (Array.isArray(o.expected_expense) ? o.expected_expense : (old ? D.expected_expense : [])).map((e, i) => ({
    id: e.id || 'x' + i, name: e.name, amount: Math.abs(e.amount || 0), acc: e.acc || out.accounts[0].id, date: e.date, repeat: e.repeat != null ? e.repeat : 0, until: e.until || '', cat: e.cat || 'Otros', snooze: e.snooze, card: e.card || undefined, mod: e.mod
  }));
  out.cats = (Array.isArray(o.cats) && o.cats.length ? o.cats : DEF_CATS).map((c) => ({ name: String(c.name), color: c.color || '#C9CBD1', icon: c.icon || '' }));
  if (!out.cats.some((c) => c.name === 'Otros')) out.cats.push({ name: 'Otros', color: '#C9CBD1', icon: '' });
  out.transactions.forEach((t, i) => { if (!t.id) t.id = 1000 + i; if (t.amount > 0 && t.category === 'Ingreso' && out.cards.some((c) => c.id === t.acc)) t.category = 'Pago de crédito'; });
  [out.accounts, out.cards, out.subs, out.savings, out.transactions, out.expected_income, out.expected_expense, out.planned, out.history].forEach((list) => list.forEach((o) => {
    ['balance', 'limit', 'payment', 'goal', 'monthly', 'amount', 'income', 'expense'].forEach((k) => { if (typeof o[k] === 'number') o[k] = clampAmt(o[k]); });
    (o.log || []).forEach((l) => { if (typeof l.amount === 'number') l.amount = clampAmt(l.amount); });
  }));
  Object.keys(out.budget).forEach((k) => { out.budget[k] = clampAmt(out.budget[k]); });
  out.budgetSets.forEach((b) => Object.keys(b.budget).forEach((k) => { b.budget[k] = clampAmt(b.budget[k]); }));
  ['cushion', 'variable_weekly'].forEach((k) => { if (typeof out.settings[k] === 'number') out.settings[k] = clampAmt(out.settings[k]); });
  if (old) { D.expected_income.forEach((e) => { if (!out.expected_income.some((x) => x.id === e.id) && e.id === 'proj') out.expected_income.push(e); }); }
  return safeProfile(out);
}
/* Seguridad: un archivo de perfil o una copia de la nube pueden venir de cualquier parte. Los campos que la app usa dentro de
 * atributos HTML o estilos (colores, iconos, últimos 4 dígitos) se reducen a su forma válida; el texto libre se escapa al mostrarlo. */
const SAFE_COLOR = /^#[0-9a-fA-F]{3,8}$/, SAFE_ICON = /^[a-z0-9-]{0,40}$/;
/* Identificadores (van dentro de data-act="…") y etiquetas (nombres de categoría y de cuentas, que la app usa también como claves):
 * se quitan los caracteres que permiten salir de un atributo o abrir una etiqueta HTML. Se aplica igual en todos lados, así las referencias
 * entre datos siguen coincidiendo. El texto libre (notas) no se toca: se escapa al mostrarlo. */
const SAFE_ID_KEYS = new Set(['id', 'acc', 'card', 'job', 'pair', 'from', 'to', 'srcId']), SAFE_LABEL_KEYS = new Set(['name', 'category', 'cat', 'nick', 'first', 'bank', 'brand', 'label', 'letter']);
const safeId = (x) => String(x).replace(/[^\w.:@+\-]/g, '').slice(0, 80), safeLabel = (x) => String(x).replace(/[<>"`]/g, '').slice(0, 120);
const safeKeys = (obj, f) => { const out = {}; Object.keys(obj).forEach((k) => { if (k !== '__proto__' && k !== 'constructor' && k !== 'prototype') out[f(k)] = obj[k]; }); return out; };
function safeProfile(o) {
  const seen = new Set();
  (function walk(v) {
    if (!v || typeof v !== 'object' || seen.has(v)) return; seen.add(v);
    if (Array.isArray(v)) { v.forEach(walk); return; }
    Object.keys(v).forEach((k) => {
      const x = v[k];
      if (k === '__proto__' || k === 'constructor' || k === 'prototype') { delete v[k]; return; }
      if (SAFE_ID_KEYS.has(k) && typeof x === 'string') { v[k] = safeId(x); return; }
      if (SAFE_LABEL_KEYS.has(k) && typeof x === 'string') { v[k] = safeLabel(x); return; }
      if (k === 'budget' && x && typeof x === 'object' && !Array.isArray(x)) { v[k] = safeKeys(x, safeLabel); return; }
      if ((k === 'ovr' || k === 'fmod') && x && typeof x === 'object' && !Array.isArray(x)) { v[k] = safeKeys(x, safeId); walk(v[k]); return; }
      if (/colou?r$/i.test(k) && x != null && typeof x !== 'object') { if (!SAFE_COLOR.test(String(x))) v[k] = '#8E8E93'; return; }
      if (k === 'icon' && x != null && typeof x !== 'object') { if (!SAFE_ICON.test(String(x))) v[k] = ''; return; }
      if (k === 'last4' && x != null && typeof x !== 'object') { v[k] = String(x).replace(/\D/g, '').slice(0, 4); return; }
      walk(x);
    });
  })(o);
  return o;
}
/* Preparación para sincronizar: fecha de edición (mod) por elemento y lápidas (tomb) de lo borrado. Todo se calcula en persist(), sin tocar cada punto de edición. */
const SYNC_COLS = ['accounts', 'cards', 'savings', 'subs', 'transactions', 'expected_income', 'expected_expense', 'planned', 'jobs', 'budgetSets'];
const SYNC_SIG = new WeakMap();
const syncSig = (it) => JSON.stringify(it, (k, v) => (k === 'mod' ? undefined : v));
function syncStamp() {
  const d = data; if (!d || typeof d !== 'object') return;
  const now = Date.now(), first = !SYNC_SIG.has(d), st = SYNC_SIG.get(d) || {}; SYNC_SIG.set(d, st);
  const horizon = now - 90 * 864e5; d.tomb = (Array.isArray(d.tomb) ? d.tomb : []).filter((x) => x && x.t > horizon);
  SYNC_COLS.forEach((col) => {
    const list = d[col]; if (!Array.isArray(list)) return;
    const prev = st[col] || (st[col] = new Map()), seen = new Set();
    list.forEach((it) => {
      if (!it || it.id == null) return; const id = String(it.id), sig = syncSig(it), old = prev.get(id); seen.add(id);
      if (old === undefined) { it.mod = it.mod || (first ? 0 : now); if (!first) d.tomb = d.tomb.filter((x) => !(x.c === col && String(x.id) === id)); }
      else if (old !== sig) it.mod = now;
      prev.set(id, syncSig(it));
    });
    prev.forEach((v, id) => { if (!seen.has(id)) { prev.delete(id); if (!first) d.tomb.push({ c: col, id: id, t: now }); } });
  });
  const fs = st.__f || (st.__f = {}); d.fmod = d.fmod && typeof d.fmod === 'object' ? d.fmod : {};
  MG_FIELDS.forEach((f) => { const s = JSON.stringify(d[f] === undefined ? null : d[f]); if (fs[f] !== undefined && fs[f] !== s) d.fmod[f] = now; fs[f] = s; });
}

/* Plata Cloud: lista de espera. Queda oculta hasta que se configure la dirección del servicio. */
const PC_LOGO = { vb: '0 0 881.8 308.35', d: [["g", "M802.1,11.85l5.2,22.9-39.6,16.8c1.6,2.5,3.1,4.9,4.7,7.5,3.6,1,7.1,2.2,10.7,3.5l27.2-11.6.5-.2h0l6.3,27.3,64.7-68.3-79.9,2.4h0l.2-.3Z"], ["g", "M483.9,172.05l-33.8,14.4,6.6-40.2-14.6,84.3h.6l3.9-23.7,33.6-14.4c.8-6.8,2-13.6,3.6-20.4h.1,0Z"], ["g", "M428.1,128.95l-2.9,17.4h-.7c-4.4-20.7-30.3-22.9-46.6-13.1-27,14.2-41.3,68.2-18.3,90.8l-35.9,14.9,2.2-12.8,15.1-87.9h17.3l3.8-23.5h-17.1l4.1-23.8h-32.8l-4.1,23.8h-13.4l-3.8,23.5h13.2l-9,52.3-23.8,11,9.5-57.8h-31.5l-2.9,17.4h-.7c-4.4-20.7-30.3-22.9-46.5-13.1-27.8,14.4-43.2,73.9-14.5,93.7l-33.8,15.6,2-12.2,22.5-135.3h-31.7c-4.6,28.1-14.2,85.3-18.7,112.9l-94.6,44,9.2-44.4c15.2-.1,37,1.5,50.3-5.8,23.7-10.2,37.1-41.2,28.2-65-6.7-15.9-21.7-22.4-39.7-22.4H27.1L0,308.35l124.4-57.4-8.3,50.1,133.8-61.7-1.5,5.7h19.7l2.5-15.2,23.6-10.9-1.2,7c-1.2,6.4-8.6,50.5-9.5,55.6.8-.4,128.3-59,129.2-59.4l-1.4,8.2h30.6l14.6-84.3,2.8-17.2h-31.5.1l.2.1ZM54.9,155.25c16.4,0,39.8-3.1,36.1,20.8-4.1,22.9-24.4,21.4-42.9,21l6.9-41.8h-.1ZM245.8,194.45c-1.5,9.7-5.2,18.6-12.7,24-19,11.1-29.4-5.2-25.4-24,1.6-9.5,5.2-18.6,12.6-23.9,18.8-10.9,29.7,4.9,25.5,23.9h0ZM420.3,179.65h0c-1.5,9.7-5.2,18.6-12.7,24-19,11.1-29.4-5.2-25.4-24,1.6-9.5,5.2-18.6,12.6-23.9,18.9-10.9,29.7,4.9,25.5,23.9h0Z"], ["k", "M539.6,200.65c-.7,2.2-1.8,4.1-3,5.9s-2.7,3.3-4.4,4.5c-1.7,1.3-3.5,2.2-5.5,2.8s-4,1-6.2,1-5.5-.6-7.5-2-3.4-3.3-4.3-5.7-1.4-5.2-1.4-8.5.4-7.1,1.4-11c.9-3.9,2.3-7.3,4.3-10.7,1.9-3.3,4.4-6,7.3-8.1,3-2.1,6.5-3,10.5-3s3.8.3,5.2.9c1.5.6,2.7,1.5,3.7,2.6s1.7,2.6,2.2,4.2.8,3.5.9,5.6l20.5-3.5c0-4.1-.9-7.9-2.5-11.1-1.6-3.3-3.8-6.1-6.6-8.5s-6.2-4.1-10.2-5.4c-3.9-1.3-8.3-1.9-13.1-1.9-7.5,0-14,1.4-19.6,4.1-5.7,2.7-10.4,6.5-14.3,11.1-3.9,4.6-6.7,10-8.7,15.8s-2.9,11.9-2.9,18,1.4,12.7,4.1,17.7,6.6,9,11.8,11.8c5,2.8,11.2,4.2,18.4,4.2s9.2-.6,13.4-1.9,7.9-3,11.2-5.5,6.3-5.2,8.7-8.5c2.4-3.4,4.4-7.1,5.9-11.3l-19.4-4h.1v.4Z"], ["k", "M575.3,123.25 L557.5,230.25 L579.1,230.25 L596.9,123.25 L575.3,123.25Z"], ["k", "M652.2,153.15c-5.1-2.7-11.2-4.1-18.4-4.1s-13.6,1.4-19.2,4c-5.7,2.7-10.4,6.3-14.3,11-3.9,4.6-6.9,9.9-8.9,15.8-2.1,5.9-3,12.1-3,18.6s1.4,12.6,4,17.6c2.7,5,6.6,8.9,11.6,11.8s11.2,4.2,18.6,4.2,13.5-1.4,19.1-4,10.4-6.3,14.4-10.9c3.9-4.6,6.9-9.9,8.9-15.8,2-5.9,3-12.1,3-18.6s-1.4-12.7-4-17.7-6.6-8.9-11.6-11.8h-.2v-.1ZM644.9,192.65c-.9,3.8-2.3,7.3-4.2,10.8-1.9,3.4-4.3,6.1-7.1,8.3-2.9,2.2-6.4,3.3-10.4,3.3s-7.8-1.5-10-4.4-3.3-6.8-3.3-11.6.4-7,1.4-10.8c.9-3.8,2.3-7.3,4.2-10.7s4.3-6.1,7.1-8.2c2.9-2.1,6.4-3.1,10.4-3.1s5.5.6,7.3,2,3.5,3.3,4.4,5.6c.9,2.4,1.5,5.1,1.5,8.4s-.4,6.8-1.4,10.7h0l.1-.3Z"], ["k", "M728.9,150.05l-7.7,46.5c-1.3,9.5-8.7,16.9-18.4,16.8-9.7,0-13.5-6.6-12-15.9l7.9-47.3h-21.5l-8.5,51.1c-1.7,10.8,0,20.8,8.8,26.7,14.8,9.2,38.6.3,42.3-17.4h1.3c-2.1,1.9-3.7,17.3-4.2,20h20.4l13.3-80.3h-21.7v-.2Z"], ["k", "M832.1,142.15c-7-100-159.8-110.5-191.5-18.8-4.2,11.5,11.1,11.6,17.5,6.7,7.1-5.8,9.9-15.4,16.5-21.9,45.1-55.4,154.6-19.9,132.7,56h-.7c-3.7-16.3-25.5-18.8-38-10.8-15.4,9.3-22.4,28.9-22.5,46.3-2.6,31.5,36.7,44.3,51.7,17.7h1.2l-2.3,12.8h21.2l14.2-88.1h0v.1ZM802.8,193.15c-2.1,13.6-19.6,29.4-31.5,16.9-7.2-12.1-1.5-32.6,9.9-40.8,18.6-10.6,27,7.2,21.6,23.9h0Z"], ["k", "M586,41.65c47.1-64.6,148.7-51.6,177.4,22,4.2,11.5-11.1,11.5-17.5,6.7-3.6-2.4-5.6-6.3-7.8-9.9-2.5-4.2-5.5-8.3-8.7-12-12.1-13.9-28.9-23.2-47-26.2-33.1-6.1-68.1,10.9-83.6,39.2-2.2,3.8-3.9,7.7-4.5,11.9-.6,3.6-.4,7.3-.6,10.5,0,7.3-6.3,10-12.6,8.5-8.9-1.9-10.2-10.7-9.2-19.1,1.3-11.6,7.7-22.1,14.2-31.5h.1c0-.1-.1-.2-.1-.2l-.1.1Z"], ["k", "M522.9,62.05h-.2c-10.2,5.2-20.8,11.4-27.5,21.1-4.7,6.9-7.9,15.3-.9,21.2,4.8,4.3,11.8,5,15.2-1.5,1.7-2.6,3.3-6.1,5.6-8.9,2.6-3.5,5.9-6.1,9.7-8.3,13.5-8.7,29.9-12.6,46.3-11.8l11-20.4c-19.1-3-39.6-.6-59.1,8.6h-.1Z"]] };
const pcLogo = (h) => '<svg viewBox="' + PC_LOGO.vb + '" role="img" aria-label="Plata Cloud" style="height:' + h + 'px;width:auto;display:block">' + PC_LOGO.d.map((x) => '<path ' + (x[0] === 'k' ? 'style="fill:var(--ink)"' : 'fill="#22B573"') + ' d="' + x[1] + '"/>').join('') + '</svg>';
const PLATA_CLOUD_API = 'https://plata-cloud.xleoricharte.workers.dev';
/* Precios de Plata Cloud: base US$3.99 (S/11.90 en Perú); early supporters, 30% menos. Primer mes gratis (marcha blanca), por invitación. */
const clPE = () => { try { return /Lima/.test(Intl.DateTimeFormat().resolvedOptions().timeZone || ''); } catch (e) { return false; } };
const CL_BASE = 3.99, CL_BASE_PEN = 11.90, CL_OFF = 0.3;
const clPr = () => { const pe = clPE(), b = pe ? CL_BASE_PEN : CL_BASE, e = Math.round(b * (1 - CL_OFF) * 100) / 100, f = (n) => (pe ? 'S/' : '$') + n.toFixed(2); return { base: f(b), early: f(e), zero: pe ? 'S/0' : '$0' }; };
function clPriceHTML(full) {
  const q = clPr();
  return '<div class="clpq"><s>' + q.early + '</s><b>' + q.zero + '</b><span>primer mes · por invitación</span></div>' +
    (full ? '<div class="clpn"><span>Early supporter · 30% menos</span> <b>' + q.early + '</b> <span>al mes, después del primer mes</span><br><span>Precio base</span> ' + q.base + ' <span>al mes</span><br><span>El precio early supporter dura un año y puede renovarse.</span> <a class="clk" href="https://plataapp.net/#legal" target="_blank" rel="noopener">Aplican términos y condiciones</a></div>' : '');
}
const cloudJoined = () => { try { return !!localStorage.getItem('plata.cloudwl'); } catch (e) { return false; } };
const PC_CLOUDS = (() => { const c = (st) => '<svg class="pcc" style="' + st + '" viewBox="0 0 345 132" fill="#1A9D63" aria-hidden="true"><path d="M323.63,127.14c10.47,7.46,19.56.98,14.79-11.82-29.64-74.62-155.95-75.59-187.82,1.44-3.14,8.46-.35,17.71,9.66,14.18,6-2.35,10.17-7.16,14.46-12.45,2.85-3.58,5.68-7.3,8.83-10.77,34.81-40.88,106.88-32.04,131.89,10.92,2.42,3.25,5.01,6.23,8.04,8.39l.14.1Z"/><path d="M95.77,41.65c47.1-64.6,148.7-51.6,177.4,22,4.2,11.5-11.1,11.5-17.5,6.7-3.6-2.4-5.6-6.3-7.8-9.9-2.5-4.2-5.5-8.3-8.7-12-12.1-13.9-28.9-23.2-47-26.2-33.1-6.1-68.1,10.9-83.6,39.2-2.2,3.8-3.9,7.7-4.5,11.9-.6,3.6-.4,7.3-.6,10.5,0,7.3-6.3,10-12.6,8.5-8.9-1.9-10.2-10.7-9.2-19.1,1.3-11.6,7.7-22.1,14.2-31.5h.1c0-.1-.1-.2-.1-.2l-.1.1Z"/><path d="M32.67,62.05h-.2c-10.2,5.2-20.8,11.4-27.5,21.1-4.7,6.9-7.9,15.3-.9,21.2,4.8,4.3,11.8,5,15.2-1.5,1.7-2.6,3.3-6.1,5.6-8.9,2.6-3.5,5.9-6.1,9.7-8.3,13.5-8.7,29.9-12.6,46.3-11.8l11-20.4c-19.1-3-39.6-.6-59.1,8.6h-.1Z"/></svg>'; return c('width:84px;right:-14px;top:-6px;opacity:.16') + c('width:56px;right:72px;bottom:-8px;opacity:.11') + c('width:46px;left:46%;top:-9px;opacity:.09'); })();
const cloudStripOff = () => { try { return !!localStorage.getItem('plata.cloudstrip') || (clBeta() && clIn()); } catch (e) { return false; } };
function cloudStripHTML() { return clLinkHTML() + clGoneHTML() + cloudStripHTML0(); }
function cloudStripHTML0() {
  if (!PLATA_CLOUD_API || cloudJoined() || cloudStripOff()) return '';
  return '<div class="cstrip cloudw" id="cloudStrip" data-cloud="1">' + PC_CLOUDS + '<span class="ct">Plata Cloud: marcha blanca gratis un mes<a class="cl cm" href="https://plataapp.net/cloud" target="_blank" rel="noopener">Conocer más ›</a></span>' +
    '<button class="cb cm" data-act="cl:open">Entrar</button><a class="cb cd" href="https://plataapp.net/cloud" target="_blank" rel="noopener">Conocer más</a>' +
    '<button class="cx" data-act="cloudstripx" aria-label="Cerrar">×</button>' +
    '</div>';
}
function renderWebCloud() { const w = $('#webcloud'); if (w) w.innerHTML = cloudStripHTML().replace('id="cloudStrip"', 'id="cloudStripTop"'); }
function cloudCardHTML() {
  if (!PLATA_CLOUD_API) return '';
  const body = cloudJoined()
    ? '<div class="sub" style="font-size:14px">Estás en la lista. Te avisaremos cuando abramos cupos.</div>'
    : '<div class="sub" style="font-size:14px;margin-bottom:10px">Sincroniza tus datos entre dispositivos, cifrados. Apúntate a la marcha blanca gratuita de un mes.</div>' +
      '<div class="row" style="border:0;padding:0;gap:8px;flex-wrap:nowrap"><input class="sinput" id="sCloudMail" type="email" inputmode="email" autocomplete="email" placeholder="correo@ejemplo.com" style="flex:1;min-width:0;border:0;border-radius:12px;padding:12px 12px;font:inherit;font-size:16px;background:var(--fill,rgba(120,120,128,.14));color:var(--ink)"><button class="execbtn" data-act="cloudjoin">Unirme a la lista</button></div>' +
      '<div class="sub" style="font-size:12px;margin-top:8px">Usaremos tu correo solo para invitarte a Plata Cloud. <a class="clk" href="https://plataapp.net/cloud" target="_blank" rel="noopener">Conocer más ›</a></div>';
  return '<div class="scard cloudw" id="cloudCard" data-cloud="1" style="padding:14px 16px">' + PC_CLOUDS + '<div class="crow">' + pcLogo(40) + '<span class="cpill">Volando en Beta 5</span></div>' + body + '</div>';
}
function wclHTML() {
  return pcLogo(34) + '<h3>Tus datos, en todos tus dispositivos</h3><p class="wclp">Plata Cloud sincroniza tu información entre tu teléfono y tu computadora, sin dejar de ser tuya.</p>' +
    '<div class="wcli"><i>1</i><span>Cifrado de extremo a extremo: solo tú puedes leer tus datos.</span></div>' +
    '<div class="wcli"><i>2</i><span>Sin contraseñas: entras con un código que te llega al correo.</span></div>' +
    '<div class="wcli"><i>3</i><span>Marcha blanca gratuita de un mes, por invitación. Si aún no tienes, entras a la lista de espera.</span></div>' + clPriceHTML(true) +
    '<button class="execbtn" data-act="wclgo">Crear cuenta o entrar</button>' +
    '<button class="wclx" data-act="wclclose">' + 'Ahora no' + '</button>';
}
function wclOpen() {
  const w = $('#welcome'); if (!w || $('#wcl')) return;
  const bk = document.createElement('div'); bk.id = 'wcl'; bk.setAttribute('data-act', 'wclclose');
  bk.innerHTML = '<div class="wclc cloudw" data-cloud="1" data-act="wclstay">' + PC_CLOUDS + '<div>' + wclHTML() + '</div></div>';
  w.appendChild(bk); requestAnimationFrame(() => { bk.style.opacity = '1'; });
}
function wclRefresh() { const c = document.querySelector('#wcl .wclc > div'); if (c) c.innerHTML = wclHTML(); const b = document.querySelector('.wcloud .cpill'); if (b) b.textContent = clIn() ? 'Con sesión' : 'Crear cuenta o entrar'; }
function wclClose() { const b = $('#wcl'); if (b) { b.style.opacity = '0'; setTimeout(() => b.remove(), 200); } }
async function cloudJoin(el) {
  const box = el && el.closest && el.closest('[data-cloud]'), i = box ? box.querySelector('input') : $('#sCloudMail'), mail = ((i && i.value) || '').trim();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(mail)) { toast('Escribe un correo válido'); return; }
  const b = el || document.querySelector('[data-act="cloudjoin"]'); if (b) b.disabled = true;
  try {
    const r = await fetch(PLATA_CLOUD_API + '/waitlist', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: mail, src: 'app', lang: String(resolveLang() || 'es').slice(0, 2), plat: syncDevice().plat, website: '' }) });
    if (r.status === 429) { toast('Demasiados intentos. Prueba en una hora.'); if (b) b.disabled = false; return; }
    if (!r.ok) throw new Error('http');
    try { localStorage.setItem('plata.cloudwl', '1'); } catch (e) { /* sin almacenamiento */ }
    const c = $('#cloudCard'); if (c) c.outerHTML = cloudCardHTML();
    document.querySelectorAll('.cstrip').forEach((x) => x.remove());
    toast('Estás en la lista.'); wclRefresh();
  } catch (e) { toast('No pudimos conectar. Inténtalo más tarde.'); if (b) b.disabled = false; }
}
function syncDevice() {
  let id = ''; try { id = localStorage.getItem('plata.dev') || ''; if (!id) { id = 'd' + Math.random().toString(36).slice(2, 10); localStorage.setItem('plata.dev', id); } } catch (e) { /* sin almacenamiento */ }
  const ua = navigator.userAgent || '', web = document.documentElement.classList.contains('web');
  const os = /iPhone|iPad|iPod/.test(ua) ? 'iPhone' : /Android/.test(ua) ? 'Android' : /Mac/.test(ua) ? 'Mac' : /Windows/.test(ua) ? 'Windows' : /Linux/.test(ua) ? 'Linux' : 'Dispositivo';
  return { id: id, plat: os + (web ? ' · escritorio' : ' · móvil') };
}
