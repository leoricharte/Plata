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

  /* El color del texto de una caja: -1 rojizo, 1 verdoso, 0 si no se distingue. Se toma el color de los píxeles que más se alejan del fondo (igual que en iPhone). */
  let probe = null;
  function tone(cv, b) {
    const W = cv.width, H = cv.height, x = Math.max(0, Math.floor(b.x * W)), y = Math.max(0, Math.floor(b.y * H));
    const w = Math.max(2, Math.min(W - x, Math.ceil(b.w * W))), h = Math.max(2, Math.min(H - y, Math.ceil(b.h * H)));
    if (w < 2 || h < 2) return 0;
    const PW = 32, PH = 8;
    if (!probe) { probe = document.createElement('canvas'); probe.width = PW; probe.height = PH; }
    const g = probe.getContext('2d', { willReadFrequently: true });
    g.clearRect(0, 0, PW, PH); g.drawImage(cv, x, y, w, h, 0, 0, PW, PH);
    const d = g.getImageData(0, 0, PW, PH).data, n = PW * PH, corners = [0, PW - 1, (PH - 1) * PW, n - 1];
    let br = 0, bg = 0, bb = 0; corners.forEach((c) => { br += d[c * 4]; bg += d[c * 4 + 1]; bb += d[c * 4 + 2]; }); br /= 4; bg /= 4; bb /= 4;
    const dist = []; for (let i = 0; i < n; i++) dist.push([Math.abs(d[i * 4] - br) + Math.abs(d[i * 4 + 1] - bg) + Math.abs(d[i * 4 + 2] - bb), i]);
    dist.sort((p, q) => q[0] - p[0]);
    if (!dist.length || dist[0][0] <= 90) return 0;
    const top = dist.slice(0, Math.max(4, Math.floor(dist.length / 12)));
    let r = 0, gg = 0, bl = 0; top.forEach((t) => { r += d[t[1] * 4]; gg += d[t[1] * 4 + 1]; bl += d[t[1] * 4 + 2]; }); r /= top.length; gg /= top.length; bl /= top.length;
    if (r > gg + 45 && r > bl + 35) return -1;
    if (gg > r + 25 && gg > bl + 15) return 1;
    return 0;
  }

  /* El texto de la captura CON su lugar: [{ text, x, y, w, h, tone }] de 0 a 1 (y crece hacia abajo), más `url` (la captura reducida, para mostrarla) y `w`/`h`.
   * Es lo que necesita la sesión de reconocimiento (core/nazca/ejemplo.js). Cada línea de Tesseract se parte donde hay un hueco grande entre palabras
   * (el nombre a la izquierda y el monto a la derecha son cajas distintas). */
  async function readBoxes(file, base) {
    const c = await prep(file), w = await load(base);
    let r; try { r = await w.recognize(await blob(c), {}, { blocks: true }); } catch (e) { throw fail('unavailable'); }
    const d = (r && r.data) || {};
    let ls = d.lines;
    if (!ls || !ls.length) { ls = []; (d.blocks || []).forEach((b) => (b.paragraphs || []).forEach((p) => (p.lines || []).forEach((l) => ls.push(l)))); }
    const W = c.width, H = c.height, boxes = [];
    const mk = (ws) => {
      const x0 = Math.min(...ws.map((q) => q.bbox.x0)), y0 = Math.min(...ws.map((q) => q.bbox.y0)), x1 = Math.max(...ws.map((q) => q.bbox.x1)), y1 = Math.max(...ws.map((q) => q.bbox.y1));
      const text = ws.map((q) => String(q.text || '').trim()).filter(Boolean).join(' '); if (!text) return;
      const b = { text, x: x0 / W, y: y0 / H, w: (x1 - x0) / W, h: (y1 - y0) / H, tone: 0 };
      b.tone = tone(c, b); boxes.push(b);
    };
    ls.forEach((l) => {
      const ws = (l.words || []).filter((q) => q && q.bbox && String(q.text || '').trim()).sort((p, q) => p.bbox.x0 - q.bbox.x0);
      if (!ws.length) { if (l.bbox && String(l.text || '').trim()) mk([{ bbox: l.bbox, text: l.text }]); return; }
      let cur = [ws[0]];
      for (let i = 1; i < ws.length; i++) {
        const prev = ws[i - 1], gap = (ws[i].bbox.x0 - prev.bbox.x1) / W, hh = Math.max(prev.bbox.y1 - prev.bbox.y0, ws[i].bbox.y1 - ws[i].bbox.y0) / H;
        if (gap > Math.max(0.05, hh * 2.2)) { mk(cur); cur = []; }
        cur.push(ws[i]);
      }
      mk(cur);
    });
    if (!boxes.length) throw fail('no_text');
    return { boxes, url: c.toDataURL('image/jpeg', 0.92), w: W, h: H };
  }

  return { load, read, readBoxes, MAX_BYTES, MAX_SIDE };
})();
