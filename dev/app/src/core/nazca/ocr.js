/* ---------- Nazca · OCR de capturas (constancias de Yape y Plin) ----------
 * Lee el texto de una captura de pantalla con Tesseract (tesseract.js, Apache 2.0) y se lo pasa a core/nazca/constancia.js.
 * Todo ocurre en el dispositivo: la imagen no se sube a ningún servidor. La librería vive en nazca/ocr/ y solo se descarga la primera
 * vez que alguien elige una captura (~6 MB); Nazca no la incluye. Para que el recorte de texto sea fiable la imagen se reduce a MAX_SIDE px.
 * Errores: Error con .code = 'not_image' | 'too_big' | 'unavailable' | 'no_text'. */
const NazcaOCR = (() => {
  const MAX_BYTES = 12 * 1024 * 1024, MAX_SIDE = 2000;
  const fail = (code) => { const e = new Error(code); e.code = code; return e; };
  let worker = null, booting = null;

  function addScript(src) {
    return new Promise((ok, no) => { const s = document.createElement('script'); s.src = src; s.onload = ok; s.onerror = () => no(fail('unavailable')); document.head.appendChild(s); });
  }

  /* base: dirección que termina en "/" con tesseract.min.js, worker.min.js, los núcleos y spa.traineddata.gz. */
  async function load(base) {
    if (worker) return worker;
    if (booting) return booting;
    booting = (async () => {
      try {
        if (!window.Tesseract) await addScript(base + 'tesseract.min.js');
        const w = await window.Tesseract.createWorker('spa', 1, { workerPath: base + 'worker.min.js', corePath: base, langPath: base, workerBlobURL: false, gzip: true, cacheMethod: 'none', logger: () => {} });
        await w.setParameters({ tessedit_pageseg_mode: '11' });   /* texto disperso: las constancias tienen el monto grande aparte y Tesseract lo salta con el modo normal */
        worker = w; return w;
      } catch (e) { throw e && e.code ? e : fail('unavailable'); } finally { booting = null; }
    })();
    return booting;
  }

  /* Reduce la captura (a escala de grises) para que el OCR sea rápido y no se coma la memoria del teléfono. Devuelve el canvas. */
  async function prep(file) {
    if (!file || !/^image\//.test(file.type || '')) throw fail('not_image');
    if (file.size > MAX_BYTES) throw fail('too_big');
    let bmp; try { bmp = await createImageBitmap(file); } catch (e) { throw fail('not_image'); }
    const k = Math.min(1, MAX_SIDE / Math.max(bmp.width, bmp.height)), c = document.createElement('canvas');
    c.width = Math.max(1, Math.round(bmp.width * k)); c.height = Math.max(1, Math.round(bmp.height * k));
    const g = c.getContext('2d'); g.fillStyle = '#fff'; g.fillRect(0, 0, c.width, c.height); g.drawImage(bmp, 0, 0, c.width, c.height);
    if (bmp.close) bmp.close();
    return c;
  }
  /* Letras claras sobre fondo de color (el monto grande de Yape): se invierten los colores y se pasan a gris para que Tesseract las vea. */
  function inverted(c) {
    const o = document.createElement('canvas'); o.width = c.width; o.height = c.height;
    const g = o.getContext('2d'), im = c.getContext('2d').getImageData(0, 0, c.width, c.height), d = im.data;
    for (let i = 0; i < d.length; i += 4) { const y = 255 - (d[i] * 0.299 + d[i + 1] * 0.587 + d[i + 2] * 0.114); d[i] = d[i + 1] = d[i + 2] = y; d[i + 3] = 255; }
    g.putImageData(im, 0, 0); return o;
  }
  const blob = (c) => new Promise((ok, no) => c.toBlob((b) => (b ? ok(b) : no(fail('not_image'))), 'image/png'));

  /* Devuelve el texto de la captura, línea por línea. `enough(texto)` dice si ya basta (p. ej. si ya se ve un monto); si no, se vuelve
   * a leer con los colores invertidos y se juntan los dos textos. */
  async function read(file, base, enough) {
    const c = await prep(file), w = await load(base);
    let out = '';
    for (const mk of [() => c, () => inverted(c)]) {
      let r; try { r = await w.recognize(await blob(mk())); } catch (e) { throw fail('unavailable'); }
      out = (out + '\n' + String((r && r.data && r.data.text) || '')).trim();
      if (out && (!enough || enough(out))) break;
    }
    if (!out) throw fail('no_text');
    return out;
  }

  return { load, read, MAX_BYTES, MAX_SIDE };
})();
