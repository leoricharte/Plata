/* ---------- Detalle de previstos / suscripciones / categorías ---------- */
function itemBackNav() {
  const b = ui.itemBack || {}; ui.itemId = null; ui.itemDel = false;
  ui.prevTab = b.prev; setTab(b.tab || 'resumen');
}
function openItem(kind, id) {
  ui.itemBack = { tab: ui.tab, prev: ui.prevTab };
  ui.prevTab = ui.tab === 'cuenta' ? ui.prevTab : ui.tab; ui.itemKind = kind; ui.itemId = id; ui.itemDel = false; ui.txId = null;
  closeSheet(); renderCuenta(); setTab('cuenta');
}
function renderItem(el) {
  if (ui.itemKind === 'credits') {
    el.innerHTML = '<div class="navrow"><button class="back" data-act="itback" aria-label="Regresar">' + IC_BACK + '</button></div>' +
      '<div class="head"><div><h1>Créditos</h1></div></div>' + creditsHTML();
    return true;
  }
  if (ui.itemKind === 'imp') { el.innerHTML = impPageHTML(); return true; }
  if (ui.itemKind === 'profile') {
    el.innerHTML = '<div class="navrow"><button class="back" data-act="itback" aria-label="Regresar">' + IC_BACK + '</button></div>' +
      '<div class="head"><div><h1>Perfil</h1></div></div>' + profileHTML();
    return true;
  }
  if (ui.itemKind === 'settings') {
    el.innerHTML = '<div class="navrow"><button class="back" data-act="itback" aria-label="Regresar">' + IC_BACK + '</button></div>' +
      '<div class="head"><div><h1>Ajustes</h1></div></div>' + settingsHTML(true);
    return true;
  }
  if (ui.itemKind === 'month') { el.innerHTML = monthScreenHTML(); return true; }
  if (ui.itemKind === 'insights') {
    const sel = insSel(), mes = MON_FULL[sel.m.T.getMonth()];
    el.innerHTML = '<div class="navrow"><button class="back" data-act="itback" aria-label="Regresar">' + IC_BACK + '</button></div>' +
      '<div class="head"><div><div class="eyebrow">' + (sel.half ? 'Hasta el día 15' : sel.m.isCur ? cap1(mes) + ' · día ' + sel.m.day : 'Cierre de ' + mes) + '</div><h1>' + (sel.half ? 'Half‑time' : 'Insights') + '</h1></div></div>' + insightsHTML(true);
    return true;
  }
  const kind = ui.itemKind, id = ui.itemId, st = (l, v, c) => '<div><span class="sub">' + l + '</span><b' + (c ? ' style="color:' + c + '"' : '') + '>' + v + '</b></div>';
  let o, col, glyph, title, sub, big, bigCol = '#1C1C1E', rows = '', btns = '', extra = '', canDel = true;
  const today = iso(getToday());
  if (kind === 'income' || kind === 'expense') {
    const out = kind === 'expense'; o = data[out ? 'expected_expense' : 'expected_income'].find((x) => x.id === id);
    if (o) {
      const oe = effItem(out ? 'exp' : 'in', o), cur = accOf(o.acc).cur, days = Math.round((pd(oe.date) - getToday()) / 86400000), ec = CAT_ORDER.indexOf(o.cat) >= 0 ? o.cat : 'Otros', d = pd(oe.date);
      const pcd = out ? payOf(o) : null;
      col = pcd ? '#B98AE6' : out ? CAT_COLOR[ec] : '#22B573'; glyph = pcd ? iconSVG('card', '#fff', 24) : out ? catGlyph(ec) : esc(o.name || '?').charAt(0); title = o.name;
      sub = pcd ? 'Pago de crédito previsto' : out ? 'Gasto previsto' : 'Ingreso previsto'; big = (out ? '−' : '+') + fmtC2(oe.amount, cur); bigCol = out ? '#1C1C1E' : 'var(--gt)';
      const when = oe.date < today ? 'Venció hace ' + plural(-days, 'día', 'días') : days === 0 ? 'Es hoy' : 'En ' + plural(days, 'día', 'días');
      rows = '<div class="stats" style="border:0;margin:0;padding:0;gap:20px">' + st('Cuenta', esc(accOf(o.acc).name)) + st('Fecha', dlabel(d) + ' ' + d.getFullYear()) + '</div>' +
        '<div class="stats" style="margin-top:14px;gap:20px">' + st('Cuándo', when, oe.date < today ? 'var(--rt)' : '') + st('Se repite', o.repeat ? repLabel(o.repeat) : 'Una vez') + (o.repeat && o.until ? st('Termina', dlabel(pd(o.until))) : '') + '</div>' +
        (pcd ? '<div class="stats" style="margin-top:14px;gap:20px">' + st(pcd.kind === 'loan' ? 'Préstamo' : 'Tarjeta', esc(pcd.name)) + '</div>' : out ? '<div class="stats" style="margin-top:14px;gap:20px">' + st('Categoría', esc(ec)) + '</div>' : '');
      btns = '<button class="primary" data-act="itconf">' + (pcd ? 'Confirmar pago' : out ? 'Confirmar gasto' : 'Confirmar ingreso') + '</button>' +
        (o.date > today ? '<button class="secbtn" data-act="ittoday">Adelantar a hoy</button>' : '');
    }
  } else if (kind === 'job') {
    o = data.jobs.find((x) => x.id === id);
    if (o) {
      const cur = accOf(o.acc).cur, sal = o.mode === 's', nx = (data.expected_income.find((e) => e.job === o.id) || {}).date || o.start;
      col = o.sim ? '#FF9F0A' : '#22B573'; glyph = esc(o.name || '?').charAt(0); title = o.name; sub = (sal ? 'Perú' : 'EE.UU.') + (o.sim ? ' · Simulado' : ''); big = '+' + fmtC2(jobNet(o), cur); bigCol = 'var(--gt)';
      rows = '<div class="stats" style="border:0;margin:0;padding:0;gap:20px">' + (sal ? st('Ingreso mensual', fmtC2(o.rate, cur)) : st('Pago por hora', fmtC2(o.rate, cur))) + st('Se cobra', repLabel(jobRep(o.freq, o))) + '</div>' +
        (sal ? '' : '<div class="stats" style="margin-top:14px;gap:20px">' + st('Horas por semana', fmtHrs(o.hours)) + st('Impuestos', o.tax + '%') + '</div>') +
        '<div class="stats" style="margin-top:14px;gap:20px">' + st('Cuenta', esc(accOf(o.acc).name)) + st(o.sim ? 'Primer pago' : 'Próximo pago', dlabel(pd(o.sim ? o.start : nx))) + (o.until ? st('Termina', dlabel(pd(o.until))) : '') + '</div>';
      const my = jobTxs().filter((t) => t.job === o.id);
      btns = secHead('Últimos ingresos') + '<div class="card lst">' + (my.length ? my.map((t) => '<div class="row tap" data-act="tx:' + t.id + '">' + tile('#22B573', esc(t.note || 'T').charAt(0)) + '<div class="grow"><div class="name" style="font-size:16px">' + esc(t.note) + '</div><div class="sub" style="font-size:13px">' + dlabel(pd(t.date)) + '</div></div>' + amtHrs(t, '<span class="amt" style="color:var(--gt);font-weight:600">+' + fmtC(t.amount, accOf(t.acc).cur) + '</span>') + ICON.chev + '</div>').join('') : '<div class="empty">Aún no hay ingresos confirmados</div>') + '</div>';
    }
  } else if (kind === 'sub') {
    o = data.subs.find((x) => x.id === id);
    if (o) {
      const i = data.subs.indexOf(o), sbr = subBrand(o); col = sbr ? sbr.bg : CARD_COLORS[i % CARD_COLORS.length]; glyph = sbr ? subSVG(sbr, 34) : esc(o.name || '?').charAt(0); title = o.name; sub = 'Servicio o suscripción'; big = fmtC2(o.amount, o.cur);
      rows = '<div class="stats" style="border:0;margin:0;padding:0;gap:20px">' + st('Día de cobro', 'Día ' + o.day) + st('Frecuencia', 'Cada mes') + '</div>' +
        (o.acc && (data.accounts.concat(data.cards)).some((x) => x.id === o.acc) ? '<div class="stats" style="margin-top:14px;gap:20px">' + st('Se cobra de', esc(accOf(o.acc).name)) + '</div>' : '') +
        '<div class="stats" style="margin-top:14px;gap:20px">' + st('Por año', fmtC2(round2(o.amount * 12), o.cur)) + (o.cur !== curP() ? st('Equivale a', '≈ ' + fmt2(usd(o.amount, o.cur))) : '') + '</div>';
      btns = '<button class="primary" data-act="subadv" style="background:#22B573;color:#fff">Adelantar cobro</button>' + '<div style="height:12px"></div>' + secHead('Historial') + '<div class="card">' + subHist(o) + '</div>';
    }
  } else if (kind === 'budget') {
    const cc = data.cats.find((x) => x.name === id);
    if (cc) {
      o = cc; const fmt = bfmt, c = calc(), lim = budOf(viewSet())[id] || 0, sp = c.catTot[id] || 0, over = lim && sp > lim;
      col = CAT_COLOR[id] || cc.color || '#8E8E93'; glyph = catGlyph(id); title = id; sub = 'Categoría'; big = lim ? fmt(lim - sp) : fmt(sp); bigCol = over ? 'var(--rt)' : '#1C1C1E';
      rows = (lim ? '<div class="bar"><i style="width:' + Math.min(100, sp / lim * 100) + '%;background:' + (over ? '#FF3B30' : col) + '"></i></div>' : '') +
        '<div class="stats" style="' + (lim ? 'margin-top:14px;' : 'border:0;margin:0;padding:0;') + 'gap:20px">' + st('Gastado este mes', fmt(sp)) + st('Límite', lim ? fmt(lim) : 'Sin límite') + '</div>' +
        (lim ? '<div class="stats" style="margin-top:14px;gap:20px">' + st(over ? 'Te pasaste por' : 'Disponible', fmt(Math.abs(lim - sp)), over ? 'var(--rt)' : 'var(--gt)') + '</div>' : '');
      canDel = id !== 'Otros';
      const mkB = iso(c.today).slice(0, 7), lt = data.transactions.filter((t) => t.date.slice(0, 7) === mkB && t.amount < 0 && !isPay(t) && (CAT_ORDER.indexOf(t.category) >= 0 ? t.category : 'Otros') === id).sort((x, y) => (x.date < y.date ? 1 : x.date > y.date ? -1 : (y.id || 0) - (x.id || 0)));
      extra = secHead('Movimientos') + (lt.length ? '<div class="card lst">' + lt.map((t) => txRow(t, true)).join('') + '</div>' : '<div class="card"><div class="empty">Sin movimientos en este mes</div></div>');
    }
  }
  if (!o) { ui.itemId = null; if (ui.tab === 'cuenta') itemBackNav(); return false; }
  el.innerHTML =
    '<div class="navrow"><button class="back" data-act="itback" aria-label="Regresar">' + IC_BACK + '</button>' +
    '<button class="editbtn" data-act="itedit" aria-label="Editar">' + IC_PEN + '</button></div>' +
    '<div class="acctop"><div class="ptile"><span class="tile" style="background:' + col + '" aria-hidden="true">' + glyph + '</span></div><h1 style="font-size:28px;margin:10px 0 2px">' + esc(title) + '</h1><div class="sub">' + sub + '</div>' +
    '<div class="big" style="font-size:40px;margin-top:12px;color:' + bigCol + '">' + big + '</div></div>' +
    '<div class="card">' + rows + '</div>' + (extra || '') + btns + '<button class="secbtn" data-act="itedit">Editar</button>' +
    (canDel ? '<button class="delbtn" data-act="itdel">' + 'Eliminar' + '</button>' : '');
  return true;
}
/* Adelantar una suscripción: registra el cobro hoy y salta el próximo cobro de la serie */
function subAdvance(sb) {
  const today = iso(getToday()), ov = (data.ovr = data.ovr || {});
  let nx = dueAfter(sb.day || 1, today);
  for (let i = 0; i < 24 && ov['sub:' + sb.id + ':' + nx] && ov['sub:' + sb.id + ':' + nx].skip; i++) nx = dueAfter(sb.day || 1, nx);
  const acc = (sb.acc && data.accounts.concat(data.cards).find((x) => x.id === sb.acc)) || data.accounts.find((x) => x.cur === sb.cur) || data.accounts[0];
  if (!acc) { toast('Añade una cuenta primero'); return; }
  const prev = data.transactions.filter((t) => t.note === sb.name && t.amount < 0).sort((a, b) => (a.date < b.date ? 1 : -1))[0];
  const amt = acc.cur === sb.cur ? sb.amount : round2(fromUSD(usd(sb.amount, sb.cur), acc.cur));
  data.transactions.push({ id: nextTxId(), date: today, amount: -amt, category: prev ? prev.category : 'Ocio', note: sb.name, acc: acc.id, sub: sb.id });
  applyTo(acc, -amt);
  ov['sub:' + sb.id + ':' + nx] = { skip: true };
  ui.dirty++; persist(); renderAll(); toast('Cobro adelantado');
}
function askConfirm(title, msg, buttons, extra, cancelLabel) {
  const old = document.getElementById('alertback'); if (old) old.remove();
  const bk = document.createElement('div'); bk.id = 'alertback'; bk.className = 'alertback';
  const close = () => { bk.classList.remove('in'); setTimeout(() => bk.remove(), 220); };
  const box = document.createElement('div'); box.className = 'alertbox'; box.setAttribute('role', 'alertdialog');
  box.innerHTML = '<h4>' + esc(title) + '</h4>' + (msg ? '<p>' + esc(msg) + '</p>' : '') + (extra || '');
  buttons.concat([{ label: cancelLabel || 'Cancelar' }]).forEach((b) => {
    const bt = document.createElement('button'); bt.type = 'button'; bt.textContent = b.label; if (b.dest) bt.className = 'dest';
    bt.addEventListener('click', (ev) => { ev.stopPropagation(); close(); if (b.fn) setTimeout(b.fn, 60); }); box.appendChild(bt);
  });
  bk.appendChild(box); bk.addEventListener('click', (ev) => { if (ev.target === bk) close(); });
  deviceEl.appendChild(bk); requestAnimationFrame(() => bk.classList.add('in'));
}
/* cambio de moneda de una cuenta/tarjeta/meta/suscripción: mantener montos, convertir con el tipo asignado o con uno manual */
const CUR_MONEY = { account: ['balance'], saving: ['goal', 'balance', 'monthly'], debt: ['balance', 'limit', 'payment'], sub: ['amount'] };
const rndCur = (x, cur) => ((CURRENCIES[cur] || {}).dec === 0 ? Math.round(x) : round2(x));
/* unidades de «to» por 1 «from»: usa el tipo de cambio del perfil para principal/segunda y el de referencia para el resto */
const curRateBetween = (from, to) => { const P = curP(), S = curS(); if (S && from === P && to === S) return fxRate(); if (S && from === S && to === P) return 1 / fxRate(); const r = fxDefault(from, to); return r > 0 ? r : 1; };
function scaleOwn(o, kind, f, cur) {
  if (!(f > 0) || f === 1) return;
  (CUR_MONEY[kind] || []).forEach((m) => { if (o[m]) o[m] = rndCur(o[m] * f, cur); });
  if (kind === 'saving' && Array.isArray(o.log)) o.log.forEach((l) => { if (l && typeof l.amount === 'number') l.amount = rndCur(l.amount * f, cur); });
}
/* lo que se mide en la moneda de una cuenta o tarjeta: movimientos, previstos, simulados y trabajos que la usan */
function scaleLinked(id, f, cur) {
  if (!(f > 0) || f === 1) return;
  const ids = {};
  const sc = (arr, keys) => (arr || []).forEach((r) => { if (r && r.acc === id) { keys.forEach((k) => { if (typeof r[k] === 'number' && r[k]) r[k] = rndCur(r[k] * f, cur); }); if (r.id) ids[r.id] = 1; } });
  sc(data.transactions, ['amount']); sc(data.expected_income, ['amount']); sc(data.expected_expense, ['amount']); sc(data.planned, ['amount']); sc(data.jobs, ['rate']);
  Object.keys(data.ovr || {}).forEach((k) => { const q = k.split(':'), x = data.ovr[k]; if (ids[q[1]] && x && typeof x.amt === 'number') x.amt = rndCur(x.amt * f, cur); });
}
/* cb(modo, r): modo 'keep' (mismos números), 'asg' (tipo asignado) o 'man' (tipo manual r) */
function askCurChange(fromLabel, to, asg, cb, canManual) {
  const old = document.getElementById('alertback'); if (old) old.remove();
  const bk = document.createElement('div'); bk.id = 'alertback'; bk.className = 'alertback';
  const close = () => { bk.classList.remove('in'); setTimeout(() => bk.remove(), 220); };
  const box = document.createElement('div'); box.className = 'alertbox curbx'; box.setAttribute('role', 'alertdialog');
  const pick = (m, r) => { close(); setTimeout(() => cb(m, r), 60); };
  const head = (t, sub) => '<div class="curic">' + RMI('coins-line', 26, '#1A9D63') + '</div><h4>' + t + '</h4>' + (sub ? '<div class="cursub" data-notr>' + esc(fromLabel) + '<span>→</span>' + esc(to) + '</div>' : '');
  const opt = (col, ic, t, s, fn) => { const b = document.createElement('button'); b.type = 'button'; b.className = 'clopt curopt'; b.innerHTML = '<span class="clot" style="background:' + col + '">' + RMI(ic, 22, '#fff') + '</span><span><b>' + t + '</b>' + (s ? '<span class="s">' + s + '</span>' : '') + '</span>'; b.addEventListener('click', (ev) => { ev.stopPropagation(); fn(); }); return b; };
  const sec = (t, fn) => { const b = document.createElement('button'); b.type = 'button'; b.className = 'cursec'; b.textContent = t; b.addEventListener('click', (ev) => { ev.stopPropagation(); fn(); }); return b; };
  const home = () => {
    box.innerHTML = head('Cambiar de moneda', true) + '<p>¿Qué hacemos con los montos?</p>';
    box.appendChild(opt('#8E8E93', 'check-line', 'Mantener los montos', '', () => pick('keep')));
    box.appendChild(opt('#1A9D63', 'arrow-left-right-line', 'Convertir al tipo asignado', asg ? '<span data-notr>1 ' + esc(fromLabel) + ' = ' + esc(String(asg)) + ' ' + esc(to) + '</span>' : '', () => pick('asg')));
    if (canManual) box.appendChild(opt('#B98AE6', 'pencil-line', 'Usar otro tipo de cambio', '', manual));
    box.appendChild(sec('Cancelar', close));
  };
  const manual = () => {
    box.innerHTML = head('Tipo de cambio', false) + '<div class="curfx" data-notr><span>1 ' + esc(fromLabel) + ' =</span><input id="curRate" inputmode="decimal" autocomplete="off" value="' + (asg || '') + '"><span>' + esc(to) + '</span></div>';
    const go = document.createElement('button'); go.type = 'button'; go.className = 'curgo'; go.textContent = 'Convertir';
    go.addEventListener('click', (ev) => { ev.stopPropagation(); const r = parseFloat(String(document.getElementById('curRate').value).replace(',', '.')); if (!(r > 0)) { toast('Escribe un tipo de cambio válido'); return; } pick('man', r); });
    box.appendChild(go); box.appendChild(sec('Volver', home));
  };
  home();
  bk.appendChild(box); bk.addEventListener('click', (ev) => { if (ev.target === bk) close(); });
  deviceEl.appendChild(bk); requestAnimationFrame(() => bk.classList.add('in'));
}
function betaInfo() {
  const old = document.getElementById('alertback'); if (old) old.remove();
  const bk = document.createElement('div'); bk.id = 'alertback'; bk.className = 'alertback';
  const close = () => { bk.classList.remove('in'); setTimeout(() => bk.remove(), 220); };
  const box = document.createElement('div'); box.className = 'alertbox'; box.setAttribute('role', 'alertdialog');
  box.innerHTML = '<h4>Versión beta</h4><p>Plata está en pruebas. Ten en cuenta:</p><ul>' +
    '<li>Pueden aparecer errores o cambios de una versión a otra.</li>' +
    '<li>Tus datos viven solo en este dispositivo: guarda tu archivo con frecuencia.</li>' +
    '<li>No se conecta a tu banco; todo se registra a mano.</li>' +
    '<li>Aún no se ha probado en todos los dispositivos.</li></ul>';
  const bt = document.createElement('button'); bt.type = 'button'; bt.textContent = 'Entendido';
  bt.addEventListener('click', (ev) => { ev.stopPropagation(); close(); }); box.appendChild(bt);
  bk.appendChild(box); bk.addEventListener('click', (ev) => { if (ev.target === bk) close(); });
  deviceEl.appendChild(bk); requestAnimationFrame(() => bk.classList.add('in'));
}
const askDelete = (what, fn) => askConfirm('¿Eliminar ' + what + '?', 'Esta acción no se puede deshacer.', [{ label: 'Eliminar', dest: true, fn: fn }]);
function itemDelete() {
  if (!ui.itemDel) { askDelete('este elemento', () => { ui.itemDel = true; itemDelete(); }); return; }
  const k = ui.itemKind, id = ui.itemId;
  if (k === 'budget') { data.cats = data.cats.filter((x) => x.name !== id); allBuds().forEach((b) => { delete b[id]; }); }
  else if (k === 'job') { data.jobs = data.jobs.filter((x) => x.id !== id); syncJobs(); }
  else { const coll = k === 'income' ? 'expected_income' : k === 'expense' ? 'expected_expense' : 'subs'; data[coll] = data[coll].filter((x) => x.id !== id); }
  ui.dirty++; persist(); ui.itemId = null; renderAll(); itemBackNav(); toast('Eliminado');
}
function txRevert(t) { applyTo(accOf(t.acc), -t.amount); }
function txEditHTML(t) {
  const acc = accOf(t.acc), pay = isPay(t);
  ui.sheetType = pay ? 'pay' : t.amount > 0 ? 'in' : 'out'; ui.sheetCat = pay ? '' : (CAT_ORDER.indexOf(t.category) >= 0 ? t.category : 'Otros'); ui.sheetAcc = acc.id; ui.txEditId = t.id;
  return sheetHead('Editar movimiento', 'close', 'txsave') +
    '<div class="amtblock"><div class="amtlabel">Monto</div><div class="amount"><span id="fSym">' + symOf(acc.cur).trim() + '</span><input id="fAmount" inputmode="decimal" autocomplete="off" value="' + Math.abs(t.amount) + '" style="width:' + amtW(Math.abs(t.amount)) + '"></div></div>' +
    (pay || t.job ? '' : segHTML('type', [{ k: 'out', label: 'Gasto', act: 'type:out' }, { k: 'in', label: 'Ingreso', act: 'type:in' }], ui.sheetType, ';margin-bottom:4px') + '<div class="thint" id="thint">' + typeHint() + '</div><div id="catWrap">' + catsHTML() + '</div>') +
    '<div class="scard">' +
    (t.job && t.hrs > 0 ? '<label class="srow">' + fico(['#FF9F0A', '#']) + '<span class="grow"><span class="slabel">Horas trabajadas</span><input class="sinput" id="fHrs" inputmode="decimal" autocomplete="off" data-rate="' + t.rate + '" value="' + t.hrs + '"></span></label><div class="srow">' + fico(['#FF6B5E', '%']) + '<span class="grow"><span class="slabel">Impuestos descontados (calculado)</span><div id="taxOut" style="font-size:17px">' + taxPct(Math.abs(t.amount), t.rate, t.hrs) + '%</div></span></div>' : '') +
    '<label class="srow">' + fico(['#22B573', 'card']) + '<span class="grow"><span class="slabel">Cuenta</span><select class="sinput" id="fAcc">' + (pay && isCredit(acc) ? byUse(data.cards).map((a) => '<option value="' + a.id + '"' + (a.id === acc.id ? ' selected' : '') + '>' + esc(accLabel(a)) + '</option>').join('') : acctOpts(acc.id, !pay && !t.job && (ui.sheetType !== 'in' || isCredit(acc)))) + '</select></span></label>' +
    '<label class="srow">' + fico(['#22B573', 'pen']) + '<span class="grow"><span class="slabel">Nota</span><input class="sinput" id="fNote" autocomplete="off" value="' + esc(t.note || '') + '"></span></label>' +
    '<label class="srow">' + fico(['#FF9F0A', 'cal']) + '<span class="grow"><span class="slabel">Fecha</span><input class="sinput" id="fDate" type="date" max="' + iso(getToday()) + '" value="' + esc(t.date) + '"></span></label></div>' +
    '<button class="primary" data-act="txsave">Guardar</button>';
}
function txSave() {
  const t = txById(ui.txEditId); if (!t) return closeSheet();
  const v = readSheet(), amt = parseFloat(String(v.amount).replace(',', '.'));
  if (!(amt > 0)) { toast('Escribe un monto'); return; }
  const pay = isPay(t), old = { amount: t.amount, acc: t.acc }, d = v.date || t.date;
  if (d > iso(getToday())) { toast(futureMsg); return; }
  if (!pay && ui.sheetType === 'in' && v.acc !== old.acc && isCredit(accOf(v.acc))) { toast('Un ingreso no va en una tarjeta. Para pagarla usa Pago.'); return; }
  txRevert(t);
  const out = pay ? t.amount < 0 : ui.sheetType === 'out';
  t.amount = pay ? (old.amount < 0 ? -amt : amt) : (out ? -amt : amt);
  if (t.job && $('#fHrs')) { const hh = parseFloat(String($('#fHrs').value).replace(',', '.')); if (hh > 0) t.hrs = hh; }
  t.acc = v.acc || t.acc; t.date = d; t.note = v.note.trim() || t.note;
  if (!pay) { t.category = out ? ui.sheetCat : 'Ingreso'; if (out) delete t.est; }
  applyTo(accOf(t.acc), t.amount);
  const pr = t.pair ? data.transactions.find((x) => x.pair === t.pair && x !== t) : null;
  if (pr) { txRevert(pr); const c1 = accOf(t.acc), c2 = accOf(pr.acc); pr.amount = (pr.amount < 0 ? -1 : 1) * round2(fromUSD(usd(amt, c1.cur), c2.cur)); pr.date = d; applyTo(c2, pr.amount); }
  ui.dirty++; persist(); closeSheet(); renderAll(); toast('Movimiento actualizado');
}
function postponeHTML(t) {
  const out = t.amount < 0, cur = accOf(t.acc).cur, tm = iso(addDays(getToday(), 1));
  return sheetHead('Posponer', 'close') +
    '<div class="amtblock"><div class="amtlabel">' + esc(t.note || t.category) + '</div><div class="amount" style="justify-content:center"><span>' + fmtSC2(t.amount, cur) + '</span></div></div>' +
    '<div class="chips" style="margin-bottom:10px"><button class="chip" data-act="txpp:1">Mañana</button><button class="chip" data-act="txpp:7">En 1 semana</button><button class="chip" data-act="txpp:30">En 1 mes</button></div>' +
    '<div class="scard"><label class="srow">' + fico(['#FF9F0A', 'cal']) + '<span class="grow"><span class="slabel">Nueva fecha</span><input class="sinput" id="fDate" type="date" min="' + tm + '" value="' + tm + '"></span></label></div>' +
    '<div class="sub" style="font-size:13px;text-align:center;padding:0 8px 8px">Se quita de tus movimientos y pasa a ' + (out ? 'gastos previstos' : 'ingresos previstos') + ' en esa fecha. El saldo de la cuenta se corrige.</div>' +
    '<button class="primary" data-act="txpdo">Posponer</button>';
}
function txPostpone() {
  const t = txById(ui.txEditId); if (!t) return closeSheet();
  const d = ($('#fDate') || {}).value || '', today = iso(getToday());
  if (!d || d <= today) { toast('Elige una fecha futura'); return; }
  const out = t.amount < 0, name = t.note || t.category, amt = Math.abs(t.amount);
  txRevert(t); data.transactions = data.transactions.filter((x) => x !== t);
  if (out) data.expected_expense.push({ id: uid(), name: name, amount: amt, acc: t.acc, date: d, repeat: 0, cat: CAT_ORDER.indexOf(t.category) >= 0 ? t.category : 'Otros' });
  else data.expected_income.push({ id: uid(), name: name, amount: amt, acc: t.acc, date: d, repeat: 0 });
  ui.dirty++; persist(); closeSheet(); ui.txId = null; renderAll(); txBackNav(); toast('Pospuesto al ' + dlabel(pd(d)));
}
function txDelete() {
  const t = txById(ui.txId); if (!t) return;
  if (!ui.txDel) { askDelete('este movimiento', () => { ui.txDel = true; txDelete(); }); return; }
  const pr = t.pair ? data.transactions.find((x) => x.pair === t.pair && x !== t) : null;
  [t, pr].forEach((x) => { if (x) txRevert(x); });
  data.transactions = data.transactions.filter((x) => x !== t && x !== pr);
  ui.dirty++; persist(); ui.txId = null; renderAll(); txBackNav(); toast('Movimiento eliminado');
}

/* Interés ganado: un abono cuya descripción dice interés / interest. Sin campo nuevo en el movimiento, así que sirve con lo ya importado. */
const isIntTx = (t) => t.amount > 0 && /\binterest\b|\binter[eé]s(es)?\b|\brendimientos?\b/i.test(String(t.note || ''));
/* Intereses de una cuenta: lo cobrado este año y, si hay datos, el rendimiento real de los últimos 12 meses sobre el saldo. */
function intStats(a, cur, st) {
  const ys = String(getToday().getFullYear()), all = data.transactions.filter((t) => (t.acc || data.accounts[0].id) === a.id && isIntTx(t));
  if (!all.length && a.type !== 'savings') return '';
  const yr = round2(sum(all.filter((t) => String(t.date).slice(0, 4) === ys), (t) => t.amount));
  const from = new Date(getToday()); from.setFullYear(from.getFullYear() - 1); const f = iso(from);
  const l12 = all.filter((t) => t.date >= f), v12 = round2(sum(l12, (t) => t.amount));
  const real = a.balance > 0 && l12.length >= 3 ? Math.round((v12 / a.balance) * 1000) / 10 : null;   /* con menos de 3 abonos no se estima: sería adivinar */
  return '<div class="stats" style="margin-top:14px;gap:20px">' + st('Intereses del año', all.length ? '+' + fmtC2(yr, cur) : '—', all.length ? 'var(--gt)' : '') + st('Rendimiento real', real != null ? '≈ ' + real + '%' : '—') + '</div>';
}
function openAcct(id) { ui.itemId = null; ui.itemKind = null; ui.txId = null; ui.acctId = id; ui.prevTab = ui.tab === 'cuenta' ? ui.prevTab : ui.tab; renderCuenta(); setTab('cuenta'); }
function navBarSync() { document.documentElement.toggleAttribute('data-cdet', ui.txId != null || ui.itemId != null); }
function renderCuenta() { renderCuenta0(); navBarSync(); }
function renderCuenta0() {
  const el = $('#s-cuenta'); if (!el) return;
  if (ui.txId != null) { if (renderTx(el)) return; }
  if (ui.itemId != null) { if (renderItem(el)) return; }
  const a = data.accounts.find((x) => x.id === ui.acctId), k = a ? null : data.cards.find((x) => x.id === ui.acctId), sv = (a || k) ? null : data.savings.find((x) => x.id === ui.acctId);
  const o = a || k || sv;
  if (!o) { el.innerHTML = ''; if (ui.tab === 'cuenta') setTab(ui.prevTab && ui.prevTab !== 'cuenta' ? ui.prevTab : 'deuda'); return; }
  const c = calc(), i = (a ? data.accounts : k ? data.cards : data.savings).indexOf(o), cur = o.cur;
  const mine = c.monthTx.filter((t) => (t.acc || data.accounts[0].id) === o.id);
  const inn = sum(mine.filter((t) => t.amount > 0), (t) => t.amount), out = -sum(mine.filter((t) => t.amount < 0), (t) => t.amount);
  const st = (l, v, col) => '<div><span class="sub">' + l + '</span><b' + (col ? ' style="color:' + col + '"' : '') + '>' + v + '</b></div>';
  let hero, info, tail = '';
  if (sv) {
    const g = svGoal(sv, c.today);
    hero = { sub: 'Meta de ahorro · ' + cur, lbl: 'Ahorrado', val: fmtC2(sv.balance, cur) };
    info = '<div class="card">' + (sv.goal > 0 ? '<div class="bar" style="height:8px;border-radius:4px;margin:0 0 8px"><i style="height:8px;border-radius:4px;width:' + g.pct + '%;background:' + sv.color + '"></i></div><div class="sub">' + Math.round(g.pct) + '% de ' + fmtC2(sv.goal, cur) + '</div>' : '<div class="sub">Esta meta no tiene monto objetivo.</div>') + '</div>' +
      '<div class="card"><div class="stats" style="border:0;margin:0;padding:0;gap:20px">' + st('Falta', sv.goal > 0 ? fmtC2(g.rem, cur) : '—') + st('Aporte mensual', sv.monthly > 0 ? fmtC2(sv.monthly, cur) : '—') + '</div>' +
      '<div class="stats" style="margin-top:14px;gap:20px">' + st('Se llena en', g.done ? '¡Cumplida!' : g.mo ? plural(g.mo, 'mes', 'meses') : '—') + st('Fecha estimada', g.done ? '—' : g.mo ? monthYear(addMonths(c.today, g.mo)) : '—', g.done ? '' : 'var(--gt)') + '</div></div>' +
      secHead('Cuándo se llena') + '<div class="card">' + svChart(sv, g, c.today) + '</div>';
    const lg = (sv.log || []).slice().sort((x, y) => (x.date < y.date ? 1 : x.date > y.date ? -1 : 0)).slice(0, 8);
    tail = secHead('Últimos movimientos') + '<div class="card lst">' + (lg.length ? lg.map((e) => { const fa = e.from ? (data.accounts.find((x) => x.id === e.from) || null) : null; return '<div class="row"><span class="tile" style="background:' + (sv.color || '#22B573') + '" aria-hidden="true">+</span><div class="grow"><div class="name" style="font-size:16px">Aporte</div><div class="sub" style="font-size:13px">' + dshort(pd(e.date)) + (fa ? ' · ' + esc(fa.name) : '') + '</div></div><span class="amt" style="color:var(--gt)">+' + fmtC2(e.amount, cur) + '</span></div>'; }).join('') : '<div class="empty">Aún no hay aportes</div>') +
      '<button class="linkrow" data-act="contribto:' + sv.id + '" style="border-top:1px solid var(--line);width:100%">' + ICON.sliders + 'Aportar a esta meta</button></div>';
  } else if (a) {
    hero = { sub: accType[a.type] + ' · ' + a.cur + l4tag(a), lbl: 'Saldo', val: fmtC2(a.balance, cur) };
    info = '<div class="card"><div class="stats" style="border:0;margin:0;padding:0;gap:20px">' + st('Entró este mes', '+' + fmtC2(inn, cur), 'var(--gt)') + st('Salió este mes', fmtC2(out, cur)) + '</div>' +
      '<div class="stats" style="margin-top:14px;gap:20px">' + st('Rendimiento anual', a.apy > 0 ? a.apy + '%' : '—') + st('Ganancia al mes', a.apy > 0 ? '≈ ' + fmtC2((a.balance * a.apy) / 1200, cur) : '—') + '</div>' + intStats(a, cur, st) + '</div>';
  } else {
    const loan = k.kind === 'loan', util = k.limit > 0 ? Math.min(100, Math.round((k.balance / k.limit) * 100)) : 0, col = o.color || CARD_COLORS[i % CARD_COLORS.length];
    hero = { sub: (loan ? 'Préstamo' : 'Tarjeta de crédito') + ' · ' + cur + l4tag(k), lbl: 'Saldo adeudado', val: fmtC2(k.balance, cur) };
    info = (!loan && k.limit > 0 ? '<div class="card"><div class="bar" style="height:8px;border-radius:4px;margin:0 0 8px"><i style="height:8px;border-radius:4px;width:' + util + '%;background:' + col + '"></i></div>' +
        '<div class="sub">' + util + '% usado · disponible ' + fmtC2(Math.max(0, k.limit - k.balance), cur) + ' de ' + fmtC2(k.limit, cur) + '</div></div>' : '') +
      '<div class="card"><div class="stats" style="border:0;margin:0;padding:0;gap:20px">' + st('Interés anual', k.apr + '%') + st('Interés al mes', '≈ ' + fmtC2((k.balance * k.apr) / 1200, cur), 'var(--ot)') + '</div>' +
      '<div class="stats" style="margin-top:14px;gap:20px">' + st('Pago mensual', k.payment > 0 ? fmtC2(k.payment, cur) : '—') + st('Día de pago', k.due_day ? 'Día ' + k.due_day : '—') + '</div>' +
      '<div class="stats" style="margin-top:14px;gap:20px">' + st('Gastado este mes', fmtC2(out, cur)) + '</div>' + apCardRow(k) + '</div>';
  }
  el.innerHTML =
    '<div class="navrow"><button class="back" data-act="acctback" aria-label="Regresar">' + IC_BACK + '</button>' +
    '<div style="display:flex;gap:10px">' + (sv ? '' : '<button class="editbtn" data-act="achide" aria-label="' + (o.hid ? 'Mostrar en el resumen' : 'Ocultar del resumen') + '">' + RMI(o.hid ? 'eye-off-line' : 'eye-line', 22, '#1C1C1E') + '</button>') +
    '<button class="editbtn" data-act="acctedit" aria-label="Editar">' + IC_PEN + '</button></div></div>' +
    '<div class="acctop"><div class="ptile">' + tileFor(o, i, a ? 'acc' : sv ? 'sav' : 'debt') + '</div><h1 style="font-size:28px;margin:10px 0 2px">' + esc(o.name) + '</h1><div class="sub">' + hero.sub + '</div>' +
    '<div class="sub" style="margin-top:14px">' + hero.lbl + '</div><div class="big" style="font-size:40px">' + hero.val + '</div></div>' +
    info +
    (sv ? tail : secHead('Movimientos') + '<div class=\"card lst\">' + movRows(60, o.id) +
      '<button class="linkrow" data-act="addto:' + o.id + '" style="border-top:1px solid var(--line);width:100%">' + IC_ADD + 'Añadir movimiento</button></div>');
}
function apCardRow(k) {
  const on = !!k.auto && apOK(k), ok = apOK(k);
  const sub = on ? 'El día ' + k.due_day + ' de cada mes te preguntamos cuánto pagaste.' : ok ? 'Te recordamos el día ' + k.due_day + ' para que registres tu pago.' : 'Añade el día de pago de la tarjeta para activarlo.';
  return '<div class="row" style="border-top:1px solid var(--line);margin-top:14px;padding:14px 0 0"><span class="grow"><span style="font-size:17px;display:block">Pago esperado</span><span class="sub" style="font-size:13px">' + sub + '</span></span>' + swHTML(on, 'apcard:' + k.id, !on && !ok) + '</div>';
}
function updatePendingDot() { const t = document.querySelector('.tab[data-act="tab:resumen"]'); if (t) t.classList.toggle('hasdot', pendingItems().length > 0); }
function renderAll() { if (resolveLang() !== LANG) applyLang(); updatePendingDot(); syncCats(); renderResumen(); renderPresupuesto(); renderProyeccion(); renderDeuda(); renderAhorro(); renderMovimientos(); renderCuenta(); refreshProf(); }

