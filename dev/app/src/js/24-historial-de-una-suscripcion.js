/* ---------- Historial de una suscripción: inicio, cambios de precio o cuenta, atrasos, quiebres y fin (se recalcula con los movimientos que haya) ---------- */
function subHist(o) {
  const T = data.transactions, k = recKey(o.name), ym = (d) => String(d).slice(0, 7), mv = (m, n) => { const d = new Date(+m.slice(0, 4), +m.slice(5, 7) - 1 + n, 1); return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0'); };
  const lbl = (m) => monthYear(new Date(+m.slice(0, 4), +m.slice(5, 7) - 1, 1)), rng = (a, b) => (a === b ? lbl(a) : lbl(a) + ' – ' + lbl(b));
  const L = T.filter((t) => t.amount < 0 && !isPay(t) && !t.job && (t.sub === o.id || txSub(t) === o || (k && t.note && recKey(t.note) === k)));
  if (!L.length) return '<div class="empty">Aún no hay cobros de esta suscripción en tus movimientos.</div>';
  const byM = {}; L.forEach((t) => { const m = ym(t.date), c = byM[m]; if (!c || Math.abs(+t.date.slice(8, 10) - (o.day || 1)) < Math.abs(+c.date.slice(8, 10) - (o.day || 1))) byM[m] = t; });
  const ms = Object.keys(byM).sort(), has = {}, accMax = {}; T.forEach((t) => { has[t.acc + '|' + ym(t.date)] = 1; if (!accMax[t.acc] || t.date > accMax[t.acc]) accMax[t.acc] = t.date; });
  const ev = [], add = (d, c, t, sb) => ev.push({ d: d, c: c, t: t, s: sb }), A = (id) => '<span data-notr>' + esc(accOf(id).name) + '</span>', cur = accOf(byM[ms[0]].acc).cur;
  const G = '#22B573', Y = '#FF9F0A', R = '#FF6B5E', B = '#4F94F7', N = '#A1A1A6'; let prev = null, breaks = 0, lateOn = false;
  add(byM[ms[0]].date, G, '<span>Primer cobro en Plata</span>', fmtC2(Math.abs(byM[ms[0]].amount), cur) + ' · ' + A(byM[ms[0]].acc));
  for (let m = ms[0]; m <= ms[ms.length - 1]; m = mv(m, 1)) {
    const c = byM[m];
    if (!c) continue;
    if (prev) {
      const gm = []; for (let x = mv(ym(prev.date), 1); x < m; x = mv(x, 1)) gm.push(x);
      if (gm.length) {
        const real = gm.filter((x) => has[prev.acc + '|' + x]), nod = gm.length - real.length;
        if (!real.length) add(mv(m, -1) + '-15', N, '<span>Sin datos</span>', '<span>Puede faltar un estado de cuenta</span> · ' + rng(gm[0], gm[gm.length - 1]));
        else if (real.length === 1 && !nod) add(gm[0] + '-15', Y, '<span>Mes sin cobro</span>', lbl(gm[0]));
        else { breaks++; add(gm[0] + '-15', R, '<span>Quiebre</span> · ' + real.length + ' <span>meses sin cobro</span>', rng(gm[0], gm[gm.length - 1]) + (nod ? ' · <span>Puede faltar un estado de cuenta</span>' : '')); }
      }
      const a0 = Math.abs(prev.amount), a1 = Math.abs(c.amount);
      if (Math.abs(a1 - a0) > Math.max(0.5, a0 * 0.05)) add(c.date, B, '<span>' + (a1 > a0 ? 'Subió de' : 'Bajó de') + '</span> ' + fmtC2(a0, cur) + ' → ' + fmtC2(a1, cur), dlabel(pd(c.date)));
      if (c.acc !== prev.acc) add(c.date, B, '<span>Cambió de cuenta</span>', A(prev.acc) + ' → ' + A(c.acc));
    }
    const dd = Math.abs(+c.date.slice(8, 10) - (o.day || 1)), late = Math.min(dd, 31 - dd) > 5;
    if (late && !lateOn) add(c.date, Y, '<span>Cobro fuera de fecha</span>', '<span>Cobró el día</span> ' + (+c.date.slice(8, 10)) + ' · <span>esperado el</span> ' + (o.day || 1)); lateOn = late;
    prev = c;
  }
  const last = byM[ms[ms.length - 1]], mx = accMax[last.acc] || last.date, ended = Math.round((pd(mx) - pd(last.date)) / 864e5) > 50;
  if (ended) add(last.date, R, '<span>Último cobro</span>', '<span>¿Se canceló?</span> · <span>Sin cobros desde</span> ' + lbl(mv(ym(last.date), 1)));
  ev.sort((a, b) => (a.d < b.d ? 1 : a.d > b.d ? -1 : 0));
  const st2 = (l, v) => '<div><span class="sub" style="font-size:13px">' + l + '</span><b>' + v + '</b></div>';
  return '<div class="stats" style="border:0;margin:0 0 4px;padding:0;gap:20px">' + st2('<span>Desde</span>', lbl(ms[0])) + st2('<span>Cobros</span>', L.length) + st2('<span>Quiebres</span>', breaks) + '</div>' +
    '<div class="tl">' + ev.slice(0, 10).map((e) => '<div class="ev"><span class="dot" style="background:' + e.c + '"></span><div class="grow"><div class="name" style="font-size:16px">' + e.t + '</div><div class="sub" style="font-size:13px">' + e.s + '</div></div></div>').join('') + '</div>';
}
