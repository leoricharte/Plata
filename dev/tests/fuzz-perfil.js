// Fuzz de XSS: cada texto de un perfil se reemplaza por HTML malicioso con su ruta; se recorren pestañas y hojas y se anota qué se ejecutó.
// Uso: node dev/tests/fuzz-perfil.js http://localhost:8770/app/   (requiere Playwright). Debe terminar con HITS 0.
const { chromium } = require('playwright');
const APP = process.argv[2] || 'http://localhost:8770/app/';
const SKIP = new Set(['id','acc','card','pair','job','from','to','next','until','date','start','end','jstart','firstHalf','mk','c','t','an','at']);
(async () => {
  const b = await chromium.launch(); const hits = new Set();
  for (const vp of [{ width: 390, height: 844 }, { width: 1440, height: 900 }]) {
    const p = await b.newPage({ viewport: vp });
    await p.exposeFunction('__hit', (x) => hits.add(x));
    await p.addInitScript(() => { window.__h = (x) => window.__hit(x); });
    p.on('dialog', d => d.dismiss());
    await p.goto(APP + '?demo=alessandro'); await p.waitForTimeout(2500);
    await p.evaluate((SKIP) => {
      const SK = new Set(SKIP), o = JSON.parse(localStorage.getItem('finanzas.v3'));
      const today = new Date().toISOString().slice(0, 10);
      const walk = (v, path, key) => {
        if (typeof v === 'string') { if (SK.has(key) || /^\d{4}-\d{2}/.test(v)) return v; return '"\'><img src=x onerror=__h("' + path.replace(/[^\w.\[\]]/g, '') + '")>'; }
        if (Array.isArray(v)) return v.map((x, i) => walk(x, path + '[' + i + ']', key));
        if (v && typeof v === 'object') { const r = {}; for (const k of Object.keys(v)) r[k] = walk(v[k], path + '.' + k, k); return r; }
        return v;
      };
      const f = walk(o, 'p', '');
      // movimientos de hoy para que todo aparezca en el mes actual
      f.transactions.slice(-15).forEach((t) => { t.date = today; });
      delete f.demo; localStorage.setItem('finanzas.v3', JSON.stringify(f));
    }, [...SKIP]);
    await p.goto(APP); await p.waitForTimeout(2500);
    for (const tab of ['resumen', 'movimientos', 'presupuesto', 'proyeccion', 'ahorro', 'deuda', 'cuenta']) {
      await p.evaluate((t) => { try { setTab(t); } catch (e) {} }, tab); await p.waitForTimeout(500);
      const acts = await p.evaluate(() => [...new Set([...document.querySelectorAll('[data-act]')].map(e => e.getAttribute('data-act')))].filter(a => !/del|wipe|reset|clear|demo|logout|cl:|save|load|tab:|lang|theme/.test(a)).slice(0, 60));
      for (const a of acts) {
        await p.evaluate((a) => { const e = document.querySelector('[data-act="' + CSS.escape(a) + '"]'); if (e) e.click(); }, a).catch(() => {});
        await p.waitForTimeout(120);
        await p.keyboard.press('Escape').catch(() => {});
      }
      await p.evaluate((t) => { try { document.querySelectorAll('.sheet,.alertback,#alertback').forEach(e => e.remove()); setTab(t); } catch (e) {} }, tab);
    }
    await p.close();
  }
  console.log('HITS', hits.size); console.log([...hits].sort().join('\n'));
  await b.close();
})();
