/* ---------- Nazca · Mercado Pago (Chile) · Estado de cuenta de la cuenta Mercado Pago (PDF) ----------
 * Lee el estado de cuenta que Mercado Pago Emisora S.A. genera para la cuenta (billetera) de Mercado Pago en Chile. Visto en UN estado real
 * (Chile, pesos chilenos); las pruebas usan uno inventado con el mismo diseño. Otros países de Mercado Pago pueden usar otro diseño: hasta tener
 * un ejemplo de cada uno no se da por probado. Entrada: lo que devuelve NazcaPDF.read(). Todo ocurre en el dispositivo.
 *
 * Cómo está armado el PDF (horizontal, 1080 x 768):
 *  · encabezado: DENOMINACIÓN SOCIAL, RUT, DOMICILIO, NOMBRE; y debajo DESDE, HASTA, FECHA DE GENERACIÓN e ID DE USUARIO;
 *  · resumen con títulos y valores justo debajo: BALANCE INICIAL, DEPÓSITOS, DÉBITOS, COMISIONES, RETENCIONES POR IMPUESTOS, PROMEDIO DIARIO DE SALDOS, BALANCE FINAL;
 *  · tabla (se repite el encabezado en cada página): FECHA DE ACREDITACIÓN (dd-mm-aaaa hh:mm:ss) · TIPO DE MOVIMIENTO (Abono / Cargo) · TIPO DE TRANSACCIÓN
 *    (Pago, Transferencia recibida…) · ID DE TRANSACCIÓN · MONEDA · MONTO DE TRANSACCIÓN (el cargo ya lleva "-") · OTROS CONCEPTOS · NOMBRE DEL COMERCIO;
 *  · números con punto de miles y coma decimal (135.000,00); el nombre del comercio puede ir en dos líneas, una arriba y otra abajo de la fila, o venir vacío.
 * El cargo/abono se toma de «TIPO DE MOVIMIENTO» y se exige que el signo del monto coincida; si no, la fila se cuenta como «no se pudo leer».
 * Comprobación «cuadra»: balance inicial + depósitos − débitos − comisiones − retenciones = balance final, y lo leído suma lo mismo que los totales impresos.
 * «OTROS CONCEPTOS» valía 0,00 en todas las filas vistas: si trae algo, no se suma (no sabemos qué significa) y la comprobación avisa si algo no cuadra.
 * Salida de read(): { bank, kind, label, cur, account:{ last4 }, period:{ from, to }, items:[{ line, date, desc, amount, cur }], skipped, check } */
const NazcaMercadoPago = (() => {
  const DT = /^(\d{2})-(\d{2})-(\d{4}) \d{2}:\d{2}:\d{2}$/, MONEY = /^-?\d{1,3}(\.\d{3})*,\d{2}$/;
  const norm = (s) => String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/\s+/g, ' ').trim().toUpperCase();
  const money = (s) => Math.round(parseFloat(String(s).replace(/\./g, '').replace(',', '.')) * 100) / 100;
  const r2 = (n) => Math.round(n * 100) / 100;
  const near = (a, b) => Math.abs(a - b) < 0.005;
  const iso = (s) => { const m = DT.exec(s) || /^(\d{2})-(\d{2})-(\d{4})/.exec(s); return m ? m[3] + '-' + m[2] + '-' + m[1] : ''; };
  const text = (page) => page.items.map((i) => i.str).join(' ');

  /* ¿Es un estado de cuenta de Mercado Pago? Pide la marca y los títulos de la tabla y del resumen. */
  function detect(doc) {
    if (!doc || !doc.pages || !doc.pages.length) return 0;
    const t = norm(text(doc.pages[0]));
    return /MERCADO ?PAGO/.test(t) && /FECHA DE ACREDITACION/.test(t) && /TIPO DE MOVIMIENTO/.test(t) && /ID DE TRANSACCION/.test(t) && /BALANCE INICIAL/.test(t) && /BALANCE FINAL/.test(t) ? 1 : 0;
  }

  /* El valor de un título del encabezado o del resumen: el texto que está justo debajo, alineado a su izquierda. */
  function below(page, title, re) {
    const h = page.items.find((i) => norm(i.str) === title); if (!h) return null;
    let best = null;
    for (const i of page.items) if (i.y < h.y - 3 && i.y > h.y - 70 && Math.abs(i.x - h.x) < 8 && re.test(i.str) && (!best || i.y > best.y)) best = i;
    return best ? best.str : null;
  }

  function read(doc) {
    if (!detect(doc)) return null;
    const first = doc.pages[0];
    const from = iso(below(first, 'DESDE', DT) || ''), to = iso(below(first, 'HASTA', DT) || '');
    const uid = below(first, 'ID DE USUARIO', /^\d{4,}$/);
    const num = (t) => { const v = below(first, t, MONEY); return v == null ? null : money(v); };
    const prev = num('BALANCE INICIAL'), dep = num('DEPOSITOS'), deb = num('DEBITOS'), com = num('COMISIONES'), ret = num('RETENCIONES POR'), end = num('BALANCE FINAL');
    const out = { bank: 'mercadopago', kind: 'corriente', label: 'Mercado Pago · Cuenta', cur: 'CLP', account: { last4: uid ? uid.slice(-4) : '' }, period: from && to ? { from, to } : null, items: [], skipped: { unreadable: 0, zero: 0 }, check: null };
    if (!out.period) return Object.assign(out, { error: 'period' });

    let sumIn = 0, sumOut = 0, line = 0; const curs = {};
    for (const page of doc.pages) {
      const H = (t) => page.items.find((i) => norm(i.str) === t);
      const hf = H('FECHA DE ACREDITACION'), hm = H('TIPO DE MOVIMIENTO'), ht = H('TIPO DE TRANSACCION'), hi = H('ID DE TRANSACCION'), hc = H('MONEDA'),
        ha = H('MONTO DE TRANSACCION'), ho = H('OTROS CONCEPTOS'), hn = H('NOMBRE DEL COMERCIO');
      if (!hf || !hm || !ht || !hi || !hc || !ha || !hn) continue;                       // página sin tabla (por ejemplo, solo el aviso final)
      const cells = (row, lo, hi2) => page.items.filter((i) => Math.abs(i.y - row.y) < 3 && i.x >= lo - 4 && i.x < hi2 - 4).sort((a, b) => a.x - b.x).map((i) => i.str).join(' ').trim();
      const rows = page.items.filter((i) => i.y < hf.y - 3 && Math.abs(i.x - hf.x) < 8 && DT.test(i.str)).sort((a, b) => b.y - a.y);
      const names = rows.map(() => []);
      for (const i of page.items) {                                                  // el nombre del comercio puede ocupar dos líneas: cada una va a la fila más cercana
        if (i.y >= hf.y - 3 || i.x < hn.x - 6 || !rows.length) continue;
        let k = 0; for (let j = 1; j < rows.length; j++) if (Math.abs(rows[j].y - i.y) < Math.abs(rows[k].y - i.y)) k = j;
        if (Math.abs(rows[k].y - i.y) < 20) names[k].push(i);
      }
      rows.forEach((row, k) => {
        const mov = norm(cells(row, hm.x, ht.x)), trx = cells(row, ht.x, hi.x), cur = cells(row, hc.x, ha.x), amt = cells(row, ha.x, ho ? ho.x : hn.x);
        const nm = names[k].sort((a, b) => b.y - a.y || a.x - b.x).map((i) => i.str).join(' ').replace(/\s+/g, ' ').trim();
        const sign = mov === 'ABONO' ? 1 : mov === 'CARGO' ? -1 : 0;
        if (!sign || !MONEY.test(amt) || !/^[A-Z]{3}$/.test(cur)) { out.skipped.unreadable++; return; }
        const v = money(amt);
        if (v !== 0 && (v < 0) !== (sign < 0)) { out.skipped.unreadable++; return; }   // el signo impreso no coincide con Abono/Cargo: no se adivina
        if (v === 0) { out.skipped.zero++; return; }
        const amount = sign * Math.abs(v);
        if (amount > 0) sumIn += amount; else sumOut += -amount;
        curs[cur] = (curs[cur] || 0) + 1;
        const desc = (nm ? (norm(trx) === 'PAGO' ? nm : (trx || 'Movimiento') + ' · ' + nm) : (trx || 'Movimiento')).slice(0, 90);
        out.items.push({ line: ++line, date: iso(row.str), desc, amount, cur });
      });
    }
    const top = Object.keys(curs).sort((a, b) => curs[b] - curs[a])[0]; if (top) out.cur = top;
    sumIn = r2(sumIn); sumOut = r2(sumOut);
    const have = prev !== null && end !== null && dep !== null && deb !== null;
    out.check = { have, prev, end, totalCharges: deb, totalCredits: dep, sumCharges: sumOut, sumCredits: sumIn, running: true,
      ok: have ? near(r2(prev + dep - deb - (com || 0) - (ret || 0)), end) && near(sumIn, dep) && near(sumOut, deb) : null };
    return out;
  }

  return { id: 'mercadopago-cuenta', bank: 'mercadopago', label: 'Mercado Pago · Cuenta', detect, read };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaMercadoPago;
