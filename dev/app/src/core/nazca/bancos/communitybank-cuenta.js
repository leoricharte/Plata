/* ---------- Nazca · Community Bank, N.A. (CBNA) · Estado de cuenta corriente (PDF) ----------
 * Lee el estado de "CBNA SIMPLY CHECKING" (y cuentas parecidas del mismo formato). Probado con UN estado real de una cuenta casi sin movimientos
 * (un solo abono) y con el fixture inventado dev/tests/pdf/community-bank.pdf; con una cuenta de muchos movimientos conviene revisar.
 * Diseño que espera: "Statement Date", "Primary Account: XXXXXX5858", resumen (Previous Balance, Deposits/Credits, Checks/Debits, Service Charge, Interest Paid,
 * Ending Balance), "Statement Dates 9/17/26 thru 10/18/26" y la tabla "Date · Description · Credits/Debits · Balance" (fecha mm/dd, SIN año).
 * El monto de la tabla viene sin signo: el signo sale de cómo cambia la columna Balance (sube → abono, baja → cargo).
 * Salida de read(): { bank, kind:'corriente', label, cur, account:{ last4 }, period, items:[{ line, date, desc, amount, cur, balance }], skipped, check } */
const NazcaCommunityBank = (() => {
  const pad = (n) => String(n).padStart(2, '0');
  const r2 = (n) => Math.round(n * 100) / 100;
  const near = (a, b) => Math.abs(a - b) < 0.005;
  const num = (s) => { const m = /^\(?-?\$?[\d,]+\.\d{2}\)?-?$/.test(String(s).trim()) ? String(s).trim() : null; if (!m) return null; const neg = /^\(|^-|-$/.test(m); return r2((neg ? -1 : 1) * parseFloat(m.replace(/[^\d.]/g, ''))); };
  const text = (doc) => doc.pages.map((p) => p.items.map((i) => i.str).join(' ')).join(' ').replace(/\s+/g, ' ');

  function detect(doc) {
    if (!doc || !doc.pages || !doc.pages.length) return 0;
    const t = text(doc);
    return /CBNA|Community Bank/i.test(t) && /Previous Balance/i.test(t) && /Deposits\/Credits/i.test(t) && /Checks\/Debits/i.test(t) && /Ending Balance/i.test(t) && /Statement Dates/i.test(t) ? 1 : 0;
  }

  function read(doc) {
    if (!detect(doc)) return null;
    const pdf = typeof NazcaPDF !== 'undefined' ? NazcaPDF : require('../pdf.js');
    const t = text(doc);
    const out = { bank: 'communitybank', kind: 'corriente', label: 'Community Bank · Cuenta corriente', cur: 'USD', account: { last4: '' }, period: null, items: [], skipped: { unreadable: 0, zero: 0 }, check: null };
    const l4 = /Primary Account:?\s*X*(\d{4})/i.exec(t); if (l4) out.account.last4 = l4[1];
    const pm = /Statement Dates\s*(\d{1,2})\/(\d{1,2})\/(\d{2,4})\s*thru\s*(\d{1,2})\/(\d{1,2})\/(\d{2,4})/i.exec(t);
    if (!pm) return Object.assign(out, { error: 'period' });
    const yy = (y) => (+y < 100 ? 2000 + +y : +y);
    const f = { m: +pm[1], d: +pm[2], y: yy(pm[3]) }, e = { m: +pm[4], d: +pm[5], y: yy(pm[6]) };
    out.period = { from: f.y + '-' + pad(f.m) + '-' + pad(f.d), to: e.y + '-' + pad(e.m) + '-' + pad(e.d) };

    const sm = {}; const first = doc.pages[0];
    for (const l of pdf.lines(first, 3)) {
      const it = l.items.map((i) => i.str.trim()).filter(Boolean);
      for (const [k, re] of [['prev', /^Previous Balance$/i], ['cred', /^Deposits\/Credits$/i], ['deb', /^Checks\/Debits$/i], ['fee', /^Service Charge$/i], ['int', /^Interest Paid$/i], ['end', /^Ending Balance$/i]]) {
        const i = it.findIndex((x) => re.test(x)); if (i >= 0 && it[i + 1] != null && num(it[i + 1]) != null) sm[k] = num(it[i + 1]);
      }
      const c = it.findIndex((x) => /^Deposits\/Credits$/i.test(x)); if (c > 0 && /^\d+$/.test(it[c - 1])) sm.nCred = +it[c - 1];
      const d = it.findIndex((x) => /^Checks\/Debits$/i.test(x)); if (d > 0 && /^\d+$/.test(it[d - 1])) sm.nDeb = +it[d - 1];
    }

    /* Descripciones largas: el estado las parte en varias líneas; la primera puede quedar ARRIBA de la fecha (empieza con un código tipo "POS CRE 0215 05/16/26 …")
     * y el resto debajo. Una línea que empieza con ese código abre una descripción nueva (va a la próxima fila sin texto); las demás continúan la fila anterior. */
    const START = /^[A-Z][A-Za-z\/]{1,3}(?: [A-Z\/]{2,4})? \d{4} \d{2}\/\d{2}\/\d{2}\b/, rows = [];
    let buf = [], inTable = false;
    for (const page of doc.pages) for (const l of pdf.lines(page, 3)) {
      const it = l.items, head = it.map((i) => i.str).join(' ');
      if (/Credits\/Debits/i.test(head) && /Balance/i.test(head)) { inTable = true; continue; }
      if (!inTable || /Branch Phone|^Page:/i.test(head.trim())) continue;
      const dm = /^(\d{1,2})\/(\d{1,2})$/.exec(it[0].str.trim());
      if (dm && it[0].x <= 70 && it.length >= 3 && num(it[it.length - 1].str) != null && num(it[it.length - 2].str) != null) {
        const inline = it.slice(1, -2).map((i) => i.str).join(' ').replace(/\s+/g, ' ').trim();
        let desc = inline; if (!desc) { desc = buf.join(' '); buf = []; }
        rows.push({ m: +dm[1], d: +dm[2], amt: num(it[it.length - 2].str), bal: num(it[it.length - 1].str), desc: [desc] });
      } else {
        const txt = head.replace(/\s+/g, ' ').trim(); if (!txt) continue;
        if (START.test(txt) || !rows.length || buf.length) buf.push(txt); else rows[rows.length - 1].desc.push(txt);
      }
    }
    const tidy = (x) => x.replace(/^[A-Z][A-Za-z\/]{1,3}(?: [A-Z\/]{2,4})? \d{4} \d{2}\/\d{2}\/\d{2} \d+\s*/, '').replace(/\s*C#\d+\s*$/, '').replace(/\s+/g, ' ').trim();
    let line = 0, run = sm.prev == null ? null : sm.prev, running = sm.prev != null, sumC = 0, sumD = 0;
    for (const r of rows) {
      const desc = tidy(r.desc.join(' ')) || tidy(r.desc.join(' ')) || 'Movimiento'; if (!r.desc.join('').trim()) { out.skipped.unreadable++; continue; }
      const y = f.y === e.y ? f.y : (r.m >= f.m ? f.y : e.y);                                        // diciembre → enero
      const date = y + '-' + pad(r.m) + '-' + pad(r.d);
      const mag = Math.abs(r.amt); let amount;
      if (run != null && near(run + mag, r.bal)) amount = mag; else if (run != null && near(run - mag, r.bal)) amount = -mag;
      else { running = false; amount = r.amt < 0 ? -mag : (/refund|deposit|credit|interest|reversal|transfer from|payroll/i.test(desc) ? mag : -mag); }
      if (!amount) { out.skipped.zero++; continue; }
      run = r.bal; if (amount > 0) sumC += amount; else sumD += -amount;
      out.items.push({ line: ++line, date, desc, amount, cur: 'USD', balance: r.bal });
    }
    sumC = r2(sumC); sumD = r2(sumD);
    const have = sm.prev != null && sm.end != null && sm.cred != null && sm.deb != null;
    const fee = sm.fee || 0, intr = sm.int || 0;
    out.check = { have, prev: sm.prev == null ? null : sm.prev, end: sm.end == null ? null : sm.end, totalCharges: sm.deb == null ? null : sm.deb + fee, totalCredits: sm.cred == null ? null : sm.cred + intr, sumCharges: sumD, sumCredits: sumC, running,
      ok: have ? near(sumC, sm.cred + intr) && near(sumD, Math.abs(sm.deb) + fee) && near(r2(sm.prev + sumC - sumD), sm.end) && running : null };
    return out;
  }
  return { id: 'communitybank-cuenta', bank: 'communitybank', label: 'Community Bank · Cuenta corriente', detect, read };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaCommunityBank;
