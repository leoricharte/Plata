/* ---------- Utilidades ---------- */
const $ = (s, el) => (el || document).querySelector(s);
const clone = (o) => JSON.parse(JSON.stringify(o));
const { sum, iso, pd, addDays, MAXAMT, clampAmt } = Motor;   /* del motor (src/motor/): fechas y montos, probados en dev/tests/motor.mjs */
/* ---------- Monedas (hasta 2 activas: principal + segunda) ---------- */
const { CURRENCIES, CUR_GRID, CUR_ORDER, CUR_OTHERS, normCustom, regCustom, fxDefault, decOf } = Motor;   /* monedas: del motor (src/motor/monedas.mjs) */
const curP = () => { const c = (data.settings || {}).currency; return CURRENCIES[c] ? c : 'USD'; };
const curS = () => { const c = (data.settings || {}).currency2; return CURRENCIES[c] && c !== curP() ? c : ''; };
const activeCurs = () => [curP()].concat(curS() ? [curS()] : []);
const curK = () => CURRENCIES[curP()].k || 1;
function guessCur() {
  let reg = ''; try { reg = String((navigator.languages && navigator.languages[0]) || navigator.language || '').split('-')[1] || ''; } catch (e) { /* sin idioma */ }
  reg = reg.toUpperCase();
  const m = { US: 'USD', GB: 'GBP', JP: 'JPY', CN: 'CNY', AU: 'AUD', CA: 'CAD', CH: 'CHF', BA: 'BAM', HR: 'EUR', SG: 'SGD', PE: 'PEN', DE: 'EUR', FR: 'EUR', IT: 'EUR', ES: 'EUR', NL: 'EUR', PT: 'EUR', IE: 'EUR', AT: 'EUR', BE: 'EUR' };
  /* la zona horaria manda: es lo más cercano a dónde vive la persona; el idioma es solo respaldo */
  let tz = ''; try { tz = curByTZ(); } catch (e) { /* sin zona */ }
  const c = (tz && CURRENCIES[tz] ? tz : '') || m[reg] || 'USD';
  return c === 'PEN' ? ['PEN', 'USD'] : [c];
}
const fmt = (n) => (n < 0 ? '−' : '') + symOf(curP()) + Math.abs(Math.round(n)).toLocaleString('en-US');
const fmt2 = (n) => symOf(curP()) + Math.abs(n).toLocaleString('en-US', { minimumFractionDigits: decOf(curP()), maximumFractionDigits: decOf(curP()) });
const axis = (v) => { const a = Math.abs(v), sg = v < 0 ? '−' : '', y = symOf(curP()).trim(); return a >= 1000 ? sg + y + (a / 1000).toString().replace(/\.0$/, '') + 'k' : sg + y + a; };
const dshort = (d) => d.getDate() + ' ' + MON[d.getMonth()];
const dlabel = (d) => DOW[d.getDay()] + ' ' + d.getDate() + ' ' + MON[d.getMonth()];
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[c]));
const plural = (n, one, many) => n + ' ' + (n === 1 ? one : many);

