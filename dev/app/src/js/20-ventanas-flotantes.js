/* ---------- Ventanas flotantes (escritorio): mover, cerrar, traer al frente ---------- */
(function () {
  const root = document.documentElement, isWeb = () => root.classList.contains('web');
  let zTop = 100, D = null;
  const dw = () => document.getElementById('s-cuenta'), sw = () => document.getElementById('sheet');
  const dOn = () => { const d = dw(); return !!(d && d.classList.contains('active')); };
  const sOn = () => { const s = sw(); return !!(s && s.classList.contains('show')); };
  function layout() {
    if (!isWeb()) return;
    const d = dw(), s = sw(); if (!d || !s) return;
    if (!dOn()) { delete d.dataset.moved; d.style.left = ''; d.style.top = ''; }
    if (!sOn()) { delete s.dataset.moved; s.style.left = ''; s.style.top = ''; }
    const both = dOn() && sOn();
    if (d.dataset.moved !== '1') d.style.left = both ? 'calc(50% - 250px)' : '';
    if (s.dataset.moved !== '1') s.style.left = both ? 'calc(50% + 250px)' : '';
  }
  function nest() {
    const d = dw(); if (!d) return;
    const n = (ui.txId != null && ui.txBack && ui.txBack.month) || (ui.itemId != null && (ui.itemKind === 'credits' || ui.itemKind === 'transp' || ui.itemKind === 'profile' || ui.itemKind === 'imp'));
    d.setAttribute('data-nest', n ? '1' : '0');
  }
  function bar() {
    const d = dw(); if (!d || (d.firstElementChild && d.firstElementChild.classList.contains('wbar'))) return;
    const b = document.createElement('div'); b.className = 'wbar';
    b.innerHTML = '<span class="wgrip"></span><button class="wx" data-act="wclose" aria-label="Cerrar">' + XSVG + '</button>';
    d.insertBefore(b, d.firstChild);
  }
  window.winClose = function () {
    ui.txId = null; ui.txDel = false; ui.itemId = null; ui.itemDel = false;
    if (typeof leaveSettings === 'function') leaveSettings();
    setTab(ui.prevTab && ui.prevTab !== 'cuenta' ? ui.prevTab : 'resumen');
  };
  function init() {
    const d = dw(), s = sw(); if (!d || !s) return;
    new MutationObserver(() => { if (!isWeb()) return; bar(); nest(); }).observe(d, { childList: true });
    new MutationObserver(layout).observe(d, { attributes: true, attributeFilter: ['class'] });
    new MutationObserver(layout).observe(s, { attributes: true, attributeFilter: ['class'] });
    bar(); nest();
  }
  document.addEventListener('pointerdown', (e) => {
    if (!isWeb() || e.button) return;
    const w = e.target.closest && e.target.closest('#s-cuenta,#sheet'); if (!w) return;
    w.style.zIndex = ++zTop;
    const topStrip = w.id === 'sheet' && e.target === w && e.clientY - w.getBoundingClientRect().top < 30;
    if (!(e.target.closest('.wbar,.shead') || topStrip) || e.target.closest('button,input,select,textarea,label,a,[data-act]')) return;
    const r = w.getBoundingClientRect();
    D = { w: w, x: e.clientX, y: e.clientY, ox: r.left + r.width / 2, oy: r.top + r.height / 2, rw: r.width, rh: r.height, on: false, pid: e.pointerId };
  });
  document.addEventListener('pointermove', (e) => {
    if (!D) return; const dx = e.clientX - D.x, dy = e.clientY - D.y;
    if (!D.on) { if (Math.abs(dx) + Math.abs(dy) < 8) return; D.on = true; D.w.classList.add('wdrag'); D.w.dataset.moved = '1'; try { D.w.setPointerCapture(D.pid); } catch (x) { /* sin captura */ } }
    const x = Math.max(80 - D.rw / 2, Math.min(innerWidth - 80 + D.rw / 2, D.ox + dx)), y = Math.max(D.rh / 2, Math.min(innerHeight - 40 + D.rh / 2, D.oy + dy));
    D.w.style.left = x + 'px'; D.w.style.top = y + 'px';
  });
  const end = () => { if (!D) return; const g = D; D = null; g.w.classList.remove('wdrag'); };
  document.addEventListener('pointerup', end); document.addEventListener('pointercancel', end);
  document.addEventListener('keydown', (e) => {
    if (!isWeb() || e.key !== 'Escape') return;
    if (document.querySelector('.alertback')) return;
    const d = dw(), s = sw(), a = dOn(), b = sOn(); if (!a && !b) return;
    const topS = b && (!a || (Number(s.style.zIndex) || 90) >= (Number(d.style.zIndex) || 80));
    if (topS) closeSheet(); else window.winClose();
  });
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init();
  window.addEventListener('plata:render', nest);
})();
