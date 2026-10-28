/* Puente web ⇄ nativo de Plata para iOS.
 * Lo inyecta Swift (WKUserScript) al inicio de cada carga. La app web NO se modifica: este archivo solo
 *  1. oculta (visibility:hidden) la barra, el botón + y el engranaje dibujados por la web, sin quitarlos del DOM,
 *     para que el CSS de la app siga decidiendo cuándo se ven;
 *  2. le cuenta a Swift dónde están, cuán visibles son y qué dicen, para que la barra de vidrio nativa los siga;
 *  3. deja a Swift "tocar" esos mismos botones (window.__plataGo);
 *  4. espeja a un archivo nativo los datos de localStorage (finanzas.* y plata.*), por si iOS vacía el almacenamiento web.
 * Solo habla con el manejador "plata"; no abre ninguna conexión. */
(function () {
  'use strict';
  if (window.__plataNative) return;
  window.__plataNative = true;

  var root = document.documentElement;
  var H = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.plata;
  function post(m) { try { H.postMessage(m); } catch (e) { /* sin puente */ } }

  /* 1. Ocultar los controles web (siguen ocupando su sitio y siguen aplicando su CSS) */
  root.setAttribute('data-native', '1');
  var st = document.createElement('style');
  st.textContent = 'html[data-native]:not(.web) #tabbar,html[data-native]:not(.web) #gearbtn,html[data-native]:not(.web) #plusbtn,html[data-native]:not(.web) .plata-nbtn{visibility:hidden!important}html[data-native]:not(.web) #qmenu{visibility:hidden!important}html[data-native] *{-webkit-user-select:none;user-select:none;-webkit-touch-callout:none;-webkit-tap-highlight-color:transparent}html[data-native] input,html[data-native] textarea,html[data-native] [contenteditable]{-webkit-user-select:text;user-select:text}';
  root.appendChild(st);

  /* 2. Estado hacia Swift */
  function r1(n) { return Math.round(n * 10) / 10; }
  /* ¿Hay otra cosa encima del centro del control? (bienvenida, tutorial, pantallas de nube...: la web las pone encima por z-index,
     no apaga la barra). Se hace visible un instante, sin pintar, porque la pregunta ignora lo que tiene visibility:hidden. */
  function covered(e, r) {
    if (!(r.width > 1 && r.height > 1)) return false;
    var prev = e.style.getPropertyValue('visibility'), pr = e.style.getPropertyPriority('visibility'), hit = null;
    e.style.setProperty('visibility', 'visible', 'important');
    try { hit = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2); } catch (x) { /* sin hit-test */ }
    if (prev) e.style.setProperty('visibility', prev, pr); else e.style.removeProperty('visibility');
    return !!hit && hit !== e && !e.contains(hit);
  }
  function boxEl(e) {
    if (!e) return { x: 0, y: 0, w: 0, h: 0, o: 0 };
    var cs = getComputedStyle(e), r = e.getBoundingClientRect();
    var o = cs.display === 'none' ? 0 : parseFloat(cs.opacity);
    if (o > 0 && covered(e, r)) o = 0;
    return { x: r1(r.left), y: r1(r.top), w: r1(r.width), h: r1(r.height), o: isNaN(o) ? 0 : r1(o) };
  }
  function box(id) { return boxEl(document.getElementById(id)); }

  /* Botones que pasan a ser nativos: lista blanca (los banners y las filas de listas quedan fuera a propósito).
     Cada uno se oculta en la web (visibility) y Swift dibuja su vidrio encima; al tocarlo, Swift hace click() en el original. */
  var KINDS = [
    ['.welcome .primary', 'prominent'], ['#sheet .primary', 'prominent'],
    ['.welcome .wcloud', 'glass'], ['.welcome .clb', 'glass'],
    ['.welcome .wdotbtn', 'icon'], ['.welcome .back', 'icon'], ['.welcome .wdown', 'icon'],
    ['#sheet .xbtn', 'icon'], ['#sheet .okbtn', 'icon'],
    ['[role="switch"]', 'switch'], ['input[type="range"]', 'slider']
  ];
  var nid = 0, tracked = [], scrollingUntil = 0;
  /* Menú del «+»: la web lo abre como #qmenu (posición fija). Se informa su rectángulo final (sin la animación) y sus filas. */
  function menu() {
    var m = document.getElementById('qmenu');
    if (!m || m.classList.contains('out')) return null;
    var w = m.offsetWidth, h = m.offsetHeight, x = parseFloat(m.style.left) || 0, y;
    if (m.style.top) y = parseFloat(m.style.top) || 0; else y = window.innerHeight - (parseFloat(m.style.bottom) || 0) - h;
    var items = [], ch = m.children;
    for (var i = 0; i < ch.length; i++) {
      var c = ch[i];
      if (c.classList.contains('qsep')) { items.push({ sep: true }); continue; }
      if (!c.hasAttribute('data-nid')) c.setAttribute('data-nid', String(++nid));
      var b = c.querySelector('b'), em = c.querySelector('em');
      items.push({ id: +c.getAttribute('data-nid'), act: c.getAttribute('data-act') || '', title: b ? b.textContent : '', sub: em ? em.textContent : '' });
    }
    return { x: r1(x), y: r1(y), w: r1(w), h: r1(h), vh: window.innerHeight, up: m.classList.contains('up'), items: items };
  }
  /* Dentro de algo que se desplaza, el vidrio nativo iría un cuadro atrasado: ese botón se queda como web */
  function scrolls(e) {
    for (var p = e.parentElement; p && p !== document.body; p = p.parentElement) {
      var oy = getComputedStyle(p).overflowY;
      if ((oy === 'auto' || oy === 'scroll') && p.scrollHeight > p.clientHeight + 1) return true;
    }
    return false;
  }
  function buttons() {
    var out = [], now = [];
    for (var i = 0; i < KINDS.length && out.length < 12; i++) {
      var list = document.querySelectorAll(KINDS[i][0]);
      for (var j = 0; j < list.length && out.length < 12; j++) {
        var e = list[j];
        if (now.indexOf(e) >= 0) continue;
        var r = e.getBoundingClientRect();
        if (!(r.width > 1 && r.height > 1)) continue;
        if (r.bottom < 0 || r.top > window.innerHeight || r.right < 0 || r.left > window.innerWidth) continue;
        if (scrolls(e) && performance.now() < scrollingUntil) continue;
        if (!e.hasAttribute('data-nid')) e.setAttribute('data-nid', String(++nid));
        e.classList.add('plata-nbtn'); now.push(e);
        var b = boxEl(e);
        out.push({ id: +e.getAttribute('data-nid'), kind: KINDS[i][1], act: (e.getAttribute('data-act') || '').split(':')[0],
          label: (e.textContent || '').replace(/\s+/g, ' ').trim() || e.getAttribute('aria-label') || '',
          chk: e.getAttribute('aria-checked') === 'true', dis: e.classList.contains('dis') || e.disabled === true,
          val: e.type === 'range' ? (parseFloat(e.value) || 0) : 0, min: e.type === 'range' ? (parseFloat(e.min) || 0) : 0, max: e.type === 'range' ? (parseFloat(e.max) || 1) : 1,
          x: b.x, y: b.y, w: b.w, h: b.h, o: b.o });
      }
    }
    tracked.forEach(function (e) { if (now.indexOf(e) < 0) e.classList.remove('plata-nbtn'); });
    tracked = now;
    return out;
  }
  function lbl(id) { var e = document.getElementById(id); return e ? (e.getAttribute('aria-label') || '') : ''; }
  var last = '', raf = 0, until = 0;
  function sample() {
    var labels = {}, on = '';
    var tabs = document.querySelectorAll('#tabs .tab');
    for (var i = 0; i < tabs.length; i++) {
      var k = (tabs[i].getAttribute('data-act') || '').split(':')[1];
      if (!k) continue;
      labels[k] = (tabs[i].textContent || '').trim() || tabs[i].getAttribute('aria-label') || k;
      if (tabs[i].classList.contains('on')) on = k;
    }
    var bar = document.getElementById('tabbar'), gd = document.querySelector('.gdot');
    var m = {
      t: 'state',
      bar: box('tabbar'), plus: box('plusbtn'), gear: box('gearbtn'), btns: buttons(), menu: menu(),
      compact: !!(bar && bar.classList.contains('compact')),
      gdot: gd ? (gd.classList.contains('gone') ? 2 : (gd.classList.contains('dirty') ? 1 : 0)) : 0,
      on: on, tab: root.getAttribute('data-tab') || '', labels: labels, plusLabel: lbl('plusbtn'), gearLabel: lbl('gearbtn'),
      theme: root.getAttribute('data-theme') || ''
    };
    var s = JSON.stringify(m);
    if (s !== last) { last = s; post(m); }
  }
  /* Mientras algo se anima (transición CSS), se muestrea en cada cuadro; en reposo no hace nada */
  function pump() { raf = 0; sample(); if (performance.now() < until) raf = requestAnimationFrame(pump); }
  function kick(ms) { until = Math.max(until, performance.now() + (ms || 700)); if (!raf) raf = requestAnimationFrame(pump); }
  try {
    new MutationObserver(function () { kick(700); }).observe(root, { childList: true, attributes: true, subtree: true, attributeFilter: ['class', 'style', 'data-tab', 'data-theme', 'data-cdet'] });
  } catch (e) { /* sin observador */ }
  ['transitionrun', 'transitionstart', 'transitionend', 'animationstart'].forEach(function (n) { document.addEventListener(n, function () { kick(700); }, true); });
  window.addEventListener('resize', function () { kick(700); });
  document.addEventListener('scroll', function () { scrollingUntil = performance.now() + 180; kick(500); }, true);
  window.addEventListener('orientationchange', function () { kick(700); });
  document.addEventListener('DOMContentLoaded', function () { kick(2500); });
  window.addEventListener('load', function () { kick(2500); });

  /* 3. Swift toca un control de la web (el selector lo escribe Swift, nunca viene de datos del usuario) */
  window.__plataGo = function (sel) {
    var e = document.querySelector(sel);
    if (!e) return;
    if (e.classList && e.classList.contains('switch')) {
      ['pointerdown', 'pointerup'].forEach(function (n) { e.dispatchEvent(new PointerEvent(n, { bubbles: true, cancelable: true, pointerType: 'touch', isPrimary: true })); });
    } else if (e.click) e.click();
  };
  /* Slider nativo: pone el valor en el input original y avisa como si lo hubieran arrastrado */
  window.__plataSet = function (n, v) {
    var e = document.querySelector('[data-nid="' + n + '"]');
    if (!e) return;
    e.value = String(v);
    e.dispatchEvent(new Event('input', { bubbles: true }));
  };

  /* 4. Respaldo nativo de los datos locales */
  var S = Storage.prototype, si = S.setItem, ri = S.removeItem, ci = S.clear, timer = 0;
  function want(k) { return /^(finanzas|plata)\./.test(String(k)); }
  function mine(o) { try { return o === window.localStorage; } catch (e) { return false; } }
  function flush() {
    timer = 0;
    var o = {};
    try { for (var i = 0; i < localStorage.length; i++) { var k = localStorage.key(i); if (want(k)) o[k] = localStorage.getItem(k); } } catch (e) { return; }
    post({ t: 'save', items: o });
  }
  function sched() { if (!timer) timer = setTimeout(flush, 800); }
  S.setItem = function (k) { var r = si.apply(this, arguments); if (mine(this) && want(k)) sched(); return r; };
  S.removeItem = function (k) { var r = ri.apply(this, arguments); if (mine(this) && want(k)) sched(); return r; };
  S.clear = function () { var r = ci.apply(this, arguments); if (mine(this)) sched(); return r; };
  document.addEventListener('visibilitychange', function () { if (document.hidden) { if (timer) clearTimeout(timer); flush(); } });
})();
