/* ---------- Nazca · BCP · Estado de cuenta de la tarjeta de crédito Visa (PDF) ----------
 * Lee el "Estado de Cuenta Tarjeta VISA" del BCP (visto en una Visa con deuda en soles y en dólares). Es distinto al de ahorros: va de arriba a abajo
 * como "saldo anterior → movimientos → sub total → comisiones → monto total facturado", con dos columnas de monto (Soles y Dólares).
 * Entrada: lo que devuelve NazcaPDF.read(). Todo ocurre en el dispositivo. Probado con UN estado real; las pruebas usan uno inventado con el mismo diseño.
 *
 * Diseño que espera:
 *  · página 1: "Número de tarjeta 4634-03XX-XXXX-0082", ciclo "Del 27/04/26 Al 25/05/26", "Fecha límite de pago", línea de crédito / línea utilizada /
 *    crédito disponible, pago mínimo y pago total (soles y dólares);
 *  · tabla de movimientos: fecha de proceso (27Abr) · fecha de consumo · descripción · tipo (CONSUMO, PAGO, CARGO) · Soles · Dólares.
 *    Un pago lleva "-" AL FINAL (2,036.11-); "CUOTA DEL MES" (tipo CARGO) es la suma de las cuotas del plan, que se detallan más abajo;
 *  · página 2: SUB TOTAL, comisiones y gastos (seguro de desgravamen, intereses…), MONTO TOTAL FACTURADO y el "DETALLE PLAN CUOTAS" en soles y en dólares.
 * Para Plata: pago → positivo; consumo, cuota y comisión → negativo. La cuota del mes se importa desglosada (una fila por compra en cuotas, con su número de
 * cuota) a la fecha de cierre, en vez de una sola fila "CUOTA DEL MES". La fecha de cada consumo es la de consumo (no la de proceso).
 * "Cuadra" (en soles y en dólares): saldo anterior + consumos − pagos + cuotas = SUB TOTAL; SUB TOTAL + comisiones = MONTO TOTAL FACTURADO;
 * y las cuotas desglosadas suman la fila "CUOTA DEL MES". */
const NazcaBCPTarjeta = (() => {
  const MES = { ene: 1, feb: 2, mar: 3, abr: 4, may: 5, jun: 6, jul: 7, ago: 8, set: 9, sep: 9, oct: 10, nov: 11, dic: 12 };
  const pad = (n) => String(n).padStart(2, '0'), r2 = (n) => Math.round(n * 100) / 100, near = (a, b) => Math.abs(a - b) < 0.005;
  const norm = (t) => String(t || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
  const AMT = /^[\d,]+\.\d{2}-?$/, num = (s) => r2(parseFloat(String(s).replace(/[,-]/g, '')));
  const flat = (doc) => doc.pages.map((p) => p.items.map((i) => i.str).join(' ')).join(' ').replace(/\s+/g, ' ');
  const sentence = (s) => { const t = s.toLowerCase(); return t.charAt(0).toUpperCase() + t.slice(1); };

  function detect(doc) {
    if (!doc || !doc.pages || !doc.pages.length) return 0;
    const t = norm(flat(doc));
    return /estado de cuenta tarjeta/.test(t) && /ciclo de facturacion/.test(t) && /fecha limite de pago/.test(t) && /linea de credito/.test(t) && /saldo anterior/.test(t) && /bcp/.test(t) ? 1 : 0;
  }

  function read(doc) {
    if (!detect(doc)) return null;
    const pdf = typeof NazcaPDF !== 'undefined' ? NazcaPDF : require('../pdf.js');
    const all = flat(doc);
    const out = { bank: 'bcp', kind: 'tarjeta', label: 'BCP · Tarjeta de crédito', cur: 'PEN', account: { last4: '' }, period: null, items: [], skipped: { unreadable: 0, zero: 0 }, check: null, card: {} };
    const l4 = /\d{4}-\d{2}[X*]{2}-[X*]{4}-(\d{4})/i.exec(all); if (l4) out.account.last4 = l4[1];
    const pm = /(\d{2})\/(\d{2})\/(\d{2})\s+(\d{2})\/(\d{2})\/(\d{2})/.exec(all);   /* el ciclo: «27/04/26 25/05/26» (del … al día de cierre) */
    if (!pm) return Object.assign(out, { error: 'period' });
    const f = { d: +pm[1], m: +pm[2], y: 2000 + +pm[3] }, e = { d: +pm[4], m: +pm[5], y: 2000 + +pm[6] };
    out.period = { from: f.y + '-' + pad(f.m) + '-' + pad(f.d), to: e.y + '-' + pad(e.m) + '-' + pad(e.d) };
    const card = out.card;
    const lines = []; doc.pages.forEach((pg) => pdf.lines(pg, 3).forEach((l) => lines.push(l)));
    const L = lines.map((l) => ({ it: l.items, txt: l.items.map((i) => i.str).join(' ').replace(/\s+/g, ' ').trim() }));
    const col = (i) => (i.x + i.w > 540 ? 'USD' : 'PEN');
    const uniq = (its) => its.filter((i, k) => !its.some((j, q) => q < k && j.str === i.str && Math.abs(j.x - i.x) < 1 && Math.abs(j.w - i.w) < 1));   // el PDF repite algunos textos (negrita)

    /* Resumen de la primera página: fecha límite, línea de crédito, pago mínimo */
    for (let k = 0; k < L.length; k++) {
      const nt = norm(L[k].txt);
      if (/fecha limite de pago/.test(nt) && !card.dueDate) { for (const x of L.slice(k + 1, k + 3)) { const m = /^(\d{2})\/(\d{2})\/(\d{2})$/.exec(x.it[x.it.length - 1].str); if (m) { card.dueDate = (2000 + +m[3]) + '-' + m[2] + '-' + m[1]; card.dueDay = +m[1]; break; } } }
      if (/^linea de credito s\/ - linea utilizada/.test(nt) && !card.limit) { const nx = L[k + 1]; if (nx) { const v = uniq(nx.it).filter((i) => /^[\d,]+(\.\d{2})?$/.test(i.str) && i.x < 300).map((i) => num(i.str)); if (v.length >= 2) { card.limit = v[0]; out._used = v[1]; } } }
      if (/^pago minimo s\/ pago total s\//.test(nt) && card.minPayment == null) { for (const nx of L.slice(k + 1, k + 4)) { const v = nx.it.filter((i) => AMT.test(i.str) && i.x < 250).map((i) => num(i.str)); if (v.length) { card.minPayment = v[0]; break; } } }   /* el monto está 1–2 líneas abajo (el texto de la penalidad queda en medio) */
      if (/^compras\b/.test(nt) && card.apr == null && L[k].it.length >= 4) { const m = /(\d{1,3}\.\d{2})\s?%/.exec(L[k].txt); if (m) card.apr = parseFloat(m[1]); }
    }

    /* Movimientos, comisiones, total y plan de cuotas */
    const prev = { PEN: 0, USD: 0 }, sum = { buy: { PEN: 0, USD: 0 }, pay: { PEN: 0, USD: 0 }, cuo: { PEN: 0, USD: 0 }, fee: { PEN: 0, USD: 0 } }, cargo = { PEN: 0, USD: 0 }, planTot = { PEN: null, USD: null };
    let sub = null, total = null, sec = '', plan = '', line = 0, seen = false;
    const yearOf = (mo) => (mo > e.m ? e.y - 1 : e.y), isDate = (i) => /^\d{2}[A-Za-zÁ-ú]{3}$/.test(i.str) && MES[norm(i.str.slice(2))] && i.x < 70;
    for (const x of L) {
      const nt = norm(x.txt);
      if (/^saldo anterior/.test(nt)) { sec = 'mov'; seen = true; for (const i of x.it) if (AMT.test(i.str)) prev[col(i)] = num(i.str); continue; }
      if (!seen) continue;
      if (/^sub total/.test(nt)) { sub = { PEN: null, USD: null }; for (const i of x.it) if (AMT.test(i.str)) sub[col(i)] = num(i.str); sec = 'fee'; continue; }
      if (/^monto total facturado/.test(nt)) { total = { PEN: null, USD: null }; for (const i of x.it) if (AMT.test(i.str)) total[col(i)] = num(i.str); sec = ''; continue; }
      const pl = /^detalle plan cuotas (soles|dolares)/.exec(nt); if (pl) { sec = 'plan'; plan = pl[1] === 'soles' ? 'PEN' : 'USD'; continue; }
      if (/^como esta compuesta su deuda/.test(nt)) break;
      if (sec === 'plan' && /^total (soles|dolares)/.test(nt)) { const a = x.it.filter((i) => AMT.test(i.str)); if (a.length) planTot[plan] = num(a[a.length - 1].str); continue; }
      if (sec === 'plan') {
        if (!isDate(x.it[0])) continue;
        const a = x.it.filter((i) => AMT.test(i.str)); if (!a.length) { out.skipped.unreadable++; continue; }
        const v = num(a[a.length - 1].str), nro = x.it.find((i) => /^\d{2}\/\d{2}$/.test(i.str));
        const desc = x.it.filter((i) => i.x > 130 && i.x < 250 && !AMT.test(i.str)).map((i) => i.str).join(' ').replace(/\s+/g, ' ').trim();
        if (!desc || !v) { out.skipped.unreadable++; continue; }
        const nn = nro ? nro.str.split('/').map(Number) : null;
        out.items.push({ line: ++line, date: out.period.to, desc: desc + (nn ? ' · cuota ' + nn[0] + ' de ' + nn[1] : ''), amount: -v, cur: plan });
        sum.cuo[plan] = r2(sum.cuo[plan] + v); continue;
      }
      if (sec === 'mov') {
        if (!isDate(x.it[0])) continue;
        const a = x.it.filter((i) => AMT.test(i.str) && i.x > 465);
        const type = (x.it.find((i) => /^(CONSUMO|PAGO|CARGO|ABONO)$/.test(i.str)) || {}).str || '';
        if (!a.length) { out.skipped.unreadable++; continue; }
        const am = a[a.length - 1], cur = col(am), v = num(am.str), credit = /-$/.test(am.str) || type === 'PAGO' || type === 'ABONO';
        if (type === 'CARGO') { cargo[cur] = r2(cargo[cur] + v); continue; }                                    // "CUOTA DEL MES": se importa desglosada (plan de cuotas)
        const second = x.it.slice(1).find((i) => /^\d{2}[A-Za-zÁ-ú]{3}$/.test(i.str)), dmy = (second || x.it[0]).str;
        const mo = MES[norm(dmy.slice(2))], date = yearOf(mo) + '-' + pad(mo) + '-' + dmy.slice(0, 2);
        const parts = x.it.filter((i) => i.x >= 130 && i.x < 400 && !(i.x >= 315 && /^[A-Z]{2}$/.test(i.str))).map((i) => i.str);   // sin el país (PE, EE…) del final
        const desc = parts.join(' ').replace(/\s+/g, ' ').trim();
        if (!desc) { out.skipped.unreadable++; continue; }
        if (!v) { out.skipped.zero++; continue; }
        (credit ? sum.pay : sum.buy)[cur] = r2((credit ? sum.pay : sum.buy)[cur] + v);
        out.items.push({ line: ++line, date, desc, amount: credit ? v : -v, cur }); continue;
      }
      if (sec === 'fee') {                                                                                  // comisiones y gastos: texto + monto en la misma línea
        const a = x.it.filter((i) => AMT.test(i.str) && i.x > 465); if (!a.length) continue;
        const desc = x.it.filter((i) => i.x >= 130 && i.x < 465 && !AMT.test(i.str)).map((i) => i.str).join(' ').replace(/\s+/g, ' ').trim(); if (!desc) continue;
        for (const am of a) { const v = num(am.str), cur = col(am); if (!v) continue; sum.fee[cur] = r2(sum.fee[cur] + v); out.items.push({ line: ++line, date: out.period.to, desc: sentence(desc), amount: -v, cur }); }
      }
    }
    const main = out.items.some((i) => i.cur === 'PEN') || !out.items.some((i) => i.cur === 'USD') ? 'PEN' : 'USD'; out.cur = main;
    const have = !!(sub && total);
    const chk = (cur) => {
      const pre = r2(prev[cur] + sum.buy[cur] - sum.pay[cur] + sum.cuo[cur]), s = sub[cur] == null ? 0 : sub[cur], t = total[cur] == null ? 0 : total[cur];
      return near(pre, s) && near(r2(s + sum.fee[cur]), t) && near(sum.cuo[cur], cargo[cur]) && (planTot[cur] == null || near(planTot[cur], sum.cuo[cur]));
    };
    if (card.minPayment == null) delete card.minPayment;
    out.check = { have, prev: prev[main], end: out._used != null && main === 'PEN' ? out._used : (total ? total[main] : null), totalCharges: have ? r2((total[main] || 0) - prev[main] + sum.pay[main]) : null,
      totalCredits: have ? sum.pay[main] : null, sumCharges: r2(sum.buy[main] + sum.cuo[main] + sum.fee[main]), sumCredits: sum.pay[main], running: true, ok: have ? chk('PEN') && chk('USD') : null };
    delete out._used;
    return out;
  }
  return { id: 'bcp-tarjeta', bank: 'bcp', label: 'BCP · Tarjeta de crédito', detect, read };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaBCPTarjeta;
