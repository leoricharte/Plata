/* ---------- Pago automático de tarjetas ---------- */
const apOK = (k) => !!k && k.due_day > 0;
/* Última cuota: lo que queda por pagar ya no alcanza (o iguala) la cuota normal */
const apFinal = (k) => !!k && k.payment > 0 && k.balance > 0.005 && k.balance <= k.payment + 0.005;
function registerPay(card, amt, d, fromId, note) {
  const from = fromId ? data.accounts.find((x) => x.id === fromId) : null, pid = uid();
  data.transactions.push({ id: nextTxId(), date: d, amount: amt, category: PAY, note: note, acc: card.id, pair: from ? pid : undefined });
  applyTo(card, amt);
  if (from) { const a2 = round2(fromUSD(usd(amt, card.cur), from.cur)); data.transactions.push({ id: nextTxId(), date: d, amount: -a2, category: PAY, note: 'Pago a ' + card.name, acc: from.id, pair: pid }); applyTo(from, -a2); }
}
function dueAfter(day, afterIso) {
  const a = pd(afterIso);
  for (let m = 0; m < 3; m++) {
    const base = new Date(a.getFullYear(), a.getMonth() + m, 1), last = new Date(base.getFullYear(), base.getMonth() + 1, 0).getDate(), d = new Date(base.getFullYear(), base.getMonth(), Math.min(day, last));
    if (d > a) return iso(d);
  }
  return afterIso;
}
function apRowHTML() {
  const k = ui.sheetType === 'pay' ? data.cards.find((x) => x.id === ui.sheetAcc) : null; if (!k) return '';
  const ok = apOK(k);
  return '<div class="row" style="padding:12px 16px"><span class="grow"><span style="font-size:17px;display:block">Pago esperado</span><span class="sub" style="font-size:13px">' + (ok ? 'El día ' + k.due_day + ' de cada mes te preguntamos cuánto pagaste.' : 'Disponible si la tarjeta tiene día de pago.') + '</span></span>' + swHTML(!!ui.sheetAuto && ok, 'apsw', !ok) + '</div>';
}
/* Avisos suaves: no bloquean (a veces se anota desordenado), solo avisan */
const negWarn = (ids) => { const l = [...new Set(ids.filter(Boolean))].map(accOf).filter((a) => a && !isCredit(a) && a.balance < -0.005); return l.length ? 'Ojo: ' + l.map((a) => a.name).join(' y ') + (l.length > 1 ? ' quedaron' : ' quedó') + ' en negativo. Si falta un ingreso, añádelo.' : ''; };
const futureMsg = 'Para fechas futuras usa los movimientos previstos.';
/* Pagar más de lo que se debe: se pregunta, porque los intereses reales pueden superar lo anotado */
function payGuard(card, amt, go) {
  const owed = Math.max(0, card.balance);
  if (amt <= owed + 0.005) { go(amt); return; }
  const opts = owed > 0.005 ? [{ label: 'Pagar solo ' + fmtC2(owed, card.cur), fn: () => go(owed) }, { label: 'Registrar el pago completo', fn: () => go(amt) }] : [{ label: 'Registrar de todos modos', fn: () => go(amt) }];
  askConfirm('Estás pagando más de lo que debes', owed > 0.005 ? 'En Plata debes ' + fmtC2(owed, card.cur) + ' en ' + card.name + ' y estás pagando ' + fmtC2(amt, card.cur) + '. Si es por intereses, registra el pago completo.' : card.name + ' ya está en 0. ¿Seguro que quieres registrar este pago?', opts);
}
function submitSheet() {
  const v = readSheet();
  const amt = parseFloat(String(v.amount).replace(',', '.'));
  if (!(amt > 0)) { toast('Escribe un monto'); return; }
  if ((v.date || iso(getToday())) > iso(getToday())) { toast(futureMsg); return; }
  if (ui.sheetType === 'pay') {
    const card = data.cards.find((x) => x.id === v.acc); if (!card) { toast('Elige una tarjeta o préstamo'); return; }
    const d = v.date || iso(getToday());
    payGuard(card, amt, (amt) => {
      const nBefore = data.transactions.length;
      registerPay(card, amt, d, v.from, v.note.trim() || ('Pago de ' + card.name + (card.payment > 0 && round2(card.balance - amt) <= 0.005 ? ' · final' : '')));
      const auto = ui.sheetAuto && apOK(card) && round2(card.balance) > 0.005;
      if (auto) card.auto = { from: v.from || '', next: dueAfter(card.due_day, d) };
      ui.dirty++; persist(); closeSheet(); renderAll(); toast(negWarn([v.from]) || (auto ? 'Pago registrado · pago esperado activado' : 'Pago registrado'));
      const np = data.transactions[nBefore]; if (np) setTimeout(() => smartCheck(np), 700);
    });
    return;
  }
  const out = ui.sheetType === 'out', cat = out ? ui.sheetCat : 'Ingreso', acc = accOf(v.acc);
  if (!out && isCredit(acc)) { toast('Un ingreso no va en una tarjeta. Para pagarla usa Pago.'); return; }
  data.transactions.push({ id: nextTxId(), date: v.date || iso(getToday()), amount: out ? -amt : amt, category: cat, note: v.note.trim() || (out ? cat : 'Ingreso'), acc: acc.id });
  applyTo(acc, out ? -amt : amt);
  ui.dirty++; persist(); closeSheet(); renderAll(); toast(negWarn([acc.id]) || 'Movimiento añadido');
  const nt = data.transactions[data.transactions.length - 1]; setTimeout(() => smartCheck(nt), 700);
}
/* --- Revisión: recorre todo lo guardado (también lo importado) y propone correcciones. Nada cambia hasta que la persona lo acepte; lo descartado no vuelve a salir. --- */
const RV_TXT = {
  xfer: ['Posible transferencia entre tus cuentas', 'Salió de una cuenta y entró a otra por casi el mismo monto. Como transferencia no cuenta como gasto ni ingreso.', 'Convertir en transferencia'],
  pay2: ['Posible pago de tarjeta', 'Una tarjeta recibió un pago y una cuenta tuvo un gasto parecido: es el mismo pago. Júntalos para que no cuente doble.', 'Juntar como un pago'],
  card: ['Posible pago de tarjeta', 'Este gasto coincide con la cuota o el saldo de una de tus tarjetas.', 'Registrar como pago'],
  dup: ['Posible movimiento repetido', 'Uno lo anotaste a mano y el otro vino del banco, con el mismo monto y casi el mismo día. Borra el que anotaste a mano.', 'Borrar el anotado a mano'],
  big: ['Monto muy alto para su categoría', 'Es mucho más que lo habitual en esta categoría. ¿Lo escribiste bien?', 'Editar'],
  own: ['Plata que solo cambió de lugar', 'Van o vienen de otra cuenta tuya que no está en Plata. Marcados como transferencia, dejan de contar como gasto o ingreso.', 'Marcar como transferencia'],
  rec_job: ['Posible trabajo', 'Llega de la misma fuente, con ritmo regular y monto parecido. Como trabajo, Plata prevé tu próximo pago.', 'Crear trabajo'],
  rec_sub: ['Posible suscripción', 'Se cobra con el mismo ritmo y monto, sumando todas tus cuentas. Como suscripción, Plata la prevé cada mes.', 'Crear suscripción'],
  rec_fix: ['Posible gasto fijo', 'Se repite con ritmo regular. Como gasto fijo, Plata lo prevé cada vez.', 'Crear gasto fijo'],
  gap: ['Posible estado de cuenta faltante', 'Puede faltar un estado, o la cuenta ya tenía saldo antes del primero que importaste.', 'Importar un estado']
};
const RV_OWN = [
  { id: 'secured', label: 'Moved to / from Secured Deposit Account', re: /moved (to|from) secured deposit/i },
  { id: 'savings', label: 'Transfer to / from Savings', re: /transfer (to|from) (my )?(chime )?savings|online banking transfer (to|from) sav|round up to savings/i },
  { id: 'internal', label: 'Transfer from x… to x…', re: /transfer from x?\d+ to x?\d+/i },
  { id: 'visa', label: 'Transfer to / from your Visa', re: /transfer (to|from) (apple pay )?visa \d{4}/i }
];
let revUndo = null;
let rvCache = null;
function revScan() {
  if (rvCache && rvCache.d === ui.dirty && rvCache.n === data.transactions.length && rvCache.o === (data.settings.rv_off || []).length) return rvCache.res;
  const T = data.transactions, skip = new Set(data.settings.rv_off || []), used = new Set(), res = [];
  const U = (x) => usd(Math.abs(x.amount), accOf(x.acc).cur), dd = (a, b) => Math.abs((pd(a) - pd(b)) / 864e5), tol = (a, b) => Math.abs(U(a) - U(b)) <= Math.max(0.5, Math.max(U(a), U(b)) * 0.03);
  const isDeb = (x) => data.accounts.some((a) => a.id === x.acc), isCrd = (x) => data.cards.some((k) => k.id === x.acc);
  const byDate = {}; T.forEach((x) => { (byDate[x.date] = byDate[x.date] || []).push(x); });
  const near = (x) => { const o = []; for (let k = -5; k <= 5; k++) { const d = new Date(pd(x.date)); d.setDate(d.getDate() + k); (byDate[iso(d)] || []).forEach((y) => { if (y !== x) o.push(y); }); } return o; };
  const pick = (cands) => { cands.sort((a, b) => a.score - b.score); cands.forEach((c) => { if (c.txs.some((x) => used.has(x.id))) return; c.txs.forEach((x) => used.add(x.id)); res.push(c); }); };
  const loose = (x) => !x.pair && !x.job, cands = [];
  const mk = (kind, txs, score, extra) => { const k = kind + ':' + txs.map((x) => x.id).join('+'); return skip.has(k) ? null : Object.assign({ kind: kind, k: k, txs: txs, score: score }, extra || {}); };
  const push = (c) => { if (c) cands.push(c); };
  T.forEach((x) => {
    if (!loose(x)) return;
    near(x).forEach((y) => {
      if (!loose(y)) return;
      const g = dd(x.date, y.date), ex = Math.abs(U(x) - U(y)) < 0.01, sc = g * 1000 + Math.abs(U(x) - U(y)), same = x.id < y.id;
      /* pago de tarjeta anotado suelto + gasto de una cuenta por lo mismo */
      if (x.amount > 0 && isCrd(x) && (x.category === PAY || !isPay(x)) && y.amount < 0 && isDeb(y) && !isPay(y) && g <= 2 && tol(x, y)) push(mk('pay2', [y, x], sc - 1));
      /* gasto + ingreso en cuentas distintas: una transferencia */
      else if (same && !isPay(x) && !isPay(y) && isDeb(x) && isDeb(y) && x.acc !== y.acc && (x.amount < 0) !== (y.amount < 0) && ((g <= 2 && tol(x, y)) || (g <= 5 && ex))) { const o = x.amount < 0 ? x : y, i = x.amount < 0 ? y : x; push(mk('xfer', [o, i], sc, { hi: g <= 1 && ex, far: g > 2 })); }
      /* anotado a mano + importado: el mismo movimiento dos veces */
      else if (same && g <= 2 && x.acc === y.acc && !x.imp !== !y.imp && x.amount === y.amount && !isPay(x) && !isPay(y)) { const man = x.imp ? y : x, imp = x.imp ? x : y; push(mk('dup', [man, imp], sc - 500)); }
    });
  });
  pick(cands);
  /* movimientos de/hacia otra cuenta tuya que no está en Plata (cuenta Secured, ahorros, tu Visa…): se marcan juntos como transferencia, sin pareja */
  RV_OWN.forEach((g) => {
    const m = T.filter((x) => loose(x) && !used.has(x.id) && !isPay(x) && isDeb(x) && g.re.test(String(x.note || ''))), k = 'own:' + g.id;
    if (m.length < 2 || skip.has(k)) return;
    m.forEach((x) => used.add(x.id));
    const one = m.every((x) => accOf(x.acc).cur === accOf(m[0].acc).cur), cur = accOf(m[0].acc).cur;
    res.push({ kind: 'own', k: k, txs: m, score: -1, label: g.label, cur: one ? cur : '', out: one ? sum(m.filter((x) => x.amount < 0), (x) => -x.amount) : null, inn: one ? sum(m.filter((x) => x.amount > 0), (x) => x.amount) : null });
  });
  /* gasto suelto que coincide con la cuota o el saldo de una tarjeta */
  const lim = iso(addDays(getToday(), -120));
  T.forEach((t) => {
    if (used.has(t.id) || !loose(t) || t.amount >= 0 || isPay(t) || !isDeb(t) || t.date < lim) return;
    const card = data.cards.find((k) => k.balance > 0.005 && [k.payment, k.balance].some((v) => v > 0 && Math.abs(usd(v, k.cur) - U(t)) <= Math.max(0.5, U(t) * 0.01)));
    if (card) { const c = mk('card', [t], 5000, { card: card.id }); if (c) { used.add(t.id); res.push(c); } }
  });
  /* monto muy por encima de lo habitual en su categoría */
  const cat = {}; T.forEach((x) => { if (x.amount < 0 && !isPay(x) && !x.job) (cat[x.category] = cat[x.category] || []).push(Math.abs(x.amount)); });
  Object.keys(cat).forEach((k) => cat[k].sort((a, b) => a - b));
  T.forEach((t) => {
    if (used.has(t.id) || t.amount >= 0 || isPay(t) || t.job || t.date < lim) return;
    const v = cat[t.category] || []; if (v.length < 6) return;
    const med = v[Math.floor(v.length / 2)];
    const rep = T.some((x) => x !== t && x.category === t.category && Math.abs(Math.abs(x.amount) - Math.abs(t.amount)) <= Math.abs(t.amount) * 0.02);   /* un monto que se repite (alquiler, cuota) no es un error de tipeo */
    if (med > 0 && !rep && Math.abs(t.amount) >= med * 10) { const c = mk('big', [t], 9000, { med: med }); if (c) res.push(c); }
  });
  /* trabajos, suscripciones y gastos que se repiten */
  recFind(T, used).forEach((c) => { if (!skip.has(c.k)) res.push(c); });
  /* estados que faltan: meses sin movimientos entre otros con datos, o el saldo no coincide con la suma de lo importado (solo cuentas hechas de importaciones) */
  data.accounts.forEach((a) => {
    const tx = T.filter((x) => x.acc === a.id); if (tx.length < 20 || !tx.every((x) => x.imp)) return;
    const have = {}; tx.forEach((x) => { have[String(x.date).slice(0, 7)] = 1; });
    const ks = Object.keys(have).sort(), miss = []; let y = +ks[0].slice(0, 4), m = +ks[0].slice(5, 7); const ey = +ks[ks.length - 1].slice(0, 4), em = +ks[ks.length - 1].slice(5, 7);
    while (y < ey || (y === ey && m <= em)) { const q = y + '-' + String(m).padStart(2, '0'); if (!have[q]) miss.push(q); if (++m > 12) { m = 1; y++; } }
    const diff = round2(a.balance - sum(tx, (x) => x.amount));
    if (!miss.length && Math.abs(diff) < 1) return;
    const k = 'gap:' + a.id + ':' + miss.join(',') + ':' + Math.round(diff); if (skip.has(k)) return;
    res.push({ kind: 'gap', k: k, txs: [], acc: a.id, miss: miss, diff: Math.abs(diff) >= 1 ? diff : 0, score: 8500 });
  });
  res.sort((a, b) => a.score - b.score);
  rvCache = { d: ui.dirty, n: T.length, o: (data.settings.rv_off || []).length, res: res };
  return res;
}
