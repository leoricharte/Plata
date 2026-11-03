/* ---------- Revisión, vista nueva: textos cortos y tarjetas por tipo (carrusel por tipo) ---------- */
const RV_G = [['transf', 'Transferencias', 'arrow-left-right-line', ['xfer', 'own']], ['pago', 'Pagos', 'bank-card-line', ['pay2', 'card']], ['rec', 'Recurrentes', 'repeat-line', ['rec']], ['rep', 'Repetidos', 'file-search-line', ['dup']], ['monto', 'Montos', 'error-warning-line', ['big']], ['falta', 'Estados', 'folder-chart-line', ['gap']]];
const RV_ONE = { xfer: 'Sale de una cuenta y entra en otra.', own: 'Va a una cuenta tuya fuera de Plata.', pay2: 'Es el mismo pago, no lo cuentes doble.', card: 'Coincide con el pago de una tarjeta.', dup: 'Lo anotaste y también vino del banco.', big: 'Mucho más alto de lo normal.', gap: 'Puede faltar un estado.', rec_job: 'Ingreso que se repite.', rec_sub: 'Cobro que se repite.', rec_fix: 'Gasto que se repite.' };
const RV_BTN = { xfer: 'Es transferencia', own: 'Es transferencia', pay2: 'Juntar como un pago', card: 'Registrar como pago', dup: 'Borrar el mío', big: 'Editar', gap: 'Importar un estado', rec_job: 'Crear trabajo', rec_sub: 'Crear suscripción', rec_fix: 'Crear gasto fijo' };
const RV_TTL = { xfer: 'Transferencia entre tus cuentas', pay2: 'Pago de tarjeta', card: 'Pago de tarjeta', dup: 'Movimiento repetido', big: 'Monto muy alto', gap: 'Estado faltante', rec_job: 'Trabajo', rec_sub: 'Suscripción', rec_fix: 'Gasto fijo' };
const RV_CAD = { w: 'cada semana', b: 'cada 2 semanas', m: 'cada mes', q: 'cada quincena' };
function rvInner(r) {
  const rk = r.kind === 'rec' ? 'rec_' + r.type : r.kind;
  const cur = r.txs.length ? accOf(r.txs[0].acc).cur : '', A = (t) => '<span>' + t + '</span> ';
  let rows = '', mid = '';
  if (r.kind === 'xfer') rows = smRow(r.txs[0], 'Sale') + smRow(r.txs[1], 'Entra');
  else if (r.kind === 'pay2') rows = smRow(r.txs[0], 'Se corregirá') + smRow(r.txs[1], 'Se vinculará');
  else if (r.kind === 'dup') rows = smRow(r.txs[0], 'Anotado a mano') + smRow(r.txs[1], 'Del banco');
  else if (r.kind === 'own') {
    const s0 = r.txs.slice().sort((a, b) => (a.date < b.date ? 1 : -1)), s2 = s0.slice(0, 2), ds = r.txs.map((x) => x.date).sort();
    mid = '<div class="rvmeta">' + r.txs.length + ' <span>movimientos</span> · ' + ds[0].slice(0, 7) + ' → ' + ds[ds.length - 1].slice(0, 7) + (r.out != null ? '<br>' + A('Salidas') + fmtC2(r.out, r.cur) + ' · ' + A('Entradas') + fmtC2(r.inn, r.cur) : '') + '</div>';
    rows = s2.map((x) => smRow(x, 'Transferencia')).join('') + (r.txs.length > 2 ? '<details class="rvwhy rvmoreD"><summary class="rvsum"><span>y</span> ' + (r.txs.length - 2) + ' <span>más</span>' + RMI('arrow-down-s-line', 22, 'currentColor') + '</summary>' + s0.slice(2, 12).map((x) => smRow(x, 'Transferencia')).join('') + (r.txs.length > 12 ? '<div class="rvmore">…</div>' : '') + '</details>' : '');
  } else if (r.kind === 'rec') {
    const s0 = r.txs.slice().sort((a, b) => (a.date < b.date ? 1 : -1)), lb = r.neg ? 'Cargo' : 'Ingreso';
    mid = '<div class="rvmeta">' + (r.fixed ? '' : '<span>aprox.</span> ') + fmtC2(r.amt, r.cur) + ' <span>' + RV_CAD[r.cad] + '</span> · ' + r.txs.length + ' <span>veces</span></div>';
    rows = s0.slice(0, 2).map((x) => smRow(x, lb)).join('') + (s0.length > 2 ? '<details class="rvwhy rvmoreD"><summary class="rvsum"><span>y</span> ' + (s0.length - 2) + ' <span>más</span>' + RMI('arrow-down-s-line', 22, 'currentColor') + '</summary>' + s0.slice(2, 12).map((x) => smRow(x, lb)).join('') + (s0.length > 12 ? '<div class="rvmore">…</div>' : '') + '</details>' : '');
  } else if (r.kind === 'gap') {
    const a = accOf(r.acc);
    mid = '<div class="rvmeta"><b data-notr>' + esc(a.name) + l4(a) + '</b>' + (r.miss.length ? '<br>' + A('Sin movimientos:') + '<span data-notr>' + r.miss.join(' · ') + '</span>' : '') + (r.diff ? '<br>' + A('Diferencia de saldo:') + fmtC2(Math.abs(r.diff), a.cur) : '') + '</div>';
  } else rows = smRow(r.txs[0], r.kind === 'big' ? 'Lo editas tú' : 'Se reemplazará') + (r.kind === 'big' ? '<div class="rvmeta">' + A('Lo normal:') + fmtC2(r.med, cur) + '</div>' : '');
  const badge = r.hi ? '<span class="rvbd g">casi seguro</span>' : r.far ? '<span class="rvbd a">revisa las fechas</span>' : '';
  return '<div class="rvt">' + (r.kind === 'rec' ? (r.brand ? '<span class="rvlogo" style="background:' + r.brand.bg + '">' + subSVG(r.brand, 18) + '</span>' : '') + '<span data-notr>' + esc(r.name) + '</span><span class="rvbd n">' + RV_TTL[rk] + '</span>' : r.kind === 'own' ? '<span data-notr>' + esc(r.label) + '</span>' : RV_TTL[r.kind]) + badge + '</div><div class="rvs">' + RV_ONE[rk] + '</div>' + mid + '<div class="rvrows">' + rows + '</div>' +
    '<details class="rvwhy"><summary class="rvsum">' + RMI('question-line', 20, 'currentColor') + '<span>¿Por qué?</span>' + RMI('arrow-down-s-line', 22, 'currentColor') + '</summary><p>' + RV_TXT[rk][1] + '</p></details>' +
    '<div class="rvbt"><button class="primary" data-act="rv:ok:' + esc(r.k) + '">' + RV_BTN[rk] + '</button><button class="linkrow" data-act="rv:no:' + esc(r.k) + '">No es</button></div>';
}
function rvShell(body) {
  const off = (data.settings.rv_off || []).length;
  return sheetHead('Revisión') + '<div class="thint" style="padding-top:0">Nada cambia hasta que aceptes.</div>' +
    (revUndo ? '<div class="scard" style="padding:12px 16px;margin-bottom:12px;display:flex;align-items:center;gap:10px"><span class="grow" style="font-size:14.5px;font-weight:600">Hecho</span><button class="linkrow" data-act="rv:undo" style="width:auto;padding:8px 12px">Deshacer</button></div>' : '') + body +
    (off ? '<button class="linkrow" data-act="rv:reset" style="width:100%;justify-content:center">Mostrar las descartadas</button>' : '');
}
const rvEmpty = () => '<div class="scard" style="padding:22px 16px;text-align:center"><div style="font-size:17px;font-weight:700">Todo en orden</div><div style="font-size:13.5px;color:var(--sec);margin-top:4px">Plata no encontró movimientos que parezcan mal clasificados.</div></div>';
const rvGroup = (list, k) => { const g = RV_G.find((x) => x[0] === k); return list.filter((r) => g[3].indexOf(r.kind) >= 0); };
function revHTML() {
  const list = revScan(); if (!list.length) return rvShell(rvEmpty());
  const tabs = RV_G.filter((g) => rvGroup(list, g[0]).length);
  const sel = tabs.find((g) => g[0] === ui.rvTab) || tabs[0], L = rvGroup(list, sel[0]), hiL = list.filter((r) => r.kind === 'xfer' && r.hi);
  return rvShell('<div class="rvtabs">' + tabs.map((g) => '<button class="rvtab' + (g === sel ? ' on' : '') + '" data-act="rv:tab:' + g[0] + '">' + RMI(g[2], 16, 'currentColor') + g[1] + '<b>' + rvGroup(list, g[0]).length + '</b></button>').join('') + '</div>' +
    (sel[0] === 'transf' && hiL.length >= 3 ? '<button class="rvall" data-act="rv:allhi">' + RMI('check-line', 18, 'currentColor') + '<span>Convertir</span> ' + hiL.length + ' <span>casi seguras</span></button>' : '') +
    '<div class="rvcar">' + L.map((r) => '<div class="scard rvcard">' + rvInner(r) + '</div>').join('') + '</div>' +
    (L.length > 1 ? '<div class="rvdots">' + (L.length <= 7 ? L.map((r, j) => '<i' + (j === 0 ? ' class="on"' : '') + '></i>').join('') : '<span class="rvcnt"><span>Desliza</span> · ' + L.length + '</span>') + '</div>' : ''));
}
document.addEventListener('scroll', (e) => { const c = e.target; if (!c || !c.classList || !c.classList.contains('rvcar') || !c.firstElementChild) return; const i = Math.round(c.scrollLeft / (c.firstElementChild.offsetWidth + 12)); c.parentNode.querySelectorAll('.rvdots i').forEach((x, j) => x.classList.toggle('on', j === i)); }, true);
function revAct(arg) {
  const i = arg.indexOf(':'), op = i < 0 ? arg : arg.slice(0, i), k = i < 0 ? '' : arg.slice(i + 1);
  if (op === 'open') { revUndo = null; showSheet(revHTML()); return; }
  if (op === 'tab') { ui.rvTab = k; showSheet(revHTML()); const e = document.querySelector('.rvtab.on'); if (e && e.parentNode) e.parentNode.scrollLeft = e.offsetLeft - (e.parentNode.clientWidth - e.offsetWidth) / 2; return; }
  if (op === 'undo') {
    if (revUndo) { revUndo.snap.forEach((q) => { q.x.category = q.category; q.x.note = q.note; if (q.pair === undefined) delete q.x.pair; else q.x.pair = q.pair; if ('sub' in q) { if (q.sub === undefined) delete q.x.sub; else q.x.sub = q.sub; } if ('job' in q) { if (q.job === undefined) delete q.x.job; else q.x.job = q.job; } });
      const mk = revUndo.mk; if (mk) { data[mk.coll] = data[mk.coll].filter((x) => x.id !== mk.id); if (mk.coll === 'jobs') syncJobs(); } revUndo = null; rvCache = null; ui.dirty++; persist(); renderAll(); toast('Deshecho'); }
    showSheet(revHTML()); return;
  }
  if (op === 'bn') { data.settings.rv_bn = revCount(); ui.dirty++; persist(); renderAll(); return; }
  if (op === 'reset') { data.settings.rv_off = []; rvCache = null; ui.dirty++; persist(); renderAll(); showSheet(revHTML()); return; }
  if (op === 'allhi') {
    const L = revScan().filter((x) => x.kind === 'xfer' && x.hi); revUndo = { snap: [] };
    L.forEach((r) => { const pid = uid(); r.txs.forEach((x) => { revUndo.snap.push({ x: x, category: x.category, pair: x.pair, note: x.note }); x.category = XFER; x.pair = pid; }); });
    toast('Transferencia registrada'); rvCache = null; ui.dirty++; persist(); renderAll(); showSheet(revHTML()); return;
  }
  const r = revScan().find((x) => x.k === k); if (!r) { showSheet(revHTML()); return; }
  revUndo = null;
  const snap = () => { revUndo = { snap: r.txs.map((x) => ({ x: x, category: x.category, pair: x.pair, note: x.note })) }; };
  if (op === 'no') { const o = data.settings.rv_off || []; o.push(k); data.settings.rv_off = o.slice(-300); }
  else if (r.kind === 'xfer') { snap(); const pid = uid(); r.txs.forEach((x) => { x.category = XFER; x.pair = pid; }); toast('Transferencia registrada'); }
  else if (r.kind === 'own') { snap(); r.txs.forEach((x) => { x.category = XFER; }); toast('Transferencia registrada'); }
  else if (r.kind === 'pay2') { snap(); const pay = r.txs[1], ex = r.txs[0], kd = accOf(pay.acc), pid = uid(), wasPay = pay.category === PAY; ex.category = PAY; ex.note = 'Pago a ' + kd.name; ex.pair = pid; pay.pair = pid; if (!wasPay) { pay.category = PAY; pay.note = 'Pago de ' + kd.name; } toast('Pago registrado'); }
  else if (r.kind === 'gap') { if (typeof nazcaOn === 'function' && !nazcaOn()) { showSheet(revHTML()); return; } closeSheet(); impOpen(); return; }
  else if (r.kind === 'dup') { const t = r.txs[0]; txRevert(t); data.transactions = data.transactions.filter((x) => x !== t); toast('Movimiento eliminado'); }
  else if (r.kind === 'card') {
    const t = r.txs[0], card = data.cards.find((x) => x.id === r.card), acc = accOf(t.acc); if (!card || data.transactions.indexOf(t) < 0) { showSheet(revHTML()); return; }
    data.transactions.splice(data.transactions.indexOf(t), 1); applyTo(acc, -t.amount);
    registerPay(card, round2(fromUSD(usd(-t.amount, acc.cur), card.cur)), t.date, acc.id, 'Pago de ' + card.name); toast('Pago registrado');
  }
  else if (r.kind === 'rec') {
    const L = r.txs, last = L[L.length - 1].date, id = uid(), sn = () => { revUndo = { snap: L.map((x) => ({ x: x, category: x.category, pair: x.pair, note: x.note, sub: x.sub, job: x.job })), mk: null }; };
    sn();
    if (r.type === 'sub') {
      data.subs.push({ id: id, since: L[0].date, name: r.name, amount: r.amt, cur: r.cur, day: +last.slice(8, 10) || 1, acc: r.acc }); L.forEach((x) => { x.sub = id; });
      revUndo.mk = { coll: 'subs', id: id }; toast('Suscripción creada');
    } else if (r.type === 'fix') {
      const rep = r.cad === 'm' ? 'm' : r.cad === 'w' ? 7 : 14;
      data.expected_expense.push({ id: id, name: r.name, amount: r.amt, acc: r.acc, date: iso(nextRep(pd(last), rep)), repeat: rep, until: '' });
      revUndo.mk = { coll: 'expected_expense', id: id }; toast('Gasto fijo creado');
    } else {
      const f = r.cad, jq = r.q ? qDays('q' + r.q[0] + ',' + r.q[1]) : null, rate = f === 'm' ? r.amt : f === 'w' ? round2(r.amt * 52 / 12) : round2(r.amt * 2);
      const jo = { id: id, mode: 's', name: r.name, rate: rate, hours: 0, tax: 0, freq: f, acc: r.acc, start: '', until: '', sim: 0 };
      if (jq) { jo.q1 = jq[0]; jo.q2 = jq[1]; }
      jo.start = iso(nextRep(pd(last), jobRep(f, jo)));
      data.jobs.push(jo); L.forEach((x) => { x.job = id; }); syncJobs();
      revUndo.mk = { coll: 'jobs', id: id }; toast('Trabajo creado');
    }
  }
  else if (r.kind === 'big') { const t = r.txs[0]; ui.txId = t.id; ui.confirmId = null; ui.form = null; showSheet(txEditHTML(t)); return; }
  rvCache = null; ui.dirty++; persist(); renderAll(); showSheet(revHTML());
}
/* Avisos de "esto se ve raro": solo ayudan a no penalizar sin querer; siempre se pueden descartar */
function smRow(t, label) {
  const cur = accOf(t.acc).cur, nm = t.note || t.category;
  return '<div style="display:flex;align-items:center;gap:10px;text-align:left;padding:10px 0;border-top:1px solid var(--line)"><div style="flex:1;min-width:0"><div style="font-size:15px;font-weight:600;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">' + esc(nm) + '</div><div style="font-size:12.5px;color:var(--sec);overflow:hidden;text-overflow:ellipsis;white-space:nowrap">' + esc(t.category + ' · ' + dlabel(pd(t.date))) + '</div><div style="font-size:12.5px;color:var(--sec);overflow:hidden;text-overflow:ellipsis;white-space:nowrap">' + esc(accOf(t.acc).name) + '</div></div>' +
    '<div style="flex:none;text-align:right"><div style="font-size:15px;font-weight:600">' + (t.amount < 0 ? '−' : '+') + fmtC2(Math.abs(t.amount), cur) + '</div><div style="font-size:12.5px;font-weight:700;color:#E5A100">' + esc(label) + '</div></div></div>';
}
function smartCheck(t) {
  if (!t || t.job || t.pair) return;
  const U = (x) => usd(Math.abs(x.amount), accOf(x.acc).cur), dd = (a, b) => Math.abs((pd(a) - pd(b)) / 864e5);
  const title = 'Eh… no somos expertos, pero';
  /* 0) pago de tarjeta anotado suelto + gasto de una cuenta por lo mismo: son dos mitades del mismo pago */
  const isDeb = (x) => data.accounts.some((a) => a.id === x.acc), isCrd = (x) => data.cards.some((k) => k.id === x.acc);
  const loosePay = (x) => x.amount > 0 && !x.pair && !x.job && isCrd(x) && (x.category === PAY || !isPay(x)), looseExp = (x) => !isPay(x) && x.amount < 0 && !x.pair && !x.job && isDeb(x);
  if (loosePay(t) || looseExp(t)) {
    const m = data.transactions.find((x) => x !== t && dd(x.date, t.date) <= 2 && Math.abs(U(x) - U(t)) <= Math.max(0.5, U(t) * 0.03) && (loosePay(t) ? looseExp(x) : loosePay(x)));
    if (m) {
      const pay = loosePay(t) ? t : m, ex = loosePay(t) ? m : t, kd = accOf(pay.acc);
      askConfirm(title, 'Creemos que estos dos movimientos son el mismo pago de tu tarjeta ' + kd.name + '. ¿Los juntamos como un solo pago para que el gasto no cuente doble?', [{ label: 'Aceptar cambios', fn: () => {
        const pid = uid(), wasPay = pay.category === PAY; ex.category = PAY; ex.note = 'Pago a ' + kd.name; ex.pair = pid; pay.pair = pid; if (!wasPay) { pay.category = PAY; pay.note = 'Pago de ' + kd.name; }
        ui.dirty++; persist(); renderAll(); toast('Pago registrado');
      } }], '<div style="margin:10px 0 14px">' + smRow(ex, 'Se corregirá') + smRow(pay, pay.category === PAY ? 'Se vinculará' : 'Se corregirá') + '</div>', 'Mantener cambios');
      return;
    }
  }
  if (isPay(t)) return;
  const acc = data.accounts.find((x) => x.id === t.acc); if (!acc) return;
  /* 1) gasto + ingreso parecidos en cuentas distintas: probablemente una transferencia */
  const o = data.transactions.find((x) => x !== t && !isPay(x) && !x.job && !x.pair && x.acc !== t.acc && data.accounts.some((a) => a.id === x.acc) && (x.amount < 0) !== (t.amount < 0) && dd(x.date, t.date) <= 2 && Math.abs(U(x) - U(t)) <= Math.max(0.5, U(t) * 0.03));
  if (o) {
    const out = t.amount < 0 ? t : o, inn = t.amount < 0 ? o : t;
    askConfirm(title, 'Creemos que esto fue una transferencia entre tus cuentas. ¿La registramos así para que no cuente como gasto ni ingreso?', [{ label: 'Aceptar cambios', fn: () => {
      const pid = uid(); [out, inn].forEach((x) => { x.category = XFER; x.pair = pid; x.note = ''; });
      ui.dirty++; persist(); renderAll(); toast('Transferencia registrada');
    } }], '<div style="margin:10px 0 14px">' + smRow(out, 'Se corregirá') + smRow(inn, 'Se corregirá') + '</div>', 'Mantener cambios');
    return;
  }
  if (t.amount >= 0) return;
  /* 2) gasto que coincide con la cuota o el saldo de una tarjeta: probablemente un pago */
  const card = data.cards.find((k) => k.balance > 0.005 && [k.payment, k.balance].some((v) => v > 0 && Math.abs(usd(v, k.cur) - U(t)) <= Math.max(0.5, U(t) * 0.01)));
  if (card) {
    askConfirm(title, 'Creemos que esto fue el pago de tu tarjeta ' + card.name + '. ¿Lo registramos como pago para que no cuente como gasto?', [{ label: 'Aceptar cambios', fn: () => {
      const i = data.transactions.indexOf(t); if (i < 0) return;
      data.transactions.splice(i, 1); applyTo(acc, -t.amount);
      registerPay(card, round2(fromUSD(usd(-t.amount, acc.cur), card.cur)), t.date, acc.id, 'Pago de ' + card.name);
      ui.dirty++; persist(); renderAll(); toast('Pago registrado');
    } }], '<div style="margin:10px 0 14px">' + smRow(t, 'Se reemplazará') + '</div>', 'Mantener cambios');
    return;
  }
  /* 3) monto muy por encima de lo habitual en su categoría: probablemente un error al escribirlo */
  const same = data.transactions.filter((x) => x !== t && x.amount < 0 && !isPay(x) && x.category === t.category && dd(x.date, t.date) <= 120).map((x) => Math.abs(x.amount) * 1).sort((a, b) => a - b);
  if (same.length >= 5) {
    const med = same[Math.floor(same.length / 2)];
    if (med > 0 && Math.abs(t.amount) >= med * 10) {
      askConfirm(title, 'Creemos que este monto es mucho para ' + t.category + ' (lo normal son unos ' + fmtC2(med, acc.cur) + '). ¿Te equivocaste al escribirlo?', [{ label: 'Aceptar cambios', fn: () => { ui.txId = t.id; ui.confirmId = null; ui.form = null; showSheet(txEditHTML(t)); } }], '<div style="margin:10px 0 14px">' + smRow(t, 'Lo editas tú') + '</div>', 'Mantener cambios');
    }
  }
}

/* --- Formularios genéricos (cuentas, ahorros, deudas, suscripciones, ingresos, simulaciones, presupuesto, aportes) --- */
const CURSEG = { t: 'seg', k: 'cur', get opts() { return activeCurs().map((c) => [c, c]); } };
const FORMS = {
  account: { coll: 'accounts', hero: 'balance', heroLabel: () => 'Saldo', cur: 'cur', need: ['name'], rebuild: ['type'], title: ['Nueva cuenta de débito', 'Cuenta de débito'],
    fields: [{ k: 'name', t: 'text', label: 'Nombre', ic: ['#22B573', 'pen'] }, { k: 'last4', t: 'last4', label: 'Últimos 4 dígitos (opcional)', ic: ['#8E8E93', '#'], show: (o) => o.type !== 'cash' }, { t: 'seg', k: 'type', opts: [['checking', 'Corriente'], ['savings', 'Ahorros'], ['cash', 'Efectivo']] }, { k: 'apy', t: 'num', label: 'Rendimiento anual (%) — opcional', ic: ['#FF9F0A', '%'], show: (o) => o.type !== 'cash' }, CURSEG],
    blank: () => ({ id: uid(), name: '', type: 'checking', cur: curP(), apy: 0, balance: 0, color: '', icon: '' }), style: 'acc' },
  saving: { coll: 'savings', hero: 'goal', heroLabel: () => 'Meta', cur: 'cur', need: ['name'], title: ['Nueva meta', 'Meta de ahorro'],
    fields: [{ k: 'name', t: 'text', label: 'Nombre', ic: ['#22B573', 'pen'] }, { k: 'balance', t: 'num', label: 'Ahorrado hasta la fecha', ic: ['#22B573', '◎'] }, { k: 'monthly', t: 'num', label: 'Aporte mensual', ic: ['#6D8BEA', '+'] }, CURSEG],
    blank: () => ({ id: uid(), name: '', cur: curP(), balance: 0, goal: 0, monthly: 0, color: CARD_COLORS[Math.floor(Math.random() * 5)], icon: '' }), style: 'sav' },
  debt: { coll: 'cards', hero: 'balance', heroLabel: () => 'Saldo adeudado (lo que debes)', cur: 'cur', need: ['name'], title: ['Nueva tarjeta o préstamo', 'Tarjeta o préstamo'], rebuild: ['kind'],
    fields: [{ k: 'name', t: 'text', label: 'Nombre', ic: ['#22B573', 'pen'] }, { k: 'last4', t: 'last4', label: 'Últimos 4 dígitos (opcional)', ic: ['#8E8E93', '#'] }, { t: 'seg', k: 'kind', opts: [['card', 'Tarjeta'], ['loan', 'Préstamo']] },
      { k: 'limit', t: 'num', label: 'Límite de la tarjeta', ic: ['#B98AE6', '▭'], show: (o) => o.kind === 'card' },
      { k: 'apr', t: 'num', label: 'Interés anual (%)', ic: ['#FF9F0A', '%'] }, { k: 'payment', t: 'num', label: 'Pago mensual', ic: ['#22B573', '$'] }, { k: 'due_day', t: 'num', label: 'Día de pago', ic: ['#FF3B30', '#'] }, CURSEG],
    blank: () => ({ id: uid(), kind: 'card', name: '', cur: curP(), limit: 0, balance: 0, apr: 20, payment: 0, due_day: 1, color: '', icon: '' }), style: 'debt' },
  sub: { coll: 'subs', hero: 'amount', heroLabel: () => 'Por mes', cur: 'cur', need: ['name'], pos: true, title: ['Nuevo servicio o suscripción', 'Servicio o suscripción'],
    fields: [{ k: 'name', t: 'text', label: 'Nombre', ic: ['#22B573', 'pen'] }, { k: 'day', t: 'num', label: 'Día de cobro', ic: ['#FF9F0A', '#'] }, { k: 'acc', t: 'select', label: 'Se cobra de', ic: ['#22B573', 'card'] }, CURSEG],
    blank: () => ({ id: uid(), name: '', amount: 0, cur: curP(), day: Math.min(28, getToday().getDate()), acc: '', since: iso(getToday()) }) },
  income: { coll: 'expected_income', hero: 'amount', heroLabel: () => 'Monto previsto', curFrom: 'acc', need: ['name'], pos: true, rebuild: ['repeat'], title: ['Ingreso previsto', 'Ingreso previsto'],
    fields: [{ k: 'name', t: 'text', label: 'Nombre', ic: ['#22B573', 'pen'] }, { t: 'seg', k: 'repeat', opts: [['0', 'Una vez'], ['7', 'Semanal'], ['14', '14 días'], ['q', 'Quincenal'], ['m', 'Mensual']] },
      { k: 'acc', t: 'select', label: 'Cuenta', ic: ['#22B573', 'card'] }, { k: 'date', t: 'date', label: 'Fecha', ic: ['#FF9F0A', 'cal'] },
      { k: 'q1', t: 'num', label: 'Día del primer pago', ic: ['#22B573', 'n1'], show: (o) => o.repeat === 'q' }, { k: 'q2', t: 'num', label: 'Día del segundo pago', ic: ['#FF9F0A', 'n2'], show: (o) => o.repeat === 'q' }, { k: 'until', t: 'date', label: 'Termina el (opcional)', ic: ['#6D8BEA', 'cal'], show: (o) => !!o.repeat }],
    blank: () => ({ id: uid(), name: '', amount: 0, acc: data.accounts[0].id, date: iso(getToday()), repeat: 0, until: '' }) },
  job: { coll: 'jobs', hero: 'rate', heroLabel: (o) => (o && o.mode === 's' ? 'Ingreso mensual estimado' : 'Pago por hora'), curFrom: 'acc', need: ['name'], pos: true, rebuild: ['freq', 'sim', 'mode'], title: ['Nuevo trabajo', 'Trabajo'],
    fields: [{ t: 'seg', k: 'mode', get opts() { return jobModes(); }, show: () => jobModes().length > 1 }, { k: 'name', t: 'text', label: 'Nombre del trabajo', ic: ['#22B573', 'pen'] }, { t: 'seg', k: 'freq', opts: [['w', 'Semanal'], ['b', '14 días'], ['q', 'Quincenal'], ['m', 'Mensual']] },
      { k: 'q1', t: 'num', label: 'Día del primer pago', ic: ['#22B573', 'n1'], show: (o) => o.freq === 'q' }, { k: 'q2', t: 'num', label: 'Día del segundo pago', ic: ['#FF9F0A', 'n2'], show: (o) => o.freq === 'q' },
      { k: 'hours', t: 'num', label: 'Horas por semana', ic: ['#FF9F0A', '#'], show: (o) => o.mode !== 's' }, { k: 'tax', t: 'num', label: 'Impuestos retenidos (%)', ic: ['#FF6B5E', '%'], show: (o) => o.mode !== 's' },
      { k: 'acc', t: 'select', label: 'Cuenta donde cae el pago', ic: ['#22B573', 'card'] }, { k: 'start', t: 'date', label: 'Primer pago', ic: ['#FF9F0A', 'cal'] },
      { k: 'until', t: 'date', label: 'Último pago (opcional)', ic: ['#6D8BEA', 'cal'] },
      { t: 'seg', k: 'sim', opts: [['0', 'Real'], ['1', 'Solo simular']] }],
    blank: () => { const md = jobModes()[0][0]; return { id: uid(), mode: md, name: '', rate: 0, hours: 40, tax: 15, freq: md === 's' ? 'm' : 'b', acc: data.accounts[0].id, start: iso(addDays(getToday(), 7)), until: '', sim: 0 }; } },
  expense: { coll: 'expected_expense', hero: 'amount', heroLabel: () => 'Monto previsto', curFrom: 'acc', need: ['name'], pos: true, rebuild: ['repeat'], title: ['Gasto previsto', 'Gasto previsto'],
    fields: [{ k: 'name', t: 'text', label: 'Nombre', ic: ['#22B573', 'pen'] }, { t: 'seg', k: 'repeat', opts: [['0', 'Una vez'], ['7', 'Semanal'], ['14', '14 días'], ['q', 'Quincenal'], ['m', 'Mensual']] },
      { k: 'acc', t: 'select', label: 'Cuenta o tarjeta', ic: ['#22B573', 'card'] }, { k: 'cat', t: 'select', label: 'Categoría', ic: ['#B98AE6', '▦'] }, { k: 'date', t: 'date', label: 'Fecha', ic: ['#FF9F0A', 'cal'] },
      { k: 'q1', t: 'num', label: 'Día del primer pago', ic: ['#22B573', 'n1'], show: (o) => o.repeat === 'q' }, { k: 'q2', t: 'num', label: 'Día del segundo pago', ic: ['#FF9F0A', 'n2'], show: (o) => o.repeat === 'q' }, { k: 'until', t: 'date', label: 'Termina el (opcional)', ic: ['#6D8BEA', 'cal'], show: (o) => !!o.repeat }],
    blank: () => ({ id: uid(), name: '', amount: 0, acc: data.accounts[0].id, date: iso(getToday()), repeat: 0, until: '', cat: 'Otros' }) },
  sim: { coll: 'planned', hero: 'amount', heroLabel: (o) => (o && o.kind === 'pay' ? 'Pago simulado' : 'Gasto simulado'), need: ['name'], pos: true, rebuild: ['kind'], title: ['Simular gasto', 'Gasto simulado'],
    fields: [{ t: 'seg', k: 'kind', opts: [['out', 'Gasto'], ['pay', 'Pago de crédito']], show: () => data.cards.length > 0 },
      { k: 'name', t: 'text', label: 'Nombre', ic: ['#22B573', 'pen'] }, { k: 'date', t: 'date', label: 'Fecha de la compra', ic: ['#FF9F0A', 'cal'], show: (o) => o.kind !== 'pay' }, { k: 'date', t: 'date', label: 'Fecha del pago', ic: ['#FF9F0A', 'cal'], show: (o) => o.kind === 'pay' }, { k: 'until', t: 'date', label: 'Ver impacto hasta (opcional)', ic: ['#6D8BEA', 'cal'] },
      { k: 'card', t: 'select', label: 'Tarjeta o préstamo', ic: ['#B98AE6', 'card'], show: (o) => o.kind === 'pay' },
      { k: 'cat', t: 'select', label: 'Categoría al ejecutarlo', ic: ['#B98AE6', '▦'], show: (o) => o.kind !== 'pay' },
      { k: 'acc', t: 'select', get label() { return 'Cuenta al ejecutarlo (monto en ' + curP() + ')'; }, ic: ['#22B573', 'card'], show: (o) => o.kind !== 'pay' },
      { k: 'acc', t: 'select', get label() { return 'Pagar desde (monto en ' + curP() + ')'; }, ic: ['#22B573', 'card'], pay: true, show: (o) => o.kind === 'pay' }],
    blank: () => ({ id: uid(), name: '', amount: 0, date: iso(addDays(getToday(), 14)), until: '', on: true, kind: 'out', cat: 'Otros', acc: data.accounts[0].id }) },
  cardpay: { coll: 'expected_expense', hero: 'amount', heroLabel: () => 'Pago previsto', curFrom: 'acc', need: [], pos: true, rebuild: ['repeat'], title: ['Pago de crédito previsto', 'Pago de crédito previsto'],
    fields: [{ k: 'name', t: 'text', label: 'Nombre (opcional)', ic: ['#22B573', 'pen'] }, { t: 'seg', k: 'repeat', opts: [['0', 'Una vez'], ['7', 'Semanal'], ['14', '14 días'], ['q', 'Quincenal'], ['m', 'Mensual']] },
      { k: 'card', t: 'select', label: 'Tarjeta o préstamo', ic: ['#B98AE6', 'card'] }, { k: 'acc', t: 'select', label: 'Pagar desde', ic: ['#22B573', 'card'], pay: true }, { k: 'date', t: 'date', label: 'Fecha', ic: ['#FF9F0A', 'cal'] },
      { k: 'q1', t: 'num', label: 'Día del primer pago', ic: ['#22B573', 'n1'], show: (o) => o.repeat === 'q' }, { k: 'q2', t: 'num', label: 'Día del segundo pago', ic: ['#FF9F0A', 'n2'], show: (o) => o.repeat === 'q' }, { k: 'until', t: 'date', label: 'Termina el (opcional)', ic: ['#6D8BEA', 'cal'], show: (o) => !!o.repeat }],
    blank: () => ({ id: uid(), name: '', amount: 0, acc: data.accounts[0].id, card: (data.cards[0] || {}).id, date: iso(getToday()), repeat: 0, until: '', cat: 'Otros' }) },
  budget: { hero: 'limit', heroLabel: () => 'Límite mensual (opcional)', curFrom: 'bud', need: ['name'], title: ['Nueva categoría', 'Categoría'], style: 'cat',
    fields: [{ k: 'name', t: 'text', label: 'Nombre', ic: ['#22B573', 'pen'] }] },
  contrib: { hero: 'amount', heroLabel: () => 'Aporte', curFrom: 'sav', need: [], pos: true, title: ['Aportar', 'Aportar'],
    fields: [{ k: 'sav', t: 'select', label: 'A la meta', ic: ['#22B573', '◎'] }], blank: () => ({}) }
};
function formCur(F, o) {
  if (F.cur) return o[F.cur] || curP();
  if (F.curFrom === 'bud') return bsCurOf();
  if (F.curFrom === 'acc') return accOf(o.acc).cur;
  if (F.curFrom === 'sav') { const s = data.savings.find((x) => x.id === o.sav); return s ? s.cur : curP(); }
  return curP();
}
function fieldInput(fd, o) {
  const v = o[fd.k] == null ? '' : o[fd.k];
  if (fd.t === 'select') {
    if (fd.k === 'cat') return '<select class="sinput" data-f="cat">' + CAT_ORDER.map((x) => '<option value="' + x + '"' + (x === (v || 'Otros') ? ' selected' : '') + '>' + x + '</option>').join('') + '</select>';
    if (fd.k === 'card') return '<select class="sinput" data-f="card">' + byUse(data.cards).map((x) => '<option value="' + x.id + '"' + (x.id === v ? ' selected' : '') + '>' + esc(accLabel(x)) + '</option>').join('') + '</select>';
    if (fd.k === 'acc' && ui.form && ui.form.kind === 'sub') return '<select class="sinput" data-f="acc"><option value="">Sin especificar</option>' + acctOpts(v, true) + '</select>';
    if (fd.k === 'acc' && !fd.pay && ui.form && (ui.form.kind === 'sim' || ui.form.kind === 'expense')) return '<select class="sinput" data-f="acc">' + acctOpts(v, true) + '</select>';
    const list = fd.k === 'sav' ? data.savings : data.accounts;
    return '<select class="sinput" data-f="' + fd.k + '">' + list.map((x) => '<option value="' + x.id + '"' + (x.id === v ? ' selected' : '') + '>' + esc(x.name) + ' · ' + x.cur + '</option>').join('') + '</select>';
  }
  if (fd.t === 'last4') return '<input class="sinput" inputmode="numeric" maxlength="4" pattern="[0-9]*" autocomplete="off" data-f="last4" placeholder="1234" value="' + esc(v) + '">';
  if (fd.t === 'date') return '<input class="sinput" type="date" data-f="' + fd.k + '" value="' + esc(v) + '">';
  if (fd.t === 'num') return '<input class="sinput" inputmode="decimal" autocomplete="off" data-f="' + fd.k + '" data-t="num" placeholder="0" value="' + (v === 0 ? '' : v) + '">';
  return '<input class="sinput" autocomplete="off" data-f="' + fd.k + '" placeholder="Nombre" value="' + esc(v) + '">';
}
function styleKind(F) { return F.style === 'debt' ? 'debt' : F.style; }
function styleHTML(o, F) {
  const col = o.color || SWATCH[0], kind = styleKind(F);
  const autoGlyph = kind === 'debt' ? iconSVG('card', '#1C1C1E', 22) : '<b>Aa</b>';
  return '<div class="scard"><div class="srow" style="display:block"><span class="slabel">Color</span><div class="swatches">' + SWATCH.map((c) => '<button class="sw' + (c === col ? ' on' : '') + '" style="background:' + c + '" data-act="fpick:color:' + c + '" aria-label="Color"></button>').join('') +
    '<span class="sw swpick' + (SWATCH.indexOf(col) < 0 ? ' on' : '') + '" id="swc" aria-label="Color personalizado"><i id="swci"' + (SWATCH.indexOf(col) < 0 ? ' style="background:' + col + '"' : '') + '></i><input type="color" id="cpick" value="' + (/^#[0-9a-fA-F]{6}$/.test(col) ? col : '#22B573') + '"></span></div></div>' +
    '<div class="srow" style="display:block"><span class="slabel">Icono</span><div class="icons"><button class="ico' + (!o.icon || (!o.iconUser && bankOf(o)) ? ' on' : '') + '" data-act="fpick:icon:auto" aria-label="Automático">' + autoGlyph + '</button>' +
    Object.keys(ICONS).map((n) => '<button class="ico' + (o.icon === n && (o.iconUser || !bankOf(o)) ? ' on' : '') + '" data-act="fpick:icon:' + n + '" aria-label="' + n + '">' + iconSVG(n, '#1C1C1E', 22) + '</button>').join('') + '</div></div></div>';
}
function updPrev() {
  const f = ui.form, el = $('#fPrev'); if (!f || !el || !FORMS[f.kind].style) return;
  const o = f.obj; el.innerHTML = tileObj(o, o.color || SWATCH[0], FORMS[f.kind].style);
}
function formHTML() {
  const f = ui.form, F = FORMS[f.kind], o = f.obj, cur = formCur(F, o);
  const hv = f.kind === 'sim' ? Math.abs(o[F.hero] || 0) : (o[F.hero] || 0);
  let segs = '', rows = '';
  F.fields.forEach((fd) => {
    if (fd.show && !fd.show(o)) return;
    if (fd.t === 'seg' && fd.k === 'cur' && fd.opts.length < 2) { /* una sola moneda */ } else if (fd.t === 'seg') segs += segHTML('f_' + fd.k, fd.opts.map((op) => ({ k: op[0], label: op[1], act: 'fseg:' + fd.k + ':' + op[0] })), String(o[fd.k]), ';margin-bottom:10px');
    else rows += '<label class="srow">' + fico(fd.ic) + '<span class="grow"><span class="slabel">' + fd.label + '</span>' + fieldInput(fd, o) + '</span></label>';
  });
  return sheetHead(f.isNew ? F.title[0] : F.title[1], null, 'fsave') +
    '<div class="amtblock">' + (F.style ? '<div class="ptile" id="fPrev">' + tileObj(o, o.color || SWATCH[0], F.style) + '</div>' : '') + '<div class="amtlabel">' + esc(F.heroLabel(o)) + '</div><div class="amount"><span id="fSym">' + symOf(cur).trim() + '</span><input id="fHero" inputmode="decimal" placeholder="0" autocomplete="off" data-f="__hero" value="' + (hv || '') + '" style="width:' + amtW(hv, '0') + '"></div></div>' +
    segs + (rows ? '<div class="scard">' + rows + '</div>' : '') + (F.style ? styleHTML(o, F) : '') +
    '<button class="primary" data-act="fsave">Guardar</button>' +
    (f.kind === 'sim' && !f.isNew ? '<button class="secbtn" data-act="exec:' + f.id + '">' + (o.kind === 'pay' ? 'Ejecutar: registrar como pago real' : 'Ejecutar: registrar como gasto real') + '</button>' : '') +
    (f.isNew || f.kind === 'contrib' || (f.kind === 'budget' && f.id === 'Otros') ? '' : '<button class="delbtn" data-act="fdel">' + 'Eliminar' + '</button>');
}
function openForm(kind, id) {
  if (kind === 'expense' && id) { const xe = data.expected_expense.find((x) => x.id === id); if (xe && payOf(xe)) kind = 'cardpay'; }
  if (kind === 'cardpay' && !data.cards.length) { toast('Primero añade una tarjeta o préstamo'); return; }
  const F = FORMS[kind], isNew = !id || kind === 'contrib';
  let o;
  if (kind === 'budget') {
    const cc = id ? data.cats.find((x) => x.name === id) : null;
    o = cc ? { name: cc.name, orig: cc.name, limit: round2(fromUSD(budOf(viewSet())[id] || 0, bsCurOf())), color: cc.color, icon: cc.icon || '' } : { name: '', limit: 0, color: SWATCH[data.cats.length % SWATCH.length], icon: '' };
  }
  else if (kind === 'contrib') {
    if (!data.savings.length) { toast('Primero crea una meta de ahorro'); return; }
    o = { sav: data.savings[0].id, from: data.accounts[0].id, amount: 0 };
  } else if (id) { const src = data[F.coll].find((x) => x.id === id); if (!src) return; o = clone(src); }
  else o = F.blank();
  if (!o) return;
  if (isQ(o.repeat)) { const x = qDays(o.repeat); o.q1 = x[0]; o.q2 = x[1]; o.repeat = 'q'; }
  if (kind === 'job' && o.freq === 'q' && !(o.q1 >= 1)) { o.q1 = 15; o.q2 = 30; }
  if (kind === 'sim' && !o.kind) o.kind = o.card ? 'pay' : 'out';
  if (FORMS[kind].style && !o.color) { const i = id ? data[FORMS[kind].coll].findIndex((x) => x.id === id) : data[FORMS[kind].coll].length; o.color = SWATCH[Math.max(0, i) % 5]; }
  ui.confirmId = null;
  ui.form = { kind: kind, id: id, isNew: isNew, obj: o, confirmDel: false };
  showSheet(formHTML());
}
function syncForm() {
  const f = ui.form; if (!f) return;
  const F = FORMS[f.kind], o = f.obj;
  document.querySelectorAll('#sheet [data-f]').forEach((el) => {
    const k = el.getAttribute('data-f'), t = el.getAttribute('data-t');
    if (k === '__hero') { const v = parseFloat(String(el.value).replace(',', '.')) || 0; o[F.hero] = f.kind === 'sim' ? -Math.abs(v) : v; }
    else if (t === 'num') o[k] = parseFloat(String(el.value).replace(',', '.')) || 0;
    else o[k] = el.value;
  });
}
/* --- Editar un evento individual de Proyección (sin tocar la serie) --- */
const EV_FORM_TITLE = { income: 'serie del ingreso', expense: 'serie del gasto', cardpay: 'serie del pago', sub: 'suscripción', debt: 'tarjeta o préstamo' };
function openEv(key) {
  const ev = EVKEY[key]; if (!ev) return;
  if (ev.type === 'sim') { openForm(ev.form === 'job' ? 'job' : 'sim', ev.srcId); return; }
  const x = (data.ovr || {})[key] || {}, d0 = key.split(':').pop();
  ui.ev = { key: key, name: ev.name, cur: ev.cur, a0: Math.abs(ev.a0), d0: d0, form: ev.form, srcId: ev.srcId, amt: x.amt != null ? x.amt : Math.abs(ev.a0), date: x.date || d0, had: !!x.skip || x.amt != null || !!x.date, skipped: !!x.skip };
  showSheet(evHTML());
}
function evHTML() {
  const v = ui.ev, hv = v.amt;
  return sheetHead('Editar este evento', null, 'evsave') +
    '<div class="amtblock"><div class="amtlabel">' + esc(v.name) + '</div><div class="amount"><span>' + symOf(v.cur).trim() + '</span><input id="fHero" inputmode="decimal" placeholder="0" autocomplete="off" value="' + (hv || '') + '" style="width:' + amtW(hv) + '"></div></div>' +
    '<div class="scard"><label class="srow">' + fico(['#FF9F0A', 'cal']) + '<span class="grow"><span class="slabel">Fecha de este evento</span><input class="sinput" type="date" id="evDate" value="' + esc(v.date) + '"></span></label></div>' +
    '<div class="sub" style="font-size:13px;padding:0 8px 6px">Solo cambia este evento; el resto de la serie sigue igual.</div>' +
    '<button class="primary" data-act="evsave">Guardar</button>' +
    '<button class="secbtn" data-act="evcal">Añadir al calendario</button>' +
    (v.skipped ? '' : '<button class="secbtn" data-act="evskip">Omitir este evento</button>') +
    (v.had ? '<button class="secbtn" data-act="evreset">Restaurar el original</button>' : '') +
    (v.form && EV_FORM_TITLE[v.form] ? '<button class="secbtn" data-act="evseries">Editar toda la ' + (v.form === 'income' || v.form === 'expense' ? EV_FORM_TITLE[v.form] : EV_FORM_TITLE[v.form]) + '</button>' : '');
}
function evStore(entry) {
  data.ovr = data.ovr || {};
  if (entry) data.ovr[ui.ev.key] = entry; else delete data.ovr[ui.ev.key];
  ui.dirty++; persist(); closeSheet(); renderAll();
}
function evSave() {
  const v = ui.ev; if (!v) return;
  const amt = parseFloat(String($('#fHero').value).replace(',', '.')), date = ($('#evDate') || {}).value || v.d0;
  if (!(amt > 0)) { toast('Escribe un monto'); return; }
  if (date <= iso(getToday())) { toast('Elige una fecha futura'); return; }
  const e = {}; if (Math.abs(amt - v.a0) > 0.0049) e.amt = round2(amt); if (date !== v.d0) e.date = date;
  evStore(Object.keys(e).length ? e : null); toast('Evento actualizado');
}
/* «Añadir al calendario»: un archivo .ics de día completo (lo abre cualquier calendario) con el monto en las notas, un aviso a las 9:00 del día anterior
   y un enlace que, al tocarlo en el calendario, abre ese evento en Plata (?ev=…). El mismo evento siempre tiene el mismo UID: volver a añadirlo lo actualiza. */
function evIcs(key, name, date, notes) {
  const t = (s) => String(s).replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\r?\n/g, '\\n');
  const fold = (l) => { const o = []; while (l.length > 73) { o.push(l.slice(0, 73)); l = ' ' + l.slice(73); } o.push(l); return o.join('\r\n'); };
  const day = date.replace(/-/g, ''), next = iso(addDays(pd(date), 1)).replace(/-/g, '');
  const link = (/^https?:/.test(location.protocol) ? location.origin + location.pathname : 'https://web.plataapp.net/') + '?ev=' + encodeURIComponent(key);
  const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
  return ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Plata//Calendario//ES', 'CALSCALE:GREGORIAN', 'BEGIN:VEVENT', 'UID:plata-' + key.replace(/[^A-Za-z0-9:_-]/g, '') + '@plataapp.net',
    'DTSTAMP:' + stamp, 'DTSTART;VALUE=DATE:' + day, 'DTEND;VALUE=DATE:' + next, 'SUMMARY:' + t(name), 'DESCRIPTION:' + t(notes + '\n' + link), 'URL:' + link,
    'BEGIN:VALARM', 'ACTION:DISPLAY', 'DESCRIPTION:' + t(name), 'TRIGGER:-PT15H', 'END:VALARM', 'END:VEVENT', 'END:VCALENDAR'].map(fold).join('\r\n') + '\r\n';
}
function evCal() {
  const v = ui.ev; if (!v) return;
  const hero = parseFloat(String(($('#fHero') || {}).value).replace(',', '.')), amt = hero > 0 ? hero : v.amt, date = ($('#evDate') || {}).value || v.date;
  const file = new File([evIcs(v.key, v.name, date, trText('Monto') + ': ' + fmtC2(amt, v.cur))], 'plata-' + date + '.ics', { type: 'text/calendar' });
  const url = URL.createObjectURL(file), a = document.createElement('a');
  a.href = url; a.download = file.name; document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 4000);
  toast('Evento listo para tu calendario');
}
const jobModes = () => { const a = activeCurs(), m = []; if (a.indexOf('USD') >= 0) m.push(['h', 'EE.UU.']); if (a.indexOf('PEN') >= 0) m.push(['s', 'Perú']); if (m.length > 1 && curP() === 'PEN') m.reverse(); return m.length ? m : [['h', 'EE.UU.'], ['s', 'Perú']]; };
const jobOf = (e) => (e && e.job ? data.jobs.find((j) => j.id === e.job) : null);
const jobHrs = (j) => j.mode === 's' ? 0 : Math.round((j.hours || 0) * (JOB_MULT[j.freq] || 1) * 100) / 100;
const JOB_MULT = { w: 1, b: 2, q: 52 / 24, m: 52 / 12 };
const jobRep = (f, j) => (f === 'w' ? 7 : f === 'b' ? 14 : f === 'q' ? qMake(j && j.q1, j && j.q2) : 'm');
const jobNet = (j) => j.mode === 's' ? round2((j.rate || 0) * (j.freq === 'm' ? 1 : j.freq === 'b' || j.freq === 'q' ? 0.5 : 12 / 52)) : round2((j.rate || 0) * (j.hours || 0) * (1 - (j.tax || 0) / 100) * (JOB_MULT[j.freq] || 1));
const fmtHrs = (h) => (Math.round((h || 0) * 100) / 100).toLocaleString('en-US') + ' hrs';
const taxPct = (amt, rate, hrs) => { const g = (rate || 0) * (hrs || 0); return g > 0 ? Math.max(0, Math.min(100, Math.round((1 - amt / g) * 1000) / 10)) : 0; };
const amtHrs = (t, amtHTML) => (t.job && t.hrs > 0 ? '<span style="display:flex;flex-direction:column;align-items:flex-end;flex:none">' + amtHTML + '<span class="sub" style="font-size:12px;color:var(--mute)">' + fmtHrs(t.hrs) + '</span></span>' : amtHTML);
const jobTxs = () => data.transactions.filter((t) => t.job && t.amount > 0).sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : b.id - a.id));
function updTax() {
  const he = $('#cHrs') || $('#fHrs'), ae = $('#cHrs') ? $('#fHero') : $('#fAmount'), out = $('#taxOut'); if (!he || !ae || !out) return;
  const n = (el) => parseFloat(String(el.value).replace(',', '.')) || 0;
  out.textContent = taxPct(n(ae), parseFloat(he.dataset.rate) || 0, n(he)).toLocaleString('en-US') + '%';
}
function syncJobs() {
  const old = {}; data.expected_income.forEach((e) => { if (e.job) old[e.job] = e; });
  data.expected_income = data.expected_income.filter((e) => !e.job);
  data.jobs.forEach((j) => {
    if (j.sim) return;
    const o = old[j.id], keep = o && o.jstart === j.start && o.date > j.start && o.repeat === jobRep(j.freq, j);
    data.expected_income.push({ id: o ? o.id : uid(), job: j.id, jstart: j.start, name: j.name, amount: jobNet(j), acc: j.acc, date: keep ? o.date : j.start, repeat: jobRep(j.freq, j), until: j.until || '' });
  });
}
function formDone(msg) { ui.dirty++; persist(); closeSheet(); ui.form = null; renderAll(); toast(msg); }
function saveForm() {
  if (!ui.form) return;
  syncForm();
  const f = ui.form, F = FORMS[f.kind], o = f.obj;
  if (f.kind === 'budget') {
    const nm = String(o.name || '').replace(/[<>:]/g, '').trim();
    if (!nm) { toast('Escribe un nombre'); return; }
    if ([PAY, XFER, 'Ingreso', 'Pago'].some((r) => r.toLowerCase() === nm.toLowerCase())) { toast('Ese nombre está reservado'); return; }
    if (CAT_ORDER.some((x) => x === nm && x !== o.orig)) { toast('Ya existe esa categoría'); return; }
    if (o.orig) {
      const cc = data.cats.find((x) => x.name === o.orig); cc.name = nm; cc.color = o.color; cc.icon = o.icon || '';
      if (nm !== o.orig) {
        data.transactions.forEach((t) => { if (t.category === o.orig) t.category = nm; });
        data.planned.forEach((t) => { if (t.cat === o.orig) t.cat = nm; });
        data.expected_expense.forEach((t) => { if (t.cat === o.orig) t.cat = nm; });
        allBuds().forEach((b) => { if (b[o.orig] != null) { b[nm] = b[o.orig]; delete b[o.orig]; } }); if (ui.sheetCat === o.orig) ui.sheetCat = nm;
      }
    } else data.cats.push({ name: safeLabel(nm), color: SAFE_COLOR.test(o.color || '') ? o.color : '#8E8E93', icon: o.icon || '' });
    { const tb = budOf(viewSet()); if (o.limit > 0) tb[nm] = round2(usd(o.limit, bsCurOf())); else delete tb[nm]; }
    return formDone('Categoría guardada');
  }
  if (f.kind === 'cardpay') { const pc = data.cards.find((x) => x.id === o.card); if (!pc) { toast('Elige una tarjeta o préstamo'); return; } if (!String(o.name || '').trim()) o.name = 'Pago de ' + pc.name; }
  if (f.kind === 'sim') { if (o.kind === 'pay') { if (!data.cards.find((x) => x.id === o.card)) { toast('Elige una tarjeta o préstamo'); return; } } else { delete o.card; } }
  if (F.need.indexOf('name') >= 0 && !String(o.name || '').trim()) { toast('Escribe un nombre'); return; }
  if (F.pos && !(Math.abs(o[F.hero]) > 0)) { toast('Escribe un monto'); return; }
  if (f.kind === 'contrib') {
    /* la meta es una forma de contar parte de tu dinero: el saldo de tus cuentas no cambia */
    const s = data.savings.find((x) => x.id === o.sav);
    s.balance = round2(s.balance + o.amount); s.log = (s.log || []).concat([{ date: iso(getToday()), amount: o.amount }]);
    return formDone('Aporte registrado');
  }
  if (f.kind === 'income' || f.kind === 'expense' || f.kind === 'cardpay') {
    if (o.repeat === 'q') { const a = Math.round(o.q1), b = Math.round(o.q2); if (!(a >= 1 && a <= 31 && b >= 1 && b <= 31)) { toast('Escribe los días de pago (del 1 al 31)'); return; } o.repeat = qMake(a, b); o.date = iso(qNext(pd(o.date), o.repeat, true)); }
    else o.repeat = repN(o.repeat);
    delete o.q1; delete o.q2; delete o.snooze;
    if (!o.repeat) o.until = '';
    if (o.until && o.until < o.date) { toast('El fin debe ser posterior a la fecha'); return; }
  }
  if (f.kind === 'job') {
    if (o.mode === 's') { o.hours = 0; o.tax = 0; } else o.mode = 'h';
    o.freq = ['w', 'b', 'q', 'm'].indexOf(o.freq) >= 0 ? o.freq : 'b';
    if (o.freq === 'q') { const a = Math.round(o.q1), b = Math.round(o.q2); if (!(a >= 1 && a <= 31 && b >= 1 && b <= 31)) { toast('Escribe los días de pago (del 1 al 31)'); return; } const x = qDays('q' + a + ',' + b); o.q1 = x[0]; o.q2 = x[1]; o.start = iso(qNext(pd(o.start), jobRep('q', o), true)); } else { delete o.q1; delete o.q2; } o.sim = Number(o.sim) ? 1 : 0; o.tax = Math.max(0, Math.min(90, o.tax || 0)); o.hours = Math.max(0, Math.min(168, o.hours || 0));
    if (o.mode !== 's' && !(o.hours > 0)) { toast('Escribe las horas por semana'); return; }
    if (!o.start) { toast('Elige la fecha del primer pago'); return; }
    if (o.until && o.until < o.start) { toast('El fin debe ser posterior al inicio'); return; }
    o.name = String(o.name).trim();
    const ci = data.jobs.findIndex((x) => x.id === o.id); if (ci >= 0) data.jobs[ci] = o; else data.jobs.push(o);
    syncJobs(); return formDone('Trabajo guardado');
  }
  if (f.kind === 'account' || f.kind === 'debt') o.last4 = String(o.last4 || '').replace(/\D/g, '').slice(0, 4);
  if (f.kind === 'account' && o.type === 'cash') { o.last4 = ''; o.apy = 0; }
  if (f.kind === 'debt') {
    const dd = Math.round(o.due_day) || 0;
    if (dd < 0 || dd > 31) { toast('El día de pago va del 1 al 31'); return; }
    o.due_day = dd;
    if (o.apr < 0) { toast('El interés no puede ser negativo'); return; }
    if (o.kind === 'card' && o.limit > 0 && o.balance > o.limit) { toast('La deuda supera el límite de la tarjeta. Revisa el saldo o el límite.'); return; }
  }
  if (f.kind === 'sub') o.day = Math.max(1, Math.min(31, Math.round(o.day) || 1));
  if (f.kind === 'debt' && o.kind !== 'card') o.limit = 0;
  o.name = String(o.name).trim();
  const coll = data[F.coll], i = coll.findIndex((x) => x.id === o.id);
  if (i >= 0) coll[i] = o; else coll.push(o);
  if ((f.kind === 'account' || f.kind === 'debt') && f.origCur != null && o.cur !== f.origCur && f.linkF > 0 && f.linkF !== 1) scaleLinked(o.id, f.linkF, o.cur);
  formDone('Guardado');
}
/* lo que depende de una cuenta o tarjeta */
function delLinks(id) {
  const l = [], c = (n, k, w) => { if (n) l.push(n + ' ' + (n === 1 ? k : w)); };
  c(data.jobs.filter((j) => j.acc === id).length, 'trabajo', 'trabajos'); c(data.subs.filter((x) => x.acc === id).length, 'suscripción', 'suscripciones');
  c(data.expected_income.filter((e) => e.acc === id && !e.job).length + data.expected_expense.filter((e) => e.acc === id || e.card === id).length, 'movimiento previsto', 'movimientos previstos');
  c(data.cards.filter((k) => k.auto && k.auto.from === id).length, 'pago esperado', 'pagos esperados');
  return l;
}
function delCascade(id) {
  const gone = data.transactions.filter((t) => t.acc === id), pairs = new Set(gone.map((t) => t.pair).filter(Boolean));
  data.transactions = data.transactions.filter((t) => t.acc !== id);
  data.transactions.forEach((t) => { if (t.pair && pairs.has(t.pair)) delete t.pair; });
  const fb = (data.accounts[0] || {}).id || '';
  data.jobs.forEach((j) => { if (j.acc === id) j.acc = fb; });
  data.subs.forEach((x) => { if (x.acc === id) x.acc = ''; });
  data.expected_income.forEach((e) => { if (e.acc === id) e.acc = fb; });
  data.expected_expense = data.expected_expense.filter((e) => e.card !== id); data.expected_expense.forEach((e) => { if (e.acc === id) e.acc = fb; });
  data.planned = data.planned.filter((x) => x.card !== id); data.planned.forEach((x) => { if (x.acc === id) x.acc = fb; });
  data.cards.forEach((k) => { if (k.auto && k.auto.from === id) k.auto.from = ''; });
  syncJobs();
}
function deleteForm() {
  if (!ui.form) return;
  const f = ui.form, F = FORMS[f.kind];
  if (!f.confirmDel && (f.kind === 'account' || f.kind === 'debt')) {
    if (f.kind === 'account' && data.accounts.length < 2) { toast('Debes tener al menos una cuenta'); return; }
    const n = data.transactions.filter((t) => t.acc === f.id).length, links = delLinks(f.id);
    if (n || links.length) {
      askConfirm('Tiene datos ligados', 'Tiene ' + n + (n === 1 ? ' movimiento' : ' movimientos') + (links.length ? ' y está ligada a ' + links.join(', ') : '') + '. Si la eliminas, se borran esos movimientos. Para conservar el historial, mejor ocúltala.', [{ label: 'Ocultar (recomendado)', fn: () => { const ob = data[F.coll].find((x) => x.id === f.id); if (ob) ob.hid = true; formDone('Oculta del resumen'); } }, { label: 'Eliminar todo', dest: true, fn: () => { f.confirmDel = true; deleteForm(); } }]); return;
    }
  }
  if (!f.confirmDel) {
    const fut = { sub: 'Dejará de aparecer en tus pagos futuros. Tu historial no cambia.', income: 'Dejará de aparecer en tus ingresos futuros. Tu historial no cambia.', expense: 'Dejará de aparecer en tus gastos futuros. Tu historial no cambia.', job: 'Dejará de generar ingresos futuros. Tu historial no cambia.' }[f.kind];
    askConfirm('¿Eliminar esto?', fut || 'Esta acción no se puede deshacer.', [{ label: 'Eliminar', dest: true, fn: () => { f.confirmDel = true; deleteForm(); } }]); return;
  }
  if (f.kind === 'budget') { data.cats = data.cats.filter((x) => x.name !== f.id); allBuds().forEach((b) => { delete b[f.id]; }); }
  else if (f.kind === 'job') { data.jobs = data.jobs.filter((x) => x.id !== f.id); syncJobs(); }
  else {
    if (f.kind === 'account' && data.accounts.length < 2) { toast('Debes tener al menos una cuenta'); return; }
    data[F.coll] = data[F.coll].filter((x) => x.id !== f.id);
    if (f.kind === 'account' || f.kind === 'debt') delCascade(f.id);
  }
  formDone('Eliminado');
}

/* --- Ejecutar un gasto simulado: pasa a ser un movimiento real --- */
function execSim(id) {
  if (ui.form && ui.form.kind === 'sim') { syncForm(); const i = data.planned.findIndex((x) => x.id === id); if (i >= 0) data.planned[i] = ui.form.obj; }
  const pl = data.planned.find((x) => x.id === id); if (!pl) return;
  const pcard = pl.kind === 'pay' ? data.cards.find((x) => x.id === pl.card) : null;
  if (pcard) {
    const amtC = round2(fromUSD(Math.abs(pl.amount), pcard.cur)); if (!(amtC > 0)) { toast('Escribe un monto'); return; }
    registerPay(pcard, amtC, iso(getToday()), pl.acc, 'Pago de ' + pcard.name);
    data.planned = data.planned.filter((x) => x.id !== id);
    ui.dirty++; persist(); closeSheet(); ui.form = null; renderAll(); toast('Pago registrado'); return;
  }
  const acc = accOf(pl.acc), amt = round2(fromUSD(Math.abs(pl.amount), acc.cur));
  if (!(amt > 0)) { toast('Escribe un monto'); return; }
  data.transactions.push({ id: nextTxId(), date: iso(getToday()), amount: -amt, category: CAT_ORDER.indexOf(pl.cat) >= 0 ? pl.cat : 'Otros', note: pl.name.replace(/\s*\(simulado\)/i, ''), acc: acc.id });
  applyTo(acc, -amt);
  data.planned = data.planned.filter((x) => x.id !== id);
  ui.dirty++; persist(); closeSheet(); ui.form = null; renderAll(); toast('Gasto registrado');
}

/* --- Próximo ingreso / gasto: confirmar o adelantar --- */
function openNextItem(k, id) { openItem(k === 'out' ? 'expense' : 'income', id); }

/* --- Confirmar ingresos previstos --- */
function confirmHTML() {
  let list = pendingItems(); if (ui.confirmPick) { if (ui.confirmPick.k === 'pay') { const pc = data.cards.find((x) => x.id === ui.confirmPick.id); list = pc && pc.auto ? [{ k: 'pay', e: { id: pc.id, name: pc.name, date: pc.auto.next, card: pc } }] : []; } else { const pe = data[ui.confirmPick.k === 'out' ? 'expected_expense' : 'expected_income'].find((x) => x.id === ui.confirmPick.id); list = pe ? [{ k: ui.confirmPick.k, e: pe }] : []; } }
  if (!list.length) return null;
  const e = list[0].k === 'pay' ? list[0].e : Object.assign({}, list[0].e, { amount: effItem(list[0].k === 'out' ? 'exp' : 'in', list[0].e).amount }), out = list[0].k === 'out', isP = list[0].k === 'pay', cur = isP ? e.card.cur : accOf(e.acc).cur, late = Math.round((getToday() - pd(e.date)) / 864e5);
  ui.confirmId = e.id; ui.confirmKind = list[0].k;
  const when = late < 0 ? 'para ' + dlabel(pd(e.date)) : late === 0 ? 'hoy' : late === 1 ? 'ayer' : 'hace ' + late + ' días';
  if (isP) {
    const c = e.card;
    return '<div id="cwrap">' + sheetHead(c.kind === 'loan' ? '¿Pagaste tu préstamo?' : '¿Pagaste tu tarjeta?', 'cclose', 'cok') +
      '<div class="amtblock"><div class="amtlabel">' + esc(c.name) + ' · día de pago ' + when + (list.length > 1 ? ' · 1 de ' + list.length : '') + '</div>' +
      '<div class="amount"><span id="fSym">' + symOf(cur).trim() + '</span><input id="fHero" inputmode="decimal" autocomplete="off" placeholder="' + (decOf(cur) ? '0.00' : '0') + '" value="' + (apFinal(c) ? c.balance.toFixed(decOf(cur) ? 2 : 0) : '') + '" style="width:' + amtW(apFinal(c) ? c.balance.toFixed(decOf(cur) ? 2 : 0) : '', decOf(cur) ? '0.00' : '0') + '"></div>' +
      '<div class="deltachip">' + (apFinal(c) ? 'Última cuota · es lo que te queda' : '¿Cuánto pagaste?') + '</div></div>' +
      '<div class="scard"><label class="srow">' + fico(['#22B573', 'card']) + '<span class="grow"><span class="slabel">Pagar desde</span><select class="sinput" id="cFrom"><option value="">Sin descontar de una cuenta</option>' + byUse(data.accounts).map((a) => '<option value="' + a.id + '"' + (a.id === c.auto.from ? ' selected' : '') + '>' + esc(accLabel(a)) + '</option>').join('') + '</select></span></label></div>' +
      '<button class="primary" data-act="cok">Confirmar</button><button class="secbtn" data-act="' + (ui.confirmPick ? 'cclose' : 'clater') + '">' + (ui.confirmPick ? 'Cancelar' : 'Aún no pagué') + '</button></div>';
  }
  const pcd = out ? payOf(e) : null;
  return '<div id="cwrap">' + sheetHead(pcd ? (pcd.kind === 'loan' ? '¿Pagaste tu préstamo?' : '¿Pagaste tu tarjeta?') : out ? '¿Se cobró este gasto?' : '¿Llegó tu ingreso?', 'cclose', 'cok') +
    '<div class="amtblock"><div class="amtlabel">' + esc(e.name) + ' · ' + (out ? 'previsto ' : 'esperado ') + when + (list.length > 1 ? ' · 1 de ' + list.length : '') + '</div>' +
    '<div class="amount"><span id="fSym">' + symOf(cur).trim() + '</span><input id="fHero" inputmode="decimal" autocomplete="off" value="' + e.amount + '" style="width:' + amtW(e.amount) + '"></div>' +
    '<div class="deltachip" id="cDelta">Igual a lo previsto</div></div>' +
    (jobOf(e) && jobOf(e).mode !== 's' ? '<div class="scard"><label class="srow">' + fico(['#FF9F0A', '#']) + '<span class="grow"><span class="slabel">Horas trabajadas</span><input class="sinput" id="cHrs" inputmode="decimal" autocomplete="off" data-rate="' + jobOf(e).rate + '" value="' + jobHrs(jobOf(e)) + '"></span></label><div class="srow">' + fico(['#FF6B5E', '%']) + '<span class="grow"><span class="slabel">Impuestos descontados</span><div id="taxOut" style="font-size:17px">' + taxPct(e.amount, jobOf(e).rate, jobHrs(jobOf(e))) + '%</div></span></div></div>' : '') +
    '<div class="scard"><div class="srow"><span class="grow"><span class="slabel">Previsto</span><div style="font-size:17px">' + fmtC2(e.amount, cur) + '</div></span><span class="slabel">' + (e.repeat ? 'Se repite ' + repLabel(e.repeat) + untilTxt(e) : 'Una sola vez') + '</span></div></div>' +
    '<button class="primary" data-act="cok">Confirmar</button><button class="secbtn" data-act="' + (ui.confirmPick ? 'cclose' : 'clater') + '">' + (ui.confirmPick ? 'Cancelar' : pcd ? 'Aún no pagué' : out ? 'Aún no se cobró' : 'Aún no llegó') + '</button></div>';
}
function confColl() { return ui.confirmKind === 'pay' ? 'cards' : ui.confirmKind === 'out' ? 'expected_expense' : 'expected_income'; }
function updConfirmDelta() {
  const e = data[confColl()].find((x) => x.id === ui.confirmId), el = $('#cDelta'); if (!e || !el) return;
  const v = parseFloat(String($('#fHero').value).replace(',', '.')) || 0, d = round2(v - effItem(ui.confirmKind === 'out' ? 'exp' : 'in', e).amount), cur = accOf(e.acc).cur, out = ui.confirmKind === 'out';
  if (Math.abs(d) < 0.005) { el.textContent = 'Igual a lo previsto'; el.className = 'deltachip'; }
  else { el.textContent = (d > 0 ? '+' : '−') + fmtC2(d, cur) + ' vs. previsto'; el.className = 'deltachip ' + ((d > 0) !== out ? 'up' : 'neg'); }
}
function openConfirm() { const h = confirmHTML(); if (h) { ui.form = null; showSheet(h); } }
function checkPending() { if (ui.skipPending || $('#sheet').classList.contains('show')) return; if (pendingItems().length) openConfirm(); }
function doConfirmPay(ok) {
  const card = data.cards.find((x) => x.id === ui.confirmId); if (!card || !card.auto) return;
  const today = iso(getToday());
  const tail = () => {
    ui.dirty++; persist(); renderAll(); ui.confirmPick = null;
    const h = confirmHTML();
    if (h) { $('#sheet').innerHTML = h; swapIn($('#cwrap')); } else closeSheet();
  };
  if (ok) {
    const amt0 = parseFloat(String(($('#fHero') || {}).value).replace(',', '.'));
    if (!(amt0 > 0)) { toast('Escribe cuánto pagaste'); return; }
    const from = ($('#cFrom') || {}).value || '';
    payGuard(card, amt0, (amt) => {
      const pdt = card.auto.next <= today ? card.auto.next : today, pnote = (() => { const left = round2(card.balance - amt); return 'Pago de ' + card.name + (card.payment > 0 && left <= 0.005 ? ' · final' : ''); })();
      registerPay(card, amt, pdt, from, pnote);
      if (card.balance > 0.005) { card.auto.from = from; card.auto.next = dueAfter(card.due_day, today); delete card.auto.snooze; toast(negWarn([from]) || 'Pago registrado'); }
      else { delete card.auto; toast(negWarn([from]) || 'Deuda pagada · pago esperado desactivado'); }
      tail();
    });
    return;
  }
  card.auto.snooze = iso(addDays(getToday(), 1)); toast('Te pregunto mañana');
  tail();
}
function doConfirm(ok) {
  if (ui.confirmKind === 'pay') { doConfirmPay(ok); return; }
  const coll = confColl(), out = ui.confirmKind === 'out', e = data[coll].find((x) => x.id === ui.confirmId); if (!e) return;
  if (ok) {
    const amt = parseFloat(String($('#fHero').value).replace(',', '.'));
    if (!(amt > 0)) { toast('Escribe el monto'); return; }
    const acc = accOf(e.acc);
    const pcd = out ? payOf(e) : null;
    if (pcd) {
      registerPay(pcd, round2(fromUSD(usd(amt, acc.cur), pcd.cur)), e.date <= iso(getToday()) ? e.date : iso(getToday()), acc.id, e.name || 'Pago de ' + pcd.name);
    } else if (out) {
      data.transactions.push({ id: nextTxId(), date: e.date <= iso(getToday()) ? e.date : iso(getToday()), amount: -amt, category: CAT_ORDER.indexOf(e.cat) >= 0 ? e.cat : 'Otros', note: e.name, acc: acc.id });
      applyTo(acc, -amt);
    } else {
      const jb = jobOf(e), tx = { id: nextTxId(), date: e.date <= iso(getToday()) ? e.date : iso(getToday()), amount: amt, category: 'Ingreso', note: e.name, acc: acc.id, est: effItem('in', e).amount };
      if (jb) { tx.job = jb.id; if (jb.mode !== 's') { tx.rate = jb.rate; tx.hrs = parseFloat(String(($('#cHrs') || {}).value).replace(',', '.')) || jobHrs(jb); } }
      data.transactions.push(tx);
      acc.balance = round2(acc.balance + amt);
    }
    if (e.repeat) { e.date = iso(nextRep(pd(e.date), e.repeat)); delete e.snooze; if (e.until && e.date > e.until) data[coll] = data[coll].filter((x) => x !== e); }
    else data[coll] = data[coll].filter((x) => x !== e);
    toast(pcd ? 'Pago registrado' : out ? 'Gasto confirmado' : 'Ingreso confirmado');
  } else { e.snooze = iso(addDays(getToday(), 1)); toast('Te pregunto mañana'); }
  ui.dirty++; persist(); renderAll(); ui.confirmPick = null;
  const h = confirmHTML();
  if (h) { $('#sheet').innerHTML = h; swapIn($('#cwrap')); } else closeSheet();
}

/* --- Simulador de pago extra de deuda --- */
function simHTML() {
  return '<div id="simwrap">' + sheetHead('Simular pago extra') +
    '<div class="amtblock"><div class="amtlabel">Pago extra cada mes</div><div class="amount"><span id="sExtra">+' + fmt(ui.extra) + '</span></div></div>' +
    '<div class="scard" style="padding:6px 16px"><input type="range" id="extraRange" min="0" max="' + (600 * curK()) + '" step="' + (10 * curK()) + '" value="' + ui.extra + '" style="--f:' + (ui.extra / (600 * curK())) + '" aria-label="Pago extra mensual"></div>' +
    '<div class="scard" id="simOut"></div><div class="sub" style="font-size:13px;text-align:center;padding:0 8px 4px">El extra se aplica primero a la deuda con mayor interés.</div></div>';
}
function updSim() {
  const c = calc(), base = payoff(0), me = payoff(ui.extra);
  $('#sExtra').textContent = '+' + fmt(ui.extra);
  const rg = $('#extraRange'); if (rg) rg.style.setProperty('--f', String(ui.extra / (600 * curK())));
  const t = (m) => { const y = Math.floor(m / 12), r = m % 12; return (y ? plural(y, 'año', 'años') + (r ? ' y ' : '') : '') + (r || !y ? plural(r, 'mes', 'meses') : ''); };
  const row = (a, b) => '<div class="srow"><span class="grow" style="font-size:16px">' + a + '</span><b style="font-size:16px">' + b + '</b></div>';
  let h;
  if (!me.ok) h = row('Libre de deuda', 'No se liquida') + row('Sugerencia', 'Sube el pago');
  else {
    h = row('Libre de deuda', monthYear(addMonths(c.today, me.months))) + row('Tiempo', t(me.months)) + row('Intereses totales', fmt(me.interest));
    if (ui.extra > 0 && base.ok) h += row('Ahorras en intereses', '<span style="color:var(--gt)">' + fmt(base.interest - me.interest) + '</span>') + row('Te libras antes', '<span style="color:var(--gt)">' + t(Math.max(0, base.months - me.months)) + '</span>');
  }
  $('#simOut').innerHTML = h;
}
function openSim() { ui.form = null; ui.confirmId = null; showSheet(simHTML()); updSim(); }

