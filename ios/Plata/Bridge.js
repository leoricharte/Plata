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
  st.textContent = 'html[data-native]:not(.web) #tabbar,html[data-native]:not(.web) #gearbtn,html[data-native]:not(.web) #plusbtn{visibility:hidden!important}';
  root.appendChild(st);

  /* 2. Estado hacia Swift */
  function r1(n) { return Math.round(n * 10) / 10; }
  function box(id) {
    var e = document.getElementById(id);
    if (!e) return { x: 0, y: 0, w: 0, h: 0, o: 0 };
    var cs = getComputedStyle(e), r = e.getBoundingClientRect();
    var o = cs.display === 'none' ? 0 : parseFloat(cs.opacity);
    return { x: r1(r.left), y: r1(r.top), w: r1(r.width), h: r1(r.height), o: isNaN(o) ? 0 : r1(o) };
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
      bar: box('tabbar'), plus: box('plusbtn'), gear: box('gearbtn'),
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
    new MutationObserver(function () { kick(700); }).observe(root, { attributes: true, subtree: true, attributeFilter: ['class', 'style', 'data-tab', 'data-theme', 'data-cdet'] });
  } catch (e) { /* sin observador */ }
  ['transitionrun', 'transitionstart', 'transitionend', 'animationstart'].forEach(function (n) { document.addEventListener(n, function () { kick(700); }, true); });
  window.addEventListener('resize', function () { kick(700); });
  window.addEventListener('orientationchange', function () { kick(700); });
  document.addEventListener('DOMContentLoaded', function () { kick(2500); });
  window.addEventListener('load', function () { kick(2500); });

  /* 3. Swift toca un control de la web (el selector lo escribe Swift, nunca viene de datos del usuario) */
  window.__plataGo = function (sel) { var e = document.querySelector(sel); if (e && e.click) e.click(); };

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
