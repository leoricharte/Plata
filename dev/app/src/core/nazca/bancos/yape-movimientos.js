/* ---------- Nazca · Yape (Perú) · Reporte de movimientos (Excel) ----------
 * Yape no tiene estado de cuenta en PDF: la app deja descargar un "Reporte de Movimientos" en Excel (.xlsx). Se lee en el dispositivo con xlsx.js.
 * Diseño que espera (hoja "Movimientos"): título "Reporte de Movimientos" y, más abajo, la fila de títulos
 *   Tipo de Transacción | Origen | Destino | Monto | Mensaje | Fecha de operación
 * con filas como "PAGASTE · Tu nombre · Comercio o persona · 16.08 · (mensaje) · 20/10/2026 13:10:26" o "TE PAGÓ" (te pagaron). Los nombres de otras personas vienen
 * enmascarados ("Sara Ron*"). Probado con UN reporte real (≈350 movimientos) y con el fixture inventado dev/tests/xlsx/yape-reporte.xlsx.
 * Para Plata: PAGASTE → negativo, TE PAGÓ → positivo. El reporte NO trae saldos ni totales, así que no hay comprobación "cuadra" (check: null).
 * Otros tipos que Yape pudiera usar se reconocen por su verbo; los que no se reconocen se cuentan como "no se pudieron leer". */
const NazcaYape = (() => {
  const norm = (t) => String(t == null ? '' : t).toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/\s+/g, ' ').trim();
  const REQ = ['tipo de transaccion', 'origen', 'destino', 'monto', 'fecha de operacion'];
  const pad = (n) => String(n).padStart(2, '0');
  const NEG = /^(pagaste|yapeaste|enviaste|recargaste|retiraste|compraste|transferiste)\b/, POS = /^(te pago|te yapeo|te yapearon|te devolvio|te envio|te transfirio|recibiste|devolucion)\b/;
  function headerAt(rows) {
    for (let i = 0; i < Math.min(rows.length, 20); i++) {
      const r = (rows[i] || []).map(norm), col = {}; REQ.forEach((k) => { const j = r.indexOf(k); if (j >= 0) col[k] = j; });
      if (REQ.every((k) => k in col)) { const m = r.indexOf('mensaje'); return { row: i, type: col['tipo de transaccion'], from: col.origen, to: col.destino, amount: col.monto, date: col['fecha de operacion'], msg: m >= 0 ? m : -1 }; }
    }
    return null;
  }
  const detect = (rows) => !!(Array.isArray(rows) && headerAt(rows));
  function money(s) {
    const t = String(s || '').replace(/[^\d.,-]/g, ''); if (!t) return NaN;
    const c = t.lastIndexOf(','), d = t.lastIndexOf('.'); let u = t;
    if (c > d) u = t.replace(/\./g, '').replace(',', '.'); else u = t.replace(/,/g, '');
    return /^-?\d+(\.\d+)?$/.test(u) ? Math.round(parseFloat(u) * 100) / 100 : NaN;
  }
  const clean = (t) => String(t || '').replace(/\s+/g, ' ').replace(/[:\s-]*N[º°o]\.?\s*[\w-]{4,}/gi, '').replace(/\s+/g, ' ').trim();
  function read(rows) {
    const h = headerAt(rows); if (!h) return { error: 'no_header' };
    const items = [], skipped = { unreadable: 0, zero: 0 }; let from = '', to = '', line = 0;
    for (let i = h.row + 1; i < rows.length; i++) {
      const r = rows[i] || []; if (!r.some((c) => String(c || '').trim())) continue; line++;
      const ty = norm(r[h.type]), amt = money(r[h.amount]), dm = /^(\d{1,2})\/(\d{1,2})\/(\d{4})/.exec(String(r[h.date] || '').trim());
      const sign = NEG.test(ty) ? -1 : POS.test(ty) ? 1 : 0;
      if (!sign || !dm || !(amt === amt)) { skipped.unreadable++; continue; } if (amt === 0) { skipped.zero++; continue; }
      const date = dm[3] + '-' + pad(+dm[2]) + '-' + pad(+dm[1]), who = String(r[sign < 0 ? h.to : h.from] || '').replace(/\s+/g, ' ').trim(), msg = h.msg >= 0 ? clean(r[h.msg]) : '';
      const desc = ((who || (sign < 0 ? 'Yape' : 'Yape (recibido)')) + (msg ? ' · ' + msg : '')).slice(0, 90);
      items.push({ line, date, desc, amount: sign * Math.abs(amt), cur: 'PEN' }); if (!from || date < from) from = date; if (!to || date > to) to = date;
    }
    return { bank: 'yape', kind: 'corriente', label: 'Yape · Movimientos', cur: 'PEN', account: { last4: '' }, period: from ? { from, to } : null, items, skipped, check: null };
  }
  return { id: 'yape-movimientos', bank: 'yape', label: 'Yape · Movimientos', detect, read };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaYape;
