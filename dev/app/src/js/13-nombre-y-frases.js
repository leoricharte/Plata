/* ---------- Nombre y frases ---------- */
const genderExample = (g, nm) => genderExampleL(g, nm);
const userGender = () => { const g = ((data.settings || {}).gender || 'n'); return g === 'm' || g === 'f' ? g : 'n'; };
const insOn = () => (data.settings || {}).insights !== false;
const scoreOn = () => insOn() && (data.settings || {}).score !== false;
const swHTML = (on, act, dis) => '<button class="sw2' + (on ? ' on' : '') + (dis ? ' dis' : '') + '" role="switch" aria-checked="' + !!on + '" data-act="' + act + '"><span></span></button>';
const userNick = () => { const st = data.settings || {}; return ((st.nick || '').trim() || (st.first || '').trim()); };
/*__I18N__*/
const PHRASES = {
  S: [['Excelente trabajo en {mes}, {n}.', 'Excelente trabajo en {mes}.'], ['{n}, {mes} fue un mes de primera.', '{Mes} fue un mes de primera.'], ['Así se hace, {n}: {mes} quedó impecable.', 'Así se hace: {mes} quedó impecable.'], ['Mes redondo, {n}. Sigue así.', 'Mes redondo. Sigue así.']],
  A: [['Muy buen {mes}, {n}.', 'Muy buen {mes}.'], ['Vas por muy buen camino, {n}.', 'Vas por muy buen camino.'], ['Buen trabajo en {mes}, {n}. Casi perfecto.', 'Buen trabajo en {mes}. Casi perfecto.'], ['{n}, {mes} salió muy bien.', '{Mes} salió muy bien.']],
  B: [['Buen ritmo en {mes}, {n}.', 'Buen ritmo en {mes}.'], ['Vas bien, {n}. Un pequeño ajuste y subes.', 'Vas bien. Un pequeño ajuste y subes.'], ['{Mes} salió sólido, {n}.', '{Mes} salió sólido.'], ['{bien}, {n}. Aún hay margen para más.', '{bien}. Aún hay margen para más.']],
  C: [['{Mes} fue regular, {n}. Se puede mejorar.', '{Mes} fue regular. Se puede mejorar.'], ['Vas a medias, {n}. Veamos dónde ajustar.', 'Vas a medias. Veamos dónde ajustar.'], ['Hay espacio para mejorar, {n}.', 'Hay espacio para mejorar.'], ['Ni mal ni bien, {n}. Puedes más.', 'Ni mal ni bien. Puedes más.']],
  D: [['Podemos hacerlo mejor, {n}.', 'Podemos hacerlo mejor.'], ['{Mes} costó un poco, {n}. Aún estás a tiempo.', '{Mes} costó un poco. Aún estás a tiempo.'], ['Toca ajustar, {n}. Empieza por lo más grande.', 'Toca ajustar. Empieza por lo más grande.'], ['Corrijamos el rumbo, {n}.', 'Corrijamos el rumbo.']],
  F: [['{Mes} fue difícil, {n}. Empecemos de nuevo.', '{Mes} fue difícil. Empecemos de nuevo.'], ['Es momento de frenar, {n}. Lo vemos paso a paso.', 'Es momento de frenar. Lo vemos paso a paso.'], ['Esto no define tu año, {n}. Hagamos un plan.', 'Esto no define tu año. Hagamos un plan.'], ['Un mal mes le pasa a cualquiera, {n}. Seguimos.', 'Un mal mes le pasa a cualquiera. Seguimos.']]
};
const EVAL_TXT = {
  S: 'Un mes ejemplar: gastas con control, ahorras y cumples tus metas. Mantén este ritmo y sigue puliendo los detalles. Estás construyendo un hábito que se nota.',
  A: 'Muy buen mes. Estás cerca de la excelencia; un pequeño ajuste en tus gastos más grandes te llevaría a la cima. Ya casi lo tienes.',
  B: 'Vas por buen camino. Aún hay margen para mejorar: revisa las categorías que más subieron y sigue avanzando. Cada mes cuenta.',
  C: 'Un mes intermedio. No está mal, pero puedes hacerlo un poquito mejor: elige una categoría para recortar y mira cómo cambia tu nota. Los grandes cambios empiezan con uno pequeño.',
  D: 'Este mes se complicó, pero estás a tiempo de corregir. Empieza por tu mayor gasto y celebra cada pequeño avance. Un mes más ordenado cambia el panorama.',
  F: 'Un mal mes no define tu camino. Empecemos de nuevo: un límite por categoría y un pequeño aporte a tus metas. Lo importante es seguir intentando.'
};
function insPhrase(m) {
  if (!m.hasPrev) return 'Registra un mes completo para recibir tu evaluación.';
  const L = LANG, list = (L === 'es' ? PHRASES : PH_T[L])[m.letter] || (L === 'es' ? PHRASES : PH_T[L]).B, nick = userNick(), v = list[(m.T.getFullYear() * 12 + m.T.getMonth()) % list.length];
  const mes = L === 'es' ? MON_FULL[m.T.getMonth()] : LOC[L].mon[m.T.getMonth()];
  const bien = L === 'es' ? (({ m: 'Bien hecho' })[userGender()] || 'Buen trabajo') : BIEN_T[L][userGender()];
  return (nick ? v[0] : v[1]).replace(/\{n\}/g, nick).replace(/\{bien\}/g, bien).replace(/\{Mes\}/g, mes.charAt(0).toUpperCase() + mes.slice(1)).replace(/\{mes\}/g, mes);
}
const tGrad = (g) => 'linear-gradient(100deg,' + (g[3] || g[0]) + ',' + g[0] + ' 45%,' + g[1] + ')';
const insBg = (g) => 'radial-gradient(110% 80% at 88% 0%,' + (g[3] || g[1]) + 'cc 0%,transparent 60%),radial-gradient(90% 70% at 0% 100%,' + g[0] + '55 0%,transparent 60%),linear-gradient(180deg,' + g[0] + ' 0%,' + g[1] + ' 48%,' + g[2] + ' 100%)';
function insLocked(m) {
  if (m.hasPrev && m.cur.n + m.prev.n >= 10) return null;
  const dimC = m.dim || 30, left = Math.max(0, dimC - m.day), need = m.hasPrev ? 7 : left + 7;
  return need <= 10 ? 'unos días' : need <= 21 ? 'un par de semanas' : 'alrededor de un mes';
}
const LOCK_SVG = '<span style="display:block;line-height:0">' + RMI('question-fill', 32, '#8E8E93') + '</span>';
/* Half‑time: del día 15 al 20 el banner muestra la nota preliminar (icono punteado, sin relleno, letra con degradado) */
/* Primer half‑time del usuario: aparece aunque aún no haya mes anterior y avisa que su primer cierre se acerca */
const HALF_FIRST = [['Tu primer half‑time.', 'Tu primer cierre de mes se acerca. Así ibas el día 15.'], ['¡Primer half‑time!', 'Falta poco para tu primer cierre de mes.'], ['Llegaste a mitad de mes.', 'Este es tu primer half‑time; tu primer cierre se acerca.']];
function firstHalfOn(m) {
  if (!insOn() || !scoreOn() || m.cur.n < 5) return false;
  if (!(m.day >= 15 || !!(data.settings || {}).forceHalf)) return false;
  const f = data.firstHalf; if (f && f !== m.mk) return false;
  if (!f) { if (m.hasPrev) { data.firstHalf = '2000-01'; persist(); return false; } data.firstHalf = m.mk; persist(); }
  return true;
}
const isHalfTime = (m) => scoreOn() && m.hasPrev && (m.day >= 15 || !!(data.settings || {}).forceHalf);
/* Foto del half‑time: la nota queda guardada en el archivo para compararla con la del cierre. Se actualiza mientras dura la ventana natural (día 15–20) y con half‑time forzado solo se crea si falta */
function halfSnapOf(cm) {
  const sn = data.halfSnaps || (data.halfSnaps = {});
  if (!sn[cm.mk] && cm.isCur && (cm.day >= 15 || !!(data.settings || {}).forceHalf) && scoreOn()) { const hm = insightsModel(cm.mk, 15); if (hm.hasPrev) { sn[cm.mk] = { letter: hm.letter, score: hm.score }; persist(); } }
  return sn[cm.mk] || null;
}
/* Qué informe se abre: half‑time (hasta el día 15) o cierre del mes (anterior) */
function insSel() {
  const cm = insightsModel(), cmk = cm.mk;
  if (ui.insHalf && (isHalfTime(cm) || firstHalfOn(cm))) { halfSnapOf(cm); return { m: insightsModel(cmk, 15), half: true }; }
  const mk = ui.insMk || prevMkOf(cmk), m = insightsModel(mk);
  return { m: !m.hasPrev && !ui.insMk ? cm : m, half: false };
}
function ghostScore(letter, sz) {
  const g = letter === '?' ? ['#C7C7CC', '#9A9AA2', '#8E8E93', '#E5E5EA'] : (GRAD[letter] || GRAD.B), id = 'gs' + Math.random().toString(36).slice(2, 7);
  return '<svg data-notr width="' + sz + '" height="' + sz + '" viewBox="0 0 64 64" aria-hidden="true" style="display:block"><defs><linearGradient id="' + id + '" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="' + g[0] + '"/><stop offset=".55" stop-color="' + g[1] + '"/><stop offset="1" stop-color="' + g[2] + '"/></linearGradient></defs>' +
    '<rect x="2" y="2" width="60" height="60" rx="20" fill="none" stroke="' + g[1] + '" stroke-opacity=".8" stroke-width="2.8" stroke-linecap="round" pathLength="40" stroke-dasharray="0 1"/>' +
    '<text x="32" y="46" text-anchor="middle" font-size="36" font-weight="800" letter-spacing="-1" fill="url(#' + id + ')" font-family="inherit">' + letter + '</text></svg>';
}
const HALF_TXT = [['¡Half‑time!', 'Esto es lo que llevabas al día 15.'], ['Llegó el half‑time.', 'Un adelanto de tu nota, con margen para mejorarla.'], ['Vas a mitad de mes.', 'Este es tu half‑time: así iba tu nota el día 15.']];
const HALF_EVAL = {
  S: 'Ritmo de primera. Mantenlo y cierra el mes con nota perfecta.',
  A: 'Muy buen ritmo. Un pequeño ajuste y cierras el mes en lo más alto.',
  B: 'Buen ritmo, con margen. Cuida tus gastos grandes y sube de nota.',
  C: 'Vas a medias. Aún estás a tiempo de mejorar antes de fin de mes.',
  D: 'Mes cuesta arriba, pero hay tiempo. Empieza por tu mayor gasto.',
  F: 'Toca frenar, pero aún queda mes. Un plan simple cambia el rumbo.'
};
function halfBanner(m) {
  const fst = firstHalfOn(m), hv = (fst ? HALF_FIRST : HALF_TXT)[(m.T.getFullYear() * 12 + m.T.getMonth()) % 3], hl = m.hasPrev ? (halfSnapOf(m) || insightsModel(m.mk, 15)).letter : 'B', hg = GRAD[hl] || GRAD.B;
  return '<div class="card tap" data-act="inshalf" role="button" style="font-variant-numeric:normal;margin:0 0 12px;padding:14px 16px;border-radius:24px">' +
    '<div style="display:flex;align-items:center;gap:14px"><div style="flex:none">' + ghostScore(m.hasPrev ? hl : '?', 56) + '</div><div class="grow" style="text-align:left;min-width:0">' +
    '<span style="display:inline-block;font-size:20px;font-weight:800;letter-spacing:-.4px;line-height:1.2;background:linear-gradient(135deg,' + hg[0] + ',' + hg[1] + ' 55%,' + hg[2] + ');-webkit-background-clip:text;background-clip:text;color:transparent;-webkit-text-fill-color:transparent">' + hv[0] + '</span>' +
    '<div style="font-size:14px;font-weight:500;color:var(--mute);line-height:1.3;margin-top:2px">' + hv[1] + '</div></div></div>' +
    '<span style="display:flex;align-items:center;justify-content:center;width:100%;height:42px;--tg:' + tGrad(hg) + ';border-radius:999px;margin-top:12px;background:linear-gradient(180deg,#2C2C2E,#0B0B0C);color:#fff;font-size:16px;font-weight:600;box-shadow:inset 0 1px 0 rgba(255,255,255,.2)">' + '<b class="btg">Ver informe hasta ahora</b>' + '</span></div>';
}
function closeBanner(m, label, act) {
  const mes = MON_FULL[m.T.getMonth()], g = m.hasPrev ? (scoreOn() && m.plus ? tierG(m.letter, m.plus) : GRAD[scoreOn() ? m.letter : 'B']) : ['#B9B9C6', '#7B7B93', '#3A3A52', '#D8D8E6'];
  return '<div class="insban tap" data-act="' + act + '" role="button" style="position:relative;overflow:hidden;border-radius:26px;margin:0 0 14px;padding:18px;text-align:center;color:#fff;--tg:' + tGrad(g) + ';background:' + insBg(g) + ';box-shadow:0 8px 24px rgba(0,0,0,.12)">' +
    '<div class="insgrain"></div>' +
    '<div style="position:relative"><div class="btx" style="font-size:15px;font-weight:500;opacity:.92">' + label + ' ' + mes + '</div>' +
    '<div class="btx" style="font-size:26px;font-weight:800;letter-spacing:-.6px;margin:2px 0 6px">' + (!scoreOn() ? 'Tus tendencias de ' + mes + '.' : m.hasPrev ? 'Tu evaluación fue ' + tL(m.letter, m.plus) + '.' : 'Aún sin evaluación.') + '</div>' +
    (scoreOn() ? '<div class="btx" style="font-size:15px;line-height:1.3;opacity:.95;margin:0 6px 14px">' + esc(insPhrase(m)) + '</div>' : '<div style="height:8px"></div>') +
    '<span style="display:flex;align-items:center;justify-content:center;width:100%;height:50px;border-radius:999px;background:var(--card);color:' + g[1] + ';font-size:17px;font-weight:600">' + '<b class="btg">Ver informe</b>' + '</span></div></div>';
}
/* Banner de inicio de mes: revela la evaluación del mes pasado (primeros 7 días, con X; se recuerda por mes en settings.mr_x). */
const MR_TXT = {
  S: [['¡Mes redondo!', 'Mira cómo quedaste.'], ['¡Qué mes!', 'Esto merece celebrarse.'], ['Cierre de mes', 'Tu mejor versión, en números.']],
  A: [['¡Se acabó el mes!', 'Revisemos cómo te fue.'], ['¡Buen cierre!', 'Te fue muy bien. Mira por qué.'], ['Mes terminado', 'Veamos qué hiciste bien.']],
  B: [['¡Se acabó el mes!', 'Revisemos cómo te fue.'], ['Mes cerrado', 'Nada mal. Veamos qué mejorar.'], ['Llegó el cierre', 'Hubo cosas buenas. Míralas.']],
  C: [['Se acabó el mes', 'Veamos qué pasó.'], ['Mes cerrado', 'Se puede mejorar. Empecemos.'], ['Llegó el cierre', 'Revisémoslo juntos.']],
  D: [['Se acabó el mes', 'Fue un mes difícil. Revisémoslo.'], ['Mes cerrado', 'Veamos dónde se escapó.'], ['Llegó el cierre', 'Aún hay tiempo de cambiarlo.']],
  F: [['Se acabó el mes', 'Fue duro. Aquí te ayudamos.'], ['Mes cerrado', 'Empecemos de nuevo.'], ['Llegó el cierre', 'Veamos qué ajustar, sin culpas.']]
};
const revealShow = (pm) => scoreOn() && getToday().getDate() <= 7 && (data.settings || {}).mr_x !== pm.mk;
function revealBanner(m) {
  const L = m.letter, g = GRAD[L] || GRAD.B, dark = L === 'C', tx = dark ? '#3B2600' : '#fff', mes = cap1(MON_FULL[m.T.getMonth()]);
  const big = m.plus && m.plus !== 'd' ? tL(L, m.plus) : L, v = MR_TXT[L][(m.T.getFullYear() * 12 + m.T.getMonth()) % 3];
  return '<section class="insban" aria-label="Tu evaluación del mes" style="position:relative;overflow:hidden;box-sizing:border-box;width:100%;height:470px;border-radius:34px;margin:0 0 14px;padding:20px 24px 22px;display:flex;flex-direction:column;align-items:center;text-align:center;color:' + tx + ';background:' + insBg(g) + ';box-shadow:0 18px 40px -12px ' + g[2] + '88,0 2px 0 rgba(255,255,255,.35) inset">' +
    '<button data-act="mrx:' + m.mk + '" aria-label="Cerrar" style="position:absolute;top:14px;right:14px;width:36px;height:36px;border-radius:50%;border:0;padding:0;display:flex;align-items:center;justify-content:center;background:' + (dark ? 'rgba(59,38,0,.14)' : 'rgba(255,255,255,.24)') + ';color:' + tx + '">' + RMI('close-line', 18, 'currentColor') + '</button>' +
    '<div style="font-size:16px;font-weight:400;margin-top:2px;opacity:.95">' + esc(v[0]) + '</div>' +
    '<div style="font-size:36px;font-weight:800;letter-spacing:-.035em;line-height:1.05">' + esc(mes) + '</div>' +
    '<div style="font-size:15px;line-height:1.25;margin-top:5px;opacity:.95;max-width:260px;text-wrap:balance">' + esc(v[1]) + '</div>' +
    '<button data-act="mrgo:' + m.mk + '" style="position:relative;width:100%;margin-top:14px;height:48px;border-radius:999px;border:0;background:#fff;color:' + g[2] + ';font-size:17px;font-weight:600;box-shadow:0 6px 18px -6px ' + g[2] + '88">Revisar insights</button>' +
    '<div role="img" aria-label="' + esc(tL(L, m.plus)) + '" style="position:absolute;left:0;right:0;bottom:-57px;text-align:center;font-size:' + (big.length > 1 ? 300 : 400) + 'px;font-weight:800;line-height:.78;letter-spacing:-.04em;color:' + (dark ? '#3B2600' : '#fff') + ';pointer-events:none">' + esc(big) + '</div></section>';
}
/* El banner de inicio de mes va arriba del Resumen, bajo el saludo y el estado de guardado; el banner de cierre de siempre sigue donde estaba. */
function revealTop() {
  if (!insOn() || !hasData()) return '';
  const pm = insightsModel(prevMkOf(insightsModel().mk));
  return !insLocked(pm) && revealShow(pm) ? revealBanner(pm) : '';
}
function insightsBanner(pos) {
  if (!insOn()) return '';
  const cm = insightsModel(), lk = insLocked(cm), pm = insightsModel(prevMkOf(cm.mk)), pOK = !insLocked(pm);
  const hOK = (isHalfTime(cm) && !lk) || firstHalfOn(cm);
  if (pos === 'bottom') {
    if (pOK || hOK || !lk) return '';
    return '<div class="card insban" style="margin-top:14px">' + LOCK_SVG +
      '<div class="name" style="font-size:20px;font-weight:700;letter-spacing:-.3px;margin:10px 0 4px">¿Buscas tus insights?</div>' +
      '<div class="sub" style="font-size:15px;line-height:1.35">Aún no tenemos suficientes datos tuyos' + (userNick() ? ', ' + esc(userNick()).replace(/ /g, '\u00a0') : '') + '. Necesitamos un mes de movimientos para aconsejarte.</div>' +
      '<div style="font-size:15px;font-weight:600;margin-top:10px;color:var(--ink)">Vuelve a revisar en ' + lk + '.</div></div>';
  }
  const hb = hOK ? halfBanner(cm) : '';
  if (pOK) return hb + closeBanner(pm, 'Cierre de', 'insights:' + pm.mk);
  if (!lk) return hb + closeBanner(cm, 'Insights de', 'insights:' + cm.mk);
  return hb;
}

function renderProyeccion() {
  const c = calc(), est = data.transactions.filter((t) => t.est > 0 && t.amount > 0);
  const avgVar = est.length ? sum(est, (t) => usd(t.amount - t.est, accOf(t.acc).cur)) / est.length : 0;
  const pend = pendingIncomes().map((e) => e.id);
  const inRows = data.expected_income.slice().sort((a, b) => (a.date < b.date ? -1 : 1)).map((e) => {
    const cur = accOf(e.acc).cur, due = pend.indexOf(e.id) >= 0;
    return rowEdit('income', e.id, tile('#22B573', esc(e.name).charAt(0)),
      '<div class="name" style="font-size:16px">' + esc(e.name) + (due ? ' <span class="badge" style="background:var(--obg);color:var(--ot);padding:2px 8px;font-size:12px">Por confirmar</span>' : '') + '</div><div class="sub" style="font-size:13px">' + dlabel(pd(e.date)) + ' · ' + repLabel(e.repeat) + untilTxt(e) + '</div>',
      '<span class="amt" style="color:var(--gt);font-weight:600">+' + fmtC(e.amount, cur) + '</span>');
  }).join('');
  const jobRows = data.jobs.map((j) => {
    const cur = accOf(j.acc).cur;
    return rowEdit('job', j.id, tile(j.sim ? '#FF9F0A' : '#22B573', esc(j.name).charAt(0) || 'T'),
      '<div class="name" style="font-size:16px">' + esc(j.name) + (j.sim ? ' <span class="badge" style="background:var(--obg);color:var(--ot);padding:2px 8px;font-size:12px">Simulado</span>' : '') + '</div><div class="sub" style="font-size:13px">' + (j.mode === 's' ? fmtC(j.rate, cur) + '/mes · sueldo · ' : fmtC(j.rate, cur) + '/h · ' + j.hours + ' h/sem · ' + j.tax + '% impuestos · ') + repLabel(jobRep(j.freq)) + '<br>' + dlabel(pd(j.start)) + (j.until ? ' → ' + dlabel(pd(j.until)) : '') + '</div>',
      '<span class="amt" style="color:var(--gt);font-weight:600">+' + fmtC(jobNet(j), cur) + '</span>');
  }).join('');
  const jobIn = jobTxs().slice(0, 6).map((t) => {
    const cur = accOf(t.acc).cur, d = pd(t.date);
    const html = '<div class="row tap" data-act="tx:' + t.id + '">' + tile('#22B573', esc(t.note || 'T').charAt(0)) + '<div class="grow"><div class="name" style="font-size:16px">' + esc(t.note) + '</div><div class="sub" style="font-size:13px">' + dlabel(d) + '</div></div>' + amtHrs(t, '<span class="amt" style="color:var(--gt);font-weight:600">+' + fmtC(t.amount, cur) + '</span>') + ICON.chev + '</div>';
    return isWebView() ? html : swWrap(t, html, isPay(t), isXfer(t));
  }).join('');
  const pendX = pendingItems().filter((x) => x.k === 'out').map((x) => x.e.id);
  const exRows = data.expected_expense.slice().sort((a, b) => (a.date < b.date ? -1 : 1)).map((e) => {
    const cur = accOf(e.acc).cur, due = pendX.indexOf(e.id) >= 0, ec = CAT_ORDER.indexOf(e.cat) >= 0 ? e.cat : 'Otros', pc = payOf(e);
    return rowEdit('expense', e.id, pc ? tile('#B98AE6', iconSVG('card', '#fff', 20)) : tile(CAT_COLOR[ec], catGlyph(ec)),
      '<div class="name" style="font-size:16px">' + esc(e.name) + (due ? ' <span class="badge" style="background:var(--obg);color:var(--ot);padding:2px 8px;font-size:12px">Por confirmar</span>' : '') + '</div><div class="sub" style="font-size:13px">' + dlabel(pd(e.date)) + ' · ' + repLabel(e.repeat) + untilTxt(e) + ' · ' + (pc ? 'Pago de crédito' : esc(ec)) + '</div>',
      '<span class="amt" style="font-weight:600">−' + fmtC(e.amount, cur) + '</span>');
  }).join('');
  const scoreM = insightsModel(), scoreOK = !insLocked(scoreM);
  const scorePill = (status) => {
    if (!scoreOK || !scoreOn()) return '';
    const l = scoreM.letter, g = GRAD[l];
    const txt = status === 'red' ? 'No recomendado' : l === 'S' || l === 'A' || l === 'B' ? (status === 'ok' ? 'Recomendado' : 'Con cautela') : l === 'C' ? (status === 'ok' ? 'Con cautela' : 'No recomendado') : (status === 'ok' ? 'Mejor espera' : 'No recomendado');
    return '<span class="badge" style="background:' + insBg(g) + ';color:#fff;padding:2px 10px;font-size:12px">' + txt + '</span>';
  };
  const impactHTML = (p) => {
    if (p.on === false) return '';
    const im = simImpact(p); if (!im) return '';
    const tag = { red: ['#FFE5E3', 'var(--rt)', 'Te deja en rojo'], amber: ['#FFF1D6', 'var(--ot)', 'Bajo tu colchón'], ok: ['#E2F6EC', 'var(--gt2)', 'Sin problema'] }[im.status];
    return '<div class="sub" style="font-size:13px;padding-top:2px">Del ' + dshort(pd(im.start)) + ' al ' + dshort(pd(im.end)) + ' · mínimo ' + fmt(im.withMin) + ' el ' + dshort(im.withDate) + ' (sin esto: ' + fmt(im.withoutMin) + ')</div><div style="display:flex;flex-wrap:wrap;gap:6px;margin-top:4px"><span class="badge" style="background:' + tag[0] + ';color:' + tag[1] + ';padding:2px 8px;font-size:12px">' + tag[2] + '</span>' + scorePill(im.status) + '</div>';
  };
  const simRows = data.planned.map((p) => '<div class="row tap" data-act="edit:sim:' + p.id + '"><span class="chk' + (p.on !== false ? ' on' : '') + '" data-act="simtog:' + p.id + '" role="checkbox" aria-checked="' + (p.on !== false) + '">' + RMI('check-line', 16, '#fff') + '</span>' +
    '<div class="grow"><div class="name" style="font-size:16px">' + esc(p.name) + '</div><div class="sub" style="font-size:13px">' + dlabel(pd(p.date)) + (p.kind === 'pay' && p.card ? ' · Pago de crédito' : '') + '</div>' + impactHTML(p) + '<div style="padding-top:6px"><button class="execbtn" data-act="exec:' + p.id + '">Ejecutar</button></div></div><span class="amt">' + fmt(p.amount) + '</span>' + ICON.chev + '</div>').join('');
  $('#s-proyeccion').innerHTML =
    '<div class="head"><div><div class="eyebrow" id="pEye"></div><h1>Proyección</h1></div></div>' + tabSel('proyeccion') +
    '<div class="card" id="cal"></div>' +
    '<div class="card">' +
      segHTML('hor', [{ k: 13, label: '3 meses', act: 'hor:13' }, { k: 26, label: '6 meses', act: 'hor:26' }, { k: 52, label: '12 meses', act: 'hor:52' }], ui.hor) +
      '<div class="lbl" id="pLabel"></div><div class="big" style="font-size:38px" id="pBig"></div><div class="sub" id="pDelta"></div><div id="pWarn"></div>' +
      '<div id="pChart" style="margin-top:12px"></div><div class="ticks" id="pTicks"></div>' +
      '<div style="padding-top:6px"><div class="sub" id="pWeek"></div><input type="range" id="weekRange" min="0" max="' + ui.hor + '" step="0.01" value="' + ui.week + '" style="--f:' + (ui.week / ui.hor) + '" aria-label="Semana de la proyección"></div>' +
      '<div class="row" style="border-top:1px solid var(--line)"><span class="grow" style="font-size:17px">Incluir gasto variable <span class="sub">(' + fmt(data.settings.variable_weekly || 0) + ' por semana)</span></span>' +
      '<button class="switch' + (ui.variable ? ' on' : '') + '" id="pSwitch" role="switch" aria-checked="' + ui.variable + '" aria-label="Incluir gasto variable estimado" data-act="toggle"><span></span></button></div>' +
      '<div class="stats"><div><span class="sub">Mínimo proyectado</span><b id="pMin"></b></div><div><span class="sub">Primera semana en rojo</span><b id="pRed"></b></div></div>' +
    '</div>' +
    secHead('Ingresos previstos') + '<div class=\"card lst\">' + (inRows || '<div class="empty">Sin ingresos previstos</div>') +
      (est.length ? '<div class="sub" style="font-size:13px;padding:6px 0 2px">Variación media vs. lo previsto: <b style="color:' + (avgVar < 0 ? 'var(--rt)' : 'var(--gt)') + '">' + (avgVar >= 0 ? '+' : '−') + fmt2(avgVar) + '</b> (' + plural(est.length, 'ingreso confirmado', 'ingresos confirmados') + ')</div>' : '') +
      addRow('income', 'Añadir ingreso previsto') + '</div>' +
    secHead('Trabajos') + '<div class="card lst">' + (jobRows || '<div class="empty">Sin trabajos</div>') + addRow('job', 'Añadir un trabajo') + '</div>' + (jobIn ? secHead('Últimos ingresos de trabajo') + '<div class="card lst">' + jobIn + '</div>' : '') +
    '<div class="sub" style="padding:0 8px 16px;font-size:13px">Cada trabajo genera sus pagos previstos según horas, impuestos y frecuencia. En "Solo simular" aparecen únicamente en la gráfica.</div>' +
    secHead('Gastos previstos') + '<div class=\"card lst\">' + (exRows || '<div class="empty">Sin gastos previstos</div>') + addRow('expense', 'Añadir gasto previsto') + (data.cards.length ? '<div class="hr" style="margin:0"></div>' + addRow('cardpay', 'Añadir pago de crédito previsto') : '') + '</div>' +
    secHead('Simular gastos') + '<div class="card lst">' + simRows + addRow('sim', 'Simular un gasto') + '</div>' +
    '<div class="sub" style="padding:0 8px 16px;font-size:13px">Los activados cambian la gráfica y muestran su impacto entre dos fechas.</div>' +
    secHead('Próximos eventos') + '<div class="card"><div id="pTimeline"></div></div>';
  void c;
  renderCal();
  updateProjection();
}
const DOTC = { in: '#22B573', out: '#8E8E93', sub: '#F08FB0', card: '#B98AE6', rec: '#6D8BEA', sim: '#FF9F0A', exp: '#FF6B5E' };
function renderCal() {
  const el = $('#cal'); if (!el) return;
  const c = calc(), cushion = data.settings.cushion || 0, tk = iso(c.today);
  const base = new Date(c.today.getFullYear(), c.today.getMonth(), 1);
  if (!ui.calMonth) ui.calMonth = 0;
  const m = new Date(base.getFullYear(), base.getMonth() + ui.calMonth, 1);
  const bal = {}; dailySeries({}).forEach((x) => { bal[x.key] = x.v; });
  const by = {}, add = (k, type, name, amt, pend, key, skipped) => { (by[k] = by[k] || []).push({ type: type, name: name, amt: amt, pend: pend, key: key, skipped: skipped }); };
  genEvents(c.today, { keepSkipped: true }).forEach((e) => { if (e.pending) add(e.orig, e.type, e.name, e.amt, true); else add(iso(e.date), e.type, e.name, e.amt, false, e.key, e.skipped); });
  data.transactions.forEach((t) => { if (t.date <= tk) add(t.date, t.amount > 0 ? 'in' : 'out', t.note || t.category, txUSD(t)); });
  const sel = ui.calSel || tk, last = new Date(m.getFullYear(), m.getMonth() + 1, 0).getDate(), lead = (m.getDay() + 6) % 7;
  let cells = '';
  for (let i = 0; i < lead; i++) cells += '<span></span>';
  for (let d = 1; d <= last; d++) {
    const k = iso(new Date(m.getFullYear(), m.getMonth(), d)), list = by[k] || [], b = bal[k];
    const types = []; list.forEach((x) => { if (!x.skipped && types.indexOf(x.type) < 0) types.push(x.type); });
    const tint = k > tk && b != null ? (b < 0 ? ' red' : b < cushion ? ' amber' : '') : '';
    cells += '<button class="cd' + tint + (k === tk ? ' today' : '') + (k === sel ? ' sel' : '') + '" data-act="calsel:' + k + '"><b>' + d + '</b><span class="dots">' + types.slice(0, 4).map((t) => '<i style="background:' + DOTC[t] + '"></i>').join('') + '</span></button>';
  }
  const dayEv = (by[sel] || []);
  const detail = '<div class="calsel"><div class="name" style="font-size:16px">' + dlabel(pd(sel)) + (bal[sel] != null ? ' <span class="sub" style="font-weight:500">· saldo ' + fmt(bal[sel]) + '</span>' : '') + '</div>' +
    (dayEv.length ? dayEv.map((x) => '<div class="row' + (x.key ? ' tap' : '') + '" style="padding:8px 0' + (x.skipped ? ';opacity:.5' : '') + '"' + (x.key ? ' data-act="evedit:' + x.key + '"' : '') + '><span class="dotl" style="background:' + DOTC[x.type] + '"></span><span class="grow" style="font-size:15px' + (x.skipped ? ';text-decoration:line-through' : '') + '">' + esc(x.name) + (x.pend ? ' <span class="badge" style="background:var(--obg);color:var(--ot);padding:1px 8px;font-size:11px">por confirmar</span>' : '') + '</span><b style="font-size:15px;color:' + (x.amt > 0 ? 'var(--gt)' : '#1C1C1E') + '">' + (x.amt > 0 ? '+' : '') + fmt(x.amt) + '</b></div>').join('') : '<div class="sub" style="font-size:14px;padding:4px 0">Sin movimientos este día</div>') + '</div>';
  el.innerHTML = '<div class="calhead"><button class="calnav" data-act="calnav:-1" aria-label="Mes anterior"' + (ui.calMonth <= -2 ? ' disabled' : '') + '>‹</button><div class="name" style="font-size:18px">' + MON_FULL[m.getMonth()].charAt(0).toUpperCase() + MON_FULL[m.getMonth()].slice(1) + ' ' + m.getFullYear() + '</div><button class="calnav" data-act="calnav:1" aria-label="Mes siguiente"' + (ui.calMonth >= 12 ? ' disabled' : '') + '>›</button></div>' +
    '<div class="calgrid dow">' + ({ es: ['L', 'M', 'X', 'J', 'V', 'S', 'D'], en: ['M', 'T', 'W', 'T', 'F', 'S', 'S'], it: ['L', 'M', 'M', 'G', 'V', 'S', 'D'], ja: ['月', '火', '水', '木', '金', '土', '日'], fr: ['L', 'M', 'M', 'J', 'V', 'S', 'D'], sh: ['P', 'U', 'S', 'Č', 'P', 'S', 'N'] })[LANG].map((x) => '<span>' + x + '</span>').join('') + '</div><div class="calgrid">' + cells + '</div>' +
    '<div class="legend" style="flex-wrap:wrap;margin:10px 0 4px"><span><u style="background:#22B573;border-radius:50%"></u>Ingreso</span><span><u style="background:#8E8E93;border-radius:50%"></u>Gasto</span><span><u style="background:#F08FB0;border-radius:50%"></u>Servicio o suscripción</span><span><u style="background:#B98AE6;border-radius:50%"></u>Pago de deuda</span><span><u style="background:#FF9F0A;border-radius:50%"></u>Simulado</span></div>' + detail;
}
let lastProj = null;
function updateProjection(fast) {
  const p = (fast && lastProj) ? lastProj : (lastProj = projection());
  const H = ui.hor, ser = p.series.slice(0, H + 1), minV = Math.min.apply(null, ser.map((s) => s.v)), firstRed = ser.find((s) => s.v < 0);
  if (ui.week > H) ui.week = H;
  const cur = { v: valAt(ser, ui.week), date: dateAt(ser, ui.week) }, delta = cur.v - p.c.balance, cushion = data.settings.cushion || 0;
  const rg = $('#weekRange'); if (rg) { rg.max = String(H); rg.style.setProperty('--f', String(ui.week / H)); }
  $('#pLabel').textContent = '¿Cuánto tendré el ' + dlabel(cur.date) + '?';
  $('#pBig').textContent = fmt(cur.v);
  $('#pDelta').textContent = (delta >= 0 ? '+' : '') + fmt(delta) + ' frente a hoy';
  $('#pWarn').innerHTML = cur.v < 0
    ? '<span class="badge" style="background:var(--rbg);color:var(--rt)">En rojo</span>'
    : cur.v < cushion ? '<span class="badge" style="background:var(--obg);color:var(--ot)">Bajo tu colchón de ' + fmt(cushion) + '</span>' : '';
  $('#pChart').innerHTML = projSVG(ser, ui.week);
  $('#pTicks').innerHTML = [0, 0.25, 0.5, 0.75, 1].map((f) => '<span>' + dshort(ser[Math.round(H * f)].date) + '</span>').join('');
  $('#pWeek').textContent = 'Semana ' + Math.round(ui.week) + ' de ' + H;
  const eye = $('#pEye'); if (eye) eye.textContent = H === 13 ? 'Próximos 3 meses' : H === 26 ? 'Próximos 6 meses' : 'Próximos 12 meses';
  $('#pMin').textContent = fmt(minV);
  $('#pRed').textContent = firstRed ? dshort(firstRed.date) : 'ninguna';
  const dotColor = { in: '#22B573', card: '#B98AE6', rec: '#A1A1A6', sub: '#F08FB0', sim: '#FF9F0A', exp: '#FF6B5E', out: '#8E8E93' };
  $('#pTimeline').innerHTML = p.timeline.length
    ? '<div class="tl">' + p.timeline.map((e) =>
      '<div class="ev' + (e.key ? ' tap' : '') + '"' + (e.key ? ' data-act="evedit:' + e.key + '"' : '') + (e.skipped ? ' style="opacity:.5"' : '') + '><span class="dot" style="background:' + dotColor[e.type] + '"></span><div class="grow"><div class="name" style="font-size:16px' + (e.skipped ? ';text-decoration:line-through' : '') + '">' + esc(e.name) + '</div><div class="sub" style="font-size:13px">' + e.date + (e.skipped ? ' <span class="badge" style="background:var(--fill);color:var(--mute);padding:1px 8px;font-size:11px">Omitido</span>' : e.edited ? ' <span class="badge" style="background:var(--gbg);color:var(--gt);padding:1px 8px;font-size:11px">Editado</span>' : '') + '</div></div>' +
      '<div style="text-align:right"><div class="amt" style="font-weight:600;color:' + (e.amt > 0 ? 'var(--gt)' : '#1C1C1E') + '">' + (e.amt > 0 ? '+' : '') + fmt(e.amt) + '</div><div class="sub" style="font-size:13px">' + (e.skipped ? '—' : fmt(e.after)) + '</div></div>' + (e.key ? ICON.chev : '<span style="width:12px;flex:none"></span>') + '</div>').join('') + '</div>'
    : '<div class="empty">No hay eventos programados</div>';
}

function segHTML(name, items, cur, extra) {
  const idx = Math.max(0, items.findIndex((it) => it.k === cur));
  return '<div class="seg" data-seg="' + name + '" style="--n:' + items.length + ';--i:' + idx + (extra || '') + '"><span class="thumb"></span>' +
    items.map((it, i) => '<button class="' + (i === idx ? 'on' : '') + '" data-act="' + it.act + '">' + it.label + '</button>').join('') + '</div>';
}
function tabSel(cur) { return '<div class="tabsel">' + segHTML('tabsel', [{ k: 'proyeccion', label: 'Proyección', act: 'tab:proyeccion' }, { k: 'ahorro', label: 'Ahorro', act: 'tab:ahorro' }], cur) + '</div>'; }
function setSeg(btn) {
  const seg = btn.closest('.seg'), bs = Array.prototype.slice.call(seg.querySelectorAll('button')), i = bs.indexOf(btn);
  seg.style.setProperty('--i', i);
  bs.forEach((b, j) => b.classList.toggle('on', j === i));
}
function swapIn(el) { el.classList.remove('swap'); void el.offsetWidth; el.classList.add('swap'); }
/* Marca de origen: el movimiento se anotó desde el Apple Watch (campo `src` del movimiento) */
const WATCH_MARK = '<svg role="img" viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="display:inline-block;margin-left:5px;vertical-align:-2px;opacity:.6"><rect x="6" y="6" width="12" height="12" rx="3"/><path d="M9 6l.6-3h4.8L15 6M9 18l.6 3h4.8L15 18"/></svg>';
function txRow(t, sw) {
    const cat = isPay(t) ? pcat(t) : t.amount > 0 ? 'Ingreso' : (CAT_ORDER.indexOf(t.category) >= 0 ? t.category : 'Otros');
    const d = pd(t.date), cur = accOf(t.acc).cur, sb = txSub(t);
    const html = '<div class="row tap"' + (sw && isWebView() ? ' data-ctx="' + (isPay(t) ? 'p' : 't') + '"' : '') + ' data-act="tx:' + t.id + '">' + (sb ? subTile(sb, data.subs.indexOf(sb)) : '<span class="tile" style="background:' + (cat === XFER ? 'transparent' : cat === PAY ? '#B98AE6' : CAT_COLOR[cat]) + '" aria-hidden="true">' + (cat === XFER ? RMI('arrow-left-right-line', 30, t.amount < 0 ? 'var(--rt)' : '#22B573') : cat === PAY ? iconSVG('card', '#fff', 20) : catGlyph(cat)) + '</span>') +
      '<div class="grow"><div class="name" style="font-size:16px">' + esc(t.note || cat) + '</div><div class="sub" style="font-size:13px">' + (cat === XFER ? (t.amount < 0 ? 'Salida' : 'Entrada') : sb ? 'Suscripción' : esc(cat)) + ' · ' + dshort(d) + (data.accounts.length + data.cards.length > 1 ? ' · ' + (t.src === 'watch' ? '<span style="white-space:nowrap">' + esc(accOf(t.acc).name) + WATCH_MARK + '</span>' : esc(accOf(t.acc).name)) : (t.src === 'watch' ? WATCH_MARK : '')) + '</div></div>' +
      amtHrs(t, '<span class="amt" style="color:' + (t.amount > 0 && !isPay(t) ? 'var(--gt)' : 'var(--ink)') + '">' + fmtSC2(t.amount, cur) + '</span>') + ICON.chev + '</div>';
    return sw && !isWebView() ? swWrap(t, html, isPay(t), isXfer(t)) : html;
}
const SW_BTN = (act, id, bg, ic, lbl) => '<button class="swb" data-act="' + act + ':' + id + '"><i style="background:' + bg + '">' + RMI(ic, 22, '#fff') + '</i><span>' + lbl + '</span></button>';
function swWrap(t, html, pay, xf) {
  const n = xf ? 1 : pay ? 2 : 3;
  return '<div class="swrow" style="--swn:' + n + '"><div class="swacts">' + (xf ? '' : SW_BTN('swedit', t.id, '#4F94F7', 'edit-line', 'Editar')) + (pay ? '' : SW_BTN('swpost', t.id, '#FF9F0A', 'calendar-event-line', 'Posponer')) + SW_BTN('swdel', t.id, '#EB5757', 'delete-bin-line', 'Eliminar') + '</div><div class="swc">' + html + '</div></div>';
}
function seasonSide(k, g, right) {
  /* Cada pieza va en <g class="m ..."> para poder moverla una vez al abrir (ver `seasonPlay`); en reposo se ve igual que siempre. */
  const M = (cls, inner, st) => '<g class="m ' + cls + '"' + (st ? ' style="' + st + '"' : '') + '>' + inner + '</g>';
  const AT = (tr, inner) => '<g transform="' + tr + '">' + inner + '</g>';
  const leafD = 'M0 -14 C10 -8 12 6 0 16 C-12 6 -10 -8 0 -14Z', sparkD = 'M0 -9 Q1 -1 9 0 Q1 1 0 9 Q-1 1 -9 0 Q-1 -1 0 -9Z';
  const P = (d, f, o) => '<path d="' + d + '" fill="' + f + '"' + (o ? ' opacity="' + o + '"' : '') + '/>';
  const flake = (tr, c, st) => AT(tr, M('flk', '<g stroke="' + c + '" stroke-width="2.2" stroke-linecap="round" fill="none"><path d="M0 -9V9M-7.8 -4.5L7.8 4.5M-7.8 4.5L7.8 -4.5"/></g>', st));
  const petal = (f, o) => '<ellipse rx="11" ry="5.5" fill="' + f + '" opacity="' + o + '"/>';
  const tw = (tr, f, o, del) => AT(tr, M('tw', P(sparkD, f, o), '--del:' + del + 's'));
  const art = {
    autumn: AT('translate(18 22) rotate(-25) scale(1.15)', M('sway', P(leafD, g[1], .95), '--del:.2s')) + AT('translate(46 38) rotate(32) scale(.85)', M('sway', P(leafD, g[0]), '--del:.5s')) + AT('translate(60 12) rotate(62) scale(.6)', M('sway', P(leafD, g[2], .75), '--del:.8s')) +
      AT('translate(30 2)', M('gh', P(leafD, g[0], .9), '--r:-20deg;--s:.62;--sx:7px;--del:.5s;--dur:2.5s')) + AT('translate(54 -2)', M('gh', P(leafD, g[1], .9), '--r:35deg;--s:.5;--sx:-6px;--del:1.3s;--dur:2.7s')) + AT('translate(8 4)', M('gh', P(leafD, g[3] || g[0], .9), '--r:10deg;--s:.45;--sx:8px;--del:2s;--dur:2.3s')),
    winter: flake('translate(18 24) scale(1.3)', g[1], '--k:1.4;--del:.25s;--dur:2s') + flake('translate(46 40) scale(.9)', g[0], '--k:1.45;--del:.9s;--dur:1.9s') + flake('translate(60 14) scale(.65)', g[2], '--k:1.5;--del:1.5s;--dur:1.8s'),
    spring: AT('translate(20 24) rotate(-35)', M('flut', petal(g[0], .95), '--del:.2s')) + AT('translate(46 38) rotate(28)', M('flut', petal(g[1], .9), '--del:.55s')) + AT('translate(60 14) rotate(-10) scale(.7)', M('flut', petal(g[3] || g[0], .9), '--del:.9s')) +
      AT('translate(34 0) rotate(-20)', M('gh soft', petal(g[0], .9), '--r:-20deg;--s:.55;--sx:9px;--del:.6s;--dur:3s')) + AT('translate(56 -2) rotate(15)', M('gh soft', petal(g[3] || g[0], .9), '--r:15deg;--s:.45;--sx:-8px;--del:1.6s;--dur:3s')),
    summer: M('sun', '<circle cx="20" cy="24" r="8.5" fill="' + g[0] + '"/>') + M('rays', '<g stroke="' + g[0] + '" stroke-width="2.4" stroke-linecap="round"><path d="M20 8V11M20 37V40M4 24H7M33 24H36M8.5 12.5L10.6 14.6M31.5 35.5L29.4 33.4M8.5 35.5L10.6 33.4M31.5 12.5L29.4 14.6"/></g>') + tw('translate(48 40)', g[1], .95, .3) + AT('translate(60 14) scale(.65)', M('tw', P(sparkD, g[3]), '--del:.7s'))
  };
  if (k === 'summer' && right) art.summer = ['M4 14 q4.5 -6 9 0 t9 0 t9 0 t9 0', 'M4 25 q4.5 -6 9 0 t9 0 t9 0 t9 0', 'M4 36 q4.5 -6 9 0 t9 0 t9 0 t9 0'].map((d, n) => M('wv', '<path d="' + d + '" fill="none" stroke="' + (n === 1 ? g[1] : g[0]) + '" stroke-width="2.4" stroke-linecap="round" opacity="' + (n === 1 ? 1 : .7) + '"/>', '--del:' + (n * .22) + 's')).join('') + tw('translate(48 40)', g[1], .95, .3) + AT('translate(60 14) scale(.65)', M('tw', P(sparkD, g[3]), '--del:.7s'));
  return '<svg aria-hidden="true"' + '' + ' viewBox="0 0 72 56" width="64" height="50">' + art[k] + '</svg>';
}
/* Una sola vez por apertura, cuando el encabezado del mes ya se ve (después del splash): le pone .play y las piezas se mueven ~4 s y vuelven. */
let seasonPlayed = false, seasonTimer = 0;
/* Al cambiar de mes en el selector, el dibujo de la temporada vuelve a moverse una vez. */
function seasonReplay() {
  seasonPlayed = true;
  if (window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  requestAnimationFrame(() => {
    clearTimeout(seasonTimer);
    document.querySelectorAll('.mhead').forEach(h => { h.classList.remove('play'); void h.offsetWidth; h.classList.add('play'); });
    seasonTimer = setTimeout(() => document.querySelectorAll('.mhead.play').forEach(h => h.classList.remove('play')), 5200);
  });
}
function seasonPlay() {
  if (seasonPlayed) return;
  if (window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches) { seasonPlayed = true; return; }
  const iv = setInterval(() => {
    if (seasonPlayed) { clearInterval(iv); return; }
    if (document.hidden || document.getElementById('splash') || document.querySelector('.welcome')) return;
    const hs = document.querySelectorAll('.mhead');
    for (let i = 0; i < hs.length; i++) {
      const r = hs[i].getBoundingClientRect(), vh = window.innerHeight || document.documentElement.clientHeight;
      if (!r.height || !hs[i].offsetParent) continue;
      const vis = Math.min(r.bottom, vh) - Math.max(r.top, 0);
      if (vis >= r.height * .6) {
        seasonPlayed = true; clearInterval(iv);
        document.querySelectorAll('.mhead').forEach(h => h.classList.add('play'));
        clearTimeout(seasonTimer); seasonTimer = setTimeout(() => document.querySelectorAll('.mhead.play').forEach(h => h.classList.remove('play')), 5200);
        return;
      }
    }
  }, 400);
}
const SEASON_ES = { autumn: 'Otoño', winter: 'Invierno', spring: 'Primavera', summer: 'Verano' };
function monthHead(T, small) {
  const k = seasonKey(T), g = SEASON_GRAD[k], mes = cap1(MON_FULL[T.getMonth()]), side = seasonSide(k, g);
  return '<div class="mhead" style="--s1:' + g[1] + ';--s2:' + g[2] + ';--d1:' + g[0] + ';--d2:' + g[1] + '"><div class="ma">' + side + '</div><div class="mtx"><div class="msm">' + (small || '<span>' + SEASON_ES[k] + '</span> ' + T.getFullYear()) + '</div><div class="mbig">' + mes + '</div></div><div class="ma r">' + (k === 'summer' ? seasonSide(k, g, true) : side) + '</div></div>';
}
function monthMovCard(c) {
  const mk = iso(c.today).slice(0, 7), mes = MON_FULL[c.today.getMonth()], hs = hidSet();
  const list = c.tx.filter((t) => t.date.slice(0, 7) === mk && !(hs && hs.has(t.acc || data.accounts[0].id)));
  const ms = monthSums(mk, 0), net = ms.inc - ms.exp;
  const st = (l, v, col) => '<div><span class="sub">' + l + '</span><b' + (col ? ' style="color:' + col + '"' : '') + '>' + v + '</b></div>';
  const sum = list.length ? '<div class="stats" style="margin:0;padding:14px 12px 12px;border:0;border-bottom:1px solid var(--line);display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:6px;text-align:center">' + st('Ingresos', fmt(ms.inc), 'var(--gt)') + st('Gastos', fmt(ms.exp)) + st('Neto', (net < 0 ? '−' : '') + fmt(Math.abs(net)), net < 0 ? 'var(--rt)' : 'var(--gt)') + '</div>' : '';
  const rows = list.length ? list.slice(0, 5).map((t) => txRow(t, true)).join('') : '<div class="empty">Aún sin movimientos en ' + mes + '</div>';
  return monthHead(c.today) + '<div class="card lst">' + sum + rows +
    '<button class="linkrow moreRow" data-act="month" style="width:100%;border-top:1px solid var(--line)"><span class="grow">Ver todo ' + mes + '</span>' + ICON.chev + '</button></div>';
}
function movRows(limit, accId) {
  const c = calc();
  const hs = !accId && limit ? hidSet() : null;
  const list = c.tx.filter((t) => hs && hs.has(t.acc || data.accounts[0].id) ? false : accId ? (t.acc || data.accounts[0].id) === accId : limit || ui.mov === 'all' || (ui.mov === 'in' ? t.amount > 0 && !isPay(t) : t.amount < 0 && !isPay(t))).slice(0, limit || 40);
  const rows = list.map((t) => txRow(t, !limit && !accId)).join('');
  return rows || '<div class="empty">Sin movimientos todavía</div>';
}

