/* ---------- Nazca · BCP · Estado de cuenta de ahorros (PDF) ----------
 * Lee el PDF "Estado de Cuenta de Ahorros Cuenta Digital BCP" (la cuenta de ahorros del BCP). Otros estados del BCP (tarjeta de crédito,
 * cuenta corriente…) no se leen con este lector: se agregan cuando haya un ejemplo de cada uno.
 * Entrada: lo que devuelve NazcaPDF.read(). Todo ocurre en el dispositivo.
 *
 * Cómo está armado el PDF (visto en un estado real; las pruebas usan uno inventado con el mismo diseño):
 *  · cada movimiento: FECHA PROC. (30SET) · FECHA VALOR + DESCRIPCIÓN (en un solo texto) · una marca opcional (* o 1) · un monto;
 *  · el monto NO trae signo: es cargo o abono según la columna (CARGOS / DEBE o ABONOS / HABER) en que cae, y eso se ve por su posición;
 *  · las fechas no traen año: sale del periodo del encabezado ("DEL 01/10/24 AL 31/10/24"), y 30SET en un estado de octubre es del mes anterior;
 *  · al final: TOTAL MOVIMIENTO (suma de cargos y de abonos) y SALDO. Con el SALDO ANTERIOR sirven para comprobar que se leyó todo:
 *    saldo anterior + abonos − cargos = saldo final.
 * Salida de read(): { bank, kind, label, cur, account:{ last4 }, period:{ from, to }, items:[{ line, date, desc, amount, cur, balance }], skipped, check } */
const NazcaBCP = (() => {
  const MES = { ENE: 1, FEB: 2, MAR: 3, ABR: 4, MAY: 5, JUN: 6, JUL: 7, AGO: 8, SET: 9, SEP: 9, OCT: 10, NOV: 11, DIC: 12 };
  const AMOUNT = /^[\d,]+\.\d{2}$/, DATE_SHORT = /^(\d{1,2})([A-Z]{3})$/, DATE_FULL = /^(\d{2})\/(\d{2})\/(\d{2}|\d{4})$/;
  const money = (s) => Math.round(parseFloat(String(s).replace(/,/g, '')) * 100) / 100;
  const pad = (n) => String(n).padStart(2, '0');
  const all = (doc) => doc.pages.flatMap((p) => p.items);
  const find = (items, re) => items.find((i) => re.test(i.str));
  const near = (a, b, tol) => Math.abs(a - b) <= tol;

  /* ¿Este PDF es un estado de ahorros del BCP? Pide el título, la sigla y las dos columnas: 1 si sí, 0 si no. */
  function detect(doc) {
    if (!doc || !doc.pages || !doc.pages.length) return 0;
    const first = doc.pages[0].items;
    const text = first.map((i) => i.str).join(' ');
    const ok = /Estado de Cuenta de Ahorros/i.test(text) && /\bBCP\b/.test(text) && /CARGOS\s*\/\s*DEBE/.test(text) && /ABONOS\s*\/\s*HABER/.test(text);
    return ok ? 1 : 0;
  }

  /* Periodo del encabezado: las dos primeras fechas dd/mm/aa que aparecen bajo "FECHA DE ESTADO DE CUENTA". */
  function period(doc) {
    const items = doc.pages[0].items;
    const label = find(items, /FECHA DE ESTADO DE CUENTA/);
    const ds = items.filter((i) => DATE_FULL.test(i.str) && (!label || i.y <= label.y + 2)).sort((a, b) => b.y - a.y || a.x - b.x);
    if (ds.length < 2) return null;
    const p = (s) => { const m = DATE_FULL.exec(s); const y = m[3].length === 2 ? 2000 + +m[3] : +m[3]; return { y, m: +m[2], d: +m[1] }; };
    const from = p(ds[0].str), to = p(ds[1].str);
    const key = (x) => x.y * 10000 + x.m * 100 + x.d;
    if (from.m < 1 || from.m > 12 || to.m < 1 || to.m > 12 || key(from) > key(to)) return null;
    return { from, to };
  }

  /* 30SET → fecha completa. El año es el más reciente cuyo día no pasa de unos días después del fin del periodo. */
  function resolve(dd, mon, per) {
    const m = MES[mon]; if (!m) return null;
    const endKey = per.to.y * 372 + per.to.m * 31 + per.to.d + 7;
    for (const y of [per.to.y, per.to.y - 1]) {
      const dt = new Date(Date.UTC(y, m - 1, +dd));
      if (dt.getUTCMonth() !== m - 1 || dt.getUTCDate() !== +dd) continue;
      if (y * 372 + m * 31 + +dd <= endKey) return y + '-' + pad(m) + '-' + pad(+dd);
    }
    return null;
  }

  function read(doc) {
    if (!detect(doc)) return null;
    const per = period(doc);
    if (!per) return { bank: 'bcp', kind: 'ahorros', label: 'BCP · Cuenta de ahorros', error: 'period' };
    const pdf = typeof NazcaPDF !== 'undefined' ? NazcaPDF : require('../pdf.js');
    const everything = all(doc);
    const curWord = find(everything, /^(SOLES|DOLARES|DÓLARES|US ?DOLARES)$/i);
    const cur = curWord ? (/^S/i.test(curWord.str) ? 'PEN' : 'USD') : 'PEN';
    const acct = find(doc.pages[0].items, /^\d{3}-\d{6,}-\d-\d{2}$/);
    const digits = acct ? acct.str.replace(/\D/g, '') : '';
    const out = { bank: 'bcp', kind: 'ahorros', label: 'BCP · Cuenta de ahorros', cur, account: { last4: digits.slice(-4) },
      period: { from: per.from.y + '-' + pad(per.from.m) + '-' + pad(per.from.d), to: per.to.y + '-' + pad(per.to.m) + '-' + pad(per.to.d) },
      items: [], skipped: { unreadable: 0, zero: 0 }, check: null };
    let prev = null, totC = null, totA = null, end = null, sumC = 0, sumA = 0, line = 0, mid = null;

    for (const page of doc.pages) {
      const hc = find(page.items, /^CARGOS\s*\/\s*DEBE$/), ha = find(page.items, /^ABONOS\s*\/\s*HABER$/);
      if (hc && ha) mid = ((hc.x + hc.w) + (ha.x + ha.w)) / 2;   // a la izquierda de esta línea: cargos; a la derecha: abonos
      if (mid === null) continue;
      const kindOf = (it) => (it.x + it.w > mid ? 'abono' : 'cargo');
      const head = find(page.items, /^FECHA PROC\.?$/);
      const top = head ? head.y : Infinity;
      const amounts = page.items.filter((i) => AMOUNT.test(i.str) && i.y < top - 2);
      const labelOf = (re) => page.items.find((i) => re.test(i.str));

      /* Totales: los montos están casi sobre la misma línea que su rótulo (unos puntos más arriba). */
      const lt = labelOf(/^TOTAL MOVIMIENTO$/);
      if (lt) for (const a of amounts) if (near(a.y, lt.y, 9)) { if (kindOf(a) === 'cargo') totC = money(a.str); else totA = money(a.str); }
      const ls = labelOf(/^SALDO$/);
      if (ls) { const a = amounts.find((x) => near(x.y, ls.y, 10)); if (a) end = money(a.str) * (kindOf(a) === 'cargo' ? -1 : 1); }
      const lp = labelOf(/^SALDO ANTERIOR$/);
      if (lp) { const a = amounts.find((x) => near(x.y, lp.y, 4)); if (a) prev = money(a.str) * (kindOf(a) === 'cargo' ? -1 : 1); }

      for (const l of pdf.lines(page)) {
        if (l.y >= top - 2) continue;
        const its = l.items;
        const d1 = DATE_SHORT.exec(its[0].str);
        if (!d1 || its[0].x > page.w * 0.2) continue;                    // no es una fila de movimiento
        const amt = its.slice(1).reverse().find((i) => AMOUNT.test(i.str));
        const body = its.slice(1).filter((i) => i !== amt && !/^[*\d]$/.test(i.str)).map((i) => i.str).join(' ').replace(/\s+/g, ' ').trim();
        const d2 = /^(\d{1,2})([A-Z]{3})\s+(.+)$/.exec(body);
        const date = resolve(d1[1], d1[2], per);
        if (!amt || !d2 || !date) { out.skipped.unreadable++; continue; }
        const val = money(amt.str);
        if (!val) { out.skipped.zero++; continue; }
        const isCharge = kindOf(amt) === 'cargo';
        if (isCharge) sumC += val; else sumA += val;
        out.items.push({ line: ++line, date, desc: d2[3], amount: isCharge ? -val : val, cur, balance: null });
      }
    }
    sumC = Math.round(sumC * 100) / 100; sumA = Math.round(sumA * 100) / 100;
    if (end !== null && out.items.length) out.items[out.items.length - 1].balance = end;
    /* Comprobación: lo leído tiene que coincidir con los totales del banco y con su saldo final. */
    const eq = (a, b) => Math.abs(a - b) < 0.005;
    const have = totC !== null && totA !== null && prev !== null && end !== null;
    out.check = { have, prev, end, totalCharges: totC, totalCredits: totA, sumCharges: sumC, sumCredits: sumA,
      ok: have ? eq(sumC, totC) && eq(sumA, totA) && eq(prev + sumA - sumC, end) : null };
    return out;
  }

  return { id: 'bcp-ahorros', bank: 'bcp', label: 'BCP · Cuenta de ahorros', detect, read };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaBCP;
