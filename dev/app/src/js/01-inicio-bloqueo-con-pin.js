
/* ---------- Bloqueo con PIN (web) ----------
 * 4 dígitos. Se guarda solo una huella (PBKDF2 con sal) en este navegador: nunca el PIN. Protege la entrada a la app en este dispositivo;
 * no cifra los datos (quien tenga acceso técnico al navegador puede saltárselo). Tras 5 fallos pide esperar cada vez más. */
const LOCKSQ = (n, c) => '<svg width="' + n + '" height="' + n + '" viewBox="0 0 24 24" fill="none" stroke="' + c + '" stroke-width="1.6" stroke-linecap="round" aria-hidden="true"><rect x="3" y="3" width="18" height="18" rx="4.5" stroke-dasharray="2.6 2.6"/><rect x="8" y="11" width="8" height="6.2" rx="1.4" fill="' + c + '" stroke="none"/><path d="M9.8 11V9.6a2.2 2.2 0 0 1 4.4 0V11"/></svg>';
const PINLOCK = (function () {
  const KEY = 'plata.pin', LEN = 4, GR = [[0, 'Siempre'], [60, '1 minuto'], [300, '5 minutos'], [900, '15 minutos']];
  const can = !!(window.crypto && crypto.subtle && window.TextEncoder);
  const rd = () => { try { return JSON.parse(localStorage.getItem(KEY) || 'null'); } catch (e) { return null; } };
  const wr = (v) => { try { if (v) localStorage.setItem(KEY, JSON.stringify(v)); else localStorage.removeItem(KEY); } catch (e) { /* sin almacenamiento */ } };
  const b64 = (u) => btoa(String.fromCharCode.apply(null, Array.from(u))), unb64 = (t) => Uint8Array.from(atob(t), (c) => c.charCodeAt(0));
  const same = (a, b) => { if (a.length !== b.length) return false; let d = 0; for (let i = 0; i < a.length; i++) d |= a[i] ^ b[i]; return d === 0; };
  const weak = (p) => /^(\d)\1+$/.test(p) || '01234567890'.indexOf(p) >= 0 || '9876543210'.indexOf(p) >= 0;
  async function derive(pin, salt, iter) { const k = await crypto.subtle.importKey('raw', new TextEncoder().encode(pin), 'PBKDF2', false, ['deriveBits']); return new Uint8Array(await crypto.subtle.deriveBits({ name: 'PBKDF2', hash: 'SHA-256', salt: salt, iterations: iter }, k, 256)); }
  let rec = rd(), ov = null, locked = !!rec, hideAt = 0, S = null, tm = null;
  const on = () => !!rec;
  const waitLeft = () => (rec && rec.until && rec.until > Date.now()) ? Math.ceil((rec.until - Date.now()) / 1000) : 0;
  function close() { if (tm) { clearInterval(tm); tm = null; } if (ov) { ov.remove(); ov = null; } S = null; }
  function draw() {
    if (!S) return; if (!ov) { ov = document.createElement('div'); ov.id = 'pinov'; document.body.appendChild(ov); ov.addEventListener('click', onClick); }
    const w = (S.mode === 'lock' || S.mode === 'verify') ? waitLeft() : 0, dots = []; for (let i = 0; i < LEN; i++) dots.push('<i' + (i < S.buf.length ? ' class="on"' : '') + '></i>');
    if (S.mode === 'cover') { ov.innerHTML = '<div class="pk-ic">' + LOCKSQ(34, '#fff') + '</div><h1>Plata</h1>'; return; }
    if (S.mode === 'offer') { ov.innerHTML = '<div class="pk-ic">' + LOCKSQ(34, '#fff') + '</div><h1>Protege tu app</h1><div class="pk-m">Pon un PIN de 4 dígitos para que nadie más abra tus finanzas en este navegador. Puedes cambiarlo o quitarlo en Ajustes.</div><button class="pk-b" data-pk="make">Crear PIN</button><button class="pk-b alt" data-pk="skip">Ahora no</button>'; return; }
    const title = S.mode === 'lock' ? 'Plata está bloqueada' : S.mode === 'setup' ? (S.first ? 'Repite tu PIN' : 'Crea tu PIN') : (S.title || 'Escribe tu PIN actual');
    const msg = w ? 'Demasiados intentos. Espera ' + (w >= 60 ? Math.floor(w / 60) + ' min ' + (w % 60) + ' s' : w + ' s') + '.' : (S.msg || (S.mode === 'setup' ? (S.first ? 'Escríbelo otra vez para confirmarlo.' : 'Elige ' + LEN + ' dígitos que solo tú sepas.') : S.mode === 'lock' ? 'Escribe tu PIN' : 'Escribe tu PIN actual.'));
    let keys = ''; '123456789'.split('').forEach((d) => { keys += '<button data-pk="' + d + '">' + d + '</button>'; });
    ov.innerHTML = (S.mode === 'lock' ? '' : '<button class="pk-x" data-pk="x" aria-label="Cerrar">×</button>') + '<div class="pk-ic">' + LOCKSQ(34, '#fff') + '</div><h1>' + title + '</h1><div class="pk-m' + ((S.err || w) ? ' e' : '') + '">' + msg + '</div><div class="pk-d' + (S.sh ? ' sh' : '') + '">' + dots.join('') + '</div><div class="pk-g' + (w ? ' off' : '') + '">' + keys + '<button class="z" disabled></button><button data-pk="0">0</button><button class="z" data-pk="del" aria-label="Borrar">⌫</button></div>' + (S.mode === 'lock' ? '<button class="pk-l" data-pk="forgot">¿Olvidaste tu PIN?</button>' : '');
    S.sh = false;
  }
  function fail(msg) { S.err = true; S.msg = msg; S.buf = ''; S.sh = true; try { navigator.vibrate && navigator.vibrate(120); } catch (e) { /* sin vibración */ } draw(); }
  async function submit() {
    const pin = S.buf;
    if (S.mode === 'setup') {
      if (S.first) { if (S.first === pin) { await make(pin); const d = S.done; close(); locked = false; if (d) d(true); } else { S.first = ''; fail('No coinciden. Empieza de nuevo.'); } }
      else if (weak(pin)) fail('Ese PIN es muy fácil de adivinar. Elige otro.');
      else { S.first = pin; S.buf = ''; S.msg = ''; S.err = false; draw(); }
      return;
    }
    const r = await check(pin);
    if (r === 'ok') { if (S.mode === 'lock') { locked = false; close(); } else { const d = S.done; close(); if (d) d(true); } }
    else if (r === 'wait') { S.buf = ''; draw(); startTick(); }
    else fail('PIN incorrecto. Te quedan ' + r + ' intentos antes de esperar.');
  }
  async function make(pin) {
    const salt = crypto.getRandomValues(new Uint8Array(16)), iter = 150000;
    rec = { v: 1, s: b64(salt), h: b64(await derive(pin, salt, iter)), i: iter, grace: rec ? rec.grace : 60, fails: 0, until: 0 }; wr(rec);
  }
  async function check(pin) {
    if (waitLeft()) return 'wait';
    const h = await derive(pin, unb64(rec.s), rec.i);
    if (same(h, unb64(rec.h))) { rec.fails = 0; rec.until = 0; wr(rec); return 'ok'; }
    rec.fails = (rec.fails || 0) + 1;
    if (rec.fails >= 5) { const st = { 5: 30, 6: 60, 7: 300, 8: 900 }; rec.until = Date.now() + (st[rec.fails] || 3600) * 1000; }
    wr(rec);
    return rec.fails >= 5 ? 'wait' : 5 - rec.fails;
  }
  function startTick() { if (tm) clearInterval(tm); tm = setInterval(() => { if (!S || (S.mode !== 'lock' && S.mode !== 'verify')) return; if (!waitLeft()) { clearInterval(tm); tm = null; S.msg = ''; S.err = false; } draw(); }, 1000); }
  function onClick(e) {
    const b = e.target.closest('[data-pk]'); if (!b || !S) return; const k = b.getAttribute('data-pk');
    if (k === 'x') { const d = S.done; close(); if (d) d(false); }
    else if (k === 'make') start('setup', S.done)
    else if (k === 'skip') { const d = S.done; close(); if (d) d(false); }
    else if (k === 'del') { S.buf = S.buf.slice(0, -1); draw(); }
    else if (k === 'forgot') forgot();
    else if (/^\d$/.test(k) && S.buf.length < LEN && !waitLeft()) { S.buf += k; S.err = false; S.msg = ''; draw(); if (S.buf.length === LEN) submit(); }
  }
  function forgot() {
    if (!ov) return;
    ov.innerHTML = '<div class="pk-ic">' + LOCKSQ(34, '#fff') + '</div><h1>¿Olvidaste tu PIN?</h1><div class="pk-m">En la web no hay un código del dispositivo para confirmarte. Para quitar el PIN hay que borrar los datos de este navegador. Si usas Plata Cloud o guardaste tu archivo de perfil, puedes recuperarlos después.</div><button class="pk-b" style="background:var(--rt)" data-pk="wipe">Borrar datos y quitar el PIN</button><button class="pk-b alt" data-pk="back">Volver</button>';
    ov.onclick = (e) => { const b = e.target.closest('[data-pk]'); if (!b) return; const k = b.getAttribute('data-pk'); if (k === 'back') { ov.onclick = null; draw(); } else if (k === 'wipe') { try { Object.keys(localStorage).filter((x) => /^(finanzas|plata)\./.test(x) && x !== 'plata.theme' && x !== 'plata.lang').forEach((x) => localStorage.removeItem(x)); } catch (er) { /* sin almacenamiento */ } location.reload(); } };
  }
  function start(mode, done, title) { close(); S = { mode: mode, buf: '', first: '', msg: '', err: false, sh: false, done: done, title: title }; draw(); if ((mode === 'lock' || mode === 'verify') && waitLeft()) startTick(); }
  function lock() { if (!rec || locked && ov) return; locked = true; start('lock'); }
  document.addEventListener('visibilitychange', () => {
    if (!rec) return;
    if (document.hidden) { hideAt = Date.now(); if (!locked && !S) { S = { mode: 'cover', buf: '' }; draw(); } }
    else { if (S && S.mode === 'cover') close(); if (!locked && Date.now() - hideAt >= (rec.grace || 0) * 1000) lock(); }
  });
  if (rec) { if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', () => start('lock')); else start('lock'); }
  document.addEventListener('click', (e) => {
    const b = e.target.closest && e.target.closest('[data-act="pin:menu"]'); if (!b) return; e.stopPropagation(); e.preventDefault();
    const fin = () => { try { renderAll(); } catch (er) { /* sin pantalla */ } };
    if (!rec) { start('setup', (ok) => { if (ok) { toast('PIN activado'); fin(); } }); return; }
    askConfirm('Bloqueo con PIN', 'Plata te pide el PIN al abrirla en este navegador. Tus datos no se cifran con él: protege la entrada, no el contenido.', [
      { label: 'Cambiar PIN', fn: () => start('verify', (ok) => { if (ok) start('setup', (ok2) => { if (ok2) toast('PIN cambiado'); }); }) },
      { label: 'Pedir el PIN: ' + (GR.find((g) => g[0] === (rec.grace || 0)) || GR[0])[1] + ' (tocar para cambiar)', fn: () => { const i = GR.findIndex((g) => g[0] === (rec.grace || 0)); rec.grace = GR[(i + 1) % GR.length][0]; wr(rec); toast('Pedir el PIN: ' + GR[(i + 1) % GR.length][1]); } },
      { label: 'Quitar PIN', dest: true, fn: () => start('verify', (ok) => { if (ok) { rec = null; wr(null); locked = false; toast('PIN quitado'); fin(); } }, 'Escribe tu PIN para quitarlo') },
    ]);
  }, true);
  return {
    on: on, can: can,
    offer: (done) => { if (rec || !can) { done(); return; } start('offer', () => done()); },
    setup: (done) => start('setup', done),
    verify: (title, done) => start('verify', done, title),
    remove: () => { rec = null; wr(null); locked = false; },
    grace: () => (rec && rec.grace) || 0,
    graceLabel: () => (GR.find((g) => g[0] === ((rec && rec.grace) || 0)) || GR[0])[1],
    nextGrace: () => { if (!rec) return; const i = GR.findIndex((g) => g[0] === (rec.grace || 0)); rec.grace = GR[(i + 1) % GR.length][0]; wr(rec); },
  };
})();

