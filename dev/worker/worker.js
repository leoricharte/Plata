/* Plata Cloud · lista de espera (primer pedazo del servicio).
 * POST /waitlist  { email, src, lang, plat, website }  → { ok: true }
 * GET  /waitlist/export  (Authorization: Bearer ADMIN_TOKEN) → lista en JSON
 * GET  /health
 * Cuentas y sincronización cifrada: /auth/start, /auth/verify, /auth/logout, /me, /me/key, /sync, /account, /admin/invite.
 * Con el secreto RESEND_API_KEY envía un correo de confirmación a quien se apunta por primera vez.
 * Guarda solo: correo, fecha, origen (app o landing), idioma y plataforma. Nada de datos financieros.
 */
const ORIGINS = ['https://plataapp.net', 'https://www.plataapp.net', 'http://tauri.localhost', 'https://tauri.localhost', 'tauri://localhost']; // las últimas tres: la app de escritorio (Tauri)
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

const cors = (req, env) => {
  const o = req.headers.get('Origin') || '';
  const ok = ORIGINS.includes(o) || String(env.TEST_ORIGINS || '').split(',').map((x) => x.trim()).filter(Boolean).includes(o) || (env.DEV === '1' && /^http:\/\/localhost(:\d+)?$/.test(o));
  return ok ? { 'Access-Control-Allow-Origin': o, 'Access-Control-Allow-Methods': 'POST, GET, PUT, DELETE, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type, Authorization', 'Access-Control-Max-Age': '86400', Vary: 'Origin' } : { Vary: 'Origin' };
};
const json = (body, status, h) => new Response(JSON.stringify(body), { status: status || 200, headers: Object.assign({ 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' }, h || {}) });

async function sha(s) {
  const b = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s));
  return Array.from(new Uint8Array(b)).map((x) => x.toString(16).padStart(2, '0')).join('').slice(0, 24);
}

async function rateLimited(req, env) {
  const ip = req.headers.get('CF-Connecting-IP') || 'x', hour = Math.floor(Date.now() / 3600000);
  const key = 'rl:' + (await sha((env.RL_SALT || 'plata') + ip)) + ':' + hour;
  const n = Number(await env.WAITLIST.get(key)) || 0;
  if (n >= LIMIT_PER_HOUR) return true;
  await env.WAITLIST.put(key, String(n + 1), { expirationTtl: 7200 });
  return false;
}

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
const MAX_REVIEW = 4000000, REVIEW_WAIT = [10, 30, 60, 120, 1440].map((m) => m * 60000);
async function reviewPut(req, env, h) {
  const origin = req.headers.get('Origin') || '';
  if (!h['Access-Control-Allow-Origin'] && origin) return json({ ok: false, error: 'origin' }, 403, h);
  const raw = await req.text();
  if (raw.length > MAX_REVIEW) return json({ ok: false, error: 'size' }, 413, h);
  let b; try { b = JSON.parse(raw); } catch (e) { return json({ ok: false, error: 'json' }, 400, h); }
  if (!b || typeof b !== 'object' || !b.data || typeof b.data !== 'object') return json({ ok: false, error: 'json' }, 400, h);
  if (await rateLimited(req, env)) return json({ ok: false, error: 'rate' }, 429, h);
  // espera creciente entre envíos desde la misma conexión: 10 min, 30 min, 1 h, 2 h, 1 día
  const ipk = 'rvl:' + (await sha((env.RL_SALT || 'plata') + (req.headers.get('CF-Connecting-IP') || 'x'))), now = Date.now();
  let lim = await kvGet(env, ipk); if (!lim || now - lim.t > 7 * 86400000) lim = { n: 0, t: 0 };
  const until = lim.t + REVIEW_WAIT[Math.min(lim.n, REVIEW_WAIT.length) - 1] ;
  if (lim.n > 0 && now < until) return json({ ok: false, error: 'wait', until: until }, 429, h);
  const id = Date.now().toString(36) + '-' + rndB64(6);
  await env.WAITLIST.put('rv:' + id, JSON.stringify({ t: Date.now(), build: Number(b.build) || 0, plat: String(b.plat || '').slice(0, 40), data: b.data }));
  await kvPut(env, ipk, { n: lim.n + 1, t: now }, 8 * 86400);
  return json({ ok: true, id: id, until: now + REVIEW_WAIT[Math.min(lim.n + 1, REVIEW_WAIT.length) - 1] }, 200, h);
}
/* Acceso de administrador: comparación en tiempo constante (se comparan hashes) y bloqueo por IP tras 5 fallos en 15 minutos (429). El contador usa KV, que no es atómico: es un freno razonable, no una garantía exacta. */
const AUTH_MAX = 5, AUTH_WIN = 900;
async function adminGate(req, env, h) { // devuelve null si el token es correcto; si no, la respuesta 401 o 429
  const ip = req.headers.get('CF-Connecting-IP') || 'x', key = 'af:' + (await sha((env.RL_SALT || 'plata') + ':adm:' + ip));
  const n = Number(await env.WAITLIST.get(key)) || 0;
  if (n >= AUTH_MAX) return json({ ok: false, error: 'rate' }, 429, Object.assign({}, h, { 'Retry-After': String(AUTH_WIN) }));
  const ok = !!env.ADMIN_TOKEN && same(await sha(req.headers.get('Authorization') || ''), await sha('Bearer ' + env.ADMIN_TOKEN));
  if (ok) return null;
  await env.WAITLIST.put(key, String(n + 1), { expirationTtl: AUTH_WIN });
  return json({ ok: false, error: 'auth' }, 401, h);
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
  v.reviewed = Date.now(); await kvPut(env, k, v);
  return json({ ok: true }, 200, h);
}
async function reviewDelete(req, env, h, url) { // borra los datos de la copia y deja solo una constancia (fecha) para que la app lo muestre
  { const g = await adminGate(req, env, h); if (g) return g; }
  const k = 'rv:' + (url.searchParams.get('id') || ''), v = await kvGet(env, k);
  if (!v) return json({ ok: false, error: 'none' }, 404, h);
  await kvPut(env, k, { t: v.t, reviewed: v.reviewed || Date.now(), deleted: Date.now() });
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
  return new Response(u, { status: 200, headers: { 'Content-Type': 'image/jpeg', 'Cache-Control': 'public, max-age=86400' } });
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
  return json({ ok: true, id: id }, 200, h);
}
async function postDel(req, env, h, url) {
  { const g = await adminGate(req, env, h); if (g) return g; }
  const id = url.searchParams.get('id') || ''; if (!POST_ID.test(id)) return json({ ok: false, error: 'none' }, 404, h);
  await env.WAITLIST.delete('po:' + id); await env.WAITLIST.delete('pi:' + id); delete MEMO.posts;
  return json({ ok: true }, 200, h);
}

/* ---------- Textos editables del sitio (editor oculto: cada texto se identifica por un hash de su versión original en español) ---------- */
const CT_KEY = /^[0-9a-f]{6,16}$/;
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
  await kvPut(env, 'ct:' + b.k, { es: b.es, en: b.en, orig: String(b.orig || '').slice(0, 160), t: Date.now() }); delete MEMO.content;
  return json({ ok: true }, 200, h);
}
async function contentDel(req, env, h, url) {
  { const g = await adminGate(req, env, h); if (g) return g; }
  const k = url.searchParams.get('k') || ''; if (!CT_KEY.test(k)) return json({ ok: false, error: 'none' }, 404, h);
  await env.WAITLIST.delete('ct:' + k); delete MEMO.content; return json({ ok: true }, 200, h);
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
const emailKey = async (env, email) => (await shaFull((env.RL_SALT || 'plata') + ':u:' + email)).slice(0, 40);
const kvGet = async (env, k) => { const v = await env.WAITLIST.get(k); try { return v ? JSON.parse(v) : null; } catch (e) { return null; } };
const kvPut = (env, k, o, ttl) => env.WAITLIST.put(k, JSON.stringify(o), ttl ? { expirationTtl: ttl } : undefined);

async function hit(env, key, max, ttl) { // contador simple por ventana
  const n = Number(await env.WAITLIST.get(key)) || 0;
  if (n >= max) return true;
  await env.WAITLIST.put(key, String(n + 1), { expirationTtl: ttl });
  return false;
}
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
    const os = String(x.plat || '').split(' · ')[0], ico = os === 'iPhone' ? 'apple' : os === 'Android' ? 'android' : os === 'Mac' ? 'macbook' : os === 'Windows' ? 'windows' : os === 'Linux' ? 'computer' : 'smartphone';
    const item = (ic, tx) => '<tr><td align="center" style="text-align:center;padding:0 0 8px"><table role="presentation" align="center" cellpadding="0" cellspacing="0" border="0"><tr><td valign="middle" style="padding:0 10px 0 0"><img src="' + MAIL_IC(ic) + '" width="20" height="20" alt="" style="display:block;margin:0 auto;border:0;width:20px;height:20px"></td><td valign="middle" style="font:600 15px/1.3 ' + F + ';color:#1C1C1E">' + String(tx).replace(/&/g, '&amp;').replace(/</g, '&lt;') + '</td></tr></table></td></tr>';
    const city = x.tz ? x.tz.split('/').pop().replace(/_/g, ' ') : '';
    detRows = '<tr><td align="center" style="text-align:center;padding:0 32px 20px"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#F2F2F4;border-radius:18px"><tr><td align="center" style="text-align:center;padding:16px 18px 8px"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">'
      + item(ico, os || (es ? 'Dispositivo' : 'Device')) + (city ? item('global', city) : '') + (x.when ? item('time', x.when) : '') + '</table></td></tr></table></td></tr>';
    Object.assign(t, es
    ? { subject: 'Alguien quiere entrar a tu cuenta de Plata Cloud', title: 'Alguien quiere entrar a tu cuenta', lead: 'Se pidió iniciar sesión en tu cuenta con estos datos. Para aprobarlo, abre Plata en un dispositivo donde ya tengas sesión: en Ajustes verás la solicitud. Confirma que el código de abajo sea el mismo que ves en el dispositivo nuevo. Vence en 10 minutos.', danger: 'APRUÉBALO SOLO SI FUISTE TÚ.', warn: 'Si no fuiste tú, recházalo en Plata o ignora este correo: sin tu aprobación nadie puede entrar.' }
    : { subject: 'Someone wants to sign in to your Plata Cloud account', title: 'Someone wants to sign in to your account', lead: 'A sign-in was requested on your account with these details. To approve it, open Plata on a device where you are already signed in: you will see the request in Settings. Check that the code below matches the one on the new device. It expires in 10 minutes.', danger: 'ONLY APPROVE IT IF IT WAS YOU.', warn: "If it wasn't you, decline it in Plata or ignore this email: nobody can sign in without your approval." }); }
  const spaced = kind === 'link' ? code : code.slice(0, 3) + ' ' + code.slice(3);
  const dangerRow = t.danger ? '<tr><td align="center" style="text-align:center;padding:0 32px 20px"><table role="presentation" align="center" cellpadding="0" cellspacing="0" border="0"><tr><td valign="top" style="padding:2px 10px 0 0"><img src="' + MAIL_WARN + '" width="22" height="22" alt="!" style="display:block;margin:0 auto;border:0;width:22px;height:22px"></td><td style="font:800 16px/1.45 ' + F + ';color:#D70015">' + t.danger + '</td></tr></table></td></tr>' : '';
  const html = '<!doctype html><html lang="' + (es ? 'es' : 'en') + '"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="only light"><title>' + t.subject + '</title></head><body style="margin:0;padding:0;background:#FFFFFF">'
    + '<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent">' + code + '</div>'
    + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#FFFFFF"><tr><td align="center"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:520px">'
    + '<tr><td><img src="' + MAIL_CLOUDS + '" width="520" alt="" style="display:block;margin:0 auto;border:0;width:100%;max-width:520px;height:auto"></td></tr>'
    + '<tr><td align="left" style="text-align:left;padding:6px 32px 0"><img src="' + MAIL_LOGO + '" width="140" height="49" alt="Plata Cloud" style="display:block;border:0;height:auto;width:140px"></td></tr>'
    + '<tr><td align="center" style="text-align:center;padding:22px 32px 8px;font:800 28px/1.15 ' + F + ';letter-spacing:-0.02em;color:#1C1C1E">' + t.title + '</td></tr>'
    + '<tr><td align="center" style="text-align:center;padding:0 32px 22px;font:400 16px/1.55 ' + F + ';color:#5B5B60">' + t.lead + '</td></tr>'
    + detRows + dangerRow
    + '<tr><td align="center" style="text-align:center;padding:0 32px 24px"><div style="display:inline-block;margin:0 auto;background:#E9F6EF;border-radius:18px;padding:18px 28px;font:800 40px/1 ' + F + ';letter-spacing:0.12em;color:#13774C">' + spaced + '</div></td></tr>'
    + '<tr><td align="center" style="text-align:center;padding:0 32px 18px;font:400 13px/1.5 ' + F + ';color:#8A8A8F">' + t.warn + '</td></tr>'
    + socialRow(F)
    + '</table></td></tr></table></body></html>';
  return { subject: t.subject, html, text: t.title + '\n\n' + spaced + '\n\n' + t.lead + (kind === 'link' ? '\n' + det : '') + '\n\n' + (t.danger ? t.danger + '\n\n' : '') + t.warn + '\n' };
}
async function sendCodeMail(env, email, lang, code, kind, x) {
  if (!env.RESEND_API_KEY) return;
  const m = codeMail(lang, code, kind, x);
  try {
    const r = await fetch('https://api.resend.com/emails', { method: 'POST', headers: { Authorization: 'Bearer ' + env.RESEND_API_KEY, 'Content-Type': 'application/json' }, body: JSON.stringify({ from: MAIL_FROM, to: [email], subject: m.subject, html: m.html, text: m.text }) });
    if (!r.ok) console.log('resend code', r.status);
  } catch (e) { console.log('resend code fail'); }
}

async function authStart(req, env, h, ctx) {
  const o = needOrigin(req, h); if (o) return o;
  const { b, err } = await readBody(req); if (err) return json({ ok: false, error: err === 413 ? 'size' : 'json' }, err, h);
  const email = cleanEmail(b.email); if (!email) return json({ ok: false, error: 'email' }, 400, h);
  const ip = req.headers.get('CF-Connecting-IP') || 'x', hour = Math.floor(Date.now() / 3600000), ek = await emailKey(env, email);
  if (await hit(env, 'rl:ai:' + (await sha((env.RL_SALT || 'plata') + ip)) + ':' + hour, 20, 7200) || await hit(env, 'rl:ae:' + ek.slice(0, 24) + ':' + hour, 5, 7200)) return json({ ok: false, error: 'rate' }, 429, h);
  let allowed = env.CLOUD_OPEN === '1' || String(env.CLOUD_TESTERS || '').toLowerCase().split(',').map((x) => x.trim()).filter(Boolean).includes(email);
  let listed = false;
  if (!allowed) { const u = await kvGet(env, 'u:' + ek); const w = await kvGet(env, 'w:' + email); allowed = !!u || !!(w && w.inv); listed = !allowed && !!w; }
  if (allowed) {
    const code = rnd6();
    await kvPut(env, 'c:' + ek, { h: await shaFull((env.RL_SALT || 'plata') + ':c:' + ek + ':' + code), exp: Date.now() + CODE_TTL, tries: 0 }, 900);
    const p = sendCodeMail(env, email, b.lang === 'en' ? 'en' : 'es', code);
    if (ctx && ctx.waitUntil) ctx.waitUntil(p); else await p;
  }
  // La app necesita saber si debe pedir el código o llevar a la lista de espera. Solo se revela "tiene acceso / está en la lista / no", con límite de intentos por correo y por conexión.
  return json({ ok: true, access: allowed, listed: listed }, 200, h);
}

async function authVerify(req, env, h) {
  const o = needOrigin(req, h); if (o) return o;
  const { b, err } = await readBody(req); if (err) return json({ ok: false, error: err === 413 ? 'size' : 'json' }, err, h);
  const email = cleanEmail(b.email), code = String(b.code || '').replace(/\s/g, '');
  if (!email || !/^\d{6}$/.test(code)) return json({ ok: false, error: 'code' }, 400, h);
  const ek = await emailKey(env, email), c = await kvGet(env, 'c:' + ek);
  if (!c || c.exp < Date.now() || c.tries >= MAX_TRIES) return json({ ok: false, error: 'code' }, 400, h);
  const ok = same(c.h, await shaFull((env.RL_SALT || 'plata') + ':c:' + ek + ':' + code));
  if (!ok) { c.tries += 1; await kvPut(env, 'c:' + ek, c, 900); return json({ ok: false, error: 'code' }, 400, h); }
  await env.WAITLIST.delete('c:' + ek);
  let u = await kvGet(env, 'u:' + ek), isNew = false;
  if (!u) { isNew = true; u = { email, t: Date.now(), kc: '' }; await kvPut(env, 'u:' + ek, u); }
  const token = rndB64(32);
  await kvPut(env, 's:' + (await shaFull(token)), { u: ek, dev: String(b.dev || '').slice(0, 40), t: Date.now() }, SESSION_DAYS * 86400);
  const d = await kvGet(env, 'd:' + ek);
  return json({ ok: true, token, new: isNew, hasKey: !!u.kc, kc: u.kc || '', hasData: !!d, rev: d ? d.rev : 0 }, 200, h);
}

async function session(req, env) {
  const m = /^Bearer ([A-Za-z0-9_-]{20,80})$/.exec(req.headers.get('Authorization') || ''); if (!m) return null;
  const sk = 's:' + (await shaFull(m[1])), s = await kvGet(env, sk); if (!s) return null;
  const u = await kvGet(env, 'u:' + s.u); if (!u) return null;
  return { sk, ek: s.u, u };
}
const unauth = (h) => json({ ok: false, error: 'auth' }, 401, h);

async function me(req, env, h) {
  const a = await session(req, env); if (!a) return unauth(h);
  const d = await kvGet(env, 'd:' + a.ek);
  return json({ ok: true, email: a.u.email, hasKey: !!a.u.kc, kc: a.u.kc || '', hasData: !!d, rev: d ? d.rev : 0, t: d ? d.t : 0 }, 200, h);
}
async function setKey(req, env, h) {
  const o = needOrigin(req, h); if (o) return o;
  const a = await session(req, env); if (!a) return unauth(h);
  const { b, err } = await readBody(req, 512); if (err) return json({ ok: false, error: 'json' }, err, h);
  if (typeof b.kc !== 'string' || !B64.test(b.kc) || b.kc.length < 16 || b.kc.length > 128) return json({ ok: false, error: 'kc' }, 400, h);
  if (a.u.kc) return json({ ok: false, error: 'exists' }, 409, h); // la comprobación de clave se fija una vez, al crear la cuenta
  a.u.kc = b.kc; await kvPut(env, 'u:' + a.ek, a.u);
  return json({ ok: true }, 200, h);
}
async function syncGet(req, env, h) {
  const a = await session(req, env); if (!a) return unauth(h);
  const d = await kvGet(env, 'd:' + a.ek);
  return json(d ? { ok: true, rev: d.rev, blob: d.blob, t: d.t, v: d.v, dev: d.dev } : { ok: true, rev: 0 }, 200, h);
}
async function syncDelete(req, env, h) {
  const o = needOrigin(req, h); if (o) return o;
  const a = await session(req, env); if (!a) return unauth(h);
  if (await hit(env, 'rl:sw:' + a.ek.slice(0, 24) + ':' + Math.floor(Date.now() / 3600000), 10, 7200)) return json({ ok: false, error: 'rate' }, 429, h);
  for (const k of ['d:', 'p:']) await env.WAITLIST.delete(k + a.ek); // solo la copia cifrada y su respaldo: la cuenta y la sesión siguen
  return json({ ok: true }, 200, h);
}
async function syncConfirm(req, env, h, ctx) {
  const o = needOrigin(req, h); if (o) return o;
  const a = await session(req, env); if (!a) return unauth(h);
  const { b } = await readBody(req);
  if (await hit(env, 'rl:sc:' + a.ek.slice(0, 24) + ':' + Math.floor(Date.now() / 3600000), 5, 7200)) return json({ ok: false, error: 'rate' }, 429, h);
  const code = rnd6();
  await kvPut(env, 'c2:' + a.ek, { h: await shaFull((env.RL_SALT || 'plata') + ':c2:' + a.ek + ':' + code), exp: Date.now() + CODE_TTL, tries: 0 }, 900);
  const p = sendCodeMail(env, a.u.email, (b && b.lang) === 'en' ? 'en' : 'es', code, b && b.kind === 'delete' ? 'delete' : 'replace');
  if (ctx && ctx.waitUntil) ctx.waitUntil(p); else await p;
  return json({ ok: true }, 200, h);
}
async function syncPut(req, env, h) {
  const o = needOrigin(req, h); if (o) return o;
  const a = await session(req, env); if (!a) return unauth(h);
  if (await hit(env, 'rl:sp:' + a.ek.slice(0, 24) + ':' + Math.floor(Date.now() / 60000), 30, 180)) return json({ ok: false, error: 'rate' }, 429, h);
  const { b, err } = await readBody(req, MAX_BLOB + 1024); if (err) return json({ ok: false, error: err === 413 ? 'size' : 'json' }, err, h);
  if (b.demo === true) return json({ ok: false, error: 'demo' }, 403, h); // un perfil de demostración nunca se sube
  if (!a.u.kc) return json({ ok: false, error: 'nokey' }, 409, h);
  if (typeof b.blob !== 'string' || !b.blob.length || b.blob.length > MAX_BLOB || !B64.test(b.blob)) return json({ ok: false, error: 'blob' }, 400, h);
  const cur = await kvGet(env, 'd:' + a.ek), curRev = cur ? cur.rev : 0;
  if (b.replace === true && curRev > 0) { // reemplazo total (archivo de perfil): exige el código enviado al correo
    const c = await kvGet(env, 'c2:' + a.ek), code = String(b.code || '').replace(/\s/g, '');
    if (!c || c.exp < Date.now() || c.tries >= MAX_TRIES || !/^\d{6}$/.test(code)) return json({ ok: false, error: 'code' }, 400, h);
    if (!same(c.h, await shaFull((env.RL_SALT || 'plata') + ':c2:' + a.ek + ':' + code))) { c.tries += 1; await kvPut(env, 'c2:' + a.ek, c, 900); return json({ ok: false, error: 'code' }, 400, h); }
    await env.WAITLIST.delete('c2:' + a.ek);
  } else if (Number(b.base) !== curRev) return json({ ok: false, error: 'conflict', rev: curRev, t: cur ? cur.t : 0 }, 409, h);
  if (cur) await kvPut(env, 'p:' + a.ek, cur); // copia anterior: una red de seguridad contra errores de un dispositivo
  const nd = { rev: curRev + 1, blob: b.blob, t: Date.now(), v: Number(b.v) || 1, dev: String(b.dev || '').slice(0, 40) };
  await kvPut(env, 'd:' + a.ek, nd);
  return json({ ok: true, rev: nd.rev, t: nd.t }, 200, h);
}
async function logout(req, env, h) {
  const a = await session(req, env); if (!a) return unauth(h);
  await env.WAITLIST.delete(a.sk);
  return json({ ok: true }, 200, h);
}
async function syncCheck(req, env, h) {
  const o = needOrigin(req, h); if (o) return o;
  const a = await session(req, env); if (!a) return unauth(h);
  const { b } = await readBody(req);
  const c = await kvGet(env, 'c2:' + a.ek), code = String((b && b.code) || '').replace(/\s/g, '');
  if (!c || Date.now() > c.exp || c.tries >= MAX_TRIES || !/^\d{6}$/.test(code)) return json({ ok: false, error: 'code' }, 400, h);
  if (!same(c.h, await shaFull((env.RL_SALT || 'plata') + ':c2:' + a.ek + ':' + code))) { c.tries += 1; await kvPut(env, 'c2:' + a.ek, c, 900); return json({ ok: false, error: 'code' }, 400, h); }
  return json({ ok: true }, 200, h);
}
async function delAccount(req, env, h) {
  const o = needOrigin(req, h); if (o) return o;
  const a = await session(req, env); if (!a) return unauth(h);
  const { b } = await readBody(req);
  const c = await kvGet(env, 'c2:' + a.ek), code = String((b && b.code) || '').replace(/\s/g, '');
  if (!c || Date.now() > c.exp || c.tries >= MAX_TRIES || !/^\d{6}$/.test(code)) return json({ ok: false, error: 'code' }, 400, h);
  if (!same(c.h, await shaFull((env.RL_SALT || 'plata') + ':c2:' + a.ek + ':' + code))) { c.tries += 1; await kvPut(env, 'c2:' + a.ek, c, 900); return json({ ok: false, error: 'code' }, 400, h); }
  for (const k of ['u:', 'd:', 'p:', 'c:', 'c2:', 'l:']) await env.WAITLIST.delete(k + a.ek);
  await env.WAITLIST.delete(a.sk); // las demás sesiones dejan de valer solas: sin cuenta, session() devuelve null
  return json({ ok: true }, 200, h);
}
// ---- aprobar un inicio de sesión desde un dispositivo con sesión activa -------------------------------------------
// El dispositivo nuevo manda una clave pública efímera (ECDH P-256). El dispositivo activo cifra la semilla con ella:
// el servidor solo retransmite texto cifrado y nunca ve la llave. La sesión se crea al recoger la aprobación.
const LINK_TTL = 10 * 60 * 1000, B64U = /^[A-Za-z0-9_-]+$/;
const matchCode = async (pub) => { const d = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(pub))); return String(((d[0] << 24 | d[1] << 16 | d[2] << 8 | d[3]) >>> 0) % 10000).padStart(4, '0'); };
async function linkStart(req, env, h, ctx) {
  const o = needOrigin(req, h); if (o) return o;
  const { b, err } = await readBody(req, 1024); if (err) return json({ ok: false, error: err === 413 ? 'size' : 'json' }, err, h);
  const email = cleanEmail(b.email), pub = String(b.pub || ''), rid = String(b.rid || '');
  if (!email || pub.length < 60 || pub.length > 140 || !B64U.test(pub) || rid.length < 20 || rid.length > 64 || !B64U.test(rid)) return json({ ok: false, error: 'bad' }, 400, h);
  const ip = req.headers.get('CF-Connecting-IP') || 'x', hour = Math.floor(Date.now() / 3600000), ek = await emailKey(env, email);
  if (await hit(env, 'rl:li:' + (await sha((env.RL_SALT || 'plata') + ip)) + ':' + hour, 10, 7200) || await hit(env, 'rl:le:' + ek.slice(0, 24) + ':' + hour, 4, 7200)) return json({ ok: false, error: 'rate' }, 429, h);
  const u = await kvGet(env, 'u:' + ek);
  let allowed = !!u || env.CLOUD_OPEN === '1' || String(env.CLOUD_TESTERS || '').toLowerCase().split(',').map((x) => x.trim()).filter(Boolean).includes(email), listed = false;
  if (!allowed) { const w = await kvGet(env, 'w:' + email); allowed = !!(w && w.inv); listed = !allowed && !!w; }
  if (u && u.kc) { // solo hay algo que aprobar si la cuenta ya tiene llave; la respuesta es igual haya o no cuenta
    const l = { rh: await shaFull(rid), pub, plat: String(b.plat || '').slice(0, 40), tz: String(b.tz || '').slice(0, 40), t: Date.now(), st: 'p' };
    await kvPut(env, 'l:' + ek, l, 660);
    let when = ''; try { when = new Date(l.t).toLocaleString(b.lang === 'en' ? 'en-US' : 'es', { timeZone: l.tz || 'UTC', dateStyle: 'medium', timeStyle: 'short' }); } catch (e) { /* zona no válida */ }
    const p = sendCodeMail(env, email, b.lang === 'en' ? 'en' : 'es', await matchCode(pub), 'link', { plat: l.plat, tz: l.tz, when });
    if (ctx && ctx.waitUntil) ctx.waitUntil(p); else await p;
  }
  return json({ ok: true, access: allowed, listed: listed }, 200, h);
}
async function linkPending(req, env, h) {
  const a = await session(req, env); if (!a) return unauth(h);
  const l = await kvGet(env, 'l:' + a.ek);
  if (!l || l.st !== 'p' || Date.now() - l.t > LINK_TTL) return json({ ok: true, req: null }, 200, h);
  return json({ ok: true, req: { pub: l.pub, plat: l.plat, tz: l.tz, t: l.t } }, 200, h);
}
async function linkAnswer(req, env, h) {
  const o = needOrigin(req, h); if (o) return o;
  const a = await session(req, env); if (!a) return unauth(h);
  const { b, err } = await readBody(req, 1024); if (err) return json({ ok: false, error: 'json' }, err, h);
  const l = await kvGet(env, 'l:' + a.ek);
  if (!l || l.st !== 'p' || Date.now() - l.t > LINK_TTL || b.pub !== l.pub) return json({ ok: false, error: 'gone' }, 404, h);
  if (b.ok === true) {
    const f = (v, n) => typeof v === 'string' && v.length >= 8 && v.length <= n && B64U.test(v);
    if (!f(b.apub, 140) || !f(b.iv, 24) || !f(b.ct, 80)) return json({ ok: false, error: 'bad' }, 400, h);
    l.st = 'a'; l.apub = b.apub; l.iv = b.iv; l.ct = b.ct; l.dt = Date.now();
    await kvPut(env, 'l:' + a.ek, l, 300);
  } else { l.st = 'd'; await kvPut(env, 'l:' + a.ek, l, 300); }
  return json({ ok: true }, 200, h);
}
async function linkPoll(req, env, h) {
  const o = needOrigin(req, h); if (o) return o;
  const { b, err } = await readBody(req, 512); if (err) return json({ ok: false, error: 'json' }, err, h);
  const email = cleanEmail(b.email), rid = String(b.rid || ''); if (!email || rid.length < 20 || rid.length > 64) return json({ ok: false, error: 'bad' }, 400, h);
  const ek = await emailKey(env, email);
  if (await hit(env, 'rl:lp:' + ek.slice(0, 24) + ':' + Math.floor(Date.now() / 60000), 40, 180)) return json({ ok: false, error: 'rate' }, 429, h);
  const l = await kvGet(env, 'l:' + ek);
  if (!l || Date.now() - l.t > LINK_TTL || !same(l.rh, await shaFull(rid))) return json({ ok: true, st: 'x' }, 200, h);
  if (l.st === 'p') return json({ ok: true, st: 'p' }, 200, h);
  await env.WAITLIST.delete('l:' + ek); // la aprobación o el rechazo se recogen una sola vez
  if (l.st === 'd') return json({ ok: true, st: 'd' }, 200, h);
  const u = await kvGet(env, 'u:' + ek); if (!u) return json({ ok: true, st: 'x' }, 200, h);
  const token = rndB64(32);
  await kvPut(env, 's:' + (await shaFull(token)), { u: ek, dev: l.plat, t: Date.now() }, SESSION_DAYS * 86400);
  return json({ ok: true, st: 'a', token, kc: u.kc || '', apub: l.apub, iv: l.iv, ct: l.ct }, 200, h);
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
    const h = cors(req, env), url = new URL(req.url);
    if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: h });
    try {
      if (url.pathname === '/health') return json({ ok: true }, 200, h);
      if (url.pathname === '/waitlist' && req.method === 'POST') return await join(req, env, h, ctx);
      if (url.pathname === '/waitlist/export' && req.method === 'GET') return await exportList(req, env, h);
      const p = url.pathname, m = req.method;
      if (p === '/content' && m === 'GET') return await contentList(env, h);
      if (p === '/content/ping' && m === 'GET') return (await adminGate(req, env, h)) || json({ ok: true }, 200, h);
      if (p === '/content' && m === 'POST') return await contentSave(req, env, h);
      if (p === '/content' && m === 'DELETE') return await contentDel(req, env, h, url);
      if (p === '/posts' && m === 'GET') return await postsList(env, h);
      if (p === '/posts/img' && m === 'GET') return await postImg(env, url);
      if (p === '/posts' && m === 'POST') return await postSave(req, env, h);
      if (p === '/posts' && m === 'DELETE') return await postDel(req, env, h, url);
      if (p === '/review' && m === 'POST') return await reviewPut(req, env, h);
      if (p === '/review/status' && m === 'GET') return await reviewStatus(env, h, url);
      if (p === '/review/delete' && m === 'POST') return await reviewDelete(req, env, h, url);
      if (p === '/review/mark' && m === 'POST') return await reviewMark(req, env, h, url);
      if (p === '/review/list' && m === 'GET') return await reviewList(req, env, h);
      if (p === '/review/get' && m === 'GET') return await reviewGet(req, env, h, url);
      if (p === '/auth/start' && m === 'POST') return await authStart(req, env, h, ctx);
      if (p === '/auth/verify' && m === 'POST') return await authVerify(req, env, h);
      if (p === '/auth/logout' && m === 'POST') return await logout(req, env, h);
      if (p === '/me' && m === 'GET') return await me(req, env, h);
      if (p === '/me/key' && m === 'PUT') return await setKey(req, env, h);
      if (p === '/sync' && m === 'GET') return await syncGet(req, env, h);
      if (p === '/sync' && m === 'PUT') return await syncPut(req, env, h);
      if (p === '/sync' && m === 'DELETE') return await syncDelete(req, env, h);
      if (p === '/sync/confirm' && m === 'POST') return await syncConfirm(req, env, h, ctx);
      if (p === '/sync/check' && m === 'POST') return await syncCheck(req, env, h);
      if (p === '/account' && m === 'DELETE') return await delAccount(req, env, h);
      if (p === '/link/start' && m === 'POST') return await linkStart(req, env, h, ctx);
      if (p === '/link/poll' && m === 'POST') return await linkPoll(req, env, h);
      if (p === '/link/pending' && m === 'GET') return await linkPending(req, env, h);
      if (p === '/link/answer' && m === 'POST') return await linkAnswer(req, env, h);
      if (p === '/admin/invite' && m === 'POST') return await adminInvite(req, env, h);
    } catch (e) { return json({ ok: false, error: 'server' }, 500, h); }
    return json({ ok: false, error: 'not_found' }, 404, h);
  }
};

