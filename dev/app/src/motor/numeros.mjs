/* Números y montos. */

/** Redondea a 2 decimales (céntimos). */
export const round2 = (n) => Math.round(n * 100) / 100;

/** Tope de un monto, para que un dato roto o malicioso no rompa los cálculos. */
export const MAXAMT = 999999999;

/** Lleva un monto al rango ±MAXAMT; NaN o ±Infinity pasan a 0. Lo que no es número se devuelve tal cual. */
export const clampAmt = (n) => (typeof n === 'number' && isFinite(n) ? Math.max(-MAXAMT, Math.min(MAXAMT, n)) : (typeof n === 'number' ? 0 : n));

/** Suma f(x) para cada x de la lista. */
export const sum = (a, f) => a.reduce((s, x) => s + f(x), 0);
