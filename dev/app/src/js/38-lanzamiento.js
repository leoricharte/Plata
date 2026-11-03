/* ---------- Animación de arranque (solo la app de Android) ----------
 * La misma del iPhone (PlataLaunchAnimation.swift): la flecha sube como una piedra rebotando en el agua, el cuerpo la sigue y cada letra hace «pop» con un resorte
 * cuando la piedra la alcanza; al final queda el logo. Los datos (geometría y recorrido) salen de 37-lanzamiento-datos.js, generados desde el Swift.
 * Se dibuja en un canvas 2D con las mismas máscaras que usa el iPhone. Dentro de la app empaquetada reemplaza al splash estático de la web; en el navegador, la PWA
 * y el iPhone no corre. El splash nativo de Android 12 es solo el fondo verde (sin imagen), como la pantalla de arranque del iPhone: la animación empieza desde el verde liso. */
const LANZ = (function () {
  const D = LANZ_DATA, P = D.path, S = D.size, LAG = 40, START = 0.36, TOTAL = START + P.duration + 0.22;
  const clamp = (v, lo, hi) => Math.min(hi === undefined ? 1 : hi, Math.max(lo === undefined ? 0 : lo, v));
  const smooth = (t) => t * t * (3 - 2 * t);
  const seg = (t, a, b) => clamp((t - a) / (b - a));
  /* Resorte amortiguado 0 → 1 con ~8 % de pasada (mismos números que PlataTimeline.spring) */
  const spring = (tau) => { if (tau <= 0) return 0; const z = 0.63, w = 26, wd = w * Math.sqrt(1 - z * z); return 1 - Math.exp(-z * w * tau) * (Math.cos(wd * tau) + z / Math.sqrt(1 - z * z) * Math.sin(wd * tau)); };
  /* Arco recorrido en el instante t (las tablas son monótonas) */
  const arc = (t) => {
    const u = t - START; if (u <= 0) return 0; if (u >= P.duration) return P.count;
    let lo = 0, hi = P.count; while (hi - lo > 1) { const m = (lo + hi) >> 1; if (P.t[m] <= u) lo = m; else hi = m; }
    return lo + (u - P.t[lo]) / (P.t[hi] - P.t[lo]);
  };
  const sample = (tab, s) => { const i = Math.min(P.count - 1, Math.floor(s)); return tab[i] + (tab[i + 1] - tab[i]) * (s - i); };
  const path = (d) => new Path2D(d);
  const LOGO = path(D.logo), ARROW = path(D.arrow), HEAD = path(D.head), LETTERS = D.letters.map((l) => ({ p: path(l.d), pv: l.pivot, t0: l.t0 }));

  /* Un cuadro. `c` es el contexto del canvas visible y `o` uno del mismo tamaño para componer las máscaras; los dos ya vienen escalados a las coordenadas del logo.
   * `base` es la transformación (escala del dispositivo × escala del logo) para volver a dibujar con ella. */
  function frame(c, o, W, H, base, t, ink) {
    c.setTransform(1, 0, 0, 1, 0, 0); c.clearRect(0, 0, W, H);
    const reset = (x) => { x.setTransform(1, 0, 0, 1, 0, 0); x.globalCompositeOperation = 'source-over'; x.globalAlpha = 1; x.clearRect(0, 0, W, H); };
    const put = (alpha) => { c.save(); c.setTransform(1, 0, 0, 1, 0, 0); c.globalAlpha = alpha === undefined ? 1 : alpha; c.drawImage(o.canvas, 0, 0); c.restore(); };
    const s = arc(t), pv = D.headPivot;

    // Cuerpo de la flecha: el logo, revelado por el trazo (TraceMask), sin la punta (BodyCutMask) y recortado contra el logo final (LogoMask)
    const sb = Math.max(0, s - LAG);
    if (sb > 0.5) {
      reset(o); o.setTransform.apply(o, base); o.fillStyle = ink; o.fill(ARROW);
      o.globalCompositeOperation = 'destination-in'; o.strokeStyle = '#fff'; o.lineWidth = 58; o.lineCap = 'round'; o.lineJoin = 'round';
      o.beginPath(); o.moveTo(P.x[0], P.y[0]); const k = Math.floor(sb); for (let i = 1; i <= k; i++) o.lineTo(P.x[i], P.y[i]);
      if (k < P.count) o.lineTo(sample(P.x, sb), sample(P.y, sb)); o.stroke();
      o.globalCompositeOperation = 'destination-out'; o.fillStyle = '#000'; o.fill(HEAD); o.strokeStyle = '#000'; o.lineWidth = 0.6; o.stroke(HEAD);
      o.globalCompositeOperation = 'destination-in'; o.fillStyle = '#fff'; o.fill(LOGO);
      put();
    }
    // Letras: pop con resorte cuando la piedra las alcanza (escala desde su pivote, suben 14 unidades y aparecen en 0,09 s)
    LETTERS.forEach((l) => {
      const tau = t - l.t0; if (!(tau > 0)) return;
      const p = spring(tau), k = 0.35 + 0.65 * p;
      reset(o); o.setTransform.apply(o, base); o.translate(l.pv[0], l.pv[1] + (1 - p) * 14); o.scale(k, k); o.translate(-l.pv[0], -l.pv[1]);
      o.fillStyle = ink; o.fill(l.p); o.globalCompositeOperation = 'destination-in'; o.fillStyle = '#fff'; o.fill(LOGO);
      put(clamp(tau / 0.09));
    });
    // Punta: crece de «punta de lápiz» a su tamaño y viaja al frente del trazo; al final queda en su sitio exacto
    if (t >= START - 0.03) {
      const grow = 0.3 + 0.7 * smooth(clamp(s / (P.count * 0.62))), intro = t < START + 0.1 ? clamp(spring((t - (START - 0.03)) * 1.1), 0, 1.12) : 1, hs = Math.max(0.0001, grow * intro);
      const px = sample(P.x, s), py = sample(P.y, s);
      // la forma de la punta (relleno + contorno de 2,4) se dibuja aparte y se aplica de una vez: dos recortes seguidos se intersectarían en vez de sumarse
      let mc = o.canvas._m; if (!mc) { mc = o.canvas._m = document.createElement('canvas'); mc.width = W; mc.height = H; }
      const m = mc.getContext('2d'); m.setTransform(1, 0, 0, 1, 0, 0); m.clearRect(0, 0, W, H); m.setTransform.apply(m, base); m.translate(px, py); m.scale(hs, hs); m.translate(-pv[0], -pv[1]);
      m.fillStyle = '#fff'; m.fill(HEAD); m.strokeStyle = '#fff'; m.lineWidth = 2.4; m.lineJoin = 'round'; m.stroke(HEAD);
      reset(o); o.setTransform.apply(o, base); o.translate(px, py); o.scale(hs, hs); o.translate(-pv[0], -pv[1]); o.fillStyle = ink; o.fill(LOGO);
      o.setTransform(1, 0, 0, 1, 0, 0); o.globalCompositeOperation = 'destination-in'; o.drawImage(mc, 0, 0);
      put();
    }
    // El logo final entra con un fundido corto por encima (solo aporta bordes de menos de 1 px)
    const fin = smooth(seg(t, TOTAL - 0.20, TOTAL - 0.08));
    if (fin > 0) { c.save(); c.setTransform.apply(c, base); c.globalAlpha = fin; c.fillStyle = ink; c.fill(LOGO); c.restore(); }
  }
  return { frame: frame, total: TOTAL, size: S, logo: LOGO };
})();

/* ---- El arranque en la app de Android: un velo verde de pantalla completa con la animación encima de todo, y al terminar se desvanece ---- */
(function () {
  if (!PN.on) return;
  const done = () => { PN.launching = false; };
  try {
    const dark = !!(window.matchMedia && matchMedia('(prefers-color-scheme: dark)').matches), still = !!(window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches);
    // blanco sobre el verde de marca en claro; verde de marca sobre verde bosque en oscuro (igual que el iPhone y que el splash nativo)
    const bg = dark ? '#0A2D1F' : '#22B573', ink = dark ? '#22B573' : '#FFFFFF';
    const veil = document.createElement('div'); veil.id = 'lanzamiento';
    veil.style.cssText = 'position:fixed;inset:0;z-index:2147483647;background:' + bg + ';display:flex;align-items:center;justify-content:center;opacity:1;transition:opacity .28s ease';
    const w = Math.round(Math.min(260, window.innerWidth * 0.72)), h = Math.round(w * LANZ.size[1] / LANZ.size[0]), dpr = Math.min(3, window.devicePixelRatio || 1);
    const cv = document.createElement('canvas'); cv.width = Math.round(w * dpr); cv.height = Math.round(h * dpr); cv.style.cssText = 'width:' + w + 'px;height:' + h + 'px;display:block';
    veil.appendChild(cv); document.body.appendChild(veil);
    const c = cv.getContext('2d'), o = document.createElement('canvas'); o.width = cv.width; o.height = cv.height; const oc = o.getContext('2d');
    const k = cv.width / LANZ.size[0], base = [k, 0, 0, k, 0, 0];
    const hideNative = () => { const sp = PN.plugin('SplashScreen'); if (sp) { try { sp.hide({ fadeOutDuration: 0 }); } catch (e) { /* se oculta solo */ } } };
    const finish = () => { veil.style.opacity = '0'; setTimeout(() => { veil.remove(); done(); }, 320); };
    if (still) { LANZ.frame(c, oc, cv.width, cv.height, base, LANZ.total + 1, ink); requestAnimationFrame(hideNative); setTimeout(finish, 400); return; }
    let t0 = 0;
    const tick = (now) => {
      if (!t0) { t0 = now; requestAnimationFrame(hideNative); }       // el primer cuadro ya está pintado: se quita el splash nativo (verde liso, sin salto)
      const t = (now - t0) / 1000;
      LANZ.frame(c, oc, cv.width, cv.height, base, Math.min(t, LANZ.total + 0.1), ink);
      if (t < LANZ.total + 0.15) requestAnimationFrame(tick); else finish();
    };
    requestAnimationFrame(tick);
  } catch (e) { done(); const v = document.getElementById('lanzamiento'); if (v) v.remove(); const sp = PN.plugin('SplashScreen'); if (sp) { try { sp.hide(); } catch (er) { /* nada */ } } }
})();
