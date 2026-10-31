/* ---------- Lente Liquid Glass: resorte, lente al presionar, arrastre y reflejo ---------- */
const tabbar = $('#tabbar'), tabsEl = $('#tabs'), barbg = $('#barbg'), pill = $('#pill');
const reduce = !!(window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches);
const P = { x: 0, w: 0, vx: 0, vw: 0, tx: 0, tw: 0, s: 1, vs: 0, ts: 1, raf: 0, last: 0, bubble: false, drag: false, on: false };
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const tabX = (el) => el.offsetLeft + tabsEl.offsetLeft;
function pillGeom(el) {
  const base = el.offsetWidth; let tw = 0;
  try {
    const k = tabbar.getBoundingClientRect().width / (tabbar.offsetWidth || 1) || 1, rg = document.createRange();
    const tn = [].slice.call(el.childNodes).filter((n) => n.nodeType === 3 && n.textContent.trim()).pop() || el.lastChild;
    if (tn) { rg.selectNodeContents(tn); tw = rg.getBoundingClientRect().width / k; }
  } catch (e) { tw = 0; }
  const cx = tabX(el) + base / 2, w = Math.min(Math.max(base + 17, Math.ceil(tw + 22)), tabbar.clientWidth - 10, 2 * (cx - 5), 2 * (tabbar.clientWidth - 5 - cx));
  return { w: w, x: cx - w / 2 };
}
let tabEls = null;
window.__retint = function () { if (typeof tabEls !== 'undefined' && tabEls) tint(); };
function tint() {
  if (!tabEls) tabEls = [].slice.call(tabbar.querySelectorAll('.tab'));
  const l = P.x, r = P.x + P.w;
  tabEls.forEach((t) => {
    const cx = tabX(t) + (t.offsetWidth || 1) / 2, on = cx > l && cx < r;
    t.style.color = on ? '#1A9D63' : (document.documentElement.dataset.theme === 'dark' ? '#F2F2F7' : '#111');
  });
}
function draw() {
  if (P.w > 0) tint();
  const st = 1 + Math.min(0.12, Math.abs(P.vx) / 5000);
  const sx = P.s * st, sy = P.s / (1 + (st - 1) * 0.5);
  pill.style.width = P.w + 'px';
  pill.style.transform = 'translate3d(' + P.x.toFixed(2) + 'px,0,0) scale(' + sx.toFixed(3) + ',' + sy.toFixed(3) + ') skewX(' + clamp(-P.vx / 90, -5, 5).toFixed(2) + 'deg)';
}
function kick() { if (!P.raf) { P.last = performance.now(); P.raf = requestAnimationFrame(step); } }
function step(t) {
  const dt = Math.min(0.032, (t - P.last) / 1000); P.last = t;
  const sp = (k, c, key, vkey, target) => { const a = k * (target - P[key]) - c * P[vkey]; P[vkey] += a * dt; P[key] += P[vkey] * dt; };
  sp(320, 26, 'x', 'vx', P.tx); sp(320, 26, 'w', 'vw', P.tw); sp(240, 17, 's', 'vs', P.ts);
  draw();
  const done = Math.abs(P.tx - P.x) < 0.2 && Math.abs(P.tw - P.w) < 0.2 && Math.abs(P.ts - P.s) < 0.002 && Math.abs(P.vx) < 2 && Math.abs(P.vw) < 2 && Math.abs(P.vs) < 0.05;
  if (done && !P.drag) { P.x = P.tx; P.w = P.tw; P.s = P.ts; P.vx = P.vw = P.vs = 0; draw(); P.raf = 0; return; }
  P.raf = requestAnimationFrame(step);
}
function movePill(jump) {
  const el = tabbar.querySelector('.tab.on'); if (!el) return;
  if (!P.drag) { const g = pillGeom(el); P.tx = g.x; P.tw = g.w; }
  if (jump || reduce || P.w === 0) { P.x = P.tx; P.w = P.tw; P.vx = P.vw = 0; draw(); } else kick();
}
function setLight(clientX) {
  const r = tabbar.getBoundingClientRect();
  tabbar.style.setProperty('--lx', clamp(((clientX - r.left) / r.width) * 100, 0, 100).toFixed(1) + '%');
}
let gyro = false;
function onTilt(e) { if (e.gamma != null) tabbar.style.setProperty('--lx', ((0.5 + clamp(e.gamma, -30, 30) / 60) * 100).toFixed(1) + '%'); }
function askGyro() {
  if (gyro || !window.DeviceOrientationEvent) return; gyro = true;
  try {
    if (typeof DeviceOrientationEvent.requestPermission === 'function') {
      DeviceOrientationEvent.requestPermission().then((r) => { if (r === 'granted') window.addEventListener('deviceorientation', onTilt); }).catch(() => {});
    } else window.addEventListener('deviceorientation', onTilt);
  } catch (e) { /* sin giroscopio */ }
}
let holdT = 0, startX = 0, suppress = false;
let heldT = 0;
tabbar.addEventListener('pointerdown', (e) => {
  askGyro(); setLight(e.clientX);
  clearTimeout(heldT); heldT = setTimeout(() => tabbar.classList.add('held'), 90);
  const t = e.target.closest('.tab'); if (!t) return;
  startX = e.clientX;
  if (t.classList.contains('on') && !reduce) {
    holdT = setTimeout(() => {
      P.bubble = true; P.drag = true; P.ts = 1.16; tabbar.classList.add('pressing');
      try { tabbar.setPointerCapture(e.pointerId); } catch (err) { /* sin captura */ }
      if (navigator.vibrate) navigator.vibrate(8);
      kick();
    }, 90);
  }
});
tabbar.addEventListener('pointermove', (e) => {
  setLight(e.clientX);
  if (!P.bubble) return;
  const r = tabbar.getBoundingClientRect(), k = r.width / tabbar.offsetWidth;
  const px = (e.clientX - r.left) / k; let bt = null, bd2 = 1e9;
  tabbar.querySelectorAll('.tab').forEach((t) => { const d = Math.abs(tabX(t) + t.offsetWidth / 2 - px); if (d < bd2) { bd2 = d; bt = t; } });
  if (bt) P.tw = pillGeom(bt).w;
  P.tx = clamp(px - P.tw / 2, 2, tabbar.clientWidth - P.tw - 2);
  kick();
});
function endPress() {
  clearTimeout(holdT);
  if (!P.bubble) return;
  const c = P.tx + P.tw / 2, tabs = Array.prototype.slice.call(tabbar.querySelectorAll('.tab'));
  let best = tabs[0], bd = 1e9;
  tabs.forEach((t) => { const d = Math.abs(tabX(t) + t.offsetWidth / 2 - c); if (d < bd) { bd = d; best = t; } });
  P.bubble = false; P.drag = false; P.ts = 1; tabbar.classList.remove('pressing');
  suppress = true; setTimeout(() => { suppress = false; }, 0);
  setTab(best.getAttribute('data-act').split(':')[1]);
  kick();
}
function release() { clearTimeout(heldT); tabbar.classList.remove('held'); endPress(); }
tabbar.addEventListener('pointerup', release);
tabbar.addEventListener('pointercancel', release);
tabbar.addEventListener('pointerleave', () => { if (!P.bubble) { clearTimeout(heldT); clearTimeout(holdT); tabbar.classList.remove('held'); } });
tabbar.addEventListener('click', (e) => { if (suppress) { e.stopPropagation(); e.preventDefault(); } }, true);
window.addEventListener('resize', () => movePill(true));

/* Minimizar la barra al bajar y restaurarla al subir (como Instagram) */
if (document.documentElement.classList.contains('android')) (function () {
  const tabs = $('#tabs');
  if (tabs) {
    const P = (k) => (MATX[k] || RMX[k]).d, sv = (c) => '<svg class="ic ' + c + '" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="' + P(c === 'fill' ? 'seedling-fill' : 'seedling-line') + '"/></svg>';
    [['resumen', 'pie-chart'], ['presupuesto', 'wallet-3'], ['proyeccion', 'line-chart'], ['deuda', 'bank-card']].forEach((t) => { const b = tabs.querySelector('[data-act="tab:' + t[0] + '"]'); if (!b) return; ['line', 'fill'].forEach((c) => { const p = b.querySelector('svg.' + c + ' path'); if (p) p.setAttribute('d', P(t[1] + '-' + c)); }); });
    const b = document.createElement('button'); b.className = 'tab tab-sv'; b.setAttribute('data-act', 'tab:ahorro'); b.setAttribute('aria-label', 'Ahorro'); b.innerHTML = sv('line') + sv('fill') + 'Ahorro';
    const cu = tabs.querySelector('[data-act="tab:deuda"]'); /* mismo orden que en iOS: Ahorro va antes de Cuentas */
    if (cu) tabs.insertBefore(b, cu); else tabs.appendChild(b);
  }
  const g = $('#gearbtn'), gs = g && g.querySelector('svg');
  if (gs) gs.innerHTML = '<path d="M3 17v2h6v-2H3zM3 5v2h10V5H3zm10 16v-2h8v-2h-8v-2h-2v6h2zM7 9v2H3v2h4v2h2V9H7zm14 4v-2H11v2h10zm-6-4h2V7h4V5h-4V3h-2v6z"/>';
})();
function setMini(on) { tabbar.classList.toggle('compact', on); const pb = $('#plusbtn'); if (pb) pb.classList.toggle('compact', on); }
document.querySelectorAll('.screen').forEach((sc) => {
  let last = 0, acc = 0;
  sc.addEventListener('scroll', () => {
    const y = sc.scrollTop, dy = y - last; last = y;
    if (y < 24) { acc = 0; setMini(false); return; }
    if ((dy > 0) !== (acc > 0)) acc = 0;
    acc += dy;
    if (acc > 14) setMini(true); else if (acc < -10) setMini(false);
  }, { passive: true });
});
if (typeof ResizeObserver === 'function') new ResizeObserver(() => { if (!P.drag) movePill(true); if (typeof placeGhost === 'function') placeGhost(); }).observe(tabbar);


