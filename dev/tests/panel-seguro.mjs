// Panel privado y administración: sesiones de 1 h, roles dev/mod, propuestas, /nazca cerrado. Requiere servidor-local.mjs en :8787 (reinícialo antes).
import { spawn } from 'node:child_process';
const A = 'http://localhost:8787', PANEL = 'https://plata-dev.pages.dev'; let fails = 0;
const ok = (c, m) => { console.log((c ? 'OK    ' : 'FALLA ') + m); if (!c) fails++; };
const j = async (p, m, b, h, base) => { const r = await fetch((base || A) + p, { method: m || 'GET', headers: Object.assign({ 'Content-Type': 'application/json' }, h || {}), body: b ? JSON.stringify(b) : undefined }); return { s: r.status, j: await r.json().catch(() => ({})) }; };
const DEV = 'a'.repeat(40), MOD = 'm'.repeat(40);
const mint = (tk, o, ip) => j('/admin/session', 'POST', null, { Authorization: 'Bearer ' + tk, Origin: o || PANEL, 'X-Test-IP': ip || '10.0.0.1' });
const as = (t, ip) => ({ Authorization: 'Bearer ' + t, Origin: PANEL, 'X-Test-IP': ip || '10.0.0.1' });

// 1) El token fijo ya no abre rutas: solo sirve para abrir sesión
ok((await j('/review/list', 'GET', null, as(DEV, '10.0.1.1'))).s === 401, 'ADMIN_TOKEN directo en /review/list → 401 (solo abre sesión)');
const d = await mint(DEV), m = await mint(MOD, PANEL, '10.0.0.2');
ok(d.s === 200 && d.j.role === 'dev' && d.j.session && d.j.session.length >= 40, 'ADMIN_TOKEN abre sesión con rol dev');
ok(m.s === 200 && m.j.role === 'mod', 'MOD_TOKEN abre sesión con rol mod');
const left = d.j.exp - Date.now(); ok(left > 3590e3 && left <= 3600e3, 'la sesión vence en 1 hora (' + Math.round(left / 1000) + ' s)');
ok((await mint(DEV, 'https://plataapp.net', '10.0.0.3')).s === 403, 'abrir sesión desde plataapp.net → 403');
ok((await mint('x'.repeat(40), PANEL, '10.0.0.4')).s === 401, 'token incorrecto → 401');
ok((await mint('', PANEL, '10.0.0.5')).s === 401, 'sin token → 401');

// 2) Roles
const D = d.j.session, M = m.j.session;
ok((await j('/review/list', 'GET', null, as(D))).s === 200, 'sesión dev: /review/list → 200');
ok((await j('/nazca/list', 'GET', null, as(D))).s === 200, 'sesión dev: /nazca/list → 200');
for (const [p, mt] of [['/review/list', 'GET'], ['/nazca/list', 'GET'], ['/waitlist/export', 'GET'], ['/admin/invite', 'POST'], ['/admin/proposals', 'GET']]) ok((await j(p, mt, mt === 'POST' ? {} : null, as(M, '10.0.0.2'))).s === 403, 'sesión mod: ' + p + ' → 403');
ok((await j('/content/ping', 'GET', null, as(M, '10.0.0.2'))).s === 200, 'sesión mod: /content/ping → 200');
ok((await j('/review/list', 'GET', null, as('z'.repeat(43), '10.0.0.6'))).s === 401, 'sesión inventada → 401');

// 3) Cerrar sesión la revoca en el servidor
const d2 = await mint(DEV, PANEL, '10.0.0.7'); const D2 = d2.j.session;
ok((await j('/review/list', 'GET', null, as(D2, '10.0.0.7'))).s === 200, 'segunda sesión dev funciona');
await j('/admin/logout', 'POST', {}, as(D2, '10.0.0.7'));
ok((await j('/review/list', 'GET', null, as(D2, '10.0.0.7'))).s === 401, 'tras /admin/logout la sesión ya no sirve');
ok((await j('/review/list', 'GET', null, as(D))).s === 200, 'las demás sesiones siguen');

// 4) El rol mod propone; un dev aprueba
const K = 'abcdef12', body = { k: K, es: 'Texto <b>nuevo</b>', en: 'New text', orig: 'x' };
const pr = await j('/content', 'POST', body, as(M, '10.0.0.2'));
ok(pr.s === 202 && pr.j.proposed, 'mod: POST /content → 202 (propuesta, no se publica)');
ok(!((await j('/content', 'GET')).j.items || {})[K], 'el texto NO está publicado todavía');
const lst = await j('/admin/proposals', 'GET', null, as(D)); const it = (lst.j.items || []).find((x) => x.id === pr.j.id);
ok(it && it.kind === 'content' && it.b.es === body.es, 'dev ve la propuesta con su contenido');
const bad = await j('/content', 'POST', { k: '12345678', es: '<img src=x onerror=alert(1)>', en: 'x' }, as(M, '10.0.0.2'));
ok(bad.s === 202, 'mod propone HTML peligroso (se guarda como propuesta)');
const ap = await j('/admin/proposals/decide?id=' + pr.j.id + '&do=approve', 'POST', {}, as(D));
ok(ap.s === 200 && ((await j('/content', 'GET')).j.items || {})[K], 'dev aprueba → el texto se publica');
const ap2 = await j('/admin/proposals/decide?id=' + bad.j.id + '&do=approve', 'POST', {}, as(D));
ok(ap2.s === 400 && ap2.j.error === 'html', 'aprobar el HTML peligroso → 400 (los controles de siempre siguen)');
ok((await j('/admin/proposals/decide?id=' + bad.j.id + '&do=reject', 'POST', {}, as(D))).s === 200, 'dev rechaza la propuesta');
ok((await j('/admin/proposals', 'GET', null, as(D))).j.count === 0, 'ya no quedan propuestas');
ok((await j('/admin/proposals/decide?id=' + pr.j.id + '&do=approve', 'POST', {}, as(M, '10.0.0.2'))).s === 403, 'mod no puede aprobar');
const dv = await j('/content', 'POST', { k: 'fedcba98', es: 'Directo', en: 'Direct', orig: 'y' }, as(D));
ok(dv.s === 200, 'dev publica directo (200)');
ok((await j('/posts', 'POST', { date: '2026-10-27', title_es: 'Hola', body_es: 'Cuerpo', by: 'Mod' }, as(M, '10.0.0.2'))).s === 202, 'mod: artículo de Novedades → propuesta');
ok(((await j('/posts', 'GET')).j.posts || []).length === 0, 'el artículo propuesto NO aparece en Novedades');

// 5) /nazca: solo archivos de verdad, con topes propios
const b64 = (s) => Buffer.from(s, 'latin1').toString('base64');
const nz = (kind, data, ip) => j('/nazca', 'POST', { v: 1, build: 1, plat: 't', kind, bank: '', why: '', b64: b64(data) }, { 'X-Test-IP': ip }, A);
ok((await nz('otro', '%PDF-1.4 x', '20.0.0.1')).s === 400, '/nazca: tipo «otro» → 400');
ok((await nz('pdf', 'MZ\x90\x00 ejecutable', '20.0.0.1')).s === 400, '/nazca: «pdf» que no es PDF → 400');
ok((await nz('xlsx', '%PDF-1.4 x', '20.0.0.1')).s === 400, '/nazca: «xlsx» que no es zip → 400');
ok((await nz('csv', 'MZ\x90\x00 ejecutable', '20.0.0.1')).s === 400, '/nazca: «csv» con cabecera de ejecutable → 400');
ok((await nz('csv', 'a,b\x00c', '20.0.0.1')).s === 400, '/nazca: «csv» con bytes nulos → 400');
ok((await nz('pdf', '%PDF-1.4 hola', '20.0.0.2')).s === 200, '/nazca: PDF real → 200');
ok((await nz('csv', 'fecha,monto\n2026-01-01,10\n', '20.0.0.2')).s === 200, '/nazca: CSV real → 200');
ok((await nz('xlsx', 'PK\x03\x04 resto', '20.0.0.2')).s === 200, '/nazca: XLSX (zip) → 200');
let last; for (let i = 0; i < 4; i++) last = await nz('pdf', '%PDF-1.4 n' + i, '20.0.0.2');
ok(last.s === 429, '/nazca: el 6.º envío del día desde una conexión → 429');
let g = 0; for (let i = 0; i < 70; i++) { const r = await nz('pdf', '%PDF-1.4 g' + i, '30.0.' + i + '.1'); if (r.s === 200) g++; }
ok(g > 0 && g < 70, '/nazca: tope global del día corta los envíos (' + g + ' aceptados de 70)');
let h12 = 0; for (let i = 0; i < 15; i++) { const r = await nz('otro', 'x', '40.0.0.1'); if (r.s === 429) h12++; }
ok(h12 > 0, '/nazca: más de 12 intentos por hora desde una conexión → 429 aunque sean inválidos');

// 6) Sin RL_SALT el servidor falla cerrado
const ch = spawn('node', [new URL('./servidor-local.mjs', import.meta.url).pathname], { env: Object.assign({}, process.env, { NOSALT: '1', PORT: '8791' }), stdio: 'ignore' });
await new Promise((r) => setTimeout(r, 1500));
const ns = await j('/nazca', 'POST', { kind: 'pdf', b64: b64('%PDF-1') }, {}, 'http://localhost:8791');
ok(ns.s === 503 && ns.j.error === 'config', 'sin RL_SALT: /nazca → 503 config (no usa una sal conocida)');
ch.kill();
console.log(fails ? '\n' + fails + ' FALLAS' : '\nTodo bien');
process.exit(fails ? 1 : 0);
