// La app de iOS no manda la cabecera Origin (no es un navegador). Entra, fija la llave, sube y baja una copia y pide aprobar un dispositivo, todo SIN Origin.
// Requiere servidor-local.mjs corriendo.
import { webcrypto as C } from 'node:crypto';
const A = 'http://localhost:8787'; let f = 0;
const ok = (c, m) => { console.log((c ? 'OK    ' : 'FALLA ') + m); if (!c) f++; };
const j = async (p, m, b, h) => { const r = await fetch(A + p, { method: m || 'GET', headers: Object.assign({ 'Content-Type': 'application/json', 'X-Test-IP': '30.0.0.1' }, h || {}), body: b ? JSON.stringify(b) : undefined }); let x = {}; try { x = await r.json(); } catch (e) { /* sin cuerpo */ } return { s: r.status, j: x }; };
const lastCode = async (to) => { const m = (await (await fetch(A + '/__mails?to=' + to)).json()).pop(); return m.text.match(/(\d{3}) (\d{3})/).slice(1).join(''); };
const b64 = (n) => Buffer.from(C.getRandomValues(new Uint8Array(n))).toString('base64url');

const em = 'carla@prueba.co';
const st = await j('/auth/start', 'POST', { email: em, lang: 'es' });
ok(st.s === 200, 'auth/start sin Origin (' + st.s + ')');
const v = await j('/auth/verify', 'POST', { email: em, code: await lastCode(em), dev: 'iPhone · app' });
ok(v.s === 200 && v.j.token, 'auth/verify sin Origin devuelve token');
const H = { Authorization: 'Bearer ' + v.j.token }, wk = b64(32);
ok((await j('/me/key', 'PUT', { kc: 'k'.repeat(43) }, { ...H, 'X-Plata-Write': wk })).s === 200, 'me/key sin Origin');
ok((await j('/sync', 'PUT', { base: 0, next: 1, blob: 'AAAA', v: 2, dev: 'iPhone · app', demo: false }, { ...H, 'X-Plata-Write': wk })).s === 200, 'PUT /sync sin Origin');
const g = await j('/sync', 'GET', null, { ...H, 'X-Plata-Write': wk });
ok(g.s === 200 && g.j.rev === 1 && g.j.dev === 'iPhone · app', 'GET /sync sin Origin devuelve la copia y el dispositivo («iPhone · app»)');
ok((await j('/link/pending', 'GET', null, { ...H, 'X-Plata-Write': wk })).s === 200, 'link/pending sin Origin');
const ls = await j('/link/start', 'POST', { email: em, pub: b64(65), rid: b64(24), plat: 'iPad · app', tz: 'America/Lima', lang: 'es' });
ok(ls.s === 200, 'link/start sin Origin (' + ls.s + ')');
const mail = (await (await fetch(A + '/__mails?to=' + em)).json()).pop();
ok(/iPad/.test(mail.html || mail.text || ''), 'el correo de la solicitud nombra a «iPad»');
ok((await j('/auth/logout-all', 'POST', { dev: 'iPhone · app' }, { ...H, 'X-Plata-Write': wk })).s === 200, 'logout-all sin Origin');
// un navegador de un origen ajeno SÍ se sigue rechazando
const bad = await j('/auth/start', 'POST', { email: em }, { Origin: 'https://malo.example' });
ok(bad.s === 403, 'un origen de navegador ajeno sigue rechazado (' + bad.s + ')');
console.log(f ? 'FALLARON ' + f : 'TODO BIEN'); process.exit(f ? 1 : 0);
