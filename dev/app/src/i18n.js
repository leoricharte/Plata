/* ---------- Idiomas: es (base) · en · ja · it · fr ---------- */
/* fr: diccionario parcial, oculto del selector hasta completarlo */
const LANG_LIST = [['auto', 'Automático'], ['es', 'Español'], ['en', 'English'], ['ja', '日本語'], ['it', 'Italiano'], ['sh', 'Srpskohrvatski']];
const LANG_CODES = ['es', 'en', 'ja', 'it', 'sh'];
const COL_OF = { es: 0, en: 1, ja: 2, it: 3, fr: 4, sh: 5 };
let LANG = 'es';
function detectLang() {
  const ls = (navigator.languages && navigator.languages.length) ? navigator.languages : [navigator.language || 'en'];
  for (let i = 0; i < ls.length; i++) { let c = String(ls[i]).slice(0, 2).toLowerCase(); if (c === 'sr' || c === 'hr' || c === 'bs') c = 'sh'; if (LANG_CODES.indexOf(c) >= 0) return c; }
  return 'en';
}
function langPref() { const s = (typeof data !== 'undefined' && data && data.settings) || {}; return LANG_CODES.indexOf(s.lang) >= 0 ? s.lang : 'auto'; }
function resolveLang() { const p = langPref(); return p === 'auto' ? detectLang() : p; }

const ES_MON = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
const ES_MONA = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const ES_DOW = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
const ES_DOWA = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'];
const LOC = {
  en: { mon: 'January February March April May June July August September October November December'.split(' '), mona: 'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec'.split(' '), dow: 'Sunday Monday Tuesday Wednesday Thursday Friday Saturday'.split(' '), dowa: 'Sun Mon Tue Wed Thu Fri Sat'.split(' ') },
  ja: { mon: '1月 2月 3月 4月 5月 6月 7月 8月 9月 10月 11月 12月'.split(' '), mona: '1月 2月 3月 4月 5月 6月 7月 8月 9月 10月 11月 12月'.split(' '), dow: '日曜日 月曜日 火曜日 水曜日 木曜日 金曜日 土曜日'.split(' '), dowa: '日 月 火 水 木 金 土'.split(' ') },
  it: { mon: 'gennaio febbraio marzo aprile maggio giugno luglio agosto settembre ottobre novembre dicembre'.split(' '), mona: 'gen feb mar apr mag giu lug ago set ott nov dic'.split(' '), dow: 'domenica lunedì martedì mercoledì giovedì venerdì sabato'.split(' '), dowa: 'dom lun mar mer gio ven sab'.split(' ') },
  sh: { mon: 'januar februar mart april maj juni juli august septembar oktobar novembar decembar'.split(' '), mona: 'jan feb mar apr maj jun jul aug sep okt nov dec'.split(' '), dow: 'nedjelja ponedjeljak utorak srijeda četvrtak petak subota'.split(' '), dowa: 'ned pon uto sri čet pet sub'.split(' ') },
  fr: { mon: 'janvier février mars avril mai juin juillet août septembre octobre novembre décembre'.split(' '), mona: 'janv. févr. mars avr. mai juin juil. août sept. oct. nov. déc.'.split(' '), dow: 'dimanche lundi mardi mercredi jeudi vendredi samedi'.split(' '), dowa: 'dim. lun. mar. mer. jeu. ven. sam.'.split(' ') }
};
const capF = (s) => s.charAt(0).toUpperCase() + s.slice(1);
const idxOf = (arr, w) => arr.indexOf(w.toLowerCase());
const jwj = (s) => s.replace(/(\d)(月|日|年)/g, '$1\u2060$2').replace(/(月|年)(\d)/g, '$1\u2060$2'); // ja: sin cortes de línea dentro de una fecha
function fmtShort(l, dw, d, mo, y) { // dw: índice o -1 · mo: índice
  const L = LOC[l], a = L.mona[mo];
  if (l === 'en') return (dw >= 0 ? L.dowa[dw] + ', ' : '') + (y ? a + ' ' + d + ', ' + y : a + ' ' + d);
  if (l === 'ja') return jwj((y ? y + '年' : '') + (mo + 1) + '月' + d + '日') + (dw >= 0 ? '(' + L.dowa[dw] + ')' : '');
  if (l === 'sh') return (dw >= 0 ? L.dowa[dw] + ', ' : '') + d + '. ' + a + (y ? ' ' + y : '');
  return (dw >= 0 ? L.dowa[dw] + ' ' : '') + d + ' ' + a + (y ? ' ' + y : '');
}
function fmtLong(l, dw, d, mo) {
  const L = LOC[l];
  if (l === 'en') return L.dow[dw] + ', ' + L.mon[mo] + ' ' + d;
  if (l === 'ja') return jwj((mo + 1) + '月' + d + '日') + ' ' + L.dow[dw];
  if (l === 'sh') return capF(L.dow[dw]) + ', ' + d + '. ' + L.mon[mo];
  return capF(L.dow[dw]) + ' ' + d + ' ' + L.mon[mo];
}
function fmtMY(l, mo, y) {
  const L = LOC[l];
  if (l === 'en') return L.mon[mo] + ' ' + y;
  if (l === 'ja') return jwj(y + '年' + (mo + 1) + '月');
  return capF(L.mon[mo]) + ' ' + y;
}

function fmtMYA(l, mo, y) {
  const L = LOC[l];
  if (l === 'en') return L.mona[mo] + ' ' + y;
  if (l === 'ja') return jwj(y + '年' + (mo + 1) + '月');
  return L.mona[mo] + ' ' + y;
}

/* ---- Tokenización: fechas, meses, nombre y números → marcadores ---- */
const MONA_RE = '(ene|feb|mar|abr|may|jun|jul|ago|sep|oct|nov|dic)';
const DOWA_RE = '(dom|lun|mar|mié|jue|vie|sáb)';
const RE_LONG = new RegExp('\\b(domingo|lunes|martes|miércoles|jueves|viernes|sábado) (\\d{1,2}) de (' + ES_MON.join('|') + ')\\b', 'gi');
const RE_MY = new RegExp('\\b(' + ES_MON.join('|') + ') (\\d{4})\\b', 'gi');
const RE_SD = new RegExp('\\b' + DOWA_RE + ' (\\d{1,2}) ' + MONA_RE + '\\b(?: (\\d{4}))?', 'gi');
const RE_D = new RegExp('\\b(\\d{1,2}) ' + MONA_RE + '\\b(?: (\\d{4}))?', 'gi');
const RE_MYA = new RegExp('\\b' + MONA_RE + ' (\\d{4})\\b', 'gi');
const RE_MF = new RegExp('\\b(' + ES_MON.join('|') + ')\\b', 'gi');
const RE_NUM = /[+−\-]?(?:S\/ ?|US\$|CHF ?|KM ?|C\$|A\$|[$€£¥●] ?)?\d(?:[\d.,]*\d)?%?/g;
const PL_SING = { 'días': 'día', 'meses': 'mes', 'semanas': 'semana', 'cuentas': 'cuenta', 'ocultas': 'oculta', 'registros': 'registro', 'cambios': 'cambio', 'ingresos': 'ingreso', 'categorías': 'categoría', 'gastos': 'gasto', 'movimientos': 'movimiento', 'metas': 'meta', 'tarjetas': 'tarjeta', 'eventos': 'evento', 'dígitos': 'dígito', 'años': 'año', 'previstos': 'previsto', 'pagos': 'pago' };
const RE_PL = new RegExp('(\\{\\d+\\}) (' + Object.keys(PL_SING).join('|') + ')(?![\\wáéíóúñ])', 'gi');
const DKEYS = ['d', 'e', 'f', 'g'];
function userNames() {
  const st = (typeof data !== 'undefined' && data && data.settings) || {}, out = [];
  [st.nick, st.first].forEach((x) => { x = (x || '').trim(); if (x.length >= 2 && out.indexOf(x) < 0) out.push(x); });
  return out;
}
function tokenize(s) {
  const ctx = { dts: [], mons: [], nums: [], long: null, my: null, mya: null, name: '' };
  let k = s;
  k = k.replace(RE_LONG, (m, w, d, mo) => { ctx.long = [idxOf(ES_DOW, w), +d, idxOf(ES_MON, mo)]; return '{D}'; });
  k = k.replace(RE_MY, (m, mo, y) => { ctx.my = [idxOf(ES_MON, mo), +y]; return '{Y}'; });
  k = k.replace(RE_SD, (m, w, d, mo, y) => { ctx.dts.push([idxOf(ES_DOWA, w), +d, idxOf(ES_MONA, mo), y ? +y : 0]); return '{d}'; });
  k = k.replace(RE_D, (m, d, mo, y) => { ctx.dts.push([-1, +d, idxOf(ES_MONA, mo), y ? +y : 0]); return '{d}'; });
  k = k.replace(RE_MYA, (m, mo, y) => { ctx.mya = [idxOf(ES_MONA, mo), +y]; return '{y}'; });
  k = k.replace(RE_MF, (m, mo) => { ctx.mons.push(idxOf(ES_MON, mo)); return '{m}'; });
  const nm = userNames();
  for (let i = 0; i < nm.length; i++) {
    const re = new RegExp('(^|[^\\p{L}\\p{N}])' + nm[i].replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '(?![\\p{L}\\p{N}])', 'gu');
    if (re.test(k)) { ctx.name = nm[i]; k = k.replace(re, '$1{n}'); break; }
  }
  k = k.replace(RE_NUM, (m) => { ctx.nums.push(m); return '{' + (ctx.nums.length - 1) + '}'; });
  k = k.replace(RE_PL, (m, n, w) => n + ' ' + PL_SING[w.toLowerCase()]);
  return { key: k, ctx: ctx };
}
function fillTpl(tpl, ctx, l) {
  let di = 0;
  return tpl
    .replace(/\{(\d+)\?([^:}]*):([^}]*)\}/g, (m, i, a, b) => (parseInt(String(ctx.nums[+i] || '').replace(/[^\d]/g, ''), 10) === 1 ? a : b))
    .replace(/\{(\d+)\}/g, (m, i) => (ctx.nums[+i] != null ? ctx.nums[+i] : m))
    .replace(/\{n\}/g, ctx.name)
    .replace(/\{([mM])\}/g, (m, c) => { const mo = ctx.mons[0]; if (mo == null) return m; const w = LOC[l].mon[mo]; return c === 'M' ? capF(w) : w; })
    .replace(/\{([defg])\}/g, (m, c) => { const x = ctx.dts[DKEYS.indexOf(c)]; return x ? fmtShort(l, x[0], x[1], x[2], x[3]) : m; })
    .replace(/\{D\}/g, () => (ctx.long ? fmtLong(l, ctx.long[0], ctx.long[1], ctx.long[2]) : '{D}'))
    .replace(/\{y\}/g, () => (ctx.mya ? fmtMYA(l, ctx.mya[0], ctx.mya[1]) : '{y}'))
    .replace(/\{Y\}/g, () => (ctx.my ? fmtMY(l, ctx.my[0], ctx.my[1]) : '{Y}'));
}

/* ---- Diccionario ---- */
const TR_ROWS = __TR_DATA__; // [[es,en,ja,it,fr], ...]
const TR_IDX = {};   // lang -> {exact:Map, lower:Map}
function buildIdx(l) {
  const col = COL_OF[l], ex = new Map(), lo = new Map();
  TR_ROWS.forEach((r) => { const v = r[col]; if (/\d/.test(r[0]) && !/\{\d+\}/.test(r[0])) { let c = 0; r = [r[0].replace(RE_NUM, () => '{' + (c++) + '}')].concat(r.slice(1)); } if (v == null || v === '') return; ex.set(r[0], v); const lk = r[0].toLowerCase(); if (!lo.has(lk)) lo.set(lk, v); });
  TR_IDX[l] = { exact: ex, lower: lo };
}
let trCache = new Map(), trSig = '';
function matchCase(src, out) {
  const a = src.charAt(0), isUpper = a !== a.toLowerCase(), isLower = a !== a.toUpperCase();
  if (isLower && !isUpper) return out.charAt(0).toLowerCase() + out.slice(1);
  if (isUpper) return out.charAt(0).toUpperCase() + out.slice(1);
  return out;
}
const GRADE_T = { en: 'Your grade was {0}.', ja: '評価は{0}でした。', it: 'La tua valutazione è stata {0}.', fr: 'Votre évaluation était {0}.', sh: 'Tvoja ocjena je {0}.' };
const RULES = [
  [/^Misma letra (\d+) meses seguidos y sube a letra\+ (dorada|platino)\.$/, (l, m) => { const g = m[2] === 'dorada'; return ({ en: 'Same letter ' + m[1] + ' months in a row and it becomes a ' + (g ? 'gold' : 'platinum') + ' letter+.', ja: '同じ評価が' + m[1] + 'か月続くと' + (g ? '金色' : 'プラチナ') + 'の「+」に。', it: 'Stessa lettera per ' + m[1] + ' mesi di fila e sale a lettera+ ' + (g ? 'dorata' : 'platino') + '.', fr: 'Même lettre ' + m[1] + ' mois d’affilée et elle devient une lettre+ ' + (g ? 'dorée' : 'platine') + '.' })[l]; }],
  [/^Misma letra (\d+) meses seguidos y baja a letra- más roja\.$/, (l, m) => ({ en: 'Same letter ' + m[1] + ' months in a row and it drops to a deeper red letter-.', ja: '同じ評価が' + m[1] + 'か月続くとより赤い「-」に下がります。', it: 'Stessa lettera per ' + m[1] + ' mesi di fila e scende a lettera- più rossa.', fr: 'Même lettre ' + m[1] + ' mois d’affilée et elle passe à une lettre- plus rouge.' })[l]],
  [/^Si sigues igual, al cuarto pasas a ([DF])-\.$/, (l, m) => ({ en: 'If it stays this way, on the fourth you drop to ' + m[1] + '-.', ja: 'このままだと4か月目に' + m[1] + '-になります。', it: 'Se resta così, al quarto scendi a ' + m[1] + '-.', fr: 'Si rien ne change, au quatrième vous passez à ' + m[1] + '-.' })[l]],
  [/^Mantén la misma letra (\d+) meses seguidos y al cuarto sube a letra\+ dorada\.$/, (l, m) => ({ en: 'Keep the same letter for ' + m[1] + ' months in a row and on the fourth it becomes a golden letter+.', ja: '同じ評価を' + m[1] + 'か月続けると、4か月目に金色の「+」に上がります。', it: 'Mantieni la stessa lettera per ' + m[1] + ' mesi di fila e al quarto diventa una lettera+ dorata.', fr: 'Gardez la même lettre ' + m[1] + ' mois d’affilée et au quatrième, elle devient une lettre+ dorée.' })[l]],
  [/^Llevas (\d+) de 2 meses con ([SABCDF])\.$/, (l, m) => ({ en: 'Month ' + m[1] + ' of 2 at ' + m[2] + '.', ja: '2か月中' + m[1] + 'か月目、' + m[2] + 'を維持。', it: 'Mese ' + m[1] + ' di 2 con ' + m[2] + '.', fr: 'Mois ' + m[1] + ' sur 2 avec ' + m[2] + '.' })[l]],
  [/^Al segundo subes a ([SABCDF])\+\.$/, (l, m) => ({ en: 'On the second, you move up to ' + m[1] + '+.', ja: '2か月目で' + m[1] + '+にアップ。', it: 'Al secondo sali a ' + m[1] + '+.', fr: 'Au deuxième, vous passez à ' + m[1] + '+.' })[l]],
  [/^Si sigues igual, al segundo pasas a ([DF])-\.$/, (l, m) => ({ en: 'If nothing changes, on the second you drop to ' + m[1] + '-.', ja: 'このままだと2か月目に' + m[1] + '-になります。', it: 'Se continui così, al secondo scendi a ' + m[1] + '-.', fr: 'Si rien ne change, au deuxième vous passez à ' + m[1] + '-.' })[l]],
  [/^Diamante · (\d+) meses seguidos$/, (l, m) => ({ en: 'Diamond · ' + m[1] + ' months in a row', ja: 'ダイヤモンド · ' + m[1] + 'か月連続', it: 'Diamante · ' + m[1] + ' mesi di fila', fr: 'Diamant · ' + m[1] + ' mois d’affilée' })[l]],
  [/^Tu evaluación fue Diamante\.$/, (l) => ({ en: 'Your grade was Diamond.', ja: '評価はダイヤモンドでした。', it: 'La tua valutazione è stata Diamante.', fr: 'Votre évaluation était Diamant.' })[l]],
  [/^Perfección\. En todo su esplendor\.$/, (l) => ({ en: 'Perfection. In all its splendor.', ja: '完璧。その輝きのすべて。', it: 'Perfezione. In tutto il suo splendore.', fr: 'La perfection. Dans toute sa splendeur.' })[l]],
  [/^([SABCDF][+-]) · (\d+) meses seguidos$/, (l, m) => ({ en: m[1] + ' · ' + m[2] + ' months in a row', ja: m[1] + ' · ' + m[2] + 'か月連続', it: m[1] + ' · ' + m[2] + ' mesi di fila', fr: m[1] + ' · ' + m[2] + ' mois d’affilée' })[l]],
  [/^Pago ([A-ZÁÉÍÓÚ\u0250-\uFFFF][^·]*)$/, (l, m) => (l === 'en' ? 'Payment ' + m[1] : l === 'it' ? 'Pagamento ' + m[1] : l === 'fr' ? 'Paiement ' + m[1] : m[1] + 'の支払い')],
  [/^(\d+) ([A-Z]{3}) en ([A-Z]{3})$/, (l, m) => (l === 'ja' ? m[1] + ' ' + m[2] + ' = ' + m[3] : m[1] + ' ' + m[2] + (l === 'fr' ? ' en ' : ' in ') + m[3])],
  [/^Tu evaluación fue ([FDCBAS][+-]?)\.$/, (l, m) => GRADE_T[l].replace('{0}', m[1])],
  [/^Principal: (\S+) · Segunda: (\S+)$/, (l, m) => ({ en: 'Primary: ' + m[1] + ' · Secondary: ' + m[2], ja: 'メイン:' + m[1] + ' · サブ:' + m[2], it: 'Principale: ' + m[1] + ' · Seconda: ' + m[2], fr: 'Principale : ' + m[1] + ' · Seconde : ' + m[2] })[l]],
  [/^Usar (\S+) como principal$/, (l, m) => ({ en: 'Use ' + m[1] + ' as primary', ja: m[1] + 'をメイン通貨にする', it: 'Usa ' + m[1] + ' come principale', fr: 'Utiliser ' + m[1] + ' comme principale' })[l]],
  [/^Saldo actual \((.+)\)$/, (l, m) => ({ en: 'Current balance', ja: '現在の残高', it: 'Saldo attuale', fr: 'Solde actuel' })[l] + ' (' + m[1] + ')'],
  [/^Monto \((.+)\)$/, (l, m) => ({ en: 'Amount', ja: '金額', it: 'Importo', fr: 'Montant' })[l] + ' (' + m[1] + ')'],
  [/^Cuenta al ejecutarlo \(monto en (.+)\)$/, (l, m) => ({ en: 'Account when executed (amount in ', ja: '実行時の口座(金額は', it: 'Conto all’esecuzione (importo in ', fr: 'Compte à l’exécution (montant en ' })[l] + m[1] + (l === 'ja' ? ')' : ')')],
  [/^Próximos (\d+) meses$/, (l, m) => ({ en: 'Next ' + m[1] + ' months', ja: '今後' + m[1] + 'か月', it: 'Prossimi ' + m[1] + ' mesi', fr: m[1] + ' prochains mois' })[l]],
  [/^¿Cargar el perfil de (.+)\?$/, (l, m) => ({ en: 'Load ' + m[1] + '’s profile?', ja: m[1] + 'のプロフィールを読み込みますか？', it: 'Caricare il profilo di ' + m[1] + '?', fr: 'Charger le profil de ' + m[1] + ' ?' })[l]],
  [/^(.+) \((S\/|US\$|C\$|A\$|\p{Sc}|[A-Z]{2,3})\)$/u, (l, m) => { const b = trCore(m[1], l); return b == null ? null : b + ' (' + m[2] + ')'; }],
  [/^(.+) \(monto en ([A-Z]{2,3})\)$/, (l, m) => { const b = trCore(m[1], l); return b == null ? null : b + ({ en: ' (amount in ', ja: '(金額は', it: ' (importo in ', fr: ' (montant en ' })[l] + m[2] + (l === 'ja' ? ')' : ')'); }],
  [/^Empieza con una copia de los límites de «(.+)»\. Luego los ajustas en Presupuesto\.$/, (l, m) => { const n = trCore(m[1], l) || m[1]; return ({ en: 'Starts with a copy of the limits from “' + n + '”. Then adjust them in Budget.', ja: '「' + n + '」の上限をコピーして開始します。あとで「予算」で調整できます。', it: 'Parte da una copia dei limiti di «' + n + '». Poi li modifichi in Budget.', fr: 'Commence avec une copie des limites de « ' + n + ' ». Ensuite, ajustez-les dans Budget.' })[l]; }],
  [/^Estás viendo y editando este set, pero hoy está activo (?:«(.+)»|el presupuesto base)\.$/, (l, m) => { const n = m[1] ? '“' + m[1] + '”' : null; return ({ en: 'You are viewing and editing this set, but today ' + (n || 'the base budget') + ' is active.', ja: 'このセットを表示・編集中ですが、現在は' + (m[1] ? '「' + m[1] + '」' : '基本の予算') + 'が有効です。', it: 'Stai vedendo e modificando questo set, ma oggi è attivo ' + (m[1] ? '«' + m[1] + '»' : 'il budget di base') + '.', fr: 'Vous consultez et modifiez ce set, mais aujourd’hui ' + (m[1] ? '« ' + m[1] + ' »' : 'le budget de base') + ' est actif.' })[l]; }]
];
const SH_FN = [
  (m) => 'Isto slovo ' + m[1] + ' mjeseca zaredom i postaje ' + (m[2] === 'dorada' ? 'zlatno' : 'platinasto') + ' slovo+.',
  (m) => 'Isto slovo ' + m[1] + ' mjeseca zaredom i spušta se na crvenije slovo-.',
  (m) => 'Ako ostane ovako, četvrti mjesec padaš na ' + m[1] + '-.',
  (m) => 'Zadrži isto slovo ' + m[1] + ' mjeseca zaredom i četvrti put postaje zlatno slovo+.',
  (m) => 'Mjesec ' + m[1] + ' od 4 sa ' + m[2] + '.',
  (m) => 'Četvrti put se penješ na ' + m[1] + '+.',
  (m) => m[1] + ' · ' + m[2] + ' mjeseca zaredom',
  (m) => 'Uplata ' + m[1],
  (m) => m[1] + ' ' + m[2] + ' u ' + m[3],
  (m) => GRADE_T.sh.replace('{0}', m[1]),
  (m) => 'Glavna: ' + m[1] + ' · Druga: ' + m[2],
  (m) => 'Koristi ' + m[1] + ' kao glavnu',
  (m) => 'Trenutno stanje (' + m[1] + ')',
  (m) => 'Iznos (' + m[1] + ')',
  (m) => 'Račun pri izvršenju (iznos u ' + m[1] + ')',
  (m) => 'Sljedećih ' + m[1] + ' mjeseci',
  (m) => 'Učitati profil korisnika ' + m[1] + '?',
  (m) => { const b = trCore(m[1], 'sh'); return b == null ? null : b + ' (' + m[2] + ')'; },
  (m) => { const b = trCore(m[1], 'sh'); return b == null ? null : b + ' (iznos u ' + m[2] + ')'; },
  (m) => 'Počinje kopijom limita iz „' + (trCore(m[1], 'sh') || m[1]) + '”. Zatim ih podesi u Budžetu.',
  (m) => 'Pregledaš i uređuješ ovaj set, ali danas je aktivan ' + (m[1] ? '„' + m[1] + '”' : 'osnovni budžet') + '.'
];
function trCore(core, l) {
  const tk = tokenize(core), key = tk.key, I = TR_IDX[l];
  let v = I.exact.get(key);
  if (v != null) return fillTpl(v, tk.ctx, l);
  const allCaps = core === core.toUpperCase() && core !== core.toLowerCase();
  const lk = key.toLowerCase();
  v = I.lower.get(lk);
  if (v != null) { const o = fillTpl(v, tk.ctx, l); return allCaps ? o.toUpperCase() : matchCase(core, o); }
  if (/^(\{[dDYym]\}|\s|·|[-–—])+$/.test(key)) return fillTpl(key, tk.ctx, l);
  for (let i = 0; i < RULES.length; i++) { const m = RULES[i][0].exec(core); if (m) return l === 'sh' ? (SH_FN[i] ? SH_FN[i](m) : null) : RULES[i][1](l, m); }
  return null;
}
function trString(core, l) {
  let r = trCore(core, l);
  if (r != null) return r;
  if (/[.!]$/.test(core) && core.length > 3) { const q = trCore(core.slice(0, -1), l); if (q != null) return q + (l === 'ja' ? '。' : core.slice(-1)); }
  if (core.indexOf(' · ') > 0) {
    const parts = core.split(' · '); let hit = false;
    const out = parts.map((p) => { const q = trString(p, l); if (q != null) { hit = true; return q; } return p; });
    if (hit) return out.join(' · ');
  }
  return null;
}
function trText(raw) {
  if (LANG === 'es') return raw;
  const m = /^(\s*)([\s\S]*?)(\s*)$/.exec(raw);
  if (!m[2]) return raw;
  const core = m[2].replace(/\s+/g, ' ');
  const sig = LANG + '|' + userNames().join(',');
  if (sig !== trSig) { trCache = new Map(); trSig = sig; }
  let r = trCache.get(core);
  if (r === undefined) { r = trString(core, LANG); trCache.set(core, r); }
  return r == null ? raw : m[1] + r + m[3];
}

/* ---- Traductor del DOM ---- */
const TR_ATTRS = ['placeholder', 'aria-label', 'title', 'alt', 'label'];
const textRec = new WeakMap(), attrRec = new WeakMap();
const SKIP_TAG = { SCRIPT: 1, STYLE: 1, TEXTAREA: 1, NOSCRIPT: 1 };
function trTextNode(n) {
  const p = n.parentNode; if (p && (SKIP_TAG[p.nodeName] || (p.closest && p.closest('[data-notr]')))) return;
  const rec = textRec.get(n), cur = n.nodeValue;
  let src;
  if (rec && rec.out === cur) src = rec.src; else src = cur;
  const out = trText(src);
  if (out !== cur) n.nodeValue = out;
  if (out !== src || rec) textRec.set(n, { src: src, out: out });
}
function trAttrs(el) {
  if (!el.getAttribute) return;
  let rec = attrRec.get(el);
  for (let i = 0; i < TR_ATTRS.length; i++) {
    const a = TR_ATTRS[i], cur = el.getAttribute(a);
    if (cur == null) continue;
    const r = rec && rec[a];
    const src = (r && r.out === cur) ? r.src : cur, out = trText(src);
    if (out !== cur) el.setAttribute(a, out);
    if (out !== src || r) { if (!rec) { rec = {}; attrRec.set(el, rec); } rec[a] = { src: src, out: out }; }
  }
}
function trTree(root) {
  if (!root) return;
  if (root.nodeType === 3) { trTextNode(root); return; }
  if (root.nodeType !== 1) return;
  if (SKIP_TAG[root.nodeName] || (root.hasAttribute && root.hasAttribute('data-notr'))) return;
  trAttrs(root);
  const w = document.createTreeWalker(root, 1 | 4, null);
  let n = w.nextNode();
  while (n) {
    if (n.nodeType === 3) trTextNode(n);
    else if (SKIP_TAG[n.nodeName] || (n.hasAttribute && n.hasAttribute('data-notr'))) { /* se omite el contenido */ } else trAttrs(n);
    n = w.nextNode();
  }
}
let trObs = null;
function startTrObserver() {
  if (trObs || !window.MutationObserver) return;
  trObs = new MutationObserver((ms) => {
    if (LANG === 'es') return;
    for (let i = 0; i < ms.length; i++) {
      const m = ms[i];
      if (m.type === 'childList') m.addedNodes.forEach((n) => trTree(n));
      else if (m.type === 'characterData') trTextNode(m.target);
      else if (m.type === 'attributes') trAttrs(m.target);
    }
  });
  trObs.observe(document.documentElement, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: TR_ATTRS });
}
function retranslateAll() {
  trCache = new Map(); trSig = '';
  trTree(document.body);
}
function applyLang() {
  const l = resolveLang();
  const changed = l !== LANG;
  LANG = l;
  document.documentElement.lang = l;
  if (l !== 'es' && !TR_IDX[l]) buildIdx(l);
  startTrObserver();
  if (changed || true) retranslateAll();
  return changed;
}
