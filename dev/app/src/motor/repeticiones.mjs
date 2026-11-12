/* Cada cuánto se repite algo (un ingreso, un pago). El valor `repeat` puede ser:
 *   'm'        cada mes, el mismo día (o el último, si el mes es más corto)
 *   'qA,B'     dos veces al mes, los días A y B (quincena), p. ej. 'q15,30'
 *   7 / 14     cada semana / cada 2 semanas (cualquier número de días)
 *   0          una vez */
import { addDays } from './fechas.mjs';

export const isQ = (r) => typeof r === 'string' && r.charAt(0) === 'q';

/** Los dos días de una quincena, ordenados y entre 1 y 31 (por defecto 15 y 30). */
export const qDays = (r) => { const m = String(r).match(/^q(\d+),(\d+)$/); const c = (n) => Math.min(31, Math.max(1, Math.round(n) || 1)); const a = c(m ? +m[1] : 15), b = c(m ? +m[2] : 30); return a <= b ? [a, b] : [b, a]; };

export const qMake = (a, b) => { const x = qDays('q' + a + ',' + b); return 'q' + x[0] + ',' + x[1]; };

/** Normaliza `repeat` a 'm', 'qA,B' o un número de días. */
export const repN = (v) => (v === 'm' || isQ(v) ? v : Number(v) || 0);

/** El siguiente día de quincena desde d (con incl, d cuenta si cae en uno de los días). */
export function qNext(d, r, incl) {
  const dd = qDays(r), y = d.getFullYear(), m = d.getMonth(), last = new Date(y, m + 1, 0).getDate();
  for (let i = 0; i < 2; i++) { const x = Math.min(dd[i], last); if (incl ? x >= d.getDate() : x > d.getDate()) return new Date(y, m, x); }
  const l2 = new Date(y, m + 2, 0).getDate(); return new Date(y, m + 1, Math.min(dd[0], l2));
}

/** La siguiente vez después de d. */
export function nextRep(d, rep) {
  if (isQ(rep)) return qNext(d, rep, false);
  if (rep === 'm') { const y = d.getFullYear(), m = d.getMonth() + 1, last = new Date(y, m + 1, 0).getDate(); return new Date(y, m, Math.min(d.getDate(), last)); }
  return addDays(d, Number(rep) || 7);
}
