/* ---------- Nazca · iO (Perú) · Estado de cuenta de la tarjeta de crédito (PDF) ----------
 * iO es la neobanco de Credicorp; su tarjeta Visa iO manda un estado de cuenta en PDF, protegido con el DNI. Probado con UN estado real (soles, sin cuotas)
 * y con el fixture inventado dev/tests/pdf/io-tarjeta.pdf. Las cuotas y los dólares se leen por el diseño de las tablas, pero no se probaron con un estado real.
 * Diseño que espera: "Tarjeta de Crédito iO del 29/07/2026 hasta el 25/08/2026", "**** **** **** 3909", la línea de crédito, "ÚLTIMO DÍA DE PAGO",
 * "Detalle de movimientos" (Abonos · Consumos directos · Consumos en cuotas; columnas SOLES / DÓLARES; fechas "06-AGO" sin año) y
 * "Resumen de movimientos" (saldo anterior, abonos, consumos, intereses, seguro, pago total y pago mínimo).
 * Para Plata: abono → positivo, consumo → negativo; los intereses, el seguro y las comisiones del resumen entran como un movimiento a la fecha de cierre.
 * "Cuadra": saldo anterior + consumos + intereses y cargos − abonos = pago total del mes. */
const NazcaIO = (() => {
  const MES = { ene: 1, feb: 2, mar: 3, abr: 4, may: 5, jun: 6, jul: 7, ago: 8, set: 9, sep: 9, oct: 10, nov: 11, dic: 12 };
  const pad = (n) => String(n).padStart(2, '0'), r2 = (n) => Math.round(n * 100) / 100, near = (a, b) => Math.abs(a - b) < 0.005;
  const norm = (t) => String(t || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
  const NUM = /^-?[\d,]+\.\d{2}$/, num = (s) => r2(parseFloat(String(s).replace(/[,\s]/g, '')));
  const flat = (doc) => doc.pages.map((p) => p.items.map((i) => i.str).join(' ')).join(' ').replace(/\s+/g, ' ');

  function detect(doc) {
    if (!doc || !doc.pages || !doc.pages.length) return 0;
    const t = norm(flat(doc));
    return /tarjeta de credito io\b/.test(t) && /detalle de movimientos/.test(t) && /ciclo de facturacion/.test(t) && /pago minimo/.test(t) ? 1 : 0;
  }

  function read(doc) {
    if (!detect(doc)) return null;
    const pdf = typeof NazcaPDF !== 'undefined' ? NazcaPDF : require('../pdf.js');
    const all = flat(doc);
    const out = { bank: 'io', kind: 'tarjeta', label: 'iO · Tarjeta de crédito', cur: 'PEN', account: { last4: '' }, period: null, items: [], skipped: { unreadable: 0, zero: 0 }, check: null, card: {} };
    const l4 = /\*{4} \*{4} \*{4} (\d{4})/.exec(all); if (l4) out.account.last4 = l4[1];
    const pm = /del (\d{2})\/(\d{2})\/(\d{4}) hasta el (\d{2})\/(\d{2})\/(\d{4})/i.exec(all);
    if (!pm) return Object.assign(out, { error: 'period' });
    const f = { d: +pm[1], m: +pm[2], y: +pm[3] }, e = { d: +pm[4], m: +pm[5], y: +pm[6] };
    out.period = { from: f.y + '-' + pad(f.m) + '-' + pad(f.d), to: e.y + '-' + pad(e.m) + '-' + pad(e.d) };
    const lines = []; doc.pages.forEach((pg) => pdf.lines(pg, 3).forEach((l) => lines.push(l)));
    const L = lines.map((l) => ({ it: l.items, txt: l.items.map((i) => i.str).join(' ').replace(/\s+/g, ' ').trim() }));

    /* Tarjeta: línea de crédito, tasa (TEA compensatoria), último día de pago y pago mínimo */
    const card = out.card, soles = (s) => { const m = /^S\/\s?([\d,]+\.\d{2})$/.exec(s); return m ? num(m[1]) : null; };
    const row3 = L.find((x) => x.it.length >= 3 && x.it.slice(0, 3).every((i) => soles(i.str) != null));
    if (row3) card.limit = soles(row3.it[0].str);
    const tea = /TEA de Inter[eé]s compensatorio\s*(\d{1,3}(?:\.\d{1,2})?)\s?%/i.exec(all); if (tea) card.apr = parseFloat(tea[1]);
    for (const x of L) { const m = /^(\d{1,2}) ([a-z]{3}) (\d{2})$/i.exec(x.txt); if (m && MES[m[2].toLowerCase()]) { card.dueDate = (2000 + +m[3]) + '-' + pad(MES[m[2].toLowerCase()]) + '-' + pad(+m[1]); card.dueDay = +m[1]; break; } }
    const iMin = L.findIndex((x) => /^pago minimo\b/.test(norm(x.txt)) && x.it.length <= 3);
    if (iMin >= 0) { const nx = L.slice(iMin + 1, iMin + 3).find((x) => x.it.length && soles(x.it[0].str) != null); if (nx) card.minPayment = soles(nx.it[0].str); }

    /* Movimientos: tablas con columnas SOLES / DÓLARES */
    let sec = '', bound = 495, sub = {}, line = 0; const sums = { PEN: { buy: 0, pay: 0 }, USD: { buy: 0, pay: 0 } };
    for (const x of L) {
      const nt = norm(x.txt);
      if (/^resumen de movimientos/.test(nt)) break;
      if (/^abonos$/.test(nt)) { sec = 'ab'; continue; }
      if (/^consumos directos/.test(nt)) { sec = 'dir'; continue; }
      if (/^consumos en cuotas/.test(nt)) { sec = 'cuo'; continue; }
      if (/^plan de cuotas/.test(nt)) { sec = ''; continue; }
      if (x.it.some((i) => /^FECHA$/.test(i.str))) { const d = x.it.find((i) => /^D[OÓ]LARES$/i.test(i.str)); if (d) bound = d.x - 14; continue; }
      if (!sec) continue;
      if (/^subtotal/.test(nt)) { const v = x.it.filter((i) => NUM.test(i.str)); if (v.length >= 2) sub[sec] = { PEN: num(v[0].str), USD: num(v[1].str) }; continue; }
      const dm = /^(\d{1,2})-([A-Za-zÁ-ú]{3})$/.exec(x.it[0].str.trim()); if (!dm || x.it[0].x > 70 || !MES[norm(dm[2])]) continue;
      const am = x.it.slice(1).filter((i) => NUM.test(i.str) && i.x >= bound - 60 && !(i.x < bound - 60));
      const amt = x.it.slice(1).filter((i) => NUM.test(i.str)); if (!amt.length) { out.skipped.unreadable++; continue; }
      const last = amt[amt.length - 1], cur = last.x >= bound ? 'USD' : 'PEN', v = Math.abs(num(last.str));
      const descIt = []; for (const i of x.it.slice(1)) { if (/^[\d.,%\/ -]+$/.test(i.str.trim())) break; descIt.push(i.str); }
      const desc = descIt.join(' ').replace(/\s+/g, ' ').trim(); if (!desc) { out.skipped.unreadable++; continue; }
      if (!v) { out.skipped.zero++; continue; }
      const mo = MES[norm(dm[2])], y = f.y === e.y ? f.y : (mo >= f.m ? f.y : e.y), date = y + '-' + pad(mo) + '-' + pad(+dm[1]);
      const credit = sec === 'ab'; if (credit) sums[cur].pay += v; else sums[cur].buy += v;
      out.items.push({ line: ++line, date, desc, amount: credit ? v : -v, cur });
    }

    /* Resumen del mes: "Tu pago del mes esta compuesto por" */
    const sm = { fees: { PEN: 0, USD: 0 }, rows: 0 }; let inSum = false;
    for (const x of L) {
      const nt = norm(x.txt);
      if (/tu pago del mes esta compuesto/.test(nt)) { inSum = true; continue; }
      if (!inSum) continue;
      const v = x.it.filter((i) => NUM.test(i.str)); if (v.length < 2) continue;
      const label = norm(x.it.filter((i) => !NUM.test(i.str) && !/^[+\-=]$/.test(i.str.trim())).map((i) => i.str).join(' ')), p = num(v[0].str), d = num(v[1].str), sign = (x.it[0].str.trim().match(/^[+\-=]$/) || [''])[0];
      sm.rows++;
      if (/saldo pendiente/.test(label)) sm.prev = { PEN: p, USD: d };
      else if (/abonos/.test(label)) sm.ab = { PEN: p, USD: d };
      else if (/consumos directos/.test(label)) sm.dir = { PEN: p, USD: d };
      else if (/consumos en cuotas/.test(label)) sm.cuo = { PEN: p, USD: d };
      else if (/pago total/.test(label)) sm.tot = { PEN: p, USD: d };
      else if (/pago minimo/.test(label)) sm.min = { PEN: p, USD: d };
      else if (sign === '+' || sign === '-') { /* intereses, seguro, comisiones… */
        const k = sign === '-' ? -1 : 1, nm = x.it.filter((i) => !NUM.test(i.str) && !/^[+\-=]$/.test(i.str.trim())).map((i) => i.str).join(' ').replace(/\s+/g, ' ').trim();
        [['PEN', p], ['USD', d]].forEach(([cur, val]) => { if (val) { sm.fees[cur] += k * val; out.items.push({ line: ++line, date: out.period.to, desc: nm.charAt(0) + nm.slice(1).toLowerCase(), amount: -k * val, cur }); } });
      }
    }
    if (card.minPayment == null && sm.min) card.minPayment = sm.min.PEN;
    const R = (n) => r2(n), main = out.items.some((i) => i.cur === 'PEN') || !out.items.some((i) => i.cur === 'USD') ? 'PEN' : 'USD'; out.cur = main;
    const have = !!(sm.prev && sm.tot && sm.ab && sm.dir);
    const chk = (cur) => { const buy = R(sums[cur].buy), pay = R(sums[cur].pay), fee = R(sm.fees[cur]); return near(pay, sm.ab[cur]) && near(buy, sm.dir[cur] + (sm.cuo ? sm.cuo[cur] : 0)) && near(R(sm.prev[cur] + buy + fee - pay), sm.tot[cur]); };
    out.check = { have, prev: sm.prev ? sm.prev[main] : null, end: sm.tot ? sm.tot[main] : null, totalCharges: sm.dir ? R(sm.dir[main] + (sm.cuo ? sm.cuo[main] : 0) + sm.fees[main]) : null, totalCredits: sm.ab ? sm.ab[main] : null,
      sumCharges: R(sums[main].buy + sm.fees[main]), sumCredits: R(sums[main].pay), running: true, ok: have ? chk('PEN') && chk('USD') : null };
    return out;
  }
  return { id: 'io-tarjeta', bank: 'io', label: 'iO · Tarjeta de crédito', detect, read };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaIO;
