/* ---------- Nazca · lector genérico de PDF (núcleo, sin pantalla) ----------
 * Para los estados de cuenta de bancos que Nazca todavía no conoce: busca las líneas que empiezan con una fecha y terminan con un monto
 * ("Oct 3  Oct 4  AMAZON MKTPLACE  $23.99", "12/03/2026  COMPRA  -45.00  1,234.50") y arma con ellas una tabla Fecha, Descripción, Monto.
 * Esa tabla se lee con el mismo motor que un CSV (Nazca.analyze / Nazca.extract), así que la fecha, el signo y la moneda se interpretan igual.
 * No sabe de qué banco es ni comprueba que "cuadre": por eso la pantalla no muestra el sello de verificado. Es una ayuda: la persona revisa la lista.
 * Entrada: lo que devuelve NazcaPDF.read(). Salida de read(): { text, count, cur, year } con `text` en formato CSV listo para Nazca. */
const NazcaPDFGen = (() => {
  const MES = { ene: 1, jan: 1, feb: 2, mar: 3, abr: 4, apr: 4, may: 5, jun: 6, jul: 7, ago: 8, aug: 8, set: 9, sep: 9, oct: 10, nov: 11, dic: 12, dec: 12 };
  const pad = (n) => String(n).padStart(2, '0');
  const MINUS = /[−–]/g;

  /* Fecha al inicio del texto: devuelve { v, rest, y } (v: fecha lista para Nazca; y: si trae año) o null. */
  function takeDate(s) {
    let m;
    if ((m = /^(\d{4})-(\d{2})-(\d{2})\b\s*/.exec(s))) return { v: m[0].trim(), rest: s.slice(m[0].length), y: true };
    if ((m = /^(\d{1,2})[/.-](\d{1,2})[/.-](\d{4}|\d{2})\b\s*/.exec(s))) return { v: m[1] + '/' + m[2] + '/' + m[3], rest: s.slice(m[0].length), y: true };
    if ((m = /^(\d{1,2})[/.-](\d{1,2})\b(?![/.-]?\d)\s*/.exec(s))) return { v: m[1] + '/' + m[2], rest: s.slice(m[0].length), y: false, short: true };
    if ((m = /^(\d{1,2})\s?(?:de\s)?([A-Za-zñÑ]{3,10})\.?(?:\s?(?:de\s)?(\d{4}))?\b\s*/.exec(s)) && MES[m[2].slice(0, 3).toLowerCase()])
      return { d: +m[1], mo: MES[m[2].slice(0, 3).toLowerCase()], yr: m[3] ? +m[3] : 0, rest: s.slice(m[0].length) };
    if ((m = /^([A-Za-zñÑ]{3,9})\.?\s(\d{1,2})(?:,?\s(\d{4}))?\b\s*/.exec(s)) && MES[m[1].slice(0, 3).toLowerCase()])
      return { d: +m[2], mo: MES[m[1].slice(0, 3).toLowerCase()], yr: m[3] ? +m[3] : 0, rest: s.slice(m[0].length) };
    return null;
  }

  /* Monto: signo, paréntesis o "-" al final = negativo; el separador decimal es el que queda antes de los 2 últimos dígitos. */
  const AMT_SRC = '[-+]?\\s?\\(?(?:S\\/\\.?|US\\$|USD|PEN|\\$)?\\s?[-+]?\\(?\\d[\\d.,]*[.,]\\d{2}\\)?-?(?:\\s?(?:CR|DR))?';
  const AMT_END = new RegExp('((?:\\s+' + AMT_SRC + ')+)\\s*$');
  const AMT_ONE = new RegExp(AMT_SRC, 'g');
  function parseAmt(tok) {
    const t = tok.trim(), cur = /S\/|PEN/.test(t) ? 'PEN' : /US\$|USD|\$/.test(t) ? 'USD' : '';
    const neg = /^[-]/.test(t.replace(/^\s*(?:S\/\.?|US\$|USD|PEN|\$)/, '')) || /^-/.test(t) || /\(/.test(t) || /-\s*$/.test(t) || /\bDR\b/.test(t);
    const num = /(\d[\d.,]*)[.,](\d{2})(?!\d)/.exec(t);
    if (!num) return null;
    const v = (num[1].replace(/[.,]/g, '') + '.' + num[2]);
    return { v: (neg ? '-' : '') + v, cur };
  }

  function read(doc) {
    const pdf = typeof NazcaPDF !== 'undefined' ? NazcaPDF : require('./pdf.js');
    const all = doc.pages.flatMap((p) => p.items.map((i) => i.str)).join(' ');
    const years = (all.match(/\b20\d{2}\b/g) || []).map(Number);
    const year = years.length ? Math.max.apply(null, years) : new Date().getFullYear();
    const out = [], curs = {};
    for (const page of doc.pages) {
      for (const l of pdf.lines(page, 3)) {
        let s = l.items.map((i) => i.str).join(' ').replace(MINUS, '-').replace(/\s+/g, ' ').trim();
        const d1 = takeDate(s); if (!d1) continue;
        s = d1.rest;
        const d2 = takeDate(s); if (d2) s = d2.rest;                            // fecha de operación + fecha de proceso
        const e = AMT_END.exec(s); if (!e) continue;
        const desc = s.slice(0, e.index).replace(/\s+/g, ' ').trim();
        const amts = e[1].match(AMT_ONE) || []; const first = amts.length ? parseAmt(amts[0]) : null;
        if (!first || !desc || !/[A-Za-zÁÉÍÓÚáéíóúñÑ]/.test(desc)) continue;
        if (/^(saldo|total|balance|previous|new balance|pago m[ií]nimo|minimum)/i.test(desc)) continue;
        const date = d1.v ? (d1.short ? d1.v + '/' + year : d1.v) : d1.yr ? d1.yr + '-' + pad(d1.mo) + '-' + pad(d1.d) : year + '-' + pad(d1.mo) + '-' + pad(d1.d);
        out.push([date, desc, first.v]); if (first.cur) curs[first.cur] = (curs[first.cur] || 0) + 1;
      }
    }
    const cur = Object.keys(curs).sort((a, b) => curs[b] - curs[a])[0] || '';
    const q = (v) => '"' + String(v).replace(/"/g, '""') + '"';
    const text = out.length ? 'Fecha,Descripción,Monto\n' + out.map((r) => r[0] + ',' + q(r[1]) + ',' + r[2]).join('\n') + '\n' : '';
    return { text, count: out.length, cur, year };
  }
  return { read };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaPDFGen;
