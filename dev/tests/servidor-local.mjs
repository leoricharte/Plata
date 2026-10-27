// Servidor local que imita Cloudflare: Workers KV (no atómico, con demora y TTL) y Durable Objects (una petición a la vez por objeto).
// Corre el worker.js real del repo. Los correos de Resend se capturan en memoria (GET /__mails) para las pruebas.
import http from 'node:http';
const W = (await import(process.argv[2] || new URL('../worker/worker.js', import.meta.url).href));
const worker = W.default, Gate = W.Gate;
const lag = () => new Promise((r) => setTimeout(r, 2 + Math.random() * 8));
const kv = new Map();
const KV = {
  async get(k) { await lag(); const v = kv.get(k); if (!v) return null; if (v.exp && v.exp < Date.now()) { kv.delete(k); return null; } return v.v; },
  async put(k, v, o) { await lag(); kv.set(k, { v: String(v), exp: o && o.expirationTtl ? Date.now() + o.expirationTtl * 1000 : 0, md: o && o.metadata }); },
  async delete(k) { await lag(); kv.delete(k); },
  async list({ prefix }) { await lag(); return { keys: [...kv.keys()].filter((k) => k.startsWith(prefix || '')).sort().map((name) => ({ name, metadata: kv.get(name).md })), list_complete: true }; }
};
const objs = new Map();
const GATE = {
  idFromName: (n) => n,
  get(id) {
    if (!objs.has(id)) { const m = new Map(); const storage = { async get(k) { await lag(); return m.get(k); }, async put(k, v) { await lag(); m.set(k, structuredClone(v)); }, async delete(k) { await lag(); m.delete(k); }, async setAlarm() {}, async deleteAll() { m.clear(); } }; objs.set(id, { g: new Gate({ storage }), q: Promise.resolve() }); }
    const o = objs.get(id);
    return { fetch: (url, init) => { const run = o.q.then(() => o.g.fetch(new Request(url, init))); o.q = run.catch(() => {}); return run; } }; // como un Durable Object: de una en una
  }
};
const mails = [];
const realFetch = globalThis.fetch;
globalThis.fetch = async (url, init) => {
  if (String(url).startsWith('https://api.resend.com')) { const b = JSON.parse(init.body); mails.push({ to: b.to[0], subject: b.subject, text: b.text, t: Date.now() }); return new Response('{"id":"x"}', { status: 200 }); }
  return realFetch(url, init);
};
export const env = { WAITLIST: KV, GATE, RL_SALT: 'sal-de-prueba', ADMIN_TOKEN: 'a'.repeat(40), MOD_TOKEN: 'm'.repeat(40), RESEND_API_KEY: 're_test', CLOUD_TESTERS: 'ana@prueba.co,beto@prueba.co,carla@prueba.co', DEV: '1', ADMIN_ORIGINS: 'https://plata-dev.pages.dev' };
if (process.env.NOGATE) delete env.GATE;
if (process.env.NOSALT) delete env.RL_SALT;
const port = Number(process.env.PORT || 8787);
http.createServer(async (req, res) => {
  if (req.url.startsWith('/__mails')) { const to = new URL(req.url, 'http://x').searchParams.get('to'); res.setHeader('Content-Type', 'application/json'); res.setHeader('Access-Control-Allow-Origin', '*'); return res.end(JSON.stringify(mails.filter((m) => !to || m.to === to))); }
  const chunks = []; for await (const c of req) chunks.push(c);
  const headers = new Headers(); for (const [k, v] of Object.entries(req.headers)) if (typeof v === 'string') headers.set(k, v);
  headers.set('CF-Connecting-IP', req.headers['x-test-ip'] || req.socket.remoteAddress);
  const r = new Request('http://localhost:' + port + req.url, { method: req.method, headers, body: ['GET', 'HEAD'].includes(req.method) ? undefined : Buffer.concat(chunks) });
  const out = await worker.fetch(r, env, { waitUntil: (p) => p.catch(() => {}) });
  res.statusCode = out.status; out.headers.forEach((v, k) => res.setHeader(k, v)); res.end(Buffer.from(await out.arrayBuffer()));
}).listen(port, () => console.log('worker local en', port));
