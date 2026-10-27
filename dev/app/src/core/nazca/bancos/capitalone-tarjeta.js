/* ---------- Nazca · Capital One · Estado de cuenta de tarjeta de crédito (PDF) ----------
 * Lee el "Statement" de una tarjeta de crédito Capital One. Probado con 9 estados reales (abr–dic 2025, en español con copia en inglés) y con documentos inventados (dev/tests/pdf/capital-one-*.pdf);
 * con diseños distintos habrá que revisar las posiciones y los textos.
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

  /* Los estados en español traen la misma información dos veces: primero la copia en español («Página 1 de 6») y después la copia en inglés («Page 4 of 6»). Se lee solo la copia en inglés, si no, todo saldría duplicado.
   * Las páginas sin número (texto legal) pertenecen a la copia de la página numerada anterior. Un estado sin copia en español queda igual. */
  function soloIngles(pages) {
    const lang = []; let cur = null;
    for (const p of pages) {
      const t = p.items.map((i) => i.str).join(' ');
      if (/\bPage \d+ of \d+/i.test(t)) cur = 'en'; else if (/\bPágina \d+ de \d+/i.test(t)) cur = 'es';
      lang.push(cur);
    }
    return lang.includes('en') && lang.includes('es') ? pages.filter((p, i) => lang[i] !== 'es') : pages;
  }

  function detect(doc) {
    if (!doc || !doc.pages || !doc.pages.length) return 0;
    const t = doc.pages.map((p) => p.items.map((i) => i.str).join(' ')).join(' ');
    return /Capital One/i.test(t) && /(Trans|Post) Date/i.test(t) && /Previous Balance/i.test(t) && /New Balance/i.test(t) ? 1 : 0;
  }

  function read(doc) {
    if (!detect(doc)) return null;
    const pdf = typeof NazcaPDF !== 'undefined' ? NazcaPDF : require('../pdf.js');
    doc = { pages: soloIngles(doc.pages) };
    const all = doc.pages.map((p) => p.items.map((i) => i.str).join(' ')).join(' ').replace(/[−–]/g, '-').replace(/\s+/g, ' ');
    const out = { bank: 'capitalone', kind: 'tarjeta', label: 'Capital One · Tarjeta de crédito', cur: 'USD', account: { last4: '' }, period: null, items: [], skipped: { unreadable: 0, zero: 0 }, check: null };
    const l4 = /ending in (\d{4})/i.exec(all); if (l4) out.account.last4 = l4[1];
    /* El periodo: "Statement period: Mar 1, 2026 - Mar 31, 2026" (diseño de prueba) o, en los estados reales, "Jun 16, 2026 - Jul 16, 2026 | 31 days in Billing Cycle" sin título. */
    const pm = /Statement period:?\s*([A-Za-z]{3})[a-z]* (\d{1,2}), (\d{4}) - ([A-Za-z]{3})[a-z]* (\d{1,2}), (\d{4})/i.exec(all) || /([A-Za-z]{3})[a-z]* (\d{1,2}), (\d{4}) - ([A-Za-z]{3})[a-z]* (\d{1,2}), (\d{4})[\s|]*\d+ days in Billing Cycle/i.exec(all);
    if (!pm || !MES[pm[1].toLowerCase()] || !MES[pm[4].toLowerCase()]) return Object.assign(out, { error: 'period' });
    const f = { m: MES[pm[1].toLowerCase()], d: +pm[2], y: +pm[3] }, t = { m: MES[pm[4].toLowerCase()], d: +pm[5], y: +pm[6] };
    out.period = { from: f.y + '-' + pad(f.m) + '-' + pad(f.d), to: t.y + '-' + pad(t.m) + '-' + pad(t.d) };

    const sm = {}; const grab = (k, re) => { const m = re.exec(all); if (m) sm[k] = money(m[1]); };
    grab('prev', new RegExp('Previous Balance\\s*' + AMT, 'i')); grab('pay', new RegExp('Payments(?: & Credits)?\\s*' + AMT, 'i')); grab('buy', new RegExp('(?:Purchases|Transactions)\\s*\\+?\\s*' + AMT, 'i')); grab('oc', new RegExp('Other Credits\\s*' + AMT, 'i')); grab('int', new RegExp('Interest Charged\\s*\\+?\\s*' + AMT, 'i'));
    grab('fees', new RegExp('Fees(?: & Interest| Charged)?\\s*\\+?\\s*' + AMT, 'i')); grab('end', new RegExp('New Balance\\s*=?\\s*' + AMT, 'i'));

    /* Datos de la tarjeta: tasa anual, fecha de pago, pago mínimo y línea de crédito (si el estado los trae). */
    const card = {}, apr = /(?:Purchase )?APR:?\s*(\d{1,3}(?:\.\d{1,2})?)\s?%/i.exec(all) || /Purchases\s+(\d{1,3}\.\d{1,2})\s?%/i.exec(all), dd = /Payment Due Date:?\s*([A-Za-z]{3})[a-z]* (\d{1,2}), (\d{4})/i.exec(all);
    const mp = new RegExp('Minimum Payment Due:?\\s*' + AMT, 'i').exec(all), cl = new RegExp('Credit Limit:?\\s*' + AMT, 'i').exec(all);
    /* en los estados reales los importes de "Minimum Payment Due" van en la línea de abajo, bajo el título */
    const under = (re) => { for (const page of doc.pages) { const ls = pdf.lines(page, 3); for (let i = 0; i < ls.length; i++) { const it = ls[i].items.find((x) => re.test(x.str)); if (!it) continue; for (let k = i + 1; k <= i + 3 && k < ls.length; k++) { const a = ls[k].items.find((x) => /^\$\s?[\d,]+\.\d{2}$/.test(x.str) && Math.abs(x.x - it.x) < 40); if (a) return money(a.str); } } } return null; };
    const mp2 = under(/^Minimum Payment Due$/), cl2 = (() => { for (const page of doc.pages) for (const l of pdf.lines(page, 3)) { const t2 = lineText(l), m = new RegExp('^Credit Limit ' + AMT + '$', 'i').exec(t2); if (m) return money(m[1]); } return null; })();
    if (apr) card.apr = parseFloat(apr[1]);
    if (dd && MES[dd[1].toLowerCase()]) { card.dueDate = dd[3] + '-' + pad(MES[dd[1].toLowerCase()]) + '-' + pad(+dd[2]); card.dueDay = +dd[2]; }
    if (mp2 != null) card.minPayment = Math.abs(mp2); else if (mp) card.minPayment = Math.abs(money(mp[1])); if (cl) card.limit = Math.abs(money(cl[1])); else if (cl2 != null) card.limit = Math.abs(cl2);
    out.card = card;
    let line = 0, sumBuy = 0, sumPay = 0, sumFee = 0, sec = '';
    for (const page of doc.pages) for (const l of pdf.lines(page, 3)) {
      const s = lineText(l);
      if (/^Fees$/i.test(s)) sec = 'fees'; else if (/^(Interest Charged|Transactions|Totals Year-to-Date)$/i.test(s)) sec = '';   /* la tabla «Fees» (cuota de membresía, cargo por atraso) va aparte de las compras */
      const m = ROW.exec(s); if (!m) continue;
      const mo = MES[m[1].toLowerCase()]; if (!mo) continue;
      const desc = m[5].replace(/\s*AuthDate \d{1,2}-[A-Za-z]{3}$/i, '').replace(/\s+/g, ' ').trim(); if (!desc || !/[A-Za-z]/.test(desc) || /^(previous|new|total|minimum|payments|purchases|fees)/i.test(desc)) continue;
      const v = money(m[6]); if (!v) { out.skipped.zero++; continue; }
      const y = f.y === t.y ? f.y : (mo >= f.m ? f.y : t.y);                              // diciembre → enero: los meses del inicio son del año anterior
      const date = y + '-' + pad(mo) + '-' + pad(+m[2]);
      const amount = v > 0 ? -v : Math.abs(v);                                          // compra (+) → gasto; pago o crédito (−) → ingreso
      if (v > 0) { if (sec === 'fees') sumFee += v; else sumBuy += v; } else sumPay += Math.abs(v);
      out.items.push({ line: ++line, date, desc, amount, cur: 'USD' });
    }
    /* Estados reales: los intereses del ciclo vienen en el resumen (sin fecha propia): entran como un gasto a la fecha de cierre. */
    const intr = sm.int > 0 ? sm.int : 0; if (intr) { out.items.push({ line: ++line, date: out.period.to, desc: 'Interest charge', amount: -intr, cur: 'USD' }); }
    sumBuy = r2(sumBuy); sumPay = r2(sumPay); sumFee = r2(sumFee);
    const have = sm.prev != null && sm.end != null && sm.buy != null && sm.pay != null;
    out.check = { have, prev: sm.prev == null ? null : sm.prev, end: sm.end == null ? null : sm.end, totalCharges: sm.buy == null ? null : sm.buy, totalCredits: sm.pay == null ? null : r2(Math.abs(sm.pay) + Math.abs(sm.oc || 0)), sumCharges: sumBuy, sumCredits: sumPay, running: true,
      ok: have ? near(sumBuy, sm.buy) && near(sumFee, sm.fees || 0) && near(sumPay, Math.abs(sm.pay) + Math.abs(sm.oc || 0)) && near(r2(sm.prev + sumBuy + sumFee + intr - sumPay), sm.end) : null };
    return out;
  }
  return { id: 'capitalone-tarjeta', bank: 'capitalone', label: 'Capital One · Tarjeta de crédito', detect, read };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaCapitalOne;
