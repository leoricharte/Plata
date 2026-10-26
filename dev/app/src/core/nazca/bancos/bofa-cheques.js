/* ---------- Nazca · Bank of America · Estado de cuenta de cuenta de cheques (PDF) ----------
 * Lee el estado de una cuenta de cheques de Bank of America (por ejemplo "Adv SafeBalance Banking"). Construido con un estado real EN ESPAÑOL (datos cambiados en las pruebas);
 * los textos en inglés (Account summary, Beginning balance, Deposits and other additions…) están previstos pero NO se han probado con un estado real en inglés.
 * Cómo está armado: página 1 con "para el 23 de julio del 2025 al 20 de agosto del 2025", "Número de cuenta: 3252 0663 0470" y el "Resumen de la cuenta" (Saldo inicial,
 * Depósitos y otros agregados, Sustracciones de tarjeta de cajero automático (ATM) y de débito, Otras sustracciones, Cargos por servicio, Saldo final); luego tablas
 * Fecha (mm/dd/aa) · Descripción · Cantidad con los depósitos (sin signo) y las sustracciones (con "-"). Cada movimiento puede traer líneas extra de detalle (ID:…): se ignoran.
 * "Cuadra": saldo inicial + depósitos − sustracciones = saldo final, y los depósitos y las sustracciones igual al resumen.
 * Salida de read(): { bank:'bofa', kind:'corriente', label, cur:'USD', account:{ last4 }, period, items:[{ line, date, desc, amount, cur }], skipped, check } */
const NazcaBofA = (() => {
  const pad = (n) => String(n).padStart(2, '0');
  const r2 = (n) => Math.round(n * 100) / 100;
  const near = (a, b) => Math.abs(a - b) < 0.005;
  const AMT = /^-?\$?[\d,]+\.\d{2}$/;
  const money = (s) => { const t = String(s).replace(/[−–]/g, '-').trim(); if (!AMT.test(t)) return null; const neg = t[0] === '-'; return r2((neg ? -1 : 1) * parseFloat(t.replace(/[-$,]/g, ''))); };
  const ES = { enero: 1, febrero: 2, marzo: 3, abril: 4, mayo: 5, junio: 6, julio: 7, agosto: 8, septiembre: 9, setiembre: 9, octubre: 10, noviembre: 11, diciembre: 12 };
  const EN = { january: 1, february: 2, march: 3, april: 4, may: 5, june: 6, july: 7, august: 8, september: 9, october: 10, november: 11, december: 12 };
  const lineText = (l) => l.items.map((i) => i.str).join(' ').replace(/\s+/g, ' ').trim();
  const allText = (doc) => doc.pages.map((p) => p.items.map((i) => i.str).join(' ')).join(' ').replace(/\s+/g, ' ');

  function detect(doc) {
    if (!doc || !doc.pages || !doc.pages.length) return 0;
    const t = allText(doc);
    return /Bank of America/i.test(t) && /Resumen de la cuenta|Account summary/i.test(t) && /Saldo inicial|Beginning balance/i.test(t) && /Saldo final|Ending balance/i.test(t) ? 1 : 0;
  }

  function period(t) {
    let m = /(\d{1,2}) de ([a-záéíóú]+) (?:del? )?(\d{4}) al (\d{1,2}) de ([a-záéíóú]+) (?:del? )?(\d{4})/i.exec(t);
    if (m && ES[m[2].toLowerCase()] && ES[m[5].toLowerCase()]) return { from: m[3] + '-' + pad(ES[m[2].toLowerCase()]) + '-' + pad(+m[1]), to: m[6] + '-' + pad(ES[m[5].toLowerCase()]) + '-' + pad(+m[4]) };
    m = /([A-Za-z]+) (\d{1,2}), (\d{4}) (?:to|through|-) ([A-Za-z]+) (\d{1,2}), (\d{4})/i.exec(t);
    if (m && EN[m[1].toLowerCase()] && EN[m[4].toLowerCase()]) return { from: m[3] + '-' + pad(EN[m[1].toLowerCase()]) + '-' + pad(+m[2]), to: m[6] + '-' + pad(EN[m[4].toLowerCase()]) + '-' + pad(+m[5]) };
    return null;
  }
  /* Quita el prefijo de tipo y la fecha de compra del comercio: "PURCHASE 0723 AMAZON MKTPL*YN4" → "AMAZON MKTPL*YN4". */
  const tidy = (d) => d.replace(/^(?:MOBILE PURCHASE|PURCHASE|CHECKCARD|RECURRING CHECKCARD)\s+\d{4}\s+/i, '').replace(/\s+/g, ' ').trim() || d;

  function read(doc) {
    if (!detect(doc)) return null;
    const pdf = typeof NazcaPDF !== 'undefined' ? NazcaPDF : require('../pdf.js');
    const out = { bank: 'bofa', kind: 'corriente', label: 'Bank of America · Cuenta de cheques', cur: 'USD', account: { last4: '' }, period: null, items: [], skipped: { unreadable: 0, zero: 0 }, check: null };
    const t = allText(doc);
    const ac = /(?:N[uú]mero de cuenta|Account number):?\s*((?:\d{4} ?){2,4})/i.exec(t); if (ac) out.account.last4 = ac[1].replace(/\s/g, '').slice(-4);
    out.period = period(t); if (!out.period) return Object.assign(out, { error: 'period' });

    const sm = {};
    for (const l of pdf.lines(doc.pages[0], 3)) {
      const its = l.items, last = its[its.length - 1], v = last ? money(last.str) : null, s = lineText(l); if (v === null || its.length < 2) continue;
      if (/^(Saldo inicial|Beginning balance)/i.test(s)) sm.prev = v; else if (/^(Saldo final|Ending balance)/i.test(s)) sm.end = v;
      else if (/^(Dep[oó]sitos y otros agregados|Deposits and other additions)/i.test(s)) sm.dep = v;
      else if (/^(Sustracciones de tarjeta|ATM and debit card subtractions)/i.test(s)) sm.atm = v;
      else if (/^(Otras sustracciones|Other subtractions)/i.test(s)) sm.oth = v;
      else if (/^(Cargos por servicio|Service fees)/i.test(s)) sm.fee = v;
    }

    let line = 0, pos = 0, neg = 0;
    for (const page of doc.pages.slice(1)) for (const l of pdf.lines(page, 3)) {
      const its = l.items, d = /^(\d{2})\/(\d{2})\/(\d{2})$/.exec(its[0].str); if (!d || its[0].x > 60 || its.length < 3) continue;
      const am = its[its.length - 1], v = money(am.str); if (v === null || am.x < 400) { out.skipped.unreadable++; continue; }
      const desc = tidy(its.slice(1, -1).map((i) => i.str).join(' ')); if (!desc) { out.skipped.unreadable++; continue; }
      if (!v) { out.skipped.zero++; continue; }
      if (v > 0) pos = r2(pos + v); else neg = r2(neg + v);
      out.items.push({ line: ++line, date: '20' + d[3] + '-' + d[1] + '-' + d[2], desc, amount: v, cur: 'USD' });
    }
    const have = sm.prev != null && sm.end != null && sm.dep != null;
    const subs = r2((sm.atm || 0) + (sm.oth || 0) + (sm.fee || 0));
    out.check = { have, prev: sm.prev == null ? null : sm.prev, end: sm.end == null ? null : sm.end, totalCharges: have ? Math.abs(subs) : null, totalCredits: sm.dep == null ? null : sm.dep, sumCharges: Math.abs(neg), sumCredits: pos, running: true,
      ok: have ? near(pos, sm.dep) && near(neg, subs) && near(r2(sm.prev + pos + neg), sm.end) : null };
    return out;
  }
  return { id: 'bofa-cheques', bank: 'bofa', label: 'Bank of America · Cuenta de cheques', detect, read };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaBofA;
