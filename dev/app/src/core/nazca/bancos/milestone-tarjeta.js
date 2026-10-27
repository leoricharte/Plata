/* ---------- Nazca · Milestone Mastercard (Concora Credit) · Estado de cuenta de tarjeta de crédito (PDF) ----------
 * Lee el estado de cuenta de la tarjeta Milestone Mastercard (la administra Concora Credit; mymilestonecard.com).
 * Construido con 6 estados reales (may – oct 2026, datos cambiados en las pruebas).
 * Cómo está armado: arriba "Account number ending in 1088", "Statement Closing Date October 26, 2026" y "Days in Billing Cycle 30";
 * "ACCOUNT SUMMARY" (Previous Balance, − Payments & Credits, + Purchases & Other Charges, + FEES CHARGED, + INTEREST CHARGED, = New Balance);
 * y "TRANSACTIONS" con filas "Tran Date · Post Date · Reference Number · Description · Amount" y, aparte, las secciones "FEES" e "INTEREST CHARGED".
 * OJO con los importes: el signo menos va DETRÁS ("8.02-" es un crédito: pago o reembolso de cashback) y no llevan "$". Las fechas no traen año (MM/DD):
 * se deduce de la fecha de cierre. El ciclo empieza el día de cierre menos los días del ciclo (el pago del 26/09 cae en el ciclo que cierra el 26/10).
 * Para Plata: compra, cuota mensual e intereses → gasto (negativo); pago o crédito (pago, cashback, interés devuelto) → ingreso (positivo).
 * "Cuadra": anterior − pagos y créditos + compras + cuotas + intereses = nuevo, y cada total del resumen iguala la suma de sus filas.
 * Salida de read(): { bank:'milestone', kind:'tarjeta', label, cur:'USD', account:{ last4 }, period, card:{ apr, dueDate, dueDay, minPayment, limit }, items, skipped, check } */
const NazcaMilestone = (() => {
  const MES = { january: 1, february: 2, march: 3, april: 4, may: 5, june: 6, july: 7, august: 8, september: 9, october: 10, november: 11, december: 12 };
  const pad = (n) => String(n).padStart(2, '0');
  const r2 = (n) => Math.round(n * 100) / 100;
  const near = (a, b) => Math.abs(a - b) < 0.005;
  const num = (s) => parseFloat(String(s).replace(/,/g, ''));
  const lineText = (l) => l.items.map((i) => i.str).join(' ').replace(/[−–]/g, '-').replace(/\s+/g, ' ').trim();
  const AMT = /^([\d,]+\.\d{2})(-)?$/;
  const iso = (y, m, d) => y + '-' + pad(m) + '-' + pad(d);

  function detect(doc) {
    if (!doc || !doc.pages || !doc.pages.length) return 0;
    const t = doc.pages.map((p) => p.items.map((i) => i.str).join(' ')).join(' ');
    return /mymilestonecard\.com|Milestone/i.test(t) && /Concora Credit/i.test(t) && /Days in Billing Cycle/i.test(t) && /Statement Closing Date/i.test(t) ? 1 : 0;
  }

  function read(doc) {
    if (!detect(doc)) return null;
    const pdf = typeof NazcaPDF !== 'undefined' ? NazcaPDF : require('../pdf.js');
    const L = doc.pages.map((p) => pdf.lines(p, 3));
    const all = L.map((ls) => ls.map(lineText).join(' ')).join(' ');
    const out = { bank: 'milestone', kind: 'tarjeta', label: 'Milestone · Tarjeta de crédito', cur: 'USD', account: { last4: '' }, period: null, card: {}, items: [], skipped: { unreadable: 0, zero: 0 }, check: null };
    const l4 = /Account number ending in (\d{4})/i.exec(all); if (l4) out.account.last4 = l4[1];
    const cm = /Statement Closing Date ([A-Za-z]+) (\d{1,2}), (\d{4})/i.exec(all), dc = /Days in Billing Cycle (\d{1,3})/i.exec(all);
    if (!cm || !MES[cm[1].toLowerCase()] || !dc) return Object.assign(out, { error: 'period' });
    const close = new Date(Date.UTC(+cm[3], MES[cm[1].toLowerCase()] - 1, +cm[2])), start = new Date(close.getTime() - (+dc[1]) * 86400000);
    out.period = { from: iso(start.getUTCFullYear(), start.getUTCMonth() + 1, start.getUTCDate()), to: iso(close.getUTCFullYear(), close.getUTCMonth() + 1, close.getUTCDate()) };
    const cmo = close.getUTCMonth() + 1, cy = close.getUTCFullYear();

    /* resumen: el menos va detrás del importe ("$0.12-" es un crédito) */
    const sm = {}, grab = (k, re) => { const m = re.exec(all); if (m) sm[k] = r2((m[2] ? -1 : 1) * num(m[1])); };
    grab('prev', /Previous Balance \$([\d,]+\.\d{2})(-)?/i); grab('pay', /Payments & Credits \$([\d,]+\.\d{2})(-)?/i); grab('buy', /Purchases & Other Charges \$([\d,]+\.\d{2})(-)?/i);
    grab('fees', /FEES CHARGED \$([\d,]+\.\d{2})(-)?/i); grab('int', /INTEREST CHARGED \$([\d,]+\.\d{2})(-)?/i); grab('end', /= New Balance \$([\d,]+\.\d{2})(-)?/i);
    if (sm.end == null) grab('end', /New Balance \$([\d,]+\.\d{2})(-)?/i);

    /* datos de la tarjeta */
    const cl = /Credit Limit \$([\d,]+\.\d{2})/i.exec(all), mp = /Minimum Payment Due \$([\d,]+\.\d{2})/i.exec(all), dd = /Payment Due Date ([A-Za-z]+) (\d{1,2}), (\d{4})/i.exec(all), apr = /Purchase APR is (\d{1,3}\.\d{1,3})\s?%/i.exec(all) || /Purchases (\d{1,3}\.\d{1,3})\s?%/i.exec(all);
    if (cl) out.card.limit = num(cl[1]);
    if (mp) out.card.minPayment = num(mp[1]);
    if (dd && MES[dd[1].toLowerCase()]) { out.card.dueDate = iso(+dd[3], MES[dd[1].toLowerCase()], +dd[2]); out.card.dueDay = +dd[2]; }
    if (apr) out.card.apr = parseFloat(apr[1]);

    /* filas: «MM/DD  MM/DD  [referencia]  descripción  importe». La sección (TRANSACTIONS, FEES, INTEREST CHARGED) dice de qué clase son. */
    let line = 0, sec = '', sumBuy = 0, sumPay = 0, sumFee = 0, sumInt = 0;
    for (const ls of L) for (const l of ls) {
      const s = lineText(l);
      if (/^TRANSACTIONS$/i.test(s)) { sec = 'buy'; continue; }
      if (/^FEES$/i.test(s)) { sec = 'fee'; continue; }
      if (/^INTEREST CHARGED$/i.test(s)) { sec = 'int'; continue; }
      if (/^(Totals 2026|Totals \d{4}|IMPORTANT ACCOUNT INFORMATION|INTEREST CHARGE CALCULATION)/i.test(s)) { sec = ''; continue; }
      if (!sec) continue;
      const its = l.items.map((i) => String(i.str).trim()).filter(Boolean);
      if (its.length < 4 || !/^\d{2}\/\d{2}$/.test(its[0]) || !/^\d{2}\/\d{2}$/.test(its[1])) continue;
      const am = AMT.exec(its[its.length - 1]); if (!am) { out.skipped.unreadable++; continue; }
      let mid = its.slice(2, -1); if (mid.length > 1 && /^[A-Z0-9]{14,}$/.test(mid[0])) mid = mid.slice(1);   /* se quita el número de referencia */
      const desc = mid.join(' ').replace(/\s+/g, ' ').trim(); if (!desc) { out.skipped.unreadable++; continue; }
      const v = r2((am[2] ? -1 : 1) * num(am[1])); if (!v) { out.skipped.zero++; continue; }   // «Interest Charge on Purchases 0.00»
      const mo = +its[0].slice(0, 2), dy = +its[0].slice(3), y = mo > cmo ? cy - 1 : cy;
      if (sec === 'fee') sumFee += v; else if (sec === 'int') sumInt += v; else if (v > 0) sumBuy += v; else sumPay += Math.abs(v);
      out.items.push({ line: ++line, date: iso(y, mo, dy), desc, amount: -v, cur: 'USD' });   // cargo (+) → gasto; crédito (−) → ingreso
    }
    sumBuy = r2(sumBuy); sumPay = r2(sumPay); sumFee = r2(sumFee); sumInt = r2(sumInt);
    const have = sm.prev != null && sm.end != null && sm.pay != null;
    out.check = { have, prev: sm.prev == null ? null : sm.prev, end: sm.end == null ? null : sm.end, totalCharges: r2(sm.buy || 0), totalCredits: r2(sm.pay || 0), sumCharges: sumBuy, sumCredits: sumPay, running: true,
      ok: have ? near(sumBuy, sm.buy || 0) && near(sumPay, sm.pay) && near(sumFee, sm.fees || 0) && near(sumInt, sm.int || 0) && near(r2(sm.prev - sumPay + sumBuy + sumFee + sumInt), sm.end) : null };
    return out;
  }
  return { id: 'milestone-tarjeta', bank: 'milestone', label: 'Milestone · Tarjeta de crédito', detect, read };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaMilestone;
