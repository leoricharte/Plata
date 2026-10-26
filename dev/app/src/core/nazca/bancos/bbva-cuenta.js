/* ---------- Nazca · BBVA Perú · "Movimiento y saldo a la fecha" de una cuenta (PDF) ----------
 * Lee el estado de cuenta de las cuentas de BBVA Perú (visto en una CUENTA SUELDO en soles; las demás cuentas usan el mismo diseño, pero hasta
 * tener un ejemplo de cada una no se da por probado). Tarjetas de crédito de BBVA tienen otro estado: se agregan cuando haya un ejemplo.
 * Entrada: lo que devuelve NazcaPDF.read(). Todo ocurre en el dispositivo.
 *
 * Cómo está armado el PDF (visto en un estado real; las pruebas usan uno inventado con el mismo diseño):
 *  · encabezado: MOVIMIENTO Y SALDO A LA FECHA, tipo de cuenta, titulares, código de cuenta (entidad, oficina, cuenta, d.c.) y CCI;
 *  · "MONEDA: SOLES", y una tabla: FECHA OPER. · FECHA VALOR · DESCRIPCIÓN · OFICINA · CAN. · NRO. OPERACIÓN · CARGO/ABONO · ITF · SALDO CONTABLE;
 *  · las fechas vienen como dd-mm (sin año): el año sale de la "FECHA" del pie de página (la del estado de cuenta, dd-mm-aaaa);
 *  · el monto va en una sola columna: el CARGO lleva un "-" AL FINAL (500.00-) y el ABONO va sin signo (1,267.59);
 *  · la primera fila es SALDO ANTERIOR; al pie, SALDO A NUESTRO FAVOR (sobregiro) y SALDO A SU FAVOR (lo que tienes).
 * No trae totales de cargos y abonos: se comprueba que el saldo corra fila por fila y que el saldo anterior más los movimientos dé el saldo final.
 * Salida de read(): { bank, kind, label, cur, account:{ last4 }, period:{ from, to }, items:[{ line, date, desc, amount, cur, balance }], skipped, check } */
const NazcaBBVA = (() => {
  const AMOUNT = /^[\d,]+\.\d{2}-?$/, DM = /^(\d{2})-(\d{2})$/, FULL = /^(\d{2})-(\d{2})-(\d{4})$/;
  const money = (s) => Math.round(parseFloat(String(s).replace(/[,-]/g, '')) * 100) / 100;
  const r2 = (n) => Math.round(n * 100) / 100;
  const near = (a, b) => Math.abs(a - b) < 0.005;
  const pad = (n) => String(n).padStart(2, '0');
  const title = (s) => s.toLowerCase().replace(/(^|\s)\S/g, (c) => c.toUpperCase());
  const text = (page) => page.items.map((i) => i.str).join(' ');

  /* ¿Es un "Movimiento y saldo a la fecha" de BBVA? Pide el título, las columnas de cargo/abono y saldo, el saldo anterior y la marca. */
  function detect(doc) {
    if (!doc || !doc.pages || !doc.pages.length) return 0;
    const t = text(doc.pages[0]);
    return /MOVIMIENTO Y SALDO A LA FECHA/.test(t) && /CARGO\/ABONO/.test(t) && /SALDO CONTABLE/.test(t) && /SALDO ANTERIOR/.test(t) && /BBVA|bbva\.pe/.test(t) ? 1 : 0;
  }

  function read(doc) {
    if (!detect(doc)) return null;
    const pdf = typeof NazcaPDF !== 'undefined' ? NazcaPDF : require('../pdf.js');
    const first = doc.pages[0];
    const prod = first.items.find((i) => /^CUENTA [A-ZÁÉÍÓÚÑ ]+$/.test(i.str));
    const kind = prod ? title(prod.str) : 'Cuenta';
    const acct = first.items.find((i) => /^\d{10}$/.test(i.str));
    const mi = first.items.findIndex((i) => /^MONEDA:?(\s|$)/.test(i.str));
    const mon = mi >= 0 ? first.items.slice(mi, mi + 4).map((i) => i.str).join(' ') : '';
    const cur = /D[ÓO]LAR|USD/i.test(mon) ? 'USD' : 'PEN';
    const out = { bank: 'bbva', kind: 'ahorros', label: 'BBVA · ' + kind, cur, account: { last4: acct ? acct.str.slice(-4) : '' }, period: null, items: [], skipped: { unreadable: 0, zero: 0 }, check: null };
    // Fecha del estado de cuenta (dd-mm-aaaa): de ahí sale el año de los movimientos.
    let st = null;
    for (const p of doc.pages) { for (const it of p.items) { const m = FULL.exec(it.str); if (m && +m[2] >= 1 && +m[2] <= 12) { st = { y: +m[3], m: +m[2], d: +m[1] }; break; } } if (st) break; }
    if (!st) return Object.assign(out, { error: 'period' });

    let prev = null, end = null, sumIn = 0, sumOut = 0, line = 0, running = true, last = null;
    for (const page of doc.pages) {
      const hdr = (s) => page.items.find((i) => i.str === s);
      const itfH = hdr('ITF'), nuestro = hdr('SALDO A NUESTRO FAVOR'), suyo = hdr('SALDO A SU FAVOR');
      const itfX = itfH ? itfH.x - 12 : page.w * 0.78;
      for (const l of pdf.lines(page)) {
        const its = l.items, amts = its.filter((i) => AMOUNT.test(i.str) && i.x > page.w * 0.55);
        const open = its.find((i) => i.str === 'SALDO ANTERIOR');
        if (open) { if (amts.length) prev = money(amts[amts.length - 1].str); continue; }
        const d = DM.exec(its[0].str);
        if (!d || its[0].x > page.w * 0.15 || !its[1] || !DM.test(its[1].str)) continue;          // no es una fila de movimiento
        const body = its.slice(2).filter((i) => !AMOUNT.test(i.str) && i.x > page.w * 0.1 && i.x < page.w * 0.38).map((i) => i.str).join(' ')
          .replace(/\/\d{6}\*+\d{4}\s*$/, '').replace(/\s+/g, ' ').trim();                          // sin el número de tarjeta enmascarado del final
        const bal = amts.length >= 2 ? amts[amts.length - 1] : null;
        const rest = bal ? amts.slice(0, -1) : [];
        const mov = rest.find((i) => i.x < itfX), itf = rest.find((i) => i.x >= itfX);
        if (!bal || !mov || !body) { out.skipped.unreadable++; continue; }
        const v = money(mov.str), neg = /-$/.test(mov.str);
        const month = +d[2], year = month > st.m ? st.y - 1 : st.y;
        const date = year + '-' + d[2] + '-' + d[1];
        const b = money(bal.str), tax = itf ? money(itf.str) : 0;
        const amount = neg ? -v : v;
        if (!v) { out.skipped.zero++; continue; }
        const expect = r2((last !== null ? last : prev !== null ? prev : NaN) + amount - tax);
        if ((last !== null || prev !== null) && !near(expect, b)) running = false;
        last = b;
        if (neg) sumOut += v; else sumIn += v;
        out.items.push({ line: ++line, date, desc: body, amount, cur, balance: tax ? r2(b + tax) : b });
        if (tax) { sumOut += tax; out.items.push({ line: ++line, date, desc: 'ITF', amount: -tax, cur, balance: b }); }
      }
      if (suyo) {                                           // pie: "SALDO A NUESTRO FAVOR" (sobregiro) y "SALDO A SU FAVOR"
        const below = page.items.filter((i) => AMOUNT.test(i.str) && i.y < suyo.y && i.y > suyo.y - 25);
        const c = (i) => i.x + i.w / 2, pick = (h) => { let best = null; for (const i of below) if (!best || Math.abs(c(i) - c(h)) < Math.abs(c(best) - c(h))) best = i; return best; };
        const a = pick(suyo), n = nuestro ? pick(nuestro) : null;
        if (a) end = r2(money(a.str) - (n && n !== a ? money(n.str) : 0));
      }
    }
    sumIn = r2(sumIn); sumOut = r2(sumOut);
    if (out.items.length) {
      const ds = out.items.map((i) => i.date).sort(), ms = st.y + '-' + pad(st.m) + '-01';
      out.period = { from: ds[0] < ms ? ds[0] : ms, to: st.y + '-' + pad(st.m) + '-' + pad(st.d) };
    }
    const have = prev !== null && end !== null;
    out.check = { have, prev, end, totalCharges: null, totalCredits: null, sumCharges: sumOut, sumCredits: sumIn, running,
      ok: have ? near(r2(prev + sumIn - sumOut), end) && running : null };
    return out;
  }

  return { id: 'bbva-cuenta', bank: 'bbva', label: 'BBVA · Cuenta', detect, read };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaBBVA;
