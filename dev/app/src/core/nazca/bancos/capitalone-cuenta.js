/* ---------- Nazca · Capital One 360 · Estado de cuenta de cheques/ahorros (PDF) ----------
 * Lee el "bank statement" mensual de una cuenta Capital One 360 (Checking). Probado con UN estado real (una sola cuenta, ~20 movimientos) y con el fixture
 * inventado dev/tests/pdf/capital-one-cuenta.pdf. Si el estado trae varias cuentas (p. ej. Checking y Savings) no se lee: conviene revisar.
 * Diseño que espera: "STATEMENT PERIOD · Aug 1 - Aug 31, 2025", "360 Checking...8622" y la tabla "DATE · DESCRIPTION · CATEGORY · AMOUNT · BALANCE" con
 * "Opening Balance" y "Closing Balance"; cada fila trae el monto CON signo ("+ $1,018.47" / "- $169.64") y el saldo corrido. Fecha "Aug 6" sin año.
 * Hay descripciones de dos líneas: la primera línea puede quedar ARRIBA de la fila con fecha ("ATM Withdrawal - … SAN") y la segunda ABAJO ("FRANCISCO, CA").
 * Para Plata: "+" → positivo, "-" → negativo. "Cuadra": saldo anterior + abonos − cargos = saldo final, y cada fila cuadra con su saldo corrido.
 * Salida de read(): { bank, kind:'corriente', label, cur, account:{ last4 }, period, items:[{ line, date, desc, amount, cur, balance }], skipped, check } */
const NazcaCapitalOneCuenta = (() => {
  const MES = { jan: 1, feb: 2, mar: 3, apr: 4, may: 5, jun: 6, jul: 7, aug: 8, sep: 9, oct: 10, nov: 11, dec: 12 };
  const pad = (n) => String(n).padStart(2, '0'), r2 = (n) => Math.round(n * 100) / 100, near = (a, b) => Math.abs(a - b) < 0.005;
  const text = (doc) => doc.pages.map((p) => p.items.map((i) => i.str).join(' ')).join(' ').replace(/\s+/g, ' ');
  const money = (s) => { const m = /^([+-])?\s?\$\s?([\d,]+\.\d{2})$/.exec(String(s).replace(/[−–]/g, '-').trim()); return m ? r2((m[1] === '-' ? -1 : 1) * parseFloat(m[2].replace(/,/g, ''))) : null; };
  const START = /^(ATM|Debit|Digital|Deposit|Withdrawal|Zelle|Monthly|Check|ACH|Transfer|Wire|Direct|Interest|Fee|Refund|Payment|POS|Bill|Online|External|Mobile|Overdraft|Cash|Credit|Purchase|Service)\b/i;

  function detect(doc) {
    if (!doc || !doc.pages || !doc.pages.length) return 0;
    const t = text(doc);
    return /Capital One/i.test(t) && /STATEMENT PERIOD/i.test(t) && /Opening Balance/i.test(t) && /Closing Balance/i.test(t) && /DATE\s+DESCRIPTION\s+CATEGORY\s+AMOUNT\s+BALANCE/i.test(t) ? 1 : 0;
  }

  function read(doc) {
    if (!detect(doc)) return null;
    const pdf = typeof NazcaPDF !== 'undefined' ? NazcaPDF : require('../pdf.js');
    const t = text(doc);
    const out = { bank: 'capitalone', kind: 'corriente', label: 'Capital One · Cuenta de cheques', cur: 'USD', account: { last4: '' }, period: null, items: [], skipped: { unreadable: 0, zero: 0 }, check: null };
    const l4 = /\.{2,}\s*(\d{4})\b/.exec(t); if (l4) out.account.last4 = l4[1];
    const pm = /([A-Za-z]{3})[a-z]* (\d{1,2}) - ([A-Za-z]{3})[a-z]* (\d{1,2}), (\d{4})/.exec(t);
    if (!pm || !MES[pm[1].toLowerCase()] || !MES[pm[3].toLowerCase()]) return Object.assign(out, { error: 'period' });
    const f = { m: MES[pm[1].toLowerCase()], d: +pm[2] }, e = { m: MES[pm[3].toLowerCase()], d: +pm[4], y: +pm[5] }, fy = f.m > e.m ? e.y - 1 : e.y;
    out.period = { from: fy + '-' + pad(f.m) + '-' + pad(f.d), to: e.y + '-' + pad(e.m) + '-' + pad(e.d) };

    let prev = null, end = null, run = null, running = true, line = 0, sumC = 0, sumD = 0, prefix = '', last = null, seenHead = false, closed = false;
    for (const page of doc.pages) for (const l of pdf.lines(page, 3)) {
      if (closed) break;
      const its = l.items.map((i) => ({ x: i.x, s: String(i.str).replace(/\s+/g, ' ').trim() })).filter((i) => i.s);
      const joined = its.map((i) => i.s).join(' ');
      if (/^DATE DESCRIPTION CATEGORY AMOUNT BALANCE/i.test(joined)) { seenHead = true; continue; }
      if (!seenHead) continue;
      const dm = its[0] && its[0].x < 90 ? /^([A-Za-z]{3}) (\d{1,2})$/.exec(its[0].s) : null;
      if (!dm) {
        if (/^(Fees Summary|Page \d+ of)/i.test(joined)) { closed = /^Fees Summary/i.test(joined) ? true : closed; continue; }
        if (its.length === 1 && its[0].x > 90 && its[0].x < 300 && /[A-Za-z]/.test(joined) && !/^(TOTAL|Total|PERIOD|DATE)/.test(joined)) {   // descripción repartida en dos líneas
          if (START.test(joined) || !last) prefix = (prefix ? prefix + ' ' : '') + joined; else last.desc = (last.desc + ' ' + joined).replace(/\s+/g, ' ').trim();
        }
        continue;
      }
      const mo = MES[dm[1].toLowerCase()]; if (!mo) continue;
      const amtIt = its.find((i) => i.x > 380 && i.x < 480 && /[$]/.test(i.s)), balIt = its.filter((i) => i.x >= 480).pop(), descIt = its.find((i) => i.x >= 90 && i.x < 340);
      const bal = balIt ? money(balIt.s) : null;
      if (descIt && /^Opening Balance$/i.test(descIt.s)) { prev = bal; run = bal; prefix = ''; continue; }
      if (descIt && /^Closing Balance$/i.test(descIt.s)) { end = bal; prefix = ''; closed = true; continue; }
      const amount = amtIt ? money(amtIt.s) : null;
      if (amount == null || bal == null) { out.skipped.unreadable++; prefix = ''; continue; }
      let desc = ((descIt ? descIt.s : prefix) || '').replace(/\s+/g, ' ').trim(); if (descIt && prefix) desc = (prefix + ' ' + desc).trim(); prefix = '';
      if (!desc) { out.skipped.unreadable++; continue; }
      if (!amount) { out.skipped.zero++; continue; }
      if (run != null && !near(r2(run + amount), bal)) running = false;
      run = bal; if (amount > 0) sumC += amount; else sumD += -amount;
      const y = f.m > e.m && mo >= f.m ? e.y - 1 : e.y, date = y + '-' + pad(mo) + '-' + pad(+dm[2]);
      last = { line: ++line, date, desc, amount, cur: 'USD', balance: bal }; out.items.push(last);
    }
    sumC = r2(sumC); sumD = r2(sumD);
    const have = prev != null && end != null;
    out.check = { have, prev, end, totalCharges: sumD, totalCredits: sumC, sumCharges: sumD, sumCredits: sumC, running, ok: have ? running && near(r2(prev + sumC - sumD), end) : null };
    return out;
  }
  return { id: 'capitalone-cuenta', bank: 'capitalone', label: 'Capital One · Cuenta de cheques', detect, read };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaCapitalOneCuenta;
