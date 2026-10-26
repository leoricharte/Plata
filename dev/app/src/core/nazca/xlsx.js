/* ---------- Nazca · lector mínimo de .xlsx ----------
 * Un .xlsx es un ZIP con XML. Aquí se abre en el dispositivo, sin librerías: ZIP (directorio central + deflate nativo del navegador) y la primera hoja
 * (textos en línea o compartidos, números). No evalúa fórmulas ni macros: solo lee los valores. Devuelve filas de texto: string[][].
 * Límites: archivo de hasta 5 MB, hasta 100 entradas y 30 MB descomprimidos (contra ZIP bombas). */
const NazcaXLSX = (() => {
  const MAX_BYTES = 5 * 1024 * 1024, MAX_ENTRIES = 100, MAX_OUT = 30 * 1024 * 1024, MAX_ROWS = 20000;
  const fail = (code) => Object.assign(new Error(code), { code });
  const u16 = (b, o) => b[o] | (b[o + 1] << 8), u32 = (b, o) => (b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)) >>> 0;
  const isZip = (b) => b.length > 4 && b[0] === 0x50 && b[1] === 0x4b && (b[2] === 3 || b[2] === 5);
  async function inflate(raw, size) {
    const st = new Blob([raw]).stream().pipeThrough(new DecompressionStream('deflate-raw')), rd = st.getReader(), parts = []; let n = 0;
    for (;;) { const r = await rd.read(); if (r.done) break; n += r.value.length; if (n > MAX_OUT || n > size + 16) { try { await rd.cancel(); } catch (e) { /* nada */ } throw fail('too_big'); } parts.push(r.value); }
    const out = new Uint8Array(n); let o = 0; parts.forEach((p) => { out.set(p, o); o += p.length; }); return out;
  }
  function entries(b) {
    let e = -1; for (let i = b.length - 22; i >= Math.max(0, b.length - 22 - 65535); i--) if (u32(b, i) === 0x06054b50) { e = i; break; }
    if (e < 0) throw fail('bad_zip');
    const n = u16(b, e + 10); let o = u32(b, e + 16); if (n > MAX_ENTRIES) throw fail('too_big');
    const out = {};
    for (let i = 0; i < n; i++) {
      if (o + 46 > b.length || u32(b, o) !== 0x02014b50) throw fail('bad_zip');
      const method = u16(b, o + 10), csize = u32(b, o + 20), usize = u32(b, o + 24), nl = u16(b, o + 28), xl = u16(b, o + 30), cl = u16(b, o + 32), lo = u32(b, o + 42);
      const name = new TextDecoder().decode(b.subarray(o + 46, o + 46 + nl)); out[name] = { method, csize, usize, lo }; o += 46 + nl + xl + cl;
    }
    return out;
  }
  async function file(b, ent, name) {
    const x = ent[name]; if (!x) return null; if (x.usize > MAX_OUT) throw fail('too_big');
    const o = x.lo; if (o + 30 > b.length || u32(b, o) !== 0x04034b50) throw fail('bad_zip');
    const s = o + 30 + u16(b, o + 26) + u16(b, o + 28), raw = b.subarray(s, s + x.csize);
    const bytes = x.method === 0 ? raw : x.method === 8 ? await inflate(raw, x.usize) : (() => { throw fail('bad_zip'); })();
    return new TextDecoder('utf-8').decode(bytes);
  }
  const unesc = (t) => String(t).replace(/&(#x[0-9a-f]+|#\d+|lt|gt|amp|quot|apos);/gi, (m, g) => g[0] === '#' ? String.fromCodePoint(g[1].toLowerCase() === 'x' ? parseInt(g.slice(2), 16) : +g.slice(1)) : ({ lt: '<', gt: '>', amp: '&', quot: '"', apos: "'" })[g.toLowerCase()]);
  const texts = (x) => { let s = '', m; const re = /<t(?:\s[^>]*)?>([\s\S]*?)<\/t>/g; while ((m = re.exec(x))) s += unesc(m[1]); return s; };
  const colIdx = (r) => { const l = /^[A-Z]+/.exec(r); if (!l) return -1; let n = 0; for (const c of l[0]) n = n * 26 + c.charCodeAt(0) - 64; return n - 1; };
  async function read(buf) {
    const b = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
    if (b.length > MAX_BYTES) throw fail('too_big'); if (!isZip(b)) throw fail('not_xlsx');
    const ent = entries(b); if (!ent['xl/workbook.xml']) throw fail('not_xlsx');
    let path = 'xl/worksheets/sheet1.xml';
    try { const wb = await file(b, ent, 'xl/workbook.xml'), rels = await file(b, ent, 'xl/_rels/workbook.xml.rels'), sid = /<sheet\b[^>]*\br:id="([^"]+)"/.exec(wb);
      if (sid && rels) { const re = new RegExp('<Relationship\\b[^>]*\\bId="' + sid[1].replace(/[^\w.-]/g, '') + '"[^>]*>', 'i'), tag = re.exec(rels), t = tag && /\bTarget="([^"]+)"/.exec(tag[0]); if (t) path = t[1].replace(/^\//, '').replace(/^(?!xl\/)/, 'xl/'); } } catch (e) { if (e.code) throw e; }
    if (!ent[path]) path = Object.keys(ent).find((k) => /^xl\/worksheets\/[^/]+\.xml$/.test(k)) || ''; if (!path) throw fail('not_xlsx');
    const ss = [], sx = await file(b, ent, 'xl/sharedStrings.xml'); if (sx) { const re = /<si\b[^>]*>([\s\S]*?)<\/si>/g; let m; while ((m = re.exec(sx))) ss.push(texts(m[1])); }
    const xml = await file(b, ent, path), rows = [], re = /<c\b([^>]*?)(?:\/>|>([\s\S]*?)<\/c>)/g; let m;
    while ((m = re.exec(xml))) {
      const at = m[1], ref = /\br="([A-Z]+)(\d+)"/.exec(at); if (!ref || m[2] == null) continue;
      const ri = +ref[2] - 1, ci = colIdx(ref[1]); if (ri >= MAX_ROWS || ci < 0 || ci > 60) continue;
      const t = (/\bt="([^"]+)"/.exec(at) || [])[1], v = /<v>([\s\S]*?)<\/v>/.exec(m[2]);
      const val = t === 'inlineStr' ? texts(m[2]) : t === 's' ? (v ? ss[+v[1]] || '' : '') : v ? unesc(v[1]) : '';
      if (val === '') continue; (rows[ri] = rows[ri] || [])[ci] = String(val);
    }
    const out = []; for (let i = 0; i < rows.length; i++) { const r = rows[i] || [], a = []; for (let j = 0; j < r.length; j++) a.push(r[j] == null ? '' : r[j]); out.push(a); }
    return out;
  }
  return { read, isZip, MAX_BYTES };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaXLSX;
