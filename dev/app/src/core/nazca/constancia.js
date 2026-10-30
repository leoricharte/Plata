/* ---------- Nazca · Constancias de Yape y Plin (texto) ----------
 * Lee el TEXTO de una constancia (la que Yape o Plin dejan compartir después de un pago) y arma un movimiento listo para revisar.
 * El texto llega de dos lados: pegado por la persona (web) o reconocido de una captura en el dispositivo (iPhone: Vision). Esta lectura es la misma en los dos.
 * No hay red ni librerías: solo reglas. Es tolerante al ruido del OCR ("5/" por "S/", mayúsculas, líneas partidas) y NO inventa: lo que no encuentra queda en `flags`.
 *   flags: 'date' (no hallé fecha: se usó hoy) · 'direction' (no dice si pagaste o te pagaron) · 'who' (sin nombre) · 'amount' (varios montos posibles)
 *   auto: true solo si reconoce Yape/Plin, trae número de operación y no hay ninguna bandera → es seguro guardarla sin preguntar (iPhone: extensión de compartir).
 * Resultado con la misma forma que los lectores de bancos (impFromPdf): items con `ref` (número de operación o hora) que entra en la huella para no duplicar un reenvío.
 * ATENCIÓN: escrito con los formatos que conocemos (Yape, Plin desde BCP/Interbank/BBVA/Scotiabank), probado con ejemplos INVENTADOS. Falta confirmarlo con constancias reales:
 * cuando haya capturas reales (con los datos cambiados) se agregan a dev/tests/constancias.json y a las pruebas. */
const NazcaConstancia = (() => {
  const strip = (t) => String(t == null ? '' : t).toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  const norm = (t) => strip(t).replace(/\s+/g, ' ').trim();
  const pad = (n) => String(n).padStart(2, '0');
  const MAX_CHARS = 6000, MAX_LINES = 80;
  const MONTHS = { ene: 1, jan: 1, feb: 2, mar: 3, abr: 4, apr: 4, may: 5, jun: 6, jul: 7, ago: 8, aug: 8, set: 9, sep: 9, oct: 10, nov: 11, dic: 12, dec: 12 };

  const NEG = /\b(yapeaste|plineaste|enviaste|pagaste|transferiste|enviado a|enviado con exito|envio realizado|pago realizado|yapeo realizado|importe enviado|envio a contactos?)\b/;
  const POS = /\b(te yapearon|te yapeo|te plinearon|te plineo|te enviaron|te envio|te pago|te transfirieron|te transfirio|te devolvieron|recibiste|recibido de)\b/;
  const KEY = /(yapeaste|plineaste|enviaste|pagaste|transferiste|te yapearon|te yapeo|te plinearon|te plineo|te enviaron|te envio|te pago|recibiste|monto|importe|total)/;
  const BAD = /(comision|saldo|limite|disponible|itf|cargo|costo)/;
  /* Monto: "S/ 18", "S/. 18.50", "S/1,234.50", "PEN 20", "US$ 5". El OCR a veces lee "S/" como "5/": solo se acepta si no sigue otro dígito (no es una fecha). */
  const AMT = /(?:^|[^A-Za-z0-9])(?:(S[ \t]*\/[ \t]*\.?|PEN|US[ \t]*\$|USD|\$)|(5[ \t]*\/[ \t]*\.?)(?:(?!\d)|(?=\d+[.,]\d{2}(?![.,]?\d))))[ \t]*(\d{1,3}(?:[. ]\d{3})+(?:[.,]\d{1,2})?|\d{1,3}(?:,\d{3})+(?:[.]\d{1,2})?|\d+(?:[.,]\d{1,2})?)(?![.,]?\d|[ \t]*\/[ \t]*\d)/gi;
  const LABEL_TO = /^(nombre del destinatario|nombre de destinatario|destinatario|destino|enviado a|enviaste a|pagaste a|yapeaste a|plineaste a|transferiste a|beneficiario|nombre del beneficiario|pagado a|comercio|contacto|para(?=[ ]*:))\b[ ]*[:\-]?[ ]*(.*)$/;
  const LABEL_FROM = /^(nombre del remitente|remitente|origen|enviado por|de parte de|recibido de|de)\b[ ]*[:\-]?[ ]*(.*)$/;
  const LABEL_MSG = /^(mensaje|detalle|concepto|motivo|descripcion|referencia|servicio)\b[ ]*[:\-]?[ ]*(.*)$/;
  const LABELISH = /^(nombre|celular|telefono|numero|nro|cuenta|monto|importe|total|fecha|hora|mensaje|detalle|concepto|motivo|operacion|codigo|destino|origen|destinatario|remitente|enviado|recibido|banco|comision|saldo|referencia|servicio|datos|id)\b/;
  const INLINE_NEG = /(?:yapeaste|plineaste|enviaste|pagaste|transferiste)[ ]+(?:(?:s\/|5\/)[ ]*[\d.,]+[ ]+)?a[ ]+(.+)$/;
  const INLINE_POS = /^(.+?)[ ]+te[ ]+(?:yapeo|plineo|envio|pago|transfirio)\b/;
  const DATE_ISO = /(\d{4})-(\d{2})-(\d{2})/, DATE_WORDS = /(\d{1,2})[ ]*(?:de[ ]+)?([a-z]{3,10})\.?,?[ ]*(?:de[ ]+)?(\d{4})/g, DATE_NUM = /(\d{1,2})[\/.-](\d{1,2})[\/.-](\d{4}|\d{2})(?![\d])/, TIME_RE = /(\d{1,2}):(\d{2})(?::\d{2})?[ ]*(?:([ap])\.?[ ]?m\b\.?)?/;
  const OP = /(?:n[ro°º.]*[ ]*(?:de[ ]*)?operacion|codigo[ ]*(?:de[ ]*)?operacion|numero[ ]*de[ ]*operacion|id[ ]*(?:de[ ]*)?operacion|codigo[ ]*(?:de[ ]*)?transaccion|operacion[ ]*n[ro°º.]*|operacion)[ ]*[:#]?[ ]*([a-z0-9][a-z0-9-]{4,23})/g;

  function daysIn(y, m) { return m === 2 ? (y % 4 === 0 && (y % 100 !== 0 || y % 400 === 0) ? 29 : 28) : [4, 6, 9, 11].indexOf(m) >= 0 ? 30 : 31; }
  function okDate(y, m, d) { return y >= 2000 && y <= 2100 && m >= 1 && m <= 12 && d >= 1 && d <= daysIn(y, m); }
  /* Fecha de una línea ya normalizada (sin tildes, en minúsculas): "2026-10-29", "29 oct. 2026", "29 de octubre de 2026", "29/10/2026" (día primero). */
  function dateIn(n) {
    let m = DATE_ISO.exec(n);
    if (m && okDate(+m[1], +m[2], +m[3])) return m[1] + '-' + m[2] + '-' + m[3];
    const re = new RegExp(DATE_WORDS.source, 'g');
    while ((m = re.exec(n))) { const mo = MONTHS[m[2].slice(0, 3)]; if (mo && okDate(+m[3], mo, +m[1])) return m[3] + '-' + pad(mo) + '-' + pad(+m[1]); }
    m = DATE_NUM.exec(n);
    if (m) { const y = m[3].length === 2 ? 2000 + +m[3] : +m[3]; if (okDate(y, +m[2], +m[1])) return y + '-' + pad(+m[2]) + '-' + pad(+m[1]); }
    return '';
  }
  /* Hora ("02:15 pm", "14:15", "2:15 p. m."): "HH:MM" de 24 h, o ''. */
  function timeIn(n) {
    const m = TIME_RE.exec(n); if (!m) return '';
    let h = +m[1]; const mi = +m[2]; if (m[3] === 'p' && h < 12) h += 12; if (m[3] === 'a' && h === 12) h = 0;
    return h < 24 && mi < 60 ? pad(h) + ':' + pad(mi) : '';
  }
  function parseAmt(raw) {
    const t = String(raw).replace(/ /g, ''), sep = Math.max(t.lastIndexOf(','), t.lastIndexOf('.'));
    const u = sep < 0 ? t : (t.length - sep - 1 === 3 ? t.replace(/[.,]/g, '') : t.slice(0, sep).replace(/[.,]/g, '') + '.' + t.slice(sep + 1));
    const v = Math.round(parseFloat(u) * 100) / 100;
    return v > 0 && v < 1e7 ? v : NaN;
  }
  const titleCase = (v) => v.toLowerCase().replace(/(^|[ ])([a-zñáéíóúü])/g, (m, a, b) => a + b.toUpperCase());
  function cleanWho(v) {
    let s = String(v || '').replace(/\s+/g, ' ').replace(/^[\s:\-–]+|[\s:\-–,;]+$/g, '');
    if (!s || /^[\d\s*xX•·-]+$/.test(s)) return '';
    if (s === s.toUpperCase() && /[A-Z]/.test(s)) s = titleCase(s);
    return s.length > 60 ? s.slice(0, 60).trim() : s;
  }
  /* Lo que sigue a una etiqueta: en la misma línea o, si está vacía, en la línea de abajo (si esa no es otra etiqueta). */
  function after(lines, ns, i, m) {
    let rem = m[2];
    if (rem) return ns[i].length === lines[i].length ? lines[i].slice(lines[i].length - rem.length) : rem;
    const j = i + 1; if (j < lines.length && !LABELISH.test(ns[j])) return lines[j];
    return '';
  }
  function whoOf(lines, ns, sign) {
    const order = sign > 0 ? [LABEL_FROM, LABEL_TO] : [LABEL_TO, LABEL_FROM];
    for (const L of order) for (let i = 0; i < lines.length; i++) { const m = L.exec(ns[i]); if (m) { const v = cleanWho(after(lines, ns, i, m)); if (v) return v; } }
    for (let i = 0; i < lines.length; i++) {
      if (sign <= 0) { const m = INLINE_NEG.exec(ns[i]); if (m) { const v = cleanWho(ns[i].length === lines[i].length ? lines[i].slice(lines[i].length - m[1].length) : m[1]); if (v) return v; } }
      if (sign >= 0) { const m = INLINE_POS.exec(ns[i]); if (m) { const v = cleanWho(ns[i].length === lines[i].length ? lines[i].slice(0, m[1].length) : m[1]); if (v) return v; } }
    }
    return '';
  }
  /* Pagos de servicios y comercios: sin «Destino», el nombre es la línea que sigue al monto («S/10» → «Metropolitano y Corredores»). */
  function headWho(lines, ns, i) {
    const j = i + 1; if (j >= lines.length) return '';
    const l = lines[j].replace(/\s+/g, ' ').trim();
    if (l.length < 3 || l.length > 60 || /\d/.test(l) || !/[a-z]{3}/i.test(l) || LABELISH.test(ns[j]) || /yape|plin|operacion|transaccion|seguridad|gracias|compartir/.test(ns[j])) return '';
    return cleanWho(l);
  }
  function msgOf(lines, ns) {
    for (let i = 0; i < lines.length; i++) {
      const m = LABEL_MSG.exec(ns[i]); if (!m) continue;
      const v = String(after(lines, ns, i, m) || '').replace(/\s+/g, ' ').trim();
      if (v && !/^(-+|sin mensaje|ninguno|n\/a)$/i.test(v)) return v.slice(0, 60);
    }
    return '';
  }
  function amountOf(lines, ns) {
    const c = [];
    lines.forEach((ln, i) => {
      const re = new RegExp(AMT.source, 'gi'); let m;
      while ((m = re.exec(ln))) {
        const v = parseAmt(m[3]); if (!(v === v)) continue;
        const usd = !!m[1] && /^(US|USD|\$)/i.test(m[1].replace(/\s+/g, '')) && !/^S/i.test(m[1]);
        let sc = 0; if (KEY.test(ns[i])) sc += 3; if (i > 0 && KEY.test(ns[i - 1])) sc += 2; if (BAD.test(ns[i]) || (i > 0 && BAD.test(ns[i - 1]) && ln.replace(m[0], '').trim() === '')) sc -= 5;
        c.push({ v, cur: usd ? 'USD' : 'PEN', sc, i });
      }
    });
    if (!c.length) return null;
    let best = c[0]; c.forEach((x) => { if (x.sc > best.sc) best = x; });
    const ties = c.filter((x) => x.sc === best.sc && x.v !== best.v);
    return { v: best.v, cur: best.cur, amb: ties.length > 0, i: best.i };
  }
  function brandOf(n) {
    const y = /yape/.test(n), p = /plin/.test(n);
    if (y && /yapeaste|te yapeo|te yapearon|yapeo realizado|codigo de seguridad/.test(n)) return 'yape';
    if (!y && !p && /ventana del comercio|finalizar tu compra/.test(n)) return 'plin';   /* pago en un comercio: el logo de Plin es una imagen y el OCR no lo lee */
    if (y && p) return /plineaste|plin enviado|plineo|te plinearon|volver a plin/.test(n) ? 'plin' : 'yape';   /* «987 440 228 - Yape» es el destino, no la app */
    return y ? 'yape' : p ? 'plin' : '';
  }
  function viaOf(n) { return /\binterbank\b/.test(n) ? 'interbank' : /\bbbva\b/.test(n) ? 'bbva' : /\bbcp\b|banco de credito/.test(n) ? 'bcp' : ''; }
  function opOf(n) {
    const re = new RegExp(OP.source, 'g'); let m;
    while ((m = re.exec(n))) if (/\d/.test(m[1])) return m[1].toUpperCase();
    return '';
  }
  function parse(text, today) {
    const lines = String(text || '').slice(0, MAX_CHARS).split(/\r?\n/).map((l) => l.replace(/\s+/g, ' ').trim()).filter(Boolean).slice(0, MAX_LINES);
    if (!lines.length) return null;
    const ns = lines.map(norm), n = ns.join('\n'), flat = ns.join(' ');
    const amt = amountOf(lines, ns); if (!amt) return null;
    let date = '', time = '';
    for (let i = 0; i < ns.length && !date; i++) { const d = dateIn(ns[i]); if (d) { date = d; time = timeIn(ns[i]) || (i + 1 < ns.length ? timeIn(ns[i + 1]) : ''); } }
    const neg = NEG.test(n), pos = POS.test(n);
    let sign = pos && !neg ? 1 : neg && !pos ? -1 : 0;
    if (!sign) { const hasTo = ns.some((l) => LABEL_TO.test(l)), hasFrom = ns.some((l) => LABEL_FROM.test(l)); sign = hasFrom && !hasTo ? 1 : hasTo ? -1 : 0; }
    const flags = [];
    if (!sign) flags.push('direction');
    if (!date) flags.push('date');
    if (amt.amb) flags.push('amount');
    let brand = brandOf(n);
    if (/cuenta de (origen|cargo)/.test(n) && viaOf(n) && !/yapeaste|te yapeo|te yapearon/.test(n)) brand = 'plin';   /* constancia del banco (BBVA…): el dinero salió de esa cuenta */
    const op = opOf(flat), who = whoOf(lines, ns, sign) || (sign <= 0 ? headWho(lines, ns, amt.i) : '');
    if (!who) flags.push('who');
    return { lines, amt, date: date || String(today || ''), time, sign: sign || -1, flags, brand, op, who, msg: msgOf(lines, ns), via: brand === 'plin' ? viaOf(n) : '', hadDate: !!date };
  }
  /* 0 = no es una constancia · 2 = Yape o Plin con monto · 1 = parece constancia de otro banco (monto + fecha + número de operación) */
  function detect(text) {
    const p = parse(text, ''); if (!p) return 0;
    return p.brand ? 2 : p.op && p.hadDate ? 1 : 0;
  }
  function read(text, opts) {
    const p = parse(text, opts && opts.today); if (!p) return { error: 'no_amount' };
    const name = p.brand === 'yape' ? 'Yape' : p.brand === 'plin' ? 'Plin' : '';
    const base = p.who || (name ? (p.sign < 0 ? name : name + ' (recibido)') : 'Constancia');
    const desc = (base + (p.msg ? ' · ' + p.msg : '')).slice(0, 90);
    const ref = p.op || (p.time ? 't' + p.time.replace(':', '') : '');
    const it = { line: 1, date: p.date, desc, amount: p.sign * p.amt.v, cur: p.amt.cur }; if (ref) it.ref = ref;
    return {
      bank: p.brand === 'yape' ? 'yape' : p.via, kind: 'corriente', label: name ? name + ' · Constancia' : 'Constancia', name, cur: p.amt.cur, account: { last4: '' },
      period: p.date ? { from: p.date, to: p.date } : null, items: [it], skipped: { unreadable: 0, zero: 0 }, check: null,
      brand: p.brand, op: p.op, time: p.time, flags: p.flags, auto: !!(p.brand && p.op && !p.flags.length)
    };
  }
  /* TABLES: las reglas tal cual; swift/tools/gen-nazca-constancia.mjs las copia a Swift para que las dos lecturas no se desvíen. */
  return { id: 'constancia', label: 'Yape y Plin · Constancia', detect, read, MAX_CHARS, MAX_LINES, TABLES: { NEG, POS, KEY, BAD, AMT, LABEL_TO, LABEL_FROM, LABEL_MSG, LABELISH, INLINE_NEG, INLINE_POS, OP, DATE_ISO, DATE_WORDS, DATE_NUM, TIME_RE, MONTHS } };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaConstancia;
