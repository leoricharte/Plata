/* ---------- Nazca · Capital One · Estado de cuenta de tarjeta de crédito (PDF) ----------
 * Lee el "Statement" de una tarjeta de crédito Capital One. OJO: este lector está armado sobre un documento de PRUEBA inventado (dev/tests/pdf/capital-one-*.pdf),
 * no sobre un estado real; con uno real habrá que revisar las posiciones y los textos antes de darlo por probado.
 * Diseño que espera: marca "Capital One"; "Statement period: Mar 1, 2026 - Mar 31, 2026"; "Account ending in 4242";
 * resumen (Previous Balance, Payments, Purchases, Fees & Interest, New Balance) y una tabla "Trans Date · Post Date · Description · Amount"
 * donde las compras son positivas y los pagos/créditos negativos.
 * Para Plata: compra → negativa (gasto), pago o crédito → positiva. "Cuadra": Previous Balance + Purchases + Fees − Payments = New Balance.
 * Salida de read(): { bank, kind:'tarjeta', label, cur, account:{ last4 }, period:{ from, to }, items:[{ line, date, desc, amount, cur }], skipped, check } */
const NazcaCapitalOne = (() => {
  const MES = { jan: 1, feb: 2, mar: 3, apr: 4, may: 5, jun: 6, jul: 7, aug: 8, sep: 9, oct: 10, nov: 11, dec: 12 };
  const pad = (n) => String(n).padStart(2, '0');
  const near = (a, b) => Math.abs(a - b) < 0.005;
  const r2 = (n) => Math.round(n * 100) / 100;
  const money = (s) => r2(parseFloat(String(s).replace(/[$,\s]/g, '').replace(/^\((.*)\)$/, '-$1')));
  const lineText = (l) => l.items.map((i) => i.str).join(' ').replace(/[−–]/g, '-').replace(/\s+/g, ' ').trim();
  const AMT = '(-?\\s?\\$\\s?[\\d,]+\\.\\d{2}|\\(\\$[\\d,]+\\.\\d{2}\\))';
  const ROW = new RegExp('^([A-Za-z]{3}) (\\d{1,2}) (?:([A-Za-z]{3}) (\\d{1,2}) )?(.+?) ' + AMT + '$');

  function detect(doc) {
    if (!doc || !doc.pages || !doc.pages.length) return 0;
    const t = doc.pages.map((p) => p.items.map((i) => i.str).join(' ')).join(' ');
    return /Capital One/i.test(t) && /Trans Date/i.test(t) && /Post Date/i.test(t) && /Previous Balance/i.test(t) && /New Balance/i.test(t) ? 1 : 0;
  }

  function read(doc) {
    if (!detect(doc)) return null;
    const pdf = typeof NazcaPDF !== 'undefined' ? NazcaPDF : require('../pdf.js');
    const all = doc.pages.map((p) => p.items.map((i) => i.str).join(' ')).join(' ').replace(/[−–]/g, '-').replace(/\s+/g, ' ');
    const out = { bank: 'capitalone', kind: 'tarjeta', label: 'Capital One · Tarjeta de crédito', cur: 'USD', account: { last4: '' }, period: null, items: [], skipped: { unreadable: 0, zero: 0 }, check: null };
    const l4 = /ending in (\d{4})/i.exec(all); if (l4) out.account.last4 = l4[1];
    const pm = /Statement period:?\s*([A-Za-z]{3})[a-z]* (\d{1,2}), (\d{4}) - ([A-Za-z]{3})[a-z]* (\d{1,2}), (\d{4})/i.exec(all);
    if (!pm || !MES[pm[1].toLowerCase()] || !MES[pm[4].toLowerCase()]) return Object.assign(out, { error: 'period' });
    const f = { m: MES[pm[1].toLowerCase()], d: +pm[2], y: +pm[3] }, t = { m: MES[pm[4].toLowerCase()], d: +pm[5], y: +pm[6] };
    out.period = { from: f.y + '-' + pad(f.m) + '-' + pad(f.d), to: t.y + '-' + pad(t.m) + '-' + pad(t.d) };

    const sm = {}; const grab = (k, re) => { const m = re.exec(all); if (m) sm[k] = money(m[1]); };
    grab('prev', new RegExp('Previous Balance\\s*' + AMT, 'i')); grab('pay', new RegExp('Payments(?: & Credits)?\\s*' + AMT, 'i')); grab('buy', new RegExp('Purchases\\s*\\+?\\s*' + AMT, 'i'));
    grab('fees', new RegExp('Fees(?: & Interest| Charged)?\\s*\\+?\\s*' + AMT, 'i')); grab('end', new RegExp('New Balance\\s*' + AMT, 'i'));

    /* Datos de la tarjeta: tasa anual, fecha de pago, pago mínimo y línea de crédito (si el estado los trae). */
    const card = {}, apr = /(?:Purchase )?APR:?\s*(\d{1,3}(?:\.\d{1,2})?)\s?%/i.exec(all), dd = /Payment Due Date:?\s*([A-Za-z]{3})[a-z]* (\d{1,2}), (\d{4})/i.exec(all);
    const mp = new RegExp('Minimum Payment Due:?\\s*' + AMT, 'i').exec(all), cl = new RegExp('Credit Limit:?\\s*' + AMT, 'i').exec(all);
    if (apr) card.apr = parseFloat(apr[1]);
    if (dd && MES[dd[1].toLowerCase()]) { card.dueDate = dd[3] + '-' + pad(MES[dd[1].toLowerCase()]) + '-' + pad(+dd[2]); card.dueDay = +dd[2]; }
    if (mp) card.minPayment = Math.abs(money(mp[1])); if (cl) card.limit = Math.abs(money(cl[1]));
    out.card = card;
    let line = 0, sumBuy = 0, sumPay = 0;
    for (const page of doc.pages) for (const l of pdf.lines(page, 3)) {
      const s = lineText(l), m = ROW.exec(s); if (!m) continue;
      const mo = MES[m[1].toLowerCase()]; if (!mo) continue;
      const desc = m[5].replace(/\s+/g, ' ').trim(); if (!desc || !/[A-Za-z]/.test(desc) || /^(previous|new|total|minimum|payments|purchases|fees)/i.test(desc)) continue;
      const v = money(m[6]); if (!v) { out.skipped.zero++; continue; }
      const y = f.y === t.y ? f.y : (mo >= f.m ? f.y : t.y);                              // diciembre → enero: los meses del inicio son del año anterior
      const date = y + '-' + pad(mo) + '-' + pad(+m[2]);
      const amount = v > 0 ? -v : Math.abs(v);                                          // compra (+) → gasto; pago o crédito (−) → ingreso
      if (v > 0) sumBuy += v; else sumPay += Math.abs(v);
      out.items.push({ line: ++line, date, desc, amount, cur: 'USD' });
    }
    sumBuy = r2(sumBuy); sumPay = r2(sumPay);
    const have = sm.prev != null && sm.end != null && sm.buy != null && sm.pay != null;
    out.check = { have, prev: sm.prev == null ? null : sm.prev, end: sm.end == null ? null : sm.end, totalCharges: sm.buy == null ? null : sm.buy, totalCredits: sm.pay == null ? null : Math.abs(sm.pay), sumCharges: sumBuy, sumCredits: sumPay, running: true,
      ok: have ? near(sumBuy, sm.buy) && near(sumPay, Math.abs(sm.pay)) && near(r2(sm.prev + sumBuy + (sm.fees || 0) - sumPay), sm.end) : null };
    return out;
  }
  return { id: 'capitalone-tarjeta', bank: 'capitalone', label: 'Capital One · Tarjeta de crédito', detect, read };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaCapitalOne;
