/* ---------- Nazca · Seen · Estado de cuenta de tarjeta de crédito (PDF) ----------
 * Lee el "Credit Card Statement" de Seen Credit Card (Seen by Snap Finance). Construido con un estado real (datos cambiados en las pruebas).
 * Cómo está armado: página 1 con "Bill Period: 08/05/2026 - 09/04/2026", "Account Number *0204", el resumen (Previous Balance, Payments, Other Credits, Purchases,
 * Interest Charged, Fee Charged, New Balance, Credit Limit) y una tabla con Card Account Number · Statement Date · New Balance · Minimum Amount Due · Payment Due Date;
 * página 2 "Account Activity" con secciones: Payments, Refunds, and Other Credits · Purchases · Fees · Interest Charged, cada fila con
 * Posted Date · Transaction Date · Description · Card Ending In · Amount (todo positivo: el signo lo da la sección). Página 3: tasa anual (APR) de las compras.
 * Para Plata: abonos y reembolsos → positivos; compras, comisiones e intereses → negativos (gasto). Los intereses no traen fecha: se usa la del cierre del periodo.
 * "Cuadra": Previous Balance − pagos y créditos + compras + intereses + comisiones = New Balance, y cada total del resumen igual a la suma de sus filas.
 * Salida de read(): { bank:'seen', kind:'tarjeta', label, cur:'USD', account:{ last4 }, period, card:{ apr, dueDate, dueDay, minPayment, limit }, items, skipped, check } */
const NazcaSeen = (() => {
  const pad = (n) => String(n).padStart(2, '0');
  const r2 = (n) => Math.round(n * 100) / 100;
  const near = (a, b) => Math.abs(a - b) < 0.005;
  const D = /^(\d{2})\/(\d{2})\/(\d{4})$/;
  const iso = (m) => m[3] + '-' + m[1] + '-' + m[2];
  const money = (s) => { const m = /^(-)?\$([\d,]+\.\d{2})$/.exec(String(s).trim()); return m ? r2((m[1] ? -1 : 1) * parseFloat(m[2].replace(/,/g, ''))) : null; };
  const lineText = (l) => l.items.map((i) => i.str).join(' ').replace(/\s+/g, ' ').trim();

  function detect(doc) {
    if (!doc || !doc.pages || !doc.pages.length) return 0;
    const t = doc.pages.map((p) => p.items.map((i) => i.str).join(' ')).join(' ');
    return /Seen Credit Card/i.test(t) && /Credit Card Statement/i.test(t) && /Bill Period/i.test(t) && /Posted Date/i.test(t) && /Previous Balance/i.test(t) ? 1 : 0;
  }

  function read(doc) {
    if (!detect(doc)) return null;
    const pdf = typeof NazcaPDF !== 'undefined' ? NazcaPDF : require('../pdf.js');
    const L = doc.pages.map((p) => pdf.lines(p, 3));
    const all = L.map((ls) => ls.map(lineText).join(' ')).join(' ').replace(/[−–]/g, '-');
    const out = { bank: 'seen', kind: 'tarjeta', label: 'Seen · Tarjeta de crédito', cur: 'USD', account: { last4: '' }, period: null, card: {}, items: [], skipped: { unreadable: 0, zero: 0 }, check: null };
    const l4 = /Account Number \*(\d{4})/i.exec(all); if (l4) out.account.last4 = l4[1];
    const bp = /Bill Period:\s*(\d{2})\/(\d{2})\/(\d{4}) - (\d{2})\/(\d{2})\/(\d{4})/.exec(all);
    if (!bp) return Object.assign(out, { error: 'period' });
    out.period = { from: bp[3] + '-' + bp[1] + '-' + bp[2], to: bp[6] + '-' + bp[4] + '-' + bp[5] };

    const g = (re) => { const m = re.exec(all); return m ? money(m[1]) : null; };
    const sm = { prev: g(/Previous Balance\s+(\$[\d,]+\.\d{2})/), pay: g(/Payments\s+(\$[\d,]+\.\d{2})/), oth: g(/Other Credits\s+(\$[\d,]+\.\d{2})/), buy: g(/Purchases\s+(\$[\d,]+\.\d{2})/),
      int: g(/Interest Charged\s+(\$[\d,]+\.\d{2})/), fee: g(/Fee Charged\s+(\$[\d,]+\.\d{2})/), end: g(/New Balance\s+(\$[\d,]+\.\d{2})/) };
    const lim = g(/Credit Limit\s+(\$[\d,]+\.\d{2})/); if (lim != null) out.card.limit = lim;
    const apr = /Purchases\s+(\d{1,3}\.\d{1,2})%/.exec(all); if (apr) out.card.apr = parseFloat(apr[1]);
    const first = L[0] || []; const hi = first.findIndex((l) => /Card Account Number/.test(lineText(l)) && /Payment Due Date/.test(lineText(l)));
    if (hi >= 0 && first[hi + 1]) { const its = first[hi + 1].items.map((i) => i.str), ds = its.filter((s) => D.test(s)), ms = its.map(money).filter((v) => v !== null);
      if (ds.length >= 2) { const m = D.exec(ds[ds.length - 1]); out.card.dueDate = iso(m); out.card.dueDay = +m[2]; } if (ms.length >= 2) out.card.minPayment = ms[1]; }

    let sec = '', line = 0; const sums = { cr: 0, buy: 0, fee: 0, int: 0 };
    for (const ls of L.slice(1)) for (const l of ls) {
      const t = lineText(l);
      if (/^Payments, Refunds, and Other Credits$/i.test(t)) { sec = 'cr'; continue; }
      if (/^Purchases$/i.test(t)) { sec = 'buy'; continue; }
      if (/^Fees$/i.test(t)) { sec = 'fee'; continue; }
      if (/^Interest Charged$/i.test(t)) { sec = 'int'; continue; }
      if (/^2026 Totals|^Interest Charge Calculation/i.test(t)) { sec = ''; continue; }
      if (!sec) continue;
      const amt = l.items.slice().reverse().find((i) => money(i.str) !== null); if (!amt) continue;
      const v = money(amt.str), d1 = D.exec(l.items[0].str), d2 = l.items[1] && D.exec(l.items[1].str);
      let date, desc;
      if (d1) { date = iso(d2 || d1); desc = l.items.filter((i, k) => k > (d2 ? 1 : 0) && i !== amt && !/^\*\d{4}$/.test(i.str)).map((i) => i.str).join(' ').replace(/\s+/g, ' ').trim(); }
      else if (sec === 'int' && /^Interest Charge/i.test(l.items[0].str)) { date = out.period.to; desc = l.items[0].str; }
      else continue;
      if (!desc) { out.skipped.unreadable++; continue; }
      if (!v) { out.skipped.zero++; continue; }
      sums[sec] = r2(sums[sec] + Math.abs(v));
      out.items.push({ line: ++line, date, desc, amount: sec === 'cr' ? Math.abs(v) : -Math.abs(v), cur: 'USD' });
    }
    const have = ['prev', 'pay', 'oth', 'buy', 'int', 'fee', 'end'].every((k) => sm[k] != null);
    out.check = { have, prev: sm.prev, end: sm.end, totalCharges: sm.buy, totalCredits: have ? r2(sm.pay + sm.oth) : null, sumCharges: sums.buy, sumCredits: sums.cr, running: true,
      ok: have ? near(sums.cr, sm.pay + sm.oth) && near(sums.buy, sm.buy) && near(sums.int, sm.int) && near(sums.fee, sm.fee) && near(r2(sm.prev - sm.pay - sm.oth + sm.buy + sm.int + sm.fee), sm.end) : null };
    return out;
  }
  return { id: 'seen-tarjeta', bank: 'seen', label: 'Seen · Tarjeta de crédito', detect, read };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaSeen;
