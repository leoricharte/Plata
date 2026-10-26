// Pruebas de la segunda auditoría: tope diario de fallos, llave fijada al leer, tope global público.
import { webcrypto as C } from 'node:crypto';
const A = 'http://localhost:8787', O = { Origin: 'http://localhost:8770' }; let f = 0;
const ok = (c, m) => { console.log((c ? 'OK    ' : 'FALLA ') + m); if (!c) f++; };
const j = async (p, m, b, h) => { const r = await fetch(A + p, { method: m || 'GET', headers: Object.assign({ 'Content-Type': 'application/json' }, O, h || {}), body: b ? JSON.stringify(b) : undefined }); let x = {}; try { x = await r.json(); } catch (e) {} return { s: r.status, j: x }; };
const lastCode = async (to) => { const m = (await (await fetch(A + '/__mails?to=' + to)).json()).pop(); return m.text.match(/(\d{3}) (\d{3})/).slice(1).join(''); };
// 1) tope diario: 3 códigos × 5 fallos = 15 → el 4.º código, aunque sea correcto, se rechaza ese día
for (let k = 0; k < 3; k++) { await j('/auth/start', 'POST', { email: 'ana@prueba.co' }, { 'X-Test-IP': '10.0.0.' + k }); const c = await lastCode('ana@prueba.co'); for (let i = 0; i < 5; i++) await j('/auth/verify', 'POST', { email: 'ana@prueba.co', code: String((Number(c) + 1 + i) % 1e6).padStart(6, '0') }, { 'X-Test-IP': '10.1.' + k + '.' + i }); }
await j('/auth/start', 'POST', { email: 'ana@prueba.co' }, { 'X-Test-IP': '10.0.0.9' }); const good = await lastCode('ana@prueba.co');
const v = await j('/auth/verify', 'POST', { email: 'ana@prueba.co', code: good }, { 'X-Test-IP': '10.2.0.1' });
ok(v.s === 429, 'tras 15 fallos en el día, el correo queda bloqueado hasta mañana (' + v.s + ')');
// 2) cuenta "antigua" (sin llave de escritura): GET /sync con la cabecera la fija; otra llave luego no sirve
await j('/auth/start', 'POST', { email: 'beto@prueba.co' }, { 'X-Test-IP': '11.0.0.1' }); const t = (await j('/auth/verify', 'POST', { email: 'beto@prueba.co', code: await lastCode('beto@prueba.co') }, { 'X-Test-IP': '11.0.0.1' })).j.token;
const H = { Authorization: 'Bearer ' + t }, wk = Buffer.from(C.getRandomValues(new Uint8Array(32))).toString('base64url');
await j('/me/key', 'PUT', { kc: 'k'.repeat(43) }, { ...H, 'X-Plata-Write': wk });
await j('/sync', 'GET', null, { ...H, 'X-Plata-Write': Buffer.from(C.getRandomValues(new Uint8Array(32))).toString('base64url') });
ok((await j('/sync', 'PUT', { base: 0, next: 1, blob: 'AAAA' }, { ...H, 'X-Plata-Write': wk })).s === 200, 'una lectura con otra llave no reemplaza la llave ya fijada');
// 3) tope global de escrituras públicas: 150 altas desde IPs distintas pasan, la 151 no
let last = 0; for (let i = 0; i < 152; i++) { const r = await j('/waitlist', 'POST', { email: 'x' + i + '@spam.co' }, { 'X-Test-IP': '20.' + (i >> 8) + '.' + (i & 255) + '.1' }); last = r.s; if (i === 149) ok(r.s === 200, 'alta #150 aceptada'); }
ok(last === 429, 'alta #152 rechazada por el tope global (' + last + ')');
process.exit(f ? 1 : 0);
