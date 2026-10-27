/* ---------- Nazca · Apple Card · Estado de cuenta (PDF) ----------
 * Lee el "Statement" mensual de Apple Card (emitida por Goldman Sachs). Construido con un estado real (datos cambiados en las pruebas).
 * Cómo está armado: página 1 con "Sep 1 — Sep 30, 2026", "Your September Balance / Minimum Payment Due / Payment Due By" y el resumen (Previous Total Balance, Total Balance);
 * luego "Payments" (Date · Description · Amount, con los pagos en NEGATIVO), "Transactions" (Date · Description · Daily Cash % · Daily Cash $ · Amount, compras en positivo),
 * "Interest Charged" (Interest charge $55.52, sin fecha) y la tabla de tasa (Annual Percentage Rate (APR) 27.74 % (variable)).
 * Para Plata: pagos → positivos; compras e intereses → negativos; un pago devuelto ("REVERSAL") queda negativo y una devolución de compra positiva.
 * "Cuadra": saldo anterior − pagos + cargos + intereses = saldo total, y "Total charges, credits and returns" igual a la suma de las compras.
 * Salida de read(): { bank:'applecard', kind:'tarjeta', label, cur:'USD', account:{ last4:'' }, period, card:{ apr, dueDate, dueDay, minPayment }, items, skipped, check } */
const NazcaAppleCard = (() => {
  const MES = { jan: 1, feb: 2, mar: 3, apr: 4, may: 5, jun: 6, jul: 7, aug: 8, sep: 9, oct: 10, nov: 11, dec: 12 };
  const pad = (n) => String(n).padStart(2, '0');
  const r2 = (n) => Math.round(n * 100) / 100;
  const near = (a, b) => Math.abs(a - b) < 0.005;
  const D = /^(\d{2})\/(\d{2})\/(\d{4})$/;
  const money = (s) => { const m = /^(-)?\$([\d,]+\.\d{2})$/.exec(String(s).replace(/[−–]/g, '-').trim()); return m ? r2((m[1] ? -1 : 1) * parseFloat(m[2].replace(/,/g, ''))) : null; };
  const lineText = (l) => l.items.map((i) => i.str).join(' ').replace(/\s+/g, ' ').trim();

  function detect(doc) {
    if (!doc || !doc.pages || !doc.pages.length) return 0;
    const t = doc.pages.map((p) => p.items.map((i) => i.str).join(' ')).join(' ');
    return /Apple Card Customer/i.test(t) && /Apple Card is issued by/i.test(t) && /Total Balance/i.test(t) ? 1 : 0;
  }

  function read(doc) {
    if (!detect(doc)) return null;
    const pdf = typeof NazcaPDF !== 'undefined' ? NazcaPDF : require('../pdf.js');
    const L = doc.pages.map((p) => pdf.lines(p, 3));
    const all = L.map((ls) => ls.map(lineText).join(' ')).join(' ').replace(/[−–]/g, '-');
    const out = { bank: 'applecard', kind: 'tarjeta', label: 'Apple Card · Tarjeta de crédito', cur: 'USD', account: { last4: '' }, period: null, card: {}, items: [], skipped: { unreadable: 0, zero: 0 }, check: null };
    const pm = /([A-Za-z]{3}) (\d{1,2}) [—–-] ([A-Za-z]{3}) (\d{1,2}), (\d{4})/.exec(all);
    if (!pm || !MES[pm[1].toLowerCase()] || !MES[pm[3].toLowerCase()]) return Object.assign(out, { error: 'period' });
    const y2 = +pm[5], y1 = MES[pm[1].toLowerCase()] > MES[pm[3].toLowerCase()] ? y2 - 1 : y2;
    out.period = { from: y1 + '-' + pad(MES[pm[1].toLowerCase()]) + '-' + pad(+pm[2]), to: y2 + '-' + pad(MES[pm[3].toLowerCase()]) + '-' + pad(+pm[4]) };

    const g = (re) => { const m = re.exec(all); return m ? money(m[1]) : null; };
    const sm = { prev: g(/Previous Total Balance\s+(\$[\d,]+\.\d{2})/), end: g(/(?<!Previous )Total Balance\s+(\$[\d,]+\.\d{2})/), chg: g(/Total charges, credits and returns\s+(\$[\d,]+\.\d{2})/), int: g(/Total interest for this month\s+(\$[\d,]+\.\d{2})/), pay: g(/Total payments for this period\s+(-?\$[\d,]+\.\d{2})/) };
    const apr = /Annual Percentage Rate \(APR\)\s+(\d{1,3}\.\d{1,2})\s?%/i.exec(all); if (apr) out.card.apr = parseFloat(apr[1]);
    const due = /\$[\d,]+\.\d{2}\s+\$([\d,]+\.\d{2})\s+([A-Z][a-z]{2}) (\d{1,2}), (\d{4})/.exec(all);
    if (due && MES[due[2].toLowerCase()]) { out.card.minPayment = parseFloat(due[1].replace(/,/g, '')); out.card.dueDate = due[4] + '-' + pad(MES[due[2].toLowerCase()]) + '-' + pad(+due[3]); out.card.dueDay = +due[3]; }

    let sec = '', line = 0, sPay = 0, sChg = 0, sInt = 0, lastDate = '';
    for (const ls of L) for (const l of ls) {
      const its = l.items, t = lineText(l);
      if (/^Payments$/.test(t)) { sec = 'pay'; continue; } if (/^Transactions$/.test(t)) { sec = 'chg'; continue; } if (/^Interest Charged$/.test(t)) { sec = 'int'; continue; } if (/^(Daily Cash|Interest Charges|Legal)$/.test(t)) { sec = ''; continue; }
      if (!sec) continue;
      const am = its[its.length - 1], v = money(am.str); if (v === null) continue;
      const d = D.exec(its[0].str);
      if (sec === 'int') { if (/^Interest charge/i.test(its[0].str) && its.length === 2) { sInt = r2(sInt + v); out.items.push({ line: ++line, date: out.period.to, desc: its[0].str, amount: -v, cur: 'USD' }); } continue; }
      /* «Daily Cash Adjustment»: al devolver una compra, Apple retira el Daily Cash que había dado; sale en una línea sin fecha bajo la devolución, cuenta como cargo y suma al total impreso */
      if (sec === 'chg' && !d && /^Daily Cash Adjustment$/.test(its[0].str) && v > 0 && lastDate) { sChg = r2(sChg + v); out.items.push({ line: ++line, date: lastDate, desc: 'Daily Cash Adjustment', amount: -v, cur: 'USD' }); continue; }
      if (!d || its[0].x > 60 || its.length < 3) continue;
      const desc = its.slice(1, -1).filter((i) => i.x < 410).map((i) => i.str).join(' ').replace(/\s+/g, ' ').trim();
      if (!desc) { out.skipped.unreadable++; continue; }
      if (!v) { out.skipped.zero++; continue; }
      const amount = sec === 'pay' ? -v : -v;          // pagos vienen negativos (→ +) y compras positivas (→ −): en los dos casos el signo se invierte
      if (sec === 'pay') sPay = r2(sPay + v); else sChg = r2(sChg + v);
      lastDate = d[3] + '-' + d[1] + '-' + d[2];
      out.items.push({ line: ++line, date: lastDate, desc, amount, cur: 'USD' });
    }
    const have = sm.prev != null && sm.end != null && sm.chg != null && sm.int != null && sm.pay != null;
    out.check = { have, prev: sm.prev, end: sm.end, totalCharges: sm.chg, totalCredits: sm.pay == null ? null : Math.abs(sm.pay), sumCharges: sChg, sumCredits: Math.abs(sPay), running: true,
      ok: have ? near(sChg, sm.chg) && near(sPay, sm.pay) && near(sInt, sm.int) && near(r2(sm.prev + sPay + sChg + sInt), sm.end) : null };
    return out;
  }
  return { id: 'applecard-tarjeta', bank: 'applecard', label: 'Apple Card · Tarjeta de crédito', detect, read };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaAppleCard;
