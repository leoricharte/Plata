/* Plata Cloud · lista de espera (primer pedazo del servicio).
 * POST /waitlist  { email, src, lang, plat, website }  → { ok: true }
 * GET  /waitlist/export  (Authorization: Bearer ADMIN_TOKEN) → lista en JSON
 * GET  /health
 * Cuentas y sincronización cifrada: /auth/start, /auth/verify, /auth/logout, /me, /me/key, /sync, /account, /admin/invite.
 * Con el secreto RESEND_API_KEY envía un correo de confirmación a quien se apunta por primera vez.
 * Guarda solo: correo, fecha, origen (app o landing), idioma y plataforma. Nada de datos financieros.
 */
// web.plataapp.net: la app. plataapp.net: el sitio (y la app vieja mientras dura la migración). Las tres últimas: la app de escritorio (Tauri).
const ORIGINS = ['https://web.plataapp.net', 'https://plataapp.net', 'https://www.plataapp.net', 'http://tauri.localhost', 'https://tauri.localhost', 'tauri://localhost'];
// Rutas de administración: solo desde el panel privado (variable ADMIN_ORIGINS, separada por comas) o desde localhost. El token sigue siendo obligatorio.
const ADMIN_PATHS = /^\/(waitlist\/export|content\/ping|review\/(list|get|mark|delete)|nazca\/(list|get|delete)|admin\/)/;
const isAdminReq = (req, url) => {
  const m = req.method === 'OPTIONS' ? (req.headers.get('Access-Control-Request-Method') || 'GET') : req.method; // en la verificación previa del navegador cuenta el método que se va a usar
  return ADMIN_PATHS.test(url.pathname) || ((url.pathname === '/content' || url.pathname === '/posts') && m !== 'GET');
};
const SRC = ['app', 'landing'];
const LANGS = ['es', 'en', 'ja', 'it', 'fr', 'sh', 'hr'];
const EMAIL = /^[^\s@<>()[\]\\,;:"]+@[^\s@<>()[\]\\,;:"]+\.[^\s@<>()[\]\\,;:"]{2,}$/;
const LIMIT_PER_HOUR = 5;


/* ---------- Correo de confirmación (Resend) ---------- */
const MAIL_FROM = 'Plata Cloud <cloud@plataapp.net>';
const MAIL_LOGO = 'https://plataapp.net/img/email-logo.png';
const MAIL_CLOUDS = 'https://plataapp.net/img/email-clouds.png';
const MAIL_IG = 'https://plataapp.net/img/email-ig.png';
const MAIL_LN = 'https://plataapp.net/img/email-ln.png';
const MAIL_WEB = 'https://plataapp.net/img/email-web.png';
const MAIL_KEY = 'https://plataapp.net/img/email-key.gif';
const MAIL_WARN = 'https://plataapp.net/img/email-warn.png';
const MAIL_IC = (n) => 'https://plataapp.net/img/email-ic-' + n + '.png';
const MAIL_TXT = {
  es: {
    subject: (n) => 'Eres la persona #' + n + ' en la lista de Plata Cloud',
    pre: (n) => 'Pronto volando. Te avisaremos apenas abramos cupos.',
    title: 'Pronto volando.',
    lead: (n) => 'Eres la persona número ' + n + ' en apuntarse a Plata Cloud. Cuando abramos cupos para la marcha blanca gratuita de un mes, te escribiremos a este correo.',
    h: ['¿Qué es Plata Cloud?', '¿Qué cambia hoy?', '¿Qué más me van a pedir?'],
    p: [
      'Es una forma opcional de usar Plata en varios dispositivos, con tus datos cifrados y seguros.',
      'Nada. Plata Cloud sale en la Beta 3, y por el momento sigue funcionando igual con tus datos solo en el dispositivo.',
      'Nada, nada, solo este correo. Por ahora ya estás.'
    ],
    btn: 'Conoce más',
    thanks: 'Gracias por confiar en Plata <3',
    sig: ['Leonardo Richarte,', 'Fundador de Plata & Estudio 2²'],
    foot: 'Recibiste este correo porque alguien lo inscribió a la lista de espera de Plata Cloud en plataapp.net. Si no fuiste tú, no pasa nada, chill. No te conocemos. Aunque tienes suerte de que estén metiendo tus correos en apps de finanzas en beta y no en otras cosas, jeje.'
  },
  en: {
    subject: (n) => "You're person #" + n + ' on the Plata Cloud list',
    pre: (n) => "Flying soon. We'll let you know as soon as spots open.",
    title: 'Flying soon.',
    lead: (n) => 'You are person number ' + n + " to join Plata Cloud. When we open spots for the free one-month trial run, we'll write to this address.",
    h: ['What is Plata Cloud?', 'What changes today?', 'What else will you ask of me?'],
    p: [
      'It is an optional way to use Plata on several devices, with your data encrypted and safe.',
      'Nothing. Plata Cloud arrives in Beta 3, and for now Plata keeps working the same, with your data only on your device.',
      'Nothing, nothing, just this email. For now, you are in.'
    ],
    btn: 'Learn more',
    thanks: 'Thanks for trusting Plata <3',
    sig: ['Leonardo Richarte,', 'Founder of Plata & Estudio 2²'],
    foot: "You got this email because someone signed this address up for the Plata Cloud waitlist at plataapp.net. If it wasn't you, no worries, chill. We don't know you. Though you're lucky your email is going into a beta finance app and not into other things, hehe."
  }
};
const mailT = (lang) => MAIL_TXT[lang] || MAIL_TXT.en;
const mailLink = (lang) => 'https://plataapp.net/cloud.html' + (lang === 'en' ? '?lang=en' : '');

const socialRow = (F) => {
  const it = (href, img, label) => '<a href="' + href + '" style="display:inline-block;margin:0 9px 6px;text-decoration:none;color:#1C1C1E;font:600 14px/1 ' + F + '"><img src="' + img + '" width="18" height="18" alt="" style="border:0;vertical-align:middle;width:18px;height:18px">&nbsp; ' + label + '</a>';
  return '<tr><td align="center" style="text-align:center;padding:6px 0 26px">' + it('https://www.instagram.com/plataapp/', MAIL_IG, 'plataapp') + it('https://www.linkedin.com/company/plataapp', MAIL_LN, 'plataapp') + it('https://plataapp.net', MAIL_WEB, 'plataapp.net') + '</td></tr>';
};
function waitlistMail(lang, n) {
  const t = mailT(lang), G = '#22B573', F = "Inter,-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif";
  const sig = t.sig, thanks = t.thanks.replace('<', '&lt;');
  const row = (i) => '<tr><td align="center" style="text-align:center;padding:0 0 18px 0"><div style="font:700 15px/1.3 ' + F + ';color:#1C1C1E;margin:0 0 3px">' + t.h[i] + '</div><div style="font:400 15px/1.55 ' + F + ';color:#5B5B60">' + t.p[i] + '</div></td></tr>';
  const html = '<!doctype html><html lang="' + (MAIL_TXT[lang] ? lang : 'en') + '"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="only light"><meta name="supported-color-schemes" content="light"><title>' + t.subject(n) + '</title><link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;700;800&display=swap" rel="stylesheet">'
    + '<style>:root{color-scheme:only light}@media (max-width:520px){.pad{padding-left:24px!important;padding-right:24px!important}.num{font-size:64px!important}.tt{font-size:30px!important}}</style></head>'
    + '<body style="margin:0;padding:0;background:#FFFFFF">'
    + '<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent">' + t.pre(n) + '</div>'
    + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#FFFFFF"><tr><td align="center" style="padding:0">'
    + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:560px">'
    + '<tr><td align="center" style="text-align:center;padding:0"><img src="' + MAIL_CLOUDS + '" width="560" alt="" style="display:block;margin:0 auto;border:0;width:100%;max-width:560px;height:auto"></td></tr>'
    + '<tr><td class="pad" align="center" style="text-align:center;padding:6px 34px 0"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
    + '<tr><td align="left" style="text-align:left;padding:0 0 20px 0"><img src="' + MAIL_LOGO + '" width="150" height="52" alt="Plata Cloud" style="display:block;border:0;height:auto;width:150px"></td></tr>'
    + '<tr><td class="num" align="center" style="text-align:center;padding:0;font:800 80px/1 ' + F + ';letter-spacing:-0.05em;color:' + G + '">#' + n + '</td></tr>'
    + '<tr><td class="tt" align="center" style="text-align:center;padding:6px 0 14px 0;font:800 36px/1.1 ' + F + ';letter-spacing:-0.03em;color:#1C1C1E">' + t.title + '</td></tr>'
    + '<tr><td align="center" style="text-align:center;padding:0 0 26px 0;font:400 17px/1.55 ' + F + ';color:#5B5B60">' + t.lead(n) + '</td></tr>'
    + row(0) + row(1) + row(2)
    + '<tr><td align="center" style="text-align:center;padding:8px 0 26px 0"><a href="' + mailLink(lang) + '" style="display:inline-block;background:' + G + ';color:#FFFFFF;text-decoration:none;border-radius:999px;padding:14px 26px;font:700 16px/1 ' + F + '">' + t.btn + '</a></td></tr>'
    + '<tr><td align="center" style="text-align:center;padding:0 0 14px 0;font:500 16px/1.4 ' + F + ';color:#1C1C1E">' + thanks + '</td></tr>'
    + '<tr><td align="center" style="text-align:center;padding:0 0 18px 0;font:700 15px/1.45 ' + F + ';color:#1C1C1E">' + sig[0] + '<br><span style="font-weight:500;color:#5B5B60">' + sig[1] + '</span></td></tr>'
    + socialRow(F)
    + '</table></td></tr>'
    + '<tr><td class="pad" align="center" style="text-align:center;padding:0 34px 34px;font:400 12.5px/1.5 ' + F + ';color:#8A8A8F">' + t.foot + '</td></tr>'
    + '</table></td></tr></table></body></html>';
  const text = '#' + n + '\n' + t.title + '\n\n' + t.lead(n) + '\n\n' + t.h.map((x, i) => x + '\n' + t.p[i]).join('\n\n') + '\n\n' + t.btn + ': ' + mailLink(lang) + '\n\n' + t.thanks + '\n' + sig[0] + ' ' + sig[1] + '\n\nInstagram: plataapp\n\n' + t.foot + '\n';
  return { subject: t.subject(n), html, text };
}

async function sendWaitlistMail(env, email, lang, n) {
  if (!env.RESEND_API_KEY) return;
  const m = waitlistMail(lang, n);
  try {
    const r = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: 'Bearer ' + env.RESEND_API_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ from: MAIL_FROM, to: [email], subject: m.subject, html: m.html, text: m.text })
    });
    if (!r.ok) console.log('resend', r.status, (await r.text()).slice(0, 200));
  } catch (e) { console.log('resend fail'); }
}

// Número de lista: contador en KV; si no existe, parte de cuántos hay ya apuntados.
async function nextNumber(env) {
  let n = Number(await env.WAITLIST.get('meta:count')) || 0;
  if (!n) { let cursor; do { const r = await env.WAITLIST.list({ prefix: 'w:', cursor }); n += r.keys.length; cursor = r.list_complete ? undefined : r.cursor; } while (cursor); }
  n += 1;
  await env.WAITLIST.put('meta:count', String(n));
  return n;
}

const list = (v) => String(v || '').split(',').map((x) => x.trim()).filter(Boolean);
const LOCAL = /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;
const cors = (req, env, admin) => {
  const o = req.headers.get('Origin') || '';
  const adminOk = list(env.ADMIN_ORIGINS).includes(o) || (env.DEV === '1' && LOCAL.test(o)); // el panel también lee las rutas públicas (textos, Novedades)
  const ok = admin ? adminOk : (ORIGINS.includes(o) || list(env.TEST_ORIGINS).includes(o) || (env.DEV === '1' && LOCAL.test(o)) || list(env.ADMIN_ORIGINS).includes(o));
  return ok ? { 'Access-Control-Allow-Origin': o, 'Access-Control-Allow-Methods': 'POST, GET, PUT, DELETE, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Plata-Write', 'Access-Control-Max-Age': '86400', Vary: 'Origin' } : { Vary: 'Origin' };
};
const json = (body, status, h) => new Response(JSON.stringify(body), { status: status || 200, headers: Object.assign({ 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' }, h || {}) });

async function sha(s) {
  const b = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s));
  return Array.from(new Uint8Array(b)).map((x) => x.toString(16).padStart(2, '0')).join('').slice(0, 24);
}

/* ---------- Contadores y códigos atómicos (Durable Object "Gate") ----------
 * Workers KV no es atómico y acepta 1 escritura por segundo por clave: con peticiones en paralelo, un contador de "leer, sumar, guardar"
 * deja pasar muchos más intentos de los permitidos (se probó: 300 intentos simultáneos contra un límite de 5). Cada contador y cada
 * código vive en su propio Durable Object, que atiende sus peticiones de una en una. Además no gasta escrituras de KV (1.000 al día gratis),
 * así que nadie puede agotar ese cupo para tumbar el servicio. */
export class Gate {
  constructor(state) { this.s = state.storage; }
  async fetch(req) {
    const b = await req.json(), now = Date.now();
    let v = await this.s.get('v');
    if (v && v.exp && v.exp < now) { v = undefined; await this.s.delete('v'); }
    const done = async (out, nv) => {
      if (nv === null) await this.s.delete('v');
      else if (nv) { await this.s.put('v', nv); if (nv.exp) await this.s.setAlarm(nv.exp + 1000); }
      return Response.json(out);
    };
    switch (b.op) {
      case 'hit': { const n = v ? v.n || 0 : 0; if (n >= b.max) return done({ limited: true }); return done({ limited: false }, { n: n + 1, exp: v ? v.exp : now + b.ttl * 1000 }); }
      case 'peek': return done({ n: v ? v.n || 0 : 0 });
      case 'set': return done({ ok: true }, { val: b.val, tries: 0, exp: now + b.ttl * 1000 });
      case 'try': { // compara el hash de un código; lo consume si acierta (salvo keep) y cuenta los fallos sin carreras
        if (!v || v.val == null || v.tries >= b.max) return done({ ok: false });
        if (v.val === b.val) return done({ ok: true }, b.keep ? undefined : null);
        return done({ ok: false }, { val: v.val, tries: v.tries + 1, exp: v.exp }); }
      case 'get': return done({ val: v ? v.val : null });
      case 'cas': { // cambia el valor solo si su estado (val.st) es el esperado
        const cur = v ? v.val : null, st = cur ? cur.st : null;
        if (b.expect !== undefined && !(Array.isArray(b.expect) ? b.expect.includes(st) : st === b.expect)) return done({ ok: false, val: cur });
        return done({ ok: true, val: b.val }, b.val === null ? null : { val: b.val, exp: now + b.ttl * 1000 }); }
      case 'del': return done({ ok: true }, null);
    }
    return done({ error: 'op' });
  }
  async alarm() { const v = await this.s.get('v'); if (!v || !v.exp || v.exp <= Date.now()) await this.s.deleteAll(); }
}
async function gate(env, name, body) {
  if (!env.GATE) throw new Error('GATE'); // sin el Durable Object enlazado, las rutas que lo necesitan fallan cerradas (503)
  const r = await env.GATE.get(env.GATE.idFromName(name)).fetch('https://gate/', { method: 'POST', body: JSON.stringify(body) });
  return r.json();
}
async function hit(env, key, max, ttl) { return (await gate(env, key, { op: 'hit', max, ttl })).limited; } // true si ya se pasó del límite
const salt = (env) => { if (!env.RL_SALT) throw new Error('GATE'); return env.RL_SALT; }; // sin RL_SALT no hay sal secreta: las rutas que anonimizan fallan cerradas (503), no con una sal conocida
const ipKey = async (req, env, tag) => tag + ':' + (await sha(salt(env) + (req.headers.get('CF-Connecting-IP') || 'x')));
async function rateLimited(req, env) {
  if (await hit(env, (await ipKey(req, env, 'rl')) + ':' + Math.floor(Date.now() / 3600000), LIMIT_PER_HOUR, 7200)) return true;
  // Tope global: aunque alguien rote IPs, las rutas públicas no pueden gastar más de 300 escrituras de KV al día (de 1.000 en el plan gratis).
  return hit(env, 'rl:pub:' + Math.floor(Date.now() / 86400000), PUBLIC_WRITES_DAY, 2 * 86400);
}
const PUBLIC_WRITES_DAY = 150; // cada alta o copia hace ~2 escrituras

async function join(req, env, h, ctx) {
  const origin = req.headers.get('Origin') || '';
  if (!h['Access-Control-Allow-Origin'] && origin) return json({ ok: false, error: 'origin' }, 403, h);
  const raw = await req.text();
  if (raw.length > 1024) return json({ ok: false, error: 'size' }, 413, h);
  let b; try { b = JSON.parse(raw); } catch (e) { return json({ ok: false, error: 'json' }, 400, h); }
  if (!b || typeof b !== 'object') return json({ ok: false, error: 'json' }, 400, h);
  if (b.website) return json({ ok: true }, 200, h); // señuelo anti-bots: se ignora en silencio
  const email = String(b.email || '').trim().toLowerCase();
  if (email.length > 254 || !EMAIL.test(email)) return json({ ok: false, error: 'email' }, 400, h);
  if (await rateLimited(req, env)) return json({ ok: false, error: 'rate' }, 429, h);
  const key = 'w:' + email;
  const had = !!(await env.WAITLIST.get(key));
  if (!had) {
    const num = await nextNumber(env);
    const rec = { n: num, t: Date.now(), src: SRC.includes(b.src) ? b.src : 'landing', lang: LANGS.includes(b.lang) ? b.lang : 'es', plat: String(b.plat || '').slice(0, 40) };
    await env.WAITLIST.put(key, JSON.stringify(rec));
    if (ctx && ctx.waitUntil) ctx.waitUntil(sendWaitlistMail(env, email, rec.lang, num)); // solo la primera vez: no se reenvía si ya estaba
  }
  return json({ ok: true, already: had }, 200, h); // la app avisa "ya estás en la lista" en la misma pantalla
}

async function exportList(req, env, h) {
  { const g = await adminGate(req, env, h); if (g) return g; }
  const out = []; let cursor;
  do {
    const r = await env.WAITLIST.list({ prefix: 'w:', cursor });
    for (const k of r.keys) { const v = await env.WAITLIST.get(k.name); out.push(Object.assign({ email: k.name.slice(2) }, JSON.parse(v || '{}'))); }
    cursor = r.list_complete ? undefined : r.cursor;
  } while (cursor);
  out.sort((a, b) => a.t - b.t);
  return json({ ok: true, count: out.length, list: out }, 200, h);
}

/* ---------- Copias enviadas para revisión del equipo (texto plano, solo con permiso expreso del usuario) ---------- */
const MAX_REVIEW = 4000000, REVIEW_TTL = 30 * 86400, REVIEW_WAIT = [10, 30, 60, 120, 1440].map((m) => m * 60000);
async function reviewPut(req, env, h) {
  if (env.REVIEW_OFF === '1') return json({ ok: false, error: 'off' }, 403, h); // p. ej. durante un piloto: no entra nada legible al servidor
  const origin = req.headers.get('Origin') || '';
  if (!h['Access-Control-Allow-Origin'] && origin) return json({ ok: false, error: 'origin' }, 403, h);
  const raw = await req.text();
  if (raw.length > MAX_REVIEW) return json({ ok: false, error: 'size' }, 413, h);
  let b; try { b = JSON.parse(raw); } catch (e) { return json({ ok: false, error: 'json' }, 400, h); }
  if (!b || typeof b !== 'object' || !b.data || typeof b.data !== 'object') return json({ ok: false, error: 'json' }, 400, h);
  if (await rateLimited(req, env)) return json({ ok: false, error: 'rate' }, 429, h);
  // espera creciente entre envíos desde la misma conexión: 10 min, 30 min, 1 h, 2 h, 1 día
  const ipk = 'rvl:' + (await sha(salt(env) + (req.headers.get('CF-Connecting-IP') || 'x'))), now = Date.now();
  let lim = await kvGet(env, ipk); if (!lim || now - lim.t > 7 * 86400000) lim = { n: 0, t: 0 };
  const until = lim.t + REVIEW_WAIT[Math.min(lim.n, REVIEW_WAIT.length) - 1] ;
  if (lim.n > 0 && now < until) return json({ ok: false, error: 'wait', until: until }, 429, h);
  const id = Date.now().toString(36) + '-' + rndB64(6);
  await env.WAITLIST.put('rv:' + id, JSON.stringify({ t: Date.now(), build: Number(b.build) || 0, plat: String(b.plat || '').slice(0, 40), data: b.data }), { expirationTtl: REVIEW_TTL }); // texto plano: no se guarda más de 30 días
  await kvPut(env, ipk, { n: lim.n + 1, t: now }, 8 * 86400);
  return json({ ok: true, id: id, until: now + REVIEW_WAIT[Math.min(lim.n + 1, REVIEW_WAIT.length) - 1] }, 200, h);
}
/* ---------- Archivos que Nazca no reconoció (la persona los manda a propósito, con permiso expreso, solo para entrenar a Nazca) ---------- */
const MAX_NAZCA = 4200000, NAZCA_TTL = 30 * 86400, NAZCA_DAY = 5;   // 4.2 MB en base64 ≈ 3 MB de archivo · 30 días · 5 envíos por conexión al día
const NAZCA_GLOBAL_DAY = 60, NAZCA_HOUR = 12;   // tope propio: ya no gasta el cupo de escrituras de la lista de espera
const b64head = (b64, n) => { try { return atob(b64.slice(0, Math.ceil(n / 3) * 4)); } catch (e) { return null; } };
function nazcaLooksLike(kind, b64) { // el tipo declarado tiene que coincidir con lo que realmente es (por los primeros bytes)
  const head = b64head(b64, 1024); if (head === null) return false;
  if (kind === 'pdf') return head.indexOf('%PDF-') >= 0;
  if (kind === 'xlsx') return head.slice(0, 4) === 'PK\x03\x04';
  return head.indexOf('\0') < 0 && !/^(%PDF-|PK\x03\x04|MZ|\x7fELF|#!|<\?php|<script)/i.test(head);   // csv / texto
}
async function nazcaPut(req, env, h) {
  if (env.REVIEW_OFF === '1') return json({ ok: false, error: 'off' }, 403, h);
  const origin = req.headers.get('Origin') || '';
  if (!h['Access-Control-Allow-Origin'] && origin) return json({ ok: false, error: 'origin' }, 403, h);
  const ip = await ipKey(req, env, 'nz');
  if (await hit(env, ip + ':h', NAZCA_HOUR, 3600)) return json({ ok: false, error: 'rate' }, 429, h);          // intentos por hora, válidos o no
  const raw = await req.text();
  if (raw.length > MAX_NAZCA + 2000) return json({ ok: false, error: 'size' }, 413, h);
  let b; try { b = JSON.parse(raw); } catch (e) { return json({ ok: false, error: 'json' }, 400, h); }
  if (!b || typeof b !== 'object' || typeof b.b64 !== 'string' || !b.b64 || b.b64.length > MAX_NAZCA || !/^[A-Za-z0-9+/=]+$/.test(b.b64)) return json({ ok: false, error: 'json' }, 400, h);
  const kind = ['pdf', 'xlsx', 'csv'].includes(b.kind) ? b.kind : '';
  if (!kind || !nazcaLooksLike(kind, b.b64)) return json({ ok: false, error: 'tipo' }, 400, h);                  // solo PDF, XLSX o CSV, y que lo sean de verdad
  if (await hit(env, ip + ':d', NAZCA_DAY, 86400)) return json({ ok: false, error: 'wait' }, 429, h);          // 5 envíos por día por conexión (contador atómico)
  if (await hit(env, 'nz:cap:' + Math.floor(Date.now() / 86400000), NAZCA_GLOBAL_DAY, 2 * 86400)) return json({ ok: false, error: 'wait' }, 429, h); // tope global del día
  const id = Date.now().toString(36) + '-' + rndB64(6), now = Date.now();
  await env.WAITLIST.put('nz:' + id, JSON.stringify({ t: now, build: Number(b.build) || 0, plat: String(b.plat || '').slice(0, 40), kind: kind, bank: String(b.bank || '').slice(0, 30), why: String(b.why || '').slice(0, 60), b64: b.b64 }), { expirationTtl: NAZCA_TTL });
  return json({ ok: true, id: id }, 200, h);
}
async function nazcaList(req, env, h) {
  { const g = await adminGate(req, env, h); if (g) return g; }
  const out = []; let cursor;
  do { const r = await env.WAITLIST.list({ prefix: 'nz:', cursor }); r.keys.forEach((k) => out.push(k.name.slice(3))); cursor = r.list_complete ? undefined : r.cursor; } while (cursor);
  return json({ ok: true, count: out.length, ids: out }, 200, h);
}
async function nazcaGet(req, env, h, url) {
  { const g = await adminGate(req, env, h); if (g) return g; }
  const v = await env.WAITLIST.get('nz:' + (url.searchParams.get('id') || ''));
  return v ? new Response(v, { status: 200, headers: Object.assign({ 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' }, h) }) : json({ ok: false, error: 'none' }, 404, h);
}
async function nazcaDelete(req, env, h, url) {
  { const g = await adminGate(req, env, h); if (g) return g; }
  await env.WAITLIST.delete('nz:' + (url.searchParams.get('id') || ''));
  return json({ ok: true }, 200, h);
}
/* Acceso de administrador. El token fijo (ADMIN_TOKEN = rol dev, MOD_TOKEN = rol mod) solo sirve para abrir una sesión (POST /admin/session); todo lo demás exige
 * esa sesión: un token aleatorio que vive 1 hora en el Gate (sin renovación), se puede revocar (POST /admin/logout) y no se escribe en ningún otro lado.
 * Comparación en tiempo constante (se comparan hashes) y bloqueo por IP tras 5 fallos en 15 minutos (429), con contador atómico.
 * ADMIN_LEGACY=1 vuelve a aceptar ADMIN_TOKEN directo en cada petición (solo para scripts viejos; no recomendado). */
const AUTH_MAX = 5, AUTH_WIN = 900, ADMIN_SESSION = 3600, ROLE_RANK = { aud: 1, mod: 2, dev: 3 }, AUDIT_TTL = 90 * 86400, USERS_MAX = 40;
/* Auditor (aud): solo mira. Puede hacer peticiones GET de administración y nada más; ninguna escritura, ni propuesta, ni invitación. Tampoco abre el CONTENIDO de datos de
 * usuarios (copias recibidas, archivos de Nazca, correos de la lista de espera) salvo que el Worker tenga AUDITOR_DATA=1: ver quién hizo qué no exige ver datos personales. */
const AUD_DATA = /^\/(review\/get|nazca\/get|waitlist\/export|admin\/nazca\/lib\/get)$/;
const audCan = (req, env) => req.method === 'GET' && (env.AUDITOR_DATA === '1' || !AUD_DATA.test(new URL(req.url).pathname));
const INTERNAL = new WeakSet(); // peticiones armadas por el propio servidor al aprobar una propuesta: ya vienen autorizadas por un dev
const WHO = new WeakMap();      // petición → quién la hizo ({ role, who, uid }); lo usa el registro de auditoría
/* Quién entra: tokens personales (plt_<id>.<secreto>, guardados solo como hash en au:<id>) o, de respaldo, los tokens compartidos ADMIN_TOKEN (dev) y MOD_TOKEN (mod). */
async function identify(env, header) {
  const m = /^Bearer (plt_([A-Za-z0-9_-]{6,12})\.[A-Za-z0-9_-]{30,64})$/.exec(header);
  if (m) {
    const u = await kvGet(env, 'au:' + m[2]);
    if (u && !u.rev && ROLE_RANK[u.role] && same(await shaFull(m[1]), u.h)) return { role: u.role, who: u.name, uid: m[2], title: u.title || '' };
    return null;
  }
  for (const [role, name, who, title] of [['dev', 'ADMIN_TOKEN', 'root', 'Acceso raíz'], ['mod', 'MOD_TOKEN', 'mod compartido', '']]) {
    const t = env[name]; if (t && t.length >= 32 && same(await shaFull(header), await shaFull('Bearer ' + t))) return { role, who, uid: '', title };
  }
  return null;
}
/* Registro de auditoría: al/<hora>-<azar> con el evento en los metadatos de KV (se lista sin leer cada uno). Guarda quién, qué y sobre qué id: nunca tokens ni el contenido. 90 días. */
async function audit(env, req, act, d, who) {
  const w = who || WHO.get(req) || { role: '', who: '?', uid: '' };
  const t = Date.now(), ip = (await ipKey(req, env, 'au')).slice(3, 11);
  try { await env.WAITLIST.put('al:' + String(t).padStart(13, '0') + '-' + rndB64(3), '1', { expirationTtl: AUDIT_TTL, metadata: { t, who: w.who, uid: w.uid, role: w.role, act, d: String(d || '').slice(0, 120), ip } }); } catch (e) { /* el registro nunca debe tumbar la acción */ }
}
const AUDITED = /^(GET \/(review\/get|nazca\/get|waitlist\/export)|POST \/(review\/(mark|delete)|nazca\/delete|admin\/invite))$/;
async function adminAuth(req, env, h, need) { // → { res } si no pasa, o { role, who, uid } si pasa
  need = need || 'dev';
  if (INTERNAL.has(req)) return Object.assign({ role: 'dev' }, WHO.get(req) || {});
  const o = req.headers.get('Origin'); if (o && !h['Access-Control-Allow-Origin']) return { res: json({ ok: false, error: 'origin' }, 403, h) }; // solo desde el panel privado
  const key = await ipKey(req, env, 'af');
  if ((await gate(env, key, { op: 'peek' })).n >= AUTH_MAX) return { res: json({ ok: false, error: 'rate' }, 429, Object.assign({}, h, { 'Retry-After': String(AUTH_WIN) })) };
  const auth = req.headers.get('Authorization') || '';
  let me = null; const m = /^Bearer ([A-Za-z0-9_-]{40,64})$/.exec(auth);
  if (m) {
    const s = (await gate(env, 'as:' + (await shaFull(m[1])), { op: 'get' })).val;
    if (s && ROLE_RANK[s.role]) { const u = s.uid ? await kvGet(env, 'au:' + s.uid) : true; if (u && !u.rev) me = { role: s.role, who: s.who || '?', uid: s.uid || '', title: (u === true ? s.title : u.title) || '' }; } // una persona revocada pierde su sesión al instante
  }
  if (!me && env.ADMIN_LEGACY === '1') { const r = await identify(env, auth); if (r && r.role === 'dev') me = r; }
  if (me && (ROLE_RANK[me.role] >= ROLE_RANK[need] || (me.role === 'aud' && audCan(req, env)))) {
    WHO.set(req, me);
    const u = new URL(req.url); if (AUDITED.test(req.method + ' ' + u.pathname)) await audit(env, req, (req.method === 'GET' ? 'ver ' : '') + u.pathname.slice(1), u.searchParams.get('id') || u.searchParams.get('do') || '', me);
    return me;
  }
  if (me) return { res: json({ ok: false, error: me.role === 'aud' ? 'readonly' : 'role' }, 403, h) }; // sesión válida, pero con un rol que no alcanza (el auditor solo lee)
  await hit(env, key, AUTH_MAX, AUTH_WIN);
  return { res: json({ ok: false, error: 'auth' }, 401, h) };
}
async function adminGate(req, env, h, need) { const a = await adminAuth(req, env, h, need); return a.res || null; } // devuelve null si pasa; si no, la respuesta 401, 403 o 429
async function adminSession(req, env, h) { // POST /admin/session con Authorization: Bearer <token personal | ADMIN_TOKEN | MOD_TOKEN> → { session, role, name, exp }
  const o = req.headers.get('Origin'); if (o && !h['Access-Control-Allow-Origin']) return json({ ok: false, error: 'origin' }, 403, h);
  const key = await ipKey(req, env, 'af');
  if ((await gate(env, key, { op: 'peek' })).n >= AUTH_MAX) return json({ ok: false, error: 'rate' }, 429, Object.assign({}, h, { 'Retry-After': String(AUTH_WIN) }));
  const hdr = req.headers.get('Authorization') || '', me = await identify(env, hdr);
  if (!me) {
    await hit(env, key, AUTH_MAX, AUTH_WIN);
    const pm = /^Bearer plt_([A-Za-z0-9_-]{6,12})\./.exec(hdr);
    if (!(await hit(env, 'au:fail:' + Math.floor(Date.now() / 86400000), 60, 2 * 86400))) await audit(env, req, 'entrada fallida', pm ? 'usuario ' + pm[1] : 'token no reconocido', { role: '', who: '—', uid: '' }); // con tope diario: nadie puede llenar el registro
    return json({ ok: false, error: 'auth' }, 401, h);
  }
  const token = rndB64(32), now = Date.now();
  await gate(env, 'as:' + (await shaFull(token)), { op: 'set', val: { role: me.role, who: me.who, uid: me.uid, title: me.title || '', t: now }, ttl: ADMIN_SESSION });
  if (me.uid) { const u = await kvGet(env, 'au:' + me.uid); if (u) { u.last = now; await kvPut(env, 'au:' + me.uid, u); } }
  await audit(env, req, 'entrada', '', me);
  return json({ ok: true, session: token, role: me.role, name: me.who, uid: me.uid || '', title: me.title || '', exp: now + ADMIN_SESSION * 1000 }, 200, h);
}
async function adminLogout(req, env, h) { // revoca la sesión en el servidor (además de olvidarla en el panel)
  const m = /^Bearer ([A-Za-z0-9_-]{40,64})$/.exec(req.headers.get('Authorization') || '');
  if (m) { const k = 'as:' + (await shaFull(m[1])), s = (await gate(env, k, { op: 'get' })).val; if (s) { await audit(env, req, 'salida', '', { role: s.role, who: s.who, uid: s.uid }); await gate(env, k, { op: 'del' }); } }
  return json({ ok: true }, 200, h);
}
const cleanLabel = (v) => String(v || '').replace(/[\u0000-\u001f<>]/g, '').trim().slice(0, 40); // nombre o cargo: texto corto, sin marcas
/* Equipo: cada persona con su token. El token se muestra UNA vez al crearlo; el servidor solo guarda su hash. */
async function usersList(req, env, h) {
  { const g = await adminGate(req, env, h, 'dev'); if (g) return g; }
  const out = []; let cursor;
  do { const r = await env.WAITLIST.list({ prefix: 'au:', cursor }); for (const k of r.keys) { const u = await kvGet(env, k.name); if (u) out.push({ id: k.name.slice(3), name: u.name, role: u.role, title: u.title || '', c: u.c, by: u.by, last: u.last || 0, rev: u.rev || 0 }); } cursor = r.list_complete ? undefined : r.cursor; } while (cursor);
  out.sort((a, b) => a.c - b.c);
  return json({ ok: true, items: out }, 200, h);
}
async function usersCreate(req, env, h) {
  const a = await adminAuth(req, env, h, 'dev'); if (a.res) return a.res;
  const { b, err } = await readBody(req, 2000); if (err) return json({ ok: false, error: 'json' }, err, h);
  const name = cleanLabel(b.name), title = cleanLabel(b.title), role = b.role;
  if (!name || !ROLE_RANK[role]) return json({ ok: false, error: 'campos' }, 400, h);
  let n = 0, cursor; do { const r = await env.WAITLIST.list({ prefix: 'au:', cursor }); n += r.keys.length; cursor = r.list_complete ? undefined : r.cursor; } while (cursor);
  if (n >= USERS_MAX) return json({ ok: false, error: 'full' }, 429, h);
  const id = rndB64(6), token = 'plt_' + id + '.' + rndB64(32);
  await kvPut(env, 'au:' + id, { name, role, title, h: await shaFull(token), c: Date.now(), by: a.who });
  await audit(env, req, 'crear persona', name + (title ? ' · ' + title : '') + ' (' + role + ')');
  return json({ ok: true, id, token }, 200, h);
}
async function usersRevoke(req, env, h, url) { // POST /admin/users/revoke?id=…&undo=1
  const a = await adminAuth(req, env, h, 'dev'); if (a.res) return a.res;
  const id = url.searchParams.get('id') || '', u = /^[A-Za-z0-9_-]{6,12}$/.test(id) ? await kvGet(env, 'au:' + id) : null;
  if (!u) return json({ ok: false, error: 'none' }, 404, h);
  u.rev = url.searchParams.get('undo') === '1' ? 0 : Date.now(); await kvPut(env, 'au:' + id, u);
  await audit(env, req, u.rev ? 'revocar persona' : 'reactivar persona', u.name);
  return json({ ok: true }, 200, h);
}
async function usersTitle(req, env, h, url) { // POST /admin/users/title?id=… con { title } → cambia el cargo de una persona (solo dev)
  const a = await adminAuth(req, env, h, 'dev'); if (a.res) return a.res;
  const { b, err } = await readBody(req, 500); if (err) return json({ ok: false, error: 'json' }, err, h);
  const id = url.searchParams.get('id') || '', u = /^[A-Za-z0-9_-]{6,12}$/.test(id) ? await kvGet(env, 'au:' + id) : null;
  if (!u) return json({ ok: false, error: 'none' }, 404, h);
  u.title = cleanLabel(b.title); await kvPut(env, 'au:' + id, u);
  await audit(env, req, 'cambiar cargo', u.name + ' → ' + (u.title || '(sin cargo)'));
  return json({ ok: true, title: u.title }, 200, h);
}
/* Proyecto (solo dev; el auditor lo lee): notas, línea de tiempo e ideas del equipo, con comentarios cortos y votos. bd:<id>. Texto plano: el panel lo pinta con textContent. */
const BOARD_MAX = 300, BOARD_TYPES = { note: 1, event: 1, idea: 1 }, BOARD_ST = { event: { plan: 1, doing: 1, done: 1 }, idea: { new: 1, keep: 1, done: 1, drop: 1 }, note: { '': 1 } }, BOARD_COM = 60;
const cleanBody = (v, n) => String(v || '').replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, '').replace(/\r\n?/g, '\n').trim().slice(0, n);
const okBoardId = (id) => /^[A-Za-z0-9_-]{6,12}$/.test(id || '');
async function boardKeys(env) { const out = []; let cursor; do { const r = await env.WAITLIST.list({ prefix: 'bd:', cursor }); for (const k of r.keys) out.push(k.name); cursor = r.list_complete ? undefined : r.cursor; } while (cursor && out.length < 2 * BOARD_MAX); return out; }
async function boardList(req, env, h) {
  { const g = await adminGate(req, env, h, 'dev'); if (g) return g; }
  const keys = (await boardKeys(env)).slice(0, BOARD_MAX), items = [];
  for (let i = 0; i < keys.length; i += 20) { const part = await Promise.all(keys.slice(i, i + 20).map((k) => kvGet(env, k))); part.forEach((v, j) => { if (v) items.push(Object.assign({ id: keys[i + j].slice(3) }, v)); }); }
  return json({ ok: true, items }, 200, h);
}
async function boardSave(req, env, h) { // POST /admin/board { id?, type, title, body, date, status, pin }
  const a = await adminAuth(req, env, h, 'dev'); if (a.res) return a.res;
  const { b, err } = await readBody(req, 12000); if (err) return json({ ok: false, error: 'json' }, err, h);
  let cur = null, id = String(b.id || '');
  if (id) { if (!okBoardId(id)) return json({ ok: false, error: 'id' }, 400, h); cur = await kvGet(env, 'bd:' + id); if (!cur) return json({ ok: false, error: 'none' }, 404, h); }
  const type = cur ? cur.type : b.type, title = cleanBody(b.title, 120).replace(/\n/g, ' ');
  if (!BOARD_TYPES[type] || !title) return json({ ok: false, error: 'campos' }, 400, h);
  const date = String(b.date || ''); if (type === 'event' && !/^\d{4}-\d{2}-\d{2}$/.test(date)) return json({ ok: false, error: 'fecha' }, 400, h);
  const st = String(b.status || (type === 'event' ? 'plan' : type === 'idea' ? 'new' : '')); if (!BOARD_ST[type][st]) return json({ ok: false, error: 'estado' }, 400, h);
  if (!cur) { if ((await boardKeys(env)).length >= BOARD_MAX) return json({ ok: false, error: 'full' }, 429, h); id = rndB64(6); }
  const now = Date.now(), it = cur || { type, c: now, by: a.who, com: [], v: [] };
  Object.assign(it, { title, body: cleanBody(b.body, 4000), st, date: type === 'event' ? date : '', pin: type === 'note' && b.pin === true, u: now, ub: a.who });
  await kvPut(env, 'bd:' + id, it);
  await audit(env, req, (cur ? 'editar ' : 'crear ') + ({ note: 'nota', event: 'hito', idea: 'idea' })[type], title.slice(0, 60));
  return json({ ok: true, id, item: Object.assign({ id }, it) }, 200, h);
}
async function boardDel(req, env, h, url) { // DELETE /admin/board?id=
  const a = await adminAuth(req, env, h, 'dev'); if (a.res) return a.res;
  const id = url.searchParams.get('id') || '', it = okBoardId(id) ? await kvGet(env, 'bd:' + id) : null;
  if (!it) return json({ ok: false, error: 'none' }, 404, h);
  await env.WAITLIST.delete('bd:' + id); await audit(env, req, 'borrar ' + ({ note: 'nota', event: 'hito', idea: 'idea' })[it.type], String(it.title).slice(0, 60));
  return json({ ok: true }, 200, h);
}
async function boardComment(req, env, h, url) { // POST /admin/board/comment?id= { txt }   ·   DELETE /admin/board/comment?id=&cid=
  const a = await adminAuth(req, env, h, 'dev'); if (a.res) return a.res;
  const id = url.searchParams.get('id') || '', it = okBoardId(id) ? await kvGet(env, 'bd:' + id) : null;
  if (!it) return json({ ok: false, error: 'none' }, 404, h);
  it.com = it.com || [];
  if (req.method === 'DELETE') {
    const cid = url.searchParams.get('cid') || '', n = it.com.length; it.com = it.com.filter((c) => c.i !== cid);
    if (it.com.length === n) return json({ ok: false, error: 'none' }, 404, h);
    await kvPut(env, 'bd:' + id, it); await audit(env, req, 'borrar comentario', String(it.title).slice(0, 60)); return json({ ok: true }, 200, h);
  }
  const { b, err } = await readBody(req, 2000); if (err) return json({ ok: false, error: 'json' }, err, h);
  const x = cleanBody(b.txt, 300); if (!x) return json({ ok: false, error: 'campos' }, 400, h);
  if (it.com.length >= BOARD_COM) return json({ ok: false, error: 'full' }, 429, h);
  const c = { i: rndB64(4), by: a.who, t: Date.now(), x }; it.com.push(c); await kvPut(env, 'bd:' + id, it);
  await audit(env, req, 'comentar', String(it.title).slice(0, 60));
  return json({ ok: true, comment: c }, 200, h);
}
async function boardVote(req, env, h, url) { // POST /admin/board/vote?id= → alterna el voto de quien llama (solo ideas)
  const a = await adminAuth(req, env, h, 'dev'); if (a.res) return a.res;
  const id = url.searchParams.get('id') || '', it = okBoardId(id) ? await kvGet(env, 'bd:' + id) : null;
  if (!it || it.type !== 'idea') return json({ ok: false, error: 'none' }, 404, h);
  const me = a.uid || a.who; it.v = it.v || []; const at = it.v.indexOf(me);
  if (at >= 0) it.v.splice(at, 1); else if (it.v.length < 40) it.v.push(me);
  await kvPut(env, 'bd:' + id, it); return json({ ok: true, v: it.v, mine: it.v.indexOf(me) >= 0 }, 200, h);
}
/* Base de Nazca (solo dev; el auditor ve la lista pero no abre los casos): extracciones de PDF YA ENMASCARADAS que el equipo quiere conservar para escribir o vigilar lectores.
 * nl:<id> → { data }, con lo que sirve para listar en los metadatos de KV. Sin vencimiento: el equipo decide qué borrar. Nunca el PDF original ni su contraseña. */
const NZL_MAX = 200, NZL_WANT = { ok: 1, bad: 1, none: 1 };
const nzClean = (v, n) => String(v || '').replace(/[\u0000-\u001f<>]/g, '').trim().slice(0, n);
function nzShapeOk(d) { // { v:1, pages:[{ w, h, items:[{ str, x, y, w }] }] }: forma exacta, sin campos de más
  if (!d || typeof d !== 'object' || d.v !== 1 || !Array.isArray(d.pages) || !d.pages.length || d.pages.length > 12) return false;
  let n = 0;
  for (const p of d.pages) {
    if (!p || !Array.isArray(p.items) || !Number.isFinite(p.w) || !Number.isFinite(p.h)) return false;
    n += p.items.length; if (n > 20000) return false;
    for (const i of p.items) if (!i || typeof i.str !== 'string' || i.str.length > 400 || !Number.isFinite(i.x) || !Number.isFinite(i.y) || !Number.isFinite(i.w)) return false;
  }
  return true;
}
async function nzLibList(req, env, h) {
  { const g = await adminGate(req, env, h, 'dev'); if (g) return g; }
  const items = []; let cursor;
  do { const r = await env.WAITLIST.list({ prefix: 'nl:', cursor }); for (const k of r.keys) if (k.metadata) items.push(Object.assign({ id: k.name.slice(3) }, k.metadata)); cursor = r.list_complete ? undefined : r.cursor; } while (cursor && items.length < NZL_MAX + 50);
  items.sort((a, b) => b.t - a.t);
  return json({ ok: true, items }, 200, h);
}
async function nzLibSave(req, env, h) { // POST /admin/nazca/lib { name, bank, want, note, data }
  const a = await adminAuth(req, env, h, 'dev'); if (a.res) return a.res;
  const { b, err } = await readBody(req, 700000); if (err) return json({ ok: false, error: 'json' }, err, h);
  const name = nzClean(b.name, 60), want = String(b.want || 'ok');
  if (!name || !NZL_WANT[want] || !nzShapeOk(b.data)) return json({ ok: false, error: 'campos' }, 400, h);
  let n = 0, cursor; do { const r = await env.WAITLIST.list({ prefix: 'nl:', cursor }); n += r.keys.length; cursor = r.list_complete ? undefined : r.cursor; } while (cursor && n < NZL_MAX);
  if (n >= NZL_MAX) return json({ ok: false, error: 'full' }, 429, h);
  const id = rndB64(6), data = { v: 1, pages: b.data.pages.map((p) => ({ w: p.w, h: p.h, items: p.items.map((i) => ({ str: i.str, x: i.x, y: i.y, w: i.w })) })) };
  const meta = { name, bank: nzClean(b.bank, 40), want, note: nzClean(b.note, 160), by: a.who, t: Date.now(), pg: data.pages.length };
  await env.WAITLIST.put('nl:' + id, JSON.stringify({ data }), { metadata: meta });
  await audit(env, req, 'añadir a la base de Nazca', name + (meta.bank ? ' · ' + meta.bank : ''));
  return json({ ok: true, id }, 200, h);
}
async function nzLibGet(req, env, h, url) { // GET /admin/nazca/lib/get?id=
  { const g = await adminGate(req, env, h, 'dev'); if (g) return g; }
  const id = url.searchParams.get('id') || '', v = okBoardId(id) ? await kvGet(env, 'nl:' + id) : null;
  if (!v) return json({ ok: false, error: 'none' }, 404, h);
  return json({ ok: true, data: v.data }, 200, h);
}
async function nzLibDel(req, env, h, url) { // DELETE /admin/nazca/lib?id=
  const a = await adminAuth(req, env, h, 'dev'); if (a.res) return a.res;
  const id = url.searchParams.get('id') || '', k = 'nl:' + id; if (!okBoardId(id)) return json({ ok: false, error: 'none' }, 404, h);
  const r = await env.WAITLIST.getWithMetadata(k); if (r.value == null) return json({ ok: false, error: 'none' }, 404, h);
  await env.WAITLIST.delete(k); await audit(env, req, 'borrar de la base de Nazca', (r.metadata && r.metadata.name) || id);
  return json({ ok: true }, 200, h);
}
async function auditList(req, env, h, url) { // GET /admin/audit?n=200
  { const g = await adminGate(req, env, h, 'dev'); if (g) return g; }
  const n = Math.min(500, Math.max(1, Number(url.searchParams.get('n')) || 200)), keys = []; let cursor;
  do { const r = await env.WAITLIST.list({ prefix: 'al:', cursor }); for (const k of r.keys) keys.push(k); cursor = r.list_complete ? undefined : r.cursor; } while (cursor);
  const items = keys.slice(-n).reverse().map((k) => k.metadata).filter(Boolean);
  return json({ ok: true, count: keys.length, items }, 200, h);
}
async function reviewList(req, env, h) {
  { const g = await adminGate(req, env, h); if (g) return g; }
  const out = []; let cursor;
  do { const r = await env.WAITLIST.list({ prefix: 'rv:', cursor }); r.keys.forEach((k) => out.push(k.name.slice(3))); cursor = r.list_complete ? undefined : r.cursor; } while (cursor);
  return json({ ok: true, count: out.length, ids: out }, 200, h);
}
async function reviewStatus(env, h, url) {
  const v = await kvGet(env, 'rv:' + (url.searchParams.get('id') || ''));
  if (!v) return json({ ok: false, error: 'none' }, 404, h);
  const day = (t) => t ? new Date(t).toISOString().slice(0, 10) : null;
  return json({ ok: true, reviewed: day(v.reviewed), deleted: day(v.deleted) }, 200, h);
}
async function reviewMark(req, env, h, url) { // el equipo marca una copia como revisada: POST /review/mark?id=… con ADMIN_TOKEN
  { const g = await adminGate(req, env, h); if (g) return g; }
  const k = 'rv:' + (url.searchParams.get('id') || ''), v = await kvGet(env, k);
  if (!v) return json({ ok: false, error: 'none' }, 404, h);
  v.reviewed = Date.now(); await kvPut(env, k, v, Math.max(60, Math.round((v.t + REVIEW_TTL * 1000 - Date.now()) / 1000)));
  return json({ ok: true }, 200, h);
}
async function reviewDelete(req, env, h, url) { // borra los datos de la copia y deja solo una constancia (fecha) para que la app lo muestre
  { const g = await adminGate(req, env, h); if (g) return g; }
  const k = 'rv:' + (url.searchParams.get('id') || ''), v = await kvGet(env, k);
  if (!v) return json({ ok: false, error: 'none' }, 404, h);
  await kvPut(env, k, { t: v.t, reviewed: v.reviewed || Date.now(), deleted: Date.now() }, REVIEW_TTL);
  return json({ ok: true }, 200, h);
}
async function reviewGet(req, env, h, url) {
  { const g = await adminGate(req, env, h); if (g) return g; }
  const v = await env.WAITLIST.get('rv:' + (url.searchParams.get('id') || ''));
  return v ? new Response(v, { status: 200, headers: Object.assign({ 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' }, h) }) : json({ ok: false, error: 'none' }, 404, h);
}

/* ---------- Artículos de Novedades (se escriben desde el panel privado; el sitio los lee y los muestra) ---------- */
// Memoria por instancia (2 min): evita listar KV en cada visita (el plan gratis permite solo 1.000 listados al día)
const MEMO = {};
async function memo(k, fn) { const m = MEMO[k]; if (m && Date.now() - m.t < 120000) return m.v; const v = await fn(); MEMO[k] = { t: Date.now(), v }; return v; }
const POST_ID = /^[A-Za-z0-9_-]{4,24}$/, POST_DATE = /^\d{4}-\d{2}-\d{2}$/;
async function postsList(env, h) {
  const out = await memo('posts', async () => {
    const out = []; let cursor;
    do { const r = await env.WAITLIST.list({ prefix: 'po:', cursor }); for (const k of r.keys) { const v = await kvGet(env, k.name); if (v) out.push(v); } cursor = r.list_complete ? undefined : r.cursor; } while (cursor);
    out.sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : (b.c || b.v || 0) - (a.c || a.v || 0)));
    return out;
  });
  return new Response(JSON.stringify({ ok: true, posts: out }), { status: 200, headers: Object.assign({ 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'public, max-age=60' }, h) });
}
async function postImg(env, url) {
  const id = url.searchParams.get('id') || '', b = POST_ID.test(id) ? await env.WAITLIST.get('pi:' + id) : null;
  if (!b) return new Response('', { status: 404 });
  const bin = atob(b), u = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i);
  return new Response(u, { status: 200, headers: { 'Content-Type': 'image/jpeg', 'X-Content-Type-Options': 'nosniff', 'Content-Security-Policy': "default-src 'none'", 'Cache-Control': 'public, max-age=86400' } });
}
async function postSave(req, env, h) {
  { const g = await adminGate(req, env, h); if (g) return g; }
  const raw = await req.text(); if (raw.length > 3000000) return json({ ok: false, error: 'size' }, 413, h);
  let b; try { b = JSON.parse(raw); } catch (e) { return json({ ok: false, error: 'json' }, 400, h); }
  const s = (x, n) => String(x == null ? '' : x).slice(0, n);
  const rec = { date: s(b.date, 10), title_es: s(b.title_es, 160).trim(), body_es: s(b.body_es, 20000), title_en: s(b.title_en, 160).trim(), body_en: s(b.body_en, 20000), by: s(b.by, 60).trim(), by_en: s(b.by_en, 60).trim(), vf: !!b.vf, alt: s(b.alt, 200), tag: s(b.tag, 100).trim(), tag_en: s(b.tag_en, 100).trim() };
  if (!POST_DATE.test(rec.date) || !rec.title_es || !rec.body_es.trim() || !rec.by) return json({ ok: false, error: 'campos' }, 400, h);
  const id = b.id && POST_ID.test(String(b.id)) ? String(b.id) : rndB64(6), old = await kvGet(env, 'po:' + id);
  rec.id = id; rec.v = Date.now(); rec.hasImg = !!(old && old.hasImg);
  rec.c = old ? (old.c || old.v || Date.now()) : Date.now(); // creación: el orden no cambia al editar
  if (old) rec.ed = new Date().toISOString().slice(0, 10); // fecha de última edición
  if (b.img === 'remove') { rec.hasImg = false; await env.WAITLIST.delete('pi:' + id); }
  else if (typeof b.img === 'string' && b.img) {
    const m = /^data:image\/jpeg;base64,([A-Za-z0-9+/=]+)$/.exec(b.img); if (!m || m[1].length > 2500000) return json({ ok: false, error: 'img' }, 400, h);
    await env.WAITLIST.put('pi:' + id, m[1]); rec.hasImg = true;
  }
  await kvPut(env, 'po:' + id, rec); delete MEMO.posts;
  await audit(env, req, old ? 'editar artículo' : 'publicar artículo', id + ' · ' + rec.title_es.slice(0, 60));
  return json({ ok: true, id: id }, 200, h);
}
async function postDel(req, env, h, url) {
  { const g = await adminGate(req, env, h); if (g) return g; }
  const id = url.searchParams.get('id') || ''; if (!POST_ID.test(id)) return json({ ok: false, error: 'none' }, 404, h);
  await env.WAITLIST.delete('po:' + id); await env.WAITLIST.delete('pi:' + id); delete MEMO.posts;
  await audit(env, req, 'eliminar artículo', id);
  return json({ ok: true }, 200, h);
}

/* ---------- Textos editables del sitio (editor oculto: cada texto se identifica por un hash de su versión original en español) ---------- */
const CT_KEY = /^[0-9a-f]{6,16}$/;
/* Solo se aceptan <b>, <i>, <em>, <strong>, <br> y <a href="…"> con enlaces http(s), mailto o relativos. Cualquier otro "<" se rechaza. */
const SAFE_TAG = /<\/?(b|i|em|strong|br)\s*\/?>|<a\s+href\s*=\s*("(https?:\/\/|mailto:)[^"<>]*"|'(https?:\/\/|mailto:)[^'<>]*'|"[\w#\/.?=&-]+"|'[\w#\/.?=&-]+')\s*>|<\/a\s*>/gi;
const safeText = (t) => !/[<>]/.test(t.replace(SAFE_TAG, ''));
async function contentList(env, h) {
  const items = await memo('content', async () => {
    const items = {}; let cursor;
    do { const r = await env.WAITLIST.list({ prefix: 'ct:', cursor }); for (const k of r.keys) { const v = await kvGet(env, k.name); if (v) items[k.name.slice(3)] = { es: v.es, en: v.en }; } cursor = r.list_complete ? undefined : r.cursor; } while (cursor);
    return items;
  });
  return new Response(JSON.stringify({ ok: true, items: items }), { status: 200, headers: Object.assign({ 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'public, max-age=30' }, h) });
}
async function contentSave(req, env, h) {
  { const g = await adminGate(req, env, h); if (g) return g; }
  const raw = await req.text(); if (raw.length > 30000) return json({ ok: false, error: 'size' }, 413, h);
  let b; try { b = JSON.parse(raw); } catch (e) { return json({ ok: false, error: 'json' }, 400, h); }
  if (!b || !CT_KEY.test(String(b.k || '')) || typeof b.es !== 'string' || typeof b.en !== 'string' || b.es.length > 6000 || b.en.length > 6000) return json({ ok: false, error: 'campos' }, 400, h);
  if (!safeText(b.es) || !safeText(b.en)) return json({ ok: false, error: 'html' }, 400, h); // el sitio también lo limpia al mostrarlo
  await kvPut(env, 'ct:' + b.k, { es: b.es, en: b.en, orig: String(b.orig || '').slice(0, 160), t: Date.now() }); delete MEMO.content;
  await audit(env, req, 'guardar texto', b.k);
  return json({ ok: true }, 200, h);
}
async function contentDel(req, env, h, url) {
  { const g = await adminGate(req, env, h); if (g) return g; }
  const k = url.searchParams.get('k') || ''; if (!CT_KEY.test(k)) return json({ ok: false, error: 'none' }, 404, h);
  await env.WAITLIST.delete('ct:' + k); delete MEMO.content; await audit(env, req, 'volver al texto original', k); return json({ ok: true }, 200, h);
}

/* ---------- Propuestas del rol mod ----------
 * Quien entra con MOD_TOKEN puede escribir Novedades y editar textos, pero nada se publica: queda una propuesta (pr:…, 14 días) que un dev ve y aprueba o rechaza.
 * Al aprobar, el servidor ejecuta la misma ruta de siempre con los mismos controles (HTML seguro, tamaños, campos). Un dev publica directo. */
const PROP_TTL = 14 * 86400, PROP_MAX = 40, EDIT_KINDS = { 'content': ['POST', '/content'], 'content-del': ['DELETE', '/content'], 'post': ['POST', '/posts'], 'post-del': ['DELETE', '/posts'] };
async function editRoute(req, env, h, url, kind, handler) {
  const a = await adminAuth(req, env, h, 'mod'); if (a.res) return a.res;
  if (a.role === 'dev') return handler(req, env, h, url);
  const body = req.method === 'DELETE' ? '' : await req.text(); if (body.length > 3000000) return json({ ok: false, error: 'size' }, 413, h);
  if (body) { try { JSON.parse(body); } catch (e) { return json({ ok: false, error: 'json' }, 400, h); } }
  let n = 0, cursor; do { const r = await env.WAITLIST.list({ prefix: 'pr:', cursor }); n += r.keys.length; cursor = r.list_complete ? undefined : r.cursor; } while (cursor);
  if (n >= PROP_MAX) return json({ ok: false, error: 'full' }, 429, h);   // hay demasiadas propuestas sin revisar
  const id = Date.now().toString(36) + '-' + rndB64(5);
  await kvPut(env, 'pr:' + id, { t: Date.now(), kind, q: url.search, body, by: a.who }, PROP_TTL);
  await audit(env, req, 'proponer ' + kind, id);
  return json({ ok: true, proposed: true, id }, 202, h);
}
async function propList(req, env, h) {
  { const g = await adminGate(req, env, h, 'dev'); if (g) return g; }
  const out = []; let cursor;
  do { const r = await env.WAITLIST.list({ prefix: 'pr:', cursor }); for (const k of r.keys) { const v = await kvGet(env, k.name); if (v) { let b = null; try { b = v.body ? JSON.parse(v.body) : null; } catch (e) { /* queda sin vista previa */ } if (b && typeof b.img === 'string' && b.img !== 'remove') b = Object.assign({}, b, { img: 'data:…(imagen)' }); out.push({ id: k.name.slice(3), t: v.t, kind: v.kind, q: v.q, by: v.by || '', b }); } } cursor = r.list_complete ? undefined : r.cursor; } while (cursor);
  out.sort((x, y) => y.t - x.t);
  return json({ ok: true, count: out.length, items: out }, 200, h);
}
async function propDecide(req, env, h, url) { // POST /admin/proposals/decide?id=…&do=approve|reject
  const a = await adminAuth(req, env, h, 'dev'); if (a.res) return a.res;
  const id = url.searchParams.get('id') || '', k = 'pr:' + id, v = /^[A-Za-z0-9_-]{4,40}$/.test(id) ? await kvGet(env, k) : null;
  if (!v) return json({ ok: false, error: 'none' }, 404, h);
  if (url.searchParams.get('do') === 'reject') { await env.WAITLIST.delete(k); await audit(env, req, 'rechazar propuesta', v.kind + ' · ' + id + (v.by ? ' · de ' + v.by : '')); return json({ ok: true, rejected: true }, 200, h); }
  const kind = EDIT_KINDS[v.kind]; if (!kind) { await env.WAITLIST.delete(k); return json({ ok: false, error: 'kind' }, 400, h); }
  const fake = new Request('https://internal' + kind[1] + (v.q || ''), { method: kind[0], body: kind[0] === 'DELETE' ? undefined : v.body, headers: { 'Content-Type': 'application/json' } });
  INTERNAL.add(fake); WHO.set(fake, a);
  const f = { content: contentSave, 'content-del': contentDel, post: postSave, 'post-del': postDel }[v.kind];
  const r = await f(fake, env, h, new URL(fake.url));
  if (r.status === 200) { await env.WAITLIST.delete(k); await audit(env, req, 'aprobar propuesta', v.kind + ' · ' + id + (v.by ? ' · de ' + v.by : '')); }
  return r;
}

/* ---------- Cuentas y sincronización (E2E: el servidor solo guarda texto cifrado) ---------- */
const CODE_TTL = 10 * 60 * 1000, SESSION_DAYS = 90, MAX_BLOB = 1500000, MAX_TRIES = 5;
const B64 = /^[A-Za-z0-9+/_=-]+$/;
async function shaFull(s) {
  const b = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s));
  return Array.from(new Uint8Array(b)).map((x) => x.toString(16).padStart(2, '0')).join('');
}
const rndB64 = (n) => { const a = new Uint8Array(n); crypto.getRandomValues(a); return btoa(String.fromCharCode.apply(null, a)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, ''); };
const rnd6 = () => { const a = new Uint32Array(1); let v; do { crypto.getRandomValues(a); v = a[0]; } while (v >= 4294000000); return String(v % 1000000).padStart(6, '0'); };
const same = (a, b) => { if (a.length !== b.length) return false; let d = 0; for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i); return d === 0; };
const emailKey = async (env, email) => (await shaFull(salt(env) + ':u:' + email)).slice(0, 40);
const kvGet = async (env, k) => { const v = await env.WAITLIST.get(k); try { return v ? JSON.parse(v) : null; } catch (e) { return null; } };
const kvPut = (env, k, o, ttl) => env.WAITLIST.put(k, JSON.stringify(o), ttl ? { expirationTtl: ttl } : undefined);

async function readBody(req, max) {
  const raw = await req.text();
  if (raw.length > (max || 2048)) return { err: 413 };
  try { const b = JSON.parse(raw); return b && typeof b === 'object' ? { b } : { err: 400 }; } catch (e) { return { err: 400 }; }
}
const needOrigin = (req, h) => (!h['Access-Control-Allow-Origin'] && (req.headers.get('Origin') || '')) ? json({ ok: false, error: 'origin' }, 403, h) : null;
const cleanEmail = (v) => { const e = String(v || '').trim().toLowerCase(); return e.length <= 254 && EMAIL.test(e) ? e : ''; };

function codeMail(lang, code, kind, x) {
  const es = lang !== 'en', F = "Inter,-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif";
  const t = es
    ? { subject: 'Tu código de Plata Cloud: ' + code, title: 'Tu código para entrar', lead: 'Escríbelo en Plata para iniciar sesión. Vence en 10 minutos.', warn: 'Si no lo pediste tú, ignora este correo: nadie puede entrar sin el código.' }
    : { subject: 'Your Plata Cloud code: ' + code, title: 'Your sign-in code', lead: 'Enter it in Plata to sign in. It expires in 10 minutes.', warn: "If you didn't request it, ignore this email: nobody can sign in without the code." };
  if (kind === 'replace') Object.assign(t, es
    ? { subject: 'Confirma el reemplazo de tu copia: ' + code, title: 'Confirma que quieres reemplazar tu copia en la nube', lead: 'Alguien pidió cargar un archivo de perfil y reemplazar lo que hay guardado en tu cuenta. Si fuiste tú, escribe este código en Plata. Vence en 10 minutos.', danger: 'ESTO BORRARÁ TU ÚLTIMA SINCRONIZACIÓN. NO LO HAGAS SI NO DESEAS PERDER TUS DATOS.', warn: 'Si no fuiste tú, ignora este correo y no compartas el código: sin él no se puede reemplazar nada.' }
    : { subject: 'Confirm replacing your cloud copy: ' + code, title: 'Confirm you want to replace your cloud copy', lead: 'Someone asked to load a profile file and replace what is saved in your account. If it was you, enter this code in Plata. It expires in 10 minutes.', danger: "THIS WILL ERASE YOUR LATEST SYNC. DON'T DO IT IF YOU DON'T WANT TO LOSE YOUR DATA.", warn: "If it wasn't you, ignore this email and don't share the code: nothing can be replaced without it." });
  if (kind === 'delete') Object.assign(t, es
    ? { subject: 'Confirma el borrado de tu cuenta: ' + code, title: 'Confirma que quieres borrar tu cuenta', lead: 'Alguien pidió borrar tu cuenta de Plata Cloud. Si fuiste tú, escribe este código en Plata. Vence en 10 minutos.', danger: 'ESTO BORRARÁ TU CUENTA Y TODA TU COPIA EN LA NUBE. NO LO HAGAS SI NO DESEAS PERDER TUS DATOS.', warn: 'Si no fuiste tú, ignora este correo y no compartas el código: sin él no se puede borrar nada.' }
    : { subject: 'Confirm deleting your account: ' + code, title: 'Confirm you want to delete your account', lead: 'Someone asked to delete your Plata Cloud account. If it was you, enter this code in Plata. It expires in 10 minutes.', danger: "THIS WILL DELETE YOUR ACCOUNT AND YOUR WHOLE CLOUD COPY. DON'T DO IT IF YOU DON'T WANT TO LOSE YOUR DATA.", warn: "If it wasn't you, ignore this email and don't share the code: nothing can be deleted without it." });
  let detRows = '', det = '';
  if (kind === 'link') { x = x || {}; det = (x.plat || '?') + (x.tz ? ' · ' + x.tz.split('/').pop().replace(/_/g, ' ') : '') + (x.when ? ' · ' + x.when : '');
    const os = String(x.plat || '').split(' · ')[0], ico = os === 'iPhone' || os === 'iPad' ? 'apple' : os === 'Android' ? 'android' : os === 'Mac' ? 'macbook' : os === 'Windows' ? 'windows' : os === 'Linux' ? 'computer' : 'smartphone';
    const item = (ic, tx) => '<tr><td align="center" style="text-align:center;padding:0 0 8px"><table role="presentation" align="center" cellpadding="0" cellspacing="0" border="0"><tr><td valign="middle" style="padding:0 10px 0 0"><img src="' + MAIL_IC(ic) + '" width="20" height="20" alt="" style="display:block;margin:0 auto;border:0;width:20px;height:20px"></td><td valign="middle" style="font:600 15px/1.3 ' + F + ';color:#1C1C1E">' + String(tx).replace(/&/g, '&amp;').replace(/</g, '&lt;') + '</td></tr></table></td></tr>';
    const city = x.tz ? x.tz.split('/').pop().replace(/_/g, ' ') : '';
    detRows = '<tr><td align="center" style="text-align:center;padding:0 32px 20px"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#F2F2F4;border-radius:18px"><tr><td align="center" style="text-align:center;padding:16px 18px 8px"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
      + item(ico, os || (es ? 'Dispositivo' : 'Device')) + (city ? item('global', city) : '') + (x.when ? item('time', x.when) : '') + '</table></td></tr></table></td></tr>';
    Object.assign(t, es
    ? { subject: 'Alguien quiere entrar a tu cuenta de Plata Cloud', title: 'Alguien quiere entrar a tu cuenta', lead: 'Se pidió iniciar sesión en tu cuenta con estos datos. Para aprobarlo, abre Plata en un dispositivo donde ya tengas sesión: en Ajustes verás la solicitud y un código de 6 dígitos. Apruébala solo si es el mismo código que ves en el dispositivo nuevo. Vence en 10 minutos.', danger: 'APRUÉBALO SOLO SI FUISTE TÚ.', warn: 'Si no fuiste tú, recházalo en Plata o ignora este correo: sin tu aprobación nadie puede entrar.' }
    : { subject: 'Someone wants to sign in to your Plata Cloud account', title: 'Someone wants to sign in to your account', lead: 'A sign-in was requested on your account with these details. To approve it, open Plata on a device where you are already signed in: you will see the request in Settings and a 6-digit code. Only approve it if the code is the same one shown on the new device. It expires in 10 minutes.', danger: 'ONLY APPROVE IT IF IT WAS YOU.', warn: "If it wasn't you, decline it in Plata or ignore this email: nobody can sign in without your approval." }); }
  const spaced = code ? code.slice(0, 3) + ' ' + code.slice(3) : '';
  const dangerRow = t.danger ? '<tr><td align="center" style="text-align:center;padding:0 32px 20px"><table role="presentation" align="center" cellpadding="0" cellspacing="0" border="0"><tr><td valign="top" style="padding:2px 10px 0 0"><img src="' + MAIL_WARN + '" width="22" height="22" alt="!" style="display:block;margin:0 auto;border:0;width:22px;height:22px"></td><td style="font:800 16px/1.45 ' + F + ';color:#D70015">' + t.danger + '</td></tr></table></td></tr>' : '';
  const html = '<!doctype html><html lang="' + (es ? 'es' : 'en') + '"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="only light"><title>' + t.subject + '</title></head><body style="margin:0;padding:0;background:#FFFFFF">'
    + '<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent">' + (code || t.title) + '</div>'
    + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#FFFFFF"><tr><td align="center"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:520px">'
    + '<tr><td><img src="' + MAIL_CLOUDS + '" width="520" alt="" style="display:block;margin:0 auto;border:0;width:100%;max-width:520px;height:auto"></td></tr>'
    + '<tr><td align="left" style="text-align:left;padding:6px 32px 0"><img src="' + MAIL_LOGO + '" width="140" height="49" alt="Plata Cloud" style="display:block;border:0;height:auto;width:140px"></td></tr>'
    + '<tr><td align="center" style="text-align:center;padding:22px 32px 8px;font:800 28px/1.15 ' + F + ';letter-spacing:-0.02em;color:#1C1C1E">' + t.title + '</td></tr>'
    + '<tr><td align="center" style="text-align:center;padding:0 32px 22px;font:400 16px/1.55 ' + F + ';color:#5B5B60">' + t.lead + '</td></tr>'
    + detRows + dangerRow
    + (code ? '<tr><td align="center" style="text-align:center;padding:0 32px 24px"><div style="display:inline-block;margin:0 auto;background:#E9F6EF;border-radius:18px;padding:18px 28px;font:800 40px/1 ' + F + ';letter-spacing:0.12em;color:#13774C">' + spaced + '</div></td></tr>' : '')
    + '<tr><td align="center" style="text-align:center;padding:0 32px 18px;font:400 13px/1.5 ' + F + ';color:#8A8A8F">' + t.warn + '</td></tr>'
    + socialRow(F)
    + '</table></td></tr></table></body></html>';
  return { subject: t.subject, html, text: t.title + '\n\n' + (spaced ? spaced + '\n\n' : '') + t.lead + (kind === 'link' ? '\n' + det : '') + '\n\n' + (t.danger ? t.danger + '\n\n' : '') + t.warn + '\n' };
}
async function sendCodeMail(env, email, lang, code, kind, x) {
  if (!env.RESEND_API_KEY) return;
  const m = codeMail(lang, code, kind, x);
  try {
    const r = await fetch('https://api.resend.com/emails', { method: 'POST', headers: { Authorization: 'Bearer ' + env.RESEND_API_KEY, 'Content-Type': 'application/json' }, body: JSON.stringify({ from: MAIL_FROM, to: [email], subject: m.subject, html: m.html, text: m.text }) });
    if (!r.ok) console.log('resend code', r.status);
  } catch (e) { console.log('resend code fail'); }
}

/* Códigos de 6 dígitos (correo): guardados como hash en el Gate, con intentos contados sin carreras. */
const codeHash = async (env, tag, ek, code) => shaFull(salt(env) + ':' + tag + ':' + ek + ':' + code);
async function codeSet(env, tag, ek, code) { await gate(env, tag + ':' + ek, { op: 'set', val: await codeHash(env, tag, ek, code), ttl: CODE_TTL / 1000 }); }
async function codeTry(env, tag, ek, code, keep) {
  if (!/^\d{6}$/.test(code)) return false;
  return (await gate(env, tag + ':' + ek, { op: 'try', val: await codeHash(env, tag, ek, code), max: MAX_TRIES, keep: !!keep })).ok;
}
const isTester = (env, email) => env.CLOUD_OPEN === '1' || list(String(env.CLOUD_TESTERS || '').toLowerCase()).includes(email);
const hourOf = () => Math.floor(Date.now() / 3600000), minOf = () => Math.floor(Date.now() / 60000), dayOf = () => Math.floor(Date.now() / 86400000);
const MAX_FAILS_DAY = 15;

async function authStart(req, env, h, ctx) {
  const o = needOrigin(req, h); if (o) return o;
  const { b, err } = await readBody(req); if (err) return json({ ok: false, error: err === 413 ? 'size' : 'json' }, err, h);
  const email = cleanEmail(b.email); if (!email) return json({ ok: false, error: 'email' }, 400, h);
  const ek = await emailKey(env, email);
  if (await hit(env, (await ipKey(req, env, 'rl:ai')) + ':' + hourOf(), 20, 7200) || await hit(env, 'rl:ae:' + ek.slice(0, 24) + ':' + hourOf(), 5, 7200)) return json({ ok: false, error: 'rate' }, 429, h);
  let allowed = isTester(env, email), listed = false;
  if (!allowed) { const u = await kvGet(env, 'u:' + ek); const w = await kvGet(env, 'w:' + email); allowed = !!u || !!(w && w.inv); listed = !allowed && !!w; }
  if (allowed) {
    const code = rnd6();
    await codeSet(env, 'c', ek, code);
    const p = sendCodeMail(env, email, b.lang === 'en' ? 'en' : 'es', code);
    if (ctx && ctx.waitUntil) ctx.waitUntil(p); else await p;
  }
  // La app necesita saber si debe pedir el código o llevar a la lista de espera. Solo se revela "tiene acceso / está en la lista / no", con límite de intentos por correo y por conexión.
  return json({ ok: true, access: allowed, listed: listed }, 200, h);
}

async function newSession(env, ek, u, dev) {
  const token = rndB64(32);
  await kvPut(env, 's:' + (await shaFull(token)), { u: ek, sv: u.sv || 0, dev: String(dev || '').slice(0, 40), t: Date.now() }, SESSION_DAYS * 86400);
  return token;
}
async function authVerify(req, env, h) {
  const o = needOrigin(req, h); if (o) return o;
  const { b, err } = await readBody(req); if (err) return json({ ok: false, error: err === 413 ? 'size' : 'json' }, err, h);
  const email = cleanEmail(b.email), code = String(b.code || '').replace(/\s/g, '');
  if (!email || !/^\d{6}$/.test(code)) return json({ ok: false, error: 'code' }, 400, h);
  if (await hit(env, (await ipKey(req, env, 'rl:av')) + ':' + minOf(), 30, 180)) return json({ ok: false, error: 'rate' }, 429, h);
  const ek = await emailKey(env, email), vf = 'rl:vf:' + ek.slice(0, 24) + ':' + dayOf();
  // Cada código admite 5 intentos, pero se pueden pedir 5 códigos por hora: este tope corta la suma (máx. 15 fallos al día por correo).
  if ((await gate(env, vf, { op: 'peek' })).n >= MAX_FAILS_DAY) return json({ ok: false, error: 'rate' }, 429, h);
  if (!(await codeTry(env, 'c', ek, code))) { await hit(env, vf, MAX_FAILS_DAY, 2 * 86400); return json({ ok: false, error: 'code' }, 400, h); }
  let u = await kvGet(env, 'u:' + ek), isNew = false;
  if (!u) { isNew = true; u = { email, t: Date.now(), kc: '' }; await kvPut(env, 'u:' + ek, u); }
  const token = await newSession(env, ek, u, b.dev);
  const d = await kvGet(env, 'd:' + ek);
  return json({ ok: true, token, new: isNew, hasKey: !!u.kc, kc: u.kc || '', hasData: !!d, rev: d ? d.rev : 0 }, 200, h);
}

async function session(req, env) {
  const m = /^Bearer ([A-Za-z0-9_-]{20,80})$/.exec(req.headers.get('Authorization') || ''); if (!m) return null;
  const sk = 's:' + (await shaFull(m[1])), s = await kvGet(env, sk); if (!s) return null;
  const u = await kvGet(env, 'u:' + s.u); if (!u) return null;
  if ((s.sv || 0) !== (u.sv || 0)) return null; // "Cerrar sesión en todos los dispositivos" invalida las sesiones anteriores
  return { sk, ek: s.u, u };
}
const unauth = (h) => json({ ok: false, error: 'auth' }, 401, h);

/* Llave de escritura: sale de la frase de 12 palabras (HKDF, rama "write"), así que quien solo tiene acceso al correo
 * puede leer el texto cifrado, pero no puede pisar, reemplazar ni borrar la copia. El servidor guarda solo su hash. */
const WK = /^[A-Za-z0-9_-]{40,64}$/;
async function writeOk(req, env, a) {
  const wk = req.headers.get('X-Plata-Write') || '';
  if (!WK.test(wk)) return false;
  const wh = await shaFull('wk:' + wk);
  if (a.u.wh) return same(a.u.wh, wh);
  a.u.wh = wh; await kvPut(env, 'u:' + a.ek, a.u); return true; // cuentas creadas antes de esta versión: se fija la primera vez que escriben
}
const noWrite = (h) => json({ ok: false, error: 'wk' }, 403, h);
const revFloor = async (env, ek) => Number(await env.WAITLIST.get('n:' + ek)) || 0; // la revisión nunca retrocede, ni después de borrar la copia

async function me(req, env, h) {
  const a = await session(req, env); if (!a) return unauth(h);
  if (!a.u.wh && a.u.kc) await writeOk(req, env, a); // cuentas anteriores a la 421: la llave se fija apenas un dispositivo con la frase se conecta
  const d = await kvGet(env, 'd:' + a.ek);
  return json({ ok: true, email: a.u.email, hasKey: !!a.u.kc, kc: a.u.kc || '', hasData: !!d, rev: d ? d.rev : 0, t: d ? d.t : 0 }, 200, h);
}
async function setKey(req, env, h) {
  const o = needOrigin(req, h); if (o) return o;
  const a = await session(req, env); if (!a) return unauth(h);
  const { b, err } = await readBody(req, 512); if (err) return json({ ok: false, error: 'json' }, err, h);
  if (typeof b.kc !== 'string' || !B64.test(b.kc) || b.kc.length < 16 || b.kc.length > 128) return json({ ok: false, error: 'kc' }, 400, h);
  if (a.u.kc) return json({ ok: false, error: 'exists' }, 409, h); // la comprobación de clave se fija una vez, al crear la cuenta
  const wk = req.headers.get('X-Plata-Write') || '';
  if (!WK.test(wk)) return noWrite(h);
  a.u.kc = b.kc; a.u.wh = await shaFull('wk:' + wk); await kvPut(env, 'u:' + a.ek, a.u);
  return json({ ok: true }, 200, h);
}
async function syncGet(req, env, h) {
  const a = await session(req, env); if (!a) return unauth(h);
  if (!a.u.wh && a.u.kc) await writeOk(req, env, a);
  const d = await kvGet(env, 'd:' + a.ek), next = Math.max(d ? d.rev : 0, await revFloor(env, a.ek)) + 1;
  return json(d ? { ok: true, rev: d.rev, next, blob: d.blob, t: d.t, v: d.v, dev: d.dev } : { ok: true, rev: 0, next }, 200, h);
}
async function syncDelete(req, env, h) {
  const o = needOrigin(req, h); if (o) return o;
  const a = await session(req, env); if (!a) return unauth(h);
  if (!(await writeOk(req, env, a))) return noWrite(h);
  if (await hit(env, 'rl:sw:' + a.ek.slice(0, 24) + ':' + hourOf(), 10, 7200)) return json({ ok: false, error: 'rate' }, 429, h);
  const cur = await kvGet(env, 'd:' + a.ek);
  if (cur) await env.WAITLIST.put('n:' + a.ek, String(Math.max(cur.rev, await revFloor(env, a.ek))));
  for (const k of ['d:', 'p:']) await env.WAITLIST.delete(k + a.ek); // solo la copia cifrada y su respaldo: la cuenta y la sesión siguen
  return json({ ok: true }, 200, h);
}
async function syncConfirm(req, env, h, ctx) {
  const o = needOrigin(req, h); if (o) return o;
  const a = await session(req, env); if (!a) return unauth(h);
  const { b } = await readBody(req);
  if (await hit(env, 'rl:sc:' + a.ek.slice(0, 24) + ':' + hourOf(), 5, 7200)) return json({ ok: false, error: 'rate' }, 429, h);
  const code = rnd6();
  await codeSet(env, 'c2', a.ek, code);
  const p = sendCodeMail(env, a.u.email, (b && b.lang) === 'en' ? 'en' : 'es', code, b && b.kind === 'delete' ? 'delete' : 'replace');
  if (ctx && ctx.waitUntil) ctx.waitUntil(p); else await p;
  return json({ ok: true }, 200, h);
}
async function syncPut(req, env, h) {
  const o = needOrigin(req, h); if (o) return o;
  const a = await session(req, env); if (!a) return unauth(h);
  if (await hit(env, 'rl:sp:' + a.ek.slice(0, 24) + ':' + minOf(), 30, 180)) return json({ ok: false, error: 'rate' }, 429, h);
  const { b, err } = await readBody(req, MAX_BLOB + 1024); if (err) return json({ ok: false, error: err === 413 ? 'size' : 'json' }, err, h);
  if (b.demo === true) return json({ ok: false, error: 'demo' }, 403, h); // un perfil de demostración nunca se sube
  if (!a.u.kc) return json({ ok: false, error: 'nokey' }, 409, h);
  if (!(await writeOk(req, env, a))) return noWrite(h);
  if (typeof b.blob !== 'string' || !b.blob.length || b.blob.length > MAX_BLOB || !B64.test(b.blob)) return json({ ok: false, error: 'blob' }, 400, h);
  const cur = await kvGet(env, 'd:' + a.ek), curRev = cur ? cur.rev : 0, next = Math.max(curRev, await revFloor(env, a.ek)) + 1;
  if (b.replace === true && curRev > 0) { // reemplazo total (archivo de perfil): exige además el código enviado al correo
    if (!(await codeTry(env, 'c2', a.ek, String(b.code || '').replace(/\s/g, '')))) return json({ ok: false, error: 'code' }, 400, h);
  } else if (Number(b.base) !== curRev) return json({ ok: false, error: 'conflict', rev: curRev, next, t: cur ? cur.t : 0 }, 409, h);
  // La app cifra la revisión dentro de la copia: si no coincide con la que se asignaría, la copia se armó contra otro estado
  if (b.next != null && Number(b.next) !== next) return json({ ok: false, error: 'conflict', rev: curRev, next, t: cur ? cur.t : 0 }, 409, h);
  if (cur) await kvPut(env, 'p:' + a.ek, cur); // copia anterior: una red de seguridad contra errores de un dispositivo
  const nd = { rev: next, blob: b.blob, t: Date.now(), v: Number(b.v) || 1, dev: String(b.dev || '').slice(0, 40) };
  await kvPut(env, 'd:' + a.ek, nd);
  return json({ ok: true, rev: nd.rev, t: nd.t }, 200, h);
}
async function logout(req, env, h) {
  const a = await session(req, env); if (!a) return unauth(h);
  await env.WAITLIST.delete(a.sk);
  return json({ ok: true }, 200, h);
}
async function logoutAll(req, env, h) { // cierra todas las sesiones (por si se perdió o robaron un dispositivo) y devuelve una nueva para este
  const o = needOrigin(req, h); if (o) return o;
  const a = await session(req, env); if (!a) return unauth(h);
  if (!(await writeOk(req, env, a))) return noWrite(h); // pide la frase: quien solo tiene el correo no puede echar al dueño
  a.u.sv = (a.u.sv || 0) + 1; await kvPut(env, 'u:' + a.ek, a.u);
  await env.WAITLIST.delete(a.sk);
  const { b } = await readBody(req);
  return json({ ok: true, token: await newSession(env, a.ek, a.u, b && b.dev) }, 200, h);
}
async function syncCheck(req, env, h) {
  const o = needOrigin(req, h); if (o) return o;
  const a = await session(req, env); if (!a) return unauth(h);
  const { b } = await readBody(req);
  if (!(await codeTry(env, 'c2', a.ek, String((b && b.code) || '').replace(/\s/g, ''), true))) return json({ ok: false, error: 'code' }, 400, h);
  return json({ ok: true }, 200, h);
}
async function delAccount(req, env, h) {
  const o = needOrigin(req, h); if (o) return o;
  const a = await session(req, env); if (!a) return unauth(h);
  const { b } = await readBody(req);
  if (!(await codeTry(env, 'c2', a.ek, String((b && b.code) || '').replace(/\s/g, '')))) return json({ ok: false, error: 'code' }, 400, h);
  for (const k of ['u:', 'd:', 'p:', 'n:']) await env.WAITLIST.delete(k + a.ek);
  await gate(env, 'link:' + a.ek, { op: 'del' });
  await env.WAITLIST.delete(a.sk); // las demás sesiones dejan de valer solas: sin cuenta, session() devuelve null
  return json({ ok: true }, 200, h);
}

/* ---- Aprobar un inicio de sesión desde un dispositivo con sesión activa ----------------------------------------------
 * Comparación numérica con compromiso previo (como el emparejamiento Bluetooth "numeric comparison"):
 *  1. Nuevo (N) → start: su clave pública efímera pkN.                                   estado p
 *  2. Activo (A) → commit: c = SHA-256(pkA ‖ nA), sin revelar pkA ni nA.                 estado c
 *  3. N → nonce: nN aleatorio, elegido después de ver c.                                  estado n
 *  4. A → reveal: pkA y nA. N comprueba c. Ambos muestran el código de 6 dígitos
 *     derivado de pkN ‖ pkA ‖ nA ‖ nN. La persona compara las dos pantallas.              estado r
 *  5. A → answer: la semilla cifrada con ECDH(pkA, pkN), solo si la persona aprueba.      estado a / d
 * Quien esté en medio (incluido este servidor) tiene que fijar su clave antes de conocer el aleatorio del otro lado, así que no puede
 * fabricar a la fuerza una clave con el mismo código: acertar es 1 en un millón. El estado vive en el Gate: cada paso es atómico. */
const LINK_TTL = 10 * 60 * 1000, B64U = /^[A-Za-z0-9_-]+$/;
const b64ok = (v, min, max) => typeof v === 'string' && v.length >= min && v.length <= max && B64U.test(v);
const linkTtl = (L) => Math.max(5, Math.round((L.t + LINK_TTL - Date.now()) / 1000));
const linkGet = async (env, ek) => (await gate(env, 'link:' + ek, { op: 'get' })).val;
const linkStep = async (env, ek, expect, L) => (await gate(env, 'link:' + ek, { op: 'cas', expect, val: L, ttl: L ? linkTtl(L) : 1 })).ok;

async function linkStart(req, env, h, ctx) {
  const o = needOrigin(req, h); if (o) return o;
  const { b, err } = await readBody(req, 1024); if (err) return json({ ok: false, error: err === 413 ? 'size' : 'json' }, err, h);
  const email = cleanEmail(b.email), pub = String(b.pub || ''), rid = String(b.rid || '');
  if (!email || !b64ok(pub, 60, 140) || !b64ok(rid, 20, 64)) return json({ ok: false, error: 'bad' }, 400, h);
  const ek = await emailKey(env, email);
  if (await hit(env, (await ipKey(req, env, 'rl:li')) + ':' + hourOf(), 10, 7200) || await hit(env, 'rl:le:' + ek.slice(0, 24) + ':' + hourOf(), 4, 7200)) return json({ ok: false, error: 'rate' }, 429, h);
  const u = await kvGet(env, 'u:' + ek);
  let allowed = !!u || isTester(env, email), listed = false;
  if (!allowed) { const w = await kvGet(env, 'w:' + email); allowed = !!(w && w.inv); listed = !allowed && !!w; }
  if (u && u.kc) { // solo hay algo que aprobar si la cuenta ya tiene llave; la respuesta es igual haya o no cuenta
    const L = { st: 'p', rh: await shaFull(rid), pub, plat: String(b.plat || '').slice(0, 40), tz: String(b.tz || '').slice(0, 40), t: Date.now() };
    await linkStep(env, ek, undefined, L); // una solicitud nueva reemplaza a la anterior (el protocolo vuelve a empezar)
    let when = ''; try { when = new Date(L.t).toLocaleString(b.lang === 'en' ? 'en-US' : 'es', { timeZone: L.tz || 'UTC', dateStyle: 'medium', timeStyle: 'short' }); } catch (e) { /* zona no válida */ }
    const p = sendCodeMail(env, email, b.lang === 'en' ? 'en' : 'es', '', 'link', { plat: L.plat, tz: L.tz, when });
    if (ctx && ctx.waitUntil) ctx.waitUntil(p); else await p;
  }
  return json({ ok: true, access: allowed, listed: listed }, 200, h);
}
async function linkPending(req, env, h) { // A: ¿hay una solicitud? y, si N ya mandó su aleatorio, cuál es
  const a = await session(req, env); if (!a) return unauth(h);
  const L = await linkGet(env, a.ek);
  if (!L || !['p', 'c', 'n', 'r'].includes(L.st)) return json({ ok: true, req: null }, 200, h);
  return json({ ok: true, req: { pub: L.pub, plat: L.plat, tz: L.tz, t: L.t, st: L.st, nn: L.nn || '' } }, 200, h);
}
async function linkA(req, env, h) { // pasos del dispositivo activo: commit, reveal y answer
  const o = needOrigin(req, h); if (o) return o;
  const a = await session(req, env); if (!a) return unauth(h);
  const { b, err } = await readBody(req, 1024); if (err) return json({ ok: false, error: 'json' }, err, h);
  const L = await linkGet(env, a.ek), gone = () => json({ ok: false, error: 'gone' }, 404, h), bad = () => json({ ok: false, error: 'bad' }, 400, h);
  if (!L || b.pub !== L.pub) return gone();
  let ok = false;
  if (b.step === 'commit') { if (!b64ok(b.c, 40, 48)) return bad(); ok = await linkStep(env, a.ek, 'p', Object.assign({}, L, { st: 'c', c: b.c })); }
  else if (b.step === 'reveal') { if (!b64ok(b.apub, 60, 140) || !b64ok(b.na, 20, 32)) return bad(); ok = await linkStep(env, a.ek, 'n', Object.assign({}, L, { st: 'r', apub: b.apub, na: b.na })); }
  else if (b.step === 'answer' && b.ok === true) { if (!b64ok(b.iv, 8, 24) || !b64ok(b.ct, 8, 80)) return bad(); ok = await linkStep(env, a.ek, 'r', Object.assign({}, L, { st: 'a', iv: b.iv, ct: b.ct })); }
  else if (b.step === 'answer') ok = await linkStep(env, a.ek, ['p', 'c', 'n', 'r'], Object.assign({}, L, { st: 'd' }));
  else return bad();
  return ok ? json({ ok: true }, 200, h) : json({ ok: false, error: 'state' }, 409, h);
}
async function linkN(req, env, h) { // pasos del dispositivo nuevo: poll y nonce (se identifica con su rid, que solo él conoce)
  const o = needOrigin(req, h); if (o) return o;
  const { b, err } = await readBody(req, 512); if (err) return json({ ok: false, error: 'json' }, err, h);
  const email = cleanEmail(b.email), rid = String(b.rid || ''); if (!email || !b64ok(rid, 20, 64)) return json({ ok: false, error: 'bad' }, 400, h);
  const ek = await emailKey(env, email);
  if (await hit(env, (await ipKey(req, env, 'rl:lp')) + ':' + minOf(), 60, 180) || await hit(env, 'rl:lp:' + ek.slice(0, 24) + ':' + minOf(), 40, 180)) return json({ ok: false, error: 'rate' }, 429, h);
  const L = await linkGet(env, ek);
  if (!L || !same(L.rh, await shaFull(rid))) return json({ ok: true, st: 'x' }, 200, h);
  if (b.step === 'nonce') {
    if (!b64ok(b.nn, 20, 32)) return json({ ok: false, error: 'bad' }, 400, h);
    return (await linkStep(env, ek, 'c', Object.assign({}, L, { st: 'n', nn: b.nn }))) ? json({ ok: true, st: 'n' }, 200, h) : json({ ok: false, error: 'state' }, 409, h);
  }
  if (L.st === 'p' || L.st === 'n') return json({ ok: true, st: L.st }, 200, h);
  if (L.st === 'c') return json({ ok: true, st: 'c', c: L.c }, 200, h);
  if (L.st === 'r') return json({ ok: true, st: 'r', c: L.c, apub: L.apub, na: L.na }, 200, h);
  if (!(await linkStep(env, ek, L.st, null))) return json({ ok: true, st: 'x' }, 200, h); // la aprobación o el rechazo se recogen una sola vez
  if (L.st === 'd') return json({ ok: true, st: 'd' }, 200, h);
  const u = await kvGet(env, 'u:' + ek); if (!u) return json({ ok: true, st: 'x' }, 200, h);
  return json({ ok: true, st: 'a', token: await newSession(env, ek, u, L.plat), kc: u.kc || '', apub: L.apub, na: L.na, iv: L.iv, ct: L.ct }, 200, h);
}

const INV_TXT = {
  es: { subject: 'Ya tienes acceso a Plata Cloud', pre: 'Tu lugar está listo. Entra cuando quieras.', title: 'Tu acceso está listo.',
    lead: 'Te autorizamos para usar Plata Cloud en la marcha blanca gratuita. Ya puedes crear tu cuenta con este mismo correo.',
    steps: ['Abre Plata en plataapp.net/app.', 'Ve a Ajustes y entra a Plata Cloud.', 'Escribe este correo y confirma el código que te llega.'],
    btn: 'Abrir Plata', thanks: 'Gracias por confiar en Plata <3', sig: ['Leonardo Richarte,', 'Fundador de Plata & Estudio 2²'],
    foot: 'Recibiste este correo porque este correo está en la lista de espera de Plata Cloud. Si no fuiste tú, ignóralo: nadie puede entrar sin el código que llega a tu bandeja.' },
  en: { subject: 'You now have access to Plata Cloud', pre: 'Your spot is ready. Come in whenever you like.', title: 'Your access is ready.',
    lead: 'We authorized you to use Plata Cloud during the free trial run. You can now create your account with this same email.',
    steps: ['Open Plata at plataapp.net/app.', 'Go to Settings and open Plata Cloud.', 'Enter this email and confirm the code we send you.'],
    btn: 'Open Plata', thanks: 'Thanks for trusting Plata <3', sig: ['Leonardo Richarte,', 'Founder of Plata & Estudio 2²'],
    foot: 'You got this email because this address is on the Plata Cloud waitlist. If it was not you, ignore it: nobody can get in without the code sent to your inbox.' }
};
function inviteMail(lang) {
  const t = INV_TXT[lang] || INV_TXT.en, G = '#22B573', F = "Inter,-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif";
  const url = 'https://plataapp.net/app/', th = t.thanks.replace('<', '&lt;');
  const li = t.steps.map((x, i) => '<tr><td align="center" style="text-align:center;padding:0 0 12px 0;font:400 15px/1.5 ' + F + ';color:#5B5B60"><b style="color:' + G + '">' + (i + 1) + '.</b>&nbsp; ' + x + '</td></tr>').join('');
  const html = '<!doctype html><html lang="' + (INV_TXT[lang] ? lang : 'en') + '"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="only light"><title>' + t.subject + '</title></head><body style="margin:0;padding:0;background:#FFFFFF">'
    + '<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent">' + t.pre + '</div>'
    + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td align="center"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:560px">'
    + '<tr><td><img src="' + MAIL_CLOUDS + '" width="560" alt="" style="display:block;margin:0 auto;border:0;width:100%;height:auto"></td></tr>'
    + '<tr><td align="center" style="text-align:center;padding:6px 34px 0"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
    + '<tr><td align="left" style="text-align:left;padding:0 0 20px 0"><img src="' + MAIL_LOGO + '" width="150" height="52" alt="Plata Cloud" style="display:block;border:0;width:150px;height:auto"></td></tr>'
    + '<tr><td align="center" style="text-align:center;padding:0 0 14px 0;font:800 36px/1.1 ' + F + ';letter-spacing:-0.03em;color:#1C1C1E">' + t.title + '</td></tr>'
    + '<tr><td align="center" style="text-align:center;padding:6px 0 30px 0"><img src="' + MAIL_KEY + '" width="132" height="126" alt="" style="display:block;margin:0 auto;border:0;width:132px;height:auto"></td></tr>'
    + '<tr><td align="center" style="text-align:center;padding:0 0 22px 0;font:400 17px/1.55 ' + F + ';color:#5B5B60">' + t.lead + '</td></tr>' + li
    + '<tr><td align="center" style="text-align:center;padding:14px 0 26px 0"><a href="' + url + '" style="display:inline-block;background:' + G + ';color:#FFFFFF;text-decoration:none;border-radius:999px;padding:14px 26px;font:700 16px/1 ' + F + '">' + t.btn + '</a></td></tr>'
    + '<tr><td align="center" style="text-align:center;padding:0 0 14px 0;font:500 16px/1.4 ' + F + ';color:#1C1C1E">' + th + '</td></tr>'
    + '<tr><td align="center" style="text-align:center;padding:0 0 30px 0;font:700 15px/1.45 ' + F + ';color:#1C1C1E">' + t.sig[0] + '<br><span style="font-weight:500;color:#5B5B60">' + t.sig[1] + '</span></td></tr>'
    + socialRow(F)
    + '</table></td></tr><tr><td align="center" style="text-align:center;padding:0 34px 34px;font:400 12.5px/1.5 ' + F + ';color:#8A8A8F">' + t.foot + '</td></tr></table></td></tr></table></body></html>';
  const text = t.title + '\n\n' + t.lead + '\n\n' + t.steps.map((x, i) => (i + 1) + '. ' + x).join('\n') + '\n\n' + t.btn + ': ' + url + '\n\n' + t.thanks + '\n' + t.sig[0] + ' ' + t.sig[1] + '\n\n' + t.foot + '\n';
  return { subject: t.subject, html, text };
}
async function sendInviteMail(env, email, lang) {
  if (!env.RESEND_API_KEY) return false;
  const m = inviteMail(lang);
  try {
    const r = await fetch('https://api.resend.com/emails', { method: 'POST', headers: { Authorization: 'Bearer ' + env.RESEND_API_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ from: MAIL_FROM, to: [email], subject: m.subject, html: m.html, text: m.text }) });
    return r.ok;
  } catch (e) { return false; }
}
// Autoriza (inv=1), opcionalmente avisa por correo (send), o revoca (revoke). Solo con ADMIN_TOKEN.
async function adminInvite(req, env, h) {
  { const g = await adminGate(req, env, h); if (g) return g; }
  const { b, err } = await readBody(req, 20000); if (err) return json({ ok: false, error: 'json' }, err, h);
  const list = Array.isArray(b.emails) ? b.emails.slice(0, 200) : []; let done = 0, mailed = 0, failed = [], missing = [];
  for (const raw of list) {
    const email = cleanEmail(raw); if (!email) { missing.push(String(raw).slice(0, 60)); continue; }
    const w = await kvGet(env, 'w:' + email); if (!w) { missing.push(email); continue; }
    if (b.revoke) { w.inv = 0; delete w.invAt; await kvPut(env, 'w:' + email, w); done++; continue; }
    w.inv = 1; if (!w.invAt) w.invAt = Date.now();
    if (b.send) { if (await sendInviteMail(env, email, w.lang)) { w.mail = Date.now(); mailed++; } else failed.push(email); }
    await kvPut(env, 'w:' + email, w); done++;
  }
  return json({ ok: true, invited: done, mailed, mailFailed: failed, notFound: missing, mailOn: !!env.RESEND_API_KEY }, 200, h);
}

export default {
  async fetch(req, env, ctx) {
    const url = new URL(req.url), h = cors(req, env, isAdminReq(req, url));
    if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: h });
    try {
      if (url.pathname === '/health') return json({ ok: true }, 200, h);
      if (url.pathname === '/waitlist' && req.method === 'POST') return await join(req, env, h, ctx);
      if (url.pathname === '/waitlist/export' && req.method === 'GET') return await exportList(req, env, h);
      const p = url.pathname, m = req.method;
      if (p === '/content' && m === 'GET') return await contentList(env, h);
      if (p === '/content/ping' && m === 'GET') return (await adminGate(req, env, h, 'mod')) || json({ ok: true }, 200, h);
      if (p === '/admin/session' && m === 'POST') return await adminSession(req, env, h);
      if (p === '/admin/logout' && m === 'POST') return await adminLogout(req, env, h);
      if (p === '/admin/users' && m === 'GET') return await usersList(req, env, h);
      if (p === '/admin/users' && m === 'POST') return await usersCreate(req, env, h);
      if (p === '/admin/users/title' && m === 'POST') return await usersTitle(req, env, h, url);
      if (p === '/admin/nazca/lib' && m === 'GET') return await nzLibList(req, env, h);
      if (p === '/admin/nazca/lib' && m === 'POST') return await nzLibSave(req, env, h);
      if (p === '/admin/nazca/lib' && m === 'DELETE') return await nzLibDel(req, env, h, url);
      if (p === '/admin/nazca/lib/get' && m === 'GET') return await nzLibGet(req, env, h, url);
      if (p === '/admin/board' && m === 'GET') return await boardList(req, env, h);
      if (p === '/admin/board' && m === 'POST') return await boardSave(req, env, h);
      if (p === '/admin/board' && m === 'DELETE') return await boardDel(req, env, h, url);
      if (p === '/admin/board/comment' && (m === 'POST' || m === 'DELETE')) return await boardComment(req, env, h, url);
      if (p === '/admin/board/vote' && m === 'POST') return await boardVote(req, env, h, url);
      if (p === '/admin/users/revoke' && m === 'POST') return await usersRevoke(req, env, h, url);
      if (p === '/admin/audit' && m === 'GET') return await auditList(req, env, h, url);
      if (p === '/admin/proposals' && m === 'GET') return await propList(req, env, h);
      if (p === '/admin/proposals/decide' && m === 'POST') return await propDecide(req, env, h, url);
      if (p === '/content' && m === 'POST') return await editRoute(req, env, h, url, 'content', contentSave);
      if (p === '/content' && m === 'DELETE') return await editRoute(req, env, h, url, 'content-del', contentDel);
      if (p === '/posts' && m === 'GET') return await postsList(env, h);
      if (p === '/posts/img' && m === 'GET') return await postImg(env, url);
      if (p === '/posts' && m === 'POST') return await editRoute(req, env, h, url, 'post', postSave);
      if (p === '/posts' && m === 'DELETE') return await editRoute(req, env, h, url, 'post-del', postDel);
      if (p === '/nazca' && m === 'POST') return await nazcaPut(req, env, h);
      if (p === '/nazca/list' && m === 'GET') return await nazcaList(req, env, h);
      if (p === '/nazca/get' && m === 'GET') return await nazcaGet(req, env, h, url);
      if (p === '/nazca/delete' && m === 'POST') return await nazcaDelete(req, env, h, url);
      if (p === '/review' && m === 'POST') return await reviewPut(req, env, h);
      if (p === '/review/status' && m === 'GET') return await reviewStatus(env, h, url);
      if (p === '/review/delete' && m === 'POST') return await reviewDelete(req, env, h, url);
      if (p === '/review/mark' && m === 'POST') return await reviewMark(req, env, h, url);
      if (p === '/review/list' && m === 'GET') return await reviewList(req, env, h);
      if (p === '/review/get' && m === 'GET') return await reviewGet(req, env, h, url);
      if (p === '/auth/start' && m === 'POST') return await authStart(req, env, h, ctx);
      if (p === '/auth/verify' && m === 'POST') return await authVerify(req, env, h);
      if (p === '/auth/logout' && m === 'POST') return await logout(req, env, h);
      if (p === '/auth/logout-all' && m === 'POST') return await logoutAll(req, env, h);
      if (p === '/me' && m === 'GET') return await me(req, env, h);
      if (p === '/me/key' && m === 'PUT') return await setKey(req, env, h);
      if (p === '/sync' && m === 'GET') return await syncGet(req, env, h);
      if (p === '/sync' && m === 'PUT') return await syncPut(req, env, h);
      if (p === '/sync' && m === 'DELETE') return await syncDelete(req, env, h);
      if (p === '/sync/confirm' && m === 'POST') return await syncConfirm(req, env, h, ctx);
      if (p === '/sync/check' && m === 'POST') return await syncCheck(req, env, h);
      if (p === '/account' && m === 'DELETE') return await delAccount(req, env, h);
      if (p === '/link/start' && m === 'POST') return await linkStart(req, env, h, ctx);
      if (p === '/link/poll' && m === 'POST') return await linkN(req, env, h);
      if (p === '/link/pending' && m === 'GET') return await linkPending(req, env, h);
      if (p === '/link/step' && m === 'POST') return await linkA(req, env, h);
      if (p === '/admin/invite' && m === 'POST') return await adminInvite(req, env, h);
    } catch (e) { return e && e.message === 'GATE' ? json({ ok: false, error: 'config' }, 503, h) : json({ ok: false, error: 'server' }, 500, h); }
    return json({ ok: false, error: 'not_found' }, 404, h);
  }
};

