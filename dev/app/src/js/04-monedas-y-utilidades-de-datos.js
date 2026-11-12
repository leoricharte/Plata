/* ---------- Monedas y utilidades de datos ---------- */
const uid = () => Math.random().toString(36).slice(2, 8);
const { round2, isQ, qDays, qMake, repN, qNext, nextRep, addMonths } = Motor;   /* del motor (src/motor/) */
const fxRate = () => (data.settings && data.settings.fx > 0 ? data.settings.fx : (curS() ? fxDefault(curP(), curS()) : 1));
const usd = (n, cur) => (curS() && cur === curS() ? n / fxRate() : n);
const fromUSD = (n, cur) => (curS() && cur === curS() ? n * fxRate() : n);
const { symOf, fmtC, fmtC2, fmtSC2 } = Motor;   /* del motor (src/motor/monedas.mjs) */
const accOf = (id) => data.accounts.find((a) => a.id === id) || data.cards.find((c) => c.id === id) || data.accounts[0];
const isCredit = (a) => data.cards.indexOf(a) >= 0 || (!!a && a.id === '__new' && a.kind === 'card');
/* Un movimiento en débito suma o resta al saldo; en crédito, un gasto sube la deuda y un pago la baja */
const applyTo = (a, signed) => { a.balance = Motor.nextBalance(a.balance, signed, isCredit(a)); };
const l4 = (o) => (o && o.last4 ? ' · ● ' + o.last4 : '');
const l4tag = (o) => (o && o.last4 ? ' <span class="sub" style="font-weight:500;font-size:13px;white-space:nowrap"><i style="display:inline-block;width:6px;height:6px;border-radius:50%;background:var(--ink);margin:0 6px 1px 2px"></i><span class="cn" style="font-size:15px;color:var(--ink)">' + esc(o.last4) + '</span></span>' : '');
/* Cuentas y tarjetas en los menús donde se elige una (igual que en la app de iPhone): las que más usaste en los últimos 90 días primero y, junto al nombre,
   cuánto dinero tienen en su propia moneda; en una tarjeta con límite, lo disponible, y en un préstamo (o una tarjeta sin límite), lo que todavía se debe. */
const recentUse = () => {
  const t = getToday(), to = iso(t), from = iso(addDays(t, -90)), first = data.accounts.length ? String(data.accounts[0].id) : '', out = {};
  (data.transactions || []).forEach((x) => { const d = String(x.date || ''); if (d < from || d > to) return; const k = x.acc ? String(x.acc) : first; out[k] = (out[k] || 0) + 1; });
  return out;
};
const byUse = (list) => { const use = recentUse(); return list.map((a, i) => ({ a: a, i: i })).sort((x, y) => ((use[String(y.a.id)] || 0) - (use[String(x.a.id)] || 0)) || (x.i - y.i)).map((x) => x.a); };
const accAmt = (a) => {
  const bal = Number(a.balance) || 0;
  if (!isCredit(a)) return fmtC(bal, a.cur);
  const limit = Number(a.limit) || 0;
  if (a.kind === 'loan' || !(limit > 0)) return fmtC(bal, a.cur) + ' ' + trText('pendiente');
  return fmtC(Math.max(0, limit - bal), a.cur) + ' ' + trText('disponible');
};
const accLabel = (a) => (a.name || '') + l4(a) + ' · ' + accAmt(a);
const acctOpts = (sel, credit) => '<optgroup label="Débito">' + byUse(data.accounts).map((a) => '<option value="' + a.id + '"' + (a.id === sel ? ' selected' : '') + '>' + esc(accLabel(a)) + '</option>').join('') + '</optgroup>' +
  (credit && data.cards.length ? '<optgroup label="Crédito">' + byUse(data.cards).map((a) => '<option value="' + a.id + '"' + (a.id === sel ? ' selected' : '') + '>' + esc(accLabel(a)) + '</option>').join('') + '</optgroup>' : '');
const inclNote = (list, bal) => { const m = {}; list.forEach((o) => { if (o.cur && o.cur !== curP()) m[o.cur] = (m[o.cur] || 0) + bal(o); }); const k = Object.keys(m).filter((x) => m[x]); return k.length ? '<span class="sub mixn">Incluye <span data-notr>' + k.map((x) => fmtC(m[x], x)).join(' + ') + '</span></span>' : ''; };
const txUSD = (t) => usd(t.amount, accOf(t.acc).cur);
const untilTxt = (e) => (e && e.repeat && e.until ? ' · hasta ' + dshort(pd(e.until)) : '');
const repLabel = (r) => (isQ(r) ? 'los días ' + qDays(r)[0] + ' y ' + qDays(r)[1] + ' de cada mes' : r === 'm' ? 'cada mes' : Number(r) === 7 ? 'cada semana' : Number(r) === 14 ? 'cada 2 semanas' : 'una vez');
const monthYear = (d) => MON[d.getMonth()] + ' ' + d.getFullYear();
const amtW = (v, ph) => { const s = String(v || ph || '0'); const d = s.replace(/[.,]/g, '').length, dots = s.length - d; return Math.max(1.2, d + dots * 0.4 + 0.3) + 'ch'; };

