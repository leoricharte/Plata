/* ---------- Nazca · TJX Rewards (Synchrony) · Estado de cuenta de tarjeta de crédito (PDF) ----------
 * Lee el estado de cuenta de la tarjeta TJX Rewards (Mastercard emitida por Synchrony Bank; la de T.J. Maxx, Marshalls y HomeGoods).
 * Construido con 4 estados reales (dic 2025 – abr 2026, datos cambiados en las pruebas).
 * Cómo está armado: encabezado "31 Day Billing Cycle from 12/12/2025 to 01/11/2026" y "Account Number ending in 2642"; "Account Summary"
 * (Previous Balance, Payments, Purchases/Debits, Interest Charges, New Balance, Credit Limit); "Transaction Detail" con filas
 * "MM/DD · Reference # · Description · Amount" (pagos con "-$", compras con "$"), una línea suelta "PURCHASE" bajo algunas compras (se ignora)
 * y "Total Fees/Interest Charged This Period". Las fechas no traen año: se deduce del ciclo de facturación.
 * Para Plata: compra → gasto (negativo); pago o crédito → ingreso (positivo); intereses y cuotas → gasto.
 * "Cuadra": anterior − pagos + compras + cuotas + intereses = nuevo, y las compras y los pagos impresos igualan la suma de las filas.
 * Salida de read(): { bank:'tjx', kind:'tarjeta', label, cur:'USD', account:{ last4 }, period, card:{ apr, dueDate, dueDay, minPayment, limit }, items, skipped, check } */
const NazcaTJX = (() => {
  const pad = (n) => String(n).padStart(2, '0');
  const r2 = (n) => Math.round(n * 100) / 100;
  const near = (a, b) => Math.abs(a - b) < 0.005;
  const money = (s) => { const m = /^(-)?\s?\$?\s?([\d,]+\.\d{2})$/.exec(String(s).replace(/[−–]/g, '-').trim()); return m ? r2((m[1] ? -1 : 1) * parseFloat(m[2].replace(/,/g, ''))) : null; };
  const lineText = (l) => l.items.map((i) => i.str).join(' ').replace(/[−–]/g, '-').replace(/\s+/g, ' ').trim();

  function detect(doc) {
    if (!doc || !doc.pages || !doc.pages.length) return 0;
    const t = doc.pages.map((p) => p.items.map((i) => i.str).join(' ')).join(' ');
    return /TJX Rewards/i.test(t) && /Billing Cycle from \d{2}\/\d{2}\/\d{4} to \d{2}\/\d{2}\/\d{4}/i.test(t) && /Transaction Detail/i.test(t) ? 1 : 0;
  }

  function read(doc) {
    if (!detect(doc)) return null;
    const pdf = typeof NazcaPDF !== 'undefined' ? NazcaPDF : require('../pdf.js');
    const L = doc.pages.map((p) => pdf.lines(p, 3));
    const all = L.map((ls) => ls.map(lineText).join(' ')).join(' ');
    const out = { bank: 'tjx', kind: 'tarjeta', label: 'TJX Rewards · Tarjeta de crédito', cur: 'USD', account: { last4: '' }, period: null, card: {}, items: [], skipped: { unreadable: 0, zero: 0 }, check: null };
    const l4 = /ending in (\d{4})/i.exec(all); if (l4) out.account.last4 = l4[1];
    const pm = /Billing Cycle from (\d{2})\/(\d{2})\/(\d{4}) to (\d{2})\/(\d{2})\/(\d{4})/i.exec(all);
    if (!pm) return Object.assign(out, { error: 'period' });
    const f = { m: +pm[1], d: +pm[2], y: +pm[3] }, t = { m: +pm[4], d: +pm[5], y: +pm[6] };
    out.period = { from: f.y + '-' + pad(f.m) + '-' + pad(f.d), to: t.y + '-' + pad(t.m) + '-' + pad(t.d) };

    /* resumen de la primera página: el importe del título va justo después (a la derecha, en la misma línea, está el límite de crédito) */
    const sm = {};
    const first = (re) => { for (const l of L[0] || []) { const s = lineText(l), m = re.exec(s); if (m) return r2(parseFloat(m[1].replace(/,/g, ''))); } return null; };
    const fixed = { prev: first(/^Previous Balance as of \d{2}\/\d{2}\/\d{4} \$([\d,]+\.\d{2})/i), end: first(/^New Balance as of \d{2}\/\d{2}\/\d{4} \$([\d,]+\.\d{2})/i), pay: first(/^Payments - ([\d,]+\.\d{2})/i), buy: first(/^Purchases\/Debits \+ ([\d,]+\.\d{2})/i), int: first(/^Interest Charges \+ ([\d,]+\.\d{2})/i), fees: first(/^Fees Charged \+ ([\d,]+\.\d{2})/i), cred: first(/^(?:Other )?Credits - ([\d,]+\.\d{2})/i) };
    for (const k of Object.keys(fixed)) if (fixed[k] != null) sm[k] = fixed[k];

    /* datos de la tarjeta */
    const apr = /Purchases\s+N\/A\s+(\d{1,3}\.\d{1,3})\s?%/i.exec(all), dd = /Payment Due Date:\s*(\d{2})\/(\d{2})\/(\d{4})/i.exec(all), mp = /Total Minimum Payment Due:\s*\$([\d,]+\.\d{2})/i.exec(all), cl = /Credit Limit\s*\$([\d,]+)/i.exec(all);
    if (apr) out.card.apr = parseFloat(apr[1]);
    if (dd) { out.card.dueDate = dd[3] + '-' + dd[1] + '-' + dd[2]; out.card.dueDay = +dd[2]; }
    if (mp) out.card.minPayment = r2(parseFloat(mp[1].replace(/,/g, '')));
    if (cl) out.card.limit = parseFloat(cl[1].replace(/,/g, ''));

    /* detalle: filas "MM/DD  referencia  descripción  importe" */
    let line = 0, sumBuy = 0, sumPay = 0, sumFee = 0, sumInt = 0, on = false;
    for (const ls of L) for (const l of ls) {
      const s = lineText(l);
      if (/^Transaction Detail/i.test(s)) on = true;
      if (!on) continue;
      if (/^(2026|20\d\d) Year-to-Date|^Interest Charge Calculation/i.test(s)) { on = false; continue; }
      const its = l.items.map((i) => String(i.str).trim()).filter(Boolean);
      if (its.length < 3 || !/^\d{2}\/\d{2}$/.test(its[0])) continue;
      const v = money(its[its.length - 1]); if (v == null) { out.skipped.unreadable++; continue; }
      let mid = its.slice(1, -1); if (mid.length > 1 && /^[A-Z0-9]{14,}$/.test(mid[0])) mid = mid.slice(1);   /* se quita el número de referencia */
      const desc = mid.join(' ').replace(/\s+/g, ' ').trim(); if (!desc) { out.skipped.unreadable++; continue; }
      if (!v) { out.skipped.zero++; continue; }                                         // «INTEREST CHARGE ON PURCHASES $0.00»
      const mo = +its[0].slice(0, 2), dy = +its[0].slice(3), y = f.y === t.y ? f.y : (mo >= f.m ? f.y : t.y);   // diciembre → enero: los meses del inicio son del año anterior
      const date = y + '-' + pad(mo) + '-' + pad(dy);
      const isInt = /^INTEREST CHARGE/i.test(desc), isFee = !isInt && v > 0 && /\b(LATE|ANNUAL|MEMBERSHIP|RETURNED PAYMENT|OVER ?LIMIT)\b.*\bFEE\b|^(LATE|ANNUAL|MEMBERSHIP) FEE/i.test(desc);
      if (v > 0) { if (isInt) sumInt += v; else if (isFee) sumFee += v; else sumBuy += v; } else sumPay += Math.abs(v);
      out.items.push({ line: ++line, date, desc, amount: v > 0 ? -v : Math.abs(v), cur: 'USD' });
    }
    sumBuy = r2(sumBuy); sumPay = r2(sumPay); sumFee = r2(sumFee); sumInt = r2(sumInt);
    const have = sm.prev != null && sm.end != null && sm.pay != null;
    out.check = { have, prev: sm.prev == null ? null : sm.prev, end: sm.end == null ? null : sm.end, totalCharges: r2((sm.buy || 0)), totalCredits: r2((sm.pay || 0) + (sm.cred || 0)), sumCharges: sumBuy, sumCredits: sumPay, running: true,
      ok: have ? near(sumBuy, sm.buy || 0) && near(sumPay, (sm.pay || 0) + (sm.cred || 0)) && near(sumFee, sm.fees || 0) && near(sumInt, sm.int || 0) && near(r2(sm.prev - sumPay + sumBuy + sumFee + sumInt), sm.end) : null };
    return out;
  }
  return { id: 'tjx-tarjeta', bank: 'tjx', label: 'TJX Rewards · Tarjeta de crédito', detect, read };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaTJX;
