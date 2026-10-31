/* ---------- Mes: banner de temporada + ventana mensual ---------- */
const SEASON_GRAD = {
  winter: ['#8EC5FF', '#4F86E6', '#1B2A66', '#E6F4FF'], spring: ['#FF9ECF', '#5FCB94', '#1B6F66', '#FFF3A8'],
  summer: ['#FFB347', '#FF7F3F', '#C2255C', '#7FE0FF'], autumn: ['#FFC857', '#E5702F', '#6B1F2E', '#FFB199']
};
function seasonKey(d) {
  const hp = (data && data.settings && data.settings.hemi) || '';
  let tz = ''; try { tz = Intl.DateTimeFormat().resolvedOptions().timeZone || ''; } catch (e) { /* sin zona */ }
  const south = /^(America\/(Lima|Santiago|Sao_Paulo|Argentina|Buenos_Aires|Montevideo|Asuncion|La_Paz|Punta_Arenas|Bahia|Fortaleza|Recife|Manaus|Cuiaba|Campo_Grande|Belem)|Australia|Antarctica|Pacific\/(Auckland|Fiji|Tongatapu|Chatham|Apia|Noumea)|Africa\/(Johannesburg|Maputo|Harare|Lusaka|Windhoek|Gaborone|Maseru|Mbabane)|Indian\/(Reunion|Mauritius|Antananarivo)|Atlantic\/(Stanley|South_Georgia))/.test(tz);
  const m = (d.getMonth() + ((hp === 's' || (hp !== 'n' && south)) ? 6 : 0)) % 12;
  return m === 11 || m < 2 ? 'winter' : m < 5 ? 'spring' : m < 8 ? 'summer' : 'autumn';
}
const cap1 = (x) => x.charAt(0).toUpperCase() + x.slice(1);
function monthScore(mk) {
  if (!scoreOn()) return null;
  const T = getToday(), cmk = iso(T).slice(0, 7);
  if (mk > cmk) return null;
  if (mk === cmk) { const m = insightsModel(); return insLocked(m) || !m.hasPrev ? null : { score: m.score, letter: m.letter, streak: m.streak, plus: m.plus }; }
  const pk = iso(new Date(Number(mk.slice(0, 4)), Number(mk.slice(5, 7)) - 2, 1)).slice(0, 7), cur = monthSums(mk, 0), prev = monthSums(pk, 0);
  if (!cur.n || !(prev.inc > 0 || prev.exp > 0)) return null;
  const AB = budOf(activeSet()), lim = CAT_ORDER.filter((k) => (AB[k] || 0) > 0), within = lim.filter((k) => (cur.cat[k] || 0) <= AB[k]).length;
  const contrib = data.savings.some((sv) => (sv.log || []).some((l) => l.date && l.date.slice(0, 7) === mk));
  const rC = cur.inc > 0 ? (cur.inc - cur.expV) / cur.inc : null, rP = prev.inc > 0 ? (prev.inc - prev.expV) / prev.inc : null;
  let A = 0, B = 0, Cc = 0;
  if (prev.expV > 0) A = clamp(-((cur.expV - prev.expV) / prev.expV) * 50, -25, 25);
  if (rC != null && rP != null) B = clamp((rC - rP) * 60, -15, 15);
  if (lim.length) Cc = (within / lim.length - 0.5) * 30;
  const sg = subGrowth(mk), E = sg ? sg.pts : 0;
  const score = clamp(Math.round(50 + A + B + Cc + E + (contrib ? 5 : 0)), 0, 100);
  const letter = score >= 90 ? 'S' : score >= 78 ? 'A' : score >= 64 ? 'B' : score >= 50 ? 'C' : score >= 35 ? 'D' : 'F', sk = gradeStreak(mk, letter);
  return { score: score, letter: letter, streak: sk.n, plus: sk.plus };
}
/* Racha: meses seguidos con la misma letra. Al segundo mes la letra sube a "+" (dorado/platino) o "-" (rojo); 4 meses seguidos en S = Diamante */
const CHAMP = ['#F6E3A8', '#D9B35F', '#8A6527', '#FFF3CF'];
const PLAT = ['#E3E7EE', '#A7B1C0', '#505A6C', '#FFFFFF'], REDD = ['#FF7A5C', '#D6302E', '#5A0E1F', '#FF9F7A'], REDF = ['#FF4D4D', '#B3122C', '#3C0614', '#FF7A6B'];
const pch = (L) => (L === 'D' || L === 'F' ? '-' : '+');
const plusGrad = (L) => (L === 'S' || L === 'A' ? CHAMP : L === 'B' || L === 'C' ? PLAT : L === 'D' ? REDD : REDF);
function gradeStreak(mk, letter) {
  if (!scoreOn()) return { n: 1, plus: false };
  let n = 1, y = Number(mk.slice(0, 4)), mo = Number(mk.slice(5, 7)) - 1;
  try {
    for (let i = 0; i < 6; i++) {
      const pk = iso(new Date(y, mo - 1 - i, 1)).slice(0, 7), ms = monthScore(pk);
      if (!ms || ms.letter !== letter) break;
      n++;
    }
  } catch (e) { /* sin racha */ }
  return { n: n, plus: n >= 2 ? (letter === 'S' && n >= 4 ? 'd' : true) : false };
}
function streakHTML(letter, n, plus) {
  const g = GRAD[letter] || GRAD.B, dia = plus === 'd', pg = tierG(letter, plus), bad = letter === 'D' || letter === 'F', mid = letter === 'B' || letter === 'C', S = letter === 'S';
  const dot = (on, last) => '<span style="width:12px;height:12px;border-radius:50%;display:inline-block;box-sizing:border-box;' + (on ? 'background:' + (last ? pg[1] : g[1]) : 'border:2px solid ' + (last ? pg[1] : '#C7C7CC')) + '"></span>';
  const dots = '<span style="display:inline-flex;gap:6px;align-items:center">' + (dia ? dot(true) + dot(true, true) + dot(true) + dot(true, true) : dot(n >= 1) + dot(n >= 2, true)) + '</span>';
  const grad = (txt) => '<div style="font-size:15px;font-weight:700;background:linear-gradient(135deg,' + pg[1] + ',' + pg[2] + ');-webkit-background-clip:text;background-clip:text;color:transparent;-webkit-text-fill-color:transparent">' + txt + '</div>';
  const t = dia ? grad('Diamante · ' + n + ' meses seguidos') + '<div class="sub" style="font-size:13px">Perfección. En todo su esplendor.</div>'
    : plus ? grad(letter + pch(letter) + ' · ' + n + ' meses seguidos') + '<div class="sub" style="font-size:13px">' + (bad ? 'Es momento de cambiar el rumbo.' : mid ? 'Nivel estable. Un ajuste más y subes.' : 'Mantienes tu nivel. ¡Sigue así!') + '</div>'
    : '<div style="font-size:14px;font-weight:600;color:var(--ink2)">Llevas ' + n + ' de 2 meses con ' + letter + '.</div><div class="sub" style="font-size:13px">' + (bad ? 'Si sigues igual, al segundo pasas a ' + letter + '-.' : 'Al segundo subes a ' + letter + '+.') + '</div>';
  return '<div style="display:flex;align-items:center;gap:12px;margin-top:14px;padding-top:12px;border-top:1px solid var(--line)">' + dots + '<div class="grow">' + t + '</div></div>';
}
const MM_PER = 10;
function mmList() {
  const mm = ui.mm, F = { all: () => true, in: (t) => t.amount > 0 && !isPay(t), out: (t) => t.amount < 0 && !isPay(t), pay: isPay };
  return data.transactions.filter((t) => t.date.slice(0, 7) === mm.mk && (F[mm.f] || F.all)(t)).sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : String(b.id).localeCompare(String(a.id), undefined, { numeric: true })));
}
function mmBodyHTML() {
  const mm = ui.mm, list = mmList(), pages = Math.max(1, Math.ceil(list.length / MM_PER));
  mm.page = clamp(mm.page || 0, 0, pages - 1);
  const rows = list.slice(mm.page * MM_PER, mm.page * MM_PER + MM_PER).map((t) => txRow(t, true)).join('');
  const nb = (act, lbl, dis) => '<button class="execbtn" data-act="' + (dis ? 'noop' : act) + '" style="min-width:104px;' + (dis ? 'opacity:.35' : '') + '">' + lbl + '</button>';
  return '<div class="card" style="padding-top:6px;padding-bottom:6px">' + (rows || '<div class="empty">Sin movimientos en este mes</div>') + '</div>' +
    (pages > 1 ? '<div style="display:flex;align-items:center;justify-content:space-between;margin:0 0 14px">' + nb('mmp:-1', 'Anterior', mm.page === 0) + '<span class="sub">Página ' + (mm.page + 1) + ' de ' + pages + '</span>' + nb('mmp:1', 'Siguiente', mm.page >= pages - 1) + '</div>' : '');
}
function mmRefresh() { const el = $('#mmBody'); if (el) { el.innerHTML = mmBodyHTML(); swapIn(el); } }
function monthScreenHTML() {
  if (!ui.mm) ui.mm = { mk: iso(getToday()).slice(0, 7), f: 'all', page: 0 };
  const mm = ui.mm, y = Number(mm.mk.slice(0, 4)), mo = Number(mm.mk.slice(5, 7)) - 1, sc = monthScore(mm.mk), ms = monthSums(mm.mk, 0), T = getToday();
  const hasPay = data.transactions.some(isPay), items = [{ k: 'all', label: 'Todos', act: 'mmf:all' }, { k: 'in', label: 'Ingresos', act: 'mmf:in' }, { k: 'out', label: 'Gastos', act: 'mmf:out' }];
  if (hasPay) { const hx = data.transactions.some(isXfer), hp = data.transactions.some((t) => t.category === PAY); items.push({ k: 'pay', label: hx ? (hp ? 'Pagos y transf.' : 'Transferencias') : 'Pagos', act: 'mmf:pay' }); }
  const pm = new Date(T.getFullYear(), T.getMonth() - 1, 1), st = (l, v, c) => '<div><span class="sub">' + l + '</span><b' + (c ? ' style="color:' + c + '"' : '') + '>' + v + '</b></div>', net = ms.inc - ms.exp;
  const openM = mm.mk >= iso(T).slice(0, 7);
  const pendRow = '<div class="card" style="padding:14px 16px"><div style="display:flex;align-items:center;gap:14px"><div style="flex:none">' + ghostScore('?', 52) + '</div><div class="grow" style="font-size:16px;font-weight:600;line-height:1.3;color:var(--ink2)">Aún estamos trabajando en tu puntaje de este mes.</div></div></div>';
  const scoreRow = sc && openM ? pendRow : sc ? '<div class="card" style="padding:14px 16px"><div style="display:flex;align-items:center;gap:14px"><div style="flex:none">' + scoreTile(sc.letter, 52, sc.plus) + '</div><div class="grow"><div class="sub" style="font-size:13px">Puntaje</div><div style="font-size:26px;font-weight:800;letter-spacing:-.5px;line-height:1.1">' + sc.score + '<span class="sub" style="font-size:15px;font-weight:600"> / 100</span></div></div></div>' + streakHTML(sc.letter, sc.streak, sc.plus) + '</div>' : '';
  const mkNow = iso(T).slice(0, 7), cnt = {};
  data.transactions.forEach((t) => { const k = t.date.slice(0, 7); if (k <= mkNow) cnt[k] = (cnt[k] || 0) + 1; });
  const first = Object.keys(cnt).sort()[0] || mkNow, ks = [];
  let dd = new Date(T.getFullYear(), T.getMonth(), 1);
  while (iso(dd).slice(0, 7) >= first && ks.length < 60) { ks.push(iso(dd).slice(0, 7)); dd = new Date(dd.getFullYear(), dd.getMonth() - 1, 1); }
  if (ks.indexOf(mm.mk) < 0) ks.push(mm.mk);
  const opts = ks.map((k) => '<option value="' + k + '"' + (k === mm.mk ? ' selected' : '') + '>' + cap1(MON_FULL[Number(k.slice(5, 7)) - 1]) + ' ' + k.slice(0, 4) + '</option>').join('');
  const pick = '<label class="mpick"><select data-mmsel aria-label="Cambiar mes">' + opts + '</select><span>' + cap1(MON_FULL[mo]).slice(0, 3) + ' ' + y + '</span>' + RMI('arrow-down-s-line', 18, 'currentColor') + '</label>';
  return '<div class="navrow" style="display:flex;align-items:center;justify-content:space-between;margin-bottom:12px"><button class="back" data-act="itback" aria-label="Regresar">' + IC_BACK + '</button>' + pick + '</div>' + monthHead(new Date(y, mo, 15)) + scoreRow +
    '<div class="sechead"><h2>Movimientos</h2></div>' +
    '<div class="card"><div class="stats" style="border:0;margin:0;padding:0;display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:6px;text-align:center">' + st('Ingresos', fmt(ms.inc), 'var(--gt)') + st('Gastos', fmt(ms.exp)) + st('Neto', (net < 0 ? '−' : '') + fmt(Math.abs(net)), net < 0 ? 'var(--rt)' : 'var(--gt)') + '</div></div>' +
    segHTML('mmf', items, mm.f) + '<div id="mmBody">' + mmBodyHTML() + '</div>';
}
const svgU = (svg) => "url('data:image/svg+xml," + encodeURIComponent(svg).replace(/'/g, '%27') + "')";
const DIAM = ['#EAFBFF', '#8ED6F3', '#4A7FD6', '#FFFFFF'];
const GEMK = 1.28;
const GEM = (sw) => '<path d="M31 29 L69 29 L87 45 L50 85 L13 45 Z" fill="#000" stroke="#000" stroke-width="' + sw + '" stroke-linejoin="round"/>';
const gmSp = (letter, plus) => plus === 'd' && letter === 'S';
const tL = (L, plus) => (plus === 'd' ? 'Diamante' : plus ? L + pch(L) : L);
const tierG = (L, plus) => (plus === 'd' ? DIAM : plusGrad(L));
function gemHTML(px, g, label) {
  return '<span role="img" aria-label="' + (label || 'S◆') + '" style="position:relative;display:block;flex:none;width:' + px + 'px;height:' + px + 'px;background:' + insBg(g) + ';-webkit-mask:' + svgU('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">' + GEM(16) + '</svg>') + ' center/100% 100% no-repeat;mask:' + svgU('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">' + GEM(16) + '</svg>') + ' center/100% 100% no-repeat"></span>';
}
const dmSp = (letter, plus) => !!plus && plus !== 'd' && /^[SABC]$/.test(letter);
const trSp = (letter, plus) => !!plus && plus !== 'd' && /^[DF]$/.test(letter);
const TRK = 1.22;
const DMK = 1.18;
function heroTile(m) {
  if (gmSp(m.letter, m.plus)) { const bx = Math.round(64 * GEMK); return '<div style="flex:none;width:' + bx + 'px;height:' + bx + 'px;margin:' + (-Math.round((bx - 64) / 2)) + 'px">' + gemHTML(bx, DIAM) + '</div>'; }
  const dm = dmSp(m.letter, m.plus), tr = trSp(m.letter, m.plus), L = tL(m.letter, m.plus), k = dm ? DMK : tr ? TRK : 1, bx = Math.round(64 * k), mg = -Math.round((bx - 64) / 2);
  return '<div role="img" aria-label="' + L + '" style="position:relative;overflow:hidden;flex:none;width:' + bx + 'px;height:' + bx + 'px;margin:' + mg + 'px;border-radius:' + (dm || tr ? 0 : 20) + 'px;background:' + insBg(m.plus ? tierG(m.letter, m.plus) : (GRAD[m.letter] || GRAD.B)) + ';' + letterCut(L, dm, true, true, tr) + '"><div class="insgrain"></div></div>';
}
function scoreTile(letter, sz, plus) {
  if (gmSp(letter, plus)) { const bx = Math.round(sz * GEMK); return '<span style="display:block;flex:none;width:' + bx + 'px;height:' + bx + 'px;margin:' + (-Math.round((bx - sz) / 2)) + 'px">' + gemHTML(bx, DIAM) + '</span>'; }
  const g = plus ? tierG(letter, plus) : (GRAD[letter] || GRAD.B), dm = dmSp(letter, plus), tr = trSp(letter, plus), L = tL(letter, plus), k = dm ? DMK : tr ? TRK : 1, bx = Math.round(sz * k), mg = -Math.round((bx - sz) / 2);
  return '<span role="img" aria-label="' + L + '" style="display:block;flex:none;width:' + bx + 'px;height:' + bx + 'px;margin:' + mg + 'px;border-radius:' + (dm || tr ? 0 : Math.round(sz * 0.32)) + 'px;background:' + insBg(g) + ';' + letterCut(L, dm, true, true, tr) + '"></span>';
}
function mmPickHTML() {
  const T = getToday(), cmk = iso(T).slice(0, 7), cnt = {};
  data.transactions.forEach((t) => { const k = t.date.slice(0, 7); if (k <= cmk) cnt[k] = (cnt[k] || 0) + 1; });
  const first = Object.keys(cnt).sort()[0] || cmk, ks = [];
  let d = new Date(T.getFullYear(), T.getMonth(), 1);
  while (iso(d).slice(0, 7) >= first && ks.length < 60) { ks.push(iso(d).slice(0, 7)); d = new Date(d.getFullYear(), d.getMonth() - 1, 1); }
  const rows = ks.map((k) => '<div class="row tap" data-act="mmset:' + k + '"><div class="grow"><div class="name" style="font-size:16px">' + cap1(MON_FULL[Number(k.slice(5, 7)) - 1]) + ' ' + k.slice(0, 4) + '</div><div class="sub" style="font-size:13px">' + plural(cnt[k] || 0, 'movimiento', 'movimientos') + '</div></div>' + (ui.mm && ui.mm.mk === k ? '<span style="color:#22B573;font-weight:700">✓</span>' : '') + '</div>').join('');
  return sheetHead('Elige un mes', null, null) + '<div class="card lst" style="margin:0 0 12px;max-height:55vh;overflow:auto">' + rows + '</div>';
}
function updateMovList() { const el = $('#movList'); el.innerHTML = movRows(); swapIn(el); }
function renderMovimientos() {
  $('#s-movimientos').innerHTML =
    '<button class="back" data-act="tab:resumen" aria-label="Regresar">' + IC_BACK + '</button>' +
    '<div class="head"><div><h1>Movimientos</h1></div></div>' +
    segHTML('mov', [{ k: 'all', label: 'Todos', act: 'mov:all' }, { k: 'in', label: 'Ingresos', act: 'mov:in' }, { k: 'out', label: 'Gastos', act: 'mov:out' }], ui.mov) +
    '<div class="card" style="padding:2px 18px;margin-bottom:12px"><button class="linkrow" data-act="add">' + IC_ADD + 'Añadir movimiento</button>' + (nazcaOn() ? '<button class="linkrow" data-act="imp:start" style="border-top:1px solid var(--line);width:100%">' + RMI('folder-chart-line', 22, '#22B573') + 'Importar movimientos</button>' : '') + '</div>' +
    '<div class="card" style="padding-top:6px;padding-bottom:6px" id="movList">' + movRows() + '</div>';
}

