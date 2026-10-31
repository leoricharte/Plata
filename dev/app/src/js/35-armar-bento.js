/* ---------- Armar Bento: tablero 16:9 de widgets (solo escritorio) ---------- */
const BENTO_KEY = 'plata.bento';
function bsorted(W) { return W.sizes.slice().sort((x, y) => BSZ[x][0] * BSZ[x][1] - BSZ[y][0] * BSZ[y][1]); }
const BW_ACTS = ['bnnop', 'bundo', 'bredo', 'bnplus', 'bnpick', 'bncolor', 'bnpreset', 'bnset', 'bndelset', 'bnopen', 'bnclose', 'bngal', 'bnreset', 'bndel', 'bnadd', 'bnsize', 'bnmove', 'bnnav', 'bnedit', 'bnview', 'bnshot'];
const BSZ = { S: [1, 1], M: [2, 1], T: [1, 2], L: [2, 2], W: [4, 1], V: [1, 3] };
const BENTO_PRE = [
  { id: 'mes', n: 'Mi mes', tag: 'predeterminado', d: 'Resumen, categorías, flujo y gasto acumulado. Directo al grano.', ic: 'dashboard-line', items: [['kpi', 'W'], ['cats', 'T'], ['flow', 'M'], ['daily', 'M'], ['monthtx', 'T']] },
  { id: 'deu', n: 'Presupuesto y deuda', d: 'Este se enfoca más en los límites. Para poder atacar los gastos en donde más fácil es.', ic: 'wallet-3-line', items: [['kpi', 'W'], ['budget', 'T'], ['debt', 'T'], ['upcoming', 'T'], ['top', 'T']] },
  { id: 'per', n: 'Perfil y evaluación', d: '¿Vas a flexear tus progresos de Plata? Este es para ti. No flexearía nada que fuese A o menos de todas maneras.', ic: 'user-smile-line', items: [['profile', 'M'], ['score', 'S'], ['rate', 'S'], ['insight', 'W'], ['weekday', 'M'], ['upcoming', 'M']] },
  { id: 'graf', n: 'Gráficos', d: 'Guaaaau que bonitoooos.', ic: 'bar-chart-grouped-line', items: [['cats', 'L'], ['flow', 'M'], ['daily', 'M'], ['weekday', 'M'], ['rate', 'S'], ['score', 'S']] },
  { id: 'cifr', n: 'Cifras', d: 'Sobresaturación de información lista a tu disposición.', ic: 'percent-line', items: [['kpi', 'W'], ['name', 'M'], ['score', 'S'], ['rate', 'S'], ['top', 'M'], ['upcoming', 'M']] },
  { id: 'todo', n: 'Todo a la vista', d: 'Vista de halcón.', ic: 'layout-grid-line', items: [['cats', 'S'], ['top', 'S'], ['subs', 'S'], ['debt', 'S'], ['goals', 'S'], ['weekday', 'S'], ['rate', 'S'], ['score', 'S'], ['insight', 'S'], ['profile', 'S'], ['flow', 'M']] },
  { id: 'vac', n: 'Vacío', d: 'Ya está bien, ya entendí, tú quieres hacerlo por tu cuenta.', ic: 'add-line', items: [], empty: true }
];
const BENTO_DEF = [{ id: 'kpi', s: 'W' }, { id: 'cats', s: 'T' }, { id: 'flow', s: 'M' }, { id: 'daily', s: 'M' }, { id: 'top', s: 'T' }];
const isWebView = () => document.documentElement.classList.contains('web');
function bentoLoad() { try { const j = JSON.parse(localStorage.getItem(BENTO_KEY)); if (Array.isArray(j) && j.length) { const k = j.filter((x) => BW[x.id] && BSZ[x.s]); if (k.length) return k; } } catch (e) { /* sin almacenamiento */ } return BENTO_DEF.map((x) => Object.assign({}, x)); }
const BENTOS_KEY = 'plata.bentos';
function bkey() {
  const st = (data && data.settings) || {}, id = [st.first, st.last, st.nick].map((x) => String(x || '').trim().toLowerCase()).join('|').replace(/[^a-z0-9|ñáéíóú]/g, '');
  return id.replace(/\|/g, '') ? BENTOS_KEY + '.' + id : BENTOS_KEY;
}
function bIsDemo() { const st = (data && data.settings) || {}; return DEMO_LIST.some((p) => String(p.name).toLowerCase() === String(st.nick || st.first || '').trim().toLowerCase()); }
const bcur = () => ui.bset && ui.bset.sets.find((x) => x.id === ui.bset.cur);
function bentoBase() { const st = data.settings || {}, n = String(st.nick || st.first || '').trim(); return n ? 'Bento de ' + n : 'Bento'; }
function bentoUnique(name, ex) {
  const nm = (name || '').trim() || bentoBase(), low = ui.bset.sets.filter((x) => x.id !== ex).map((x) => String(x.name).toLowerCase());
  if (low.indexOf(nm.toLowerCase()) < 0) return nm;
  const root = nm.replace(/ \d+$/, ''); let k = 2; while (low.indexOf((root + ' ' + k).toLowerCase()) >= 0) k++; return root + ' ' + k;
}
function bentoLoadAll() {
  let st = null; try { st = JSON.parse(localStorage.getItem(bkey())); if (!st && bkey() !== BENTOS_KEY && !bIsDemo()) { st = JSON.parse(localStorage.getItem(BENTOS_KEY)); if (st) { localStorage.setItem(bkey(), JSON.stringify(st)); localStorage.removeItem(BENTOS_KEY); } } } catch (e) { /* sin almacenamiento */ }
  if (!st || !Array.isArray(st.sets) || !st.sets.length) st = { sets: [{ id: 'b1', name: '', items: bentoLoad() }], cur: 'b1' };
  st.sets.forEach((x) => { x.items = (x.items || []).filter((i) => BW[i.id] && BSZ[i.s]); });
  if (!st.sets.some((x) => x.id === st.cur)) st.cur = st.sets[0].id;
  ui.bset = st; st.sets.forEach((x) => { if (!String(x.name || '').trim()) x.name = bentoUnique(bentoBase(), x.id); });
  ui.bento = bcur().items;
}
function bentoSave() { const c = bcur(); if (c) c.items = ui.bento; try { localStorage.setItem(bkey(), JSON.stringify(ui.bset)); } catch (e) { /* sin almacenamiento */ } }
function bentoLayout(items) {
  const occ = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]], res = new Array(items.length);
  const free = (x, y, w, h) => { if (x < 0 || y < 0 || x + w > 4 || y + h > 3) return false; for (let b = 0; b < h; b++) for (let a = 0; a < w; a++) if (occ[y + b][x + a]) return false; return true; };
  const put = (k, x, y) => { const w = BSZ[items[k].s][0], h = BSZ[items[k].s][1]; for (let b = 0; b < h; b++) for (let a = 0; a < w; a++) occ[y + b][x + a] = 1; res[k] = Object.assign({}, items[k], { x: x, y: y, w: w, h: h }); };
  items.forEach((it, k) => { if (it.px != null && it.py != null && free(it.px, it.py, BSZ[it.s][0], BSZ[it.s][1])) put(k, it.px, it.py); });
  items.forEach((it, k) => {
    if (res[k]) return; const w = BSZ[it.s][0], h = BSZ[it.s][1]; let pos = null;
    for (let y = 0; y <= 3 - h && !pos; y++) for (let x = 0; x <= 4 - w && !pos; x++) if (free(x, y, w, h)) pos = { x: x, y: y };
    if (pos) put(k, pos.x, pos.y); else res[k] = Object.assign({}, it, { off: true });
  });
  return res;
}
const bfits = (items) => bentoLayout(items).every((x) => !x.off);
const bbar = (pct, col) => '<div class="bbar"><i style="width:' + Math.max(0, Math.min(100, pct)) + '%;background:' + col + '"></i></div>';
const bemp = (t) => '<div class="bemp">' + t + '</div>';
const bcap = (h) => (h >= 2 ? 9 : 4);
function bvb(w, h, ex) {
  const wr = document.querySelector('.bwrap'), cw = wr ? wr.clientWidth : 1400, ch = wr ? wr.clientHeight : 800;
  const B = Math.min(cw, (ch - 30) * 16 / 9), fs = Math.max(10, Math.min(18, B * 0.0105));
  const cellW = (B - 42) / 4, cellH = (B * 9 / 16 - 28) / 3;
  return [Math.max(120, Math.round(cellW * w + (w - 1) * 14 - B * 0.032)), Math.max(60, Math.round(cellH * h + (h - 1) * 14 - B * 0.028 - fs * 2 - (ex || 0) * fs)), fs];
}
const bgd = (id, c) => '<linearGradient id="' + id + '" x1="0" y1="0" x2="0" y2="1"><stop offset="0" style="stop-color:color-mix(in srgb,' + c + ',#fff 26%)"/><stop offset="1" style="stop-color:color-mix(in srgb,' + c + ',#000 36%)"/></linearGradient>';
const BGDEFS = '<defs>' + bgd('bgG', '#22B573') + bgd('bgI', 'var(--ink)') + '<linearGradient id="bgA" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#22B573" stop-opacity=".42"/><stop offset="1" stop-color="#22B573" stop-opacity=".02"/></linearGradient></defs>';
function bDonut(items, total, label) {
  const C = 2 * Math.PI * 38; let off = 0; const dd = items.map((k) => bgd('bgd' + String(k.color).replace(/[^0-9a-fA-F]/g, ''), k.color)).join('');
  const arcs = total > 0 ? items.map((k) => { const f = k.v / total, len = Math.max(0, f * C - 1.4), o = '<circle cx="50" cy="50" r="38" fill="none" stroke="url(#bgd' + String(k.color).replace(/[^0-9a-fA-F]/g, '') + ')" stroke-width="14" stroke-dasharray="' + len.toFixed(2) + ' ' + (C - len).toFixed(2) + '" stroke-dashoffset="' + (-off).toFixed(2) + '" transform="rotate(-90 50 50)"/>'; off += f * C; return o; }).join('') : '';
  return '<svg class="dsvg" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid meet"><defs>' + dd + '</defs><circle cx="50" cy="50" r="38" fill="none" stroke="var(--track)" stroke-width="14"/>' + arcs + '<text x="50" y="47" text-anchor="middle" font-size="6.5" style="fill:var(--mute)">' + label + '</text><defs><linearGradient id="egx" x1="0" x2="0" y1="0" y2="1"><stop offset="0" class="es0"/><stop offset=".55" class="es1"/><stop offset="1" class="es2"/></linearGradient><linearGradient id="dgx" x1="0" x2="0" y1="0" y2="1"><stop offset="0" class="gs0"/><stop offset=".55" class="gs1"/><stop offset="1" class="gs2"/></linearGradient></defs><text x="50" y="60" text-anchor="middle" font-size="13" font-weight="750" style="fill:url(#egx)">' + fmt(total) + '</text></svg>';
}
function bLast() { try { if (!insOn()) return null; const m = insightsModel(prevMkOf(iso(getToday()).slice(0, 7))); return insLocked(m) ? null : m; } catch (e) { return null; } }
function bAvatar(sz) { let gg = null, av = null; try { gg = goldGrade(); av = gg ? null : avatarInfo(); } catch (e) { /* sin laurel */ } const sg = !gg && av && av.letter === 'S'; if (!gg && !sg) return avatarHTML(sz); const o = Math.round(sz * 1.375); return '<div style="position:relative;flex:none;width:' + o + 'px;height:' + o + 'px;display:flex;align-items:center;justify-content:center">' + laurelSVG(o, gg ? gg.pal : av.g, gg ? gg.cfg : LAU.S) + avatarHTML(sz, undefined, true) + '</div>'; }
const bTG = (g) => { const m = (c) => 'color-mix(in srgb,' + c + ' var(--tm,100%),#000)'; return 'linear-gradient(100deg,' + m(g[3] || g[0]) + ',' + m(g[0]) + ' 45%,' + m(g[1]) + ')'; };
function bnameGrad() { const m = bLast(); if (!m || !m.hasPrev) return ''; const g = m.plus ? tierG(m.letter, m.plus) : (GRAD[m.letter] || GRAD.B); return 'background-image:' + bTG(g) + ';'; }
const BPK = {
  card: { t: 'Tarjeta', d: 'Una tarjeta o préstamo en compacto. Tú eliges cuál.', ic: 'bank-card-line', pre: 'card', ph: 'Sin tarjetas ni préstamos', list: (c) => c.cards.map((q) => ({ id: q.id, name: q.name, o: q })) },
  goal: { t: 'Meta', d: 'El avance de una meta de ahorro. Tú eliges cuál.', ic: 'seedling-line', pre: 'goal', ph: 'Aún no tienes metas', list: (c) => c.savings.map((q) => ({ id: q.id, name: q.name, o: q })) },
  cat: { t: 'Categoría', d: 'Lo que llevas gastado en una categoría. Tú eliges cuál.', ic: 'pie-chart-2-line', pre: 'cat', ph: 'Sin gastos este mes', list: (c) => CAT_ORDER.filter((k) => (c.catTot[k] || 0) > 0 || ((budOf(activeSet()) || {})[k] || 0) > 0).map((k) => ({ id: k, name: k, o: k })) },
  acct: { t: 'Cuenta', d: 'El saldo de una cuenta. Tú eliges cuál.', ic: 'wallet-3-line', pre: 'acct', ph: 'Sin cuentas', list: () => data.accounts.filter((q) => !q.hid).map((q) => ({ id: q.id, name: q.name, o: q })) }
};
function bpkOf(kind, x, c) {
  const L = BPK[kind].list(c); if (!L.length) return null; const re = new RegExp('^' + kind + '\\d*$'), same = (ui.bento || []).filter((q) => re.test(q.id));
  let r = x && x.k ? L.find((q) => q.id === x.k) : null;
  if (!r) { const used = same.filter((q) => q.k).map((q) => q.k), free = L.filter((q) => used.indexOf(q.id) < 0), pos = Math.max(0, same.findIndex((q) => x && q.id === x.id)); r = free[Math.min(pos, free.length - 1)] || L[0]; }
  return r;
}
function bring(o) {
  const R = 108, C = 2 * Math.PI * R, pc = Math.max(0, Math.min(100, o.pct)), ln = pc / 100 * C, id = o.uid, big = String(o.big), fs = Math.max(24, Math.min(46, 150 / (big.length * 0.58)));
  const tx = 'font-size="17" font-weight="650" letter-spacing="1.5" style="fill:var(--mute);text-transform:uppercase"';
  return '<svg class="dsvg" viewBox="0 0 340 340" preserveAspectRatio="xMidYMid meet"><defs><path id="' + id + 't" d="M 24,170 A 146,146 0 0 1 316,170"/><path id="' + id + 'b" d="M 8,170 A 162,162 0 0 0 332,170"/></defs>' +
    '<circle cx="170" cy="170" r="' + R + '" fill="none" stroke="var(--track)" stroke-width="24"/>' + (pc > 0 ? '<circle cx="170" cy="170" r="' + R + '" fill="none" stroke="' + o.color + '" stroke-width="24" stroke-linecap="round" stroke-dasharray="' + Math.max(1, ln).toFixed(1) + ' ' + C.toFixed(1) + '" transform="rotate(-90 170 170)"/>' : '') +
    '<text x="170" y="' + (170 + fs * 0.2) + '" text-anchor="middle" font-size="' + fs + '" font-weight="750" letter-spacing="-1.2" style="fill:currentColor">' + big + '</text>' +
    (o.sub ? '<text x="170" y="' + (170 + fs * 0.2 + 32) + '" text-anchor="middle" font-size="21" font-weight="600" style="fill:' + (o.subc || 'var(--mute)') + '">' + o.sub + '</text>' : '') +
    '<text ' + tx + '><textPath href="#' + id + 't" startOffset="50%" text-anchor="middle">' + o.top + '</textPath></text>' +
    '<text ' + tx + '><textPath href="#' + id + 'b" startOffset="50%" text-anchor="middle">' + o.bot + '</textPath></text></svg>';
}
function bhalf(o) {
  const pc = Math.max(0, Math.min(100, o.pct)), big = String(o.big), fs = Math.max(30, Math.min(58, 200 / (big.length * 0.58)));
  const arc = 'M 30,175 A 140,140 0 0 1 310,175', pl = (x) => String(x || '').replace(/<[^>]*>/g, '');
  let lab = (o.top || '') + '<tspan> · </tspan>' + (o.bot || ''), len = pl(o.top).length + 3 + pl(o.bot).length;
  if (len > 34) { lab = o.top || ''; len = pl(o.top).length; }
  const lf = Math.max(11, Math.min(16, 320 / (Math.max(8, len) * 0.78)));
  return '<svg class="dsvg" viewBox="0 0 340 216" preserveAspectRatio="xMidYMid meet">' +
    '<path d="' + arc + '" fill="none" stroke="var(--track)" stroke-width="28" stroke-linecap="round"/>' +
    (pc > 0 ? '<path d="' + arc + '" fill="none" stroke="' + o.color + '" stroke-width="28" stroke-linecap="round" pathLength="100" stroke-dasharray="' + Math.max(1, pc).toFixed(1) + ' 100"/>' : '') +
    '<text x="170" y="' + (o.sub ? 142 : 160) + '" text-anchor="middle" font-size="' + fs + '" font-weight="750" letter-spacing="-1.4" style="fill:currentColor">' + big + '</text>' +
    (o.sub ? '<text x="170" y="172" text-anchor="middle" font-size="22" font-weight="600" style="fill:' + (o.subc || 'var(--mute)') + '">' + o.sub + '</text>' : '') +
    '<text x="170" y="207" text-anchor="middle" font-size="' + lf.toFixed(1) + '" font-weight="650" letter-spacing="1.2" style="fill:var(--mute);text-transform:uppercase">' + lab + '</text></svg>';
}
function bpkData(kind, r, c) {
  const o = r.o;
  if (kind === 'card') { const lim = o.limit > 0, u = lim ? o.util : 100; return { pct: u, color: !lim ? 'color-mix(in srgb,var(--mute) 55%,transparent)' : u > 85 ? '#FF6961' : u > 60 ? '#FF9500' : '#22B573', big: fmt(o.ub), sub: o.interest > 0 ? '<tspan>≈ ' + fmt2(o.interest) + ' </tspan><tspan>/mes</tspan>' : '', top: '<tspan>' + esc(String(o.name).slice(0, 20)) + '</tspan>' + (lim ? '<tspan> · ' + u + '% </tspan><tspan>usado</tspan>' : ''), bot: '<tspan>Deuda actual</tspan>', rows: [['Debes', fmt(o.ub)], o.cur !== curP() ? ['Original', fmtC(o.balance, o.cur)] : null, lim ? ['Disponible', fmt(Math.max(0, o.limit - o.balance))] : null, o.interest > 0 ? ['Interés estimado al mes', fmt2(o.interest)] : null, o.apr ? ['Tasa', o.apr + '% anual'] : null, o.due_day ? ['Pago', 'día ' + o.due_day] : null] }; }
  if (kind === 'goal') { const p = o.goal > 0 ? o.balance / o.goal * 100 : 0; return { pct: p, color: o.color || '#22B573', big: fmt(o.ub), sub: o.goal > 0 ? 'de ' + fmt(usd(o.goal, o.cur)) : '', subc: 'var(--mute)', top: '<tspan>' + esc(String(o.name).slice(0, 20)) + '</tspan><tspan> · ' + Math.round(p) + '%</tspan>', bot: '<tspan>Meta de ahorro</tspan>', rows: [['Ahorrado', fmt(o.ub)], o.cur !== curP() ? ['Original', fmtC(o.balance, o.cur)] : null, o.goal > 0 ? ['Falta', fmt(Math.max(0, usd(o.goal - o.balance, o.cur)))] : null, o.monthly > 0 ? ['Aporte mensual', fmt(usd(o.monthly, o.cur))] : null] }; }
  if (kind === 'cat') { const sp = c.catTot[o] || 0, lm = (budOf(activeSet()) || {})[o] || 0, p = lm > 0 ? sp / lm * 100 : 0; return { pct: lm > 0 ? p : 100, color: lm > 0 ? (p > 100 ? '#FF6961' : p > 80 ? '#FF9500' : CAT_COLOR[o]) : CAT_COLOR[o], big: fmt(sp), sub: lm > 0 ? 'de ' + fmt(lm) : '', subc: 'var(--mute)', top: '<tspan>' + esc(o) + '</tspan>' + (lm > 0 ? '<tspan> · ' + Math.round(p) + '%</tspan>' : ''), bot: '<tspan>Gastado este mes</tspan>', rows: [['Gastado', fmt(sp), p > 100 ? 'exp' : ''], lm > 0 ? ['Límite', fmt(lm)] : null, lm > 0 ? [lm - sp >= 0 ? 'Te quedan' : 'Te pasaste', fmt(Math.abs(lm - sp))] : null] }; }
  const tot = sum(data.accounts.filter((q) => !q.hid), (q) => Math.max(0, usd(q.balance, q.cur))), v = usd(o.balance, o.cur);
  return { pct: tot > 0 ? Math.max(0, v) / tot * 100 : 0, color: o.color || '#22B573', big: fmt(v), sub: o.cur !== curP() ? fmtC(o.balance, o.cur) : '', subc: 'var(--mute)', top: '<tspan>' + esc(o.name) + '</tspan>', bot: '<tspan>Saldo disponible</tspan>', rows: [['Saldo', fmt(v)], tot > 0 ? ['Del total', Math.round(Math.max(0, v) / tot * 100) + '%'] : null, o.apy ? ['Rendimiento', o.apy + '% anual'] : null] };
}
function bpkW(kind, slot) {
  const K = BPK[kind];
  return { t: K.t + (slot ? ' ' + (slot + 1) : ''), d: K.d, ic: K.ic, sizes: ['S', 'M', 'T'], nh: 1,
    tt: (x) => { const c = calc(), r = bpkOf(kind, x, c); if (!ui.bnEdit || !r || (x && x.pv)) return r ? esc(r.name) : K.t; return '<select class="bsel" data-bcard="' + (x ? x.id : '') + '" aria-label="Elegir">' + BPK[kind].list(c).map((q) => '<option value="' + esc(q.id) + '"' + (q.id === r.id ? ' selected' : '') + '>' + esc(q.name) + '</option>').join('') + '</select>'; },
    r: (c, w, h, x) => {
      const r = bpkOf(kind, x, c); if (!r) return bemp(K.ph); const d = bpkData(kind, r, c), ring = bring(Object.assign({ uid: 'bk' + (x ? x.id : kind) }, d));
      if (h === 1 && w >= 2) return '<div class="bdon" style="flex-direction:column">' + bhalf(d) + '</div>';
      if (h === 1) return '<div class="bdon" style="flex-direction:column">' + ring + '</div>';
      return '<div style="display:flex;flex-direction:column;gap:.7em;flex:1;min-height:0"><div style="flex:1;min-height:0;display:flex">' + ring + '</div><div class="bstack" style="flex:none">' + d.rows.filter(Boolean).map((q) => '<div class="brow"><div><span>' + q[0] + '</span><b' + (q[2] ? ' class="' + q[2] + '"' : '') + ' style="color:var(--ink)">' + q[1] + '</b></div></div>').join('') + '</div></div>';
    } };
}
const BW = {
  kpi: { t: 'Resumen del mes', d: 'Balance, ingresos, gastos y ahorro neto.', ic: 'dashboard-line', sizes: ['W', 'M'], dk: true, r: (c, w) => {
    const net = c.income - c.expense, it = [['Balance actual', fmt(c.balance), '', 'wallet-3-line'], ['Ingresos del mes', fmt(c.income), 'pos', 'arrow-down-circle-line'], ['Gastos del mes', fmt(c.expense), 'exp', 'arrow-up-circle-line'], ['Ahorro neto', (net >= 0 ? '+' : '') + fmt(net), net >= 0 ? 'pos' : 'neg', 'seedling-line']], two = w < 4;
    return '<div class="bkpi' + (two ? ' two' : '') + '">' + it.map((x) => '<div><i class="ki ' + x[2] + '">' + RMI(x[3], two ? 22 : 30, 'currentColor') + '</i><span>' + x[0] + '</span><b class="' + x[2] + '">' + x[1] + '</b></div>').join('') + '</div>';
  } },
  cats: { t: 'Gasto por categoría', d: 'En qué se va tu plata este mes.', ic: 'pie-chart-2-line', sizes: ['S', 'T', 'L'], r: (c, w, h) => {
    if (!c.cats.length) return bemp('Sin gastos este mes');
    const list = '<div class="blist">' + c.cats.slice().sort((a, b) => b.v - a.v).slice(0, h >= 2 ? 8 : 5).map((k) => '<div><i style="background:' + k.color + '"></i><span>' + esc(k.name) + '</span><b>' + fmt(k.v) + '</b></div>').join('') + '</div>';
    if (w === 1 && h === 1) return '<div class="bdon">' + bDonut(c.cats, c.expV, 'Gastado') + '</div>';
    if (w === 1) return '<div style="display:flex;flex-direction:column;gap:.8em;flex:1;min-height:0"><div style="flex:1;min-height:0;display:flex">' + bDonut(c.cats, c.expV, 'Gastado') + '</div>' + list.replace('class="blist"', 'class="blist" style="flex:none;gap:.4em"') + '</div>';
    return '<div class="bdon">' + bDonut(c.cats, c.expV, 'Gastado') + list + '</div>';
  } },
  flow: { t: 'Ingresos vs gastos', d: 'Comparación de los últimos meses.', ic: 'bar-chart-grouped-line', sizes: ['M', 'L', 'W'], r: (c, w, h) => {
    const ms = c.months.filter((m) => m.income > 0 || m.expense > 0); if (!ms.length) return bemp('Aún no hay meses para comparar');
    const dim = bvb(w, h, 1.8), vw = dim[0], vh = dim[1], fz = dim[2], H = vh - fz * 2.4 - fz * 1.5, gw = (vw - 8) / ms.length, bw = Math.min(gw * 0.3, fz * (ms.length < 3 ? 9 : 4.5)), mx = Math.max.apply(null, ms.map((m) => Math.max(m.income, m.expense, 1)));
    const vl = (x, y, v) => bw >= fz * 2.6 ? '<text x="' + x + '" y="' + (y - fz * 0.45) + '" text-anchor="middle" font-size="' + (fz * 0.85) + '" font-weight="650" style="fill:var(--ink)">' + fmt(v) + '</text>' : '';
    const T0 = fz * 1.5, HH = H;
    const bars = ms.map((m, i) => { const gx = 4 + i * gw + gw / 2, hi = Math.max(2, m.income / mx * HH), he = Math.max(2, m.expense / mx * HH), yi = T0 + HH - hi, ye = T0 + HH - he; return '<rect x="' + (gx - bw - 2) + '" y="' + yi + '" width="' + bw + '" height="' + hi + '" rx="' + Math.min(6, bw / 4) + '" fill="#22B573" class="gI" style="fill:url(#bgG)"/>' + vl(gx - bw / 2 - 2, yi, m.income) + '<rect x="' + (gx + 2) + '" y="' + ye + '" width="' + bw + '" height="' + he + '" rx="' + Math.min(6, bw / 4) + '" class="gX" style="fill:url(#bgI)" opacity="' + (m.cur ? 1 : 0.8) + '"/>' + vl(gx + bw / 2 + 2, ye, m.expense) + '<text x="' + gx + '" y="' + (T0 + HH + fz * 1.5) + '" text-anchor="middle" font-size="' + fz * 0.9 + '" style="fill:var(--mute)">' + m.label + '</text>'; }).join('');
    return '<div class="bleg"><span><i style="background:#22B573"></i>Ingresos</span><span><i style="background:var(--ink)"></i>Gastos</span></div><svg class="bsvg" viewBox="0 0 ' + vw + ' ' + vh + '" preserveAspectRatio="xMidYMid meet">' + BGDEFS + bars + '</svg>';
  } },
  daily: { t: 'Gasto acumulado del mes', d: 'Cómo avanza tu gasto día a día.', ic: 'line-chart-line', sizes: ['M', 'L', 'W'], r: (c, w, h) => {
    const flow = c.monthTx.filter((t) => !isPay(t) && t.amount < 0), td = c.today.getDate(), per = new Array(c.dim + 1).fill(0);
    flow.forEach((t) => { per[parseInt(t.date.slice(8), 10)] += -txUSD(t); });
    if (!flow.length) return bemp('Sin gastos este mes');
    const cum = []; let a = 0; for (let d = 1; d <= td; d++) { a += per[d]; cum.push(a); }
    const lim = c.budgetTotal > 0 ? c.budgetTotal : 0, dim = bvb(w, h, 2.6), vw = dim[0], vh = dim[1], fz = dim[2], H = vh - fz * 1.6, mx = Math.max(a, lim, 1) * 1.08;
    const X = (d) => 4 + (d - 1) / Math.max(1, c.dim - 1) * (vw - 8), Y = (v) => H - v / mx * H;
    const pts = cum.map((v, i) => X(i + 1).toFixed(1) + ',' + Y(v).toFixed(1)).join(' ');
    const area = 'M' + X(1).toFixed(1) + ',' + H + ' L' + pts.replace(/ /g, ' L') + ' L' + X(td).toFixed(1) + ',' + H + ' Z';
    const ly = lim ? '<line x1="4" x2="' + (vw - 4) + '" y1="' + Y(lim).toFixed(1) + '" y2="' + Y(lim).toFixed(1) + '" stroke="#FF9500" stroke-width="1.2" stroke-dasharray="4 3"/>' : '';
    return '<div class="bhead"><b class="exp">' + fmt(a) + '</b><span>' + (lim ? 'de ' + fmt(lim) + ' en límites' : 'gastado hasta hoy') + '</span></div><svg class="bsvg" viewBox="0 0 ' + vw + ' ' + vh + '" preserveAspectRatio="xMidYMid meet"><path d="' + area + '" fill="#22B573" opacity=".14"/><polyline points="' + pts + '" fill="none" stroke="#22B573" stroke-width="2.2" stroke-linejoin="round" stroke-linecap="round"/>' + ly + '<circle cx="' + X(td).toFixed(1) + '" cy="' + Y(a).toFixed(1) + '" r="3.2" fill="#22B573"/><text x="4" y="' + (vh - 3) + '" font-size="'+(fz*0.9)+'" style="fill:var(--mute)">1</text><text x="' + (vw - 4) + '" y="' + (vh - 3) + '" text-anchor="end" font-size="' + (fz * 0.9) + '" style="fill:var(--mute)">' + c.dim + '</text></svg>';
  } },
  budget: { t: 'Presupuesto', d: 'Cuánto llevas contra cada límite.', ic: 'wallet-3-line', sizes: ['T', 'L', 'M'], r: (c, w, h) => {
    const lim = budOf(activeSet()) || {}, cap = bcap(h) - (w > 1 && h === 1 ? 1 : 0);
    const rows = CAT_ORDER.filter((k) => (lim[k] || 0) > 0).map((k) => ({ k: k, sp: c.catTot[k] || 0, lm: lim[k] }));
    if (!rows.length) { const top = c.cats.slice().sort((a, b) => b.v - a.v).slice(0, cap); if (!top.length) return bemp('Define límites en Presupuesto'); const mx = top[0].v; return '<div class="bstack">' + top.map((k) => '<div class="brow"><div><span>' + esc(k.name) + '</span><b>' + fmt(k.v) + '</b></div>' + bbar(k.v / mx * 100, k.color) + '</div>').join('') + '</div>'; }
    return '<div class="bstack">' + rows.sort((a, b) => b.sp / b.lm - a.sp / a.lm).slice(0, cap).map((r) => { const p = r.sp / r.lm * 100; return '<div class="brow"><div><span>' + r.k + '</span><b' + (p > 100 ? ' class="exp"' : p > 80 ? ' class="warn"' : '') + '>' + fmt(r.sp) + ' <small>/ ' + fmt(r.lm) + '</small></b></div>' + bbar(p, p > 100 ? 'var(--rt)' : p > 80 ? '#FF9500' : CAT_COLOR[r.k]) + '</div>'; }).join('') + '</div>';
  } },
  top: { t: 'Mayores gastos', d: 'Lo que más dinero se llevó este mes.', ic: 'trophy-line', sizes: ['T', 'S', 'M'], r: (c, w, h) => {
    const g = {}; c.monthTx.filter((t) => !isPay(t) && t.amount < 0).forEach((t) => { const n = (t.note || t.category || 'Sin nombre').trim(), k = n.toLowerCase(); g[k] = g[k] || { n: n, v: 0 }; g[k].v += -txUSD(t); });
    const top = Object.keys(g).map((k) => g[k]).sort((a, b) => b.v - a.v).slice(0, bcap(h)); if (!top.length) return bemp('Sin gastos este mes');
    return '<div class="bstack">' + top.map((x) => '<div class="brow"><div><span>' + esc(x.n) + '</span><b>' + fmt(x.v) + '</b></div>' + bbar(x.v / top[0].v * 100, '#22B573') + '</div>').join('') + '</div>';
  } },
  subs: { t: 'Servicios y suscripciones', d: 'Lo que pagas cada mes sin pensarlo.', ic: 'repeat-line', sizes: ['T', 'S', 'M'], r: (c, w, h) => {
    if (!data.subs.length) return bemp('No tienes servicios ni suscripciones');
    const rows = data.subs.slice().sort((a, b) => usd(b.amount, b.cur) - usd(a.amount, a.cur)).slice(0, bcap(h) - 1);
    return '<div class="bstack">' + rows.map((x) => '<div class="brow"><div><span>' + esc(x.name) + ' <small>día ' + x.day + '</small></span><b>' + fmt(usd(x.amount, x.cur)) + '</b></div></div>').join('') + '</div><div class="bfoot"><span>Total al mes</span><b>' + fmt(c.subsTotal) + '</b></div>';
  } },
  debt: { t: 'Tarjetas y deuda', d: 'Cuánto debes y cuánto crédito usas.', ic: 'bank-card-line', sizes: ['S', 'M', 'T'], r: (c, w, h) => {
    if (!c.cards.length) return bemp('Sin tarjetas ni préstamos');
    return '<div class="bstack">' + c.cards.slice(0, bcap(h) - 1).map((k) => '<div class="brow"><div><span>' + esc(k.name) + '</span><b>' + fmt(k.ub) + (k.limit > 0 ? ' <small>' + k.util + '%</small>' : '') + '</b></div>' + bbar(k.limit > 0 ? k.util : 100, k.util > 70 ? 'var(--rt)' : k.util > 40 ? '#FF9500' : '#22B573') + '</div>').join('') + '</div><div class="bfoot"><span>Deuda total</span><b class="exp">' + fmt(c.debt) + '</b></div>';
  } },
  goals: { t: 'Metas de ahorro', d: 'Qué tanto te falta para cada meta.', ic: 'seedling-line', sizes: ['S', 'M', 'T'], r: (c, w, h) => {
    if (!c.savings.length) return bemp('Aún no tienes metas');
    return '<div class="bstack">' + c.savings.slice(0, bcap(h) - 1).map((k) => { const p = k.goal > 0 ? k.balance / k.goal * 100 : 0; return '<div class="brow"><div><span>' + esc(k.name) + '</span><b>' + Math.round(p) + '%</b></div>' + bbar(p, k.color) + '</div>'; }).join('') + '</div><div class="bfoot"><span>Ahorrado</span><b>' + fmt(c.saved) + '</b></div>';
  } },
  upcoming: { t: 'Próximos movimientos', d: 'Lo que viene en los próximos días.', ic: 'calendar-event-line', sizes: ['T', 'M', 'L'], r: (c, w, h) => {
    const lim = addDays(c.today, 45), ev = genEvents(c.today, {}).filter((e) => e.date <= lim).slice(0, 6); if (!ev.length) return bemp('Nada previsto por ahora');
    return '<div class="bstack' + (w > 1 ? ' bcp' : '') + '">' + ev.map((e) => '<div class="bup"><div class="dd"><b>' + e.date.getDate() + '</b><small>' + MON[e.date.getMonth()] + '</small></div><span class="n">' + esc(e.name) + '</span><b class="a ' + (e.amt >= 0 ? 'pos' : '') + '">' + (e.amt >= 0 ? '+' : '') + fmt(e.amt) + '</b></div>').join('') + '</div>';
  } },
  monthtx: { t: 'Movimientos del mes', d: 'Lo último que movió tu plata este mes.', ic: 'calendar-2-line', sizes: ['T', 'M', 'L'], r: (c, w, h) => {
    const mk = iso(c.today).slice(0, 7), hs = hidSet(), list = c.tx.filter((t) => t.date.slice(0, 7) === mk && !(hs && hs.has(t.acc || data.accounts[0].id)));
    if (!list.length) return bemp('Sin movimientos este mes');
    const n = h > 1 ? (w > 1 ? 8 : 6) : 3;
    return '<div class="bstack' + (w > 1 && h > 1 ? ' bcp' : '') + '" data-act="month">' + list.slice(0, n).map((t) => '<div class="bup"><div class="dd"><b>' + pd(t.date).getDate() + '</b><small>' + MON[pd(t.date).getMonth()] + '</small></div><span class="n">' + esc(t.note || (t.amount > 0 ? 'Ingreso' : t.category)) + '</span><b class="a ' + (t.amount > 0 && !isPay(t) ? 'pos' : '') + '">' + fmtSC2(t.amount, accOf(t.acc).cur) + '</b></div>').join('') + '</div>';
  } },
  weekday: { t: 'Gasto por día', d: 'En qué días de la semana gastas más.', ic: 'calendar-2-line', sizes: ['S', 'M'], r: (c, w, h) => {
    const from = iso(addDays(c.today, -90)), per = [0, 0, 0, 0, 0, 0, 0]; let n = 0;
    c.tx.forEach((t) => { if (t.date >= from && t.amount < 0 && !isPay(t)) { per[(pd(t.date).getDay() + 6) % 7] += -txUSD(t); n++; } });
    if (!n) return bemp('Sin gastos recientes');
    const dim = bvb(w, h), vw = dim[0], vh = dim[1], fz = dim[2], H = vh - fz * 1.8, gw = (vw - 8) / 7, mx = Math.max.apply(null, per), top = per.indexOf(mx), lb = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return '<svg class="bsvg" viewBox="0 0 ' + vw + ' ' + vh + '" preserveAspectRatio="xMidYMid meet">' + BGDEFS + per.map((v, i) => { const bh = Math.max(1, v / mx * H), x = 4 + i * gw + gw * 0.18; return '<rect x="' + x + '" y="' + (H - bh) + '" width="' + (gw * 0.64) + '" height="' + bh + '" rx="3" fill="#22B573" class="gI" style="fill:url(#bgG)" opacity="' + (i === top ? 1 : 0.5) + '"/><text x="' + (4 + i * gw + gw / 2) + '" y="' + (vh - 3) + '" text-anchor="middle" font-size="' + (fz * 0.95) + '" style="fill:var(--mute)">' + lb[i] + '</text>'; }).join('') + '</svg>';
  } },
  score: { t: 'Tu evaluación', tt: () => { const m = bLast(); return m && m.hasPrev ? 'Nota de ' + MON_FULL[m.T.getMonth()] : 'Tu evaluación'; }, d: 'La nota de tu último cierre de mes.', ic: 'medal-line', sizes: ['S', 'M', 'T'], r: (c, w, h) => {
    const m = bLast(); if (!m || !m.hasPrev || !scoreOn()) return bemp('Aún sin evaluación');
    const g = m.plus ? tierG(m.letter, m.plus) : (GRAD[m.letter] || GRAD.B), L = m.plus === 'd' ? '◆' : tL(m.letter, m.plus), d = bvb(w, h), big = Math.max(40, Math.min(d[1] * 0.82, d[0] * (w > 1 ? 0.4 : 0.8)));
    const sub = '';
    const ltr = '<div style="font-size:' + big + 'px;font-weight:800;letter-spacing:-.05em;line-height:1;padding:0 .1em 0 .04em;background:' + bTG(g) + ';-webkit-background-clip:text;background-clip:text;color:transparent;-webkit-text-fill-color:transparent">' + L + '</div>';
    if (w === 1) return '<div style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center">' + ltr + sub + (h > 1 ? '<div style="margin-top:1em;color:var(--ink);line-height:1.35">' + esc(insPhrase(m)) + '</div>' : '') + '</div>';
    return '<div style="flex:1;display:flex;align-items:center;gap:1.6em;min-height:0"><div style="text-align:center;flex:none">' + ltr + sub + '</div><div style="flex:1;min-width:0;color:var(--ink);font-size:1.6em;font-weight:600;letter-spacing:-.02em;line-height:1.25">' + esc(insPhrase(m)) + '</div></div>';
  } },
  insight: { t: 'Último insight', tt: () => { const m = bLast(); return m && m.hasPrev ? 'Insight de ' + MON_FULL[m.T.getMonth()] : 'Último insight'; }, d: 'La lectura más reciente de tus finanzas.', ic: 'lightbulb-line', sizes: ['M', 'W', 'S', 'L'], r: (c, w, h) => {
    const m = bLast(); if (!m || !m.hasPrev) return bemp('Aún sin insights');
    const g = m.plus ? tierG(m.letter, m.plus) : (GRAD[m.letter] || GRAD.B), tg = bTG(g), d = bvb(w, h), fz = Math.max(1.4, Math.min(w > 1 && h === 1 ? 2.7 : 4.4, d[0] / (w > 1 ? 270 : 250) * (h > 1 ? 1.3 : 1)));
    const phrase = '<div style="font-size:' + fz + 'em;font-weight:700;letter-spacing:-.03em;line-height:1.2;background:' + tg + ';-webkit-background-clip:text;background-clip:text;color:transparent;-webkit-text-fill-color:transparent">' + esc(insPhrase(m)) + '</div>' + (w < 2 ? '<div style="color:var(--mute)">Cierre de ' + MON_FULL[m.T.getMonth()] + '</div>' : '');
    if (w < 2) return '<div style="flex:1;display:flex;flex-direction:column;justify-content:center;gap:.5em;min-height:0">' + phrase + '</div>';
    const pm = MON_FULL[Number(m.pmk.slice(5, 7)) - 1], pts = [];
    if (m.ps != null) pts.push([m.ps <= 0, 'Gastaste ' + Math.round(Math.abs(m.ps) * 100) + '% ' + (m.ps <= 0 ? 'menos' : 'más') + ' que en ' + pm]);
    if (m.rateC != null) pts.push([m.rateP != null ? m.rateC >= m.rateP : m.rateC >= 0, m.rateC < 0 ? 'Gastaste ' + Math.round(-m.rateC * 100) + '% más de lo que ingresaste' : 'Ahorraste el ' + Math.round(m.rateC * 100) + '% de tus ingresos' + (m.rateP != null && m.rateP >= 0 && m.rateC >= 0 ? ' (antes ' + Math.round(m.rateP * 100) + '%)' : '')]);
    if (m.lim.length) pts.push([m.within === m.lim.length, m.within + ' de ' + m.lim.length + ' categorías dentro de su límite']);
    pts.push([m.contrib ? true : null, m.contrib ? 'Aportaste a tus metas este mes' : 'Aportar a una meta suma un bonus extra']);
    const leftW = (d[0] - 60) * 0.64, txt = insPhrase(m), nl = h > 1 ? 3 : 2;
    let pf = Math.min(leftW * nl / (txt.length * 0.56), d[1] * (h > 1 ? 0.14 : 0.15)), vf = Math.min(leftW / 4 / 3.5, d[1] * 0.27);
    const need = pf * 1.2 * nl + vf * 1.2 + vf * 0.45 + 28, k = Math.min(1, (d[1] - 4) / need); pf *= k; vf *= k;
    const net = m.cur.inc - m.cur.exp;
    const st = [['Ingresos', fmt(m.cur.inc), 0], ['Gastos', fmt(m.cur.exp), 1], ['Ahorro', m.rateC == null ? '—' : Math.round(m.rateC * 100) + '%', m.rateC != null && m.rateC < 0 ? 1 : 0], ['Nota', tL(m.letter, m.plus) + ' · ' + m.score, 0]].map((x) => '<div style="display:flex;flex-direction:column;gap:.1em"><span style="color:var(--mute);font-size:' + Math.max(13, Math.round(vf * 0.4)) + 'px">' + x[0] + '</span><b style="font-size:' + Math.round(vf) + 'px;white-space:nowrap;font-weight:800;letter-spacing:-.03em;line-height:1.1;background:' + (x[2] ? 'linear-gradient(180deg,#FF9A92,#E5625A 55%,#8E2C28)' : 'linear-gradient(180deg,#46E096,#22B573 55%,#0B5F3B)') + ';-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent">' + x[1] + '</b></div>').join('');
    const kf = Math.round(Math.max(14, Math.min(d[1] * 0.074, d[0] * 0.026, 22))), kp = '<div data-kp="1" style="flex:none;width:36%;border-left:1px solid var(--wline);padding-left:1.2em;display:flex;align-items:center;justify-content:center;font-size:' + kf + 'px"><div style="display:flex;flex-direction:column;gap:.6em;max-width:100%"><div style="color:var(--mute);font-size:.72em;text-transform:uppercase;letter-spacing:.08em;font-weight:600">Puntos clave</div>' + pts.map((x) => '<div style="display:flex;gap:.6em;align-items:flex-start;line-height:1.28"><i style="flex:none;width:.55em;height:.55em;border-radius:50%;margin-top:.365em;background:' + (x[0] === null ? '#8E8E93' : x[0] ? '#22B573' : '#E5625A') + '"></i><span>' + esc(x[1]) + '</span></div>').join('') + '</div></div>';
    const phrase2 = '<div style="font-size:' + Math.round(pf) + 'px;font-weight:700;letter-spacing:-.03em;line-height:1.2;background:' + tg + ';-webkit-background-clip:text;background-clip:text;color:transparent;-webkit-text-fill-color:transparent">' + esc(txt) + '</div>';
    return '<div style="flex:1;display:flex;gap:1.8em;min-height:0"><div style="flex:1;min-width:0;display:flex;flex-direction:column;justify-content:center;gap:.5em">' + phrase2 + '<div style="display:grid;grid-template-columns:repeat(4,auto);justify-content:space-between;gap:0 1em;margin-top:' + Math.round(vf * 0.35) + 'px">' + st + '</div></div>' + kp + '</div>';
  } },
  profile: { t: 'Perfil', d: 'Tu foto y tu nombre en grande.', ic: 'user-smile-line', sizes: ['M', 'S', 'T', 'V'], r: (c, w, h) => {
    const st = data.settings || {}, nm = [(st.first || '').trim(), (st.last || '').trim()].filter(Boolean).join(' '), name = (st.nick || '').trim() || nm;
    if (!name && !avatarPhoto()) return bemp('Añade tu nombre y foto en Perfil');
    const d = bvb(w, h), col = w === 1, tall = col && h >= 3, sz = Math.round(Math.max(48, Math.min(col ? d[0] * (tall ? 0.74 : 0.5) : d[1] * 0.6, col ? d[1] * (tall ? 0.42 : 0.3) : d[0] * 0.2, tall ? 260 : 190)));
    const avail = col ? d[0] - 50 : d[0] - sz - 120, fs = Math.round(Math.max(20, Math.min(d[1] * (col ? 0.26 : 0.5), avail / (Math.max(4, (col ? Math.ceil(name.length / 2) : name.length)) * 0.62))));
    return '<div style="flex:1;min-height:0;display:flex;' + (col ? 'flex-direction:column;' : '') + 'align-items:center;justify-content:center;gap:' + (col ? '.6em' : '1.2em') + ';text-align:' + (col ? 'center' : 'left') + ';overflow:hidden">' + bAvatar(sz) + (name ? '<b class="bname"' + (col ? '' : ' data-fit="1"') + ' style="' + bnameGrad() + 'font-size:' + fs + 'px;white-space:' + (col ? 'normal' : 'nowrap') + ';overflow-wrap:anywhere' + (col ? '' : ';flex:1;min-width:0') + '">' + esc(name) + '</b>' : '') + '</div>';
  } },
  name: { t: 'Nombre', d: 'Tu nombre en grande.', ic: 'user-smile-line', sizes: ['M', 'S', 'W'], r: (c, w, h) => {
    const st = data.settings || {}, nm = (st.nick || '').trim() || [(st.first || '').trim(), (st.last || '').trim()].filter(Boolean).join(' ');
    if (!nm) return bemp('Añade tu nombre en Perfil');
    const d = bvb(w, h), fs = Math.round(Math.max(18, Math.min(d[1] * 0.62, (d[0] - 140) / (Math.max(5, nm.length) * 0.68))));
    return '<div style="flex:1;min-height:0;display:flex;align-items:center;justify-content:center;text-align:center;overflow:hidden"><b class="bname" data-fit="1" style="' + bnameGrad() + 'font-size:' + fs + 'px;flex:1;min-width:0">' + esc(nm) + '</b></div>';
  } },
  rate: { t: 'Tasa de ahorro', d: 'Qué parte de tus ingresos te queda.', ic: 'percent-line', sizes: ['S'], r: (c) => {
    if (!(c.income > 0)) return bemp('Sin ingresos este mes');
    const r = (c.income - c.expense) / c.income, p = Math.max(0, Math.min(1, r)), A = Math.PI * 40, col = r < 0 ? 'var(--rt)' : '#22B573';
    return '<svg class="bsvg" viewBox="0 0 100 62" preserveAspectRatio="xMidYMid meet"><defs><linearGradient id="rgx" x1="0" x2="0" y1="0" y2="1"><stop offset="0" class="gs0"/><stop offset=".55" class="gs1"/><stop offset="1" class="gs2"/></linearGradient><linearGradient id="rga" gradientUnits="userSpaceOnUse" x1="10" y1="52" x2="90" y2="12"><stop offset="0" stop-color="#46E096"/><stop offset=".55" stop-color="#22B573"/><stop offset="1" stop-color="#0E7A4B"/></linearGradient></defs><path d="M10,52 A40,40 0 0 1 90,52" fill="none" stroke="var(--track)" stroke-width="10" stroke-linecap="round"/><path d="M10,52 A40,40 0 0 1 90,52" fill="none" stroke="' + (r < 0 ? col : 'url(#rga)') + '" stroke-width="10" stroke-linecap="round" stroke-dasharray="' + (A * p).toFixed(1) + ' ' + A.toFixed(1) + '"/><text x="50" y="50" text-anchor="middle" font-size="19" font-weight="750" style="fill:' + (r < 0 ? 'var(--rt)' : 'url(#rgx)') + '">' + Math.round(r * 100) + '%</text></svg>';
  } },
  card: bpkW('card', 0), card2: bpkW('card', 1), card3: bpkW('card', 2), goal: bpkW('goal', 0), goal2: bpkW('goal', 1), cat: bpkW('cat', 0), cat2: bpkW('cat', 1), acct: bpkW('acct', 0), acct2: bpkW('acct', 1)
};
function bentoHTML() {
  const c = calc(), items = ui.bento || (ui.bento = bentoLoad()), lay = bentoLayout(items), n = items.length;
  const tiles = lay.map((x, i) => {
    if (x.off) return '';
    const W = BW[x.id];
    const zs = bsorted(W), zi = zs.indexOf(x.s);
    const ctl = !ui.bnEdit ? '' : (''+ '<div class="bctl"><button class="pal" data-act="bncolor:' + x.id + '" title="Color del widget">' + RMI('palette-line', 15, '#fff') + '</button><button class="x" data-act="bndel:' + x.id + '" title="Quitar">' + RMI('delete-bin-line', 15, 'currentColor') + '</button></div>' + (zs.length > 1 ? '<i class="bres" data-bres="' + x.id + '" title="Arrastra para cambiar el tamaño"></i>' : ''));
    return '<div data-bid="' + x.id + '" class="bw' + (W.dk ? ' dk' : '') + (x.c ? ' sol s' + (x.c - 1) : '') + '" style="grid-column:' + (x.x + 1) + '/span ' + x.w + ';grid-row:' + (x.y + 1) + '/span ' + x.h + '">' + ctl + (W.nh && x.h === 1 && !ui.bnEdit ? '' : '<div class="bw-h">' + (W.tt ? W.tt(x) : W.t) + '</div>') + '<div class="bw-b">' + W.r(c, x.w, x.h, x) + '</div></div>';
  }).join('');
  const occ = {}; lay.forEach((x) => { if (!x.off) for (let j = 0; j < x.h; j++) for (let i = 0; i < x.w; i++) occ[(x.y + j) + ',' + (x.x + i)] = 1; });
  let slots = ''; if (ui.bnEdit) for (let y = 0; y < 3; y++) for (let x = 0; x < 4; x++) if (!occ[y + ',' + x]) slots += '<button class="bslot" style="grid-column:' + (x + 1) + ';grid-row:' + (y + 1) + '" data-act="bngal">' + RMI('add-circle-line', 26, 'currentColor') + '<span>Añadir widgets</span></button>';
  const empty = (n || ui.bnEdit) ? '' : '<div class="bemp" style="grid-column:1/-1;grid-row:1/-1;border:2px dashed var(--wline);border-radius:26px;display:flex;align-items:center;justify-content:center">' + (ui.bnEdit ? 'Tu Bento está vacío. Añade widgets para empezar.' : 'Este Bento está vacío. Toca Editar para añadir widgets.') + '</div>';
  const gal = ui.bnEdit && ui.bnGal ? '<aside class="bgal"><h3>Widgets</h3><p>Elige qué quieres ver. Cada uno se puede achicar o agrandar pasando el cursor encima.</p>' + Object.keys(BW).filter((id) => { const m = /^([a-z]+)(\d)$/.exec(id); if (!m || items.some((x) => x.id === id)) return true; const pv = +m[2] - 1; return items.some((x) => x.id === m[1] + (pv > 1 ? pv : '')); }).map((id) => { const on = items.some((x) => x.id === id), W = BW[id]; return '<button class="bgi" data-act="' + (on ? 'bndel:' : 'bnadd:') + id + '"><span class="gi">' + RMI(W.ic, 22, '#22B573') + '</span><span><b>' + W.t + '</b><span class="s">' + W.d + '</span></span><em>' + (on ? 'Añadido' : 'Añadir') + '</em></button>'; }).join('') + '</aside>' : '';
  const cs = bcur(), nm = cs ? cs.name : 'Bento';
  const chips = ui.bset.sets.map((x) => '<button class="bchip' + (x.id === ui.bset.cur ? ' on' : '') + '" data-act="bnset:' + x.id + '">' + esc(x.name) + '</button>').join('');
  const editHdr = '<div class="bh"><input class="bname" value="' + esc(nm) + '" maxlength="40" aria-label="Nombre del Bento" spellcheck="false" style="width:' + Math.max(6, nm.length + 2) + 'ch"><div class="bsets">' + chips + '</div>' + bUndoBtns() + '<button class="bbtn' + (ui.bnGal ? ' on' : '') + '" data-act="bngal">' + RMI('add-circle-line', 18, 'currentColor') + 'Añadir widgets</button><button class="bbtn" data-act="bnreset">Restablecer</button>' + (ui.bset.sets.length > 1 ? '<button class="bbtn" data-act="bndelset" aria-label="Eliminar Bento" title="Eliminar Bento">' + RMI('delete-bin-line', 18, 'currentColor') + '</button>' : '') + '<button class="bbtn pri" data-act="bnview">Listo</button></div>';
  const N = ui.bset.sets.length, ci = ui.bset.sets.findIndex((x) => x.id === ui.bset.cur);
  const viewHdr = '<div class="bh"><h2>' + esc(nm) + (N > 1 ? '<small>' + (ci + 1) + ' de ' + N + '</small>' : '') + '</h2>' + bUndoBtns() + '<button class="bbtn" data-act="bnplus" aria-label="Nuevo Bento" title="Nuevo Bento">' + RMI('add-line', 18, 'currentColor') + ' Nuevo</button><button class="bbtn" data-act="bnedit">' + RMI('edit-line', 18, 'currentColor') + 'Editar</button><button class="bbtn pri" data-act="bnshot">' + RMI('camera-line', 18, 'currentColor') + 'Generar captura</button><button class="bbtn" data-act="bnclose" aria-label="Cerrar" title="Cerrar">' + RMI('close-line', 18, 'currentColor') + '</button></div>';
  const side = (!ui.bnEdit && N > 1) ? '<button class="bside l" data-act="bnnav:-1" aria-label="Anterior"' + (ci <= 0 ? ' disabled' : '') + '>' + RMI('arrow-left-s-line', 28, 'currentColor') + '</button><button class="bside r" data-act="bnnav:1" aria-label="Siguiente"' + (ci >= N - 1 ? ' disabled' : '') + '>' + RMI('arrow-right-s-line', 28, 'currentColor') + '</button>' : '';
  const dots = (!ui.bnEdit && N > 1) ? '<div class="bdots">' + ui.bset.sets.map((x) => '<button class="' + (x.id === ui.bset.cur ? 'on' : '') + '" data-act="bnset:' + x.id + '" aria-label="' + esc(x.name) + '"></button>').join('') + '</div>' : '';
  const pick = ui.bPick ? '<div class="bpick" data-act="bnplus"><div class="bpbox" data-act="bnnop"><h3>Nuevo Bento</h3><div class="bpgrid">' + BENTO_PRE.map((x) => { const L = bentoLayout(x.items.map((q) => ({ id: q[0], s: q[1] }))); return '<button class="bpc' + (x.empty ? ' bpv' : '') + '" data-act="bnpick:' + x.id + '"><div class="bpm' + (x.empty ? ' bpe' : '') + '">' + (x.empty ? RMI('add-line', 34, 'var(--mute)') : '') + L.map((q, qi) => q.off ? '' : '<i style="grid-column:' + (q.x + 1) + '/span ' + q.w + ';grid-row:' + (q.y + 1) + '/span ' + q.h + '"></i>').join('') + '</div><div class="bpt"><span class="bpi">' + RMI(x.ic, 20, '#22B573') + '</span><b>' + x.n + '</b>' + (x.tag ? '<em class="bptag">' + x.tag + '</em>' : '') + '</div>' + (x.d ? '<span class="bpd">' + x.d + '</span>' : '') + '</button>'; }).join('') + '</div></div></div>' : '';
  const dirc = ui.bdir ? ' sl' + (ui.bdir > 0 ? 'r' : 'l') : ''; ui.bdir = 0;
  return (ui.bnEdit ? editHdr : viewHdr) + '<div class="bstage' + (ui.bnEdit ? '' : ' view') + '"><div class="bwrap"><div class="bcanvas' + dirc + '" id="bcanvas">' + tiles + slots + empty + '</div>' + dots + '</div>' + side + gal + '</div>' + pick;
}
function bFit(root) { (root || document).querySelectorAll('[data-kp]').forEach((k) => { const w = k.closest('.bw'); if (!w) return; k.style.transform = ''; const A = w.getBoundingClientRect(), B = k.getBoundingClientRect(); if (A.height) k.style.transform = 'translateY(' + Math.round((A.top + A.height / 2) - (B.top + B.height / 2)) + 'px)'; }); (root || document).querySelectorAll('.bname[data-fit]').forEach((b) => { const p = b.parentElement; if (!p || !p.clientWidth || !p.clientHeight) return; let lo = 10, hi = Math.min(p.clientHeight * 0.95, 600); b.style.fontSize = hi + 'px'; if (b.scrollWidth <= b.clientWidth + 1 && b.scrollHeight <= p.clientHeight + 1) return; for (let i = 0; i < 14; i++) { const m = (lo + hi) / 2; b.style.fontSize = m + 'px'; if (b.scrollWidth <= b.clientWidth + 1 && b.scrollHeight <= p.clientHeight + 1) lo = m; else hi = m; } b.style.fontSize = Math.floor(lo) + 'px'; }); }
window.addEventListener('resize', () => { if (typeof bFit === 'function') bFit($('#bento')); });
function bentoRender() { const el = $('#bento'); if (!el) return; const sc = el.querySelector('.bgal'), st = sc ? sc.scrollTop : 0; el.innerHTML = bentoHTML(); const g = el.querySelector('.bgal'); if (g && st) g.scrollTop = st; if (typeof retranslateAll === 'function') retranslateAll(); bFit(el); requestAnimationFrame(() => bFit(el)); }
function bPreview(id) {
  const old = document.getElementById('bpv'); if (old) old.remove(); const cv = document.getElementById('bcanvas'); if (!cv || !id || !BW[id]) return;
  const W = BW[id], z = W.sizes[0], w = BSZ[z][0], h = BSZ[z][1], gap = 14, cw = (cv.clientWidth - 3 * gap) / 4, ch = (cv.clientHeight - 2 * gap) / 3, c = calc(), it = { id: id, s: z, pv: 1 };
  const d = document.createElement('div'); d.id = 'bpv'; d.className = 'bw' + (W.dk ? ' dk' : '');
  d.style.cssText = 'position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);width:' + (cw * w + gap * (w - 1)) + 'px;height:' + (ch * h + gap * (h - 1)) + 'px;z-index:40;pointer-events:none;box-shadow:0 30px 80px rgba(0,0,0,.55);animation:none;outline:2px solid #22B573;outline-offset:3px';
  let body = ''; try { body = W.r(c, w, h, it); } catch (e) { body = ''; }
  d.innerHTML = '<div class="bw-h">' + (W.tt ? W.tt(it) : W.t) + '</div><div class="bw-b">' + body + '</div>'; cv.appendChild(d); if (typeof retranslateAll === 'function') trTree(d);
}
document.addEventListener('mouseover', (e) => { const g = e.target.closest && e.target.closest('.bgi'); if (!g) { if (document.getElementById('bpv') && !(e.target.closest && e.target.closest('.bgal'))) bPreview(null); return; } const a = (g.getAttribute('data-act') || '').split(':'); bPreview(a[1]); });
document.addEventListener('mouseout', (e) => { const g = e.target.closest && e.target.closest('.bgi'); if (g && !(e.relatedTarget && g.contains(e.relatedTarget))) bPreview(null); });
document.addEventListener('change', (e) => { const t = e.target; if (t && t.classList && t.classList.contains('bsel') && ui.bento) { const it = ui.bento.find((q) => q.id === t.getAttribute('data-bcard')); if (it) { bPush('tarjeta', JSON.stringify(ui.bset)); it.k = t.value; bentoSave(); bentoRender(); } return; } if (t && t.classList && t.classList.contains('bname') && ui.bset) { const c = bcur(); if (!c) return; c.name = bentoUnique(t.value, c.id); bentoSave(); bentoRender(); } });
document.addEventListener('input', (e) => { const t = e.target; if (t && t.id === 'fNote') { const n = $('#nsug'); if (n) n.innerHTML = noteSugHTML(t.value); } });
document.addEventListener('input', (e) => { const t = e.target; if (t && t.classList && t.classList.contains('bname')) t.style.width = Math.max(6, t.value.length + 2) + 'ch'; });
document.addEventListener('keydown', (e) => { const t = e.target; if (t && t.classList && t.classList.contains('bname') && e.key === 'Enter') t.blur(); });
(function () {
  let D = null;
  const best = (e) => {
    const w = (e.clientX - D.left + D.gap) / (D.cw + D.gap), hh = (e.clientY - D.top + D.gap) / (D.ch + D.gap); let b = D.it.s, bd = 1e9;
    BW[D.it.id].sizes.forEach((k) => { const d = Math.pow(BSZ[k][0] - w, 2) + Math.pow(BSZ[k][1] - hh, 2); if (d < bd) { bd = d; b = k; } });
    return b;
  };
  const place = (k) => {
    const old = D.it.s; D.it.s = k; const lay = bentoLayout(ui.bento), me = lay.find((x) => x.id === D.it.id); D.it.s = old;
    if (!me || me.off) return null; me.kills = lay.filter((x) => x.off).map((x) => x.id); return me;
  };
  const mark = (me) => { document.querySelectorAll('.bw.rm').forEach((x) => x.classList.remove('rm')); if (me && me.kills.length) document.querySelectorAll('.bw').forEach((el) => { const id = el.getAttribute('data-bid'); if (id && me.kills.indexOf(id) >= 0) el.classList.add('rm'); }); };
  const show = (me, ok) => {
    const g = D.ghost; g.style.left = (me.x * (D.cw + D.gap)) + 'px'; g.style.top = (me.y * (D.ch + D.gap)) + 'px'; g.style.width = (me.w * D.cw + (me.w - 1) * D.gap) + 'px'; g.style.height = (me.h * D.ch + (me.h - 1) * D.gap) + 'px'; g.classList.toggle('bad', !ok);
  };
  document.addEventListener('pointerdown', (e) => {
    const h = e.target.closest && e.target.closest('.bres'); if (!h || !ui.bento) return;
    const cv = document.getElementById('bcanvas'), it = ui.bento.find((x) => x.id === h.getAttribute('data-bres')); if (!cv || !it) return;
    const r = cv.getBoundingClientRect(), gap = 14, cw = (r.width - 3 * gap) / 4, ch = (r.height - 2 * gap) / 3, tile = h.parentElement, tr = tile.getBoundingClientRect();
    const ghost = document.createElement('div'); ghost.className = 'bghost'; const live = document.createElement('div'); live.className = 'blive'; cv.appendChild(ghost); cv.appendChild(live);
    D = { it: it, cv: cv, cw: cw, ch: ch, gap: gap, left: tr.left, top: tr.top, ox: tr.left - r.left, oy: tr.top - r.top, tile: tile, ghost: ghost, live: live, cur: it.s };
    tile.classList.add('resizing'); const me = place(it.s); if (me) show(me, true); e.preventDefault();
    try { h.setPointerCapture(e.pointerId); } catch (x) { /* sin captura */ }
  });
  document.addEventListener('pointermove', (e) => {
    if (!D) return; const r = D.cv.getBoundingClientRect(), L = D.live.style;
    L.left = D.ox + 'px'; L.top = D.oy + 'px'; L.width = Math.max(D.cw * .6, e.clientX - D.left) + 'px'; L.height = Math.max(D.ch * .6, e.clientY - D.top) + 'px';
    const k = best(e), me = place(k); if (me) { D.cur = k; show(me, true); mark(me); } else { const m0 = place(D.cur); if (m0) show(m0, false); }
  });
  const end = () => {
    if (!D) return; const d = D; D = null; d.ghost.remove(); d.live.remove(); d.tile.classList.remove('resizing');
    document.querySelectorAll('.bw.rm').forEach((x) => x.classList.remove('rm'));
    if (d.cur !== d.it.s) { const bf = JSON.stringify(ui.bset); const kl = (function () { d.it.s = d.cur; return bentoLayout(ui.bento).filter((x) => x.off).map((x) => x.id); })(); if (kl.length) { ui.bento = ui.bento.filter((x) => kl.indexOf(x.id) < 0); const cc = bcur(); cc.items = ui.bento; toast(kl.length === 1 ? 'Se quitó 1 widget para hacer espacio' : 'Se quitaron ' + kl.length + ' widgets para hacer espacio'); } bPush(BLBL.bnresize, bf.replace('"s":"' + d.cur + '"', '"s":"' + d.cur + '"')); bentoSave(); bentoRender(); }
  };
  document.addEventListener('pointerup', end); document.addEventListener('pointercancel', end);
})();
(function () {
  let G = null;
  const trial = (cx, cy) => {
    const items = ui.bento.map((x) => Object.assign({}, x)), me = items.find((x) => x.id === G.id), mw = BSZ[me.s][0], mh = BSZ[me.s][1]; me.px = cx; me.py = cy;
    items.forEach((x) => { if (x !== me && x.px != null) { const w = BSZ[x.s][0], h = BSZ[x.s][1]; if (x.px < cx + mw && x.px + w > cx && x.py < cy + mh && x.py + h > cy) { delete x.px; delete x.py; } } });
    return { items: items, lay: bentoLayout(items), w: mw, h: mh };
  };
  const mark = (t) => { document.querySelectorAll('.bw.rm').forEach((x) => x.classList.remove('rm')); const kills = t.lay.filter((x) => x.off).map((x) => x.id); document.querySelectorAll('#bcanvas .bw').forEach((el) => { if (kills.indexOf(el.getAttribute('data-bid')) >= 0) el.classList.add('rm'); }); return kills; };
  document.addEventListener('pointerdown', (e) => {
    if (!ui.bnEdit || !ui.bento || e.button) return; const t = e.target.closest && e.target.closest('#bcanvas .bw'); if (!t) return;
    if (e.target.closest('.bctl,.bres,input,button,a,select')) return;
    const cv = document.getElementById('bcanvas'), r = cv.getBoundingClientRect(), tr = t.getBoundingClientRect(), gap = 14;
    G = { el: t, id: t.getAttribute('data-bid'), x: e.clientX, y: e.clientY, on: false, pid: e.pointerId, cv: cv, r: r, tr: tr, gap: gap, cw: (r.width - 3 * gap) / 4, ch: (r.height - 2 * gap) / 3, cell: null, t: null };
  });
  document.addEventListener('pointermove', (e) => {
    if (!G) return; const dx = e.clientX - G.x, dy = e.clientY - G.y;
    if (!G.on) { if (Math.abs(dx) + Math.abs(dy) < 8) return; G.on = true; G.el.classList.add('bdrag'); G.ghost = document.createElement('div'); G.ghost.className = 'bghost'; G.cv.appendChild(G.ghost); try { G.el.setPointerCapture(G.pid); } catch (x) { /* sin captura */ } }
    G.el.style.setProperty('transform', 'translate(' + dx + 'px,' + dy + 'px) scale(1.03)', 'important');
    const it = ui.bento.find((x) => x.id === G.id), w = BSZ[it.s][0], h = BSZ[it.s][1];
    const cx = Math.max(0, Math.min(4 - w, Math.round((G.tr.left + dx - G.r.left) / (G.cw + G.gap)))), cy = Math.max(0, Math.min(3 - h, Math.round((G.tr.top + dy - G.r.top) / (G.ch + G.gap))));
    if (!G.cell || G.cell[0] !== cx || G.cell[1] !== cy) {
      G.cell = [cx, cy]; G.t = trial(cx, cy); mark(G.t); const g = G.ghost.style;
      g.left = cx * (G.cw + G.gap) + 'px'; g.top = cy * (G.ch + G.gap) + 'px'; g.width = (w * G.cw + (w - 1) * G.gap) + 'px'; g.height = (h * G.ch + (h - 1) * G.gap) + 'px';
    }
  });
  const end = () => {
    if (!G) return; const g = G; G = null; if (!g.on) return;
    document.querySelectorAll('.bw.rm').forEach((x) => x.classList.remove('rm')); g.ghost.remove(); g.el.classList.remove('bdrag'); g.el.style.removeProperty('transform');
    if (!g.t) { bentoRender(); return; }
    const before = JSON.stringify(ui.bset), kills = g.t.lay.filter((x) => x.off).map((x) => x.id);
    const cur = ui.bento.find((x) => x.id === g.id); if (cur.px === g.cell[0] && cur.py === g.cell[1] && !kills.length) { bentoRender(); return; }
    ui.bento = g.t.items.filter((x) => kills.indexOf(x.id) < 0); bcur().items = ui.bento;
    if (kills.length) toast(kills.length === 1 ? 'Se quitó 1 widget para hacer espacio' : 'Se quitaron ' + kills.length + ' widgets para hacer espacio');
    bPush('posición', before); bentoSave(); bentoRender();
  };
  document.addEventListener('pointerup', end); document.addEventListener('pointercancel', end);
})();
function bentoNav(d) {
  if (!ui.bset) return; const i = ui.bset.sets.findIndex((x) => x.id === ui.bset.cur), j = i + d; if (j < 0 || j >= ui.bset.sets.length) return;
  ui.bset.cur = ui.bset.sets[j].id; ui.bento = bcur().items; ui.bdir = d; bentoSave(); bentoRender();
}
const BQR = { n: 25, d: 'M0 0h1v1h-1zM1 0h1v1h-1zM2 0h1v1h-1zM3 0h1v1h-1zM4 0h1v1h-1zM5 0h1v1h-1zM6 0h1v1h-1zM11 0h1v1h-1zM13 0h1v1h-1zM14 0h1v1h-1zM15 0h1v1h-1zM18 0h1v1h-1zM19 0h1v1h-1zM20 0h1v1h-1zM21 0h1v1h-1zM22 0h1v1h-1zM23 0h1v1h-1zM24 0h1v1h-1zM0 1h1v1h-1zM6 1h1v1h-1zM10 1h1v1h-1zM11 1h1v1h-1zM13 1h1v1h-1zM14 1h1v1h-1zM15 1h1v1h-1zM16 1h1v1h-1zM18 1h1v1h-1zM24 1h1v1h-1zM0 2h1v1h-1zM2 2h1v1h-1zM3 2h1v1h-1zM4 2h1v1h-1zM6 2h1v1h-1zM10 2h1v1h-1zM12 2h1v1h-1zM15 2h1v1h-1zM18 2h1v1h-1zM20 2h1v1h-1zM21 2h1v1h-1zM22 2h1v1h-1zM24 2h1v1h-1zM0 3h1v1h-1zM2 3h1v1h-1zM3 3h1v1h-1zM4 3h1v1h-1zM6 3h1v1h-1zM11 3h1v1h-1zM12 3h1v1h-1zM14 3h1v1h-1zM18 3h1v1h-1zM20 3h1v1h-1zM21 3h1v1h-1zM22 3h1v1h-1zM24 3h1v1h-1zM0 4h1v1h-1zM2 4h1v1h-1zM3 4h1v1h-1zM4 4h1v1h-1zM6 4h1v1h-1zM10 4h1v1h-1zM11 4h1v1h-1zM12 4h1v1h-1zM13 4h1v1h-1zM14 4h1v1h-1zM15 4h1v1h-1zM18 4h1v1h-1zM20 4h1v1h-1zM21 4h1v1h-1zM22 4h1v1h-1zM24 4h1v1h-1zM0 5h1v1h-1zM6 5h1v1h-1zM8 5h1v1h-1zM10 5h1v1h-1zM13 5h1v1h-1zM15 5h1v1h-1zM18 5h1v1h-1zM24 5h1v1h-1zM0 6h1v1h-1zM1 6h1v1h-1zM2 6h1v1h-1zM3 6h1v1h-1zM4 6h1v1h-1zM5 6h1v1h-1zM6 6h1v1h-1zM8 6h1v1h-1zM10 6h1v1h-1zM12 6h1v1h-1zM14 6h1v1h-1zM16 6h1v1h-1zM18 6h1v1h-1zM19 6h1v1h-1zM20 6h1v1h-1zM21 6h1v1h-1zM22 6h1v1h-1zM23 6h1v1h-1zM24 6h1v1h-1zM10 7h1v1h-1zM11 7h1v1h-1zM12 7h1v1h-1zM14 7h1v1h-1zM15 7h1v1h-1zM16 7h1v1h-1zM0 8h1v1h-1zM3 8h1v1h-1zM5 8h1v1h-1zM6 8h1v1h-1zM8 8h1v1h-1zM9 8h1v1h-1zM10 8h1v1h-1zM11 8h1v1h-1zM12 8h1v1h-1zM13 8h1v1h-1zM14 8h1v1h-1zM17 8h1v1h-1zM19 8h1v1h-1zM3 9h1v1h-1zM4 9h1v1h-1zM7 9h1v1h-1zM8 9h1v1h-1zM12 9h1v1h-1zM13 9h1v1h-1zM14 9h1v1h-1zM16 9h1v1h-1zM17 9h1v1h-1zM18 9h1v1h-1zM24 9h1v1h-1zM1 10h1v1h-1zM2 10h1v1h-1zM3 10h1v1h-1zM6 10h1v1h-1zM7 10h1v1h-1zM10 10h1v1h-1zM12 10h1v1h-1zM13 10h1v1h-1zM17 10h1v1h-1zM19 10h1v1h-1zM20 10h1v1h-1zM23 10h1v1h-1zM24 10h1v1h-1zM1 11h1v1h-1zM4 11h1v1h-1zM5 11h1v1h-1zM7 11h1v1h-1zM8 11h1v1h-1zM9 11h1v1h-1zM10 11h1v1h-1zM13 11h1v1h-1zM14 11h1v1h-1zM15 11h1v1h-1zM19 11h1v1h-1zM20 11h1v1h-1zM1 12h1v1h-1zM3 12h1v1h-1zM4 12h1v1h-1zM6 12h1v1h-1zM7 12h1v1h-1zM9 12h1v1h-1zM12 12h1v1h-1zM14 12h1v1h-1zM17 12h1v1h-1zM18 12h1v1h-1zM19 12h1v1h-1zM21 12h1v1h-1zM23 12h1v1h-1zM24 12h1v1h-1zM3 13h1v1h-1zM7 13h1v1h-1zM8 13h1v1h-1zM11 13h1v1h-1zM12 13h1v1h-1zM17 13h1v1h-1zM18 13h1v1h-1zM19 13h1v1h-1zM21 13h1v1h-1zM22 13h1v1h-1zM24 13h1v1h-1zM0 14h1v1h-1zM2 14h1v1h-1zM3 14h1v1h-1zM5 14h1v1h-1zM6 14h1v1h-1zM7 14h1v1h-1zM12 14h1v1h-1zM17 14h1v1h-1zM18 14h1v1h-1zM19 14h1v1h-1zM20 14h1v1h-1zM22 14h1v1h-1zM24 14h1v1h-1zM1 15h1v1h-1zM2 15h1v1h-1zM3 15h1v1h-1zM7 15h1v1h-1zM8 15h1v1h-1zM12 15h1v1h-1zM13 15h1v1h-1zM15 15h1v1h-1zM20 15h1v1h-1zM23 15h1v1h-1zM0 16h1v1h-1zM1 16h1v1h-1zM3 16h1v1h-1zM4 16h1v1h-1zM6 16h1v1h-1zM7 16h1v1h-1zM9 16h1v1h-1zM10 16h1v1h-1zM11 16h1v1h-1zM13 16h1v1h-1zM14 16h1v1h-1zM16 16h1v1h-1zM17 16h1v1h-1zM18 16h1v1h-1zM19 16h1v1h-1zM20 16h1v1h-1zM21 16h1v1h-1zM22 16h1v1h-1zM8 17h1v1h-1zM10 17h1v1h-1zM14 17h1v1h-1zM15 17h1v1h-1zM16 17h1v1h-1zM20 17h1v1h-1zM21 17h1v1h-1zM24 17h1v1h-1zM0 18h1v1h-1zM1 18h1v1h-1zM2 18h1v1h-1zM3 18h1v1h-1zM4 18h1v1h-1zM5 18h1v1h-1zM6 18h1v1h-1zM9 18h1v1h-1zM13 18h1v1h-1zM15 18h1v1h-1zM16 18h1v1h-1zM18 18h1v1h-1zM20 18h1v1h-1zM21 18h1v1h-1zM23 18h1v1h-1zM24 18h1v1h-1zM0 19h1v1h-1zM6 19h1v1h-1zM8 19h1v1h-1zM9 19h1v1h-1zM10 19h1v1h-1zM11 19h1v1h-1zM13 19h1v1h-1zM16 19h1v1h-1zM20 19h1v1h-1zM21 19h1v1h-1zM22 19h1v1h-1zM23 19h1v1h-1zM0 20h1v1h-1zM2 20h1v1h-1zM3 20h1v1h-1zM4 20h1v1h-1zM6 20h1v1h-1zM9 20h1v1h-1zM11 20h1v1h-1zM12 20h1v1h-1zM14 20h1v1h-1zM16 20h1v1h-1zM17 20h1v1h-1zM18 20h1v1h-1zM19 20h1v1h-1zM20 20h1v1h-1zM21 20h1v1h-1zM24 20h1v1h-1zM0 21h1v1h-1zM2 21h1v1h-1zM3 21h1v1h-1zM4 21h1v1h-1zM6 21h1v1h-1zM8 21h1v1h-1zM9 21h1v1h-1zM10 21h1v1h-1zM11 21h1v1h-1zM12 21h1v1h-1zM13 21h1v1h-1zM19 21h1v1h-1zM20 21h1v1h-1zM21 21h1v1h-1zM22 21h1v1h-1zM0 22h1v1h-1zM2 22h1v1h-1zM3 22h1v1h-1zM4 22h1v1h-1zM6 22h1v1h-1zM9 22h1v1h-1zM11 22h1v1h-1zM12 22h1v1h-1zM13 22h1v1h-1zM14 22h1v1h-1zM17 22h1v1h-1zM19 22h1v1h-1zM20 22h1v1h-1zM22 22h1v1h-1zM24 22h1v1h-1zM0 23h1v1h-1zM6 23h1v1h-1zM9 23h1v1h-1zM10 23h1v1h-1zM11 23h1v1h-1zM12 23h1v1h-1zM13 23h1v1h-1zM15 23h1v1h-1zM16 23h1v1h-1zM17 23h1v1h-1zM21 23h1v1h-1zM0 24h1v1h-1zM1 24h1v1h-1zM2 24h1v1h-1zM3 24h1v1h-1zM4 24h1v1h-1zM5 24h1v1h-1zM6 24h1v1h-1zM8 24h1v1h-1zM9 24h1v1h-1zM11 24h1v1h-1zM14 24h1v1h-1zM15 24h1v1h-1zM16 24h1v1h-1zM18 24h1v1h-1zM19 24h1v1h-1zM23 24h1v1h-1zM24 24h1v1h-1z' };
function bentoShot() {
  const cv = $('#bcanvas'); if (!cv) return; const r = cv.getBoundingClientRect(), W = Math.round(r.width), H = Math.round(r.height), P = 36, CS = getComputedStyle(cv);
  const clone = cv.cloneNode(true), src = [cv].concat(Array.prototype.slice.call(cv.querySelectorAll('*'))), dst = [clone].concat(Array.prototype.slice.call(clone.querySelectorAll('*')));
  src.forEach((el, i) => { const cs = getComputedStyle(el); let t = ''; for (let k = 0; k < cs.length; k++) { const p = cs[k]; t += p + ':' + cs.getPropertyValue(p) + ';'; } dst[i].setAttribute('style', t + 'animation:none;transition:none;' + (i ? '' : 'opacity:1;transform:none;width:' + W + 'px;height:' + H + 'px;')); });
  clone.querySelectorAll('.bslot').forEach((e) => e.remove());
  const bg = getComputedStyle(document.documentElement).getPropertyValue('--wpage').trim() || '#E3F6EC', mute = getComputedStyle(document.documentElement).getPropertyValue('--mute').trim() || '#6B7F73';
  const fw = W + P * 2, fh = H + P * 2 + 78, nm = bcur() ? bcur().name : 'Bento';
  const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="' + fw + '" height="' + fh + '"><foreignObject width="100%" height="100%"><div xmlns="http://www.w3.org/1999/xhtml" style="width:' + fw + 'px;height:' + fh + 'px;background:' + bg + ';padding:' + P + 'px;box-sizing:border-box;font-family:' + CS.fontFamily.replace(/"/g, "'") + '">' + new XMLSerializer().serializeToString(clone) + '<div style="margin-top:16px;display:flex;align-items:center;justify-content:space-between;color:' + mute + '"><div style="display:flex;flex-direction:column;gap:4px;font-size:15px;font-weight:600"><span>' + esc(nm) + '</span><span style="font-weight:500;opacity:.85">Plata · ' + new Date().toLocaleDateString(undefined, { day: 'numeric', month: 'long', year: 'numeric' }) + '</span></div><div style="display:flex;align-items:center;gap:14px"><div style="display:flex;flex-direction:column;align-items:flex-end;gap:6px;font-size:15px;font-weight:700"><span style="display:flex;align-items:center;gap:6px">' + RMI('instagram-line', 18, 'currentColor') + '@plataapp</span><span style="font-weight:500;opacity:.85">plataapp.net</span></div><div style="background:#fff;padding:6px;border-radius:8px;line-height:0"><svg xmlns="http://www.w3.org/2000/svg" width="56" height="56" viewBox="0 0 ' + BQR.n + ' ' + BQR.n + '" shape-rendering="crispEdges"><path fill="#0B1F17" d="' + BQR.d + '"/></svg></div></div></div></div></foreignObject></svg>';
  const img = new Image(), sc = Math.max(1, Math.min(2, 3200 / fw));
  img.onload = () => {
    const c = document.createElement('canvas'); c.width = Math.round(fw * sc); c.height = Math.round(fh * sc); const x = c.getContext('2d'); x.scale(sc, sc); x.drawImage(img, 0, 0);
    try { c.toBlob((bl) => { if (!bl) { toast('No se pudo generar la captura'); return; } const a = document.createElement('a'); a.href = URL.createObjectURL(bl); a.download = (nm || 'Bento').replace(/[^\w\- áéíóúñÁÉÍÓÚÑ]/g, '') + '.png'; document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(a.href), 4000); toast('Captura guardada'); }, 'image/png'); } catch (e) { toast('No se pudo generar la captura'); }
  };
  img.onerror = () => toast('No se pudo generar la captura');
  img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
}
function bentoKey(e) {
  if (e.target && (e.target.tagName === 'INPUT' || e.target.isContentEditable)) return;
  if ((e.ctrlKey || e.metaKey) && !/^(INPUT|TEXTAREA)$/.test((e.target && e.target.tagName) || '') && (e.key.toLowerCase() === 'z' || e.key.toLowerCase() === 'y') && !ui.bPick) { e.preventDefault(); bUndo(e.key.toLowerCase() === 'y' || e.shiftKey); }
  else if (e.key === 'Escape') { if (ui.bnEdit) { ui.bnEdit = false; ui.bnGal = false; bentoRender(); } else closeBento(); }
  else if (!ui.bnEdit && e.key === 'ArrowRight') bentoNav(1); else if (!ui.bnEdit && e.key === 'ArrowLeft') bentoNav(-1);
}
function openBento() {
  BUNDO.u = []; BUNDO.r = [];
  if (!isWebView()) return; closeBento();
  const el = document.createElement('div'); el.id = 'bento'; el.className = 'bento'; deviceEl.appendChild(el); ui.bnGal = false; ui.bnEdit = false; ui.bPick = false; bentoLoadAll(); bentoRender();
  document.addEventListener('keydown', bentoKey); document.documentElement.classList.add('bnopen');
}
window.addEventListener('resize', () => { if (document.getElementById('bento')) { clearTimeout(window._bz); window._bz = setTimeout(bentoRender, 150); } });
function closeBento() { document.documentElement.classList.remove('bnopen'); ui.bPick = false; const el = $('#bento'); if (el) el.remove(); document.removeEventListener('keydown', bentoKey); }


/* Deslizar movimientos (solo móvil): uno abierto a la vez */
const SW = { el: null, x0: 0, y0: 0, base: 0, drag: false, moved: false, id: null };
const swW = (r) => (r.closest('.swrow') ? r.closest('.swrow').querySelector('.swacts').offsetWidth + 18 : 0);
function swClose(except) { document.querySelectorAll('.swc.open').forEach((c) => { if (c !== except) { c.classList.remove('open'); c.style.transform = ''; } }); }
document.addEventListener('pointerdown', (e) => {
  if (isWebView()) return; const c = e.target.closest && e.target.closest('.swc');
  if (!c) { SW.moved = false; swClose(); return; }
  swClose(c); SW.el = c; SW.x0 = e.clientX; SW.y0 = e.clientY; SW.base = c.classList.contains('open') ? -swW(c) : 0; SW.drag = false; SW.moved = false; SW.id = e.pointerId;
}, true);
document.addEventListener('pointermove', (e) => {
  const c = SW.el; if (!c || e.pointerId !== SW.id) return; const dx = e.clientX - SW.x0, dy = e.clientY - SW.y0;
  if (!SW.drag) { if (Math.abs(dx) > 8 && Math.abs(dx) > Math.abs(dy) * 1.4) { SW.drag = true; SW.moved = true; c.classList.add('sd'); try { c.setPointerCapture(e.pointerId); } catch (x) { /* */ } } else if (Math.abs(dy) > 10) { SW.el = null; return; } else return; }
  const W = swW(c); let x = SW.base + dx; if (x > 0) x = x * 0.25; else if (x < -W) x = -W + (x + W) * 0.25; c.style.transform = 'translateX(' + x + 'px)';
}, true);
function swEnd(e) {
  const c = SW.el; if (!c || (e && e.pointerId !== SW.id)) return; SW.el = null; if (!SW.drag) return; c.classList.remove('sd');
  const m = /translateX\((-?[\d.]+)px\)/.exec(c.style.transform), x = m ? Number(m[1]) : 0, W = swW(c), open = x < -W * 0.4 && (SW.base === 0 || x < -W * 0.6);
  c.classList.toggle('open', open); c.style.transform = open ? 'translateX(' + -W + 'px)' : '';
}
document.addEventListener('pointerup', swEnd, true); document.addEventListener('pointercancel', swEnd, true);
document.addEventListener('click', (e) => {
  const c = e.target.closest && e.target.closest('.swc'); if (!c) return;
  if (SW.moved) { SW.moved = false; e.stopPropagation(); e.preventDefault(); return; }
  if (c.classList.contains('open')) { e.stopPropagation(); e.preventDefault(); swClose(); }
}, true);
function pxAct(a, arg) {
  const q = arg.split(':'), k = q[0], id = q.slice(1).join(':'); swClose(); ctxClose();
  if (a === 'pxconf') { ui.itemKind = k; ui.itemId = id; ui.confirmPick = { k: k === 'expense' ? 'out' : 'in', id: id }; ui.skipPending = false; const h = confirmHTML(); if (h) showSheet(h); }
  else if (a === 'pxedit') { if (k === 'acct' || k === 'saving') { const isA = data.accounts.some((x) => x.id === id), isS = data.savings.some((x) => x.id === id); openForm(isS ? 'saving' : isA ? 'account' : 'debt', id); } else openForm(k, id); }
  else if (a === 'pxdel') { ui.itemBack = { tab: ui.tab, prev: ui.prevTab }; ui.itemKind = k; ui.itemId = id; ui.itemDel = false; itemDelete(); }
  else if (a === 'pxadd') { openSheet(); ui.sheetAcc = id; ui.sheetCard = data.cards.some((c) => c.id === id) ? id : null; showSheet(sheetHTML()); }
  else if (a === 'pxhide') { const ob = data.accounts.find((x) => x.id === id) || data.cards.find((x) => x.id === id); if (ob) { ob.hid = !ob.hid; ui.dirty++; persist(); renderAll(); toast(ob.hid ? 'Oculta del resumen' : 'Visible en el resumen'); } }
  else if (a === 'pxcontrib') { openForm('contrib'); if (ui.form && ui.form.kind === 'contrib') { ui.form.obj.sav = id; showSheet(formHTML()); } }
}
function swCtx(id) { ui.txBack = { tab: ui.tab, acctId: ui.acctId, prev: ui.prevTab, month: ui.tab === 'cuenta' && ui.itemKind === 'month' && ui.itemId != null }; ui.txId = id; ui.txDel = false; }
function swAct(a, id) {
  const t = txById(id); if (!t) return; swClose();
  if (a === 'swedit') { swCtx(id); ui.form = null; ui.confirmId = null; showSheet(txEditHTML(t)); }
  else if (a === 'swpost') { if (isPay(t)) return; swCtx(id); ui.txEditId = t.id; ui.form = null; ui.confirmId = null; showSheet(postponeHTML(t)); }
  else if (a === 'swdel') { swCtx(id); txDelete(); }
}

document.addEventListener('contextmenu', (e) => {
  const r = isWebView() && e.target.closest && e.target.closest('.row[data-ctx]'); if (!r) return; e.preventDefault();
  if (r.getAttribute('data-ctx') === 'x') {
    const q = (r.getAttribute('data-act') || '').split(':'), acts = PX_ACTS(q[1], q[2]); if (!acts) return; ctxClose();
    const m = document.createElement('div'); m.className = 'ctxm';
    m.innerHTML = acts.map((a) => '<button' + (a[0] === 'pxdel' ? ' class="dg"' : '') + ' data-act="' + a[0] + ':' + q[1] + ':' + q[2] + '">' + RMI(a[3], 18, 'currentColor') + a[1] + '</button>').join('');
    document.body.appendChild(m); const w = m.offsetWidth, h = m.offsetHeight; m.style.left = Math.min(e.clientX, innerWidth - w - 8) + 'px'; m.style.top = Math.min(e.clientY, innerHeight - h - 8) + 'px'; return;
  }
  const id = (r.getAttribute('data-act') || '').split(':')[1], pay = r.getAttribute('data-ctx') === 'p'; ctxClose();
  const m = document.createElement('div'); m.className = 'ctxm';
  m.innerHTML = '<button data-act="swedit:' + id + '">' + RMI('edit-line', 18, 'currentColor') + 'Editar</button>' + (pay ? '' : '<button data-act="swpost:' + id + '">' + RMI('calendar-event-line', 18, 'currentColor') + 'Posponer</button>') + '<button class="dg" data-act="swdel:' + id + '">' + RMI('delete-bin-line', 18, 'currentColor') + 'Eliminar</button>';
  document.body.appendChild(m); const w = m.offsetWidth, h = m.offsetHeight; m.style.left = Math.min(e.clientX, innerWidth - w - 8) + 'px'; m.style.top = Math.min(e.clientY, innerHeight - h - 8) + 'px';
});
document.addEventListener('contextmenu', (e) => {
  if (!isWebView() || e.defaultPrevented) return; const tg = e.target;
  if (tg && tg.closest && tg.closest('input,textarea,select,[contenteditable="true"]')) return;
  e.preventDefault();
});
function ctxClose() { document.querySelectorAll('.ctxm').forEach((x) => x.remove()); }
/* Calendario propio en escritorio: reemplaza el selector de fecha nativo */
(function () {
  let pop = null, cur = null, view = null, hot = null;
  const isW = () => document.documentElement.classList.contains('web');
  const close = () => { if (pop) { pop.remove(); pop = null; cur = null; } };
  const pad = (n) => (n < 10 ? '0' : '') + n;
  const key = (y, m, d) => y + '-' + pad(m + 1) + '-' + pad(d);
  const lang = () => { try { return String(resolveLang() || 'es'); } catch (e) { return 'es'; } };
  const HOY = { es: 'Hoy', en: 'Today', ja: '今日', it: 'Oggi', fr: "Aujourd'hui", hr: 'Danas' };
  const parse = (v) => { const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(v || ''); return m ? { y: +m[1], m: +m[2] - 1, d: +m[3] } : null; };
  const draw = () => {
    if (!pop || !cur) return;
    const L = lang(), mon0 = !(L === 'en' || L === 'ja'), sel = parse(cur.value), td = new Date();
    const first = new Date(view.y, view.m, 1), start = (first.getDay() + (mon0 ? 6 : 0)) % 7, dim = new Date(view.y, view.m + 1, 0).getDate();
    let title = ''; try { title = new Intl.DateTimeFormat(L, { month: 'long', year: 'numeric' }).format(first); } catch (e) { title = (view.m + 1) + '/' + view.y; }
    title = title.charAt(0).toUpperCase() + title.slice(1);
    let wd = ''; for (let i = 0; i < 7; i++) { let n = ''; try { n = new Intl.DateTimeFormat(L, { weekday: 'narrow' }).format(new Date(2024, 0, 1 + ((i + (mon0 ? 0 : 6)) % 7))); } catch (e) { n = '·'; } wd += '<span>' + n + '</span>'; }
    const mn = cur.min || '', mx = cur.max || '';
    let cells = '';
    for (let i = 0; i < 42; i++) {
      const dt = new Date(view.y, view.m, 1 - start + i), k = key(dt.getFullYear(), dt.getMonth(), dt.getDate()), out = dt.getMonth() !== view.m;
      const dis = (mn && k < mn) || (mx && k > mx);
      cells += '<button type="button" class="cp-d' + (out ? ' out' : '') + (sel && sel.y === dt.getFullYear() && sel.m === dt.getMonth() && sel.d === dt.getDate() ? ' on' : '') + (k === key(td.getFullYear(), td.getMonth(), td.getDate()) ? ' td' : '') + (hot === k ? ' hot' : '') + '"' + (dis ? ' disabled' : '') + ' data-k="' + k + '">' + dt.getDate() + '</button>';
    }
    const ch = (d) => RMI(d, 20, 'currentColor');
    pop.innerHTML = '<div class="cp-h"><b>' + title + '</b><span><button type="button" class="cp-n" data-n="-1" aria-label="‹">' + ch('arrow-left-s-line') + '</button><button type="button" class="cp-n" data-n="1" aria-label="›">' + ch('arrow-right-s-line') + '</button></span></div><div class="cp-w">' + wd + '</div><div class="cp-g">' + cells + '</div><div class="cp-f"><button type="button" class="cp-t">' + (HOY[L] || HOY.es) + '</button></div>';
  };
  const pick = (k) => { if (!cur) return; const el = cur; el.value = k; el.dispatchEvent(new Event('input', { bubbles: true })); el.dispatchEvent(new Event('change', { bubbles: true })); close(); };
  const open = (el) => {
    close(); cur = el; const s = parse(el.value) || (() => { const t = new Date(); return { y: t.getFullYear(), m: t.getMonth(), d: t.getDate() }; })();
    view = { y: s.y, m: s.m }; hot = key(s.y, s.m, s.d);
    const p = document.createElement('div'); p.className = 'selpop calpop'; pop = p;
    p.addEventListener('mousedown', (e) => { e.preventDefault(); e.stopPropagation(); });
    p.addEventListener('click', (e) => {
      e.stopPropagation(); const n = e.target.closest('.cp-n'), d = e.target.closest('.cp-d'), t = e.target.closest('.cp-t');
      if (n) { const v = new Date(view.y, view.m + Number(n.dataset.n), 1); view = { y: v.getFullYear(), m: v.getMonth() }; draw(); }
      else if (d && !d.disabled) pick(d.dataset.k);
      else if (t) { const x = new Date(); pick(key(x.getFullYear(), x.getMonth(), x.getDate())); }
    });
    document.body.appendChild(p); draw();
    const r = el.getBoundingClientRect(), w = 288, vw = window.innerWidth, vh = window.innerHeight, h = p.offsetHeight;
    p.style.width = w + 'px'; p.style.left = Math.max(8, Math.min(r.left, vw - w - 8)) + 'px';
    if (vh - r.bottom - 12 >= h || r.top < h) p.style.top = Math.max(8, Math.min(r.bottom + 6, vh - h - 8)) + 'px'; else p.style.top = (r.top - h - 6) + 'px';
  };
  document.addEventListener('mousedown', (e) => {
    if (!isW()) return;
    const el = e.target.closest && e.target.closest('input[type=date]');
    if (el && !el.disabled && !el.readOnly) { e.preventDefault(); el.focus(); if (cur === el) close(); else open(el); return; }
    if (pop && !e.target.closest('.calpop')) close();
  }, true);
  document.addEventListener('keydown', (e) => {
    if (!isW()) return;
    const el = e.target && e.target.matches && e.target.matches('input[type=date]') ? e.target : null;
    if (!pop) { if (el && (e.key === 'Enter' || e.key === ' ')) { e.preventDefault(); open(el); } return; }
    if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); close(); return; }
    const mv = { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -7, ArrowDown: 7 }[e.key];
    if (mv) { e.preventDefault(); const h = parse(hot), nd = new Date(h.y, h.m, h.d + mv); hot = key(nd.getFullYear(), nd.getMonth(), nd.getDate()); view = { y: nd.getFullYear(), m: nd.getMonth() }; draw(); }
    else if (e.key === 'Enter') { e.preventDefault(); pick(hot); }
  }, true);
  window.addEventListener('resize', close); document.addEventListener('scroll', (e) => { if (pop && !(e.target.closest && e.target.closest('.calpop'))) close(); }, true);
})();
/* Desplegables propios en escritorio: reemplazan el menú nativo del <select> */
(function () {
  let pop = null, cur = null, act = -1;
  const isW = () => document.documentElement.classList.contains('web');
  const close = () => { if (pop) { pop.remove(); pop = null; cur = null; act = -1; } };
  const items = () => (pop ? Array.prototype.slice.call(pop.querySelectorAll('.sp-i')) : []);
  const mark = (i) => { const l = items(); act = Math.max(0, Math.min(l.length - 1, i)); l.forEach((x, j) => x.classList.toggle('hot', j === act)); if (l[act]) l[act].scrollIntoView({ block: 'nearest' }); };
  const pick = (sel, v) => { sel.value = v; sel.dispatchEvent(new Event('input', { bubbles: true })); sel.dispatchEvent(new Event('change', { bubbles: true })); close(); };
  const open = (sel) => {
    close(); cur = sel;
    const sr = sel.getBoundingClientRect(), p = document.createElement('div'); p.className = 'selpop'; p.setAttribute('role', 'listbox');
    Array.prototype.forEach.call(sel.children, (n) => {
      const add = (o, ind) => { const d = document.createElement('div'); d.className = 'sp-i' + (o.selected ? ' on' : '') + (ind ? ' ind' : ''); d.setAttribute('role', 'option'); d.dataset.v = o.value; const t = document.createElement('span'); t.textContent = o.textContent; d.appendChild(t); if (o.selected) d.insertAdjacentHTML('beforeend', RMI('check-line', 18, 'currentColor')); if (o.disabled) d.classList.add('dis'); p.appendChild(d); };
      if (n.tagName === 'OPTGROUP') { const h = document.createElement('div'); h.className = 'sp-g'; h.textContent = n.label; p.appendChild(h); Array.prototype.forEach.call(n.children, (o) => add(o, true)); } else if (n.tagName === 'OPTION') add(n, false);
    });
    p.addEventListener('mousedown', (e) => { e.preventDefault(); e.stopPropagation(); });
    p.addEventListener('click', (e) => { e.stopPropagation(); const d = e.target.closest('.sp-i'); if (d && !d.classList.contains('dis')) pick(sel, d.dataset.v); });
    p.addEventListener('mousemove', (e) => { const d = e.target.closest('.sp-i'); if (d) { const l = items(); act = l.indexOf(d); l.forEach((x, j) => x.classList.toggle('hot', j === act)); } });
    document.body.appendChild(p); pop = p;
    const w = Math.max(sr.width, 200), vw = window.innerWidth, vh = window.innerHeight;
    let left = sr.width < 200 && sr.right > vw / 2 ? sr.right - w : sr.left; left = Math.max(8, Math.min(left, vw - w - 8));
    p.style.width = w + 'px'; p.style.left = left + 'px';
    const below = vh - sr.bottom - 12, above = sr.top - 12, h = Math.min(p.scrollHeight, 340);
    if (below >= h || below >= above) { p.style.top = (sr.bottom + 6) + 'px'; p.style.maxHeight = Math.min(340, below) + 'px'; } else { p.style.maxHeight = Math.min(340, above) + 'px'; p.style.bottom = (vh - sr.top + 6) + 'px'; }
    const on = p.querySelector('.sp-i.on'); mark(on ? items().indexOf(on) : 0); if (on) on.scrollIntoView({ block: 'center' });
  };
  document.addEventListener('mousedown', (e) => {
    if (!isW()) return;
    const s = e.target.closest && e.target.closest('select');
    if (s && !s.disabled) { e.preventDefault(); if (cur === s) close(); else open(s); return; }
    if (pop && !e.target.closest('.selpop')) close();
  }, true);
  document.addEventListener('keydown', (e) => {
    if (!pop) return;
    if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); close(); }
    else if (e.key === 'ArrowDown') { e.preventDefault(); mark(act + 1); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); mark(act - 1); }
    else if (e.key === 'Enter') { e.preventDefault(); const d = items()[act]; if (d && cur) pick(cur, d.dataset.v); }
  }, true);
  window.addEventListener('resize', close); document.addEventListener('scroll', (e) => { if (pop && !(e.target.closest && e.target.closest('.selpop'))) close(); }, true);
})();

document.addEventListener('click', () => setTimeout(ctxClose, 0), true); document.addEventListener('keydown', (e) => { if (e.key === 'Escape') ctxClose(); }); document.addEventListener('scroll', ctxClose, true);
/* Flujo de scroll Resumen ↔ Bentos (escritorio): "crujido" de 3 giros + profundidad */
const FLOW = { acc: 0, last: 0, lock: 0, lm: 0, idle: 0 };
const flowMode = () => { const m = data && data.settings && data.settings.bflow; return m === 'before' || m === 'off' ? m : 'after'; };
const flowDir = () => (flowMode() === 'before' ? -1 : 1);
const flowIdx = () => (ui.bset ? Math.max(0, ui.bset.sets.findIndex((x) => x.id === ui.bset.cur)) : 0);
function flowEl(cls) { let e = $('.' + cls); if (!e) { e = document.createElement('div'); e.className = cls; deviceEl.appendChild(e); } e.classList.remove('up', 'dn'); e.classList.add(flowDir() > 0 ? 'up' : 'dn'); return e; }
function flowMeter(n) {
  const e = flowEl('fmeter'); const txt = n === 1 ? 'Dos más' : n === 2 ? 'Una más' : 'Sigue deslizando';
  e.innerHTML = '<span>' + txt + '</span><i class="' + (n > 0 ? 'on' : '') + '"></i><i class="' + (n > 1 ? 'on' : '') + '"></i><i class="' + (n > 2 ? 'on' : '') + '"></i>';
  requestAnimationFrame(() => e.classList.add('on'));
}
function flowReset() {
  FLOW.acc = 0; const e = $('.fmeter'); if (e) { e.classList.remove('on'); setTimeout(() => { if (!e.classList.contains('on')) e.remove(); }, 300); }
  const pk = $('.fpeek'); if (pk) { pk.style.height = '0'; setTimeout(() => { if (pk.style.height === '0px') pk.remove(); }, 300); }
  const m = $('main'); if (m && !$('#bento')) { m.style.transition = 'translate .3s cubic-bezier(.2,.9,.25,1)'; m.style.translate = ''; }
}
function flowRecede(on, ms) {
  const m = $('main'); if (!m) return; const d = flowDir();
  m.style.transition = 'transform ' + ms + 'ms cubic-bezier(.2,.9,.25,1),filter ' + ms + 'ms,opacity ' + ms + 'ms,translate ' + ms + 'ms';
  m.style.translate = ''; m.style.transform = on ? 'scale(.93) translateY(' + (-2 * d) + '%)' : ''; m.style.filter = on ? 'blur(3px) brightness(.92)' : ''; m.style.opacity = on ? '.6' : '';
  if (!on) setTimeout(() => { if (!$('#bento')) { m.style.transition = ''; m.style.filter = ''; m.style.transform = ''; } }, ms + 40);
}
const FLOW_EASE = 'cubic-bezier(.2,.9,.25,1)';
function flowShadow(el) { const d = flowDir(); el.style.boxShadow = d > 0 ? '0 -18px 50px -10px rgba(5,25,15,.28)' : '0 18px 50px -10px rgba(5,25,15,.28)'; el.style.borderRadius = '26px'; }
function flowOpen() {
  if (!ui.bset) bentoLoadAll(); const d = flowDir(); bentoLoadAll(); ui.bset.cur = ui.bset.sets[0].id; ui.bento = bcur().items; flowReset();
  openBento(); const el = $('#bento'); if (!el) return; el.style.animation = 'none'; flowShadow(el);
  el.animate([{ transform: 'translateY(' + 100 * d + '%)' }, { transform: 'none' }], { duration: 560, easing: FLOW_EASE }); flowRecede(true, 560);
}
function flowClose() {
  const el = $('#bento'); if (!el) return; const d = flowDir(); const mn = $('main'); if (mn) { mn.style.scrollBehavior = 'auto'; mn.scrollTop = 0; mn.style.scrollBehavior = ''; } flowShadow(el); flowRecede(false, 520);
  const a = el.animate([{ transform: 'none' }, { transform: 'translateY(' + 100 * d + '%)' }], { duration: 480, easing: FLOW_EASE, fill: 'forwards' });
  a.onfinish = () => { if (el === $('#bento')) closeBento(); const m = $('main'); if (m) { m.style.transition = ''; m.style.filter = ''; m.style.transform = ''; m.style.opacity = ''; } };
}
function flowStep(k, dir) { // salta entre bentos fijados con profundidad
  const old = $('#bento'); if (!old) return; const ghost = old.cloneNode(true); ghost.removeAttribute('id'); ghost.style.zIndex = 119; ghost.style.animation = 'none'; ghost.style.pointerEvents = 'none'; deviceEl.appendChild(ghost);
  ui.bset.cur = ui.bset.sets[k].id; ui.bento = bcur().items; ui.bdir = 0; bentoSave(); bentoRender();
  const el = $('#bento'), d = dir, fwd = dir === flowDir();
  el.style.animation = 'none'; flowShadow(el);
  if (fwd) { ghost.animate([{ transform: 'none', filter: 'none' }, { transform: 'scale(.93)', filter: 'blur(3px) brightness(.92)', opacity: .6 }], { duration: 560, easing: FLOW_EASE, fill: 'forwards' }); el.animate([{ transform: 'translateY(' + 100 * d + '%)' }, { transform: 'none' }], { duration: 560, easing: FLOW_EASE }); }
  else { el.style.zIndex = 119; ghost.style.zIndex = 121; flowShadow(ghost); el.animate([{ transform: 'scale(.93)', filter: 'blur(3px) brightness(.92)' }, { transform: 'none', filter: 'none' }], { duration: 520, easing: FLOW_EASE }); ghost.animate([{ transform: 'none' }, { transform: 'translateY(' + 100 * -d + '%)' }], { duration: 520, easing: FLOW_EASE, fill: 'forwards' }); }
  setTimeout(() => { ghost.remove(); el.style.zIndex = ''; }, 600);
}
function flowCanScroll(t, dy, stop) {
  for (let e = t; e && e !== stop && e.nodeType === 1; e = e.parentElement) {
    const oy = getComputedStyle(e).overflowY; if ((oy === 'auto' || oy === 'scroll') && e.scrollHeight > e.clientHeight + 1) { if (dy > 0 ? e.scrollTop + e.clientHeight < e.scrollHeight - 2 : e.scrollTop > 1) return true; }
  }
  return false;
}
document.addEventListener('scroll', () => { FLOW.lm = performance.now(); }, true);
document.addEventListener('wheel', (e) => {
  if (!isWebView() || flowMode() === 'off' || e.ctrlKey || !data || !data.settings) return;
  let dy = e.deltaY; if (e.deltaMode === 1) dy *= 16; else if (e.deltaMode === 2) dy *= 600; if (Math.abs(dy) < 1 || Math.abs(e.deltaX) > Math.abs(e.deltaY)) return;
  const d = flowDir(), bn = $('#bento'), now = performance.now(), away = dy * d > 0;
  let go = null;
  if (bn) {
    if (ui.bnEdit || ui.bPick || ui.bnGal || $('.bdrag') || $('#sheet.show') || e.target.closest('.bpop,.bmodal,input,select,textarea')) return;
    const k = flowIdx(), pin = k < 2 && k < ui.bset.sets.length;
    if (away) { if (pin && k + 1 < Math.min(2, ui.bset.sets.length)) go = () => flowStep(k + 1, d); else { e.preventDefault(); return; } }
    else go = (!pin || k === 0) ? flowClose : () => flowStep(k - 1, -d);
  } else {
    const m = $('main'), cu = $('#s-cuenta'); if (!m || !away || !m.contains(e.target) || $('#sheet.show') || $('.welcome') || (cu && getComputedStyle(cu).display !== 'none')) return;
    if (flowCanScroll(e.target, dy, m.parentElement)) return;
    if (d > 0 ? m.scrollTop + m.clientHeight < m.scrollHeight - 2 : m.scrollTop > 1) return;
    go = flowOpen;
  }
  e.preventDefault();
  if (now < FLOW.lock || now - FLOW.lm < 160) return;
  if (now - FLOW.last > 600) FLOW.acc = 0;
  FLOW.last = now; FLOW.acc += Math.abs(dy);
  const n = Math.min(3, Math.floor(FLOW.acc / 100));
  try { localStorage.setItem('plata.flowhint', '1'); } catch (x) { /* sin almacenamiento */ } const h = $('.fhint'); if (h) { h.classList.remove('on'); setTimeout(() => h.remove(), 300); }
  if (n >= 3) { FLOW.acc = 0; FLOW.lock = now + 850; flowReset(); go(); return; }
  if (n > 0) {
    flowMeter(n);
    if (!bn) { const m = $('main'); m.style.transition = 'translate .2s ' + FLOW_EASE; m.style.translate = '0 ' + (-n * 9 * d) + 'px'; const pk = flowEl('fpeek'); pk.style.height = n * 12 + 'px'; }
  }
  clearTimeout(FLOW.idle); FLOW.idle = setTimeout(flowReset, 600);
}, { passive: false });
function flowHint() {
  let seen = false; try { seen = !!localStorage.getItem('plata.flowhint'); } catch (x) { /* */ }
  if (seen || !isWebView() || flowMode() === 'off' || !data || !data.settings || $('#bento') || $('.welcome') || !$('main')) return false;
  const e = flowEl('fhint'); e.innerHTML = RMI('arrow-down-line', 16, 'currentColor') + '<span>' + (flowDir() > 0 ? 'Desliza hacia abajo para ver tu Bento' : 'Desliza hacia arriba para ver tu Bento') + '</span>';
  requestAnimationFrame(() => e.classList.add('on')); try { localStorage.setItem('plata.flowhint', '1'); } catch (x) { /* */ }
  setTimeout(() => { e.classList.remove('on'); setTimeout(() => e.remove(), 400); }, 7000); return true;
}
(function () { let n = 0; const iv = setInterval(() => { if (++n > 24 || flowHint()) clearInterval(iv); }, 2000); })();
const BUNDO = { u: [], r: [] };
const BLBL = { bncolor: 'color del widget', bndel: 'widget quitado', bnadd: 'widget añadido', bnsize: 'tamaño', bnmove: 'orden', bnpick: 'Bento nuevo', bnreset: 'restablecer', bnpreset: 'plantilla', bndelset: 'Bento eliminado', bnresize: 'tamaño' };
function bPush(lbl, before) { BUNDO.u.push({ s: before, l: lbl }); if (BUNDO.u.length > 60) BUNDO.u.shift(); BUNDO.r = []; }
function bRestore(snap) { ui.bset = JSON.parse(snap); ui.bento = bcur().items; bentoSave(); bentoRender(); }
function bUndo(redo) {
  const from = redo ? BUNDO.r : BUNDO.u, to = redo ? BUNDO.u : BUNDO.r, e = from.pop();
  if (!e) { toast(redo ? 'Nada que rehacer' : 'Nada que deshacer'); return; }
  to.push({ s: JSON.stringify(ui.bset), l: e.l }); bRestore(e.s); toast((redo ? 'Rehecho: ' : 'Deshecho: ') + e.l);
}
const BUNDO_ICO = (back) => RMI(back ? 'arrow-go-back-line' : 'arrow-go-forward-line', 18, 'currentColor');
const bUndoBtns = () => '<button class="bbtn" data-act="bundo" aria-label="Deshacer" title="Deshacer (Ctrl+Z)"' + (BUNDO.u.length ? '' : ' disabled style="opacity:.4"') + '>' + BUNDO_ICO(true) + '</button><button class="bbtn" data-act="bredo" aria-label="Rehacer" title="Rehacer (Ctrl+Shift+Z)"' + (BUNDO.r.length ? '' : ' disabled style="opacity:.4"') + '>' + BUNDO_ICO(false) + '</button>';
function bentoAct(a, arg) {
  if (a === 'bundo') { bUndo(false); return; }
  if (a === 'bredo') { bUndo(true); return; }
  const before = BLBL[a] && ui.bset ? JSON.stringify(ui.bset) : null;
  bentoAct0(a, arg);
  if (before && ui.bset && JSON.stringify(ui.bset) !== before) { bPush(BLBL[a], before); bentoRender(); }
}
function bentoAct0(a, arg) {
  const q = (arg || '').split(':'), items = ui.bento || (ui.bento = bentoLoad());
  if (a === 'bnopen') openBento();
  else if (a === 'bnset') { const t = ui.bset.sets.find((x) => x.id === q[0]); if (t) { const i0 = ui.bset.sets.findIndex((x) => x.id === ui.bset.cur), i1 = ui.bset.sets.indexOf(t); ui.bdir = i1 > i0 ? 1 : i1 < i0 ? -1 : 0; ui.bset.cur = t.id; ui.bento = t.items; bentoSave(); bentoRender(); } }
  else if (a === 'bndelset') { if (ui.bset.sets.length < 2) return; const c = bcur(); askDelete(c.name, () => { ui.bset.sets = ui.bset.sets.filter((x) => x.id !== c.id); ui.bset.cur = ui.bset.sets[0].id; ui.bento = bcur().items; bentoSave(); bentoRender(); }); }
  else if (a === 'bnclose') closeBento();
  else if (a === 'bnedit') { ui.bnEdit = true; bentoRender(); }
  else if (a === 'bnview') { ui.bnEdit = false; ui.bnGal = false; bentoRender(); }
  else if (a === 'bnnav') bentoNav(Number(q[0]));
  else if (a === 'bnshot') bentoShot();
  else if (a === 'bngal') { ui.bnGal = !ui.bnGal; bentoRender(); }
  else if (a === 'bnplus') { ui.bPick = !ui.bPick; bentoRender(); }
  else if (a === 'bnpick') { const P = BENTO_PRE.find((x) => x.id === q[0]); if (P) { const id = 'b' + Date.now().toString(36); ui.bset.sets.push({ id: id, name: bentoUnique(bentoBase(), id), items: P.items.map((x) => ({ id: x[0], s: x[1] })) }); ui.bset.cur = id; ui.bento = bcur().items; ui.bPick = false; ui.bdir = 1; if (P.empty) { ui.bnEdit = true; ui.bnGal = true; } bentoSave(); bentoRender(); } }
  else if (a === 'bncolor') { const it = items.find((x) => x.id === q[0]); if (it) { it.c = ((it.c || 0) + 1) % 6; if (!it.c) delete it.c; bentoSave(); bentoRender(); } }
  else if (a === 'bnpreset') { const P = BENTO_PRE.find((x) => x.id === q[0]); if (P) { ui.bento = P.items.map((x) => ({ id: x[0], s: x[1] })); bentoSave(); bentoRender(); } }
  else if (a === 'bnreset') { ui.bento = BENTO_DEF.map((x) => Object.assign({}, x)); bentoSave(); bentoRender(); }
  else if (a === 'bndel') { ui.bento = items.filter((x) => x.id !== q[0]); bentoSave(); bentoRender(); }
  else if (a === 'bnadd') {
    const W = BW[q[0]]; if (!W || items.some((x) => x.id === q[0])) return;
    const order = W.sizes.slice().sort((x, y) => (x === W.sizes[0] ? -1 : y === W.sizes[0] ? 1 : BSZ[x][0] * BSZ[x][1] - BSZ[y][0] * BSZ[y][1]));
    const z = order.find((s) => bfits(items.concat([{ id: q[0], s: s }])));
    if (!z) { toast('No cabe: quita o achica otro widget'); return; }
    items.push({ id: q[0], s: z }); bentoSave(); bentoRender();
  } else if (a === 'bnsize') {
    const it = items.find((x) => x.id === q[0]); if (!it) return; const zs = bsorted(BW[it.id]), ni = zs.indexOf(it.s) + Number(q[1]); if (ni < 0 || ni >= zs.length) return; const old = it.s; it.s = zs[ni];
    if (!bfits(items)) { it.s = old; toast('No cabe: quita o achica otro widget'); return; }
    bentoSave(); bentoRender();
  } else if (a === 'bnmove') {
    const i = items.findIndex((x) => x.id === q[0]), j = i + Number(q[1]); if (i < 0 || j < 0 || j >= items.length) return; items.forEach((x) => { delete x.px; delete x.py; });
    const t = items[i]; items[i] = items[j]; items[j] = t;
    if (!bfits(items)) { items[j] = items[i]; items[i] = t; toast('No cabe en ese orden'); return; }
    bentoSave(); bentoRender();
  }
}

(function(){ const b = $('#wbento'); if (b) b.innerHTML = RMI('layout-grid-line', 18, 'currentColor') + '<span class="wbl">Bentos</span>'; })();

/* Enlace directo a un perfil de demostración (ej. app/?demo=alessandro&lang=es). No toca datos reales: la demo guarda una copia y se restaura al salir. */
(function () {
  const m = /[?&]demo=([a-z]+)/.exec(location.search); if (!m || !DEMO_PROFILES[m[1]]) return;
  try { loadDemo(m[1]); const l = /[?&]lang=([a-z]{2})/.exec(location.search); if (l && data && data.settings) { data.settings.lang = l[1]; persist(); } wMark(true); newsMark(); navNoteMark(); } catch (e) { /* si falla, abre la app normal */ }
})();
applyLang(); renderAll(); setTab('resumen'); movePill(true);
if (!hasData() && !wSeen() && (!/[?&]nosplash/.test(location.search) || /[?&]welcome/.test(location.search))) { showWelcome(); } else setTimeout(checkPending, 2300);
seasonPlay();
document.addEventListener('visibilitychange', () => { if (!document.hidden) { ui.skipPending = false; updatePendingDot(); checkPending(); } });
if (document.fonts && document.fonts.ready) document.fonts.ready.then(() => movePill(true));

if ('serviceWorker' in navigator && /^https?:/.test(location.protocol)) { window.addEventListener('load', () => { navigator.serviceWorker.register('sw.js').catch(() => {}); }); }
/* Interruptores: mantiene el vidrio al cambiar de estado y se asienta suave */
document.addEventListener('click', (e) => {
  const b = e.target.closest && e.target.closest('.sw2'); if (!b || b.classList.contains('dis')) return;
  const act = b.getAttribute('data-act'), was = b.classList.contains('on');
  const n = b.isConnected ? b : document.querySelector('.sw2[data-act="' + act + '"]'); if (!n) return;
  n.classList.add(was ? 'fl-on' : 'fl-off'); void n.offsetWidth;
  setTimeout(() => n.classList.remove('fl-on', 'fl-off'), 150);
});
