// Flujo de scroll Resumen ↔ Bentos en escritorio: al salir del Bento por cualquier camino (girar hacia arriba, Esc o el botón de cerrar)
// el Resumen debe quedar nítido: sin difuminado, sin achicarse y sin transparencia.
// Requiere Playwright y la web compilada:  sh dev/web/build.sh && (cd dist-web && python3 -m http.server 8791 &) && node dev/tests/bento-flujo.cjs http://localhost:8791/
const { chromium } = require('playwright');
const BASE = process.argv[2] || 'http://localhost:8791/';
let f = 0; const ok = (c, m) => { console.log((c ? 'OK    ' : 'FALLA ') + m); if (!c) f++; };
(async () => {
  const b = await chromium.launch(); const errs = [];
  const nuevo = async () => {
    const ctx = await b.newContext({ viewport: { width: 1440, height: 900 } }); const p = await ctx.newPage(); p.on('pageerror', (e) => errs.push(String(e)));
    await p.goto(BASE + '?demo=shawn&lang=es&nosplash'); await p.waitForTimeout(2500); await p.mouse.move(720, 450); return p;
  };
  const girar = async (p, dy, n) => { for (let i = 0; i < n; i++) { await p.mouse.wheel(0, dy); await p.waitForTimeout(60); } };
  const nitido = (p) => p.evaluate(() => { const m = document.querySelector('main'), s = getComputedStyle(m); return s.filter === 'none' && (s.transform === 'none' || s.transform === 'matrix(1, 0, 0, 1, 0, 0)') && s.opacity === '1'; });
  const abrir = async (p) => { await p.evaluate(() => { document.querySelectorAll('.screen').forEach((e) => { e.scrollTop = e.scrollHeight; }); const m = document.querySelector('main'); m.scrollTop = m.scrollHeight; }); await p.waitForTimeout(400); await girar(p, 120, 6); await p.waitForTimeout(900); return p.evaluate(() => !!document.getElementById('bento')); };

  // 1) Girar hacia abajo abre el Bento y el Resumen queda detrás, difuminado
  let p = await nuevo(); ok(await abrir(p), 'abrir: girar hacia abajo en el Resumen abre el Bento');
  ok(!(await nitido(p)), 'abrir: el Resumen queda detrás, difuminado');
  // 2) Girar hacia arriba lo cierra y todo vuelve nítido
  await girar(p, -120, 6); await p.waitForTimeout(1200);
  ok(!(await p.evaluate(() => !!document.getElementById('bento'))), 'girar arriba: el Bento se cierra');
  ok(await nitido(p), 'girar arriba: el Resumen queda nítido');
  // 3) Esc
  p = await nuevo(); await abrir(p); await p.keyboard.press('Escape'); await p.waitForTimeout(900);
  ok(!(await p.evaluate(() => !!document.getElementById('bento'))), 'Esc: el Bento se cierra');
  ok(await nitido(p), 'Esc: el Resumen queda nítido (no se queda difuminado)');
  // 4) Botón de cerrar
  p = await nuevo(); await abrir(p); const x = await p.$('[data-act="bnclose"]');
  if (x) { await x.click(); await p.waitForTimeout(900); ok(await nitido(p), 'botón cerrar: el Resumen queda nítido'); } else console.log('(sin botón bnclose visible: se omite)');
  // 5) Abrir, cerrar y volver a abrir rápido: nunca queda difuminado con el Bento ya cerrado
  p = await nuevo(); await abrir(p); await p.keyboard.press('Escape'); await p.waitForTimeout(100); await abrir(p); await p.keyboard.press('Escape'); await p.waitForTimeout(900);
  ok(await nitido(p), 'abrir/cerrar seguido: el Resumen queda nítido');
  // 6) Girar sin parar (arriba y abajo, con inercia): al final, con el Bento cerrado, el Resumen no queda difuminado
  p = await nuevo(); await p.evaluate(() => { document.querySelectorAll('.screen').forEach((e) => { e.scrollTop = e.scrollHeight; }); const m = document.querySelector('main'); m.scrollTop = m.scrollHeight; }); await p.waitForTimeout(400);
  for (let r = 0; r < 4; r++) { await girar(p, 120, 8); await p.waitForTimeout(150); await girar(p, -120, 8); await p.waitForTimeout(150); }
  await p.waitForTimeout(1500); if (await p.evaluate(() => !!document.getElementById('bento'))) { await girar(p, -120, 8); await p.waitForTimeout(1500); }
  const queda = await p.evaluate(() => !!document.getElementById('bento'));
  ok(queda || await nitido(p), 'girar sin parar: con el Bento cerrado el Resumen queda nítido' + (queda ? ' (el Bento quedó abierto: no aplica)' : ''));
  ok(!queda ? true : !(await nitido(p)), 'girar sin parar: si el Bento queda abierto, el Resumen sigue detrás de él');
  console.log('errores de página:', errs.length ? errs : 'ninguno'); if (errs.length) f++;
  await b.close(); console.log(f ? '\n' + f + ' FALLAS' : '\nTodo bien'); process.exit(f ? 1 : 0);
})();
