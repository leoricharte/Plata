/* ---------- Monedas y utilidades de datos ---------- */
const uid = () => Math.random().toString(36).slice(2, 8);
const round2 = (n) => Math.round(n * 100) / 100;
const fxRate = () => (data.settings && data.settings.fx > 0 ? data.settings.fx : (curS() ? fxDefault(curP(), curS()) : 1));
const usd = (n, cur) => (curS() && cur === curS() ? n / fxRate() : n);
const fromUSD = (n, cur) => (curS() && cur === curS() ? n * fxRate() : n);
const symOf = (cur) => (CURRENCIES[cur] || CURRENCIES.USD).sym.replace(/ $/, '\u00a0');
const fmtC = (n, cur) => (n < 0 ? '−' : '') + symOf(cur) + Math.abs(Math.round(n)).toLocaleString('en-US');
const fmtC2 = (n, cur) => symOf(cur) + Math.abs(n).toLocaleString('en-US', { minimumFractionDigits: decOf(cur), maximumFractionDigits: decOf(cur) });
const fmtSC2 = (n, cur) => (n < 0 ? '−' : '+') + fmtC2(n, cur);
const accOf = (id) => data.accounts.find((a) => a.id === id) || data.cards.find((c) => c.id === id) || data.accounts[0];
const isCredit = (a) => data.cards.indexOf(a) >= 0 || (!!a && a.id === '__new' && a.kind === 'card');
/* Un movimiento en débito suma o resta al saldo; en crédito, un gasto sube la deuda y un pago la baja */
const applyTo = (a, signed) => { a.balance = round2(isCredit(a) ? a.balance - signed : a.balance + signed); };
const l4 = (o) => (o && o.last4 ? ' · ● ' + o.last4 : '');
const l4tag = (o) => (o && o.last4 ? ' <span class="sub" style="font-weight:500;font-size:13px;white-space:nowrap"><i style="display:inline-block;width:6px;height:6px;border-radius:50%;background:var(--ink);margin:0 6px 1px 2px"></i><span class="cn" style="font-size:15px;color:var(--ink)">' + esc(o.last4) + '</span></span>' : '');
const acctOpts = (sel, credit) => '<optgroup label="Débito">' + data.accounts.map((a) => '<option value="' + a.id + '"' + (a.id === sel ? ' selected' : '') + '>' + esc(a.name) + l4(a) + ' · ' + a.cur + '</option>').join('') + '</optgroup>' +
  (credit && data.cards.length ? '<optgroup label="Crédito">' + data.cards.map((a) => '<option value="' + a.id + '"' + (a.id === sel ? ' selected' : '') + '>' + esc(a.name) + l4(a) + ' · ' + a.cur + '</option>').join('') + '</optgroup>' : '');
const inclNote = (list, bal) => { const m = {}; list.forEach((o) => { if (o.cur && o.cur !== curP()) m[o.cur] = (m[o.cur] || 0) + bal(o); }); const k = Object.keys(m).filter((x) => m[x]); return k.length ? '<span class="sub mixn">Incluye <span data-notr>' + k.map((x) => fmtC(m[x], x)).join(' + ') + '</span></span>' : ''; };
const txUSD = (t) => usd(t.amount, accOf(t.acc).cur);
const isQ = (r) => typeof r === 'string' && r.charAt(0) === 'q';
const qDays = (r) => { const m = String(r).match(/^q(\d+),(\d+)$/); const c = (n) => Math.min(31, Math.max(1, Math.round(n) || 1)); const a = c(m ? +m[1] : 15), b = c(m ? +m[2] : 30); return a <= b ? [a, b] : [b, a]; };
const qMake = (a, b) => { const x = qDays('q' + a + ',' + b); return 'q' + x[0] + ',' + x[1]; };
const repN = (v) => (v === 'm' || isQ(v) ? v : Number(v) || 0);
function qNext(d, r, incl) {
  const dd = qDays(r), y = d.getFullYear(), m = d.getMonth(), last = new Date(y, m + 1, 0).getDate();
  for (let i = 0; i < 2; i++) { const x = Math.min(dd[i], last); if (incl ? x >= d.getDate() : x > d.getDate()) return new Date(y, m, x); }
  const l2 = new Date(y, m + 2, 0).getDate(); return new Date(y, m + 1, Math.min(dd[0], l2));
}
function nextRep(d, rep) {
  if (isQ(rep)) return qNext(d, rep, false);
  if (rep === 'm') { const y = d.getFullYear(), m = d.getMonth() + 1, last = new Date(y, m + 1, 0).getDate(); return new Date(y, m, Math.min(d.getDate(), last)); }
  return addDays(d, Number(rep) || 7);
}
const untilTxt = (e) => (e && e.repeat && e.until ? ' · hasta ' + dshort(pd(e.until)) : '');
const repLabel = (r) => (isQ(r) ? 'los días ' + qDays(r)[0] + ' y ' + qDays(r)[1] + ' de cada mes' : r === 'm' ? 'cada mes' : Number(r) === 7 ? 'cada semana' : Number(r) === 14 ? 'cada 2 semanas' : 'una vez');
const addMonths = (d, n) => new Date(d.getFullYear(), d.getMonth() + n, 1);
const monthYear = (d) => MON[d.getMonth()] + ' ' + d.getFullYear();
const amtW = (v, ph) => { const s = String(v || ph || '0'); const d = s.replace(/[.,]/g, '').length, dots = s.length - d; return Math.max(1.2, d + dots * 0.4 + 0.3) + 'ch'; };

