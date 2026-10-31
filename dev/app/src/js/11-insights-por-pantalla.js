/* ---------- Insights por pantalla: presupuesto, ahorro, deuda ---------- */
const insLine = (txt, kind) => txt ? '<div style="font-size:12px;line-height:1.3;margin-top:4px;font-weight:500;color:' + ({ warn: '#B96A00', bad: 'var(--rt)', ok: 'var(--gt)' }[kind] || '#6C6C70') + '">' + txt + '</div>' : '';
function budgetInsight(k, sp, lim) {
  if (!insOn()) return '';
  if (!(lim > 0)) return '';
  const c = calc(), d = c.today.getDate(), dim = c.dim, pct = sp / lim;
  if (sp - lim >= 0.5) return insLine('Superaste el límite por ' + bfmt(sp - lim) + '.', 'bad');
  if (k === 'Alquiler' || sp > lim) return '';
  if (pct >= 0.8 && d < dim) return insLine('Vas rápido: llevas el ' + Math.round(pct * 100) + '% y va el día ' + d + ' de ' + dim + '.', 'warn');
  const proj = d > 0 ? sp / d * dim : 0;
  if (pct >= 0.4 && d >= 5 && proj > lim * 1.1) return insLine('A este ritmo cerrarías pasándote por unos ' + bfmt(proj - lim) + '.', 'warn');
  return '';
}
function savingInsight(sv) {
  if (!insOn()) return '';
  if (!(sv.goal > 0) || sv.balance >= sv.goal) return '';
  const T = getToday(), mk = iso(T).slice(0, 7), raw = (data.savings.find((x) => x.id === sv.id) || {}).log || [];
  const thisM = raw.filter((l) => l.date && l.date.slice(0, 7) === mk).reduce((t, l) => t + (l.amount || 0), 0);
  const cutoff = iso(addDays(T, -90)), recent = raw.filter((l) => l.date && l.date >= cutoff), last90 = recent.reduce((t, l) => t + (l.amount || 0), 0), first = recent.reduce((m, l) => (l.date < m ? l.date : m), iso(T)), span = Math.max(1, Math.min(3, Math.ceil((T - pd(first)) / 2592000000))), real = last90 / span;
  const rem = sv.goal - sv.balance;
  if (!(sv.monthly > 0) && !(real > 0)) return insLine('Define un aporte mensual para ver cuándo llegas a tu meta.', 'warn');
  if (thisM <= 0 && T.getDate() >= 10) return insLine('Aún no has aportado este mes' + (sv.monthly > 0 ? ' (planeabas ' + fmtC(sv.monthly, sv.cur) + ')' : '') + '.', 'warn');
  if (sv.monthly > 0 && real > 0 && real < sv.monthly * 0.8) { const mo = Math.ceil(rem / real); return insLine('Tu ritmo real es de ~' + fmtC(real, sv.cur) + '/mes: la meta llegaría en ' + monthYear(addMonths(T, mo)) + '.', 'warn'); }
  if (thisM > 0) return insLine('Vas al día: ya aportaste ' + fmtC(thisM, sv.cur) + ' este mes.', 'ok');
  return '';
}
function debtSim(bal, apr, pay) {
  const r = apr / 1200; let b = bal, n = 0, tot = 0;
  if (!(pay > 0) || pay <= b * r) return null;
  while (b > 0.005 && n < 600) { const i = b * r; tot += i; b = b + i - pay; n++; }
  return { months: n, interest: tot };
}
function debtInsight(k) {
  if (!insOn()) return '';
  let out = '';
  if (k.kind === 'card' && k.limit > 0 && k.util > 30) out += insLine('Usas el ' + k.util + '% de tu límite: mantenerlo bajo 30% ayuda a tu historial crediticio.', 'warn');
  if (k.balance > 0 && k.apr > 0 && k.payment > 0 && k.cur === curP()) {
    const xtra = 50 * curK(), a = debtSim(k.balance, k.apr, k.payment), b = debtSim(k.balance, k.apr, k.payment + xtra);
    if (!a) out += insLine('Tu pago mensual no alcanza a cubrir los intereses.', 'bad');
    else if (b && a.interest - b.interest >= 10) out += insLine('Pagando ' + fmt(xtra) + ' más al mes terminas ' + plural(a.months - b.months, 'mes', 'meses') + ' antes y ahorras ~' + fmt(a.interest - b.interest) + ' en intereses.', 'ok');
  }
  return out;
}
/* Aros concéntricos de Presupuesto: los mismos del Apple Watch y de la app de iPhone (hasta 4 categorías con tope, las de más gasto),
   cada uno con el icono de su categoría en la punta y su nombre curvado en un tono oscuro del mismo color; el «Quedan …» va en el hueco. */
function budgetRingsSVG(cats, left, bt, fmt) {
  const S = 280, C = S / 2, W = 19, G = 3, FS = 10.5, N = cats.length, DEG = 180 / Math.PI;
  const rgb = (h, k) => { const n = parseInt(String(h || '#22B573').replace('#', ''), 16) || 0; return 'rgb(' + [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((v) => Math.round(v * k)).join(',') + ')'; };
  const wt = (ch) => 'I·  1.,'.indexOf(ch) >= 0 ? 0.55 : 'MW%'.indexOf(ch) >= 0 ? 1.2 : 1;
  const step = (ch, r) => FS * 0.98 * wt(ch) / r * DEG;
  const span = (t, r) => t.toUpperCase().split('').reduce((a, ch) => a + step(ch, r), 0);
  const fit = (name, pct, avail, r) => {
    if (avail <= 0) return '';
    for (const whole of [pct, '']) { for (let n = name.length; n >= 3; n--) { const nm = n === name.length ? name : name.slice(0, n - 1) + '…'; if (span(nm + whole, r) <= avail) return nm + whole; } }
    return '';
  };
  let g = '';
  cats.forEach((c, i) => {
    const r = C - W / 2 - i * (W + G), circ = 2 * Math.PI * r, frac = c.limit > 0 ? c.spent / c.limit : 0, lap = Math.min(1, Math.max(0.004, frac)), col = c.color || '#22B573', dk = rgb(col, 0.3);
    g += '<circle cx="' + C + '" cy="' + C + '" r="' + r + '" fill="none" stroke="' + col + '" stroke-opacity=".25" stroke-width="' + W + '"/>';
    const SEG = 18, segLen = lap * circ / SEG;
    for (let q = 0; q < SEG; q++) g += '<circle cx="' + C + '" cy="' + C + '" r="' + r + '" fill="none" stroke="' + col + '" stroke-opacity="' + (0.65 + 0.35 * q / (SEG - 1)).toFixed(3) + '" stroke-width="' + W + '" stroke-dasharray="' + (segLen + 0.6).toFixed(2) + ' ' + (circ * 2) + '" stroke-dashoffset="' + (-q * segLen).toFixed(2) + '" transform="rotate(-90 ' + C + ' ' + C + ')"/>';
    const tipA = 360 * lap, px = (a) => (C + r * Math.sin(a / DEG)).toFixed(2), py = (a) => (C - r * Math.cos(a / DEG)).toFixed(2);
    g += '<circle cx="' + px(0) + '" cy="' + py(0) + '" r="' + (W / 2) + '" fill="' + col + '" fill-opacity=".65"/><circle cx="' + px(tipA) + '" cy="' + py(tipA) + '" r="' + (W / 2) + '" fill="' + col + '"/>';
    const isz = W * 0.62, ia = frac > 0.02 ? tipA : 0, cat = data.cats.find((x) => x.name === c.name), ic = cat && cat.icon && ICONS[cat.icon] ? RMI(ICONS[cat.icon], isz, dk) : '';
    if (ic) g += ic.replace('<svg ', '<svg x="' + (px(ia) - isz / 2).toFixed(2) + '" y="' + (py(ia) - isz / 2).toFixed(2) + '" ');
    else g += '<text x="' + px(ia) + '" y="' + (+py(ia) + 3.5) + '" text-anchor="middle" font-size="' + isz + '" font-weight="800" fill="' + dk + '">' + esc(trText(c.name)).charAt(0) + '</text>';
    const iconHalf = (isz / 2 + 1) / r * DEG, start = W * 0.35 / r * DEG + 3, end = (frac >= 1 ? 360 : 360 * Math.min(1, Math.max(0, frac))) - iconHalf - 3, begin = frac >= 1 ? Math.max(start, iconHalf + 3) : start;
    const label = fit(trText(c.name), ' · ' + Math.round(frac * 100) + '%', end - begin, r);
    if (label) { let a = begin; label.toUpperCase().split('').forEach((ch) => { const st = step(ch, r); if (ch !== ' ') g += '<text x="' + C + '" y="' + (C - r + FS * 0.36).toFixed(2) + '" text-anchor="middle" font-size="' + FS + '" font-weight="800" fill="' + dk + '" transform="rotate(' + (a + st / 2).toFixed(2) + ' ' + C + ' ' + C + ')">' + esc(ch) + '</text>'; a += st; }); }
  });
  const hole = (C - N * (W + G) + G) * 2, amt = fmt(Math.abs(left)), fs = Math.max(14, Math.min(24, (hole - 16) / (amt.length * 0.6)));
  g += '<text x="' + C + '" y="' + (C - 14) + '" text-anchor="middle" font-size="12" style="fill:var(--sec)">' + (left >= 0 ? 'Quedan' : 'Te pasaste') + '</text>' +
    '<text x="' + C + '" y="' + (C + 10) + '" text-anchor="middle" font-size="' + fs.toFixed(1) + '" font-weight="700" letter-spacing="-0.7" style="fill:' + (left >= 0 ? 'var(--ink)' : 'var(--rt)') + '">' + amt + '</text>' +
    '<text x="' + C + '" y="' + (C + 28) + '" text-anchor="middle" font-size="11" style="fill:var(--sec)">de ' + fmt(bt) + '</text>';
  return '<svg viewBox="0 0 ' + S + ' ' + S + '" style="width:100%;height:auto;font-family:Inter,-apple-system,BlinkMacSystemFont,system-ui,sans-serif" role="img" aria-label="Aros del presupuesto por categoría">' + g + '</svg>';
}
function renderPresupuesto() {
  const fmt = bfmt;
  const c = calc(), vs = viewSet(), vb = budOf(vs), bt = sum(CAT_ORDER, (k) => vb[k] || 0), act = activeSet(), prev = (vs || null) !== (act || null), left = bt - c.expV, dl = c.dim - c.today.getDate() + 1;
  const center = prev
    ? '<text x="120" y="112" text-anchor="middle" font-size="13" fill="#6C6C70" font-family="inherit">Límite del set</text><text x="120" y="144" text-anchor="middle" font-size="30" font-weight="700" letter-spacing="-0.9" fill="#1C1C1E" font-family="inherit">' + fmt(bt) + '</text>'
    : bt
    ? '<text x="120" y="112" text-anchor="middle" font-size="13" fill="#6C6C70" font-family="inherit">' + (left >= 0 ? 'Quedan' : 'Te pasaste') + '</text><text x="120" y="144" text-anchor="middle" font-size="30" font-weight="700" letter-spacing="-0.9" fill="' + (left >= 0 ? '#1C1C1E' : 'var(--rt)') + '" font-family="inherit">' + fmt(Math.abs(left)) + '</text><text x="120" y="166" text-anchor="middle" font-size="12" fill="#6C6C70" font-family="inherit">de ' + fmt(bt) + '</text>'
    : '<text x="120" y="112" text-anchor="middle" font-size="13" fill="#6C6C70" font-family="inherit">Gastado</text><text x="120" y="144" text-anchor="middle" font-size="30" font-weight="700" fill="#1C1C1E" font-family="inherit">' + fmt(c.expV) + '</text>';
  const rings = CAT_ORDER.filter((k) => (vb[k] || 0) > 0).map((k) => ({ name: k, spent: c.catTot[k] || 0, limit: vb[k], color: CAT_COLOR[k] })).sort((a, b) => b.spent - a.spent).slice(0, 4);
  const budgetRings = !prev && bt > 0 && rings.length > 0;   /* con presupuesto activo: los aros del Watch · si no, el anillo de siempre */
  const ring = budgetRings ? budgetRingsSVG(rings, left, bt, fmt) : ringSVG(prev ? [] : (c.cats.length ? c.cats : []), 100, 22, 4, 240, center);
  const rows = CAT_ORDER.map((k) => {
    const lim = vb[k] || 0, sp = c.catTot[k] || 0, pct = lim ? sp / lim : 0, over = lim && sp > lim;
    const col = over ? '#FF3B30' : pct > 0.85 ? '#FF9F0A' : CAT_COLOR[k];
    if (prev) return rowEdit('budget', k, tile(CAT_COLOR[k], catGlyph(k)), '<div class="name" style="font-size:16px">' + esc(k) + '</div><div class="sub" style="font-size:13px">' + (lim ? 'Límite ' + fmt(lim) : 'Sin límite') + '</div>', lim ? '' : '<span class="sub">Definir</span>');
    return rowEdit('budget', k, tile(CAT_COLOR[k], catGlyph(k)),
      '<div class="name" style="font-size:16px">' + esc(k) + '</div><div class="bar"><i style="width:' + Math.min(100, pct * 100) + '%;background:' + col + '"></i></div><div class="sub" style="font-size:13px">' + fmt(sp) + (lim ? ' de ' + fmt(lim) : ' · sin límite') + '</div>' + budgetInsight(k, sp, lim),
      lim ? '<span class="amt" style="color:' + (over ? 'var(--rt)' : '#1C1C1E') + '">' + fmt(lim - sp) + '</span>' : '<span class="sub">Definir</span>');
  }).join('');
  const subRows = data.subs.slice().sort((a, b) => a.day - b.day).map((s, i) => rowEdit('sub', s.id, subTile(s, i),
    '<div class="name" style="font-size:16px">' + esc(s.name) + '</div><div class="sub" style="font-size:13px">Día ' + s.day + ' de cada mes' + (s.cur !== curP() ? ' · ≈ ' + fmt2(usd(s.amount, s.cur)) : '') + '</div>',
    '<span class="amt">' + fmtC2(s.amount, s.cur) + '</span>')).join('');
  $('#s-presupuesto').innerHTML =
    '<div class="head"><div>' + (bt ? '<div class="eyebrow">' + (dl === 1 ? 'Queda 1 día del mes' : 'Quedan ' + dl + ' días del mes') + '</div>' : '') + '<h1>Presupuesto</h1></div></div>' +
    '<div class="card" style="padding:4px 16px"><div class="row tap" data-act="bsets" style="padding:10px 0"><div class="grow"><div class="sub" style="font-size:12px">Set de presupuesto</div><div class="name" style="font-size:17px">' + esc(vs ? vs.name : 'Presupuesto base') + (vs && vs === act ? ' <span class="badge" style="background:var(--gbg);color:var(--gt2);margin-left:4px">Activo</span>' : !vs && !act ? ' <span class="badge" style="background:var(--gbg);color:var(--gt2);margin-left:4px">Activo</span>' : '') + '</div>' +
      '<div class="sub" style="font-size:13px">' + (vs ? 'Del ' + dshort(pd(vs.from)) + ' al ' + dshort(pd(vs.to)) : 'Se usa cuando no hay otro set activo') + '</div></div>' + ICON.chev + '</div>' +
      (prev ? '<div class="sub" style="font-size:13px;padding:0 0 12px;color:var(--ot)">Estás viendo y editando este set, pero hoy está activo ' + (act ? '«' + esc(act.name) + '»' : 'el presupuesto base') + '.</div>' : '') + '</div>' +
    '<div class="card"><div style="max-width:' + (budgetRings ? 280 : 240) + 'px;margin:0 auto">' + ring + '</div>' +
      (!prev && bt && left > 0 ? '<div class="sub" style="text-align:center;padding-top:6px">Puedes gastar unos <b style="color:var(--ink)">' + fmt(left / dl) + '</b> al día</div>' : '') + '</div>' +
    secHead('Límites por categoría') + '<div class=\"card lst\">' + rows + addRow('budget', 'Añadir categoría') + '</div>' +
    secHead('Servicios y suscripciones') + '<div class="card"><div class="big" style="font-size:28px;margin:2px 0 4px">' + fmt2(c.subsTotal) + ' <span class="sub" style="font-weight:500;letter-spacing:0">al mes</span></div>' +
      '<div class="sub" style="padding-bottom:4px">' + fmt2(c.subsTotal * 12) + ' al año</div>' + subRows + addRow('sub', 'Añadir servicio o suscripción') + '</div>';
}

function bsetsHTML() {
  const act = activeSet(), vs = viewSet();
  const row = (id, nm, sub, isAct, isView) => '<div class="row tap" data-act="bsview:' + id + '"><div class="grow"><div class="name" style="font-size:16px">' + esc(nm) + (isAct ? ' <span class="badge" style="background:var(--gbg);color:var(--gt2);margin-left:4px">Activo</span>' : '') + '</div><div class="sub" style="font-size:13px">' + sub + '</div></div>' +
    (id !== 'base' ? '<button class="calnav" data-act="bsedit:' + id + '" aria-label="Editar" style="width:34px;height:34px;margin-right:6px;padding:0;display:flex;align-items:center;justify-content:center">' + RMI('pencil-line', 16, '#22B573') + '</button>' : '') + '<span style="flex:none;width:20px;text-align:center;color:#22B573;font-weight:700">' + (isView ? '✓' : '') + '</span></div>';
  const rows = row('base', 'Presupuesto base', 'Se usa cuando no hay otro set activo', !act, !vs) +
    bsets().slice().sort((a, b) => (a.from < b.from ? -1 : 1)).map((b) => row(b.id, b.name, 'Del ' + dshort(pd(b.from)) + ' al ' + dshort(pd(b.to)) + ' ' + pd(b.to).getFullYear() + (b.cur && b.cur === curS() ? ' · ' + b.cur : ''), act === b, vs === b)).join('');
  return sheetHead('Sets de presupuesto', null, null) + '<div class="sub" style="font-size:13px;padding:0 8px 10px">Cada set tiene sus propios límites y se activa solo entre sus fechas. Toca uno para verlo y editar sus límites.</div><div class="card lst" style="margin:0 0 12px">' + rows + '</div><button class="primary" data-act="bsnew">Nuevo set</button>';
}
function bseditHTML() {
  const v = ui.bs;
  return sheetHead(v.isNew ? 'Nuevo set' : 'Editar set', 'bsback', 'bssave') +
    '<div class="scard"><label class="srow">' + fico(['#22B573', 'pen']) + '<span class="grow"><span class="slabel">Nombre</span><input class="sinput" id="bsName" autocomplete="off" placeholder="Ej. Mes de rodaje" value="' + esc(v.name) + '"></span></label>' +
    '<label class="srow">' + fico(['#22B573', 'cal']) + '<span class="grow"><span class="slabel">Inicio</span><input class="sinput" type="date" id="bsFrom" value="' + esc(v.from) + '"></span></label>' +
    '<label class="srow">' + fico(['#FF9F0A', 'cal']) + '<span class="grow"><span class="slabel">Fin</span><input class="sinput" type="date" id="bsTo" value="' + esc(v.to) + '"></span></label></div>' +
    (curS() ? '<div class="scard"><label class="srow"><span class="grow"><span class="slabel">Moneda del set</span><select class="mini" id="bsCur" style="width:100%;text-align:left;padding:0 12px"><option value="">' + curP() + '</option><option value="' + curS() + '"' + (v.cur === curS() ? ' selected' : '') + '>' + curS() + '</option></select></span></label></div>' : '') +
    (v.isNew ? '<div class="sub" style="font-size:13px;padding:0 8px 6px">Empieza con una copia de los límites de «' + esc(v.srcName) + '». Luego los ajustas en Presupuesto.</div>' : '') +
    '<button class="primary" data-act="bssave">Guardar</button>' + (v.isNew ? '' : '<button class="delbtn" data-act="bsdel">Eliminar set</button>');
}
function bsEdit(id) {
  const t = getToday();
  if (id) { const b = bsets().find((x) => x.id === id); if (!b) return; ui.bs = { id: id, isNew: false, name: b.name, from: b.from, to: b.to, cur: b.cur || '' }; }
  else { const vs = viewSet(); ui.bs = { id: uid(), isNew: true, cur: '', name: '', from: iso(t), to: iso(addDays(t, 30)), srcName: vs ? vs.name : 'Presupuesto base', src: vs ? vs.id : 'base' }; }
  showSheet(bseditHTML());
}
function bsSave() {
  const v = ui.bs; if (!v) return;
  const nm = String(($('#bsName') || {}).value || '').replace(/[<>]/g, '').trim().slice(0, 40), from = ($('#bsFrom') || {}).value, to = ($('#bsTo') || {}).value, bc = ($('#bsCur') || {}).value || '';
  if (!nm) { toast('Escribe un nombre'); return; }
  if (!from || !to) { toast('Elige inicio y fin'); return; }
  if (to < from) { toast('El fin debe ser posterior al inicio'); return; }
  const clash = bsets().find((x) => x.id !== v.id && x.from <= to && x.to >= from); if (clash) { toast('Esas fechas se cruzan con «' + clash.name + '». Cámbialas.'); return; }
  if (v.isNew) { const src = v.src === 'base' ? data.budget : (bsets().find((x) => x.id === v.src) || {}).budget || data.budget; bsets().push({ id: v.id, name: nm, from: from, to: to, budget: clone(src), cur: bc }); ui.bsel = v.id; }
  else { const b = bsets().find((x) => x.id === v.id); if (b) { b.name = nm; b.from = from; b.to = to; b.cur = bc; } }
  ui.bs = null; ui.dirty++; persist(); closeSheet(); renderAll(); toast('Set guardado');
}
function secHead(t, extra) { return '<div class="sechead"><h2>' + t + '</h2>' + (extra || '') + '</div>'; }
function renderDeuda() {
  const c = calc();
  /* las cuentas ocultas no aparecen en esta pestaña ni cuentan en sus totales */
  c.cards = c.cards.filter((k) => !k.hid); c.balance = sum(data.accounts.filter((x) => !x.hid), (x) => usd(x.balance, x.cur)); c.debt = sum(c.cards, (k) => k.ub);
  const rk = data.settings.ring_kind || 'all', fc = c.cards.filter((k) => rk === 'all' || k.kind === rk), fDebt = fc.reduce((t, k) => t + k.ub, 0), fInt = fc.reduce((t, k) => t + k.interest, 0);
  const items = fc.filter((k) => k.ub > 0).map((k) => ({ v: k.ub, color: k.color }));
  const center =
    '<text x="150" y="164" text-anchor="middle" font-size="46" font-weight="700" letter-spacing="-1.6" fill="#1C1C1E" font-family="inherit">' + fmt(fDebt) + '</text>' +
    '<text x="150" y="200" text-anchor="middle" font-size="22" font-weight="600" fill="var(--ot)" font-family="inherit">' + fmt2(fInt) + '</text>' +
    '<text font-size="11" font-weight="500" letter-spacing="1.6" fill="#6C6C70" font-family="inherit"><textPath href="#dtop" startOffset="50%" text-anchor="middle">' + ({ all: 'DEUDA TOTAL', card: 'DEUDA EN TARJETAS', loan: 'DEUDA EN PRÉSTAMOS' })[rk] + ' · ' + fc.length + (fc.length === 1 ? ' CUENTA' : ' CUENTAS') + '</textPath></text>' +
    '<text font-size="11" font-weight="500" letter-spacing="1.6" fill="#6C6C70" font-family="inherit"><textPath href="#dbot" startOffset="50%" text-anchor="middle">INTERESES ESTIMADOS AL MES</textPath></text>';
  const defs = '<defs><path id="dtop" d="M 62,150 A 88,88 0 0 1 238,150"/><path id="dbot" d="M 46,150 A 104,104 0 0 0 254,150"/></defs>';
  const ring = items.length ? ringSVG(items, 126, 30, 6, 300, center, defs) : '';
  const detail = ui.interest
    ? '<div style="padding:4px 0 8px">' + fc.map((k) => '<div class="row" style="padding:8px 0"><span class="grow">' + esc(k.name) + ' <span class="sub">· ' + k.apr + '% anual</span></span><b>' + fmt2(k.interest) + '/mes</b></div>').join('') + '</div>'
    : '';
  const sm = (pf) => data.settings[pf + '_sort'] || 'name', sd = (pf) => data.settings[pf + '_dir'] === 'desc' ? -1 : 1, todayD = c.today.getDate(), dimN = c.dim;
  const byName = (x, y) => String(x.name).localeCompare(String(y.name), LANG);
  const dueIn = (k) => (k.payment > 0 || k.balance > 0) && k.due_day ? (((k.due_day - todayD) % dimN) + dimN) % dimN : 999;
  const sortAcc = (list0, kind) => { const list = list0.filter((o) => !o.hid); const sortMode = sm(kind === 'card' ? 'card' : 'acct'), sortDir = sd(kind === 'card' ? 'card' : 'acct'); const hide = !!data.settings[(kind === 'card' ? 'card' : 'acct') + '_hide']; return list.map((o, i) => ({ o: o, i: i })).filter((it) => !hide || (kind === 'card' ? it.o.balance > 0 : it.o.balance !== 0)).sort((A, B) => {
    const x = A.o, y = B.o;
    if (sortMode === 'amount') return sortDir * ((kind === 'card' ? x.ub - y.ub : usd(x.balance, x.cur) - usd(y.balance, y.cur)) || byName(x, y));
    if (sortMode === 'due') return kind === 'card' ? sortDir * ((dueIn(x) - dueIn(y)) || byName(x, y)) : sortDir * byName(x, y);
    return sortDir * byName(x, y);
  }); };
  const debitRows = sortAcc(data.accounts, 'acc').map((it) => { const a = it.o, i = it.i; return rowEdit('acct', a.id, tileFor(a, i, 'acc'),
    '<div class="name" style="font-size:16px">' + esc(a.name) + l4tag(a) + hidMark(a) + '</div><div class="sub" style="font-size:13px">' + accType[a.type] + ' · ' + a.cur + (a.apy > 0 ? ' · ' + a.apy + '% anual · ≈ ' + fmtC2((a.balance * a.apy) / 1200, a.cur) + '/mes' : '') + '</div>',
    '<span class="amt">' + fmtC(a.balance, a.cur) + '</span>'); }).join('');
  const creditRows = sortAcc(c.cards, 'card').map((it) => { const k = it.o, i = it.i; return rowEdit('acct', k.id, tileFor(k, i, 'debt'),
    '<div class="name">' + esc(k.name) + l4tag(k) + hidMark(k) + '</div>' + (k.kind === 'card' && k.limit > 0 ? '<div class="bar"><i style="width:' + Math.min(100, k.util) + '%;background:' + ((bankPick(k) || {}).fixed ? bankPick(k).bg : k.color) + '"></i></div>' : '') +
    '<div class="sub" style="font-size:13px">' + (k.kind === 'loan' ? 'Préstamo' : k.util + '% usado · disponible ' + fmtC(Math.max(0, k.limit - k.balance), k.cur)) + '</div>' +
    (function () { const parts = []; if (k.apr > 0) { parts.push(k.apr + '% anual'); if (k.balance > 0) parts.push('≈ ' + fmtC2((k.balance * k.apr) / 1200, k.cur) + '/mes'); } if (k.due_day > 0) parts.push('pago día ' + k.due_day); return parts.length ? '<div class="sub" style="font-size:13px">' + parts.join(' · ') + '</div>' : ''; })() + debtInsight(k),
    '<span class="amt">' + fmtC(k.balance, k.cur) + '</span>'); }).join('');
  const sortBtn = (pf) => { const sortOn = sm(pf) !== 'name' || sd(pf) < 0 || !!data.settings[pf + '_hide']; return '<button class="sortbtn' + (sortOn ? ' on' : '') + '" data-act="sortmenu:' + pf + '" aria-label="Ordenar">' + RMI('filter-3-line', 18, sortOn ? '#fff' : '#6C6C70') + '</button>'; };
  const hiddenNote = (pf, list) => { if (!data.settings[pf + '_hide']) return ''; const n = list.filter((o) => (pf === 'card' ? !(o.balance > 0) : o.balance === 0)).length; return n ? '<div class="sub" style="padding:8px 0 2px;text-align:center;font-size:13px">' + n + (n === 1 ? ' oculta' : ' ocultas') + ' por no estar en uso</div>' : ''; };
  const base = payoff(0, rk), net = c.balance - c.debt;
  const lim = c.cards.filter((k) => k.kind === 'card' && k.limit > 0), creditLimit = lim.reduce((t, k) => t + usd(k.limit, k.cur), 0), creditAvail = lim.reduce((t, k) => t + Math.max(0, usd(k.limit - k.balance, k.cur)), 0);
  $('#s-deuda').innerHTML =
    '<div class="head"><div><h1>Cuentas</h1></div></div>' +
    '<div class="card"><div class="stats" style="border:0;margin:0;padding:0;gap:20px"><div><span class="sub">Disponible (débito)</span><b>' + fmt(c.balance) + '</b></div><div><span class="sub">Deuda (crédito)</span><b style="color:' + (c.debt > 0 ? 'var(--ot)' : '#1C1C1E') + '">' + fmt(c.debt) + '</b></div></div>' +
      '<div class="stats" style="border:0;margin:14px 0 0;padding:14px 0 0;border-top:1px solid var(--line);gap:20px"><div><span class="sub">Crédito disponible</span><b style="color:var(--gt)">' + fmt(creditAvail) + '</b></div><div><span class="sub">Límite total</span><b>' + fmt(creditLimit) + '</b></div></div>' +
      '<div class="sub" style="padding-top:8px">' + (creditLimit > 0 ? 'Usas ' + Math.round(((creditLimit - creditAvail) / creditLimit) * 100) + '% de tu crédito · ' : '') + 'Neto: <b style="color:' + (net < 0 ? 'var(--rt)' : '#1C1C1E') + '">' + fmt(net) + '</b></div></div>' +
    '<div class="sub" style="padding:0 8px 16px;font-size:13px">Los movimientos entran a la cuenta que elijas al añadirlos.</div>' +
    secHead('Trabajo') + '<div class="card lst">' + data.jobs.map((j) => rowEdit('job', j.id, tile(j.sim ? '#FF9F0A' : '#22B573', esc(j.name).charAt(0) || 'T'), '<div class="name" style="font-size:16px">' + esc(j.name) + '</div><div class="sub" style="font-size:13px">' + (j.mode === 's' ? 'Ingreso mensual' : 'Pago por hora') + '</div>', '<span class="amt" style="color:var(--gt);font-weight:600">+' + fmtC(jobNet(j), accOf(j.acc).cur) + '</span>')).join('') + addRow('job', data.jobs.length ? 'Añadir otro trabajo' : 'Añadir trabajo') + '</div>' +
    secHead('Cuentas de débito', sortBtn('acct')) + '<div class=\"card lst\">' + debitRows + hiddenNote('acct', data.accounts) + addRow('account', 'Añadir cuenta de débito') + '</div>' +
    (c.cards.length ? '<div class="card" style="position:relative"><button class="sortbtn' + (rk !== 'all' ? ' on' : '') + '" style="position:absolute;top:14px;right:14px;z-index:2" data-act="sortmenu:ring" aria-label="Filtrar">' + RMI('filter-3-line', 18, rk !== 'all' ? '#fff' : '#6C6C70') + '</button><div style="max-width:300px;margin:0 auto">' + (ring || '<div class="empty">Sin deuda registrada</div>') + '</div>' +
      '<div style="padding-top:10px"><div class="name" style="font-size:17px">' + (!fDebt ? 'Sin deuda' : base.months && base.ok ? 'Libre de deuda en ' + monthYear(addMonths(c.today, base.months)) : 'Tu plan actual no liquida la deuda') + '</div><div class="sub" style="padding:2px 0 6px">Con tus pagos actuales. Mira cuánto cambia pagando un poco más.</div>' + inclNote(fc, (k) => k.balance) +
      '<button class="linkrow" data-act="interest">' + ICON.info + (ui.interest ? 'Ocultar detalle de intereses' : 'Ver detalle de intereses') + '</button>' + detail +
      '<button class="linkrow" data-act="sim">' + ICON.sliders + 'Simular pago extra</button></div></div>' : '') +
    secHead('Tarjetas y préstamos', sortBtn('card')) + '<div class=\"card lst\">' + (creditRows || '<div class="empty">Aún no hay tarjetas ni préstamos</div>') + hiddenNote('card', c.cards) + addRow('debt', 'Añadir tarjeta o préstamo') + '</div>';
}

function renderAhorro() {
  const c = calc();
  const items = c.savings.filter((s) => s.ub > 0).map((s) => ({ v: s.ub, color: s.color }));
  const center = '<text x="120" y="112" text-anchor="middle" font-size="13" fill="#6C6C70" font-family="inherit">Ahorrado</text><text x="120" y="146" text-anchor="middle" font-size="32" font-weight="700" letter-spacing="-1" fill="#1C1C1E" font-family="inherit">' + fmt(c.saved) + '</text>';
  const ring = ringSVG(items, 100, 22, 4, 240, center);
  const rows = c.savings.map((s) => {
    const pct = s.goal > 0 ? Math.min(100, (s.balance / s.goal) * 100) : 0;
    const rem = Math.max(0, s.goal - s.balance), mo = s.monthly > 0 && rem > 0 ? Math.ceil(rem / s.monthly) : 0;
    const eta = s.goal > 0 ? (rem <= 0 ? '¡Meta cumplida!' : (mo ? 'Meta en ' + plural(mo, 'mes', 'meses') + ' · ' + monthYear(addMonths(c.today, mo)) : 'Sin aporte mensual')) : 'Sin meta';
    return rowEdit('saving', s.id, tileFor(s, 0, 'sav'),
      '<div class="name" style="font-size:16px">' + esc(s.name) + '</div>' + (s.goal > 0 ? '<div class="bar"><i style="width:' + pct + '%;background:' + s.color + '"></i></div>' : '') +
      '<div class="sub" style="font-size:13px">' + (s.goal > 0 ? Math.round(pct) + '% de ' + fmtC(s.goal, s.cur) + ' · ' : '') + eta + '</div>' + savingInsight(s),
      '<span class="amt">' + fmtC(s.balance, s.cur) + '</span>');
  }).join('');
  $('#s-ahorro').innerHTML =
    '<div class="head"><div><h1>Ahorro</h1></div></div>' + tabSel('ahorro') +
    '<div class="card"><div style="max-width:240px;margin:0 auto">' + ring + '</div>' +
      '<div class="sub" style="text-align:center;padding-top:6px">Aportas unos <b style="color:var(--ink)">' + fmt(c.savedMonthly) + '</b> al mes</div>' + inclNote(c.savings, (x) => x.balance) +
      '<button class="linkrow" data-act="new:contrib">' + ICON.sliders + 'Aportar a una meta</button></div>' +
    secHead('Metas') + '<div class=\"card lst\">' + (rows || '<div class="empty">Aún no tienes metas</div>') + addRow('saving', 'Añadir meta de ahorro') + '</div>';
}

