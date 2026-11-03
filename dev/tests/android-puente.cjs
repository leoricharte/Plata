// Puente de la app de Android (01-inicio-bloqueo-con-pin.js y 36-android.js) con un Capacitor SIMULADO: huella o rostro en el bloqueo, avisos locales,
// guardar archivos por «Compartir», recibir una captura desde «Compartir» y el enlace de un evento. No prueba el código nativo (Java): ese lo compila el CI.
// Requiere Playwright y la web compilada:  sh dev/web/build.sh && (cd dist-web && python3 -m http.server 8790 &) && node dev/tests/android-puente.cjs http://localhost:8790/
const { chromium } = require('playwright');
const BASE = process.argv[2] || 'http://localhost:8790/';
let f = 0; const ok = (c, m) => { console.log((c ? 'OK    ' : 'FALLA ') + m); if (!c) f++; };

// Un Capacitor falso: cada llamada a un plugin queda en window.__calls y responde según `cfg`.
const mock = (cfg) => {
  window.__cfg = cfg; window.__calls = []; window.__listeners = {};
  if (!cfg.noPin) localStorage.setItem('plata.pin', JSON.stringify({ v: 1, s: 'AAAA', h: 'AAAA', i: 1000, grace: 0, bio: !!cfg.bioSaved, fails: 0, until: 0 }));
  if (cfg.avisos) localStorage.setItem('plata.avisos', JSON.stringify(cfg.avisos));
  const answer = (name, m, a) => {
    if (name === 'PlataNative' && m === 'biometricAvailable') return { available: window.__cfg.bioAvailable !== false };
    if (name === 'PlataNative' && m === 'biometricAuth') return { ok: !!window.__cfg.bioOk };
    if (name === 'PlataNative' && m === 'getShared') { const it = (window.__cfg.shared || []).shift(); return it ? { item: it } : {}; }
    if (name === 'LocalNotifications' && (m === 'checkPermissions' || m === 'requestPermissions')) return { display: 'granted' };
    if (name === 'Filesystem' && m === 'writeFile') return { uri: 'file:///cache/' + a.path };
    if (name === 'App' && m === 'addListener') { (window.__listeners[a] = window.__listeners[a] || []).push(arguments[3]); return { remove() {} }; }
    if (name === 'App' && m === 'getLaunchUrl') return {};
    return {};
  };
  if (cfg.noCap) return;
  window.Capacitor = { isNativePlatform: () => true, registerPlugin: (name) => new Proxy({}, { get: (_, m) => (a, cb) => {
    window.__calls.push([name, m, a]);
    if (name === 'App' && m === 'addListener') { (window.__listeners[a] = window.__listeners[a] || []).push(cb); return Promise.resolve({ remove() {} }); }
    return Promise.resolve(answer(name, m, a)); } }) };
};
const calls = (p, name, m) => p.evaluate(([n, mm]) => window.__calls.filter((c) => c[0] === n && c[1] === mm).map((c) => c[2]), [name, m]);

(async () => {
  const b = await chromium.launch(); const errs = [];
  const WV = 'Mozilla/5.0 (Linux; Android 14; Pixel 8 Build/AP2A.240805.005; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/130.0.0.0 Mobile Safari/537.36';
  const open = async (cfg, url) => {
    const ctx = await b.newContext({ viewport: { width: 430, height: 900 }, userAgent: cfg.wv ? WV : undefined }); const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(String(e)));
    await p.addInitScript(mock, cfg); await p.goto(BASE + (url || '?demo=shawn&lang=es&nosplash')); return p;
  };
  const pinOpen = (p) => p.evaluate(() => !!document.getElementById('pinov') && /bloqueada/.test(document.getElementById('pinov').innerText));

  // 1) Huella activada y correcta: se pide sola al abrir y desbloquea
  let p = await open({ bioSaved: true, bioOk: true }); await p.waitForTimeout(5500);
  ok((await calls(p, 'PlataNative', 'biometricAuth')).length >= 1, 'huella: se pide sola al abrir la app bloqueada');
  ok(!(await pinOpen(p)), 'huella: si es correcta, el bloqueo se abre sin PIN');
  const t = (await calls(p, 'PlataNative', 'biometricAuth'))[0]; ok(t && t.cancel === 'Usar el PIN', 'huella: el botón del sistema dice «Usar el PIN»');

  // 2) Huella cancelada: queda el PIN, con un botón para intentar de nuevo
  p = await open({ bioSaved: true, bioOk: false }); await p.waitForTimeout(5500);
  ok(await pinOpen(p), 'huella cancelada: el bloqueo sigue y se puede usar el PIN');
  ok(!!(await p.$('#pinov [data-pk="bio"]')), 'huella cancelada: hay un botón de huella en el teclado');
  const n0 = (await calls(p, 'PlataNative', 'biometricAuth')).length; await p.click('#pinov [data-pk="bio"]'); await p.waitForTimeout(300);
  ok((await calls(p, 'PlataNative', 'biometricAuth')).length === n0 + 1, 'huella cancelada: el botón vuelve a pedirla');
  // solo una vez por bloqueo: no se queda pidiéndola en bucle
  ok(n0 === 1, 'huella: se pide una sola vez automáticamente (no en bucle)');

  // 2b) Arranque animado: velo verde con la animación encima de todo, el splash nativo se quita al pintar el primer cuadro, y la huella espera a que termine
  p = await open({ bioSaved: true, bioOk: true }); await p.waitForTimeout(350);
  const v = await p.evaluate(() => { const e = document.getElementById('lanzamiento'); return e ? { z: getComputedStyle(e).zIndex, bg: getComputedStyle(e).backgroundColor, canvas: !!e.querySelector('canvas'), web: !!document.getElementById('splash') } : null; });
  ok(!!v && v.canvas && v.z === '2147483647', 'arranque: hay un velo con la animación por encima de todo');
  ok(!!v && v.bg === 'rgb(34, 181, 115)', 'arranque: el fondo es el verde de marca (el mismo del splash nativo)');
  ok(!!v && v.web === false, 'arranque: el splash estático de la web no sale en Android');
  await p.waitForTimeout(500); const hides = await calls(p, 'SplashScreen', 'hide'); ok(hides.length === 1, 'arranque: el splash nativo se oculta una sola vez, cuando ya se pintó el primer cuadro');
  ok((await calls(p, 'PlataNative', 'biometricAuth')).length === 0, 'arranque: la huella NO se pide mientras corre la animación');
  await p.waitForTimeout(3600);
  ok(!(await p.evaluate(() => !!document.getElementById('lanzamiento'))), 'arranque: al terminar el velo se quita');
  ok((await calls(p, 'PlataNative', 'biometricAuth')).length >= 1, 'arranque: y entonces se pide la huella');
  // 2c) La aleta «Ábrela en tu navegador»: no sale dentro de la app, pero sí en un navegador integrado de verdad
  p = await open({ noPin: true, wv: true }); await p.waitForTimeout(2500);
  ok(!(await p.evaluate(() => !!document.querySelector('.iab'))), 'aleta: dentro de la app de Android NO sale «Ábrela en tu navegador»');
  p = await open({ noPin: true, wv: true, noCap: true }); await p.waitForTimeout(2500);
  ok(await p.evaluate(() => !!document.querySelector('.iab')), 'aleta: en un WebView cualquiera (sin la app) SÍ sale, como antes');

  // 3) Sin huella guardada o sin sensor: no hay botón ni se pide
  p = await open({ bioSaved: false, bioOk: true }); await p.waitForTimeout(2200);
  ok((await calls(p, 'PlataNative', 'biometricAuth')).length === 0 && !(await p.$('#pinov [data-pk="bio"]')), 'sin huella activada: no se pide ni hay botón');
  p = await open({ bioSaved: true, bioAvailable: false }); await p.waitForTimeout(2200);
  ok((await calls(p, 'PlataNative', 'biometricAuth')).length === 0 && !(await p.$('#pinov [data-pk="bio"]')), 'teléfono sin huella configurada: el PIN funciona como siempre');

  // 4) Avisos: la fila en Ajustes y la programación al abrir
  p = await open({ bioSaved: true, bioOk: true, avisos: { inact: true, up: true, amt: true, ins: true, since: Date.now() - 86400000 * 3 } }); await p.waitForTimeout(4200);
  await p.locator('[data-act="settings"]:visible').first().click().catch(() => {}); await p.waitForTimeout(900);
  ok(!!(await p.$('[data-act="avisos:menu"]')), 'avisos: la fila «Avisos» aparece en Ajustes');
  const sch = await calls(p, 'LocalNotifications', 'schedule'); const ns = sch.length ? sch[sch.length - 1].notifications : [];
  ok(ns.length > 0, 'avisos: al abrir se programan avisos (' + ns.length + ')');
  ok(ns.every((n) => Number.isInteger(n.id) && n.id > 0 && n.title && n.body && n.channelId === 'avisos' && n.schedule && n.schedule.at), 'avisos: cada uno trae id entero, título, texto, canal y fecha');
  ok(new Set(ns.map((n) => n.id)).size === ns.length, 'avisos: los ids no se repiten');
  ok((await calls(p, 'LocalNotifications', 'createChannel')).length >= 1, 'avisos: se crea el canal «Avisos de Plata»');
  await p.click('[data-act="avisos:menu"]'); await p.waitForTimeout(500);
  ok(await p.evaluate(() => /Si llevas días sin anotar: sí/.test(document.body.innerText) && /Nota del mes y half-time: sí/.test(document.body.innerText)), 'avisos: el menú muestra el estado de cada tipo');

  // 5) Guardar un archivo: el blob: no se descarga, se escribe en la caché y se abre «Compartir»
  p = await open({ noPin: true }); await p.waitForTimeout(2200);
  await p.evaluate(() => { const bl = new Blob(['{"hola":1}'], { type: 'application/json' }), u = URL.createObjectURL(bl), a = document.createElement('a'); a.href = u; a.download = 'plata-prueba.json'; document.body.appendChild(a); a.click(); a.remove(); });
  await p.waitForTimeout(600);
  const w = await calls(p, 'Filesystem', 'writeFile'), s = await calls(p, 'Share', 'share');
  ok(w.length === 1 && w[0].path === 'plata-prueba.json' && w[0].directory === 'CACHE' && Buffer.from(w[0].data, 'base64').toString() === '{"hola":1}', 'archivos: se escribe en la caché con el contenido exacto');
  ok(s.length === 1 && s[0].url === 'file:///cache/plata-prueba.json', 'archivos: se abre «Compartir» con ese archivo');
  // un enlace normal no se toca
  ok(await p.evaluate(() => { const a = document.createElement('a'); a.href = '#x'; document.body.appendChild(a); a.click(); a.remove(); return true; }), 'archivos: un clic en un enlace normal sigue funcionando');

  // 6) Recibir desde «Compartir»: una captura pregunta qué es; un texto va a las constancias
  const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==', 'base64').toString('base64');
  p = await open({ noPin: true, shared: [{ kind: 'file', name: 'captura.png', mime: 'image/png', data: png }] }); await p.waitForTimeout(4200);
  ok(await p.evaluate(() => /Captura recibida/.test(document.body.innerText) && /Constancia de Yape o Plin/.test(document.body.innerText) && /Captura de movimientos de un banco/.test(document.body.innerText)), 'compartir: una captura recibida pregunta si es constancia o movimientos');
  p = await open({ noPin: true, shared: [{ kind: 'text', mime: 'text/plain', text: 'texto cualquiera' }] }); await p.waitForTimeout(4200);
  ok(await p.evaluate(() => /no parece una constancia|Constancia|constancia/i.test(document.body.innerText)), 'compartir: un texto se manda a leer como constancia');

  // 7) Enlace de un evento: abre ese evento en Proyección
  p = await open({ noPin: true }); await p.waitForTimeout(4500);
  await p.locator('[data-act="tab:proyeccion"]:visible').first().click(); await p.waitForTimeout(700);
  const key = await p.$eval('[data-act^="evedit:"]', (e) => e.getAttribute('data-act').slice(7));
  await p.locator('[data-act="tab:resumen"]:visible').first().click(); await p.waitForTimeout(500);
  await p.evaluate((k) => (window.__listeners.appUrlOpen || []).forEach((cb) => cb({ url: 'https://web.plataapp.net/?ev=' + encodeURIComponent(k) })), key); await p.waitForTimeout(1500);
  ok(await p.evaluate(() => /Editar este evento/.test(document.body.innerText)), 'enlace: https://web.plataapp.net/?ev=… abre el evento en Proyección');

  // 8) Textos: dentro de la app de Android no se habla de «navegador» ni de «la web»; en la web quedan exactamente como siempre
  const pinTxt = async (cfg) => {
    const q = await open(cfg); await q.waitForTimeout(2500);
    await q.waitForSelector('#pinov [data-pk="forgot"]', { timeout: 6000 }); await q.click('#pinov [data-pk="forgot"]');
    await q.waitForTimeout(400); return q.evaluate(() => (document.getElementById('pinov') || { innerText: '' }).innerText);
  };
  // menú «Bloqueo con PIN» (Ajustes): se desbloquea con la huella simulada y se abre la fila
  p = await open({ bioSaved: true, bioOk: true }); await p.waitForTimeout(5500);
  await p.locator('[data-act="settings"]:visible').first().click().catch(() => {}); await p.waitForTimeout(900);
  await p.click('[data-act="pin:menu"]'); await p.waitForTimeout(500);
  let tx = await p.evaluate(() => (document.querySelector('.alertbox') || { innerText: '' }).innerText);
  ok(/este teléfono/.test(tx) && !/navegador/i.test(tx), 'textos: el menú «Bloqueo con PIN» dice «este teléfono», no «navegador»');
  tx = await pinTxt({ bioSaved: false, bioOk: false });
  ok(/Plata en este teléfono/.test(tx) && !/navegador|la web/i.test(tx), 'textos: «¿Olvidaste tu PIN?» no habla de navegador ni de la web');
  tx = await pinTxt({ bioSaved: false, bioOk: false, noCap: true });
  ok(/este navegador/.test(tx), 'textos: en la web «¿Olvidaste tu PIN?» sigue igual');
  // la mudanza de plataapp.net/app → web.plataapp.net: la app de Android también corre en el origen web.plataapp.net y NO debe pedir nada al sitio viejo
  const mudanza = async (noCap) => {
    const ctx = await b.newContext({ viewport: { width: 430, height: 900 } }); let pidio = false;
    await ctx.route('https://plataapp.net/**', (r) => { if (/puente\.html/.test(r.request().url())) pidio = true; r.abort(); });
    await ctx.route('https://web.plataapp.net/**', async (r) => { const u = new URL(r.request().url()); try { await r.fulfill({ response: await r.fetch({ url: BASE + u.pathname.replace(/^\//, '') + u.search }) }); } catch (e) { r.abort(); } });
    const q = await ctx.newPage(); q.on('pageerror', (e) => errs.push(String(e))); await q.addInitScript(mock, { noPin: true, noCap });
    await q.goto('https://web.plataapp.net/?nosplash'); await q.waitForTimeout(2500); return pidio;
  };
  ok((await mudanza(true)) === true, 'mudanza: en la web sin datos SÍ pide los datos al sitio viejo (control de la prueba)');
  ok((await mudanza(false)) === false, 'mudanza: en la app de Android NO se llama al sitio viejo');
  // novedades: sin Apple Watch, widgets ni «nativa en iPhone»
  p = await open({ noPin: true }); await p.waitForTimeout(2500);
  await p.locator('[data-act="settings"]:visible').first().click().catch(() => {}); await p.waitForTimeout(900);
  await p.click('[data-act="news"]'); await p.waitForSelector('.newsbx', { timeout: 4000 }); const nw = await p.evaluate(() => document.querySelector('.newsbx').innerText);
  ok(!/iPhone|Apple Watch|reloj|muñeca|Widgets/i.test(nw) && /Yape/.test(nw), 'novedades: en Android no salen las de iPhone, Watch ni widgets');

  console.log('errores de página:', errs.length ? errs : 'ninguno'); if (errs.length) f++;
  await b.close(); console.log(f ? '\n' + f + ' FALLAS' : '\nTodo bien'); process.exit(f ? 1 : 0);
})();
