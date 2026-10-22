/* Plata Cloud · lista de espera (primer pedazo del servicio).
 * POST /waitlist  { email, src, lang, plat, website }  → { ok: true }
 * GET  /waitlist/export  (Authorization: Bearer ADMIN_TOKEN) → lista en JSON
 * GET  /health
 * Guarda solo: correo, fecha, origen (app o landing), idioma y plataforma. Nada de datos financieros.
 */
const ORIGINS = ['https://plataapp.net', 'https://www.plataapp.net'];
const SRC = ['app', 'landing'];
const LANGS = ['es', 'en', 'ja', 'it', 'fr', 'sh', 'hr'];
const EMAIL = /^[^\s@<>()[\]\\,;:"]+@[^\s@<>()[\]\\,;:"]+\.[^\s@<>()[\]\\,;:"]{2,}$/;
const LIMIT_PER_HOUR = 5;

const cors = (req, env) => {
  const o = req.headers.get('Origin') || '';
  const ok = ORIGINS.includes(o) || (env.DEV === '1' && /^http:\/\/localhost(:\d+)?$/.test(o));
  return ok ? { 'Access-Control-Allow-Origin': o, 'Access-Control-Allow-Methods': 'POST, GET, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type', 'Access-Control-Max-Age': '86400', Vary: 'Origin' } : { Vary: 'Origin' };
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

async function join(req, env, h) {
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
  if (!(await env.WAITLIST.get(key))) {
    const rec = { t: Date.now(), src: SRC.includes(b.src) ? b.src : 'landing', lang: LANGS.includes(b.lang) ? b.lang : 'es', plat: String(b.plat || '').slice(0, 40) };
    await env.WAITLIST.put(key, JSON.stringify(rec));
  }
  return json({ ok: true }, 200, h); // misma respuesta si ya estaba: no revela quién está en la lista
}

async function exportList(req, env, h) {
  const auth = req.headers.get('Authorization') || '';
  if (!env.ADMIN_TOKEN || auth !== 'Bearer ' + env.ADMIN_TOKEN) return json({ ok: false, error: 'auth' }, 401, h);
  const out = []; let cursor;
  do {
    const r = await env.WAITLIST.list({ prefix: 'w:', cursor });
    for (const k of r.keys) { const v = await env.WAITLIST.get(k.name); out.push(Object.assign({ email: k.name.slice(2) }, JSON.parse(v || '{}'))); }
    cursor = r.list_complete ? undefined : r.cursor;
  } while (cursor);
  out.sort((a, b) => a.t - b.t);
  return json({ ok: true, count: out.length, list: out }, 200, h);
}

export default {
  async fetch(req, env) {
    const h = cors(req, env), url = new URL(req.url);
    if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: h });
    try {
      if (url.pathname === '/health') return json({ ok: true }, 200, h);
      if (url.pathname === '/waitlist' && req.method === 'POST') return await join(req, env, h);
      if (url.pathname === '/waitlist/export' && req.method === 'GET') return await exportList(req, env, h);
    } catch (e) { return json({ ok: false, error: 'server' }, 500, h); }
    return json({ ok: false, error: 'not_found' }, 404, h);
  }
};
