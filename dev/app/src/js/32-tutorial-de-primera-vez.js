/* ---------- Tutorial de primera vez ----------
 * Solo se activa para quien termina la bienvenida (no con datos de demostración ni con perfiles que ya existían).
 * Muestra UN consejo a la vez, una sola vez cada uno, cuando la persona llega a esa parte. Siempre se puede omitir. */
const tourOn = () => !!(data && data.settings && data.settings.tour && data.settings.tour.on);
const tourSheetOpen = () => { const sh = document.getElementById('sheet'); return !!(sh && sh.classList.contains('show')); };
const tourFree = () => !tourSheetOpen() && !document.querySelector('.qmenu') && ui.itemId == null;
const TOUR = [
  { id: 'qmenu', auto: 1, sel: '.qmenu', ring: 0, when: () => !!document.querySelector('.qmenu'), t: 'Qué quieres añadir', x: 'Transacción es algo que ya pasó. Lo previsto (alquiler, sueldo, un pago futuro) es lo que alimenta tu proyección.' },
  { id: 'addtx', auto: 1, sel: '#sheet [data-act="submit"]', when: () => tourSheetOpen() && !!document.querySelector('#sheet [data-act="type:out"]'), t: 'Guarda aquí', x: 'Escribe el monto, elige gasto o ingreso y la categoría, y toca el check verde para guardar.' },
  { id: 'start', sel: '.tab[data-act="tab:deuda"]', when: () => ui.tab === 'resumen' && tourFree(), t: 'Empieza por Cuentas', x: 'Ahí pones tu saldo real, agregas tarjetas y puedes importar tus estados de cuenta.' },
  { id: 'plus', sel: '#plusbtn', when: () => ui.tab === 'resumen' && tourFree(), t: 'Añade desde aquí', x: 'Con el + registras un movimiento, algo previsto, una transferencia o tu trabajo.' },
  { id: 'deuda', auto: 1, sel: '', when: () => ui.tab === 'deuda' && tourFree(), t: 'Tus cuentas', x: 'Ajusta tu saldo real y añade tus cuentas, tarjetas y préstamos para que Plata cuadre tu mes.' },
  { id: 'presu', auto: 1, sel: '', when: () => ui.tab === 'presupuesto' && tourFree(), t: 'Presupuesto', x: 'Pon un tope por categoría y mira cuánto llevas gastado este mes.' },
  { id: 'proy', auto: 1, sel: '', when: () => ui.tab === 'proyeccion' && tourFree(), t: 'Proyección', x: 'Con lo que tienes previsto, aquí ves cómo irá tu saldo en las próximas semanas.' },
  { id: 'imp', sel: '#s-resumen [data-act="imp:start"]', ring: 1, when: () => ui.tab === 'resumen' && tourFree() && !!data.settings.tour.seen.plus, t: 'Importa en vez de escribir', x: 'Sube el PDF o CSV de tu banco y Plata lee los movimientos en tu dispositivo. Nada sale de aquí.' },
  { id: 'gear', sel: '#gearbtn', when: () => ui.tab === 'resumen' && tourFree() && !!(data.settings.tour.seen.plus), t: 'Ajustes', x: 'Perfil, idioma, tema y respaldo de tus datos. Aquí también puedes repetir este tutorial.' }
];
let tourCur = '', tourSig = '';
function tourClear() { document.querySelectorAll('.tourring,.tourtip,.tourdim').forEach((n) => n.remove()); tourCur = ''; tourSig = ''; }
function tourSeen(id) { if (!tourOn()) return; data.settings.tour.seen[id] = 1; persist(); tourClear(); setTimeout(tourTick, 250); }
function tourEnd() { if (data && data.settings) { data.settings.tour = { on: false, seen: (data.settings.tour && data.settings.tour.seen) || {} }; persist(); } tourClear(); if (ui.tab === 'cuenta') { try { renderCuenta(); } catch (e) { /* sin ajustes */ } } }
function tourTick() {
  const dev = document.getElementById('device'), root = document.documentElement;
  const blocked = !tourOn() || !dev || data.demo || ui.w || document.getElementById('welcome') || document.getElementById('splash') || document.querySelector('.alertback.in') || document.hidden || /lk90|lk270/.test(root.className);
  if (blocked) { if (tourCur) tourClear(); return; }
  const seen = data.settings.tour.seen || {};
  let tip = null, el = null;
  for (const c of TOUR) {
    if ((seen[c.id] && c.id !== tourCur) || !c.when()) continue;
    if (c.sel) { el = document.querySelector(c.sel); const r = el && el.getBoundingClientRect(); if (!r || r.width < 8 || r.height < 8 || getComputedStyle(el).visibility === 'hidden') { if (c.opt) el = null; else continue; } } else el = null;
    tip = c; break;
  }
  if (!tip) { if (tourCur) tourClear(); return; }
  const d = dev.getBoundingClientRect(), k = d.width / (dev.offsetWidth || d.width) || 1, W = dev.offsetWidth, H = dev.offsetHeight;
  const r = el ? el.getBoundingClientRect() : null;
  const box = r ? { x: (r.left - d.left) / k, y: (r.top - d.top) / k, w: r.width / k, h: r.height / k } : null;
  const sig = tip.id + '|' + (box ? [box.x, box.y, box.w, box.h].map(Math.round).join(',') : '') + '|' + W + 'x' + H;
  if (sig === tourSig) return;
  tourClear(); tourCur = tip.id; tourSig = sig;
  if (tip.auto && !seen[tip.id]) { seen[tip.id] = 1; persist(); }
  if (tip.sel !== '.qmenu') { const m = document.createElement('div'); if (box && tip.ring !== 0) { m.className = 'tourdim hole'; m.style.cssText = 'left:' + (box.x - 3) + 'px;top:' + (box.y - 3) + 'px;width:' + (box.w + 6) + 'px;height:' + (box.h + 6) + 'px;border-radius:' + Math.min(22, (box.h + 6) / 2 + 4) + 'px'; } else m.className = 'tourdim'; dev.appendChild(m); }
  if (box && tip.ring !== 0) { const g = document.createElement('div'); g.className = 'tourring'; const pad = 3; g.style.cssText = 'left:' + (box.x - pad) + 'px;top:' + (box.y - pad) + 'px;width:' + (box.w + pad * 2) + 'px;height:' + (box.h + pad * 2) + 'px;border-radius:' + Math.min(22, (box.h + pad * 2) / 2 + 4) + 'px'; dev.appendChild(g); }
  const b = document.createElement('div'); b.className = 'tourtip'; b.setAttribute('role', 'status');
  b.innerHTML = '<b>' + tip.t + '</b>' + tip.x + '<div class="tr"><button class="tskip" data-tour="skip">Omitir tutorial</button><button class="tok" data-tour="ok">Entendido</button></div>';
  dev.appendChild(b);
  const bw = b.offsetWidth, bh = b.offsetHeight;
  let left, top;
  if (box) { left = Math.max(14, Math.min(W - bw - 14, box.x + box.w / 2 - bw / 2)); top = box.y + box.h / 2 > H / 2 ? box.y - bh - 16 : box.y + box.h + 16; if (tip.sel === '.qmenu') top = Math.max(70, box.y - bh - 14); }
  else { left = (W - bw) / 2; top = H - bh - 110; }
  b.style.left = left + 'px'; b.style.top = Math.max(60, Math.min(H - bh - 12, top)) + 'px';
}
document.addEventListener('click', (e) => {
  const t = e.target.closest && e.target.closest('[data-tour]');
  if (t) { e.stopPropagation(); if (t.dataset.tour === 'skip') tourEnd(); else tourSeen(tourCur); return; }
  if (!tourCur || !tourOn()) return;
  const c = TOUR.find((x) => x.id === tourCur); if (c && c.sel && c.ring !== 0 && e.target.closest && e.target.closest(c.sel)) tourSeen(c.id);
  else setTimeout(tourTick, 350);
}, true);
setInterval(tourTick, 800);

