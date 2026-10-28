/* Arranque de la página interna de lectura de PDF (solo iOS; no existe en la web).
   El worker de pdf.js corre en el hilo principal de esta página (globalThis.pdfjsWorker): así no hace falta crear un Worker desde un esquema propio. */
try {
  window.NazcaPDF = NazcaPDF;   // viene de nazca-pdf.js, el mismo archivo que usa la web
  const W = await import('./pdf.worker.mjs');
  globalThis.pdfjsWorker = { WorkerMessageHandler: W.WorkerMessageHandler };
  window.__lib = await import('./pdf.mjs');
  window.__ok = true;
} catch (e) { window.__err = String((e && e.message) || e).slice(0, 160); }
