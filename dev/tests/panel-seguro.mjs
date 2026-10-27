// Panel privado y administración: sesiones de 1 h, roles dev/mod, propuestas, /nazca cerrado. Requiere servidor-local.mjs en :8787 (reinícialo antes).
import { spawn } from 'node:child_process';
const A = 'http://localhost:8787', PANEL = 'https://dev-estudio22.pages.dev'; let fails = 0;
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

// 4b) Personas con token propio + registro de auditoría
const cu = await j('/admin/users', 'POST', { name: 'Ana Prueba', role: 'mod', title: 'Editora <b>de</b> contenido' }, as(D));
const AT = cu.j.token;
ok(cu.s === 200 && /^plt_[A-Za-z0-9_-]{6,12}\.[A-Za-z0-9_-]{30,}$/.test(AT || ''), 'dev crea a Ana (mod): recibe un token personal una sola vez');
const ul = await j('/admin/users', 'GET', null, as(D));
ok(ul.j.items.some((x) => x.name === 'Ana Prueba' && x.role === 'mod') && !JSON.stringify(ul.j).includes('"h"') && !JSON.stringify(ul.j).includes(AT), 'la lista no trae el token ni su hash');
ok((await j('/admin/users', 'POST', { name: 'X', role: 'mod' }, as(M, '10.0.0.2'))).s === 403, 'mod no puede crear personas');
ok((await j('/admin/audit', 'GET', null, as(M, '10.0.0.2'))).s === 403, 'mod no puede leer el registro');
const am = await mint(AT, PANEL, '10.0.8.1');
ok(am.s === 200 && am.j.role === 'mod' && am.j.name === 'Ana Prueba', 'el token de Ana abre sesión: rol mod y nombre');
ok(/^Editora/.test(am.j.title) && !/[<>]/.test(am.j.title), 'la sesión trae el cargo que le asignó el dev, sin marcas HTML');
ok((await j('/admin/users', 'GET', null, as(D))).j.items.some((x) => x.id === cu.j.id && /^Editora/.test(x.title)), 'la lista de Equipo muestra el cargo');
const ct = await j('/admin/users/title?id=' + cu.j.id, 'POST', { title: 'Coordinadora' }, as(D));
ok(ct.s === 200 && ct.j.title === 'Coordinadora', 'el dev cambia el cargo de Ana');
ok((await j('/admin/users/title?id=' + cu.j.id, 'POST', { title: 'CEO' }, as(M, '10.0.0.2'))).s === 403, 'un mod no puede asignar cargos');
ok((await mint(AT, PANEL, '10.0.8.9')).j.title === 'Coordinadora', 'la sesión nueva ya trae el cargo actualizado');
const AS = am.j.session;
ok((await mint(AT.slice(0, -3) + 'aaa', PANEL, '10.0.8.2')).s === 401, 'token con el id correcto y el secreto equivocado → 401');
const pa = await j('/content', 'POST', { k: 'a1b2c3d4', es: 'Cambio de Ana', en: 'Ana change', orig: 'o' }, as(AS, '10.0.8.1'));
ok(pa.s === 202, 'Ana propone un cambio (202)');
const aps = await j('/admin/proposals', 'GET', null, as(D));
ok((aps.j.items.find((x) => x.id === pa.j.id) || {}).by === 'Ana Prueba', 'la propuesta dice que viene de Ana');
await j('/admin/proposals/decide?id=' + pa.j.id + '&do=approve', 'POST', {}, as(D));
const rv = await j('/admin/users/revoke?id=' + cu.j.id, 'POST', {}, as(D));
ok(rv.s === 200 && (await j('/content/ping', 'GET', null, as(AS, '10.0.8.1'))).s === 401, 'al revocar a Ana, su sesión abierta deja de servir al instante');
ok((await mint(AT, PANEL, '10.0.8.3')).s === 401, 'y su token ya no abre sesión nueva');
await j('/admin/users/revoke?id=' + cu.j.id + '&undo=1', 'POST', {}, as(D));
ok((await mint(AT, PANEL, '10.0.8.4')).s === 200, 'reactivarla le devuelve el acceso');
// 4c) Auditor: solo lectura, y sin abrir datos de usuarios
const ca = await j('/admin/users', 'POST', { name: 'Aldo Auditor', title: 'Auditoría externa', role: 'aud' }, as(D));
ok(ca.s === 200, 'dev crea a un auditor');
const aa = await mint(ca.j.token, PANEL, '10.0.9.1'); const AU = aa.j.session;
ok(aa.s === 200 && aa.j.role === 'aud' && aa.j.title === 'Auditoría externa', 'el auditor abre sesión con rol aud y su cargo');
for (const pth of ['/admin/users', '/admin/audit', '/admin/proposals', '/nazca/list', '/review/list', '/content/ping', '/admin/board']) ok((await j(pth, 'GET', null, as(AU, '10.0.9.1'))).s === 200, 'auditor puede leer ' + pth);
for (const [pth, mt, bd] of [['/admin/users', 'POST', { name: 'Z', role: 'dev' }], ['/admin/users/revoke?id=' + cu.j.id, 'POST', {}], ['/admin/users/title?id=' + cu.j.id, 'POST', { title: 'x' }], ['/content', 'POST', { k: 'a1b2c3d4', es: 'x', en: 'x', orig: 'o' }], ['/posts', 'POST', { date: '2026-10-27', title_es: 'x', body_es: 'y', by: 'z' }], ['/admin/proposals/decide?id=zzzzzzzz&do=approve', 'POST', {}], ['/review/mark', 'POST', {}], ['/admin/invite', 'POST', {}], ['/nazca/delete', 'POST', {}], ['/admin/board', 'POST', { type: 'note', title: 'x' }]]) {
  const r = await j(pth, mt, bd, as(AU, '10.0.9.1')); ok(r.s === 403 && r.j.error === 'readonly', 'auditor NO puede ' + mt + ' ' + pth.split('?')[0] + ' (403 readonly)');
}
for (const pth of ['/review/get?id=aaaaaaaa', '/nazca/get?id=aaaaaaaa', '/waitlist/export']) ok((await j(pth, 'GET', null, as(AU, '10.0.9.1'))).s === 403, 'auditor no abre datos de usuarios: ' + pth.split('?')[0]);
ok((await j('/review/list', 'GET', null, as(M, '10.0.0.2'))).s === 403, 'el mod sigue sin ver copias');
// 4d) Proyecto: notas, hitos, ideas, comentarios
const bn = await j('/admin/board', 'POST', { type: 'note', title: 'Revisar el token\u0007 de Resend', body: 'Línea 1\nLínea 2 con <b> y \u0000nulo', pin: true }, as(D));
ok(bn.s === 200 && bn.j.item.title === 'Revisar el token de Resend' && !/[\u0000-\u0008]/.test(bn.j.item.body) && bn.j.item.body.includes('\n') && bn.j.item.pin === true, 'crear nota: limpia caracteres de control y conserva saltos de línea');
const be = await j('/admin/board', 'POST', { type: 'event', title: 'Lanzar beta 3', date: '2026-11-15', status: 'doing' }, as(D));
ok(be.s === 200 && be.j.item.st === 'doing' && be.j.item.date === '2026-11-15', 'crear hito con fecha y estado');
ok((await j('/admin/board', 'POST', { type: 'event', title: 'Sin fecha' }, as(D))).s === 400, 'un hito sin fecha → 400');
ok((await j('/admin/board', 'POST', { type: 'idea', title: 'x', status: 'raro' }, as(D))).s === 400, 'estado inválido → 400');
ok((await j('/admin/board', 'POST', { type: 'otro', title: 'x' }, as(D))).s === 400, 'tipo inválido → 400');
const bi = await j('/admin/board', 'POST', { type: 'idea', title: 'Widget de gastos' }, as(D));
ok(bi.s === 200 && bi.j.item.st === 'new', 'crear idea (estado inicial: nueva)');
const bc = await j('/admin/board/comment?id=' + bi.j.id, 'POST', { txt: 'Me gusta, pero chiquito' }, as(D));
ok(bc.s === 200 && bc.j.comment.by === 'root', 'comentar una idea: queda a nombre de quien comentó');
ok((await j('/admin/board/comment?id=' + bi.j.id, 'POST', { txt: '   ' }, as(D))).s === 400, 'comentario vacío → 400');
ok((await j('/admin/board/vote?id=' + bi.j.id, 'POST', {}, as(D))).j.mine === true && (await j('/admin/board/vote?id=' + bi.j.id, 'POST', {}, as(D))).j.mine === false, 'votar y quitar el voto');
ok((await j('/admin/board/vote?id=' + bn.j.id, 'POST', {}, as(D))).s === 404, 'solo las ideas se votan');
const bl = await j('/admin/board', 'GET', null, as(D));
ok(bl.j.items.length === 3 && bl.j.items.find((x) => x.id === bi.j.id).com.length === 1, 'el tablero lista los 3 ítems con sus comentarios');
const bu = await j('/admin/board', 'POST', { id: bi.j.id, title: 'Widget de gastos v2', status: 'keep' }, as(D));
ok(bu.s === 200 && bu.j.item.type === 'idea' && bu.j.item.com.length === 1 && bu.j.item.title.endsWith('v2'), 'editar conserva el tipo y los comentarios');
ok((await j('/admin/board', 'GET', null, as(M, '10.0.0.2'))).s === 403 && (await j('/admin/board', 'POST', { type: 'note', title: 'x' }, as(M, '10.0.0.2'))).s === 403, 'el mod no entra al tablero');
ok((await j('/admin/board/comment?id=' + bi.j.id + '&cid=' + bc.j.comment.i, 'DELETE', null, as(D))).s === 200, 'borrar un comentario');
ok((await j('/admin/board?id=' + bn.j.id, 'DELETE', null, as(D))).s === 200 && (await j('/admin/board?id=' + bn.j.id, 'DELETE', null, as(D))).s === 404, 'borrar una nota (y no existe después)');
ok((await j('/admin/board?id=' + bn.j.id, 'DELETE', null, as(AU, '10.0.9.1'))).s === 403, 'el auditor no puede borrar');
// 4e) Base de Nazca: extracciones ya enmascaradas
const ext = { v: 1, source: 'panel', pages: [{ w: 595, h: 842, items: [{ str: 'BANCO EJEMPLO', x: 40, y: 800, w: 90 }, { str: 'SALDO', x: 40, y: 780, w: 30 }] }] };
const nz1 = await j('/admin/nazca/lib', 'POST', { name: 'interbank-tarjeta-sep', bank: 'interbank', want: 'ok', note: 'no cuadra el total\u0007', data: ext }, as(D));
ok(nz1.s === 200 && nz1.j.id, 'dev añade un caso a la base de Nazca');
for (const [why, bd] of [['sin nombre', { name: '', want: 'ok', data: ext }], ['«want» inválido', { name: 'x', want: 'si', data: ext }], ['sin páginas', { name: 'x', want: 'ok', data: { v: 1, pages: [] } }], ['con un archivo en vez de extracción', { name: 'x', want: 'ok', data: 'JVBERi0xLjQ=' }], ['texto demasiado largo', { name: 'x', want: 'ok', data: { v: 1, pages: [{ w: 1, h: 1, items: [{ str: 'a'.repeat(401), x: 0, y: 0, w: 1 }] }] } }], ['coordenada no numérica', { name: 'x', want: 'ok', data: { v: 1, pages: [{ w: 1, h: 1, items: [{ str: 'a', x: 'x', y: 0, w: 1 }] }] } }]]) ok((await j('/admin/nazca/lib', 'POST', bd, as(D))).s === 400, 'base de Nazca: rechaza ' + why);
const nzl = await j('/admin/nazca/lib', 'GET', null, as(D));
ok(nzl.j.items.length === 1 && nzl.j.items[0].bank === 'interbank' && nzl.j.items[0].want === 'ok' && !/\u0007/.test(nzl.j.items[0].note) && !('data' in nzl.j.items[0]), 'la lista trae metadatos limpios y no el contenido');
const nzg = await j('/admin/nazca/lib/get?id=' + nz1.j.id, 'GET', null, as(D));
ok(nzg.s === 200 && nzg.j.data.pages[0].items.length === 2 && !('source' in nzg.j.data), 'abrir un caso devuelve solo la extracción (sin campos de más)');
ok((await j('/admin/nazca/lib', 'GET', null, as(AU, '10.0.9.1'))).s === 200, 'el auditor ve la lista de casos');
ok((await j('/admin/nazca/lib/get?id=' + nz1.j.id, 'GET', null, as(AU, '10.0.9.1'))).s === 403, 'el auditor no abre el contenido de un caso');
ok((await j('/admin/nazca/lib', 'POST', { name: 'x', want: 'ok', data: ext }, as(AU, '10.0.9.1'))).s === 403 && (await j('/admin/nazca/lib?id=' + nz1.j.id, 'DELETE', null, as(AU, '10.0.9.1'))).s === 403, 'el auditor no añade ni borra');
ok((await j('/admin/nazca/lib', 'GET', null, as(M, '10.0.0.2'))).s === 403, 'el mod no entra a la base de Nazca');
ok((await j('/admin/nazca/lib?id=' + nz1.j.id, 'DELETE', null, as(D))).s === 200 && (await j('/admin/nazca/lib?id=' + nz1.j.id, 'DELETE', null, as(D))).s === 404, 'borrar un caso (y ya no existe)');
const au = await j('/admin/audit?n=200', 'GET', null, as(D)); const ev = au.j.items || [];
const has = (act, who) => ev.some((e) => e.act === act && (!who || e.who === who));
ok(has('entrada', 'Ana Prueba') && has('entrada', 'root') && has('entrada', 'mod compartido'), 'registro: entradas de Ana, root y mod compartido');
ok(has('entrada fallida') && has('crear persona', 'root') && has('revocar persona', 'root') && has('proponer content', 'Ana Prueba'), 'registro: entrada fallida, crear/revocar persona y propuesta de Ana');
ok(has('aprobar propuesta', 'root') && has('guardar texto', 'root'), 'registro: la aprobación y el guardado quedan a nombre de quien aprobó');
ok(has('salida', 'root'), 'registro: salida');
ok(!JSON.stringify(ev).includes(AT) && !JSON.stringify(ev).includes(DEV) && !JSON.stringify(ev).includes('plt_'), 'el registro no contiene tokens');
ok(ev.every((e) => e.t && e.ip && e.ip.length === 8), 'cada evento trae hora y una huella corta de la conexión (sin IP)');
await j('/review/get?id=nada', 'GET', null, as(D)); await j('/nazca/delete?id=nada', 'POST', {}, as(D));
const au2 = (await j('/admin/audit', 'GET', null, as(D))).j.items;
ok(au2.some((e) => e.act === 'ver review/get') && au2.some((e) => e.act === 'nazca/delete'), 'registro: ver una copia y borrar un envío de Nazca');

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
