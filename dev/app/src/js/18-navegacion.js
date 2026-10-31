/* ---------- Navegación ---------- */
const TAB_ORDER = ['resumen', 'presupuesto', 'proyeccion', 'deuda', 'ahorro', 'movimientos', 'cuenta'];
function webFocus(t) {
  const e = $('#s-' + t); if (!e) return;
  const m = document.querySelector('main');
  if (m) { const top = t === 'resumen' ? 0 : e.offsetTop - 12, h = m.clientHeight; if (t === 'resumen' ? m.scrollTop > 0 : (e.offsetTop < m.scrollTop || e.offsetTop + e.offsetHeight > m.scrollTop + h)) m.scrollTo({ top: Math.max(0, top), behavior: 'smooth' }); }
  e.classList.remove('wflash'); void e.offsetWidth; e.classList.add('wflash');
  clearTimeout(e._wf); e._wf = setTimeout(() => e.classList.remove('wflash'), 1500);
}
function setTab(t) {
  if (document.getElementById('impnav')) { const n = document.getElementById('impnav'); n.remove(); }
  if (document.documentElement.classList.contains('web') && t !== 'cuenta' && ui.tab !== 'cuenta' && TAB_ORDER.indexOf(t) >= 0) { ui.tab = t; document.documentElement.setAttribute('data-tab', t); webFocus(t); return; }
  const prevT = ui.tab, mode = t === prevT ? 'tab' : t === 'cuenta' ? 'push' : prevT === 'cuenta' ? 'pop' : 'tab';
  ui.tab = t;
  clearTimeout(setTab._lt);
  TAB_ORDER.forEach((k) => { const e = $('#s-' + k); e.classList.remove('leaving', 'l-push', 'l-pop', 'nav-tab', 'nav-push', 'nav-pop'); });
  TAB_ORDER.forEach((k) => {
    const e = $('#s-' + k), on = k === t;
    e.classList.toggle('active', on);
    if (on) { void e.offsetWidth; if (mode !== 'tab') e.classList.add('nav-' + mode); }
    else if (k === prevT && prevT !== t && mode !== 'tab') e.classList.add('leaving', 'l-' + mode);
  });
  if (mode !== 'tab') setTab._lt = setTimeout(() => { TAB_ORDER.forEach((k) => $('#s-' + k).classList.remove('leaving', 'l-push', 'l-pop')); }, 460);
  $('#s-' + t).scrollTop = 0;
  const hl = t === 'movimientos' ? 'resumen' : t === 'cuenta' ? (['resumen', 'presupuesto', 'proyeccion', 'ahorro', 'deuda'].indexOf(ui.prevTab) >= 0 ? ui.prevTab : 'deuda') : t === 'ahorro' ? (document.documentElement.classList.contains('android') ? 'ahorro' : 'proyeccion') : t;
  document.documentElement.setAttribute('data-tab', t);
  document.querySelectorAll('.tab').forEach((b) => b.classList.toggle('on', b.getAttribute('data-act') === 'tab:' + hl));
  if (typeof setMini === 'function') setMini(false);
  if (typeof movePill === 'function') movePill();
}

function flashOver(el) { el.classList.remove('overflash'); void el.offsetWidth; el.classList.add('overflash'); setTimeout(() => el.classList.remove('overflash'), 900); }
document.addEventListener('focusin', (e) => { const el = e.target; if (el && el.tagName === 'INPUT' && el.getAttribute('inputmode') === 'decimal') el.dataset.prev = el.value; }, true);
document.addEventListener('input', (e) => {
  const el = e.target; if (!el || el.tagName !== 'INPUT' || el.getAttribute('inputmode') !== 'decimal') return;
  const v = parseFloat(String(el.value).replace(',', '.'));
  if (Math.abs(v) > MAXAMT) { e.stopImmediatePropagation(); el.value = el.dataset.prev || ''; flashOver(el); toast('No hay forma de que tengas tanto dinero, y si lo tienes, felicidades.'); return; }
  el.dataset.prev = el.value;
}, true);
let toastTimer = 0;
function toast(msg, top) {
  const t = $('#toast');
  t.classList.toggle('top', !!top || $('#sheet').classList.contains('show')); t.textContent = msg; t.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove('show'), 2200);
}

