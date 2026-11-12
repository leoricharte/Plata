/* ---------- Utilidades ---------- */
const $ = (s, el) => (el || document).querySelector(s);
const clone = (o) => JSON.parse(JSON.stringify(o));
const { sum, iso, pd, addDays, MAXAMT, clampAmt } = Motor;   /* del motor (src/motor/): fechas y montos, probados en dev/tests/motor.mjs */
/* ---------- Monedas (hasta 2 activas: principal + segunda) ---------- */
const CURRENCIES = {
  USD: { sym: '$', name: 'Dólar estadounidense', rate: 1, k: 1 }, EUR: { sym: '€', name: 'Euro', rate: 0.92, k: 1 },
  JPY: { sym: '¥', name: 'Yen japonés', rate: 150, k: 100, dec: 0 }, GBP: { sym: '£', name: 'Libra esterlina', rate: 0.79, k: 1 },
  CAD: { sym: 'C$', name: 'Dólar canadiense', rate: 1.37, k: 1 }, BAM: { sym: 'KM ', name: 'Marco convertible', rate: 1.8, k: 2 },
  PEN: { sym: 'S/ ', name: 'Sol peruano', rate: 3.7, k: 4 },
  MXN: { sym: 'MX$', name: 'Peso mexicano', rate: 18.5, k: 18 },
  ARS: { sym: 'AR$', name: 'Peso argentino', rate: 1000, k: 1000 },
  BRL: { sym: 'R$', name: 'Real brasileño', rate: 5.4, k: 5 },
  CLP: { sym: 'CL$', name: 'Peso chileno', rate: 940, k: 900, dec: 0 },
  COP: { sym: 'CO$', name: 'Peso colombiano', rate: 3900, k: 4000, dec: 0 },
  UYU: { sym: 'UY$', name: 'Peso uruguayo', rate: 40, k: 40 },
  PYG: { sym: '₲', name: 'Guaraní paraguayo', rate: 7500, k: 7500, dec: 0 },
  BOB: { sym: 'Bs ', name: 'Boliviano', rate: 6.9, k: 7 },
  VES: { sym: 'Bs.S ', name: 'Bolívar venezolano', rate: 150, k: 150 },
  CRC: { sym: '₡', name: 'Colón costarricense', rate: 510, k: 500, dec: 0 },
  GTQ: { sym: 'Q', name: 'Quetzal guatemalteco', rate: 7.7, k: 8 },
  HNL: { sym: 'L ', name: 'Lempira hondureño', rate: 26, k: 26 },
  NIO: { sym: 'C$', name: 'Córdoba nicaragüense', rate: 36.8, k: 37 },
  DOP: { sym: 'RD$', name: 'Peso dominicano', rate: 62, k: 60 },
  CUP: { sym: 'CUP ', name: 'Peso cubano', rate: 24, k: 24 },
  /* resto del mundo (para "Otros"; tipos de cambio aproximados, editables) */
  AED: { sym: 'AED ', name: 'Dírham de los EAU', rate: 3.67, k: 4 },
  AFN: { sym: 'AFN ', name: 'Afgani', rate: 70, k: 70 },
  ALL: { sym: 'ALL ', name: 'Lek albanés', rate: 92, k: 90 },
  AMD: { sym: 'AMD ', name: 'Dram armenio', rate: 390, k: 400 },
  ANG: { sym: 'ANG ', name: 'Florín antillano', rate: 1.79, k: 2 },
  AOA: { sym: 'AOA ', name: 'Kwanza angoleño', rate: 920, k: 900 },
  AUD: { sym: 'A$', name: 'Dólar australiano', rate: 1.52, k: 2 },
  AWG: { sym: 'AWG ', name: 'Florín arubeño', rate: 1.79, k: 2 },
  AZN: { sym: 'AZN ', name: 'Manat azerbaiyano', rate: 1.7, k: 2 },
  BBD: { sym: 'BBD ', name: 'Dólar barbadense', rate: 2, k: 2 },
  BDT: { sym: 'BDT ', name: 'Taka bangladesí', rate: 120, k: 100 },
  BGN: { sym: 'BGN ', name: 'Lev búlgaro', rate: 1.8, k: 2 },
  BHD: { sym: 'BHD ', name: 'Dinar bareiní', rate: 0.376, k: 1, dec: 3 },
  BIF: { sym: 'BIF ', name: 'Franco burundés', rate: 2900, k: 3000, dec: 0 },
  BMD: { sym: 'BMD ', name: 'Dólar bermudeño', rate: 1, k: 1 },
  BND: { sym: 'BND ', name: 'Dólar de Brunéi', rate: 1.35, k: 1 },
  BSD: { sym: 'BSD ', name: 'Dólar bahameño', rate: 1, k: 1 },
  BTN: { sym: 'BTN ', name: 'Ngultrum butanés', rate: 84, k: 80 },
  BWP: { sym: 'BWP ', name: 'Pula botsuano', rate: 13.6, k: 10 },
  BYN: { sym: 'BYN ', name: 'Rublo bielorruso', rate: 3.3, k: 3 },
  BZD: { sym: 'BZD ', name: 'Dólar beliceño', rate: 2, k: 2 },
  CDF: { sym: 'CDF ', name: 'Franco congoleño', rate: 2800, k: 3000 },
  CHF: { sym: 'CHF ', name: 'Franco suizo', rate: 0.88, k: 1 },
  CNY: { sym: 'CN¥', name: 'Yuan chino', rate: 7.25, k: 7 },
  CVE: { sym: 'CVE ', name: 'Escudo caboverdiano', rate: 101, k: 100 },
  CZK: { sym: 'CZK ', name: 'Corona checa', rate: 23, k: 20 },
  DJF: { sym: 'DJF ', name: 'Franco yibutiano', rate: 178, k: 200, dec: 0 },
  DKK: { sym: 'DKK ', name: 'Corona danesa', rate: 6.9, k: 7 },
  DZD: { sym: 'DZD ', name: 'Dinar argelino', rate: 134, k: 100 },
  EGP: { sym: 'EGP ', name: 'Libra egipcia', rate: 48, k: 50 },
  ETB: { sym: 'ETB ', name: 'Birr etíope', rate: 120, k: 100 },
  FJD: { sym: 'FJD ', name: 'Dólar fiyiano', rate: 2.25, k: 2 },
  GEL: { sym: 'GEL ', name: 'Lari georgiano', rate: 2.7, k: 3 },
  GHS: { sym: 'GHS ', name: 'Cedi ghanés', rate: 15, k: 20 },
  GMD: { sym: 'GMD ', name: 'Dalasi gambiano', rate: 70, k: 70 },
  GNF: { sym: 'GNF ', name: 'Franco guineano', rate: 8600, k: 9000, dec: 0 },
  GYD: { sym: 'GYD ', name: 'Dólar guyanés', rate: 209, k: 200 },
  HKD: { sym: 'HK$', name: 'Dólar de Hong Kong', rate: 7.8, k: 8 },
  HRK: { sym: 'HRK ', name: 'Kuna croata', rate: 6.9, k: 7 },
  HTG: { sym: 'HTG ', name: 'Gourde haitiano', rate: 131, k: 100 },
  HUF: { sym: 'HUF ', name: 'Forinto húngaro', rate: 360, k: 400, dec: 0 },
  IDR: { sym: 'IDR ', name: 'Rupia indonesia', rate: 16000, k: 20000, dec: 0 },
  ILS: { sym: '₪', name: 'Nuevo séquel israelí', rate: 3.7, k: 4 },
  INR: { sym: '₹', name: 'Rupia india', rate: 84, k: 80 },
  IQD: { sym: 'IQD ', name: 'Dinar iraquí', rate: 1310, k: 1000, dec: 0 },
  IRR: { sym: 'IRR ', name: 'Rial iraní', rate: 42000, k: 40000, dec: 0 },
  ISK: { sym: 'ISK ', name: 'Corona islandesa', rate: 138, k: 100, dec: 0 },
  JMD: { sym: 'JMD ', name: 'Dólar jamaiquino', rate: 157, k: 200 },
  JOD: { sym: 'JOD ', name: 'Dinar jordano', rate: 0.709, k: 1, dec: 3 },
  KES: { sym: 'KES ', name: 'Chelín keniano', rate: 129, k: 100 },
  KGS: { sym: 'KGS ', name: 'Som kirguís', rate: 86, k: 90 },
  KHR: { sym: 'KHR ', name: 'Riel camboyano', rate: 4100, k: 4000, dec: 0 },
  KRW: { sym: '₩', name: 'Won surcoreano', rate: 1350, k: 1000, dec: 0 },
  KWD: { sym: 'KWD ', name: 'Dinar kuwaití', rate: 0.307, k: 1, dec: 3 },
  KZT: { sym: 'KZT ', name: 'Tenge kazajo', rate: 500, k: 500 },
  LAK: { sym: 'LAK ', name: 'Kip laosiano', rate: 21900, k: 20000, dec: 0 },
  LBP: { sym: 'LBP ', name: 'Libra libanesa', rate: 89500, k: 90000, dec: 0 },
  LKR: { sym: 'LKR ', name: 'Rupia de Sri Lanka', rate: 300, k: 300 },
  MAD: { sym: 'MAD ', name: 'Dírham marroquí', rate: 9.9, k: 10 },
  MDL: { sym: 'MDL ', name: 'Leu moldavo', rate: 17.8, k: 20 },
  MGA: { sym: 'MGA ', name: 'Ariary malgache', rate: 4500, k: 4000, dec: 0 },
  MKD: { sym: 'MKD ', name: 'Denar macedonio', rate: 57, k: 60 },
  MMK: { sym: 'MMK ', name: 'Kyat birmano', rate: 2100, k: 2000, dec: 0 },
  MNT: { sym: 'MNT ', name: 'Tugrik mongol', rate: 3400, k: 3000, dec: 0 },
  MOP: { sym: 'MOP ', name: 'Pataca de Macao', rate: 8, k: 8 },
  MUR: { sym: 'MUR ', name: 'Rupia mauriciana', rate: 46, k: 50 },
  MVR: { sym: 'MVR ', name: 'Rufiyaa maldiva', rate: 15.4, k: 20 },
  MWK: { sym: 'MWK ', name: 'Kwacha malauí', rate: 1730, k: 2000, dec: 0 },
  MYR: { sym: 'RM', name: 'Ringgit malayo', rate: 4.4, k: 4 },
  MZN: { sym: 'MZN ', name: 'Metical mozambiqueño', rate: 64, k: 60 },
  NAD: { sym: 'NAD ', name: 'Dólar namibio', rate: 18, k: 20 },
  NGN: { sym: '₦', name: 'Naira nigeriano', rate: 1600, k: 2000 },
  NOK: { sym: 'NOK ', name: 'Corona noruega', rate: 10.8, k: 10 },
  NPR: { sym: 'NPR ', name: 'Rupia nepalí', rate: 134, k: 100 },
  NZD: { sym: 'NZ$', name: 'Dólar neozelandés', rate: 1.65, k: 2 },
  OMR: { sym: 'OMR ', name: 'Rial omaní', rate: 0.385, k: 1, dec: 3 },
  PGK: { sym: 'PGK ', name: 'Kina papú', rate: 4, k: 4 },
  PHP: { sym: '₱', name: 'Peso filipino', rate: 57, k: 60 },
  PKR: { sym: 'PKR ', name: 'Rupia pakistaní', rate: 280, k: 300 },
  PLN: { sym: 'PLN ', name: 'Esloti polaco', rate: 4, k: 4 },
  QAR: { sym: 'QAR ', name: 'Rial catarí', rate: 3.64, k: 4 },
  RON: { sym: 'RON ', name: 'Leu rumano', rate: 4.6, k: 5 },
  RSD: { sym: 'RSD ', name: 'Dinar serbio', rate: 108, k: 100 },
  RUB: { sym: '₽', name: 'Rublo ruso', rate: 92, k: 90 },
  RWF: { sym: 'RWF ', name: 'Franco ruandés', rate: 1400, k: 1000, dec: 0 },
  SAR: { sym: 'SAR ', name: 'Rial saudí', rate: 3.75, k: 4 },
  SBD: { sym: 'SBD ', name: 'Dólar de las Islas Salomón', rate: 8.5, k: 8 },
  SCR: { sym: 'SCR ', name: 'Rupia seychellense', rate: 14, k: 10 },
  SEK: { sym: 'SEK ', name: 'Corona sueca', rate: 10.5, k: 10 },
  SGD: { sym: 'S$', name: 'Dólar de Singapur', rate: 1.35, k: 1 },
  SRD: { sym: 'SRD ', name: 'Dólar surinamés', rate: 36, k: 40 },
  SZL: { sym: 'SZL ', name: 'Lilangeni suazi', rate: 18, k: 20 },
  THB: { sym: '฿', name: 'Baht tailandés', rate: 35, k: 40 },
  TJS: { sym: 'TJS ', name: 'Somoni tayiko', rate: 10.6, k: 10 },
  TMT: { sym: 'TMT ', name: 'Manat turcomano', rate: 3.5, k: 4 },
  TND: { sym: 'TND ', name: 'Dinar tunecino', rate: 3.1, k: 3 },
  TOP: { sym: 'TOP ', name: 'Paanga tongano', rate: 2.4, k: 2 },
  TRY: { sym: '₺', name: 'Lira turca', rate: 34, k: 30 },
  TTD: { sym: 'TTD ', name: 'Dólar de Trinidad y Tobago', rate: 6.8, k: 7 },
  TWD: { sym: 'NT$', name: 'Nuevo dólar taiwanés', rate: 32, k: 30 },
  TZS: { sym: 'TZS ', name: 'Chelín tanzano', rate: 2700, k: 3000, dec: 0 },
  UAH: { sym: '₴', name: 'Grivna ucraniana', rate: 41, k: 40 },
  UGX: { sym: 'UGX ', name: 'Chelín ugandés', rate: 3700, k: 4000, dec: 0 },
  UZS: { sym: 'UZS ', name: 'Som uzbeko', rate: 12800, k: 10000, dec: 0 },
  VND: { sym: '₫', name: 'Dong vietnamita', rate: 25000, k: 20000, dec: 0 },
  VUV: { sym: 'VUV ', name: 'Vatu vanuatuense', rate: 119, k: 100, dec: 0 },
  WST: { sym: 'WST ', name: 'Tala samoano', rate: 2.8, k: 3 },
  XAF: { sym: 'XAF ', name: 'Franco CFA de África Central', rate: 610, k: 600, dec: 0 },
  XCD: { sym: 'EC$', name: 'Dólar del Caribe Oriental', rate: 2.7, k: 3 },
  XOF: { sym: 'XOF ', name: 'Franco CFA de África Occidental', rate: 610, k: 600, dec: 0 },
  XPF: { sym: 'XPF ', name: 'Franco CFP', rate: 110, k: 100, dec: 0 },
  YER: { sym: 'YER ', name: 'Rial yemení', rate: 250, k: 200, dec: 0 },
  ZAR: { sym: 'R ', name: 'Rand sudafricano', rate: 18, k: 20 },
  ZMW: { sym: 'ZMW ', name: 'Kwacha zambiano', rate: 26, k: 30 }
};
const CUR_GRID = ['USD', 'EUR', 'JPY', 'GBP', 'CAD', 'BAM', 'PEN', 'MXN', 'ARS', 'BRL', 'CLP', 'COP', 'UYU', 'PYG', 'BOB', 'VES', 'CRC', 'GTQ', 'HNL', 'NIO', 'DOP', 'CUP'];
const CUR_ORDER = CUR_GRID.slice();
const CUR_BUILTIN = Object.keys(CURRENCIES);
const CUR_OTHERS = () => CUR_BUILTIN.filter((c) => CUR_GRID.indexOf(c) < 0).sort();
const normCustom = (s) => { s = Array.from(String(s || '').trim().toUpperCase().replace(/\s+/g, '')).slice(0, 3).join(''); return /^[\p{L}\p{N}$€£¥₿₽₩₹₫₺₴]{1,3}$/u.test(s) && CUR_BUILTIN.indexOf(s) < 0 ? s : ''; };
function regCustom(code) {
  Object.keys(CURRENCIES).forEach((k) => { if (CURRENCIES[k].custom) delete CURRENCIES[k]; });
  for (let i = CUR_ORDER.length - 1; i >= 0; i--) if (CUR_GRID.indexOf(CUR_ORDER[i]) < 0) CUR_ORDER.splice(i, 1);
  const c = normCustom(code); if (!c) return '';
  CURRENCIES[c] = { sym: /^\p{L}+$/u.test(c) ? c + ' ' : c, name: 'Personalizada', rate: 1, k: 1, custom: true };
  CUR_ORDER.push(c); return c;
}
const curP = () => { const c = (data.settings || {}).currency; return CURRENCIES[c] ? c : 'USD'; };
const curS = () => { const c = (data.settings || {}).currency2; return CURRENCIES[c] && c !== curP() ? c : ''; };
const activeCurs = () => [curP()].concat(curS() ? [curS()] : []);
const curK = () => CURRENCIES[curP()].k || 1;
const fxDefault = (p, s) => Number((CURRENCIES[s].rate / CURRENCIES[p].rate).toPrecision(4));
const decOf = (cur) => (CURRENCIES[cur] && CURRENCIES[cur].dec != null ? CURRENCIES[cur].dec : 2);
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

