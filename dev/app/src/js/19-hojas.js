/* ---------- Hojas (estilo Apple Pay) ---------- */
function catsHTML() {
  return ui.sheetType === 'out'
    ? '<div class="chips">' + CAT_ORDER.map((c) => '<button class="chip' + (ui.sheetCat === c ? ' on' : '') + '" data-act="cat:' + c + '">' + c + '</button>').join('') + '</div>'
    : '';
}
const XSVG = RMI('close-line', 22, '#1C1C1E');
const OKSVG = RMI('check-line', 24, '#F5F5F5');
function sheetHead(title, act, save) { return '<div class="shead"><button class="xbtn" data-act="' + (act || 'close') + '" aria-label="Cerrar">' + XSVG + '</button><div class="stitle">' + title + '</div>' + (save ? '<button class="okbtn" data-act="' + save + '" aria-label="Guardar">' + OKSVG + '</button>' : '') + '</div>'; }
const GL = {
  pen: '' + IC_PEN_W + '',
  cal: '' + IC_CAL_W + '',
  card: ICON.card.replace('width="24" height="24"', 'width="19" height="19"')
};
const FICO = { pen: 'pencil-line', cal: 'calendar-line', card: 'bank-card-line', '#': 'hashtag-line', '%': 'percent-line', '$': 'coins-line', '◎': 'seedling-line', '▦': 'layout-grid-line', '▭': 'bank-card-line' };
const NUMC = (n) => '<svg width="24" height="24" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9.25" fill="none" stroke="currentColor" stroke-width="2"/><text x="12" y="16.4" text-anchor="middle" font-size="12.5" font-weight="700" fill="currentColor" font-family="Inter,-apple-system,sans-serif">' + n + '</text></svg>';
const fico = (ic) => '<span class="sico" aria-hidden="true">' + (ic[1] === 'n1' || ic[1] === 'n2' ? NUMC(ic[1].slice(1)) : FICO[ic[1]] ? RMI(FICO[ic[1]], 24, 'currentColor') : '<b class="glyph">' + ic[1] + '</b>') + '</span>';

/* --- Sugerencias de nota: lo que ya escribiste antes --- */
function typeHint() {
  const t = ui.sheetType;
  return t === 'in' ? 'Dinero que entra. Suma a tus ingresos.' : t === 'pay' ? 'Pagas lo que debes. No es un gasto.' : ui.sheetCard ? 'Compra con tarjeta. Aumenta tu deuda.' : 'Dinero que sale. Cuenta en tu presupuesto.';
}
function noteSugList(q) {
  const cnt = {};
  (data.transactions || []).slice().reverse().forEach((t) => {
    const n = String(t.note || '').trim(); if (!n || n.length > 40 || /^Pago de /.test(n)) return;
    const k = n.toLowerCase(); if (!cnt[k]) { cnt[k] = { n: n, c: 0, cat: t.category, out: t.amount < 0 }; } cnt[k].c++;
  });
  const ql = q.trim().toLowerCase();
  return Object.keys(cnt).map((k) => cnt[k]).filter((x) => !ql || (x.n.toLowerCase().indexOf(ql) >= 0 && x.n.toLowerCase() !== ql)).sort((a, b) => {
    const as = ql && a.n.toLowerCase().indexOf(ql) === 0 ? 1 : 0, bs = ql && b.n.toLowerCase().indexOf(ql) === 0 ? 1 : 0; return bs - as || b.c - a.c;
  }).slice(0, 4);
}
function noteSugHTML(q) {
  ui.nsug = noteSugList(q);
  return ui.nsug.map((x, i) => '<button type="button" class="nchip" data-act="nsug:' + i + '">' + esc(x.n) + '</button>').join('');
}

/* --- Transferir entre cuentas (no cuenta como gasto ni ingreso) --- */
const xNum = (v) => parseFloat(String(v || '').replace(',', '.'));
function xferConv(amt) { const f = accOf(ui.xf.from), t = accOf(ui.xf.to); return round2(fromUSD(usd(amt, f.cur), t.cur)); }
function xferRead() { const g = (id) => ($(id) || {}).value || ''; return { amount: g('#fAmount'), recv: g('#xRecv'), comm: g('#xComm'), note: g('#xNote'), date: g('#xDate') }; }
function openXfer() {
  if (data.accounts.length < 2) { toast('Añade otra cuenta para transferir'); openForm('account'); return; }
  ui.sheetCard = null; ui.form = null; ui.confirmId = null; ui.txEditId = null;
  ui.xf = { from: data.accounts[0].id, to: data.accounts[1].id, recvEdited: false };
  showSheet(xferHTML());
}
function xferHTML(keep) {
  const k = keep || {}, x = ui.xf, f = accOf(x.from), t = accOf(x.to), diff = f.cur !== t.cur;
  const opts = (sel, skip) => data.accounts.filter((a) => a.id !== skip).map((a) => '<option value="' + a.id + '"' + (a.id === sel ? ' selected' : '') + '>' + esc(a.name) + l4(a) + ' · ' + a.cur + '</option>').join('');
  const row = (ic, lbl, inner) => '<label class="srow">' + fico(ic) + '<span class="grow"><span class="slabel">' + lbl + '</span>' + inner + '</span></label>';
  return sheetHead('Transferir', null, 'xsubmit') +
    '<div class="amtblock"><div class="amtlabel">Monto</div><div class="amount"><span id="fSym">' + symOf(f.cur).trim() + '</span><input id="fAmount" inputmode="decimal" placeholder="' + (decOf(f.cur) ? '0.00' : '0') + '" autocomplete="off" value="' + esc(k.amount || '') + '" style="width:' + amtW(k.amount, decOf(f.cur) ? '0.00' : '0') + '"></div></div>' +
    '<div class="thint" style="padding-top:0">No cuenta como gasto ni ingreso.</div>' +
    '<div class="scard">' +
    row(['#22B573', 'card'], 'Desde', '<select class="sinput" id="xFrom">' + opts(x.from, x.to) + '</select>') +
    row(['#22B573', 'card'], 'A', '<select class="sinput" id="xTo">' + opts(x.to, x.from) + '</select>') +
    (diff ? row(['#22B573', '$'], 'Recibes', '<span style="display:flex;align-items:center;gap:6px"><span class="xsym" style="font-size:17px;font-weight:500">' + symOf(t.cur).trim() + '</span><input class="sinput" id="xRecv" inputmode="decimal" autocomplete="off" placeholder="' + (decOf(t.cur) ? '0.00' : '0') + '" value="' + esc(k.recv || '') + '"></span><span class="sub xrate" id="xRate" style="font-size:13px"></span>') : '') +
    row(['#FF9F0A', '$'], 'Comisión (opcional)', '<span style="display:flex;align-items:center;gap:6px"><span class="xsym" style="font-size:17px;font-weight:500">' + symOf(f.cur).trim() + '</span><input class="sinput" id="xComm" inputmode="decimal" autocomplete="off" placeholder="0" value="' + esc(k.comm || '') + '"></span>') +
    row(['#22B573', 'pen'], 'Nota', '<input class="sinput" id="xNote" placeholder="Opcional" autocomplete="off" value="' + esc(k.note || '') + '">') +
    row(['#FF9F0A', 'cal'], 'Fecha', '<input class="sinput" id="xDate" type="date" max="' + iso(getToday()) + '" value="' + esc(k.date || iso(getToday())) + '">') + '</div>' +
    '<button class="primary" data-act="xsubmit">Transferir</button>';
}
function xferSync() {
  const x = ui.xf; if (!x) return; const rv = $('#xRecv'); if (!rv) return;
  const amt = xNum(($('#fAmount') || {}).value), t = accOf(x.to), f = accOf(x.from);
  if (!x.recvEdited) rv.value = amt > 0 ? xferConv(amt).toFixed(decOf(t.cur) ? 2 : 0) : '';
  const rc = xNum(rv.value), hint = $('#xRate'), est = 'Estimado con el cambio de la app. Corrígelo si recibiste otro monto.';
  if (hint) { if (amt > 0 && rc > 0 && x.recvEdited) { const rt = rc / amt, rn = (v) => Math.round(v * 10000) / 10000; hint.innerHTML = '<span>Tipo de cambio:</span> ' + (rt >= 1 ? '1 ' + f.cur + ' = ' + rn(rt) + ' ' + t.cur : '1 ' + t.cur + ' = ' + rn(1 / rt) + ' ' + f.cur); } else hint.textContent = est; }
}
function xferSubmit() {
  const x = ui.xf; if (!x) return; const v = xferRead(), amt = xNum(v.amount);
  if (!(amt > 0)) { toast('Escribe un monto'); return; }
  if ((v.date || iso(getToday())) > iso(getToday())) { toast(futureMsg); return; }
  const f = accOf(x.from), t = accOf(x.to); let recv = amt;
  if (f.cur !== t.cur) { recv = xNum(v.recv); if (!(recv > 0)) recv = xferConv(amt); }
  recv = round2(recv); const comm = round2(xNum(v.comm) || 0), d = v.date || iso(getToday()), pid = uid(), note = v.note.trim();
  data.transactions.push({ id: nextTxId(), date: d, amount: -amt, category: XFER, note: note, acc: f.id, pair: pid }); applyTo(f, -amt);
  data.transactions.push({ id: nextTxId(), date: d, amount: recv, category: XFER, note: note, acc: t.id, pair: pid }); applyTo(t, recv);
  if (comm > 0) { data.transactions.push({ id: nextTxId(), date: d, amount: -comm, category: 'Otros', note: 'Comisión de transferencia', acc: f.id }); applyTo(f, -comm); }
  ui.dirty++; persist(); closeSheet(); renderAll(); toast(negWarn([f.id]) || 'Transferencia registrada');
}
document.addEventListener('input', (e) => { const el = e.target; if (!ui.xf || !el) return; if (el.id === 'xRecv') ui.xf.recvEdited = true; if (el.id === 'fAmount' || el.id === 'xRecv') xferSync(); });
document.addEventListener('change', (e) => {
  const el = e.target; if (!ui.xf || !el || (el.id !== 'xFrom' && el.id !== 'xTo')) return; const keep = xferRead(), key = el.id === 'xFrom' ? 'from' : 'to', other = key === 'from' ? 'to' : 'from';
  ui.xf[key] = el.value; if (ui.xf[other] === el.value) ui.xf[other] = (data.accounts.find((a) => a.id !== el.value) || {}).id; ui.xf.recvEdited = false; showSheet(xferHTML(keep)); xferSync();
});

/* --- Nuevo movimiento --- */
function sheetHTML(keep) {
  const k = keep || {}, acc = accOf(ui.sheetAcc);
  return sheetHead('Nuevo movimiento', null, 'submit') +
    '<div class="amtblock"><div class="amtlabel">Monto</div><div class="amount"><span id="fSym">' + symOf(acc.cur).trim() + '</span><input id="fAmount" inputmode="decimal" placeholder="' + (decOf(acc.cur) ? '0.00' : '0') + '" autocomplete="off" value="' + esc(k.amount || '') + '" style="width:' + amtW(k.amount, decOf(acc.cur) ? '0.00' : '0') + '"></div></div>' +
    segHTML('type', (ui.sheetCard ? [{ k: 'out', label: 'Compra', act: 'type:out' }, { k: 'pay', label: 'Pago', act: 'type:pay' }] : [{ k: 'out', label: 'Gasto', act: 'type:out' }, { k: 'in', label: 'Ingreso', act: 'type:in' }].concat(data.cards.length ? [{ k: 'pay', label: 'Pago de crédito', act: 'type:pay' }] : [])), ui.sheetType, ';margin-bottom:4px') + '<div class="thint" id="thint">' + typeHint() + '</div>' +
    '<div id="catWrap">' + catsHTML() + '</div>' +
    '<div class="scard">' +
    (ui.sheetType === 'pay'
      ? '<label class="srow">' + fico(['#B98AE6', 'card']) + '<span class="grow"><span class="slabel">Tarjeta o préstamo</span><select class="sinput" id="fAcc">' + data.cards.map((a) => '<option value="' + a.id + '"' + (a.id === acc.id ? ' selected' : '') + '>' + esc(a.name) + l4(a) + ' · ' + a.cur + '</option>').join('') + '</select></span></label>' +
        '<label class="srow">' + fico(['#22B573', 'card']) + '<span class="grow"><span class="slabel">Pagar desde</span><select class="sinput" id="fFrom"><option value="">Sin descontar de una cuenta</option>' + data.accounts.map((a) => '<option value="' + a.id + '"' + (a.id === ui.sheetFrom ? ' selected' : '') + '>' + esc(a.name) + l4(a) + ' · ' + a.cur + '</option>').join('') + '</select></span></label>' + '<div id="apWrap">' + apRowHTML() + '</div>'
      : '<label class="srow">' + fico(['#22B573', 'card']) + '<span class="grow"><span class="slabel">Cuenta</span><select class="sinput" id="fAcc">' + acctOpts(acc.id, ui.sheetType !== 'in') + '</select></span></label>') +
    '<label class="srow">' + fico(['#22B573', 'pen']) + '<span class="grow"><span class="slabel">Nota</span><input class="sinput" id="fNote" placeholder="Opcional" autocomplete="off" value="' + esc(k.note || '') + '"></span></label>' +
    '<div class="nsug" id="nsug">' + noteSugHTML(k.note || '') + '</div>' +
    '<label class="srow">' + fico(['#FF9F0A', 'cal']) + '<span class="grow"><span class="slabel">Fecha</span><input class="sinput" id="fDate" type="date" max="' + iso(getToday()) + '" value="' + esc(k.date || iso(getToday())) + '"></span></label></div>' +
    '<button class="primary" data-act="submit">Añadir</button>' +
    (nazcaOn() && !ui.sheetCard ? '<button class="linkrow" data-act="imp:cap" style="justify-content:center;width:100%;margin-top:6px">' + RMI('camera-line', 22, '#1A9D63') + 'Importar captura de Yape o Plin</button>' : '');
}
const HISTORY = [
  { n: 'Beta 5', d: '30 oct 2026', t: 'Plata llega a iPhone y Apple Watch como app nativa: constancias de Yape y Plin que se leen en tu dispositivo, widgets y Bentos, aros de presupuesto y Face ID.', big: 1 },
  { n: 'Beta 4', d: '27 oct 2026', t: 'Nazca lee tus estados de cuenta en tu dispositivo, Revisión con sugerencias en tarjetas y detección de recurrentes, historial de cada suscripción e infraestructura blindada.', big: 1 },
  { n: 'Beta 3', d: '24 oct 2026', t: 'Plata Cloud: sincronización cifrada entre tus dispositivos, por invitación y con el primer mes gratis. Además, notas y rachas con laureles, transferencias entre cuentas, logos automáticos de bancos y servicios, y avisos inteligentes.', big: 1 },
  { n: 'Beta 2', d: '20 oct 2026', t: 'Plata llega a tu mesa: versión de escritorio y Bentos, además del modo oscuro y nuevas secciones en la web.', big: 1 },
  { n: 'Compilación 200', d: '20 oct 2026', t: 'Aviso para abrir Plata en el navegador real si la abres desde Instagram u otras apps.' },
  { n: 'Beta 1 · Lanzamiento público', d: '19 oct 2026', t: 'Plata sale a internet con su sitio en plataapp.net.', big: 1 },
  { n: 'Compilación 1', d: '17 oct 2026', t: 'La primera versión guardada de la app.' }
];
function historySheetHTML() {
  return sheetHead('Historia de Plata') + '<div class="sub" style="font-size:14px;padding:0 8px 4px;text-align:center">Lo más destacado, cada 50 compilaciones y en cada beta.</div><div class="scard" style="padding:14px 16px 16px"><div class="tl">' +
    HISTORY.map((h) => '<div class="ev"><span class="dot" style="background:' + (h.big ? 'var(--accent)' : 'var(--mute)') + '"></span><div class="grow"><div class="name" style="font-size:16px;font-weight:600">' + h.n + '</div><div class="sub" style="font-size:13px">' + h.d + '</div><div style="font-size:14px;margin-top:4px;line-height:1.3">' + h.t + '</div></div></div>').join('') + '</div></div>';
}
function showSheet(html) { const s = $('#sheet'); ui.profSheet = false; s.innerHTML = html; s.classList.remove('tall', 'prof'); s.classList.add('show'); $('#backdrop').classList.add('show'); }
function openSheet() { ui.sheetCard = null; ui.sheetAuto = false; ui.sheetType = 'out'; ui.sheetCat = CAT_ORDER[0] || 'Otros'; ui.sheetAcc = data.accounts[0].id; ui.confirmId = null; ui.form = null; showSheet(sheetHTML()); }
document.addEventListener('click', (e) => { const a = e.target.closest && e.target.closest('.amount'); if (a && e.target.tagName !== 'INPUT') { const i = a.querySelector('input'); if (i) i.focus(); } });
document.addEventListener('change', (e) => { const el = e.target; if (el && el.matches && el.matches('select[data-mmsel]')) { ui.mm = { mk: el.value, f: 'all', page: 0 }; renderCuenta(); seasonReplay(); document.querySelectorAll('.screen').forEach((sc) => { sc.scrollTop = 0; }); } });

