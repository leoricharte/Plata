/* Fechas. Plata guarda los días como texto 'AAAA-MM-DD' y trabaja con Date a medianoche hora local (nunca UTC). */

export const pad = (n) => String(n).padStart(2, '0');

/** Date → 'AAAA-MM-DD' (hora local). */
export const iso = (d) => d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate());

/** 'AAAA-MM-DD' → Date a medianoche local. */
export const pd = (s) => { const p = String(s).split('-').map(Number); return new Date(p[0], p[1] - 1, p[2]); };

export const addDays = (d, n) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);

/** El día 1 del mes que está n meses después de d. */
export const addMonths = (d, n) => new Date(d.getFullYear(), d.getMonth() + n, 1);
