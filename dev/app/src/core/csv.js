/* ---------- Importar movimientos desde CSV (núcleo, sin pantalla) ----------
 * Todo ocurre en el dispositivo: el archivo nunca se sube a ningún servidor.
 * Este archivo no usa el DOM ni el estado de la app, para poder probarlo en Node y reusarlo en otras plataformas.
 * Entrada: el contenido del archivo. Salida: movimientos { date: 'AAAA-MM-DD', desc, amount (negativo = sale dinero), cur, balance }.
 * Formatos que entiende: separador , ; tabulador |, comillas, UTF-8 o Windows-1252, líneas de encabezado del banco antes de la tabla,
 * un solo monto con signo, columnas separadas de cargo y abono, o monto sin signo más una columna de tipo (cargo/abono, D/C),
 * números como 1,234.56 · 1.234,56 · (12.50) · 12.50- · S/ 12.50, y fechas como 25/10/2026 · 2026-10-25 · 25-oct-2026 · 10/25/2026. */
const PlataCSV = (() => {
  const MAX_ROWS = 5000, MAX_BYTES = 5 * 1024 * 1024;
  const norm = (s) => String(s == null ? '' : s).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9/$ ]+/g, ' ').replace(/\s+/g, ' ').trim();

  /* --- Texto: UTF-8 si es válido; si no, Windows-1252 (lo que suele exportar Excel en español) --- */
  function decode(buf) {
    const u = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
    let s;
    try { s = new TextDecoder('utf-8', { fatal: true }).decode(u); } catch (e) { s = new TextDecoder('windows-1252').decode(u); }
    return s.replace(/^﻿/, '');
  }

  /* --- CSV con comillas (RFC 4180, tolerante) --- */
  function splitRows(text, d) {
    const rows = []; let row = [], cell = '', q = false;
    for (let i = 0; i < text.length; i++) {
      const c = text[i];
      if (q) {
        if (c === '"') { if (text[i + 1] === '"') { cell += '"'; i++; } else q = false; } else cell += c;
      } else if (c === '"' && cell.trim() === '') { q = true; cell = ''; }
      else if (c === d) { row.push(cell); cell = ''; }
      else if (c === '\n' || c === '\r') { if (c === '\r' && text[i + 1] === '\n') i++; row.push(cell); rows.push(row); row = []; cell = ''; if (rows.length > MAX_ROWS + 60) break; }
      else cell += c;
    }
    if (cell !== '' || row.length) { row.push(cell); rows.push(row); }
    return rows.map((r) => r.map((x) => x.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, '').trim())).filter((r) => r.some((x) => x !== ''));
  }
  /* El separador es el que deja más filas con el mismo número de columnas (y más de una columna) */
  function detectDelim(text) {
    const sample = text.slice(0, 20000);
    let best = ',', bestScore = -1;
    [',', ';', '\t', '|'].forEach((d) => {
      const rows = splitRows(sample, d).slice(0, 40), counts = {};
      rows.forEach((r) => { if (r.length > 1) counts[r.length] = (counts[r.length] || 0) + 1; });
      const top = Object.keys(counts).reduce((m, k) => Math.max(m, counts[k] * Math.min(Number(k), 8)), 0);
      if (top > bestScore) { bestScore = top; best = d; }
    });
    return best;
  }

  /* --- Encabezados: qué es cada columna --- */
  const ROLES = {
    date: { re: /^(fecha|date|dia|f )|fecha|transaction date|posted date|posting date|booking date/, prefer: /operacion|transaccion|consumo|movimiento|compra|transaction/, avoid: /valor|valuta|proceso|contable|posted|posting|vencimiento|corte|pago/ },
    desc: { re: /descripcion|concepto|detalle|glosa|referencia|comercio|establecimiento|description|memo|payee|narrative|details|beneficiario|^movimiento$|^operacion$|^nombre$/, prefer: /descripcion|concepto|detalle|glosa|comercio|establecimiento|description|payee/ },
    amount: { re: /^(monto|importe|amount|valor|total|monto total|importe total|soles|dolares|s\/|us\$)( |$)|^monto|^importe|amount/ },
    debit: { re: /^(cargo|cargos|debito|debitos|retiro|retiros|egreso|egresos|salida|salidas|debit|debits|withdrawal|withdrawals|consumo|consumos|debe|money out|paid out)( |$)/ },
    credit: { re: /^(abono|abonos|credito|creditos|deposito|depositos|ingreso|ingresos|entrada|entradas|credit|credits|deposit|deposits|haber|money in|paid in)( |$)/ },
    balance: { re: /^saldo|balance/ },
    currency: { re: /^(moneda|currency|divisa|mon|ccy)( |$)/ },
    type: { re: /^(tipo|tipo de movimiento|tipo movimiento|tipo de operacion|cargo abono|cargo\/abono|d\/c|dc|db\/cr|type|naturaleza|signo|debito\/credito|debito credito)( |$)/ }
  };
  function roleOf(h) {
    const n = norm(h); if (!n) return null;
    if (ROLES.date.re.test(n)) return 'date';
    if (ROLES.balance.re.test(n)) return 'balance';
    if (ROLES.type.re.test(n)) return 'type';
    if (ROLES.debit.re.test(n)) return 'debit';
    if (ROLES.credit.re.test(n)) return 'credit';
    if (ROLES.currency.re.test(n)) return 'currency';
    if (ROLES.amount.re.test(n)) return 'amount';
    if (ROLES.desc.re.test(n)) return 'desc';
    return null;
  }
  function findHeader(rows) {
    let best = -1, bestScore = 1;
    for (let i = 0; i < Math.min(rows.length, 40); i++) {
      const roles = {}; rows[i].forEach((h) => { const r = roleOf(h); if (r) roles[r] = 1; });
      const score = Object.keys(roles).length + (roles.date ? 1 : 0) + (roles.amount || roles.debit || roles.credit ? 1 : 0);
      if (score > bestScore && rows[i].length >= 2) { best = i; bestScore = score; }
    }
    return best;
  }

  /* --- Números --- */
  const CUR_RE = /(S\/\.?|US\$|USD|PEN|EUR|€|\$|soles|dolares|dólares)/gi;
  function curOf(s) {
    const n = norm(s).replace(/\s/g, '');
    if (!n) return '';
    if (/^(pen|s\/|s|sol|soles|nuevossoles|mn)$/.test(n) || /^s\//.test(n)) return 'PEN';
    if (/^(usd|us\$|\$|us|dolar|dolares|me)$/.test(n) || /^us\$/.test(n)) return 'USD';
    if (/^(eur|euro|euros)$/.test(n) || String(s).trim() === '€') return 'EUR';
    if (/^[a-z]{3}$/.test(n)) return n.toUpperCase();
    return '';
  }
  function decimalVote(vals) {
    let dot = 0, comma = 0;
    vals.forEach((v) => {
      const s = String(v).replace(CUR_RE, '').replace(/[^\d.,]/g, '');
      if (!s) return;
      const li = Math.max(s.lastIndexOf('.'), s.lastIndexOf(','));
      if (s.indexOf('.') >= 0 && s.indexOf(',') >= 0) { if (s[li] === '.') dot += 3; else comma += 3; return; }
      const m = /[.,](\d+)$/.exec(s); if (!m) return;
      const sep = s[s.length - m[1].length - 1], parts = s.split(sep).length - 1;
      if (m[1].length <= 2 && parts === 1) { if (sep === '.') dot += 2; else comma += 2; }
      else if (m[1].length === 3) { if (sep === '.') comma += 1; else dot += 1; }
    });
    return comma > dot ? ',' : '.';
  }
  function parseAmount(v, dec) {
    let s = String(v == null ? '' : v).trim(); if (!s) return null;
    let neg = false;
    if (/^\(.*\)$/.test(s)) { neg = true; s = s.slice(1, -1); }
    s = s.replace(CUR_RE, ' ').trim();
    if (/^[-−–]/.test(s)) { neg = !neg; s = s.replace(/^[-−–]\s*/, ''); }
    else if (/^\+/.test(s)) s = s.slice(1);
    if (/[-−–]$/.test(s)) { neg = !neg; s = s.replace(/\s*[-−–]$/, ''); }
    if (/\b(db|dr)$/i.test(s)) { neg = true; s = s.replace(/\s*(db|dr)$/i, ''); } else if (/\bcr$/i.test(s)) s = s.replace(/\s*cr$/i, '');
    s = s.replace(/\s/g, '');
    if (!/^[\d.,]+$/.test(s) || !/\d/.test(s)) return null;
    s = dec === ',' ? s.replace(/\./g, '').replace(',', '.') : s.replace(/,/g, '');
    if ((s.match(/\./g) || []).length > 1) return null;
    const n = parseFloat(s); if (!isFinite(n)) return null;
    return Math.round((neg ? -n : n) * 100) / 100;
  }

  /* --- Fechas --- */
  const MONTHS = { ene: 1, jan: 1, feb: 2, mar: 3, abr: 4, apr: 4, may: 5, jun: 6, jul: 7, ago: 8, aug: 8, sep: 9, set: 9, oct: 10, nov: 11, dic: 12, dec: 12 };
  const monIdx = (w) => MONTHS[norm(w).slice(0, 3)] || 0;
  function dateParts(v) {
    const s = String(v || '').trim(); let m;
    if ((m = /^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?:$|[ T])/.exec(s))) return { k: 'ymd', a: +m[1], b: +m[2], c: +m[3] };
    if ((m = /^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2}|\d{4})(?:$|[ T,])/.exec(s))) return { k: 'xxy', a: +m[1], b: +m[2], c: +m[3] };
    if ((m = /^(\d{1,2})[-/. ]+([a-zA-ZáéíóúÁÉÍÓÚ]{3,})\.?[-/. ,]+(\d{2}|\d{4})(?:$|[ T])/.exec(s)) && monIdx(m[2])) return { k: 'ymd', a: +m[3], b: monIdx(m[2]), c: +m[1] };
    if ((m = /^([a-zA-Z]{3,})\.? (\d{1,2}),? (\d{4})(?:$|[ T])/.exec(s)) && monIdx(m[1])) return { k: 'ymd', a: +m[3], b: monIdx(m[1]), c: +m[2] };
    if ((m = /^(\d{4})(\d{2})(\d{2})$/.exec(s))) return { k: 'ymd', a: +m[1], b: +m[2], c: +m[3] };
    return null;
  }
  function dateOrder(vals) { // dmy (Perú) salvo que los datos digan lo contrario
    let dmy = 0, mdy = 0;
    vals.forEach((v) => { const p = dateParts(v); if (p && p.k === 'xxy') { if (p.a > 12) dmy++; if (p.b > 12) mdy++; } });
    return mdy > dmy ? 'mdy' : 'dmy';
  }
  function parseDate(v, order) {
    const p = dateParts(v); if (!p) return null;
    let y, mo, d;
    if (p.k === 'ymd') { y = p.a; mo = p.b; d = p.c; } else if (order === 'mdy') { mo = p.a; d = p.b; y = p.c; } else { d = p.a; mo = p.b; y = p.c; }
    if (y < 100) y += 2000;
    if (y < 1990 || y > 2100 || mo < 1 || mo > 12 || d < 1) return null;
    const dt = new Date(y, mo - 1, d);
    if (dt.getMonth() !== mo - 1 || dt.getDate() !== d) return null;
    return y + '-' + String(mo).padStart(2, '0') + '-' + String(d).padStart(2, '0');
  }

  /* --- Tipo (cargo/abono) --- */
  const typeSign = (v) => { const n = norm(v); if (/^(cargo|cargos|d|db|dr|debito|debit|retiro|egreso|consumo|compra|salida)( |$)/.test(n)) return -1; if (/^(abono|abonos|c|cr|credito|credit|deposito|ingreso|entrada|devolucion)( |$)/.test(n)) return 1; return 0; };

  /* --- Analizar: separador, encabezado, columnas y formatos --- */
  function analyze(text) {
    if (text.length > MAX_BYTES * 2) throw new Error('grande');
    const delim = detectDelim(text), all = splitRows(text, delim);
    if (!all.length) throw new Error('vacio');
    const hi = findHeader(all), headers = hi >= 0 ? all[hi] : [], body = (hi >= 0 ? all.slice(hi + 1) : all).filter((r) => r.length >= 2);
    const width = Math.max.apply(null, body.slice(0, 50).map((r) => r.length).concat([headers.length, 0]));
    const col = (j) => body.slice(0, 400).map((r) => r[j] || '');
    const isDateCol = (j) => { const v = col(j).filter(Boolean); return v.length && v.filter((x) => dateParts(x)).length / v.length >= 0.6; };
    const isNumCol = (j) => { const v = col(j).filter(Boolean); return v.length && v.filter((x) => parseAmount(x, '.') !== null || parseAmount(x, ',') !== null).length / v.length >= 0.6; };
    const isTextCol = (j) => { const v = col(j).filter(Boolean); return v.length && v.filter((x) => /[a-zA-ZáéíóúñÁÉÍÓÚÑ]{3,}/.test(x)).length / v.length >= 0.5; };
    const map = { date: -1, desc: -1, amount: -1, debit: -1, credit: -1, balance: -1, currency: -1, type: -1 };
    const pick = (role, j, prio) => { if (map[role] < 0 || prio > (map['_' + role] || 0)) { map[role] = j; map['_' + role] = prio; } };
    headers.forEach((h, j) => {
      const r = roleOf(h); if (!r) return;
      const n = norm(h), R = ROLES[r];
      let prio = 1; if (R.prefer && R.prefer.test(n)) prio = 3; if (R.avoid && R.avoid.test(n)) prio = 0.5;
      if (r === 'date' && !isDateCol(j)) return;
      if ((r === 'amount' || r === 'debit' || r === 'credit' || r === 'balance') && !isNumCol(j)) return;
      pick(r, j, prio);
    });
    // Sin encabezado útil: se adivina por el contenido
    if (map.date < 0) for (let j = 0; j < width; j++) if (isDateCol(j)) { map.date = j; break; }
    if (map.amount < 0 && map.debit < 0 && map.credit < 0) {
      const nums = []; for (let j = 0; j < width; j++) if (j !== map.date && j !== map.balance && isNumCol(j) && !isDateCol(j)) nums.push(j);
      if (nums.length) map.amount = nums[0];
    }
    if (map.desc < 0) {
      let best = -1, bestLen = 0;
      for (let j = 0; j < width; j++) {
        if ([map.date, map.amount, map.debit, map.credit, map.balance, map.currency, map.type].indexOf(j) >= 0 || !isTextCol(j)) continue;
        const v = col(j), len = v.reduce((s, x) => s + x.length, 0) / (v.length || 1), uniq = new Set(v).size / (v.length || 1);
        if (len * uniq > bestLen) { bestLen = len * uniq; best = j; }
      }
      map.desc = best;
    }
    if (map.type >= 0) { const v = col(map.type).filter(Boolean); if (!v.length || v.filter((x) => typeSign(x)).length / v.length < 0.8) map.type = -1; }
    Object.keys(map).forEach((k) => { if (k[0] === '_') delete map[k]; });
    const numVals = [].concat(map.amount >= 0 ? col(map.amount) : [], map.debit >= 0 ? col(map.debit) : [], map.credit >= 0 ? col(map.credit) : [], map.balance >= 0 ? col(map.balance) : []);
    let dec = decimalVote(numVals);
    if (delim === ';' && numVals.every((x) => !/\./.test(x) || !/,/.test(x)) && decimalVote(numVals) === '.' && numVals.some((x) => /,\d{1,2}$/.test(x))) dec = ',';
    return { delim, headerRow: hi, headers, width, cols: map, dec, order: map.date >= 0 ? dateOrder(col(map.date)) : 'dmy', rows: body.slice(0, MAX_ROWS), truncated: body.length > MAX_ROWS };
  }

  /* --- Convertir filas en movimientos --- */
  const SKIP_DESC = /^(total|totales|saldo anterior|saldo inicial|saldo final|saldo al|saldo disponible|subtotal)\b/;
  function cleanDesc(s) { return String(s || '').replace(/\s+/g, ' ').trim().slice(0, 140); }
  function extract(a, opts) {
    const c = Object.assign({}, a.cols, (opts && opts.cols) || {}), dec = (opts && opts.dec) || a.dec, order = (opts && opts.order) || a.order;
    const out = [], skipped = { blank: 0, unreadable: 0, total: 0 };
    a.rows.forEach((r, i) => {
      const line = i + 1, get = (j) => (j >= 0 ? r[j] || '' : '');
      const desc = cleanDesc(get(c.desc));
      if (SKIP_DESC.test(norm(desc)) || SKIP_DESC.test(norm(r[0]))) { skipped.total++; return; }
      const date = parseDate(get(c.date), order);
      let amount = null;
      if (c.amount >= 0) {
        amount = parseAmount(get(c.amount), dec);
        if (amount !== null && c.type >= 0) { const sg = typeSign(get(c.type)); if (sg) amount = sg * Math.abs(amount); }
      }
      if (amount === null && (c.debit >= 0 || c.credit >= 0)) {
        const d = parseAmount(get(c.debit), dec), cr = parseAmount(get(c.credit), dec);
        if (d) amount = -Math.abs(d); else if (cr) amount = Math.abs(cr); else if (d === 0 || cr === 0) amount = 0;
      }
      if (!date && !amount && !desc) { skipped.blank++; return; }
      if (!date || amount === null || amount === 0) { skipped.unreadable++; return; }
      const cur = curOf(get(c.currency)) || curOf((String(get(c.amount) || get(c.debit) || get(c.credit)).match(CUR_RE) || [''])[0]);
      const bal = c.balance >= 0 ? parseAmount(get(c.balance), dec) : null;
      out.push({ line, date, desc, amount, cur, balance: bal });
    });
    return { items: out, skipped };
  }

  /* --- Categoría sugerida: primero lo que ya hiciste antes con el mismo comercio, después palabras clave --- */
  const STOP = /\b(compra|compras|pago|pagos|consumo|consumos|pos|visa|mastercard|mc|deb|debito|credito|cargo|abono|trx|tarj|tarjeta|op|oper|operacion|transf|transferencia|interbancaria|yape|plin|pe|lima|peru|pen|usd|s\/|www|com|sac|eirl|srl|sa)\b/g;
  const merchant = (desc) => norm(desc).replace(/[0-9]+/g, ' ').replace(/\//g, ' ').replace(STOP, ' ').replace(/\s+/g, ' ').trim().split(' ').slice(0, 3).join(' ');
  const KEYWORDS = [
    ['Comida', /\b(tambo|oxxo|mass|plaza ?vea|plazavea|tottus|wong|metro|vivanda|makro|mercado|minimarket|market|bodega|restaurant|restaurante|rest|polleria|pollo|pizza|kfc|mcdonald|mcdonalds|burger|starbucks|cafe|cafeteria|rappi|pedidos ?ya|pedidosya|panaderia|chifa|cevicheria|bembos|norky|papa john|dominos|supermercado|juice|sanguch|comida|food)\b/],
    ['Transporte', /\b(uber|cabify|indrive|indriver|beat|taxi|primax|repsol|petroperu|pecsa|grifo|gasolina|combustible|peaje|latam|sky airline|jetsmart|metropolitano|linea ?1|bus|cruz del sur|oltursa|estacionamiento|parking|autopista|lima expresa|rutas de lima|didi)\b/],
    ['Ocio', /\b(netflix|spotify|disney|hbo|prime video|primevideo|youtube|cineplanet|cinemark|cinepolis|steam|playstation|xbox|nintendo|teleticket|joinnus|discoteca|bar|crunchyroll|twitch|apple com bill|google play)\b/],
    ['Alquiler', /\b(alquiler|renta|arrendamiento|rent)\b/]
  ];
  function categorizer(cats, history) {
    const names = (cats || []).map((x) => x.name), byNorm = {};
    names.forEach((n) => { byNorm[norm(n)] = n; });
    const learned = {};
    (history || []).forEach((t) => { if (t && t.amount < 0 && t.note && names.indexOf(t.category) >= 0) { const k = merchant(t.note); if (k) learned[k] = t.category; } });
    const other = names.indexOf('Otros') >= 0 ? 'Otros' : (names[names.length - 1] || 'Otros');
    return (desc, amount) => {
      if (amount > 0) return 'Ingreso';
      const k = merchant(desc); if (k && learned[k]) return learned[k];
      const n = norm(desc);
      for (let i = 0; i < names.length; i++) { const cn = norm(names[i]); if (cn.length >= 4 && cn !== 'otros' && (' ' + n + ' ').indexOf(' ' + cn + ' ') >= 0) return names[i]; }
      for (let i = 0; i < KEYWORDS.length; i++) if (KEYWORDS[i][1].test(n) && byNorm[norm(KEYWORDS[i][0])]) return byNorm[norm(KEYWORDS[i][0])];
      return other;
    };
  }

  /* --- Repetidos: huella exacta (si ya importaste este archivo) o mismo monto y fecha cercana (si lo anotaste a mano) --- */
  function fnv(s) { let h = 2166136261; for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return (h >>> 0).toString(36); }
  function fingerprints(items) { const seen = {}; return items.map((it) => { const base = it.date + '|' + it.amount.toFixed(2) + '|' + norm(it.desc); seen[base] = (seen[base] || 0) + 1; return fnv(base + '|' + seen[base]); }); }
  function markDuplicates(items, existing, acc) {
    const prints = fingerprints(items), mine = (existing || []).filter((t) => t && t.acc === acc), used = new Set(), byPrint = new Set();
    mine.forEach((t) => { if (t.imp) byPrint.add(t.imp); });
    const day = (s) => Date.UTC(+s.slice(0, 4), +s.slice(5, 7) - 1, +s.slice(8, 10)) / 864e5;
    return items.map((it, i) => {
      if (byPrint.has(prints[i])) return { fp: prints[i], dup: 'exact' };
      let hit = -1;
      for (let k = 0; k < mine.length; k++) {
        const t = mine[k]; if (used.has(k) || t.imp) continue;
        if (Math.abs(t.amount - it.amount) < 0.005 && Math.abs(day(t.date) - day(it.date)) <= 2) { hit = k; break; }
      }
      if (hit >= 0) { used.add(hit); return { fp: prints[i], dup: 'near' }; }
      return { fp: prints[i], dup: '' };
    });
  }

  return { decode, analyze, extract, parseAmount, parseDate, dateParts, curOf, categorizer, merchant, markDuplicates, fingerprints, roleOf, MAX_BYTES, MAX_ROWS, norm };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = PlataCSV;
