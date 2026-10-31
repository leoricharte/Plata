/* ---------- Detalle de movimiento ---------- */
const txById = (id) => data.transactions.find((t) => String(t.id) === String(id));
function txBackNav() {
  const b = ui.txBack || {}; ui.txId = null; ui.txDel = false;
  if (b.tab === 'cuenta') { ui.acctId = b.acctId; ui.prevTab = b.prev; if (b.month) { ui.itemKind = 'month'; ui.itemId = 'x'; } renderCuenta(); }
  else { ui.prevTab = b.prev; setTab(b.tab || 'resumen'); }
}
function openTx(id) {
  ui.txBack = { tab: ui.tab, acctId: ui.acctId, prev: ui.prevTab, month: ui.tab === 'cuenta' && ui.itemKind === 'month' && ui.itemId != null }; ui.itemId = null;
  ui.prevTab = ui.tab === 'cuenta' ? ui.prevTab : ui.tab; ui.txId = id; ui.txDel = false;
  renderCuenta(); setTab('cuenta');
}
function renderTx(el) {
  const t = txById(ui.txId);
  if (!t) { ui.txId = null; if (ui.tab === 'cuenta') txBackNav(); return false; }
  const acc = accOf(t.acc), cur = acc.cur, pay = isPay(t), xf = isXfer(t), sb = txSub(t), cat = pay ? pcat(t) : t.amount > 0 ? 'Ingreso' : sb ? 'Suscripción' : (CAT_ORDER.indexOf(t.category) >= 0 ? t.category : 'Otros');
  const sbr = sb && subBrand(sb), col = xf ? 'transparent' : pay ? '#B98AE6' : sb ? (sbr ? sbr.bg : CARD_COLORS[data.subs.indexOf(sb) % CARD_COLORS.length]) : CAT_COLOR[cat], glyph = xf ? RMI('arrow-left-right-line', 44, t.amount < 0 ? 'var(--rt)' : '#22B573') : pay ? iconSVG('card', '#fff', 30) : sb ? (sbr ? subSVG(sbr, 34) : esc(sb.name || '?').charAt(0)) : catGlyph(cat), d = pd(t.date);
  const st = (l, v, c) => '<div><span class="sub">' + l + '</span><b' + (c ? ' style="color:' + c + '"' : '') + '>' + v + '</b></div>';
  const kind = xf ? 'Transferencia' : pay ? 'Pago de crédito' : t.amount > 0 ? 'Ingreso' : 'Gasto';
  const pairT = t.pair ? data.transactions.find((x) => x.pair === t.pair && x !== t) : null;
  let extra = '';
  if (t.est > 0 && t.amount > 0) { const df = round2(t.amount - t.est); extra = '<div class="stats" style="margin-top:14px;gap:20px">' + st('Previsto', fmtC2(t.est, cur)) + st('Diferencia', (df >= 0 ? '+' : '−') + fmtC2(Math.abs(df), cur), df >= 0 ? 'var(--gt)' : 'var(--rt)') + '</div>'; }
  if (t.job && t.hrs > 0) { const tp = taxPct(t.amount, t.rate, t.hrs); extra += '<div class="stats" style="margin-top:14px;gap:20px">' + st('Horas trabajadas', fmtHrs(t.hrs)) + st('Monto pagado', fmtC2(t.amount, cur)) + '</div><div class="stats" style="margin-top:14px;gap:20px">' + st('Bruto (' + fmtC2(t.rate, cur) + '/h)', fmtC2(t.rate * t.hrs, cur)) + st('Impuestos descontados', tp.toLocaleString('en-US') + '%') + '</div>'; }
  if (pairT) extra += '<div class="stats" style="margin-top:14px;gap:20px">' + st(pairT.amount < 0 ? 'Salió de' : 'Entró a', esc(accOf(pairT.acc).name)) + '</div>';
  el.innerHTML =
    '<div class="navrow"><button class="back" data-act="txback" aria-label="Regresar">' + IC_BACK + '</button>' +
    (xf ? '' : '<button class="editbtn" data-act="txedit" aria-label="Editar">' + IC_PEN + '</button>') + '</div>' +
    '<div class="acctop"><div class="ptile"><span class="tile" style="background:' + col + '" aria-hidden="true">' + glyph + '</span></div><h1 style="font-size:28px;margin:10px 0 2px">' + esc(t.note || cat) + '</h1><div class="sub">' + cat + '</div>' +
    '<div class="big" style="font-size:40px;margin-top:12px;color:' + (t.amount > 0 && !pay ? 'var(--gt)' : '#1C1C1E') + '">' + fmtSC2(t.amount, cur) + '</div></div>' +
    '<div class="card"><div class="stats" style="border:0;margin:0;padding:0;gap:20px">' + st('Cuenta', esc(acc.name)) + st('Fecha', dlabel(d) + ' ' + d.getFullYear()) + '</div>' +
    '<div class="stats" style="margin-top:14px;gap:20px">' + st('Tipo', kind) + st('Categoría', cat) + '</div>' + extra + (t.src === 'watch' ? '<div class="sub" style="margin-top:14px;display:flex;align-items:center;gap:6px">' + WATCH_MARK.replace('margin-left:5px;', '') + '<span>Anotado desde el Apple Watch</span></div>' : '') + '</div>' +
    (xf ? '' : '<button class="secbtn" data-act="txedit">Editar</button>') +
    (pay ? '' : '<button class="secbtn" data-act="txpost">Posponer</button>') +
    '<button class="delbtn" data-act="txdel">' + 'Eliminar' + '</button>';
  return true;
}
