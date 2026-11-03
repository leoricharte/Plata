/* ---------- Plata para Android (empaquetada con Capacitor) ----------
 * Lo que la app de iPhone hace con código nativo (avisos, guardar y compartir archivos, recibir capturas desde «Compartir», enlaces a un evento),
 * aquí lo hace esta capa sobre la web. Solo se activa dentro de la app empaquetada (PN.on, ver 01-inicio-bloqueo-con-pin.js): en el navegador,
 * en la PWA y en el iPhone no existe window.Capacitor y nada de esto corre. La huella o el rostro viven en 01 (van pegados al bloqueo con PIN). */

/* ---- Avisos locales: lo mismo que Reminders.swift del iPhone. Se programan en el teléfono con lo que ya sabe Plata; no pasan por ningún servidor. ---- */
const AV_TIERS = [
  [2, [['Tu plata no se anota sola', 'Your money won\'t log itself', 'Dos días de silencio. Son 30 segundos, no una tesis.', 'Two days of silence. It takes 30 seconds, not a thesis.'],
       ['Psst. ¿Y los gastos de hoy?', 'Psst. What about today\'s spending?', 'Dos días sin anotar. Tu yo del viernes te lo va a agradecer.', 'Two days without logging. Future you will say thanks.'],
       ['Tu plata está sola en casa', 'Your money is home alone', 'Pasa a anotar algo antes de que haga una fiesta.', 'Log something before it throws a party.']]],
  [5, [['Tu mes sigue corriendo', 'Your month keeps moving', '5 días sin anotar. Lo que no registras hoy, mañana ya no lo recuerdas.', '5 days with no entries. What you don\'t log today, you won\'t remember tomorrow.'],
       ['Cinco días. Cinco. Cuéntame.', 'Five days. Five. Talk to me.', 'Anota lo que pasó, aunque sea lo del café.', 'Log what happened, even if it\'s just the coffee.'],
       ['Tu presupuesto está preocupado', 'Your budget is worried', 'No sabe de ti hace 5 días. Dale una señal de vida.', 'No word from you in 5 days. Give it a sign of life.']]],
  [9, [['Plata te extraña (enserio)', 'Plata misses you (seriously)', '9 días sin pasar por aquí. Tu saldo también quiere saber de ti.', '9 days gone. Your balance wants to hear from you too.'],
       ['¿Seguimos juntos?', 'Are we still a thing?', '9 días sin una sola anotación. Plata necesita que hablemos.', '9 days without a single entry. Plata needs us to talk.'],
       ['Tus gastos siguen pasando', 'Your spending keeps happening', 'Con o sin que los anotes. Ya son 9 días de datos perdidos.', 'Whether you log it or not. That\'s 9 days of lost data.']]],
  [16, [['Sin datos no hay nota', 'No data, no grade', '16 días a ciegas. Así no hay evaluación que valga.', '16 days flying blind. No grade can survive that.'],
        ['Tu nota del mes está en coma', 'Your monthly grade is in a coma', '16 días sin datos. Un minuto y la reanimas.', '16 days without data. One minute and you revive it.'],
        ['Plata no adivina', 'Plata can\'t guess', '16 días sin anotar. Sin datos, la nota se la inventa cualquiera.', '16 days without entries. Without data, any grade is made up.']]],
  [23, [['Casi un mes de misterio', 'Almost a month of mystery', 'Ponte al día en un minuto antes del cierre. Tú sabrás.', 'Catch up in a minute before month-end. Your call.'],
        ['Casi un mes sin ti', 'Almost a month without you', 'Ponte al día antes de que el cierre te agarre desprevenido.', 'Catch up before month-end catches you off guard.'],
        ['El cierre de mes no perdona', 'Month-end doesn\'t forgive', 'Un minuto hoy te ahorra un dolor de cabeza después.', 'One minute today saves a headache later.']]],
];
/* Evaluación del mes (día 1) y half-time (día 15): 5 versiones de cada uno según el mes. {mes} es el mes que se evalúa. */
const AV_MONTH = [
  ['Salió tu evaluación de {mes}', 'Your {mes} grade is in', 'Entra y mira qué nota sacaste.', 'Open Plata and see what you got.'],
  ['¿Sacaste A? ¿Sacaste F?', 'Did you get an A? An F?', 'Tu evaluación de {mes} ya está lista.', 'Your {mes} grade is ready.'],
  ['Se acabó el mes. Hora de la verdad.', 'The month is over. Moment of truth.', 'Mira cómo te fue en {mes}.', 'See how {mes} went.'],
  ['Tu cierre de mes está servido', 'Your month-end report is served', 'Una nota, tus números y algunos consejos.', 'A grade, your numbers and some tips.'],
  ['Ding: nueva evaluación', 'Ding: new grade', 'Revisa tus insights de {mes} antes de que se enfríen.', 'Check your {mes} insights while they\'re hot.'],
];
const AV_HALF = [
  ['¡Half-time!', 'Half-time!', 'Así va tu nota a mitad de mes.', 'Here\'s how your grade looks at mid-month.'],
  ['Llegaste a la mitad', 'You\'ve hit the halfway mark', 'Mira tu avance: aún queda tiempo para mejorar.', 'See your progress; there\'s still time to improve.'],
  ['Mitad de mes, momento de revisar', 'Mid-month check-in', 'Tu informe parcial ya está listo.', 'Your partial report is ready.'],
  ['Tu nota va tomando forma', 'Your grade is taking shape', 'Revisa el half-time y ajusta antes del cierre.', 'Check your half-time and adjust before month-end.'],
  ['¿Cómo vas este mes?', 'How\'s your month going?', 'Tu half-time te lo cuenta en un minuto.', 'Your half-time tells you in a minute.'],
];
/* Pagos, cobros e ingresos de mañana: título y texto (es, en) para «mañana» y para «hoy», 3 versiones por tipo (se elige una estable por evento). */
const AV_UP = {
  card: { eve: [['Mañana toca pagar la tarjeta', 'Card payment due tomorrow', 'Que los intereses no se coman tu mes.', 'Don\'t let interest eat your month.'],
                ['La tarjeta cobra mañana', 'Your card is due tomorrow', 'Págala a tiempo y los intereses se quedan con hambre.', 'Pay on time and interest goes hungry.'],
                ['Mañana vence tu tarjeta', 'Your card is due tomorrow', 'Un recordatorio con cariño: que no te cobren de más.', 'A friendly nudge: don\'t pay a cent more than you owe.']],
          today: [['Hoy se paga la tarjeta', 'Card payment due today', 'Hoy no hay excusas. Págala y respira.', 'No excuses today. Pay it and breathe.'],
                  ['Hoy vence la tarjeta', 'Card due today', 'Hoy es el día. Págala y duerme tranquilo.', 'Today\'s the day. Pay it and sleep easy.'],
                  ['Tu tarjeta no espera', 'Your card won\'t wait', 'Vence hoy. Un par de toques y listo.', 'Due today. A couple of taps and done.']] },
  income: { eve: [['Mañana te cae plata', 'Money lands tomorrow', 'Cuando llegue, confírmala. Disfrútala un minuto antes de gastarla.', 'Confirm it when it lands. Enjoy it for a minute before spending it.'],
                  ['Mañana llega tu plata', 'Your money arrives tomorrow', 'Confírmala al llegar. Gastarla viene después.', 'Confirm it when it arrives. Spending it comes later.'],
                  ['Se viene un ingreso', 'Income incoming', 'Que no se quede sin registrar, ¿eh?', 'Don\'t leave it unlogged, okay?']],
            today: [['Hoy te cae plata', 'Money lands today', null, null], ['Hoy llega tu plata', 'Your money arrives today', null, null], ['Hoy llega un ingreso', 'Income lands today', null, null]] },
  pay: { eve: [['Mañana vence un pago', 'A payment is due tomorrow', 'Que no te agarre de sorpresa.', 'Don\'t get caught off guard.'],
               ['Mañana toca pagar', 'Payment day tomorrow', 'Mejor que lo recuerdes tú y no el banco.', 'Better you remember than the bank.'],
               ['Un pago te espera mañana', 'A payment awaits tomorrow', 'Sin sustos: ya lo sabes con tiempo.', 'No surprises: you know ahead of time.']],
         today: [['Hoy vence un pago', 'A payment is due today', 'Que no se te pase hoy.', 'Don\'t let it slip today.'],
                 ['Hoy toca pagar', 'Payment day', 'Hazlo ahora y quítatelo de encima.', 'Do it now and get it off your plate.'],
                 ['Hoy te espera un pago', 'A payment awaits today', 'Pagarlo hoy es gratis; olvidarlo, no.', 'Paying today is free; forgetting isn\'t.']] },
};
const AV_SUB_HINT = [['¿Todavía la usas o solo la mantienes viva? Piénsalo.', 'Do you still use it, or just keep it on life support? Think about it.'],
                     ['¿Te sirve o solo te cobra? Decide antes de que lo haga por ti.', 'Useful or just charging you? Decide before it decides for you.'],
                     ['Otro cobro automático. ¿Sigue valiendo la pena?', 'Another automatic charge. Still worth it?']];

/* Un número entero estable a partir de un texto (los avisos del sistema piden ids numéricos). */
const avId = (s) => { let h = 0; for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0; return (h & 0x7fffffff) || 1; };

/* El plan de avisos: una lista de { key, title, body, at } según los datos y las preferencias. Es una función pura (se prueba en dev/tests/avisos.mjs).
 *   o.now: Date · o.lang: 0 español, 1 inglés · o.prefs: { inact, up, amt, ins, since } · o.txs: movimientos · o.events: genEvents() · o.fmt: formatea un monto
 *   o.insights: ¿están encendidas la evaluación y los insights? · o.monthName(Date): nombre del mes */
function avisosPlan(o) {
  const out = [], now = o.now, L = o.lang === 1 ? 1 : 0, P = o.prefs || {};
  const at = (day, hour) => new Date(day.getFullYear(), day.getMonth(), day.getDate(), hour, 0, 0, 0);
  const startOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const addDay = (d, n) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);
  const pd2 = (s) => { const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(s || '')); return m ? new Date(+m[1], +m[2] - 1, +m[3]) : null; };
  const add = (key, title, body, when) => { if (when > now) out.push({ key: key, title: title, body: body, at: when }); };
  const pick = (row) => [row[L], row[2 + L]];
  const daysOf = (d) => Math.floor(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) / 86400000);

  if (P.ins && o.insights) {
    // los próximos 2 inicios de mes (nota del mes que acaba de cerrar) y los próximos 2 días 15 (half-time), a las 9:00
    for (let k = 0; k < 3; k++) {
      const first = new Date(now.getFullYear(), now.getMonth() + k, 1), key = first.getFullYear() + '-' + String(first.getMonth() + 1).padStart(2, '0');
      const idx = (first.getFullYear() * 12 + first.getMonth() + 1) % 5;
      if (k > 0) {
        const mes = o.monthName(new Date(first.getFullYear(), first.getMonth() - 1, 1)), t = pick(AV_MONTH[idx]);
        add('insm-' + key, t[0].replace('{mes}', mes), t[1].replace('{mes}', mes), at(first, 9));
      }
      const h = pick(AV_HALF[idx]);
      add('insh-' + key, h[0], h[1], at(addDay(first, 14), 9));
    }
  }

  if (P.inact) {
    // desde el último movimiento (o, si no hay ninguno, desde el día en que se encendió)
    let last = null;
    (o.txs || []).forEach((t) => { const d = pd2(t.date); if (d && d <= now && (!last || d > last)) last = d; });
    const since = new Date(P.since || now.getTime()), anchor = startOfDay(last && last > since ? last : since);
    let n = 0;
    AV_TIERS.forEach((tier, i) => {
      const day = addDay(anchor, tier[0]), when = at(day, 19);
      if (!(when > now) || n >= 3) return;
      n++;
      const t = pick(tier[1][(Math.floor(day.getTime() / 86400000) + i) % tier[1].length]);
      add('inact' + i, t[0], t[1], when);
    });
  }

  if (P.up) {
    let count = 0; const today = daysOf(now);
    (o.events || []).forEach((ev) => {
      if (ev.type === 'sim' || count >= 40) return;
      const day = ev.date, dd = daysOf(day);
      if (!(day.getTime() > now.getTime() - 86400000) || dd - today > 21) return;
      const amount = P.amt ? o.fmt(Math.abs(ev.amt)) : '', name = ev.name || '', tag = [name, amount].filter(Boolean).join(' · '), pre = tag ? tag + '. ' : '';
      let sum = 0; for (let i = 0; i < name.length; i++) sum += name.charCodeAt(i) < 128 ? name.charCodeAt(i) : 0;   // estable para el mismo evento
      const v = (dd + sum) % 3;
      let eve, td;
      if (ev.type === 'card') { eve = pick(AV_UP.card.eve[v]); td = pick(AV_UP.card.today[v]); eve[1] = pre + eve[1]; td[1] = pre + td[1]; }
      else if (ev.type === 'sub') {
        const amt = amount ? amount + '. ' : '', hint = AV_SUB_HINT[v][L];
        eve = [name ? (L ? name + ' charges you tomorrow' : 'Mañana se cobra ' + name) : (L ? 'A subscription charges you tomorrow' : 'Mañana se cobra una suscripción'), amt + hint];
        td = [name ? (L ? name + ' charges you today' : 'Hoy se cobra ' + name) : (L ? 'A subscription charges you today' : 'Hoy se cobra una suscripción'), amt + hint];
      } else {
        const set = ev.amt > 0 ? AV_UP.income : AV_UP.pay;
        eve = pick(set.eve[v]); const tt = set.today[v]; td = [tt[L], tt[2 + L] || set.eve[v][2 + L]];
        eve[1] = pre + eve[1]; td[1] = pre + td[1];
      }
      const before = addDay(day, -1), base = 'ev' + ev.date.getFullYear() + '-' + (ev.date.getMonth() + 1) + '-' + ev.date.getDate() + '-' + avId(name) % 100000;
      if (at(before, 9) > now) { add(base + 'a', eve[0], eve[1], at(before, 9)); count++; }
      else if (at(day, 8) > now) { add(base + 'b', td[0], td[1], at(day, 8)); count++; }
    });
  }
  return out;
}

const AVK = 'plata.avisos', AVIDS = 'plata.avisos.ids';
const avisosPrefs = () => { try { const p = JSON.parse(localStorage.getItem(AVK) || 'null'); return Object.assign({ inact: false, up: false, amt: false, ins: false, since: 0 }, p || {}); } catch (e) { return { inact: false, up: false, amt: false, ins: false, since: 0 }; } };
const avisosSave = (p) => { try { localStorage.setItem(AVK, JSON.stringify(p)); } catch (e) { /* sin almacenamiento */ } };

async function avisosAllow() {
  const LN = PN.plugin('LocalNotifications'); if (!LN) return false;
  try {
    let p = await LN.checkPermissions();
    if (p.display !== 'granted') p = await LN.requestPermissions();
    return p.display === 'granted';
  } catch (e) { return false; }
}

/* Reprograma todo: borra los avisos de Plata que ya estaban y pone los nuevos. Se llama al abrir, al salir de la app y al cambiar una preferencia. */
async function avisosSchedule() {
  const LN = PN.plugin('LocalNotifications'); if (!LN || !data) return;
  try {
    let old = []; try { old = JSON.parse(localStorage.getItem(AVIDS) || '[]'); } catch (e) { /* sin lista */ }
    if (old.length) await LN.cancel({ notifications: old.map((id) => ({ id: id })) });
    const P = avisosPrefs(); try { localStorage.setItem(AVIDS, '[]'); } catch (e) { /* sin almacenamiento */ }
    if (!(P.inact || P.up || P.ins)) return;
    if ((await LN.checkPermissions()).display !== 'granted') return;
    const lang = resolveLang() === 'es' ? 0 : 1, T = getToday();
    const plan = avisosPlan({ now: new Date(), lang: lang, prefs: P, txs: data.transactions || [], events: P.up ? genEvents(T) : [], fmt: fmt, insights: insOn() && (data.settings || {}).score !== false,
      monthName: (d) => new Intl.DateTimeFormat(lang ? 'en' : 'es', { month: 'long' }).format(d) });
    if (!plan.length) return;
    try { await LN.createChannel({ id: 'avisos', name: lang ? 'Plata reminders' : 'Avisos de Plata', description: lang ? 'Payments, charges and your monthly grade' : 'Pagos, cobros y tu nota del mes', importance: 3 }); } catch (e) { /* ya existe */ }
    const ids = [], notifications = plan.map((n) => { const id = avId(n.key); ids.push(id); return { id: id, title: n.title, body: n.body, channelId: 'avisos', schedule: { at: n.at, allowWhileIdle: true } }; });
    await LN.schedule({ notifications: notifications });
    try { localStorage.setItem(AVIDS, JSON.stringify(ids)); } catch (e) { /* sin almacenamiento */ }
  } catch (e) { /* sin avisos: nada que mostrar */ }
}
async function avisosSet(ch) {
  const P = Object.assign(avisosPrefs(), ch);
  if ((ch.inact || ch.up || ch.ins) && !(await avisosAllow())) { toast('Activa los avisos de Plata en los ajustes del teléfono'); return; }
  if (!P.since) P.since = Date.now();
  avisosSave(P); avisosSchedule(); setTimeout(avisosMenu, 250);
}
function avisosMenu() {
  const P = avisosPrefs(), st = (v) => (v ? 'sí' : 'no');
  askConfirm('Avisos', 'Se programan en tu teléfono con lo que ya sabe Plata: no pasan por ningún servidor.', [
    { label: 'Si llevas días sin anotar: ' + st(P.inact) + ' (tocar para cambiar)', fn: () => avisosSet({ inact: !P.inact }) },
    { label: 'Pagos, cobros e ingresos de mañana: ' + st(P.up) + ' (tocar para cambiar)', fn: () => avisosSet({ up: !P.up }) },
    { label: 'Mostrar montos en los avisos: ' + st(P.amt) + ' (tocar para cambiar)', fn: () => avisosSet({ amt: !P.amt }) },
    { label: 'Nota del mes y half-time: ' + st(P.ins) + ' (tocar para cambiar)', fn: () => avisosSet({ ins: !P.ins }) },
  ], '', 'Cerrar');
}
const avisosOn = () => { const P = avisosPrefs(); return !!(P.inact || P.up || P.ins); };

/* ---- Guardar y compartir archivos: el navegador del sistema (WebView) no descarga los blob:, así que se escriben en la caché y se abre «Compartir» ---- */
function nativeBlobBase64(b) { return new Promise((res, rej) => { const r = new FileReader(); r.onload = () => res(String(r.result).split(',')[1] || ''); r.onerror = () => rej(r.error); r.readAsDataURL(b); }); }
async function nativeSaveFile(name, blob) {
  const FS = PN.plugin('Filesystem'), SH = PN.plugin('Share');
  if (!FS || !SH) { toast('No se pudo guardar el archivo'); return; }
  try {
    const w = await FS.writeFile({ path: name, data: await nativeBlobBase64(blob), directory: 'CACHE', recursive: true });
    await SH.share({ title: name, url: w.uri, dialogTitle: 'Guardar o enviar' });
  } catch (e) { if (!/cancel/i.test(String((e && (e.message || e.errorMessage)) || e))) toast('No se pudo guardar el archivo'); }
}
(function () {
  if (!PN.on) return;
  const blobs = new Map(), co = URL.createObjectURL.bind(URL), click = HTMLAnchorElement.prototype.click;
  URL.createObjectURL = (b) => { const u = co(b); try { if (b instanceof Blob) blobs.set(u, b); } catch (e) { /* sin registro */ } return u; };
  HTMLAnchorElement.prototype.click = function () {
    const b = this.hasAttribute('download') ? blobs.get(this.href) : null;
    if (b) { nativeSaveFile(this.getAttribute('download') || 'plata', b); return; }
    return click.call(this);
  };
})();

/* ---- Recibir desde «Compartir»: una captura o un archivo que la persona manda a Plata desde otra app (el plugin nativo lo deja en espera) ---- */
function nativeFileFrom(it) {
  const bin = atob(it.data || ''), u = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i);
  return new File([u], it.name || 'compartido', { type: it.mime || '' });
}
async function shareIngest() {
  const p = PN.plugin('PlataNative'); if (!p || !data || !nazcaOn()) return;
  let r; try { r = await p.getShared(); } catch (e) { return; }
  const it = r && r.item; if (!it) return;
  setTab('cuenta'); impOpen();
  if (it.kind === 'text') { ui.impDir = ui.impDir || 'out'; impShow('paste', 'tab'); impConstancia(it.text, false); return; }
  const f = nativeFileFrom(it);
  if (/^image\//.test(it.mime || '')) {
    askConfirm('Captura recibida', '¿Qué es?', [
      { label: 'Constancia de Yape o Plin', fn: () => { ui.impDir = ui.impDir || 'out'; impShow('paste', 'tab'); impShot(f); } },
      { label: 'Captura de movimientos de un banco', fn: () => impExLoad(f) },
    ], '', 'Cancelar');
  } else impFiles([f]);
}

/* ---- Enlaces: https://web.plataapp.net/?ev=… (el que lleva el evento añadido al calendario) abre ese evento en Proyección ---- */
function nativeOpenLink(url) {
  let key = ''; try { key = new URL(url).searchParams.get('ev') || ''; } catch (e) { return; }
  if (!key) return;
  try { genEvents(getToday()); setTab('proyeccion'); if (EVKEY[key]) setTimeout(() => openEv(key), 350); } catch (e) { /* queda la app normal */ }
}

/* ---- Arranque dentro de la app empaquetada ---- */
(function () {
  if (!PN.on) return;
  document.addEventListener('click', (e) => {
    const b = e.target.closest && e.target.closest('[data-act="avisos:menu"]'); if (!b) return; e.stopPropagation(); e.preventDefault(); avisosMenu();
  }, true);
  const App = PN.plugin('App');
  if (App) {
    try { App.addListener('appUrlOpen', (e) => nativeOpenLink(e && e.url)); } catch (e) { /* sin enlaces */ }
    try { App.getLaunchUrl().then((r) => { if (r && r.url) setTimeout(() => nativeOpenLink(r.url), 1200); }); } catch (e) { /* sin enlace de arranque */ }
    try { App.addListener('appStateChange', (s) => { if (s && s.isActive) setTimeout(shareIngest, 400); else avisosSchedule(); }); } catch (e) { /* sin estado */ }
  }
  setTimeout(() => { avisosSchedule(); shareIngest(); }, 2500);
})();
