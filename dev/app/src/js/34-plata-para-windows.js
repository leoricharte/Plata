/* ---------- Plata para Windows (app de escritorio con Tauri) ----------
   Dentro de esa app, Tauri inyecta window.__TAURI__ (withGlobalTauri). Ahí la ventana va sin la barra de Windows:
   Plata dibuja la suya (transparente, así toma el fondo y el tema de la app), con arrastre y los tres botones.
   En el navegador y en el celular no existe window.__TAURI__ y todo queda igual. */
const IS_WIN_APP = !!(window.__TAURI__ && window.__TAURI__.window && /Windows/.test(navigator.userAgent || ''));
if (IS_WIN_APP) (function () {
  const R = document.documentElement, W = window.__TAURI__.window.getCurrentWindow();
  R.classList.add('tauri-win');
  const bar = document.createElement('div'); bar.id = 'tbar';
  bar.innerHTML = '<div class="tbd" data-tauri-drag-region></div>' +
    '<button type="button" class="tbm" data-w="min" aria-label="Minimizar">' + RMI('subtract-line', 16) + '</button>' +
    '<button type="button" class="tbm" data-w="max" id="tbmax" aria-label="Maximizar">' + RMI('checkbox-blank-line', 13) + '</button>' +
    '<button type="button" class="tbx" data-w="close" aria-label="Cerrar">' + RMI('close-line', 18) + '</button>';
  document.body.insertBefore(bar, document.body.firstChild);
  bar.addEventListener('click', (e) => {
    const b = e.target.closest('button'); if (!b) return;
    const a = b.dataset.w;
    if (a === 'min') W.minimize(); else if (a === 'max') W.toggleMaximize(); else if (a === 'close') W.close();
  });
  const syncMax = () => { W.isMaximized().then((m) => { const b = $('#tbmax'); if (!b) return; b.innerHTML = RMI(m ? 'checkbox-multiple-blank-line' : 'checkbox-blank-line', 13); b.setAttribute('aria-label', m ? 'Restaurar' : 'Maximizar'); }).catch(() => {}); };
  window.addEventListener('resize', syncMax); syncMax();
  const pill = document.querySelector('.webbar .betapill'); if (pill) pill.innerHTML = 'B E T A&nbsp;&nbsp;P A R A&nbsp;&nbsp;W I N D O W S';
})();
/* Flechas de apertura (solo escritorio): al abrir y, en la pantalla de inicio, cada cierto tiempo al azar */
(function () {
  if (!document.documentElement.classList.contains('web') || (window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches)) return;
  const P = '80.2 2.31 85.19 24.07 0 61.22 7.77 74.67 88.16 39.37 88.63 39.15 88.63 39.17 94.59 65.13 156.26 0 80.2 2.31';
  const FORM = { 1: [[[0, 0, 120]]], 2: [[[0, 0, 100], [110, 44, 132]], [[0, 40, 126], [120, 0, 100]]], 3: [[[0, 0, 100], [104, 0, 100], [60, 80, 132]], [[0, 0, 116], [90, 60, 100], [190, 24, 100]]] };
  const FULL = [[0, 0, 100], [104, 0, 100], [40, 82, 100], [146, 92, 138]];
  function fly(F) {
    const el = document.createElement('div'); el.className = 'wjump'; el.setAttribute('aria-hidden', 'true');
    el.innerHTML = F.map((f, i) => '<span class="jx" style="margin-left:' + f[0] + 'px;margin-bottom:' + f[1] + 'px;width:' + f[2] + 'px;height:' + Math.round(f[2] * 0.478) + 'px;animation-delay:' + (i * 0.045) + 's"><svg viewBox="0 0 156.26 74.67" style="width:100%;height:100%;display:block"><polygon points="' + P + '" fill="#22B573"/></svg></span>').join('');
    const sx = Math.round(Math.min(640, innerWidth * 0.42)), dx = sx + 400, dy = -Math.round(dx * 0.44 + 220);
    el.style.setProperty('--sx', sx + 'px'); el.style.setProperty('--dx', dx + 'px'); el.style.setProperty('--dy', dy + 'px');
    document.body.appendChild(el); setTimeout(() => el.remove(), 1400);
  }
  const onLanding = () => !document.hidden && !!document.querySelector('.welcome .wland') && !document.getElementById('splash');
  function loop() {
    setTimeout(() => {
      if (onLanding()) { const r = Math.random(), n = r < 0.5 ? 1 : r < 0.8 ? 2 : 3, opts = FORM[n]; fly(opts[Math.floor(Math.random() * opts.length)]); }
      loop();
    }, 5000 + Math.random() * 25000);
  }
  setTimeout(() => { fly(FULL); loop(); }, 700);
})();
