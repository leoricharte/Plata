/* ---------- Nazca · lector genérico de PDF (núcleo, sin pantalla) ----------
 * Para los estados de cuenta de bancos que Nazca todavía no conoce: busca las líneas que empiezan con una fecha y terminan con un monto
 * ("Oct 3  Oct 4  AMAZON MKTPLACE  $23.99", "12/03/2026  COMPRA  -45.00  1,234.50") y arma con ellas una tabla Fecha, Descripción, Monto.
 * Esa tabla se lee con el mismo motor que un CSV (Nazca.analyze / Nazca.extract), así que la fecha, el signo y la moneda se interpretan igual.
 * No sabe de qué banco es ni comprueba que "cuadre": por eso la pantalla no muestra el sello de verificado. Es una ayuda: la persona revisa la lista.
 * Entrada: lo que devuelve NazcaPDF.read(). Salida de read(): { text, count, cur, year } con `text` en formato CSV listo para Nazca. */
const NazcaPDFGen = (() => {
  const MES = { ene: 1, jan: 1, feb: 2, mar: 3, abr: 4, apr: 4, may: 5, jun: 6, jul: 7, ago: 8, aug: 8, set: 9, sep: 9, oct: 10, nov: 11, dic: 12, dec: 12 };
  const pad = (n) => String(n).padStart(2, '0');
  const MINUS = /[−–—]/g;
  const mon = (w) => MES[String(w).slice(0, 3).toLowerCase()] || 0;
  const y4 = (y) => (y < 100 ? 2000 + y : y);

  /* Fecha al inicio del texto. Devuelve { iso | v (para el motor de CSV), rest } o null. Entiende: 2026-03-05 · 5/3/2026 · 9/30/26 · 5-3 · 5 mar 2026 · 5-mar-26 · Mar 5, 2026 · Mar 5 · March 5th. */
  function takeDate(s) {
    let m;
    if ((m = /^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?!\d)\s*/.exec(s))) return { v: m[1] + '-' + pad(+m[2]) + '-' + pad(+m[3]), rest: s.slice(m[0].length) };
    if ((m = /^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4}|\d{2})(?!\d)\s*/.exec(s))) return { v: m[1] + '/' + m[2] + '/' + (m[3].length === 2 ? y4(+m[3]) : m[3]), rest: s.slice(m[0].length) };
    if ((m = /^(\d{1,2})\s?(?:de\s|[-/.]\s?)?([A-Za-zñÑ]{3,10})\.?(?:[\s,/-]*(?:de\s)?(\d{4}|\d{2}))?(?![A-Za-z\d])\s*/.exec(s)) && mon(m[2]))
      return { d: +m[1], mo: mon(m[2]), yr: m[3] ? y4(+m[3]) : 0, rest: s.slice(m[0].length) };
    if ((m = /^([A-Za-zñÑ]{3,9})\.?\s?(\d{1,2})(?:st|nd|rd|th)?(?:,?\s(\d{4}))?(?![A-Za-z\d])\s*/.exec(s)) && mon(m[1]))
      return { d: +m[2], mo: mon(m[1]), yr: m[3] ? +m[3] : 0, rest: s.slice(m[0].length) };
    if ((m = /^(\d{1,2})[/.-](\d{1,2})(?![/.\d-]?\d)\s*/.exec(s)) && +m[1] <= 31 && +m[2] <= 31) return { v: m[1] + '/' + m[2], short: true, rest: s.slice(m[0].length) };
    return null;
  }

  /* Monto: un token entero ("$40.00", "-$1,175.13", "(45.00)", "45.00-", "S/ 12.50", "20,00 CR"). El separador decimal es el que queda antes de los 2 últimos dígitos. */
  const AMT_TOK = /^\s*([-+]?\s?\(?\s?(?:S\/\.?|US\$|USD|PEN|EUR|€|\$)?\s?[-+]?\(?\s?\d[\d.,\s]*[.,]\d{2}\s?\)?\s?-?\s?(?:CR|DR|Cr|Dr)?)\s*$/;
  function parseAmt(tok) {
    const t = String(tok).trim(); if (!AMT_TOK.test(t)) return null;
    const cur = /S\/|PEN/.test(t) ? 'PEN' : /US\$|USD|\$/.test(t) ? 'USD' : '';
    const num = /(\d[\d.,\s]*)[.,](\d{2})(?!\d)/.exec(t); if (!num) return null;
    const neg = /^[-−]/.test(t.replace(/^\s*(?:S\/\.?|US\$|USD|PEN|EUR|€|\$)\s?/, '')) || /^-/.test(t) || /\(/.test(t) || /-\s*(?:CR|DR)?\s*$/.test(t) || /\bDR\b/i.test(t);
    return { v: num[1].replace(/[.,\s]/g, '') + '.' + num[2], neg, cur };
  }

  /* Encabezados de columna conocidos (español e inglés). */
  const KINDS = [['balance', /saldo|balance/i], ['net', /\bnet\b|neto/i], ['debit', /d[eé]bito|debit|cargo|retiro|withdraw|charge|money out|paid out|gasto|salida/i], ['credit', /cr[eé]dito|credit|abono|dep[oó]sito|deposit|money in|paid in|ingreso|entrada/i],
    ['amount', /monto|importe|amount|valor|total|cantidad|sum/i], ['desc', /descripci|description|detalle|detail|concepto|memo|payee|merchant|movimiento|referencia|narrat|transaction(?!\s*date)/i], ['date', /fecha|date|d[ií]a|\bday\b/i], ['type', /tipo|type|status|estado|m[eé]todo|category|categor/i]];
  const kindOf = (t) => { for (const [k, re] of KINDS) if (re.test(t)) return k; return ''; };
  const NUMK = { debit: 1, credit: 1, amount: 1, net: 1, balance: 1 };

  function header(l) {
    const every = l.items.map((i) => ({ kind: kindOf(i.str), x: i.x, c: i.x + i.w / 2 })), cells = every.filter((c) => c.kind);
    const hasDate = cells.some((c) => c.kind === 'date'), hasNum = cells.some((c) => NUMK[c.kind]), hasDesc = cells.some((c) => c.kind === 'desc');
    return cells.length >= 2 && l.items.length <= cells.length + 3 && (hasNum && (hasDate || hasDesc)) ? every.map((c) => (c.kind ? c : Object.assign(c, { kind: 'other' }))) : null;
  }

  /* Un renglón de movimiento: empieza con una fecha (1 a 3 piezas de texto) y puede traer una segunda fecha (fecha valor / de proceso). */
  function rowOf(items, hdr) {
    let d1 = null, used = 0;
    for (let k = 1; k <= Math.min(3, items.length); k++) { const d = takeDate(items.slice(0, k).map((i) => i.str).join(' ').replace(MINUS, '-')); if (d && !d.rest.trim()) { d1 = d; used = k; break; } }
    if (!d1) return null;
    let rest = items.slice(used);
    for (let k = 1; k <= Math.min(3, rest.length); k++) { const d = takeDate(rest.slice(0, k).map((i) => i.str).join(' ')); if (d && !d.rest.trim()) { rest = rest.slice(k); break; } }
    const nums = rest.map((it) => ({ it, a: parseAmt(it.str.replace(MINUS, '-')) })).filter((o) => o.a && o.it.x > items[0].x + 20);
    if (!nums.length) return null;
    const first = nums[0].it;
    let mov = null, descItems;
    const numCols = hdr ? hdr.filter((c) => NUMK[c.kind]) : [];
    if (numCols.length) {
      const near = (o) => numCols.slice().sort((p, q) => Math.abs(p.c - (o.it.x + o.it.w / 2)) - Math.abs(q.c - (o.it.x + o.it.w / 2)))[0];
      const by = {}; for (const o of nums) { const c = near(o); if (Math.abs(c.c - (o.it.x + o.it.w / 2)) < 70 && !by[c.kind]) by[c.kind] = o.a; }
      if (by.debit || by.credit) { const dv = by.debit && +by.debit.v !== 0 ? by.debit : null, cv = by.credit && +by.credit.v !== 0 ? by.credit : null; mov = dv ? { v: dv.v, neg: true, cur: dv.cur } : cv ? { v: cv.v, neg: false, cur: cv.cur } : null; }
      else mov = by.net || by.amount || null;
      const descCol = hdr.find((c) => c.kind === 'desc'), after = descCol ? hdr.filter((c) => c.x > descCol.x + 2).sort((p, q) => p.x - q.x)[0] : null;
      descItems = descCol ? rest.filter((i) => i.x >= descCol.x - 4 && (!after || i.x < after.x - 2) && !parseAmt(i.str)) : null;
    }
    if (!mov) mov = nums[0].a;
    if (!descItems || !descItems.length) descItems = rest.filter((i) => i.x < first.x && !(parseAmt(i.str) && i.x > items[0].x + 20));
    const desc = descItems.map((i) => i.str).join(' ').replace(MINUS, '-').replace(/\s+/g, ' ').trim();
    return { d: d1, desc, mov };
  }

  /* Plan B si las piezas de texto no se separan bien por columna: toda la línea como texto; se quitan las fechas del final y se toma el primer monto. */
  const AMT_SRC = '[-+]?\\s?\\(?(?:S\\/\\.?|US\\$|USD|PEN|\\$)?\\s?[-+]?\\(?\\d[\\d.,]*[.,]\\d{2}\\)?-?(?:\\s?(?:CR|DR))?';
  function rowFromText(s) {
    const d1 = takeDate(s); if (!d1) return null;
    s = d1.rest; const d2 = takeDate(s); if (d2) s = d2.rest;
    for (let n = 0; n < 3; n++) { const m = /\s+(\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}|\d{4}-\d{2}-\d{2})$/.exec(s); if (!m) break; s = s.slice(0, m.index); }
    const e = new RegExp('((?:\\s+' + AMT_SRC + ')+)\\s*$').exec(s); if (!e) return null;
    const amts = e[1].match(new RegExp(AMT_SRC, 'g')) || [], a = amts.length ? parseAmt(amts[0]) : null; if (!a) return null;
    return { d: d1, desc: s.slice(0, e.index).replace(/\s+/g, ' ').trim(), mov: a };
  }

  const SKIP = /^(saldo|total|balance|previous|new balance|pago m[ií]nimo|minimum|beginning|ending|opening|closing|summary|resumen)/i;

  /* Nombre probable del banco o emisor: la primera línea de arriba de la primera página que parezca un nombre (no un título genérico, ni fechas, ni números). */
  const GENERIC = /estado|statement|extracto|cuenta|account|p[aá]gina|page|fecha|date|documento|movimientos|resumen|summary|saldo|balance|detalle|transacc|period/i;
  function guessName(doc) {
    const pdf = typeof NazcaPDF !== 'undefined' ? NazcaPDF : require('./pdf.js');
    const page = doc.pages[0]; if (!page) return '';
    for (const l of pdf.lines(page, 3).slice(0, 8)) {
      const t = l.items.map((i) => i.str).join(' ').replace(/\s+/g, ' ').trim();
      if (t.length < 3 || t.length > 32 || (t.match(/[A-Za-zÁÉÍÓÚáéíóúñÑ]/g) || []).length < 3 || /\d{3,}/.test(t) || GENERIC.test(t) || /[$%@]/.test(t)) continue;
      return t;
    }
    return '';
  }
  /* Nombre probable a partir del nombre del archivo: "prueba-capital-one.csv" → "Capital One". Si no queda nada con sentido, ''. */
  function nameFromFile(fname) {
    let t = String(fname || '').replace(/\.[A-Za-z0-9]{2,4}$/, '').replace(/[_\-.]+/g, ' ').replace(/\b(prueba|test|falso|estado|cuenta|movimientos|statement|export|descarga|download|csv|pdf|copia|copy|final|nuevo)\b/gi, ' ').replace(/\d+/g, ' ').replace(/\s+/g, ' ').trim();
    if ((t.match(/[A-Za-zÁÉÍÓÚáéíóúñÑ]/g) || []).length < 3 || t.length > 28 || /^(img|dsc|scan|doc|file|data|untitled|sin titulo|whatsapp)\b/i.test(t)) return '';
    return t.replace(/(^|\s)\S/g, (c) => c.toUpperCase());
  }


  /* ¿Es una tarjeta de crédito? Se buscan pistas en el texto (línea de crédito, pago mínimo, fecha de pago, tasa anual, saldo anterior/nuevo, la palabra "credit card"…); con 3 o más se trata como tarjeta.
   * En una tarjeta, Plata guarda las compras como gasto (−) y los pagos y créditos como ingreso (+). Cada banco los imprime a su manera:
   *  · lo más común (EE. UU.): compras en positivo y pagos en negativo; · otros: compras en negativo y pagos en positivo.
   * Se mira cómo vienen impresos los movimientos que parecen pagos ("payment", "pago", "thank you", "abono", "reembolso", "refund"…) y de ahí se decide la convención. */
  const CARD_CUES = [/credit card|tarjeta de cr[eé]dito|\bvisa\b|master ?card|american express|\bamex\b/i, /credit limit|l[ií]nea de cr[eé]dito|credit line|cr[eé]dito disponible|available credit/i, /minimum (?:payment|amount) due|pago m[ií]nimo|min(?:imum)? payment/i,
    /payment due(?: date)?|fecha (?:l[ií]mite )?de pago|vencimiento|due date/i, /\bAPR\b|annual percentage rate|\bTEA\b|\bTCEA\b|tasa de inter[eé]s|interest rate/i, /new balance|previous balance|nuevo saldo|saldo anterior|statement closing|fecha de corte/i];
  const PAYMENT = /payment|pago|thank you|gracias|abono|refund|reembolso|devoluci|credit adjustment|reward|cashback|ajuste a favor|\bcr[eé]dito\b/i;
  function cardInfo(doc, rows) {
    const t = doc.pages.map((p) => p.items.map((i) => i.str).join(' ')).join(' ').replace(/\s+/g, ' ');
    const cues = CARD_CUES.filter((re) => re.test(t)).length;
    const info = {}, num = (m) => parseFloat(String(m).replace(/[,\s]/g, ''));
    const isCard = cues >= 3 && rows.length > 0;
    if (isCard) {
      let m = /(?:\bAPR\b|annual percentage rate|\bTEA\b|\bTCEA\b|tasa(?: de inter[eé]s)?(?: anual)?|interest rate)[^\d%]{0,40}(\d{1,3}(?:[.,]\d{1,2})?)\s?%/i.exec(t) || /(\d{1,3}(?:[.,]\d{1,2})?)\s?%\s?\(?(?:Fixed|Variable|APR|TEA)/i.exec(t); if (m) info.apr = num(m[1].replace(',', '.'));
      m = /(?:minimum (?:payment|amount) due|pago m[ií]nimo)[^\d$]{0,30}(?:S\/\.?|US\$|\$)?\s?([\d,]+\.\d{2})/i.exec(t); if (m) info.minPayment = num(m[1]);
      m = /(?:credit limit|l[ií]nea de cr[eé]dito)(?! available| disponible)[^\d$]{0,30}(?:S\/\.?|US\$|\$)?\s?([\d,]+\.\d{2})/i.exec(t); if (m) info.limit = num(m[1]);
      m = /(?:payment due(?: date)?|due date|fecha (?:l[ií]mite )?de pago|vencimiento)[:\s-]{0,6}([A-Za-z0-9/.,\s-]{6,24})/i.exec(t);
      if (m) { const d = takeDate(m[1].trim()); if (d) { const yr = (t.match(/\b20\d{2}\b/g) || []).map(Number); const Y = Math.max.apply(null, yr.length ? yr : [new Date().getFullYear()]);
        const iso = d.v ? (d.short ? null : (/^\d{4}-/.test(d.v) ? d.v : (() => { const q = d.v.split('/').map(Number); return q[2] + '-' + pad(q[0] > 12 ? q[1] : q[0]) + '-' + pad(q[0] > 12 ? q[0] : q[1]); })())) : (d.yr || Y) + '-' + pad(d.mo) + '-' + pad(d.d);
        if (iso) { info.dueDate = iso; info.dueDay = +iso.slice(8, 10); } } }
    }
    const l4 = /(?:ending in|terminad[ao] en|account (?:number )?\*?|n[uú]mero de tarjeta|card (?:no\.?|number))[^\d]{0,12}(?:\*{2,}|x{2,}|•{2,}|\.{3,})?\s?(\d{4})\b/i.exec(t) || /(?:\*{2,}|x{3,}|•{3,})\s?(\d{4})\b/i.exec(t);
    const pays = rows.filter((r) => PAYMENT.test(r[1])), negPays = pays.filter((r) => /^-/.test(r[2])).length;
    const usStyle = !pays.length || negPays >= pays.length / 2;        // los pagos vienen en negativo → las compras vienen en positivo
    const unsigned = !rows.some((r) => /^-/.test(r[2]));                // todo viene en positivo: solo la descripción distingue un pago de una compra
    const sign = (desc, v) => { const a = String(v).replace(/^-/, ''); if (unsigned) return PAYMENT.test(desc) ? a : '-' + a; return usStyle ? (/^-/.test(v) ? a : '-' + a) : (/^-/.test(v) ? v : a); };
    return { isCard, info, last4: l4 ? l4[1] : '', sign };
  }

  function read(doc) {
    const pdf = typeof NazcaPDF !== 'undefined' ? NazcaPDF : require('./pdf.js');
    const all = doc.pages.flatMap((p) => p.items.map((i) => i.str)).join(' ');
    const years = (all.match(/\b20\d{2}\b/g) || []).map(Number);
    const year = years.length ? Math.max.apply(null, years) : new Date().getFullYear();
    const out = [], curs = {}; let hdr = null;
    for (const page of doc.pages) {
      for (const l of pdf.lines(page, 3)) {
        const h = header(l); if (h) { hdr = h; continue; }
        let r = rowOf(l.items, hdr);
        if (!r) r = rowFromText(l.items.map((i) => i.str).join(' ').replace(MINUS, '-').replace(/\s+/g, ' ').trim());
        if (!r || !r.desc || !/[A-Za-zÁÉÍÓÚáéíóúñÑ]/.test(r.desc) || SKIP.test(r.desc) || !r.mov) continue;
        const d = r.d, date = d.v ? (d.short ? d.v + '/' + year : d.v) : (d.yr || year) + '-' + pad(d.mo) + '-' + pad(d.d);
        out.push([date, r.desc, (r.mov.neg ? '-' : '') + r.mov.v]); if (r.mov.cur) curs[r.mov.cur] = (curs[r.mov.cur] || 0) + 1;
      }
    }
    const cur = Object.keys(curs).sort((a, b) => curs[b] - curs[a])[0] || '';
    const card = cardInfo(doc, out);
    if (card.isCard) for (const r of out) r[2] = card.sign(r[1], r[2]);
    const q = (v) => '"' + String(v).replace(/"/g, '""') + '"';
    const text = out.length ? 'Fecha,Descripción,Monto\n' + out.map((r) => r[0] + ',' + q(r[1]) + ',' + r[2]).join('\n') + '\n' : '';
    return { text, count: out.length, cur, year, name: guessName(doc), isCard: card.isCard, card: card.info, last4: card.last4 };
  }
  return { read, nameFromFile, guessName };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaPDFGen;
