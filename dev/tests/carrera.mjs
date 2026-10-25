// Carrera contra el código de 6 dígitos, en proceso (máxima concurrencia, como un atacante con muchas conexiones).
// Con el worker anterior (contadores en KV) el intento #251 entraba; con el Gate (Durable Object) no.
const lag = () => new Promise((r) => setTimeout(r, 2 + Math.random() * 8));
async function run(path) {
  const W = await import(path), kv = new Map(), objs = new Map(), mails = [];
  const KV = { async get(k) { await lag(); return kv.has(k) ? kv.get(k) : null; }, async put(k, v) { await lag(); kv.set(k, String(v)); }, async delete(k) { await lag(); kv.delete(k); }, async list() { return { keys: [], list_complete: true }; } };
  const GATE = { idFromName: (n) => n, get(id) { if (!objs.has(id)) { const m = new Map(); objs.set(id, { g: new W.Gate({ storage: { async get(k) { await lag(); return m.get(k); }, async put(k, v) { await lag(); m.set(k, structuredClone(v)); }, async delete(k) { await lag(); m.delete(k); }, async setAlarm() {}, async deleteAll() { m.clear(); } } }), q: Promise.resolve() }); } const o = objs.get(id); return { fetch: (u, i) => { const r = o.q.then(() => o.g.fetch(new Request(u, i))); o.q = r.catch(() => {}); return r; } }; } };
  globalThis.fetch = async (u, i) => { mails.push(JSON.parse(i.body)); return new Response('{}'); };
  const env = { WAITLIST: KV, GATE: W.Gate ? GATE : undefined, RL_SALT: 's', RESEND_API_KEY: 'x', CLOUD_TESTERS: 'ana@prueba.co' };
  const post = (p, b, ip) => W.default.fetch(new Request('http://x' + p, { method: 'POST', body: JSON.stringify(b), headers: { 'CF-Connecting-IP': ip } }), env, {}).then((r) => r.json());
  await post('/auth/start', { email: 'ana@prueba.co' }, '1.1.1.1');
  const code = mails.pop().text.match(/(\d{3}) (\d{3})/).slice(1).join('');
  const gs = Array.from({ length: 300 }, (_, i) => i === 250 ? code : String((Number(code) + 1 + i) % 1e6).padStart(6, '0'));
  const rs = await Promise.all(gs.map((g, i) => post('/auth/verify', { email: 'ana@prueba.co', code: g }, '2.2.' + (i % 250) + '.1')));
  return rs.some((r) => r.token);
}
const entro = await run(process.argv[2] || new URL('../worker/worker.js', import.meta.url).href);
console.log((entro ? 'FALLA ' : 'OK    ') + '300 intentos simultáneos contra un código de 6 dígitos (el correcto en el #251): ' + (entro ? 'entró' : 'no entró'));
process.exit(entro ? 1 : 0);
