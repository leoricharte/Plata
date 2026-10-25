// CORS en producción (sin DEV): el panel en plata-dev.pages.dev debe poder hacer la verificación previa y leer lo público; plataapp.net no puede usar el admin.
const W = await import(new URL('../worker/worker.js', import.meta.url).href); const env = { ADMIN_ORIGINS: 'https://plata-dev.pages.dev', WAITLIST: { get: async () => null, list: async () => ({ keys: [], list_complete: true }) } };
let f = 0; const ok = (c, m) => { console.log((c ? 'OK    ' : 'FALLA ') + m); if (!c) f++; };
const pre = async (path, origin, method) => (await W.default.fetch(new Request('https://x' + path, { method: 'OPTIONS', headers: { Origin: origin, 'Access-Control-Request-Method': method } }), env, {})).headers.get('Access-Control-Allow-Origin');
ok(await pre('/content', 'https://plata-dev.pages.dev', 'POST') === 'https://plata-dev.pages.dev', 'panel: verificación previa de POST /content');
ok(await pre('/review/list', 'https://plata-dev.pages.dev', 'GET') === 'https://plata-dev.pages.dev', 'panel: verificación previa de GET /review/list');
ok(await pre('/content', 'https://plataapp.net', 'POST') === null, 'sitio: NO puede preparar POST /content');
ok(await pre('/review/list', 'https://plataapp.net', 'GET') === null, 'sitio: NO puede preparar GET /review/list');
ok(await pre('/sync', 'https://web.plataapp.net', 'PUT') === 'https://web.plataapp.net', 'app nueva: verificación previa de PUT /sync');
ok(await pre('/sync', 'https://evil.example', 'PUT') === null, 'origen ajeno: nada');
const g = await W.default.fetch(new Request('https://x/content', { headers: { Origin: 'https://plata-dev.pages.dev' } }), env, {});
ok(g.headers.get('Access-Control-Allow-Origin') === 'https://plata-dev.pages.dev', 'panel: puede leer GET /content');
process.exit(f ? 1 : 0);
