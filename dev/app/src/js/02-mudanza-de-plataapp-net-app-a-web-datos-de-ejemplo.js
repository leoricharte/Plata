/* ---------- Mudanza de plataapp.net/app a web.plataapp.net ----------
 * Los datos del navegador no cruzan de dominio solos. La primera vez que la app abre en web.plataapp.net SIN datos, carga un puente
 * invisible del dominio viejo (plataapp.net/app/puente.html), que le pasa los datos por postMessage dirigido solo a este origen.
 * Al guardarlos, le pide al puente que borre la copia vieja: así no queda ninguna frase guardada en el dominio del sitio público. */
(function () {
  const NEW = 'https://web.plataapp.net', OLD = 'https://plataapp.net';
  try {
    if (location.origin !== NEW || localStorage.getItem('plata.mudanza')) return;
    if (localStorage.getItem('finanzas.v3') || localStorage.getItem('plata.cloud')) { localStorage.setItem('plata.mudanza', 'propia'); return; } // ya hay datos aquí: no se pisa nada
  } catch (e) { return; }
  const f = document.createElement('iframe'); f.src = OLD + '/app/puente.html'; f.title = 'mudanza'; f.setAttribute('aria-hidden', 'true'); f.style.cssText = 'position:absolute;width:0;height:0;border:0;visibility:hidden';
  const ok = (k) => /^(finanzas|plata)\.[\w.-]{1,40}$/.test(k) && k !== 'plata.mudanza';
  const fin = (reload) => { clearTimeout(tm); window.removeEventListener('message', on); f.remove(); try { localStorage.setItem('plata.mudanza', String(Date.now())); } catch (e) { /* sin almacenamiento */ } if (reload) location.reload(); };
  const tm = setTimeout(() => { window.removeEventListener('message', on); f.remove(); try { const n = Number(localStorage.getItem('plata.mudanza.n') || 0) + 1; localStorage.setItem('plata.mudanza.n', String(n)); if (n >= 3) localStorage.setItem('plata.mudanza', 'sin-respuesta'); } catch (e) { /* sin almacenamiento */ } }, 12000);
  let got = 0;
  function on(e) {
    if (e.origin !== OLD || e.source !== f.contentWindow || !e.data || typeof e.data !== 'object') return;
    if (e.data.t === 'listo') f.contentWindow.postMessage({ t: 'pedir' }, OLD);
    else if (e.data.t === 'datos') {
      const it = e.data.items && typeof e.data.items === 'object' ? e.data.items : {};
      Object.keys(it).forEach((k) => { if (ok(k) && typeof it[k] === 'string' && it[k].length < 5e6) { try { localStorage.setItem(k, it[k]); got++; } catch (x) { /* sin espacio */ } } });
      if (it['plata.cloud']) { try { localStorage.setItem('plata.mudanza.cloud', '1'); } catch (x) { /* sin almacenamiento */ } } // se confirma con la persona al abrir (ver abajo)
      if (got) f.contentWindow.postMessage({ t: 'borrar' }, OLD); else fin(false);
    } else if (e.data.t === 'borrado') fin(got > 0);
  }
  window.addEventListener('message', on);
  (document.body || document.documentElement).appendChild(f);
})();

/* ---------- Datos de ejemplo (misma forma que el save file, versión 2) ---------- */
function makeSample() {
  const T = getToday(), off = (n) => iso(addDays(T, n)), ms = iso(new Date(T.getFullYear(), T.getMonth(), 1));
  const tx = []; let id = 1;
  const add = (o, amount, category, note, acc, est) => { const d = o === 'rent' ? ms : off(o); if (d > iso(T)) return; const t = { id: id++, date: d, amount: amount, category: category, note: note, acc: acc }; if (est) t.est = est; tx.push(t); };
  add('rent', -1150, 'Alquiler', 'Alquiler', 'bank');
  add(-1, -41.8, 'Comida', 'Supermercado', 'bank'); add(-1, -14.5, 'Comida', 'Café y almuerzo', 'cap');
  add(-2, -62.3, 'Mascotas', 'Comida de gatos', 'apple'); add(-2, -9.99, 'Ocio', 'Suscripción música', 'cap');
  add(-3, -28.4, 'Transporte', 'Uber', 'cap'); add(-4, -76.2, 'Comida', 'Supermercado', 'bank');
  add(-5, -120, 'Proyectos', 'Alquiler de lente', 'bank'); add(-5, -34, 'Ocio', 'Cine y cena', 'apple');
  add(-6, -18.75, 'Comida', 'Delivery', 'chime'); add(-7, -32, 'Transporte', 'Gasolina', 'cap');
  add(-9, 1420, 'Ingreso', 'Sueldo', 'bank', 1400);
  add(-10, -52.6, 'Mascotas', 'Veterinario', 'bank'); add(-11, -22, 'Otros', 'Regalo', 'bank');
  add(-12, -64.9, 'Comida', 'Supermercado', 'bank'); add(-13, -15, 'Ocio', 'Bar', 'cap');
  add(-14, -12, 'Transporte', 'Pasajes', 'cash'); add(-15, 600, 'Ingreso', 'Proyecto Estudio 2²', 'bank', 750);
  add(-16, -27.9, 'Comida', 'Cena con el equipo', 'apple'); add(-18, -180, 'Proyectos', 'Locación de rodaje', 'bank');
  add(-20, -58.3, 'Comida', 'Supermercado', 'bank'); add(-21, -12.99, 'Ocio', 'Streaming', 'cap');
  add(-23, 1420, 'Ingreso', 'Sueldo', 'bank', 1420); add(-25, -39, 'Mascotas', 'Arena y juguetes', 'apple');
  add(-27, -88.4, 'Comida', 'Supermercado', 'bank'); add(-30, -240, 'Proyectos', 'Software anual', 'apple');
  const pm = new Date(T.getFullYear(), T.getMonth() - 1, 1), dd = (d) => iso(new Date(pm.getFullYear(), pm.getMonth(), d));
  const addP = (d, amount, category, note, acc) => tx.push({ id: id++, date: dd(d), amount: amount, category: category, note: note, acc: acc });
  addP(1, -1150, 'Alquiler', 'Alquiler', 'bank'); addP(2, -68.4, 'Comida', 'Supermercado', 'bank'); addP(3, -35, 'Transporte', 'Gasolina', 'cap'); addP(4, -140, 'Proyectos', 'Alquiler de equipo', 'bank');
  addP(5, -95, 'Mascotas', 'Veterinario', 'bank'); addP(6, -22.5, 'Comida', 'Delivery', 'chime'); addP(7, -58, 'Mascotas', 'Comida de gatos', 'apple'); addP(8, -30, 'Ocio', 'Cine', 'apple');
  addP(9, 1420, 'Ingreso', 'Sueldo', 'bank', 1400); addP(9, -85, 'Otros', 'Ropa', 'apple'); addP(10, -81.2, 'Comida', 'Supermercado', 'bank'); addP(11, -280, 'Proyectos', 'Lente en renta', 'apple');
  addP(12, -26, 'Transporte', 'Uber', 'cap'); addP(13, -80, 'Ocio', 'Concierto', 'apple'); addP(14, -44.9, 'Comida', 'Cena', 'apple'); addP(14, -95, 'Comida', 'Cena de cumpleaños', 'apple');
  addP(15, -19.99, 'Ocio', 'Streaming', 'cap'); addP(16, 450, 'Ingreso', 'Proyecto Estudio 2²', 'bank', 450); addP(16, -150, 'Proyectos', 'Locación', 'bank'); addP(17, -49, 'Transporte', 'Pasajes', 'cash');
  addP(20, -95, 'Comida', 'Supermercado', 'bank'); addP(22, -210, 'Proyectos', 'Software', 'apple'); addP(24, 1420, 'Ingreso', 'Sueldo', 'bank', 1420); addP(27, -72, 'Mascotas', 'Veterinario', 'bank');
  return {
    version: 3,
    settings: { currency: 'USD', currency2: 'PEN', fx: 3.7, cushion: 400, variable_weekly: 180, acct_sort: 'name', first: 'Leonardo', last: 'Richarte', nick: 'Leo', gender: 'm' },
    cats: [
      { name: 'Comida', color: '#B98AE6', icon: 'bag' }, { name: 'Proyectos', color: '#EDB03E', icon: 'bolt' },
      { name: 'Alquiler', color: '#6D8BEA', icon: 'home' }, { name: 'Ocio', color: '#F08FB0', icon: 'star' },
      { name: 'Transporte', color: '#5CC8C0', icon: 'car' }, { name: 'Mascotas', color: '#FF9F0A', icon: 'heart' },
      { name: 'Otros', color: '#C9CBD1', icon: '' }
    ],
    accounts: [
      { id: 'bank', name: 'Chase Checking', type: 'checking', cur: 'USD', balance: 2840.55, color: '#6D8BEA', icon: 'bank', last4: '4417' },
      { id: 'sav', name: 'Ally Ahorros', type: 'savings', cur: 'USD', balance: 6200, apy: 4.2, color: '#22B573', icon: 'coins', last4: '9023' },
      { id: 'pen', name: 'BCP Soles', type: 'checking', cur: 'PEN', balance: 1850, color: '#EDB03E', icon: 'wallet', last4: '3308' },
      { id: 'cash', name: 'Efectivo', type: 'cash', cur: 'USD', balance: 120, color: '#8E8E93', icon: 'cash', last4: '' }
    ],
    transactions: tx,
    history: [
      { month: '2026-05', income: 2480, expense: 2210 }, { month: '2026-06', income: 2610, expense: 2395 },
      { month: '2026-07', income: 3120, expense: 2540 }, { month: '2026-08', income: 2900, expense: 2685 },
      { month: '2026-09', income: 3290, expense: 2970 }
    ],
    cards: [
      { id: 'apple', kind: 'card', name: 'Apple Card', cur: 'USD', limit: 2500, balance: 1180.4, apr: 27.99, due_day: 28, payment: 300, auto: { from: 'bank', next: dueAfter(28, iso(T)) }, color: '#1C1C1E', icon: 'card', last4: '7781' },
      { id: 'cap', kind: 'card', name: 'Capital One', cur: 'USD', limit: 3000, balance: 640, apr: 24.9, due_day: 9, payment: 150, color: '#FF453A', icon: 'card', last4: '2256' },
      { id: 'chime', kind: 'card', name: 'Chime Credit Builder', cur: 'USD', limit: 500, balance: 85, apr: 0, due_day: 22, payment: 85, color: '#22B573', icon: '', last4: '6012' },
      { id: 'loan', kind: 'loan', name: 'Préstamo de estudios', cur: 'USD', limit: 0, balance: 5400, apr: 6.8, due_day: 5, payment: 140, color: '#B98AE6', icon: 'cap', last4: '' }
    ],
    recurring: [ { name: 'Alquiler', amount: -1150, day: 1 } ],
    subs: [
      { id: 'nflx', name: 'Netflix', amount: 15.49, cur: 'USD', day: 3 },
      { id: 'icl', name: 'iCloud+', amount: 2.99, cur: 'USD', day: 5 },
      { id: 'spot', name: 'Spotify', amount: 10.99, cur: 'USD', day: 12 },
      { id: 'gym', name: 'Gimnasio', amount: 35, cur: 'USD', day: 15 },
      { id: 'claro', name: 'Plan móvil Perú', amount: 35, cur: 'PEN', day: 20 }
    ],
    savings: [
      { id: 'sf', log: [{ date: off(-3), amount: 400, from: 'bank' }, { date: off(-33), amount: 400, from: 'bank' }, { date: off(-63), amount: 400, from: 'bank' }], name: 'Fondo mudanza SF', cur: 'USD', balance: 3200, goal: 6000, monthly: 400, color: '#22B573', icon: 'plane' },
      { id: 'peru', log: [{ date: off(-8), amount: 300, from: 'pen' }, { date: off(-38), amount: 300, from: 'pen' }], name: 'Ahorro Perú', cur: 'PEN', balance: 2100, goal: 8000, monthly: 300, color: '#6D8BEA', icon: 'home' },
      { id: 'emerg', log: [{ date: off(-12), amount: 150, from: 'bank' }], name: 'Emergencias', cur: 'USD', balance: 1500, goal: 5000, monthly: 150, color: '#FF9F0A', icon: 'bolt' }
    ],
    budget: { Comida: 450, Proyectos: 400, Alquiler: 1150, Ocio: 150, Transporte: 90, Mascotas: 120, Otros: 100 },
    expected_income: [
      { id: 'pay', name: 'Sueldo', amount: 1420, acc: 'bank', date: off(5), repeat: 14 },
      { id: 'proj', name: 'Proyecto Estudio 2²', amount: 450, acc: 'bank', date: off(0), repeat: 0 },
      { id: 'lima', name: 'Pago freelance Lima', amount: 900, acc: 'pen', date: off(12), repeat: 0 }
    ],
    expected_expense: [
      { id: 'gymx', name: 'Gimnasio', amount: 35, acc: 'cap', date: off(-1), repeat: 'm', cat: 'Ocio' },
      { id: 'net', name: 'Internet', amount: 55, acc: 'bank', date: off(6), repeat: 'm', cat: 'Otros' },
      { id: 'vet', name: 'Veterinario', amount: 80, acc: 'bank', date: off(3), repeat: 0, cat: 'Mascotas' }
    ],
    planned: [
      { id: 'flight', name: 'Vuelo a SF', amount: -480, date: off(30), until: off(45), on: true, cat: 'Transporte', acc: 'bank' },
      { id: 'gift', name: 'Regalos (simulado)', amount: -300, date: off(55), on: true, cat: 'Otros', acc: 'bank' },
      { id: 'laptop', name: 'Laptop nueva', amount: -1200, date: off(20), on: false, cat: 'Proyectos', acc: 'bank' }
    ]
  };
}

const EMPTY = {
  version: 3,
  settings: { currency: 'USD', currency2: '', fx: 3.5, cushion: 0, variable_weekly: 0, first: '', last: '', nick: '', gender: 'n' },
  accounts: [ { id: 'bank', name: 'Cuenta principal', type: 'checking', cur: 'USD', balance: 0 } ],
  transactions: [], history: [], cards: [], recurring: [], subs: [], savings: [], budget: {}, budgetSets: [], expected_income: [], expected_expense: [], planned: [], jobs: []
};
const KEY = 'finanzas.v3', KEY_DIRTY = 'finanzas.dirty', KEY_SAVED = 'finanzas.lastsaved';
function lastSaved() { try { return Number(localStorage.getItem(KEY_SAVED)) || 0; } catch (e) { return 0; } }
function stampSaved() { try { localStorage.setItem(KEY_SAVED, String(Date.now())); } catch (e) { /* sin almacenamiento */ } }
function lastSavedLabel() {
  const t = lastSaved(); if (!t) return 'Última vez guardado · nunca';
  const d = new Date(t), dias = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'], meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  let h = d.getHours(); const ap = h >= 12 ? 'p. m.' : 'a. m.'; h = h % 12 || 12;
  return 'Última vez guardado · ' + dias[d.getDay()] + ' ' + d.getDate() + ' ' + meses[d.getMonth()] + ', ' + h + ':' + String(d.getMinutes()).padStart(2, '0') + ' ' + ap;
}

const DEF_CATS = [{ name: 'Comida', color: '#B98AE6' }, { name: 'Proyectos', color: '#EDB03E' }, { name: 'Alquiler', color: '#6D8BEA' }, { name: 'Ocio', color: '#F08FB0' }, { name: 'Transporte', color: '#5CC8C0' }, { name: 'Otros', color: '#C9CBD1' }];
const CAT_ORDER = DEF_CATS.map((c) => c.name);
const CAT_COLOR = { Ingreso: '#22B573' }; DEF_CATS.forEach((c) => { CAT_COLOR[c.name] = c.color; });
function syncCats() {
  CAT_ORDER.length = 0; Object.keys(CAT_COLOR).forEach((k) => { delete CAT_COLOR[k]; }); CAT_COLOR.Ingreso = '#22B573';
  data.cats.forEach((c) => { CAT_ORDER.push(c.name); CAT_COLOR[c.name] = c.color || '#C9CBD1'; });
  if (CAT_ORDER.indexOf(ui.sheetCat) < 0) ui.sheetCat = CAT_ORDER[0] || 'Otros';
}
const PAY = 'Pago de crédito', XFER = 'Transferencia', isXfer = (t) => t.category === XFER, isPay = (t) => t.category === PAY || t.category === XFER, pcat = (t) => (t.category === XFER ? XFER : PAY);
function catGlyph(n) { const c = data.cats.find((x) => x.name === n); return c && c.icon && ICONS[c.icon] ? iconSVG(c.icon, '#fff', 20) : esc(trText(n)).charAt(0); }
const CARD_COLORS = ['#B98AE6','#6D8BEA','#EDB03E','#F08FB0','#5CC8C0'];
const MON = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
const MON_FULL = ['enero','febrero','marzo','abril','mayo','junio','julio','agosto','septiembre','octubre','noviembre','diciembre'];
const DOW = ['dom','lun','mar','mié','jue','vie','sáb'];
const DOW_FULL = ['Domingo','Lunes','Martes','Miércoles','Jueves','Viernes','Sábado'];

/*__WORLD__*/
/*__RMX__*/
/*__MATX__*/
const ICON = {
  folder: RMI('folder-line', 22, '#1C1C1E'),
  save: RMI('upload-2-line', 22, '#1C1C1E'),
  chev: RMC('arrow-right-s-line', 12, 18, 1.02, '#C7C7CC', 'chev'),
  card: RMI('bank-card-line', 24, '#fff'),
  info: RMI('information-line', 22, '#1A9D63'),
  sliders: RMI('equalizer-3-line', 22, '#1A9D63')
};
const IC_BACK = RMC('arrow-left-s-line', 12, 20, 1.2, '#1C1C1E');
const IC_PEN = RMI('pencil-line', 21, '#1C1C1E');
const IC_ADD = RMI('add-circle-line', 24, '#1A9D63');

