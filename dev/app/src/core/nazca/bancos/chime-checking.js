/* ---------- Nazca · Chime · Estado de cuenta de la cuenta corriente (PDF) ----------
 * Lee el "Checking Account Statement" de Chime (emitido por The Bancorp Bank). Construido con un estado real (datos cambiados en las pruebas).
 * Cómo está armado: página 1 con el número de cuenta, "Statement period (September 01, 2026 - September 30, 2026)" y el resumen (Beginning balance,
 * Deposits, ATM Withdrawals, Purchases, Adjustments, Transfers, Round Up Transfers, Fees, SpotMe Tips, Ending balance); luego la tabla
 * TRANSACTION DATE · DESCRIPTION · TYPE · AMOUNT · NET AMOUNT · SETTLEMENT DATE, con fechas m/d/aaaa y montos con signo ($40.00, -$40.00).
 * Cada movimiento puede traer una segunda línea con el detalle del comercio (se ignora). Se usa el monto neto.
 * "Cuadra": saldo inicial + suma de movimientos = saldo final, y los depósitos y las comisiones coinciden con el resumen.
 * Salida de read(): { bank:'chime', kind:'corriente', label, cur:'USD', account:{ last4 }, period, items:[{ line, date, desc, type, amount, cur }], skipped, check } */
const NazcaChime = (() => {
  const pad = (n) => String(n).padStart(2, '0');
  const r2 = (n) => Math.round(n * 100) / 100;
  const near = (a, b) => Math.abs(a - b) < 0.005;
  const money = (s) => { const m = /^(-)?\$([\d,]+\.\d{2})$/.exec(String(s).replace(/[−–]/g, '-').trim()); return m ? r2((m[1] ? -1 : 1) * parseFloat(m[2].replace(/,/g, ''))) : null; };
  const DATE = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/;
  const MONTHS = ['january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december'];
  const text = (doc) => doc.pages.map((p) => p.items.map((i) => i.str).join(' ')).join(' ').replace(/\s+/g, ' ');

  function detect(doc) {
    if (!doc || !doc.pages || !doc.pages.length) return 0;
    const t = text(doc);
    return /Checking Account Statement/i.test(t) && /TRANSACTION DATE/.test(t) && /NET AMOUNT/.test(t) && /SETTLEMENT DATE/.test(t) && /Chime|The Bancorp Bank/i.test(t) ? 1 : 0;
  }

  function read(doc) {
    if (!detect(doc)) return null;
    const pdf = typeof NazcaPDF !== 'undefined' ? NazcaPDF : require('../pdf.js');
    const t = text(doc);
    const out = { bank: 'chime', kind: 'corriente', label: 'Chime · Cuenta corriente', cur: 'USD', account: { last4: '' }, period: null, items: [], skipped: { unreadable: 0, zero: 0 }, check: null };
    const ac = /Account number\s+(\d{6,})/i.exec(t); if (ac) out.account.last4 = ac[1].slice(-4);
    const pm = /\(\s*([A-Za-z]+) (\d{1,2}), (\d{4}) - ([A-Za-z]+) (\d{1,2}), (\d{4})\s*\)/.exec(t);
    if (!pm || MONTHS.indexOf(pm[1].toLowerCase()) < 0 || MONTHS.indexOf(pm[4].toLowerCase()) < 0) return Object.assign(out, { error: 'period' });
    out.period = { from: pm[3] + '-' + pad(MONTHS.indexOf(pm[1].toLowerCase()) + 1) + '-' + pad(+pm[2]), to: pm[6] + '-' + pad(MONTHS.indexOf(pm[4].toLowerCase()) + 1) + '-' + pad(+pm[5]) };

    const sum = {}; const grab = (k, re) => { const m = re.exec(t); if (m) sum[k] = money(m[1]); };
    grab('prev', /Beginning balance on [A-Za-z]+ \d{1,2}, \d{4}\s+(-?\$[\d,]+\.\d{2})/); grab('end', /Ending balance on [A-Za-z]+ \d{1,2}, \d{4}\s+(-?\$[\d,]+\.\d{2})/);
    grab('dep', /Deposits\s+(-?\$[\d,]+\.\d{2})/); grab('fees', /Fees\s+(-?\$[\d,]+\.\d{2})/);

    let line = 0, cols = null, total = 0, dep = 0, fees = 0;
    for (const page of doc.pages) for (const l of pdf.lines(page, 3)) {
      const its = l.items, hd = its.find((i) => i.str === 'TRANSACTION DATE');
      if (hd) { const g = (n) => its.find((i) => i.str === n); const a = g('AMOUNT'), n = g('NET AMOUNT'), d = g('DESCRIPTION'), ty = g('TYPE'), st = g('SETTLEMENT DATE'); if (a && n && d && ty && st) cols = { desc: d.x, type: ty.x, amt: a.x, net: n.x, set: st.x }; continue; }
      if (!cols || !its.length) continue;
      const d = DATE.exec(its[0].str); if (!d || its[0].x > cols.desc) continue;
      const inCol = (lo, hi) => its.filter((i) => i.x >= lo - 3 && i.x < hi - 3);
      const desc = inCol(cols.desc, cols.type).map((i) => i.str).join(' ').replace(/\s+/g, ' ').trim();
      const type = inCol(cols.type, cols.amt - 20).map((i) => i.str).join(' ').trim();
      const netIt = its.find((i) => i.x >= cols.net - 20 && i.x < cols.set - 3 && money(i.str) !== null) || its.find((i) => i.x >= cols.amt - 20 && i.x < cols.net - 20 && money(i.str) !== null);
      if (!desc || !netIt) { out.skipped.unreadable++; continue; }
      const v = money(netIt.str); if (!v) { out.skipped.zero++; continue; }
      total = r2(total + v); if (/^Deposit$/i.test(type)) dep = r2(dep + v); if (/^Fee$/i.test(type)) fees = r2(fees + v);
      out.items.push({ line: ++line, date: d[3] + '-' + pad(+d[1]) + '-' + pad(+d[2]), desc, type, amount: v, cur: 'USD' });
    }
    const have = sum.prev != null && sum.end != null;
    out.check = { have, prev: sum.prev == null ? null : sum.prev, end: sum.end == null ? null : sum.end, totalCharges: null, totalCredits: sum.dep == null ? null : sum.dep, sumCharges: null, sumCredits: dep, running: true,
      ok: have ? near(r2(sum.prev + total), sum.end) && (sum.dep == null || near(dep, sum.dep)) && (sum.fees == null || near(fees, sum.fees)) : null };
    return out;
  }
  return { id: 'chime-checking', bank: 'chime', label: 'Chime · Cuenta corriente', detect, read };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaChime;
