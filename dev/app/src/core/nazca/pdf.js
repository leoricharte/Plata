/* ---------- Nazca · lectura de PDF (núcleo, sin pantalla) ----------
 * Saca de un PDF el texto de cada página con su posición (x, y). Con eso, cada lector de banco (bancos/) sabe qué es cargo y qué es abono:
 * en muchos estados de cuenta la diferencia no está en el texto sino en la columna donde cae el monto.
 * Todo ocurre en el dispositivo: el PDF no se sube a ningún servidor. La librería (pdf.js, Mozilla, Apache 2.0) vive en nazca/ y solo se
 * descarga y se carga cuando alguien importa un PDF; Nazca no la incluye, la recibe (así este archivo se prueba en Node sin navegador).
 * La clave del PDF (el DNI en el BCP) solo se usa para abrirlo: no se guarda ni se muestra, y esta función no la devuelve ni la registra.
 * Errores: Error con .code = 'not_pdf' | 'too_big' | 'need_password' | 'bad_password' | 'invalid' | 'no_text' | 'unavailable'. */
const NazcaPDF = (() => {
  const MAX_BYTES = 15 * 1024 * 1024, MAX_PAGES = 60, MAX_ITEMS = 200000;
  const fail = (code) => { const e = new Error(code); e.code = code; return e; };
  const tag = (e) => { if (!e || !e.code) { const x = fail('invalid'); x.detail = String((e && e.name || 'Error') + ': ' + (e && e.message || '')).slice(0, 110); return x; } return e; };

  /* El estándar deja que "%PDF-" aparezca dentro de los primeros 1024 bytes (algunos bancos anteponen texto o bytes de más). */
  function hasHeader(src) {
    const n = Math.min(src.length - 4, 1024);
    for (let i = 0; i < n; i++) if (src[i] === 37 && src[i + 1] === 80 && src[i + 2] === 68 && src[i + 3] === 70 && src[i + 4] === 45) return true;
    return false;
  }

  /* Carga pdf.js desde `base` (una dirección que termina en "/", con pdf.mjs y pdf.worker.mjs). El navegador la pide una sola vez. */
  async function load(base) {
    try {
      const lib = await import(base + 'pdf.mjs');
      if (lib.GlobalWorkerOptions) lib.GlobalWorkerOptions.workerSrc = base + 'pdf.worker.mjs';
      return lib;
    } catch (e) { throw fail('unavailable'); }
  }

  /* bytes: ArrayBuffer o Uint8Array · lib: lo que devuelve load() · password: opcional.
   * Devuelve { pages: [{ w, h, items: [{ str, x, y, w }] }], total, truncated }. (x, y) es la esquina inferior izquierda del texto; y crece hacia arriba. */
  async function read(bytes, lib, password) {
    const src = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
    if (src.length > MAX_BYTES) throw fail('too_big');
    if (!hasHeader(src)) throw fail('not_pdf');
    const opts = { data: new Uint8Array(src), isEvalSupported: false, enableScripting: false, useSystemFonts: false, disableFontFace: true,
      disableAutoFetch: true, disableStream: true, verbosity: 0 };
    if (password) opts.password = String(password);
    const task = lib.getDocument(opts);
    let doc;
    try { doc = await task.promise; }
    catch (e) {
      try { task.destroy(); } catch (x) { /* nada */ }
      const n = e && e.name;
      if (n === 'PasswordException') throw fail(e.code === 2 ? 'bad_password' : 'need_password');
      const x = fail('invalid'); x.detail = String((n || 'Error') + ': ' + (e && e.message || '')).slice(0, 110); throw x;   // solo el tipo y el mensaje técnico de pdf.js: no incluye el contenido del PDF ni la clave
    }
    try {
      const pages = []; let count = 0;
      const last = Math.min(doc.numPages, MAX_PAGES);
      for (let n = 1; n <= last; n++) {
        const page = await doc.getPage(n);
        const vp = page.getViewport({ scale: 1 });
        const tc = await page.getTextContent();
        const items = [];
        for (const it of tc.items) {
          if (typeof it.str !== 'string' || !it.str.trim() || !it.transform) continue;
          if (++count > MAX_ITEMS) throw fail('invalid');
          items.push({ str: it.str.replace(/\s+/g, ' ').trim(), x: it.transform[4], y: it.transform[5], w: it.width || 0 });
        }
        pages.push({ w: vp.width, h: vp.height, items });
        page.cleanup();
      }
      if (!count) throw fail('no_text');
      return { pages, total: doc.numPages, truncated: doc.numPages > MAX_PAGES };
    } catch (e) { throw tag(e); } finally { try { await doc.destroy(); } catch (e) { /* nada */ } }
  }

  /* Agrupa los textos de una página en líneas (de arriba hacia abajo) y ordena cada una de izquierda a derecha. tol: tolerancia vertical. */
  function lines(page, tol) {
    tol = tol || 2.5;
    const sorted = page.items.slice().sort((a, b) => b.y - a.y || a.x - b.x), out = [];
    for (const it of sorted) {
      const l = out[out.length - 1];
      if (l && Math.abs(l.y - it.y) <= tol) l.items.push(it); else out.push({ y: it.y, items: [it] });
    }
    for (const l of out) l.items.sort((a, b) => a.x - b.x);
    return out;
  }

  const api = { load, read, lines, MAX_BYTES, MAX_PAGES };
  return api;
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaPDF;
