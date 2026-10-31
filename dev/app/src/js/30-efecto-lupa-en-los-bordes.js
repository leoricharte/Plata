/* ---------- Efecto lupa en los bordes (sin filtros SVG, funciona en Safari) ----------
   Cada borde de la barra se divide en dos franjas con copias del contenido de atrás: la exterior invertida
   y la interior ampliada, empalmadas para que no haya saltos. */
const deviceEl = $('#device');
const LENS = [{ cls: 'edge', o: 0, s: 1.28 }, { cls: 'core', o: 0, s: 1.14 }];
function makeRefract(host) {
  const refract = host.querySelector('.refract'), layers = [];
  LENS.forEach((ln) => {
    const el = document.createElement('div'), gh = document.createElement('div');
    el.className = 'lz ' + ln.cls; gh.className = 'ghost'; el.appendChild(gh); refract.appendChild(el);
    layers.push({ ln: ln, el: el, gh: gh });
  });
  return { host: host, layers: layers };
}
const lensHosts = [makeRefract(tabbar)];
function placeGhost() {
  const sc = document.querySelector('.screen.active'), st = sc ? sc.scrollTop : 0, gw = deviceEl.clientWidth + 'px';
  lensHosts.forEach((h) => {
    const L = h.host.offsetLeft, T = h.host.offsetTop, W = h.host.offsetWidth, H = h.host.offsetHeight;
    h.layers.forEach((ly) => {
      const o = ly.ln.o, s = ly.ln.s, cx = W / 2 - o, cy = H / 2 - o;
      ly.gh.style.width = gw;
      ly.gh.style.transform = 'translate3d(' + (cx * (1 - s) - s * (L + o)).toFixed(2) + 'px,' + (cy * (1 - s) - s * (st + T + o)).toFixed(2) + 'px,0) scale(' + s + ')';
    });
  });
}
let ghostRaf = 0;
function syncGhost() {
  if (ghostRaf) return;
  ghostRaf = requestAnimationFrame(() => {
    ghostRaf = 0;
    const sc = document.querySelector('.screen.active');
    if (sc) { const html = sc.innerHTML.replace(/ id="[^"]*"/g, '').replace(/ data-act="[^"]*"/g, ''); lensHosts.forEach((h) => h.layers.forEach((ly) => { ly.gh.innerHTML = html; })); }
    placeGhost();
  });
}
if (typeof MutationObserver === 'function') new MutationObserver(syncGhost).observe($('main'), { subtree: true, childList: true, characterData: true, attributes: true });
document.querySelectorAll('.screen').forEach((sc) => sc.addEventListener('scroll', placeGhost, { passive: true }));
function syncTA() { const sc = document.querySelector('.screen.active'), st = sc ? sc.scrollTop : 0; deviceEl.style.setProperty('--ta', String(Math.max(0, Math.min(1, st / 48)))); }
document.querySelectorAll('.screen').forEach((sc) => sc.addEventListener('scroll', syncTA, { passive: true }));
new MutationObserver(syncTA).observe(document.querySelector('.screens') || deviceEl, { subtree: true, attributes: true, attributeFilter: ['class'] }); syncTA();
window.addEventListener('resize', syncGhost);
syncGhost();

