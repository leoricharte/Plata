// Pruebas de seguridad del servidor contra el worker real (servidor-local.mjs en :8787). Cada prueba imprime OK/FALLA.
import { webcrypto as C, createHash } from 'node:crypto';
const A = 'http://localhost:8787', O = { Origin: 'http://localhost:8770' }; let fails = 0;
const ok = (c, m) => { console.log((c ? 'OK    ' : 'FALLA ') + m); if (!c) fails++; };
const j = async (p, m, b, h) => { const r = await fetch(A + p, { method: m || 'GET', headers: Object.assign({ 'Content-Type': 'application/json' }, O, h || {}), body: b ? JSON.stringify(b) : undefined }); let x = {}; try { x = await r.json(); } catch (e) {} return { s: r.status, j: x }; };
const mails = async (to) => (await (await fetch(A + '/__mails?to=' + to)).json());
const lastCode = async (to) => { const m = (await mails(to)).pop(); return m && (m.text.match(/(\d{3}) (\d{3})/) || []).slice(1).join(''); };
const login = async (email, ip) => { await j('/auth/start', 'POST', { email }, { 'X-Test-IP': ip || '9.9.9.9' }); const code = await lastCode(email); const r = await j('/auth/verify', 'POST', { email, code }, { 'X-Test-IP': ip || '9.9.9.9' }); return r.j.token; };
const b64u = (u) => Buffer.from(u).toString('base64url');

// 1) Carrera contra el código de 6 dígitos
await j('/auth/start', 'POST', { email: 'ana@prueba.co' }, { 'X-Test-IP': '1.1.1.1' });
const code = await lastCode('ana@prueba.co');
const guesses = Array.from({ length: 300 }, (_, i) => i === 250 ? code : String((Number(code) + 1 + i) % 1e6).padStart(6, '0'));
const rs = await Promise.all(guesses.map((g, i) => j('/auth/verify', 'POST', { email: 'ana@prueba.co', code: g }, { 'X-Test-IP': '2.2.' + (i % 250) + '.1' })));
ok(!rs.some((r) => r.j.token), '300 intentos en paralelo (el correcto en el #251) no entran: ' + rs.filter((r) => r.s === 400).length + ' rechazados');
ok([400, 429].includes((await j('/auth/verify', 'POST', { email: 'ana@prueba.co', code }, { 'X-Test-IP': '3.3.3.3' })).s), 'tras 5 fallos, ni el código correcto sirve');

// 2) Cuenta nueva con llave de escritura
const tok = await login('beto@prueba.co'); ok(!!tok, 'inicio de sesión normal funciona');
const H = { Authorization: 'Bearer ' + tok }, wk = b64u(C.getRandomValues(new Uint8Array(32))), kc = b64u(C.getRandomValues(new Uint8Array(32)));
ok((await j('/me/key', 'PUT', { kc }, H)).s === 403, '/me/key sin llave de escritura → 403');
ok((await j('/me/key', 'PUT', { kc }, { ...H, 'X-Plata-Write': wk })).s === 200, '/me/key con llave de escritura → 200');
let g = await j('/sync', 'GET', null, H); ok(g.j.rev === 0 && g.j.next === 1, 'GET /sync informa la próxima revisión (next=1)');
ok((await j('/sync', 'PUT', { base: 0, next: 1, blob: 'AAAA' }, H)).s === 403, 'PUT /sync sin llave de escritura (solo con el correo) → 403');
ok((await j('/sync', 'PUT', { base: 0, next: 1, blob: 'AAAA' }, { ...H, 'X-Plata-Write': b64u(C.getRandomValues(new Uint8Array(32))) })).s === 403, 'PUT /sync con otra llave → 403');
ok((await j('/sync', 'PUT', { base: 0, next: 1, blob: 'AAAA' }, { ...H, 'X-Plata-Write': wk })).s === 200, 'PUT /sync con la llave correcta → 200 (rev 1)');
ok((await j('/sync', 'PUT', { base: 1, next: 5, blob: 'BBBB' }, { ...H, 'X-Plata-Write': wk })).s === 409, 'PUT con una revisión cifrada que no corresponde → 409');
ok((await j('/sync', 'DELETE', null, H)).s === 403, 'DELETE /sync solo con el correo → 403');
ok((await j('/sync', 'DELETE', null, { ...H, 'X-Plata-Write': wk })).s === 200, 'DELETE /sync con la llave → 200');
g = await j('/sync', 'GET', null, H); ok(g.j.rev === 0 && g.j.next === 2, 'después de borrar, la revisión no retrocede (next=2)');

// 3) Cerrar sesión en todos los dispositivos
const tok2 = await login('beto@prueba.co', '9.9.9.8');
ok((await j('/auth/logout-all', 'POST', {}, { Authorization: 'Bearer ' + tok2 })).s === 403, 'logout-all solo con el correo → 403');
const la = await j('/auth/logout-all', 'POST', {}, { ...H, 'X-Plata-Write': wk });
ok(la.s === 200 && !!la.j.token, 'logout-all con la llave → 200 y token nuevo');
ok((await j('/me', 'GET', null, { Authorization: 'Bearer ' + tok2 })).s === 401, 'la otra sesión quedó cerrada');
ok((await j('/me', 'GET', null, { Authorization: 'Bearer ' + la.j.token })).s === 200, 'la sesión nueva funciona');

// 4) Administración
const ses = async (tk, ip) => (await j('/admin/session', 'POST', null, { Authorization: 'Bearer ' + tk, Origin: 'https://dev-estudio22.pages.dev', 'X-Test-IP': ip || '5.5.5.5' })).j.session;
const AD = { Authorization: 'Bearer ' + await ses('a'.repeat(40)) };
ok((await j('/review/list', 'GET', null, { ...AD, Origin: 'https://plataapp.net' })).s === 403, 'token de admin usado desde plataapp.net → 403');
ok((await j('/review/list', 'GET', null, { ...AD, Origin: 'https://dev-estudio22.pages.dev' })).s === 200, 'token de admin desde el panel → 200');
const AH = { ...AD, Origin: 'https://dev-estudio22.pages.dev' };
ok((await j('/content', 'POST', { k: 'abcdef12', es: '<img src=x onerror=alert(1)>', en: 'x' }, AH)).j.error === 'html', 'texto con <img onerror> → rechazado');
ok((await j('/content', 'POST', { k: 'abcdef12', es: '<a href="javascript:alert(1)">x</a>', en: 'x' }, AH)).j.error === 'html', 'enlace javascript: → rechazado');
ok((await j('/content', 'POST', { k: 'abcdef12', es: 'Hola <b>mundo</b>, lee <a href="ayuda.html">ayuda</a> o <a href=\'https://x.co\'>esto</a>.<br>', en: 'Hi' }, AH)).s === 200, 'formato permitido → 200');
for (let i = 0; i < 5; i++) await j('/review/list', 'GET', null, { Authorization: 'Bearer malo', 'X-Test-IP': '7.7.7.7', Origin: 'https://dev-estudio22.pages.dev' });
ok((await j('/review/list', 'GET', null, { ...AH, 'X-Test-IP': '7.7.7.7' })).s === 429, 'tras 5 tokens malos desde una IP → bloqueo 429');

// 5) Copias para análisis: no se aceptan conteos fabricados como HTML (se guardan, pero el panel solo usa números) y caducan
const rv = await j('/review', 'POST', { build: 1, plat: 'x', data: { transactions: { length: '<img src=x onerror=alert(1)>' } } }, { 'X-Test-IP': '6.6.6.6' });
ok(rv.s === 200, 'POST /review sigue aceptando copias (el panel es quien no las interpreta como HTML)');

// 6) Aprobación de dispositivo: un tercero sin sesión no puede avanzar el protocolo
const r0 = await j('/link/step', 'POST', { step: 'commit', pub: 'x'.repeat(80), c: 'y'.repeat(43) }); ok(r0.s === 401, '/link/step sin sesión → 401');
console.log(fails ? '\n' + fails + ' FALLAS' : '\nTodo bien');
process.exit(fails ? 1 : 0);
