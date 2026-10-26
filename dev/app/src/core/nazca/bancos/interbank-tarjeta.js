/* ---------- Nazca · Interbank · Estado de cuenta de la tarjeta de crédito (PDF) ----------
 * Lee el estado de cuenta de las tarjetas de crédito de Interbank (visto en una "INTERBANK PREMIA" en soles). Es distinto al de ahorros:
 * no trae una lista de consumos con saldo, sino "DETALLE DE PAGO DEL MES", que suma subtotales. Entrada: lo que devuelve NazcaPDF.read().
 * Todo ocurre en el dispositivo.
 *
 * Diseño que espera (visto en UN estado real; las pruebas usan uno inventado con el mismo diseño):
 *  · página 1: tarjeta ("INTERBANK PREMIA 4110 93** **** 3822 - SOLES"), "del 07/08/2026 al cierre de 09/09/2026", línea de crédito, saldo
 *    disponible, deuda total, último día de pago, pago del mes y pago mínimo;
 *  · "DETALLE DE PAGO DEL MES" con dos columnas de monto, S/ y US$, y estas secciones (cada una con su SUBTOTAL):
 *      TU ESTADO DE CUENTA ANTERIOR (lo que debías) · PAGOS REALIZADOS (con "-") · TUS CONSUMOS (si hubo; no estaba en el ejemplo) ·
 *      TUS CONSUMOS EN CUOTAS (la cuota del mes: capital + interés) · OTROS COBROS (seguro de desgravamen, etc.);
 *  · PAGO DEL MES (suma de subtotales) y PAGO MÍNIMO DEL MES.
 * Para Plata: pago → positivo; consumo, cuota y cobro → negativo. La fecha de una cuota en el PDF es la de la COMPRA original (meses atrás): como lo
 * que se paga este ciclo es la cuota, entra a la fecha de cierre. "Cuadra": cada subtotal coincide con sus filas y los subtotales suman el pago del mes.
 * Los consumos del mes (sin cuotas) se leen con el mismo diseño de fila que "otros cobros", pero no se han probado con un estado real. */
const NazcaInterbankTarjeta = (() => {
  const MES = { ene: 1, feb: 2, mar: 3, abr: 4, may: 5, jun: 6, jul: 7, ago: 8, set: 9, sep: 9, oct: 10, nov: 11, dic: 12 };
  const pad = (n) => String(n).padStart(2, '0'), r2 = (n) => Math.round(n * 100) / 100, near = (a, b) => Math.abs(a - b) < 0.005;
  const norm = (t) => String(t || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
  const NUM = /^-?[\d,]+\.\d{2}$/, num = (s) => r2(parseFloat(String(s).replace(/[,\s]/g, '')));
  const flat = (doc) => doc.pages.map((p) => p.items.map((i) => i.str).join(' ')).join(' ').replace(/\s+/g, ' ');

  function detect(doc) {
    if (!doc || !doc.pages || !doc.pages.length) return 0;
    const t = norm(flat(doc));
    return /detalle de pago del mes/.test(t) && /tarjeta de credito/.test(t) && /pago minimo/.test(t) && /linea de credito/.test(t) && /interbank/.test(t) ? 1 : 0;
  }

  function read(doc) {
    if (!detect(doc)) return null;
    const pdf = typeof NazcaPDF !== 'undefined' ? NazcaPDF : require('../pdf.js');
    const all = flat(doc);
    const out = { bank: 'interbank', kind: 'tarjeta', label: 'Interbank · Tarjeta de crédito', cur: 'PEN', account: { last4: '' }, period: null, items: [], skipped: { unreadable: 0, zero: 0 }, check: null, card: {} };
    const l4 = /(\d{4}) - (SOLES|D[ÓO]LARES)/i.exec(all); if (l4) { out.account.last4 = l4[1]; if (/^D/i.test(l4[2])) out.cur = 'USD'; }
    const pm = /del (\d{2})\/(\d{2})\/(\d{4}) al cierre de (\d{2})\/(\d{2})\/(\d{4})/i.exec(all);
    if (!pm) return Object.assign(out, { error: 'period' });
    const f = { d: +pm[1], m: +pm[2], y: +pm[3] }, e = { d: +pm[4], m: +pm[5], y: +pm[6] };
    out.period = { from: f.y + '-' + pad(f.m) + '-' + pad(f.d), to: e.y + '-' + pad(e.m) + '-' + pad(e.d) };
    const lines = []; doc.pages.forEach((pg) => pdf.lines(pg, 3).forEach((l) => lines.push(Object.assign(l, { w: pg.w }))));
    const L = lines.map((l) => ({ it: l.items, w: l.w, txt: l.items.map((i) => i.str).join(' ').replace(/\s+/g, ' ').trim() }));

    /* Tarjeta: línea de crédito, deuda total, último día de pago, pago mínimo y tasa */
    const card = out.card; let debt = null;
    const lim = /Tu L[ií]nea de Cr[eé]dito es de:.*?S\/\s?([\d,]+\.\d{2})/i.exec(all.replace(/\s+/g, ' '));
    const row3 = L.find((x) => x.it.filter((i) => /^S\/\s?[\d,]+\.\d{2}/.test(i.str)).length >= 3);
    if (row3) { const v = row3.it.filter((i) => /^S\/\s?[\d,]+\.\d{2}/.test(i.str)).map((i) => num(/([\d,]+\.\d{2})/.exec(i.str)[1])); card.limit = v[0]; debt = v[2]; }
    else if (lim) card.limit = num(lim[1]);
    const iDue = L.findIndex((x) => /^ultimo dia de pago/.test(norm(x.txt)));
    if (iDue >= 0) for (const x of L.slice(iDue + 1, iDue + 6)) { const m = /(\d{2})\/(\d{2})\/(\d{4})/.exec(x.txt); if (m) { card.dueDate = m[3] + '-' + m[2] + '-' + m[1]; card.dueDay = +m[1]; break; } }
    const iTea = L.findIndex((x) => /^\*?\s*tea de consumos soles y dolares/.test(norm(x.txt)));      // la tasa viene en la línea de abajo: "Soles  87.76%"
    if (iTea >= 0) for (const x of L.slice(iTea + 1, iTea + 3)) { const m = /^soles\s+(\d{1,3}(?:\.\d{1,2})?)\s?%$/i.exec(x.txt); if (m) { card.apr = parseFloat(m[1]); break; } }

    /* Detalle de pago del mes: dos columnas (S/ y US$) */
    const isUsd = (i) => i.x + i.w > 520;
    const col = (items) => { const v = { PEN: null, USD: null }; for (const i of items) if (NUM.test(i.str)) { const k = isUsd(i) ? 'USD' : 'PEN'; v[k] = num(i.str); } return v; };
    let sec = '', line = 0, started = false; const prev = { PEN: null, USD: null }, sums = {}, sub = {}; let total = null, minPay = null;
    const SEC = [['pay', /^pagos realizados/], ['buy', /^tus consumos(?! en cuotas)/], ['cuo', /^tus consumos en cuotas/], ['otr', /^otros cobros/]];
    for (const s of ['pay', 'buy', 'cuo', 'otr']) sums[s] = { PEN: 0, USD: 0 };
    for (const x of L) {
      const nt = norm(x.txt);
      if (/^detalle de pago del mes/.test(nt)) { started = true; continue; }
      if (!started) continue;
      if (/^informacion sobre tu tarjeta/.test(nt)) break;
      if (/^tu estado de cuenta anterior/.test(nt)) { sec = 'prev'; continue; }
      const hit = SEC.find((s) => s[1].test(nt) && x.it[0].x < 70);
      if (hit) { sec = hit[0]; continue; }
      if (/^subtotal/.test(nt)) { if (sec && sec !== 'prev') sub[sec] = col(x.it); continue; }
      if (/^pago del mes/.test(nt)) { total = col(x.it); sec = ''; continue; }
      if (/^pago minimo del mes/.test(nt)) { minPay = col(x.it); continue; }
      if (sec === 'prev') { if (/^deb[ií]as/.test(nt)) Object.assign(prev, col(x.it)); continue; }
      if (!sec) continue;
      const dm = /^(\d{1,2})-([A-Za-zÁ-ú]{3})$/.exec(x.it[0].str.trim());
      if (!dm || x.it[0].x > 70 || !MES[norm(dm[2])]) continue;                       // no es una fila con fecha (cabeceras, titular de la tarjeta…)
      const a = col(x.it.slice(1)), mo = MES[norm(dm[2])], y = f.y === e.y ? f.y : (mo >= f.m ? f.y : e.y);
      let date = y + '-' + pad(mo) + '-' + pad(+dm[1]);
      const descIt = []; for (const i of x.it.slice(1)) { if (/^[\d.,%\/ -]+$/.test(i.str.trim())) break; descIt.push(i.str); }
      let desc = descIt.join(' ').replace(/\s+/g, ' ').trim();
      if (!desc) { out.skipped.unreadable++; continue; }
      if (sec === 'cuo') {                                                              // fecha = compra original; la cuota se paga este ciclo
        const nums = x.it.slice(1).filter((i) => /^\d{3}$/.test(i.str.trim()));
        const pact = nums[0] ? +nums[0].str : 0, por = nums[1] ? +nums[1].str : 0;
        desc = desc.replace(/\s*\([^)]*$/, '').replace(/\s*\(PASE A CUOT\)?/i, '').trim();
        if (pact && por && pact >= por) desc += ' · cuota ' + (pact - por + 1) + ' de ' + pact;
        date = out.period.to;
      }
      let any = false;
      for (const cur of ['PEN', 'USD']) {
        const v = a[cur]; if (v == null) continue;
        if (!v) { if (cur === 'PEN' || a.PEN == null) out.skipped.zero++; continue; }
        any = true; sums[sec][cur] = r2(sums[sec][cur] + v);
        out.items.push({ line: ++line, date, desc, amount: sec === 'pay' ? Math.abs(v) : -Math.abs(v), cur });
      }
      if (!any && a.PEN == null && a.USD == null) out.skipped.unreadable++;
    }
    /* Pagos: el PDF los imprime negativos, así que la suma de pagos del PDF es negativa; el subtotal = deuda anterior + pagos. */
    const pays = {}; for (const cur of ['PEN', 'USD']) pays[cur] = -out.items.filter((i) => i.cur === cur && i.amount > 0).reduce((s, i) => s + i.amount, 0);
    const main = out.items.some((i) => i.cur === 'PEN') || !out.items.some((i) => i.cur === 'USD') ? 'PEN' : 'USD'; out.cur = main;
    const have = !!(total && sub.pay && prev.PEN != null);
    const rowsOk = (cur) => {
      if (!sub.pay || prev[cur] == null || sub.pay[cur] == null) return false;
      let ok = near(r2((prev[cur] || 0) + pays[cur]), sub.pay[cur]);
      for (const s of ['buy', 'cuo', 'otr']) { const st = sub[s] ? sub[s][cur] : null; if (st == null) { if (sums[s][cur]) ok = false; } else if (!near(st, sums[s][cur])) ok = false; }
      let st = 0; for (const s of ['pay', 'buy', 'cuo', 'otr']) if (sub[s] && sub[s][cur] != null) st += sub[s][cur];
      return ok && total && total[cur] != null && near(r2(st), total[cur]);
    };
    if (minPay && minPay.PEN != null) card.minPayment = minPay.PEN;
    const buys = ['buy', 'cuo', 'otr'].reduce((s, k) => s + sums[k][main], 0);
    out.check = { have, prev: prev[main], end: debt != null && main === 'PEN' ? debt : total ? total[main] : null, totalCharges: have ? r2(['buy', 'cuo', 'otr'].reduce((s, k) => s + ((sub[k] && sub[k][main]) || 0), 0)) : null,
      totalCredits: have ? r2(-pays[main]) : null, sumCharges: r2(buys), sumCredits: r2(-pays[main]), running: true, ok: have ? rowsOk('PEN') && rowsOk('USD') : null };
    return out;
  }
  return { id: 'interbank-tarjeta', bank: 'interbank', label: 'Interbank · Tarjeta de crédito', detect, read };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaInterbankTarjeta;
