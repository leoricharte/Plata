/* ---------- Insights: tendencias del mes + evaluación ---------- */
/* Gasto fijo: cuánto crecieron tus suscripciones frente al mes anterior (en dinero y en cantidad). Las ya existentes antes de llevar la cuenta son la base. */
function subGrowth(mk) {
  const hist = data.subHist || {}, pk = prevMkOf(mk), isCur = mk === iso(getToday()).slice(0, 7);
  const cur = isCur ? sum(data.subs, (x) => usd(x.amount, x.cur)) : hist[mk];
  if (cur == null) return null;
  const nw = data.subs.filter((x) => x.since && x.since.slice(0, 7) === mk), newTot = sum(nw, (x) => usd(x.amount, x.cur));
  const base = hist[pk] != null ? hist[pk] : (isCur ? cur - newTot : null);
  if (base == null) return null;
  const d = round2(cur - base), pct = base > 0 ? d / base : (d > 0 ? 1 : 0);
  return { cur: cur, base: base, d: d, pct: pct, n: nw.length, pts: d > 0.005 ? -clamp(pct * 40, 0, 10) : 0 };
}
function monthSums(mk, upTo) {
  const o = { inc: 0, exp: 0, expV: 0, sub: 0, cat: {}, n: 0 };
  data.transactions.forEach((t) => {
    if (isPay(t) || t.date.slice(0, 7) !== mk) return;
    if (upTo && Number(t.date.slice(8, 10)) > upTo) return;
    const v = txUSD(t); o.n++;
    if (v > 0) o.inc += v; else if (txSub(t)) { o.exp -= v; o.sub -= v; } else { o.exp -= v; o.expV -= v; const c = CAT_ORDER.indexOf(t.category) >= 0 ? t.category : 'Otros'; o.cat[c] = (o.cat[c] || 0) - v; }
  });
  return o;
}
const triSVG = (dir, col, sz) => '<span style="display:inline-flex;vertical-align:-3px">' + RMI(dir > 0 ? 'arrow-drop-up-fill' : dir < 0 ? 'arrow-drop-down-fill' : 'subtract-line', Math.round((sz || 14) * 1.3), col) + '</span>';
const prevMkOf = (mk) => iso(new Date(Number(mk.slice(0, 4)), Number(mk.slice(5, 7)) - 2, 1)).slice(0, 7);
function insightsModel(mk0, upTo0) {
  const T0 = getToday(), cmk = iso(T0).slice(0, 7), mk = mk0 || cmk, isCur = mk === cmk, y = Number(mk.slice(0, 4)), mo = Number(mk.slice(5, 7)) - 1;
  const T = new Date(y, mo, 1), dimM = new Date(y, mo + 1, 0).getDate(), part = !!upTo0 || isCur, day = upTo0 || (isCur ? T0.getDate() : dimM), pmk = prevMkOf(mk), dimP = new Date(y, mo, 0).getDate();
  const cur = monthSums(mk, part ? day : 0); let prev = monthSums(pmk, part ? day : 0), est = false;
  if (!prev.n) { const h = data.history.find((x) => x.month === pmk); if (h) { const f = part ? Math.min(1, day / dimP) : 1; prev = { inc: h.income * f, exp: h.expense * f, expV: h.expense * f, sub: 0, cat: {}, n: 0 }; est = true; } }
  const hasPrev = prev.inc > 0 || prev.exp > 0, pct = (a, b) => (b > 0 ? (a - b) / b : null);
  const c0 = calc(), mtx = data.transactions.filter((t) => t.date.slice(0, 7) === mk && (!part || Number(t.date.slice(8, 10)) <= day)).sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : (b.id || 0) - (a.id || 0)));
  const c = Object.assign({}, c0, { dim: dimM, monthTx: mtx, catTot: cur.cat }), AB = budOf(activeSet()), lim = CAT_ORDER.filter((k) => (AB[k] || 0) > 0), within = lim.filter((k) => (cur.cat[k] || 0) <= AB[k]).length;
  const contrib = data.savings.some((sv) => (sv.log || []).some((l) => l.date && l.date.slice(0, 7) === mk && (!part || Number(l.date.slice(8, 10)) <= day)));
  const rateC = cur.inc > 0 ? (cur.inc - cur.expV) / cur.inc : null, rateP = prev.inc > 0 ? (prev.inc - prev.expV) / prev.inc : null;
  let A = 0, B = 0, Cc = 0, D = contrib ? 5 : 0;
  const ps = pct(cur.expV, prev.expV); if (ps != null) A = clamp(-ps * 50, -25, 25);
  if (rateC != null && rateP != null) B = clamp((rateC - rateP) * 60, -15, 15);
  if (lim.length) Cc = (within / lim.length - 0.5) * 30;
  const sg = subGrowth(mk), E = sg ? sg.pts : 0, score = clamp(Math.round(50 + A + B + Cc + D + E), 0, 100), delta = A + B;
  const letter = score >= 90 ? 'S' : score >= 78 ? 'A' : score >= 64 ? 'B' : score >= 50 ? 'C' : score >= 35 ? 'D' : 'F';
  const sk = hasPrev ? gradeStreak(mk, letter) : { n: 1, plus: false };
  return { streak: sk.n, plus: sk.plus, isCur: isCur, T: T, day: day, dim: dimM, mk: mk, cur: cur, prev: prev, est: est, hasPrev: hasPrev, pct: pct, ps: ps, c: c, lim: lim, within: within, contrib: contrib, rateC: rateC, rateP: rateP, sg: sg, score: score, delta: delta, letter: letter, pmk: pmk };
}
function insightsHTML(noHead) {
  const sel = insSel(), m = sel.m, half = sel.half, hs = (data.halfSnaps || {})[m.mk] || null, hl = half && hs ? hs : m, c = m.c, cur = m.cur, prev = m.prev, GOOD = 'var(--gt)', BAD = 'var(--rt)', MUTE = '#6C6C70';
  const pmName = MON_FULL[Number(m.pmk.slice(5, 7)) - 1];
  const chip = (p, upBad) => { if (p == null) return '<span class="sub">—</span>'; const up = p > 0.005, dn = p < -0.005; if (!up && !dn) return '<span class="sub" style="font-weight:600">' + triSVG(0, MUTE, 12) + ' igual</span>'; const good = upBad ? dn : up; return '<span style="color:' + (good ? GOOD : BAD) + ';font-weight:600;font-size:15px">' + triSVG(up ? 1 : -1, good ? GOOD : BAD, 12) + ' ' + Math.round(Math.abs(p) * 100) + '%</span>'; };
  const stat = (lbl, v, p, upBad, sub) => '<div class="row"><div class="grow"><div class="sub" style="font-size:14px">' + lbl + '</div><div style="font-size:24px;font-weight:700;letter-spacing:-.5px">' + v + '</div></div><div style="text-align:right">' + chip(p, upBad) + '<div class="sub" style="font-size:12px;margin-top:2px">' + sub + '</div></div></div>';
  const vs = m.hasPrev ? 'vs. ' + pmName + (m.est ? ' (aprox.)' : '') : 'sin mes anterior';
  const netC = cur.inc - cur.exp, netP = prev.inc - prev.exp;
  const closed = !m.isCur && !half;
  let h = secHead(closed ? 'Cierre vs. ' + pmName : 'Este mes vs. ' + pmName);
  h += '<div class="card lst">' + stat('Gastado', fmt(cur.exp), m.pct(cur.exp, prev.exp), true, vs) + (half ? '' : stat('Ingresos', fmt(cur.inc), m.pct(cur.inc, prev.inc), false, vs)) + '<div class="hr"></div>' +
    stat('Te quedó libre', fmt(netC), null, false, vs).replace('<span class="sub">—</span>', m.hasPrev ? (Math.abs(netC - netP) < 1 ? '<span class="sub" style="font-weight:600">igual</span>' : '<span style="color:' + (netC >= netP ? GOOD : BAD) + ';font-weight:600;font-size:15px">' + triSVG(netC >= netP ? 1 : -1, netC >= netP ? GOOD : BAD, 12) + ' ' + fmt(Math.abs(netC - netP)) + '</span>') : '<span class="sub">—</span>') + '</div>';
  // categorías que más cambiaron
  const ch = CAT_ORDER.map((k) => ({ k: k, a: cur.cat[k] || 0, b: prev.cat[k] || 0 })).filter((x) => x.a > 0 || x.b > 0).map((x) => Object.assign(x, { d: x.a - x.b })).sort((x, y) => Math.abs(y.d) - Math.abs(x.d)).slice(0, 3);
  if (!half && m.prev.n && ch.length) {
    h += secHead('Categorías que más cambiaron') + '<div class="card lst">' + ch.map((x) => '<div class="row">' + tile(CAT_COLOR[x.k], catGlyph(x.k)) + '<div class="grow"><div class="name" style="font-size:16px">' + x.k + '</div><div class="sub" style="font-size:13px">' + fmt(x.b) + ' → ' + fmt(x.a) + '</div></div>' + (x.b > 0 ? chip(x.d / x.b, true) : '<span class="sub" style="font-weight:600">nuevo</span>') + '</div>').join('') + '</div>';
  }
  // ritmo
  const fixedM = cur.cat['Alquiler'] || 0, proj = m.day > 0 ? fixedM + (cur.expV - fixedM) / m.day * m.dim : 0;
  let pace = '<div class="sub" style="font-size:15px">Al ritmo actual cerrarías el mes gastando <b style="color:var(--ink)">' + fmt(proj) + '</b>.</div>';
  if (c.budgetTotal > 0) { const over = proj > c.budgetTotal; pace += '<div class="bar" style="margin:12px 0 8px"><i style="width:' + Math.min(100, proj / c.budgetTotal * 100) + '%;background:' + (over ? '#FF3B30' : '#22B573') + '"></i></div><div class="sub" style="font-size:14px;color:' + (over ? BAD : GOOD) + ';font-weight:600">' + (over ? 'Te pasarías ' + fmt(proj - c.budgetTotal) + ' de tu presupuesto de ' + fmt(c.budgetTotal) : 'Quedarías ' + fmt(c.budgetTotal - proj) + ' por debajo de tu presupuesto de ' + fmt(c.budgetTotal)) + '</div>'; }
  if (!closed) h += secHead('Ritmo de gasto') + '<div class="card">' + pace + '</div>';
  // lo más grande
  const big = c.monthTx.filter((t) => !isPay(t) && t.amount < 0).sort((a, b) => txUSD(a) - txUSD(b))[0];
  if (!half && big) { const bc = CAT_ORDER.indexOf(big.category) >= 0 ? big.category : 'Otros'; h += secHead('Tu gasto más grande') + '<div class="card lst"><div class="row tap" data-act="tx:' + big.id + '">' + tile(CAT_COLOR[bc], catGlyph(bc)) + '<div class="grow"><div class="name" style="font-size:16px">' + esc(big.note || bc) + '</div><div class="sub" style="font-size:13px">' + bc + ' · ' + dshort(pd(big.date)) + '</div></div><span class="amt">' + fmtSC2(big.amount, accOf(big.acc).cur) + '</span>' + ICON.chev + '</div></div>'; }
  // comprometido
  if (!half && c.subsTotal > 0) h += secHead('Ya comprometido') + '<div class="card"><div class="sub" style="font-size:15px">Tus servicios y suscripciones suman <b style="color:var(--ink)">' + fmt(c.subsTotal) + '</b> al mes' + (cur.inc > 0 ? ', el <b style="color:var(--ink)">' + Math.round(c.subsTotal / cur.inc * 100) + '%</b> de lo que has ingresado este mes' : '') + '.' + (m.sg && (m.sg.n > 0 || Math.abs(m.sg.d) > 0.005) ? '<div style="margin-top:8px;color:' + (m.sg.d > 0.005 ? BAD : GOOD) + ';font-weight:600">' + (m.sg.n > 0 ? plural(m.sg.n, 'suscripción nueva', 'suscripciones nuevas') + ' · ' : '') + (m.sg.d >= 0 ? '+' : '−') + fmt(Math.abs(m.sg.d)) + ' al mes frente a ' + pmName + '</div>' : '') + '</div></div>';
  // evaluación
  const dir = !m.hasPrev ? 0 : m.delta > 3 ? 1 : m.delta < -3 ? -1 : 0, dcol = dir > 0 ? GOOD : dir < 0 ? BAD : MUTE;
  const why = [];
  if (m.ps != null) why.push((m.ps <= 0 ? '▲' : '▼') + (closed ? ' Gastaste ' : ' Gastas ') + Math.round(Math.abs(m.ps) * 100) + '% ' + (m.ps <= 0 ? 'menos' : 'más') + ' que en ' + pmName + (closed ? '' : ' a esta altura'));
  if (m.rateC != null) why.push((m.rateP != null && m.rateC >= m.rateP ? '▲' : '▼') + (closed ? ' Ahorraste el ' : ' Estás ahorrando el ') + Math.round(m.rateC * 100) + '% de tus ingresos' + (m.rateP != null ? ' (antes ' + Math.round(m.rateP * 100) + '%)' : ''));
  if (m.lim.length) why.push((m.within === m.lim.length ? '▲' : '▼') + ' ' + m.within + ' de ' + m.lim.length + ' categorías dentro de su límite');
  if (m.contrib) why.push('▲ Aportaste a tus metas este mes (+5 de bonus)'); else if (data.savings.length) why.push('○ Aportar a una meta suma un bonus extra');
  const wl = why.map((x) => '<div class="sub" style="font-size:14px;padding:4px 0;color:var(--ink2)"><span style="color:' + (x.charAt(0) === '▲' ? GOOD : x.charAt(0) === '○' ? MUTE : BAD) + '">' + (x.charAt(0) === '○' ? '○' : '●') + '</span> ' + x.slice(2) + '</div>').join('');
  const ev = '<div class="card"><div style="display:flex;align-items:center;gap:14px"><div class="grow"><div style="font-size:17px;font-weight:600">' + (!m.hasPrev ? 'Aún sin mes anterior para comparar' : dir > 0 ? 'Vas mejor que en ' + pmName : dir < 0 ? 'Vas peor que en ' + pmName : 'Vas igual que en ' + pmName) + '</div><div class="sub" style="font-size:13px;margin-top:2px">' + (m.hasPrev ? ({ S: 'Perfecto', A: 'Muy bueno', B: 'Bueno', C: 'Mediocre', D: 'Deficiente', F: 'Muy malo' }[hl.letter] || '') + ' · ' : '') + (m.hasPrev ? hl.score + ' de 100' : 'Tu primera evaluación llega al cerrar el mes') + '</div></div>' +
    (m.hasPrev ? '<span style="display:flex;align-items:center">' + triSVG(dir, dcol, 22) + '</span>' : '') +
    (half || !m.hasPrev ? ghostScore(m.hasPrev ? hl.letter : '?', 64) : heroTile(m)) + '</div>' +
    (m.hasPrev ? '<div style="font-size:14px;line-height:1.4;color:var(--ink2);margin-top:14px">' + esc(half ? (HALF_EVAL[hl.letter] || HALF_EVAL.B) : (EVAL_TXT[m.letter] || EVAL_TXT.B)) + '</div>' : '') + (!half && m.hasPrev ? streakHTML(m.letter, m.streak, m.plus) : '') +
    (!half && hs && m.hasPrev ? '<div style="display:flex;align-items:center;gap:8px;margin-top:14px;font-size:14px;font-weight:600;font-variant-numeric:normal;color:var(--ink2)"><span>Half‑time</span>' + ghostScore(hs.letter, 28) + '<span style="color:#8E8E93">→</span>' + scoreTile(m.letter, 28, m.plus) + '</div>' : '') +
    (half ? '' : '<div style="border-top:1px solid rgba(60,60,67,.12);margin-top:14px;padding-top:10px">' + wl + '</div>') + '</div>';
  const note = '';
  const fh = firstHalfOn(m) ? '<div class="card"><div style="font-size:17px;font-weight:600">Tu primer cierre de mes se acerca</div><div class="sub" style="font-size:14px;line-height:1.4;margin-top:4px">Este es tu primer half‑time: una mirada a cómo vas a mitad de mes. Cuando el mes termine recibirás tu primera evaluación, de la F a la S.</div></div>' : '';
  return (noHead ? '' : secHead('Insights')) + fh + (scoreOn() ? ev : '') + h + note;
}
const GRAD = {
  S: ['#C9A2FF', '#6D6BF2', '#1F1B6B', '#5CC8FF'], A: ['#6BE59A', '#1FA67A', '#0C4558', '#C4F54D'], B: ['#58D1AE', '#2A8FA8', '#1B3F7A', '#9BF0DC'],
  C: ['#FFE75A', '#F8BC2A', '#A0600C', '#FFF4A8'], D: ['#FF9A3C', '#E8472B', '#7A1A33', '#FFB36B'], F: ['#FF6A5C', '#C73A52', '#51103A', '#FF9F6B']
};

