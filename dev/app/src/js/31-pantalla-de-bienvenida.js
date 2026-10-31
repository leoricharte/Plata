/* ---------- Pantalla de bienvenida ---------- */
const KEY_WELCOME = 'finanzas.welcomed';
const wSeen = () => { try { return localStorage.getItem(KEY_WELCOME) === '1'; } catch (e) { return false; } };
function wMark(v) { try { if (v) localStorage.setItem(KEY_WELCOME, '1'); else localStorage.removeItem(KEY_WELCOME); } catch (e) { /* sin almacenamiento */ } }
function hideWelcome() { const w = $('#welcome'); wMark(true); const m = $('#wmenu'); if (m) m.remove(); const b = $('#wmenuback'); if (b) b.remove(); if (w) { w.style.transition = 'opacity .35s'; w.style.opacity = '0'; setTimeout(() => w.remove(), 380); } ui.w = null; }
const TZ_CUR = { 'America/Lima': 'PEN', 'America/Mexico_City': 'MXN', 'America/Cancun': 'MXN', 'America/Monterrey': 'MXN', 'America/Tijuana': 'MXN', 'America/Bogota': 'COP', 'America/Santiago': 'CLP', 'America/Sao_Paulo': 'BRL', 'America/Montevideo': 'UYU', 'America/Asuncion': 'PYG', 'America/La_Paz': 'BOB', 'America/Caracas': 'VES', 'America/Costa_Rica': 'CRC', 'America/Guatemala': 'GTQ', 'America/Tegucigalpa': 'HNL', 'America/Managua': 'NIO', 'America/Santo_Domingo': 'DOP', 'America/Havana': 'CUP', 'America/Toronto': 'CAD', 'America/Vancouver': 'CAD', 'America/Edmonton': 'CAD', 'America/Winnipeg': 'CAD', 'America/Halifax': 'CAD', 'America/Montreal': 'CAD', 'America/Regina': 'CAD', 'America/St_Johns': 'CAD', 'Europe/London': 'GBP', 'Europe/Sarajevo': 'BAM', 'Asia/Tokyo': 'JPY', 'Asia/Dubai': 'AED', 'Asia/Kolkata': 'INR', 'Asia/Calcutta': 'INR', 'Asia/Shanghai': 'CNY', 'Asia/Seoul': 'KRW', 'Asia/Singapore': 'SGD', 'Asia/Hong_Kong': 'HKD', 'Asia/Bangkok': 'THB', 'Asia/Manila': 'PHP', 'Asia/Jakarta': 'IDR', 'Europe/Zurich': 'CHF', 'Europe/Warsaw': 'PLN', 'Europe/Prague': 'CZK', 'Europe/Stockholm': 'SEK', 'Europe/Oslo': 'NOK', 'Europe/Copenhagen': 'DKK', 'Europe/Istanbul': 'TRY', 'Europe/Moscow': 'RUB', 'Europe/Kiev': 'UAH', 'Europe/Kyiv': 'UAH', 'Africa/Johannesburg': 'ZAR', 'Africa/Cairo': 'EGP', 'Africa/Lagos': 'NGN', 'Africa/Nairobi': 'KES', 'Australia/Sydney': 'AUD', 'Australia/Melbourne': 'AUD', 'Australia/Perth': 'AUD', 'Pacific/Auckland': 'NZD', 'America/Argentina/Buenos_Aires': 'ARS' };
(function () {
  const add = (c, zs) => zs.split(' ').forEach((z) => { if (!TZ_CUR[z]) TZ_CUR[z] = c; });
  add('USD', 'America/New_York America/Chicago America/Denver America/Los_Angeles America/Phoenix America/Anchorage America/Detroit America/Boise America/Indiana/Indianapolis America/Kentucky/Louisville America/Adak Pacific/Honolulu America/Panama America/El_Salvador America/Guayaquil America/Puerto_Rico Pacific/Guam');
  add('EUR', 'Europe/Madrid Europe/Paris Europe/Berlin Europe/Rome Europe/Amsterdam Europe/Brussels Europe/Lisbon Europe/Dublin Europe/Vienna Europe/Athens Europe/Helsinki Europe/Luxembourg Europe/Zagreb Europe/Tallinn Europe/Riga Europe/Vilnius Europe/Bratislava Europe/Ljubljana Europe/Malta Atlantic/Canary Atlantic/Azores Atlantic/Madeira Africa/Ceuta Europe/Monaco Europe/Vatican Europe/San_Marino Europe/Andorra Asia/Nicosia Europe/Podgorica Europe/Busingen');
  add('AUD', 'Australia/Brisbane Australia/Adelaide Australia/Darwin Australia/Hobart Australia/Canberra');
  add('RON', 'Europe/Bucharest'); add('HUF', 'Europe/Budapest'); add('BGN', 'Europe/Sofia'); add('RSD', 'Europe/Belgrade'); add('ISK', 'Atlantic/Reykjavik'); add('MKD', 'Europe/Skopje'); add('ALL', 'Europe/Tirane'); add('MDL', 'Europe/Chisinau'); add('BYN', 'Europe/Minsk');
  add('TWD', 'Asia/Taipei'); add('VND', 'Asia/Ho_Chi_Minh Asia/Saigon'); add('MYR', 'Asia/Kuala_Lumpur'); add('PKR', 'Asia/Karachi'); add('BDT', 'Asia/Dhaka'); add('SAR', 'Asia/Riyadh'); add('ILS', 'Asia/Jerusalem Asia/Tel_Aviv'); add('QAR', 'Asia/Qatar'); add('KWD', 'Asia/Kuwait'); add('LKR', 'Asia/Colombo'); add('NPR', 'Asia/Kathmandu'); add('KZT', 'Asia/Almaty'); add('GEL', 'Asia/Tbilisi'); add('AMD', 'Asia/Yerevan'); add('AZN', 'Asia/Baku'); add('IQD', 'Asia/Baghdad'); add('JOD', 'Asia/Amman'); add('LBP', 'Asia/Beirut'); add('KHR', 'Asia/Phnom_Penh'); add('MMK', 'Asia/Yangon'); add('UZS', 'Asia/Tashkent');
  add('MAD', 'Africa/Casablanca'); add('GHS', 'Africa/Accra'); add('TND', 'Africa/Tunis'); add('DZD', 'Africa/Algiers'); add('ETB', 'Africa/Addis_Ababa'); add('TZS', 'Africa/Dar_es_Salaam'); add('UGX', 'Africa/Kampala');
  add('JMD', 'America/Jamaica'); add('TTD', 'America/Port_of_Spain'); add('BSD', 'America/Nassau'); add('BBD', 'America/Barbados'); add('GYD', 'America/Guyana'); add('SRD', 'America/Paramaribo'); add('HTG', 'America/Port-au-Prince'); add('BZD', 'America/Belize');
  add('ARS', 'America/Buenos_Aires'); add('BRL', 'America/Manaus America/Fortaleza America/Recife America/Bahia America/Belem America/Cuiaba America/Campo_Grande'); add('MXN', 'America/Merida America/Chihuahua America/Hermosillo America/Mazatlan America/Matamoros America/Bahia_Banderas America/Ojinaga'); add('CLP', 'America/Punta_Arenas'); add('CAD', 'America/Whitehorse America/Yellowknife America/Iqaluit America/Moncton America/Goose_Bay America/Glace_Bay America/Thunder_Bay America/Nipigon America/Rainy_River America/Dawson America/Dawson_Creek America/Fort_Nelson America/Swift_Current America/Cambridge_Bay America/Inuvik America/Rankin_Inlet America/Resolute America/Atikokan America/Pangnirtung');
})();
function curByTZ() {
  let z = ''; try { z = Intl.DateTimeFormat().resolvedOptions().timeZone || ''; } catch (e) { /* sin Intl */ }
  if (TZ_CUR[z]) return TZ_CUR[z];
  if (/^America\/Argentina\//.test(z)) return 'ARS';
  return '';
}
const CUR_SECTIONS = [['Américas', ['CAD', 'PEN', 'MXN', 'ARS', 'BRL', 'CLP', 'COP', 'UYU', 'PYG', 'BOB', 'VES', 'CRC', 'GTQ', 'HNL', 'NIO', 'DOP', 'CUP']], ['Europa', ['GBP', 'BAM']], ['Asia', ['JPY']]];
const CUR_REG = {
  na: ['USD', 'CAD', 'MXN', 'GTQ', 'HNL', 'NIO', 'CRC', 'DOP', 'CUP', 'HTG', 'JMD', 'TTD', 'BSD', 'BBD', 'BMD', 'BZD', 'XCD', 'ANG', 'AWG'],
  sa: ['PEN', 'ARS', 'BRL', 'CLP', 'COP', 'UYU', 'PYG', 'BOB', 'VES', 'GYD', 'SRD'],
  eu: ['EUR', 'GBP', 'CHF', 'SEK', 'NOK', 'DKK', 'ISK', 'PLN', 'CZK', 'HUF', 'RON', 'BGN', 'HRK', 'RSD', 'MKD', 'ALL', 'BAM', 'MDL', 'UAH', 'BYN', 'RUB'],
  af: ['ZAR', 'EGP', 'MAD', 'NGN', 'KES', 'GHS', 'TND', 'DZD', 'ETB', 'TZS', 'UGX', 'RWF', 'AOA', 'BIF', 'BWP', 'CDF', 'CVE', 'DJF', 'GMD', 'GNF', 'MGA', 'MUR', 'MWK', 'MZN', 'NAD', 'SCR', 'SZL', 'XAF', 'XOF', 'ZMW'],
  me: ['TRY', 'AED', 'SAR', 'ILS', 'QAR', 'KWD', 'BHD', 'OMR', 'JOD', 'LBP', 'IQD', 'IRR', 'YER', 'AMD', 'AZN', 'GEL'],
  as: ['JPY', 'CNY', 'HKD', 'KRW', 'TWD', 'INR', 'PKR', 'BDT', 'LKR', 'NPR', 'BTN', 'MVR', 'THB', 'VND', 'IDR', 'MYR', 'SGD', 'PHP', 'KHR', 'LAK', 'MMK', 'BND', 'MOP', 'MNT', 'KZT', 'KGS', 'TJS', 'TMT', 'UZS', 'AFN'],
  oc: ['AUD', 'NZD', 'FJD', 'PGK', 'SBD', 'TOP', 'VUV', 'WST', 'XPF']
};
const REG_NAME = { na: 'Norteamérica y Caribe', sa: 'Sudamérica', eu: 'Europa', af: 'África', me: 'Medio Oriente', as: 'Asia', oc: 'Oceanía' };
const REG_COL = { na: '#1AA566', sa: '#66DFA6', eu: '#0E7A4D', af: '#3DD68C', me: '#A6E8C8', as: '#22B573', oc: '#138A55' };
function curMapHTML(w, sel, one, conv) {
  const tile = (c) => { const i = sel.indexOf(c), dis = i < 0 && !one; return '<button class="ccy' + (i >= 0 ? ' on' : '') + (dis ? ' dis' : '') + '" data-act="wcur:' + c + '"' + (dis ? ' disabled' : '') + '><b>' + c + '</b><span>' + symOf(c).trim() + '</span>' + (i >= 0 && !one ? '<i>' + (i + 1) + '</i>' : '') + '</button>'; };
  const reg = w.region || '', ks = Object.keys(WORLD_REG);
  const map = '<div class="wmapbox"><svg class="wmap" viewBox="0 0 960 500" role="img" aria-label="Mapamundi">' + ks.map((k) => '<path class="wrg' + (k === reg ? ' on' : '') + '" data-act="wreg:' + k + '" style="--c:' + REG_COL[k] + '" d="' + WORLD_REG[k] + '"><title>' + REG_NAME[k] + '</title></path>').join('') + '</svg></div>' +
    '';
  const rec = ['USD', 'EUR'], tz = curByTZ(); if (tz && rec.indexOf(tz) < 0 && CURRENCIES[tz]) rec.push(tz);
  const list = reg ? CUR_REG[reg].filter((c) => CURRENCIES[c]).slice(0, 10) : rec;
  return '<div class="wsplit"><div class="wlcol">' + (conv || '') + map + '</div><div class="wrcol">' +
    '<div class="ccyh">' + (reg ? REG_NAME[reg] : 'Recomendado') + '</div><div class="ccyg wreg">' + list.map(tile).join('') + '</div>' +
    '</div></div>';
}
function curGridHTML(w, sel, one) {
  const tile = (c) => { const i = sel.indexOf(c), dis = i < 0 && !one; return '<button class="ccy' + (i >= 0 ? ' on' : '') + (dis ? ' dis' : '') + '" data-act="wcur:' + c + '"' + (dis ? ' disabled' : '') + '><b>' + c + '</b><span>' + symOf(c).trim() + '</span>' + (i >= 0 && !one ? '<i>' + (i + 1) + '</i>' : '') + '</button>'; };
  const rec = ['USD', 'EUR'], tz = curByTZ(); if (tz && rec.indexOf(tz) < 0 && CURRENCIES[tz]) rec.push(tz);
  const sec = (t, list, extra) => '<div class="ccyh">' + t + '</div><div class="ccyg">' + list.map(tile).join('') + (extra || '') + '</div>';
  const others = sel.filter((c) => rec.indexOf(c) < 0 && CUR_GRID.indexOf(c) < 0 && c !== w.custom).concat(w.custom ? [w.custom] : []);
  const shown = rec.slice();
  return sec('Recomendado', rec) + CUR_SECTIONS.map((s) => { const l = s[1].filter((c) => shown.indexOf(c) < 0); shown.push.apply(shown, l); return l.length ? sec(s[0], l) : ''; }).join('') +
    sec('Otros', others, '<button class="ccy" data-act="wcust"><b>+</b><span>Otros</span></button>');
}
function wCustSet(w, raw) {
  const c = normCustom(raw), old = w.custom || '';
  if (c === old) return;
  const i = w.cur.indexOf(old);
  w.custom = c; regCustom(c);
  if (old && i >= 0) { if (c) w.cur[i] = c; else if (w.cur.length > 1) w.cur.splice(i, 1); }
  if (!old && c && w.cur.length < 2 && w.cur.indexOf(c) < 0) w.cur.push(c);
  if (w.accCur === old) w.accCur = w.cur[0];
  w.fx = 0;
}
function wJobModes(w) { const m = []; if (w.cur.indexOf('USD') >= 0) m.push(['h', 'EE.UU.']); if (w.cur.indexOf('PEN') >= 0) m.push(['s', 'Perú']); if (m.length > 1 && w.cur[0] === 'PEN') m.reverse(); return m.length ? m : [['h', 'EE.UU.'], ['s', 'Perú']]; }
function wJobMode(w) { const m = wJobModes(w); return m.some((x) => x[0] === w.jMode) ? w.jMode : m[0][0]; }
function wSync() {
  const w = ui.w; if (!w) return;
  const g = (id) => { const e = $('#' + id); return e ? e.value : null; };
  if (g('wCust') != null) wCustSet(w, g('wCust'));
  if (g('wFx') != null) w.fx = parseFloat(String(g('wFx')).replace(',', '.')) || w.fx;
  if (g('wIncDate') != null) w.incDate = g('wIncDate') || w.incDate;
  if (g('wJobDate') != null) w.jDate = g('wJobDate') || w.jDate;
  if (g('wFxDate') != null) w.fxDate = g('wFxDate') || w.fxDate;
  document.querySelectorAll('#welcome [data-w]').forEach((e) => {
    const k = e.getAttribute('data-w');
    if (k.indexOf('bud:') === 0) { (w.bud = w.bud || {})[k.slice(4)] = e.value; } else w[k] = e.value;
  });
}
/* Recorridos: el nivel decide cuántos pasos opcionales se muestran */
const W_STEPS = { simple: ['name', 'cur', 'acc', 'imp', 'look'], standard: ['name', 'ins', 'cur', 'acc', 'imp', 'inc', 'budget', 'look'], extended: ['name', 'ins', 'cur', 'acc', 'imp', 'inc', 'fixed', 'budget', 'subs', 'debt', 'goal', 'look'] };
function wStart(cloud) { const t = iso(getToday()); ui.w = { level: null, step: 0, first: '', last: '', nick: '', gender: 'n', cur: isWebView() ? [] : guessCur(), fx: 0, accName: 'Cuenta principal', accType: 'checking', accCur: '', bal: '', incName: 'Sueldo', incAmt: '', incRep: 'm', incQ1: '15', incQ2: '30', jQ1: '15', jQ2: '30', fxQ1: '1', fxQ2: '15', incDate: t, incKind: 'i', jMode: '', jName: 'Trabajo', jRate: '', jHours: '40', jTax: '15', jFreq: '', jDate: t, fxName: 'Renta', fxAmt: '', fxRep: 'm', fxDate: t, bud: {}, subName: '', subAmt: '', subDay: '1', dbKind: 'card', dbName: '', dbBal: '', dbLim: '', dbApr: '20', dbPay: '', dbDay: '1', gName: '', gGoal: '', gMon: '' }; if (cloud) ui.w.cloud = true; welcomeHTML('next'); }
async function wcloudGo() {
  if (!(clBeta() && clIn()) || hasData()) { wclOpen(); return; }
  /* Con sesión y sin datos aquí: si la nube ya tiene tu copia se carga; si está vacía, recorrido de inicio en la nube. Los avisos son diálogos (los toasts no se ven sobre la bienvenida) */
  const lb = document.querySelector('.wcloud .wct'), old = lb ? lb.textContent : '';
  if (lb) lb.textContent = 'Revisando tu nube…';
  const back = () => { if (lb) lb.textContent = old; };
  const say = (m) => { back(); askConfirm('Plata Cloud', m, [], '', 'Entendido'); };
  try {
    const g = await clFetch('/sync');
    if (g.s === 401) { back(); CL.ui = { step: 'email' }; clSheet(); return; }
    if (g.s === 200 && !(g.j.rev > 0)) { back(); wStart(true); return; }
    if (g.s === 200) {
      if (CL.st.mode !== 'cloud') { CL.st.mode = 'cloud'; CL.st.modeAt = 0; clSave(); } CL.busy = false; CL.hold = false;
      await clSync('first');
      if (hasData()) { hideWelcome(); setTab('resumen'); return; }
      /* Copia sincronizada pero sin datos (p. ej. quedó vacía de una prueba): cuenta como nube vacía y se empieza el recorrido */
      if (CL.status === 'error' || CL.status === 'offline' || CL.status === 'login') { say('Tu nube tiene una copia, pero no pudimos abrirla en este dispositivo (estado: ' + CL.status + '). Cierra sesión y vuelve a entrar con tu frase.'); return; }
      back(); wStart(true); return;
    }
    say('No pudimos revisar tu nube (código ' + g.s + '). Inténtalo más tarde.');
  } catch (e) { say('No pudimos conectar con Plata Cloud. Revisa tu internet e inténtalo de nuevo.'); }
}
function wCopyLink() { const u = 'https://plataapp.net', ok = () => toast('Enlace copiado'); try { navigator.clipboard.writeText(u).then(ok, () => toast(u)); } catch (e) { toast(u); } }
const W_OPT = ['name', 'imp', 'inc', 'fixed', 'budget', 'subs', 'debt', 'goal'];
const wSteps = (w) => { const b = (W_STEPS[w.level] || []).filter((x) => x !== 'imp' || nazcaOn()); return w.cloud && b.length ? b.concat('dev') : b; };
const wSid = (w) => wSteps(w)[w.step];
function wClear(w) {
  const sid = wSid(w);
  if (sid === 'name') { w.first = ''; w.last = ''; w.nick = ''; }
  else if (sid === 'imp') w.impAfter = '';
  else if (sid === 'inc') { w.incAmt = ''; w.jRate = ''; }
  else if (sid === 'fixed') w.fxAmt = '';
  else if (sid === 'budget') w.bud = {};
  else if (sid === 'subs') w.subAmt = '';
  else if (sid === 'debt') { w.dbName = ''; w.dbBal = ''; }
  else if (sid === 'goal') { w.gName = ''; w.gGoal = ''; }
}
const wnum = (v) => parseFloat(String(v == null ? '' : v).replace(',', '.')) || 0;
function lookPreviewHTML() {
  const w = ui.w; if (!w) return '';
  if (!w.lookDemo) w.lookDemo = ['brenda', 'shawn', 'andrea'][Math.floor(Math.random() * 3)];
  const d = DEMO_PROFILES[w.lookDemo]; if (!d) return '';
  const cur = d.settings.currency, sy = symOf(cur).trim(), mf = (n) => (n < 0 ? '−' : '') + sy + Math.abs(n).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const tot = d.accounts.filter((a) => a.cur === cur && (a.type === 'checking' || a.type === 'cash')).reduce((x, a) => x + a.balance, 0);
  const tx = d.transactions.filter((t) => t.date <= d.__anchor).slice(-3).reverse();
  return '<div class="wsub" style="margin:22px 0 8px">Vista previa</div><div class="lookprev"><div class="lp-h">Hola, ' + esc(d.settings.first) + '</div><div class="lp-card"><div class="lp-l">Disponible</div><div class="lp-big">' + mf(tot) + '</div></div>' +
    '<div class="lp-card" style="padding:4px 14px">' + tx.map((t) => '<div class="lp-r"><span class="grow">' + esc(t.note) + '<small>' + esc(t.category) + '</small></span><b style="color:' + (t.amount < 0 ? 'var(--ink)' : 'var(--gt)') + '">' + (t.amount > 0 ? '+' : '') + mf(t.amount) + '</b></div>').join('') + '</div></div>' +
    '<div class="lpnote"><span class="lpi" aria-hidden="true">i</span>Este perfil está disponible como demostración también.</div>';
}
function welcomeHTML(dir) {
  const w = ui.w, el = $('#welcome'); if (!el) return;
  const steps = w && w.level ? wSteps(w) : [];
  const dots = (n) => '<div class="wdots">' + steps.map((x, i) => '<i class="' + (i === n ? 'on' : '') + '"></i>').join('') + '</div>';
  const isWeb = document.documentElement.classList.contains('web');
  const back = isWeb ? '<button class="back" data-act="whome" aria-label="Cerrar">' + RMI('close-line', 24, 'currentColor') + '</button>' : '<button class="back" data-act="wback" aria-label="Regresar">' + IC_BACK + '</button>';
  if (w) { if (!w.cur || !w.cur.length) { const ci = wSteps(w).indexOf('cur'); if (!(isWebView() && ci >= 0 && w.step <= ci)) w.cur = ['USD']; } if (w.cur.indexOf(w.accCur) < 0) w.accCur = w.cur[0]; if (!(w.fx > 0) && w.cur[1]) w.fx = fxDefault(w.cur[0], w.cur[1]); }
  const sym = w ? symOf(w.accCur).trim() : '$';
  let top = '', body = '', foot = '';
  const fld = (label, id, val, extra) => '<label class="srow"><span class="grow"><span class="slabel">' + label + '</span><input class="sinput" data-w="' + id + '" ' + (extra || 'autocomplete="off"') + ' value="' + esc(val == null ? '' : val) + '"></span></label>';
  const numf = (label, id, val, ph) => fld(label, id, val, 'inputmode="decimal" placeholder="' + (ph || '0.00') + '" autocomplete="off"');
  const qf = (a, b) => fld('Día del primer pago', a[0], a[1], 'inputmode="numeric" placeholder="15" autocomplete="off"') + fld('Día del segundo pago', b[0], b[1], 'inputmode="numeric" placeholder="30" autocomplete="off"');
  if (ui.wpriv) {
    const wb = document.documentElement.classList.contains('web');
    const gear = '<button type="button" class="wgear" data-act="wgear" aria-label="Ajustes">' + RMI('settings-3-line', 20, wb ? '#0E7A4D' : '#3A3A3C') + '</button>';
    const blk = (col, ic, ttl, inner) => '<div style="display:flex;gap:14px;align-items:flex-start;margin-top:22px">' + tile(col, RMI(ic, 24, '#fff')) + '<div style="min-width:0"><div style="font-size:17px;font-weight:600;letter-spacing:-.02em;color:var(--ink)">' + ttl + '</div><div style="font-size:15px;line-height:1.4;color:var(--mute);margin-top:4px">' + inner + '</div></div></div>';
    top = '<div class="wtop"></div>';
    body = '<div class="wmain wpriv"' + (wb ? '' : ' style="justify-content:flex-start;padding-top:48px;margin:0 14px"') + '><div style="margin-bottom:20px">' + LOCKSQ(64, wb ? '#22B573' : '#3A3A3C') + '</div><h1>Tus datos son tuyos.</h1>' +
      (ui.w && ui.w.cloud
        ? blk('#22B573', 'cloud-line', 'Tus datos se cifran antes de salir de tu teléfono.', 'Estudio 22 y Plata no podemos leerlos: en Plata Cloud solo guardamos texto cifrado.') +
          blk(wb ? '#0E7A4D' : '#8E8E93', 'shield-check-line', 'Guarda tu frase de recuperación', 'Es la única forma de abrir tus datos en otro dispositivo. Si la pierdes, nadie puede recuperarla, ni nosotros. La ves en el menú de tres puntos de tu perfil.') +
          blk(wb ? '#16915B' : '#6E6E73', 'arrow-left-right-line', 'Se sincroniza entre tus dispositivos', 'Entra con tu correo en otro dispositivo y tus datos aparecen solos. Si te quedas sin internet, Plata sigue funcionando y sincroniza al volver.')
        : blk('#22B573', 'smartphone-line', 'Tus datos se almacenan localmente en tu teléfono.', 'Estudio 22 y Plata no recopilan tus datos financieros.') +
          blk(wb ? '#0E7A4D' : '#8E8E93', 'settings-3-line', 'Respalda tus datos', 'Aunque por el momento cerrar y abrir la app mantiene tus datos, haz siempre una copia con el engranaje ' + gear + ' de la esquina derecha para mantenerla al día y segura.') +
          blk(wb ? '#16915B' : '#6E6E73', 'arrow-left-right-line', 'Solo se sincroniza con Plata Cloud', 'Para usar Plata en otro dispositivo, guarda tu archivo y cárgalo allí, o prueba Plata Cloud (opcional, por invitación).')) +
      (ui.wprivDemo ? '<div class="wnote" style="margin:22px 0 0;text-align:left">Los perfiles de demostración fueron creados usando estadísticas y no representan uso real de ningún usuario.</div>' : '') + '</div>';
    foot = '<div class="wnote wprivfoot" style="margin:0 14px 12px">' + (ui.w && ui.w.cloud ? 'Plata Cloud está en Beta, por invitación. Puedes volver al modo Local cuando quieras desde tu perfil.' : 'Plata está en una versión Beta. Plata Cloud, la sincronización opcional, es por invitación.') + '</div><button class="primary" data-act="wpriv">Aceptar</button>';
  } else if (!w) {
    top = '<div class="wtop"></div>';
    const oc = (c, n, t, d, a) => '<button data-act="' + a + '">' + tile(c, RMI(n, 22, '#fff')) + '<span><b>' + t + '</b><span class="s">' + d + '</span></span></button>';
    body = '<div class="wland"><div class="wmain"><div class="wbrand" data-act="wlogo"><div class="plogo" role="img" aria-label="Plata"></div></div><div class="wtag">Finanzas simples. Tu plata a tu modo.</div></div>' +
      '<div class="wnote" style="font-size:13px;font-weight:500;margin:0 0 12px">' + APP_VERSION + ' · ' + APP_BUILD + '</div><div class="wright"><div class="wrow"><button class="primary" data-act="wstart" style="flex:1">Empezar</button><button class="wdotbtn" data-act="wmenu" aria-label="Más opciones">' + RMI('more-fill', 24, '#1C1C1E') + '</button></div>' +
      '<button class="wcloud cloudw" data-act="wcloud">' + PC_CLOUDS + '<span class="wct">Empezar en la nube</span></button>' + (clIn() ? '<button class="wghost" data-act="cl:out">Cerrar sesión de Plata Cloud</button>' : '') +
      '<div class="wopts">' + oc('#22B573', 'flashlight-line', 'Inicio rápido', 'Adelanta el recorrido inicial.', 'wquick') + oc('#B98AE6', 'bar-chart-line', 'Datos de demostración', 'Revisa un ejemplo de alguien usando Plata.', 'wdemo') + '</div></div></div></div>' + WSOC;
  } else if (w.demo) {
    top = '<div class="wtop">' + back + '<span></span><span style="width:44px"></span></div>';
    body = '<div class="wmain wdm" style="justify-content:flex-start;padding-top:18px"><h1>Perfiles de demostración</h1><div class="wsub">Elige uno para ver Plata con datos de ejemplo.</div><div class="wdemogrid">' + demoCards('wdemopick') + '</div><div class="wdemofoot">Estos perfiles se crearon con estadísticas de ejemplo. Los datos no son reales.</div></div>';
  } else if (!w.level) {
    top = '<div class="wtop">' + back + '<span></span>' + (w.cloud ? '<span class="cpill wcpill">' + RMI('cloud-line', 14, 'currentColor') + 'Plata Cloud</span>' : '<span style="width:44px"></span>') + '</div>';
    const lv = (k, t, d, m, rec, ic, col) => '<button class="wopt wlvl" data-act="wlevel:' + k + '">' + tile(col, RMI(ic, 24, '#fff')) + '<span style="flex:1"><b>' + t + (rec ? '<i>Recomendado</i>' : '') + '</b><span class="s">' + d + '</span></span><em>' + m + '</em></button>';
    body = '<div class="wmain" style="justify-content:flex-start;padding-top:18px"><h1>¿Cómo quieres empezar?</h1><div class="wsub">Elige cuánto quieres configurar ahora. Lo demás puedes añadirlo después.</div>' +
      lv('simple', 'Simple', 'Lo esencial: tu nombre, moneda y una cuenta. Registra ingresos y gastos y listo.', '1 min', false, 'seedling-line', '#22B573') +
      lv('standard', 'Estándar', 'Además: Insights y half‑time, tus ingresos y límites de presupuesto.', '3 min', true, 'layout-grid-line', '#22B573') +
      lv('extended', 'Extendido', 'Todo desde el inicio: gastos fijos, suscripciones, deudas y una meta de ahorro.', '6 min', false, 'rocket-2-line', '#B98AE6') + '</div>';
  } else {
    const sid = wSid(w), last = w.step === steps.length - 1, opt = W_OPT.indexOf(sid) >= 0, cont = false, web = document.documentElement.classList.contains('web');
    top = '<div class="wtop">' + back + (web ? '<span></span>' : dots(w.step)) + (w.cloud ? '<span class="cpill wcpill">' + RMI('cloud-line', 14, 'currentColor') + 'Plata Cloud</span>' : '<span style="width:44px"></span>') + '</div>';
    const stepHTML = (sid) => { let body = '', note = '';
    if (sid === 'look') {
      body = '<h1>¿Cómo lo prefieres?</h1><div class="wsub">Elige la apariencia de Plata. Auto sigue la del sistema. Puedes cambiarla después en tu perfil.</div><div style="margin-top:18px">' +
        segHTML('wtheme', [{ k: 'auto', label: 'Auto', act: 'theme:auto' }, { k: 'light', label: 'Claro', act: 'theme:light' }, { k: 'dark', label: 'Oscuro', act: 'theme:dark' }], window.__themePref()) + '</div>' + lookPreviewHTML();
    } else if (sid === 'name') {
      body = '<h1>¿Cómo te llamas?</h1><div class="wsub">Opcional. Plata lo usará para saludarte; pero luego puedes cambiarlo en tu perfil.</div>' +
        '<div id="wphoto">' + wPhotoHTML() + '</div>' +
        '<div class="scard wcompact"><div style="display:flex">' + fld('Nombre', 'first', w.first, 'autocomplete="given-name"') + fld('Apellido', 'last', w.last, 'autocomplete="family-name"') + '</div>' + fld('Apodo', 'nick', w.nick, 'autocomplete="off" placeholder="Cómo quieres que te llamemos"') + '</div>' +
        '<div class="wsub" style="margin:12px 0 8px">Género (para dirigirnos a ti correctamente)</div>' +
        segHTML('wgen', [{ k: 'm', label: 'Masculino', act: 'wset:gender:m' }, { k: 'f', label: 'Femenino', act: 'wset:gender:f' }, { k: 'n', label: 'Neutro', act: 'wset:gender:n' }], w.gender) +
        '<div class="wnote" style="font-style:italic;text-align:left;margin:8px 4px 0;font-size:13px">' + esc(genderExample(w.gender, w.nick || w.first)) + '</div>';
    } else if (sid === 'ins') {
      const iOn = w.ins !== false, sOn = iOn && w.score !== false;
      body = '<h1>Insights y half‑time</h1><div class="wsub">Cada mes comparamos tus movimientos con los del anterior y te damos una evaluación de la F a la S, junto con consejos sobre tu presupuesto, tus metas de ahorro y tus deudas. Puedes cambiarlo después en Ajustes.</div>' +
        wGradesHTML() + '<div class="scard"><div class="row"><span class="grow" style="font-size:17px">Activar Insights y half‑time</span>' + swHTML(iOn, 'wtog:ins') + '</div>' +
        '<div class="row"><span class="grow" style="font-size:17px">Mostrar puntuación</span>' + swHTML(sOn, 'wtog:score', !iOn) + '</div></div>';
      note = '<div class="wnote">Esta información no es recopilada por Plata ni Estudio 22. Toda la información se maneja en tu archivo de perfil.</div>';
    } else if (sid === 'cur') {
      const sel = w.cur, one = sel.length < 2;
      const conv = '<div class="wconv">' + (sel.indexOf('PEN') >= 0 ? '<div class="wnote wegg">¡Que viva el Perú ca****!</div>' : '') +
        '<div class="sub" style="padding:2px 4px 10px">' + (!sel.length ? 'Elige tu moneda principal.' : one ? 'Principal: ' + CURRENCIES[sel[0]].name + '.' : 'Principal: ' + sel[0] + ' · Segunda: ' + sel[1]) + '</div>' +
        (one ? '' : '<div class="wfxrow"><div class="scard"><label class="srow"><span class="grow"><span class="slabel">1 ' + sel[0] + ' en ' + sel[1] + '</span><input class="sinput" id="wFx" inputmode="decimal" value="' + w.fx + '"></span></label></div>' +
          '<button class="wswapb" data-act="wswap">' + RMI('arrow-left-right-line', 26, 'currentColor') + '<span>Usar ' + sel[1] + ' como principal</span></button></div>') + '</div>';
      body = '<div class="wtrow"><h1>¿Qué moneda usas?</h1>' + (web ? '<div class="wpills">' + sel.map((c, i) => '<button class="wpill' + (sel.length > 1 ? ' rm' : '') + '" data-act="wcur:' + c + '"' + (sel.length > 1 ? ' title="Quitar ' + c + '"' : ' tabindex="-1"') + '><b><i>' + (i + 1) + '</i><u>✕</u></b>' + c + '</button>').join('') + (sel.length > 1 && w.rmHint && Date.now() - w.rmHint < 4500 ? '<span class="wrmhint" style="animation-delay:-' + ((Date.now() - w.rmHint) / 1000).toFixed(2) + 's">→ Haz clic en una moneda para borrar la elección.</span>' : '') + '</div>' : '') + '</div><div class="wsub">Elige hasta 2 monedas. Puedes cambiarlo después en Ajustes.</div>' +
        (web ? curMapHTML(w, sel, one, conv) : curGridHTML(w, sel, one)) +
        (w.customOpen || w.custom ? '<div class="scard"><label class="srow"><span class="grow"><span class="slabel">Otras monedas del mundo</span><select class="mini" id="wOther" style="width:100%;text-align:left;padding:0 8px"><option value="">Elige una moneda…</option>' + CUR_OTHERS().filter((c) => !CURRENCIES[c].custom).map((c) => '<option value="' + c + '">' + c + ' · ' + CURRENCIES[c].name + '</option>').join('') + '</select></span></label>' +
          '<label class="srow"><span class="grow"><span class="slabel">¿No está? Escribe tu propio código (hasta 3 caracteres)</span><input class="sinput" id="wCust" maxlength="3" autocapitalize="characters" autocomplete="off" style="text-transform:uppercase" value="' + esc(w.custom || '') + '"></span></label></div>' : '') +
        (web ? '' : '<div class="sub" style="padding:2px 4px 12px">' + (one ? 'Principal: ' + CURRENCIES[sel[0]].name + '.' : 'Principal: ' + sel[0] + ' · Segunda: ' + sel[1]) + '</div>' +
        (one ? '' : '<div class="scard"><label class="srow"><span class="grow"><span class="slabel">1 ' + sel[0] + ' en ' + sel[1] + '</span><input class="sinput" id="wFx" inputmode="decimal" value="' + w.fx + '"></span></label></div><button class="wghost" data-act="wswap" style="height:46px;font-size:16px;margin-top:0">Usar ' + sel[1] + ' como principal</button>'));
      note = (!web && sel.indexOf('PEN') >= 0 ? '<div class="wnote" style="font-style:italic;color:#AEAEB2;font-size:13px">¡Que viva el Perú ca****!</div>' : '');
    } else if (sid === 'acc') {
      body = '<h1>Tu primera cuenta</h1><div class="wsub">Donde guardas o recibes tu dinero. Podrás añadir más.</div>' +
        segHTML('wtype', [{ k: 'checking', label: 'Corriente', act: 'wset:accType:checking' }, { k: 'savings', label: 'Ahorros', act: 'wset:accType:savings' }, { k: 'cash', label: 'Efectivo', act: 'wset:accType:cash' }], w.accType) +
        (w.cur.length > 1 ? segHTML('wcur', w.cur.map((c) => ({ k: c, label: c + ' (' + symOf(c).trim() + ')', act: 'wset:accCur:' + c })), w.accCur) : '') +
        '<div class="scard">' + fld('Nombre', 'accName', w.accName) + numf('Saldo actual (' + sym + ')', 'bal', w.bal) + '</div>';
    } else if (sid === 'imp') {
      const on = w.impAfter === '1', banks = NazcaBancos.CATALOG.map((c) => c.banks.filter((b) => b.active).map((b) => b.name)).reduce((x, y) => x.concat(y), []);
      const opt = (k, t, d, ic, sel) => '<button class="wopt' + (sel ? ' on' : '') + '" data-act="wset:impAfter:' + k + '" style="margin-top:10px">' + tile('#22B573', RMI(ic, 24, '#fff')) + '<span style="flex:1"><b>' + t + '</b><span class="s">' + d + '</span></span>' + (sel ? RMI('checkbox-circle-fill', 24, '#22B573') : '') + '</button>';
      body = '<h1>¿Traes tus movimientos?</h1><div class="wsub">Opcional. Sube el estado de cuenta de tu banco (PDF o CSV) y Nazca llena tu historial. Lo lee tu dispositivo: no se sube a ningún servidor, salvo que tú decidas mandarlo.</div>' +
        opt('1', 'Importar al terminar', 'Al acabar el recorrido te abrimos el importador. Puedes unirlo a la cuenta que acabas de crear.', 'upload-2-line', on) +
        opt('0', 'Lo haré después', 'Siempre lo encuentras en Movimientos y en Ajustes.', 'time-line', !on) +
        '<div class="wnote" style="text-align:left;margin:14px 4px 0;font-size:13px"><span>Nazca reconoce estados de</span> <span data-notr>' + esc(banks.join(', ')) + '</span><span>, y lee otros bancos por su contenido.</span></div>';
    } else if (sid === 'inc' && w.incKind === 'j') {
      const jm = wJobModes(w), md = wJobMode(w), fq = w.jFreq || (md === 's' ? 'm' : 'b');
      body = '<h1>¿Cuánto ganas?</h1><div class="wsub">Opcional. Plata calcula tu pago neto y lo prevé en tus ingresos.</div>' +
        segHTML('wik', [{ k: 'i', label: 'Ingreso', act: 'wset:incKind:i' }, { k: 'j', label: 'Trabajo', act: 'wset:incKind:j' }], 'j') +
        (jm.length > 1 ? segHTML('wjm', jm.map((x) => ({ k: x[0], label: x[1], act: 'wset:jMode:' + x[0] })), md) : '') +
        segHTML('wjf', [{ k: 'w', label: 'Semanal', act: 'wset:jFreq:w' }, { k: 'b', label: '14 días', act: 'wset:jFreq:b' }, { k: 'q', label: 'Quincenal', act: 'wset:jFreq:q' }, { k: 'm', label: 'Mensual', act: 'wset:jFreq:m' }], fq) +
        '<div class="scard">' + fld('Nombre del trabajo', 'jName', w.jName) + numf((md === 's' ? 'Ingreso mensual estimado (' : 'Pago por hora (') + sym + ')', 'jRate', w.jRate) +
        (md === 's' ? '' : numf('Horas por semana', 'jHours', w.jHours, '40') + numf('Impuestos retenidos (%)', 'jTax', w.jTax, '15')) +
        (fq === 'q' ? qf(['jQ1', w.jQ1], ['jQ2', w.jQ2]) : '<label class="srow"><span class="grow"><span class="slabel">Primer pago</span><input class="sinput" id="wJobDate" type="date" value="' + esc(w.jDate) + '"></span></label>') + '</div>';
    } else if (sid === 'inc') {
      body = '<h1>¿Cuánto ganas?</h1><div class="wsub">Opcional. Así Plata prevé tus próximos ingresos.</div>' +
        segHTML('wik', [{ k: 'i', label: 'Ingreso', act: 'wset:incKind:i' }, { k: 'j', label: 'Trabajo', act: 'wset:incKind:j' }], 'i') +
        segHTML('wrep', [{ k: 'm', label: 'Mensual', act: 'wset:incRep:m' }, { k: 'q', label: 'Quincenal', act: 'wset:incRep:q' }, { k: '14', label: '14 días', act: 'wset:incRep:14' }, { k: '7', label: 'Semanal', act: 'wset:incRep:7' }], w.incRep) +
        '<div class="scard">' + fld('Nombre', 'incName', w.incName) + numf('Monto (' + sym + ')', 'incAmt', w.incAmt) +
        (w.incRep === 'q' ? qf(['incQ1', w.incQ1], ['incQ2', w.incQ2]) : '<label class="srow"><span class="grow"><span class="slabel">Próxima fecha</span><input class="sinput" id="wIncDate" type="date" value="' + esc(w.incDate) + '"></span></label>') + '</div>';
    } else if (sid === 'fixed') {
      body = '<h1>¿Tienes gastos fijos?</h1><div class="wsub">Renta, servicios… Opcional. Plata los suma a tu proyección; podrás añadir más.</div>' +
        segHTML('wfrep', [{ k: 'm', label: 'Mensual', act: 'wset:fxRep:m' }, { k: 'q', label: 'Quincenal', act: 'wset:fxRep:q' }, { k: '14', label: '14 días', act: 'wset:fxRep:14' }, { k: '7', label: 'Semanal', act: 'wset:fxRep:7' }], w.fxRep) +
        '<div class="scard">' + fld('Nombre', 'fxName', w.fxName) + numf('Monto (' + sym + ')', 'fxAmt', w.fxAmt) +
        (w.fxRep === 'q' ? qf(['fxQ1', w.fxQ1], ['fxQ2', w.fxQ2]) : '<label class="srow"><span class="grow"><span class="slabel">Próximo pago</span><input class="sinput" id="wFxDate" type="date" value="' + esc(w.fxDate) + '"></span></label>') + '</div>';
    } else if (sid === 'budget') {
      body = '<h1>Tu presupuesto</h1><div class="wsub">Cuánto quieres gastar al mes en cada categoría. Opcional; puedes dejarlo en blanco y definirlo después.</div>' +
        '<div class="scard">' + DEF_CATS.filter((c) => c.name !== 'Otros').map((c) => numf(c.name + ' (' + sym + ')', 'bud:' + c.name, (w.bud || {})[c.name], '0')).join('') + '</div>';
    } else if (sid === 'subs') {
      body = '<h1>Servicios y suscripciones</h1><div class="wsub">Netflix, Spotify, gimnasio… Opcional. Añade una ahora y las demás después.</div>' +
        '<div class="scard">' + fld('Nombre', 'subName', w.subName) + numf('Monto por mes (' + sym + ')', 'subAmt', w.subAmt) + fld('Día de cobro', 'subDay', w.subDay, 'inputmode="numeric" autocomplete="off"') + '</div>';
    } else if (sid === 'debt') {
      body = '<h1>Tarjetas y préstamos</h1><div class="wsub">Opcional. Añade una; Plata calcula intereses y cuándo quedarías libre de deuda.</div>' +
        segHTML('wdbk', [{ k: 'card', label: 'Tarjeta', act: 'wset:dbKind:card' }, { k: 'loan', label: 'Préstamo', act: 'wset:dbKind:loan' }], w.dbKind) +
        '<div class="scard">' + fld('Nombre', 'dbName', w.dbName) + numf('Saldo adeudado (' + sym + ')', 'dbBal', w.dbBal) + (w.dbKind === 'card' ? numf('Límite de la tarjeta (' + sym + ')', 'dbLim', w.dbLim) : '') +
        numf('Interés anual (%)', 'dbApr', w.dbApr, '20') + numf('Pago mensual (' + sym + ')', 'dbPay', w.dbPay) + fld('Día de pago', 'dbDay', w.dbDay, 'inputmode="numeric" autocomplete="off"') + '</div>';
    } else if (sid === 'dev') {
      const em = esc((CL.st && CL.st.email) || ''), url = 'plataapp.net';
      const qr = '<div class="wqr"><svg xmlns="http://www.w3.org/2000/svg" width="132" height="132" viewBox="0 0 ' + BQR.n + ' ' + BQR.n + '" shape-rendering="crispEdges" aria-hidden="true"><path fill="#0B1F17" d="' + BQR.d + '"/></svg></div>';
      body = '<h1>Tu Plata ya viaja contigo</h1><div class="wsub"><span>' + (web ? 'Abre Plata en tu celular e inicia sesión con tu correo' : 'Abre Plata en tu computadora e inicia sesión con tu correo') + '</span>' + (em ? ': <b data-notr>' + em + '</b>' : '') + '<span>. Tus datos aparecen solos, cifrados.</span></div>' +
        '<div class="scard wdev">' + (web ? qr : '') + '<div class="wdevu">' + url + '</div>' + (web ? '<div class="wdevs">Escanea el código con la cámara de tu celular.</div>' : '<button class="clb alt wdevb" data-act="wcopy">Copiar enlace</button>') + '</div>' +
        '<div class="wnote" style="text-align:left;margin:14px 4px 0;font-size:13px">Primer mes gratis, sin cobros todavía: te avisaremos antes de cobrar. Aplican términos y condiciones (están en plataapp.net, sección Aviso legal). Tu frase de recuperación está en el menú de tres puntos de tu perfil.</div>';
    } else if (sid === 'goal') {
      body = '<h1>Una meta de ahorro</h1><div class="wsub">Opcional. Por ejemplo, un fondo de emergencias o un viaje.</div>' +
        '<div class="scard">' + fld('Nombre', 'gName', w.gName) + numf('Meta (' + sym + ')', 'gGoal', w.gGoal) + numf('Aporte mensual (' + sym + ')', 'gMon', w.gMon) + '</div>';
    }
    return { body: body, note: note }; };
    let body0, note;
    if (cont) { body0 = steps.map((x) => { const r = stepHTML(x); return '<section class="wsec">' + r.body + r.note + '</section>'; }).join(''); note = ''; }
    else { const r = stepHTML(sid); body0 = r.body; note = r.note; }
    body = '<div class="wmain" style="justify-content:flex-start;padding-top:18px">' + body0 + '</div>';
    foot = cont ? '<div class="wnote" style="margin:12px 0">Todo es opcional: lo que dejes en blanco se puede añadir después.</div><button class="primary" data-act="wfin">Terminar</button>' : note + '<button class="primary" data-act="' + (last ? 'wfin' : 'wnext') + '">' + (last ? 'Terminar' : 'Continuar') + '</button>' + (opt ? '<button class="wghost" data-act="' + (last ? 'wfin:skip' : 'wnext:skip') + '">Omitir</button>' : '');
    if (web) foot = '<div class="wdownrow"><div class="wside r">' + (w.step === 0 ? '<span class="whint">Usa la rueda del ratón para seguir' + RMI('arrow-down-line', 22, 'currentColor') + '</span>' : '') + dots(w.step) + '<button class="wdown' + (wLocked() ? ' lock' : '') + '" data-act="' + (last ? 'wfin' : 'wnext') + '" aria-label="' + (last ? 'Terminar' : 'Siguiente') + '">' + RMI(last ? 'check-line' : 'arrow-down-line', 28, '#073D24') + '</button></div>' + (w.step >= 1 ? '<div class="wside l"><button class="wdown wup" data-act="wback" aria-label="Anterior">' + RMI('arrow-up-line', 28, '#22B573') + '</button>' + (w.step === 1 ? '<span class="whint up">¡Ups! ¿Te faltó algo? Usa la rueda del ratón para regresar.</span>' : '') + '</div>' : '') + (opt ? '<button class="wskip" data-act="' + (last ? 'wfin:skip' : 'wnext:skip') + '">Omitir</button>' : '') + '</div>';
  }
  const old = el.querySelector('.wpage'), stage = el.querySelector('.wstage'), scM = old && old.querySelector('.wmain'), scT = !dir && scM ? scM.scrollTop : 0;
  const pg = document.createElement('div'); pg.className = 'wpage'; pg.innerHTML = body + foot;
  if (dir && old && stage) {
    const gone = old.cloneNode(true); gone.className = 'wpage ' + (dir === 'back' ? 'outr' : 'outl'); gone.removeAttribute('id');
    const tp = el.querySelector('.wtop'); if (tp) tp.outerHTML = top; else el.insertAdjacentHTML('afterbegin', top);
    stage.innerHTML = ''; stage.appendChild(gone); pg.className = 'wpage ' + (dir === 'back' ? 'inl' : 'inr'); stage.appendChild(pg);
    setTimeout(() => { if (gone.parentNode) gone.remove(); pg.classList.remove('inr', 'inl'); }, 440);
  } else { el.innerHTML = top + '<div class="wstage"></div>'; el.querySelector('.wstage').appendChild(pg); const m2 = pg.querySelector('.wmain'); if (m2 && scT) m2.scrollTop = scT; }
  if (document.documentElement.classList.contains('web')) { requestAnimationFrame(wFit); setTimeout(wFit, 480); }
}
const wLocked = () => !!(ui.w && ui.w.level && isWebView() && wSid(ui.w) === 'cur' && !(ui.w.cur && ui.w.cur.length));
function wBlock() {
  const now = Date.now(); if (now - (ui.wBlk || 0) < 900) return; ui.wBlk = now;
  const sd = document.querySelector('.welcome .wside.r');
  if (sd) { const o = sd.querySelector('.wlockmsg'); if (o) o.remove(); const h = document.createElement('span'); h.className = 'wlockmsg'; h.textContent = 'Elige una moneda para continuar.'; sd.appendChild(h); setTimeout(() => { h.style.opacity = '0'; setTimeout(() => h.remove(), 400); }, 2800); }
  const m = document.querySelector('.welcome .wpage:not(.outl):not(.outr)') || document.querySelector('.welcome');
  if (m) { m.classList.remove('wshake'); void m.offsetWidth; m.classList.add('wshake'); setTimeout(() => m.classList.remove('wshake'), 500); }
}
function wStepDir(dn, force) {
  if (!ui.w || !ui.w.level) return false;
  if (dn && wLocked()) { wBlock(); return true; }
  const now = Date.now(); if (now - (ui.wWheel || 0) < 850) return true;
  const m = document.querySelector('.welcome .wpage:not(.outl):not(.outr) .wmain');
  if (m && !m.classList.contains('noscroll')) { const atEnd = m.scrollTop + m.clientHeight >= m.scrollHeight - 3, atTop = m.scrollTop <= 2; if (dn ? !atEnd : !atTop) return false; }
  ui.wWheel = now; wSync();
  if (dn) { if (ui.w.step < wSteps(ui.w).length - 1) { ui.w.step++; welcomeHTML('next'); } }
  else if (ui.w.step > 0) { ui.w.step--; welcomeHTML('back'); } else { ui.w.level = null; welcomeHTML('back'); }
  return true;
}
function wFit() {
  document.querySelectorAll('.welcome .wmain').forEach((m) => { if (m.querySelector('.wbrand')) return; const over = m.scrollHeight - m.clientHeight; m.classList.toggle('noscroll', over <= 110); });
}
document.addEventListener('wheel', (e) => {
  if (!document.documentElement.classList.contains('web') || !ui.w || !ui.w.level || !e.target.closest || !e.target.closest('.welcome')) return;
  if (Math.abs(e.deltaY) < 12) return; wStepDir(e.deltaY > 0);
}, { passive: true });
document.addEventListener('keydown', (e) => {
  if (!document.documentElement.classList.contains('web') || !ui.w || !ui.w.level || !$('#welcome')) return;
  const t = e.target, tag = t && t.tagName; if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' || (t && t.isContentEditable)) return;
  if (e.key === 'ArrowDown' || e.key === 'PageDown') { if (wStepDir(true)) e.preventDefault(); }
  else if (e.key === 'ArrowUp' || e.key === 'PageUp') { if (wStepDir(false)) e.preventDefault(); }
});
function showWelcome() {
  if ($('#welcome')) return;
  const el = document.createElement('div'); el.id = 'welcome'; el.className = 'welcome'; deviceEl.appendChild(el); ui.w = null; welcomeHTML();
}
function wGearHint() {
  const w = $('#welcome'), src = $('#gearbtn'); if (!w || !src) return;
  const old = $('#wgearhint'); if (old) old.remove();
  const h = src.cloneNode(true); h.id = 'wgearhint'; h.removeAttribute('data-act'); h.className = 'gearbtn gearhint'; h.setAttribute('aria-hidden', 'true'); h.removeAttribute('aria-label');
  w.appendChild(h); setTimeout(() => { h.style.transition = 'opacity .3s'; h.style.opacity = '0'; setTimeout(() => h.remove(), 320); }, 3800);
}
function wPriv(fn, demo) { ui.wpriv = true; ui.wprivDemo = !!demo; ui.wfn = fn; welcomeHTML('next'); }
let wLogoTaps = [];
let wSel = 'B';
function wStreakInner() {
  const t = wSel === 'S' || wSel === 'A' ? 'Misma letra 2 meses seguidos y sube a letra+ dorada.' : wSel === 'B' || wSel === 'C' ? 'Misma letra 2 meses seguidos y sube a letra+ platino.' : 'Misma letra 2 meses seguidos y baja a letra- más roja.';
  return '<div style="flex:none">' + scoreTile(wSel, 38, true) + '</div><div class="sub" style="font-size:14px;line-height:1.35;color:var(--ink2)">' + t + '</div>';
}
function wGradesHTML() {
  const L = [['S', 'Perfecto'], ['A', 'Muy bueno'], ['B', 'Bueno'], ['C', 'Mediocre'], ['D', 'Deficiente'], ['F', 'Muy malo']];
  return '<div class="scard" style="padding:14px 12px"><div style="display:flex;justify-content:space-between;gap:2px">' +
    L.map((x) => '<div style="display:flex;flex-direction:column;align-items:center;gap:6px;flex:1;min-width:0">' + '<button data-act="wgsel:' + x[0] + '" aria-label="' + x[0] + '" style="padding:0;display:flex;transition:transform .2s,opacity .2s;' + (x[0] === wSel ? '' : 'opacity:.55;') + '">' + scoreTile(x[0], 38) + '</button><span style="font-size:11px;color:var(--mute);font-weight:500;white-space:nowrap">' + x[1] + '</span></div>').join('') + '</div>' +
    '<div id="wstreak" style="display:flex;align-items:center;gap:12px;margin-top:14px;padding-top:12px;border-top:1px solid var(--line)">' + wStreakInner() + '</div>' +
    '<div style="display:flex;align-items:center;gap:12px;margin-top:12px;padding-top:12px;border-top:1px solid var(--line)"><div style="flex:none">' + ghostScore('B', 38) + '</div>' +
    '<div class="sub" style="font-size:14px;line-height:1.35;color:var(--ink2)">Half‑time: el día 15 ves cómo va tu nota. Al cerrar el mes recibes la final.</div></div></div>';
}
function wLogoTap() {
  const t = Date.now(); wLogoTaps = wLogoTaps.filter((x) => t - x < 900); wLogoTaps.push(t);
  if (wLogoTaps.length >= 3) { wLogoTaps = []; wDebug(); }
}
function wDebug() {
  const w = $('#welcome'); if (!w || $('#wdbg')) return; wCloseMenu();
  const cur = langPref();
  const bk = document.createElement('div'); bk.id = 'wdbg'; bk.setAttribute('data-act', 'wdbgclose');
  bk.style.cssText = 'position:absolute;inset:0;z-index:180;background:rgba(0,0,0,.28);display:flex;align-items:center;justify-content:center;padding:24px;opacity:0;transition:opacity .2s';
  const card = document.createElement('div'); card.setAttribute('data-act', 'wdbgstay');
  card.style.cssText = 'width:100%;max-width:340px;background:var(--card);border-radius:28px;padding:20px 8px 10px;box-shadow:0 20px 60px rgba(0,0,0,.25)';
  card.innerHTML = '<div style="padding:0 16px 4px;font-size:20px;font-weight:700;letter-spacing:-.4px">Debug</div><div style="padding:0 16px 8px;font-size:14px;color:var(--mute)">Apariencia</div>' +
    '<div style="padding:0 16px 12px;display:flex;gap:6px">' + [['auto', 'Auto'], ['light', 'Claro'], ['dark', 'Oscuro']].map((t) => '<button data-act="wdbgtheme:' + t[0] + '" style="flex:1;height:38px;border-radius:999px;font-size:15px;font-weight:600;' + (window.__themePref() === t[0] ? 'background:#22B573;color:#fff' : 'background:var(--fill, rgba(120,120,128,.16));color:var(--ink)') + '">' + t[1] + '</button>').join('') + '</div><div style="padding:0 16px 10px;font-size:14px;color:var(--mute)">Idioma de la pantalla de inicio</div>' + LANG_LIST.map((x) => '<button class="pmi" data-act="wdbg:' + x[0] + '" style="width:100%;display:flex;align-items:center;justify-content:space-between;padding:14px 16px;font-size:17px;border-radius:16px;text-align:left"><span>' + x[1] + '</span>' + (cur === x[0] ? RMI('check-line', 22, '#22B573') : '') + '</button>').join('') + wDebugGradesHTML();
  bk.appendChild(card); w.appendChild(bk); requestAnimationFrame(() => { bk.style.opacity = '1'; });
}
function wDebugGradesHTML() {
  const L = ['S', 'A', 'B', 'C', 'D', 'F'], b = (k, plus) => '<button data-act="wgrade:' + k + '" aria-label="' + k + '" style="display:flex;justify-content:center;padding:0">' + scoreTile(k.charAt(0), 40, plus) + '</button>';
  const dia = b('Sd', 'd');
  return '<div style="padding:12px 16px 8px;font-size:14px;color:var(--mute)">Calificaciones (datos planos)</div><div style="display:grid;grid-template-columns:repeat(6,1fr);gap:8px 4px;padding:0 12px 4px">' +
    L.map((x) => b(x, false)).join('') + L.map((x) => b(x + 'p', true)).join('') + dia + '</div>' +
    '<div style="padding:4px 16px 8px;font-size:12px;color:#8E8E93">Segunda fila: letra+ / letra- (racha de 2 meses) · al final: Diamante</div>';
}
function wDebugClose() { const b = $('#wdbg'); if (b) { b.style.opacity = '0'; setTimeout(() => b.remove(), 200); } }
function wDebugPick(v) {
  data.settings.lang = v === 'auto' ? '' : v; persist(); applyLang();
  ui.w = null; welcomeHTML();
}
function wMenu() {
  if ($('#wmenu')) { wCloseMenu(); return; }
  const w = $('#welcome'), btn = w.querySelector('.wdotbtn'), d = w.getBoundingClientRect(), r = btn.getBoundingClientRect(), k = d.width / w.offsetWidth || 1;
  const bk = document.createElement('div'); bk.id = 'wmenuback'; bk.setAttribute('data-act', 'wmenuclose'); bk.style.cssText = 'position:absolute;inset:0;z-index:160';
  const m = document.createElement('div'); m.id = 'wmenu'; m.className = 'popmenu'; m.style.zIndex = '170'; m.style.transformOrigin = '100% 100%';
  const ic = (c, n) => RMI(n, 22, c);
  m.innerHTML = '<button class="pmi" data-act="wquick" style="gap:12px;padding-left:18px">' + ic('#22B573', 'flashlight-line') + '<span style="display:flex;flex-direction:column;align-items:flex-start;text-align:left"><span>Inicio rápido</span><span style="font-size:12px;font-weight:400;color:var(--mute);line-height:1.25;margin-top:1px;white-space:normal">Adelanta el recorrido inicial.</span></span></button><div class="pmsep"></div>' +
    '<button class="pmi" data-act="wdemo" style="gap:12px;padding-left:18px">' + ic('#B98AE6', 'bar-chart-line') + '<span style="display:flex;flex-direction:column;align-items:flex-start;text-align:left"><span>Datos de demostración</span><span style="font-size:12px;font-weight:400;color:var(--mute);line-height:1.25;margin-top:1px;white-space:normal">Revisa un ejemplo de alguien usando Plata.</span></span></button><div class="pmsep"></div>' +
    '<button class="pmi" data-act="wload" style="gap:12px;padding-left:18px">' + ic('#4C8DF6', 'upload-2-line') + '<span style="display:flex;flex-direction:column;align-items:flex-start;text-align:left"><span>Cargar archivo de perfil</span><span style="font-size:12px;font-weight:400;color:var(--mute);line-height:1.25;margin-top:1px;white-space:normal">Abre un perfil que guardaste.</span></span></button>';
  w.appendChild(bk); w.appendChild(m);
  m.style.right = ((d.right - r.right) / k) + 'px'; m.style.bottom = ((d.bottom - r.top) / k + 8) + 'px';
  requestAnimationFrame(() => m.classList.add('in'));
}
function wCloseMenu() { const m = $('#wmenu'); if (m) { m.classList.remove('in'); setTimeout(() => m.remove(), 180); } const b = $('#wmenuback'); if (b) b.remove(); }
function wPhotoHTML() { const p = ui.w && ui.w.photo; return '<div style="display:flex;flex-direction:column;align-items:center;gap:2px;padding:0 0 12px"><button data-act="pickphoto" aria-label="Foto de perfil" style="padding:0">' + avatarHTML(60, p || '') + '</button><div style="display:flex;gap:18px"><button class="linkrow" data-act="pickphoto" style="padding:0;border:0;font-size:15px;min-height:30px;color:#22B573">' + (p ? 'Cambiar foto' : 'Añadir foto (opcional)') + '</button>' + (p ? '<button class="linkrow" data-act="rmphoto" style="padding:0;border:0;font-size:15px;min-height:30px;color:var(--rt)">Quitar</button>' : '') + '</div></div>'; }
const wQ = (v, d) => { const n = Math.round(parseFloat(String(v).replace(',', '.'))); return n >= 1 && n <= 31 ? n : d; };
function wFinish(skip) {
  newsMark();
  wSync(); const w = ui.w; if (!w) return; if (skip) wClear(w);
  const fresh = clone(EMPTY), acc = fresh.accounts[0];
  fresh.settings = Object.assign({}, fresh.settings || {}, w.photo ? { photo: w.photo, photoSrc: w.photoSrc, photoCrop: w.photoCrop } : {}, { first: (w.first || '').trim(), last: (w.last || '').trim(), nick: (w.nick || '').trim(), gender: w.gender || 'n', insights: w.ins !== false, score: w.ins !== false && w.score !== false, currency: w.cur[0], currency2: w.cur[1] || '', customCur: w.custom || '', fx: w.cur[1] ? (w.fx > 0 ? w.fx : fxDefault(w.cur[0], w.cur[1])) : (fresh.settings && fresh.settings.fx) || 3.5, tour: { on: true, seen: {} } });
  acc.name = (w.accName || '').trim() || 'Cuenta principal'; acc.type = w.accType; acc.cur = w.cur.indexOf(w.accCur) >= 0 ? w.accCur : w.cur[0]; acc.balance = round2(parseFloat(String(w.bal).replace(',', '.')) || 0);
  const amt = parseFloat(String(w.incAmt).replace(',', '.'));
  if (w.incKind === 'j') {
    const md = wJobMode(w), rate = wnum(w.jRate), hrs = md === 's' ? 0 : Math.max(0, Math.min(168, wnum(w.jHours)));
    if (rate > 0 && (md === 's' || hrs > 0)) {
      const fq = ['w', 'b', 'q', 'm'].indexOf(w.jFreq) >= 0 ? w.jFreq : (md === 's' ? 'm' : 'b');
      const jq = qDays('q' + wQ(w.jQ1, 15) + ',' + wQ(w.jQ2, 30)), jobo = { id: uid(), mode: md, name: (w.jName || '').trim() || 'Trabajo', rate: rate, hours: hrs, tax: md === 's' ? 0 : Math.max(0, Math.min(90, wnum(w.jTax))), freq: fq, acc: acc.id, start: w.jDate || iso(getToday()), until: '', sim: 0 };
      if (fq === 'q') { jobo.q1 = jq[0]; jobo.q2 = jq[1]; jobo.start = iso(qNext(pd(iso(getToday())), 'q' + jq[0] + ',' + jq[1], true)); }
      fresh.jobs.push(jobo);
    }
  } else if (amt > 0) fresh.expected_income.push({ id: uid(), name: (w.incName || '').trim() || 'Sueldo', amount: amt, acc: acc.id, date: w.incRep === 'q' ? iso(qNext(pd(iso(getToday())), qMake(wQ(w.incQ1, 15), wQ(w.incQ2, 30)), true)) : w.incDate, repeat: w.incRep === 'm' ? 'm' : w.incRep === 'q' ? qMake(wQ(w.incQ1, 15), wQ(w.incQ2, 30)) : Number(w.incRep) });
  if (w.level === 'extended') {
    const fx = wnum(w.fxAmt), nm = (w.fxName || '').trim();
    if (fx > 0) fresh.expected_expense.push({ id: uid(), name: nm || 'Gasto fijo', amount: fx, acc: acc.id, date: w.fxRep === 'q' ? iso(qNext(pd(iso(getToday())), qMake(wQ(w.fxQ1, 1), wQ(w.fxQ2, 15)), true)) : (w.fxDate || iso(getToday())), repeat: w.fxRep === 'm' ? 'm' : w.fxRep === 'q' ? qMake(wQ(w.fxQ1, 1), wQ(w.fxQ2, 15)) : Number(w.fxRep), until: '', cat: /renta|alquiler/i.test(nm) ? 'Alquiler' : 'Otros' });
    const sb = wnum(w.subAmt); if (sb > 0) fresh.subs.push({ id: uid(), since: iso(getToday()), name: (w.subName || '').trim() || 'Servicio o suscripción', amount: sb, cur: acc.cur, day: Math.max(1, Math.min(31, Math.round(wnum(w.subDay)) || 1)) });
    const db = wnum(w.dbBal), dn = (w.dbName || '').trim();
    if (db > 0 || dn) fresh.cards.push({ id: uid(), kind: w.dbKind === 'loan' ? 'loan' : 'card', name: dn || (w.dbKind === 'loan' ? 'Préstamo' : 'Tarjeta'), cur: acc.cur, limit: w.dbKind === 'loan' ? 0 : wnum(w.dbLim), balance: db, apr: w.dbApr === '' ? 20 : wnum(w.dbApr), payment: wnum(w.dbPay), due_day: Math.max(1, Math.min(31, Math.round(wnum(w.dbDay)) || 1)), color: '', icon: '' });
    const gl = wnum(w.gGoal), gn = (w.gName || '').trim();
    if (gn && gl > 0) fresh.savings.push({ id: uid(), name: gn, cur: acc.cur, balance: 0, goal: gl, monthly: wnum(w.gMon), color: CARD_COLORS[0], icon: '' });
  }
  if (w.level !== 'simple') { const bd = {}; Object.keys(w.bud || {}).forEach((k) => { const v = wnum(w.bud[k]); if (v > 0) bd[k] = v; }); if (Object.keys(bd).length) fresh.budget = bd; }
  wPriv(() => { data = migrate(fresh); syncJobs(); ui.dirty = 1; persist(); renderAll(); setTab('resumen'); hideWelcome(); toast('¡Todo listo!'); if (w.cloud && clIn()) setTimeout(() => clSync('tour'), 300); if (w.impAfter === '1') setTimeout(() => { try { impOpen(); } catch (e) { /* sin importador */ } }, 650); });
}

