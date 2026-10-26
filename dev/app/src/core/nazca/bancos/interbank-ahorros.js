/* ---------- Nazca · Interbank · Estado de cuenta de cuenta de ahorros (PDF) ----------
 * Lee el "ESTADO DE CUENTA" de las cuentas de ahorro de Interbank (por ejemplo "CUENTA SIMPLE SOLES"). Otros estados de Interbank (tarjeta de
 * crédito, cuenta sueldo con otro diseño…) se agregan cuando haya un ejemplo de cada uno.
 * Entrada: lo que devuelve NazcaPDF.read(). Todo ocurre en el dispositivo.
 *
 * Cómo está armado el PDF (visto en un estado real; las pruebas usan uno inventado con el mismo diseño):
 *  · página 1: encabezado (ESTADO DE CUENTA, producto y moneda, número de cuenta, "DEL 31 DE OCTUBRE AL 29 DE NOVIEMBRE"), DETALLE DE MOVIMIENTOS;
 *  · cada movimiento: fecha completa dd/mm/aaaa · concepto · monto CON SIGNO (+ ingreso, − gasto) · saldo contable de esa fila;
 *  · "EMPEZASTE NOVIEMBRE CON 0.00" es el saldo anterior y "SALDO CONTABLE AL 29/11" trae el total de ingresos, el de gastos y el saldo final;
 *  · la última página es una guía ("Te ayudamos a conocer tu Estado de Cuenta") con movimientos de EJEMPLO de otra persona: se ignora.
 * Como cada fila trae su saldo, además de los totales se comprueba que el saldo corra fila por fila.
 * Salida de read(): { bank, kind, label, cur, account:{ last4 }, period:{ from, to }, items:[{ line, date, desc, amount, cur, balance }], skipped, check } */
const NazcaInterbank = (() => {
  const MES = { ENERO: 1, FEBRERO: 2, MARZO: 3, ABRIL: 4, MAYO: 5, JUNIO: 6, JULIO: 7, AGOSTO: 8, SETIEMBRE: 9, SEPTIEMBRE: 9, OCTUBRE: 10, NOVIEMBRE: 11, DICIEMBRE: 12 };
  const AMOUNT = /^[+-]?[\d,]+\.\d{2}$/, DATE = /^(\d{2})\/(\d{2})\/(\d{4})$/;
  const GUIDE = /Te ayudamos a conocer/i;
  const money = (s) => Math.round(parseFloat(String(s).replace(/,/g, '')) * 100) / 100;
  const pad = (n) => String(n).padStart(2, '0');
  const text = (page) => page.items.map((i) => i.str).join(' ');
  const real = (doc) => doc.pages.filter((p) => !GUIDE.test(text(p)));      // páginas con datos de verdad (sin la guía de ejemplo)
  const near = (a, b) => Math.abs(a - b) < 0.005;
  const title = (s) => s.toLowerCase().replace(/(^|\s)\S/g, (c) => c.toUpperCase());

  /* ¿Es un estado de cuenta de ahorros de Interbank? Pide el título, la columna "Saldo Contable", el detalle de movimientos y la marca. */
  function detect(doc) {
    if (!doc || !doc.pages || !doc.pages.length) return 0;
    const pages = real(doc); if (!pages.length) return 0;
    const t = pages[0].items.map((i) => i.str).join(' ');
    const all = doc.pages.map(text).join(' ');
    const ok = /ESTADO DE CUENTA/.test(t) && /DETALLE DE MOVIMIENTOS/.test(t) && /Saldo Contable/i.test(t) && /\bIngresos\b/.test(t) && /\bGastos\b/.test(t) && /Interbank/i.test(all);
    return ok ? 1 : 0;
  }

  /* "DEL 31 DE OCTUBRE AL 29 DE NOVIEMBRE" o "DEL 1 AL 30 DE NOVIEMBRE": sin año; el año sale de las fechas de los movimientos. */
  function span(page) {
    for (const it of page.items) {
      const m = /^DEL (\d{1,2})(?: DE ([A-ZÁÉÍÓÚ]+))? AL (\d{1,2}) DE ([A-ZÁÉÍÓÚ]+)$/.exec(it.str);
      if (!m) continue;
      const to = MES[m[4]], from = m[2] ? MES[m[2]] : to; if (!to || !from) continue;
      return { fd: +m[1], fm: from, td: +m[3], tm: to };
    }
    return null;
  }

  function read(doc) {
    if (!detect(doc)) return null;
    const pdf = typeof NazcaPDF !== 'undefined' ? NazcaPDF : require('../pdf.js');
    const pages = real(doc), first = pages[0];
    const sp = span(first);
    const head = text(first);
    const cur = /D[ÓO]LARES/i.test(head.split('DETALLE DE MOVIMIENTOS')[0]) ? 'USD' : 'PEN';
    const prod = first.items.find((i) => /^CUENTA [A-ZÁÉÍÓÚ ]+$/.test(i.str));
    const kind = prod ? title(prod.str.replace(/\s+(SOLES|D[ÓO]LARES)$/i, '')) : '';
    const label = 'Interbank' + (kind ? ' · ' + kind : '');
    const acct = first.items.find((i) => /^\d{3}-\d{10}$/.test(i.str));
    const out = { bank: 'interbank', kind: 'ahorros', label, cur, account: { last4: acct ? acct.str.replace(/\D/g, '').slice(-4) : '' }, period: null, items: [], skipped: { unreadable: 0, zero: 0 }, check: null };
    if (!sp) return Object.assign(out, { error: 'period' });

    let prev = null, totIn = null, totOut = null, end = null, endDay = null, sumIn = 0, sumOut = 0, line = 0, running = true, last = null;
    for (const page of pages) {
      const hi = page.items.find((i) => i.str === 'Ingresos'), hg = page.items.find((i) => i.str === 'Gastos');
      const mid = hi && hg ? ((hi.x + hi.w) + (hg.x + hg.w)) / 2 : null;     // solo se usa si un monto no trae signo
      for (const l of pdf.lines(page)) {
        const its = l.items, amts = its.filter((i) => AMOUNT.test(i.str) && i.x > page.w * 0.3);
        const open = its.find((i) => /^EMPEZASTE .+ CON$/.test(i.str));
        if (open) { if (amts.length) prev = money(amts[amts.length - 1].str); continue; }
        const tot = its.find((i) => /^SALDO CONTABLE AL \d{2}\/\d{2}$/.test(i.str));
        if (tot) { if (amts.length >= 3) { totIn = Math.abs(money(amts[0].str)); totOut = Math.abs(money(amts[1].str)); end = money(amts[amts.length - 1].str); endDay = tot.str.slice(-5); } continue; }
        const d = DATE.exec(its[0].str);
        if (!d || its[0].x > page.w * 0.2) continue;                       // no es una fila de movimiento
        const body = its.slice(1).filter((i) => !AMOUNT.test(i.str) || i.x <= page.w * 0.3).map((i) => i.str).join(' ').replace(/\s+/g, ' ').trim();
        if (amts.length < 2 || !body) { out.skipped.unreadable++; continue; }
        const bal = amts[amts.length - 1], mov = amts[amts.length - 2];
        let v = money(mov.str);
        const signed = /^[+-]/.test(mov.str);
        const neg = signed ? mov.str[0] === '-' : (mid !== null ? mov.x + mov.w < mid : v < 0);
        v = Math.abs(v);
        const date = d[3] + '-' + d[2] + '-' + d[1];
        if (!v) { out.skipped.zero++; continue; }
        const amount = neg ? -v : v;
        if (neg) sumOut += v; else sumIn += v;
        const b = money(bal.str);
        if (last !== null && !near(Math.round((last + amount) * 100) / 100, b)) running = false;
        if (last === null && prev !== null && !near(Math.round((prev + amount) * 100) / 100, b)) running = false;
        last = b;
        out.items.push({ line: ++line, date, desc: body, amount, cur, balance: b });
      }
    }
    sumIn = Math.round(sumIn * 100) / 100; sumOut = Math.round(sumOut * 100) / 100;

    /* Año: el de las fechas de los movimientos. El fin del periodo es el primer "dd/mm" igual o posterior a la última fila; el inicio, el anterior. */
    if (out.items.length) {
      const ds = out.items.map((i) => i.date).sort(), lastD = ds[ds.length - 1], ly = +lastD.slice(0, 4), lk = (+lastD.slice(5, 7)) * 100 + (+lastD.slice(8, 10));
      const ty = sp.tm * 100 + sp.td >= lk ? ly : ly + 1, fy = sp.fm > sp.tm ? ty - 1 : ty;
      out.period = { from: fy + '-' + pad(sp.fm) + '-' + pad(sp.fd), to: ty + '-' + pad(sp.tm) + '-' + pad(sp.td) };
    }
    const have = prev !== null && totIn !== null && totOut !== null && end !== null;
    out.check = { have, prev, end, totalCharges: totOut, totalCredits: totIn, sumCharges: sumOut, sumCredits: sumIn, running,
      ok: have ? near(sumOut, totOut) && near(sumIn, totIn) && near(Math.round((prev + sumIn - sumOut) * 100) / 100, end) && running : null };
    return out;
  }

  return { id: 'interbank-ahorros', bank: 'interbank', label: 'Interbank · Cuenta de ahorros', detect, read };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaInterbank;
