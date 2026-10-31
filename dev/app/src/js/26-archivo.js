/* ---------- Archivo (save file) ---------- */
function stampName() {
  const n = new Date(), z = (v) => String(v).padStart(2, '0');
  return 'plata-' + n.getFullYear() + '-' + z(n.getMonth() + 1) + '-' + z(n.getDate()) + '_' + z(n.getHours()) + '-' + z(n.getMinutes()) + '.json';
}
function reviewCopy() {
  const copy = JSON.parse(JSON.stringify(data)), z = (v) => String(v).padStart(2, '0'), n = new Date();
  const m = anRead(data) || { id: Array.from(crypto.getRandomValues(new Uint8Array(4))).map((x) => x.toString(16).padStart(2, '0')).join(''), at: n.getFullYear() + '-' + z(n.getMonth() + 1) + '-' + z(n.getDate()) };
  anStamp(copy, m);
  copy.meta = { at: Date.now(), plat: syncDevice().plat };
  return copy;
}
function reviewDlg() {
  const rv0 = data.settings && data.settings.rv; if (rv0 && rv0.until > Date.now()) { toast('Ya enviaste una copia hace poco. Podrás enviar otra más tarde.'); return; }
  const row = (ic, t, no) => '<div class="row rvr"><span class="rvi' + (no ? ' no' : '') + '">' + RMI(ic, 18, 'currentColor') + '</span><span class="grow">' + t + '</span></div>';
  showSheet(sheetHead('Análisis de uso') +
    '<div class="rvint"><div class="rvbig">' + RMI('file-search-line', 26, '#1A9D63') + '</div>' +
    '<div class="sub">Se enviará una copia de tu archivo de perfil al equipo de Plata para entender cómo se usa la app y mejorarla.</div></div>' +
    '<div class="slabel rvl">Qué se hará</div><div class="scard">' +
    row('folder-line', 'Se envía una copia con tus movimientos, cuentas, tarjetas y ajustes.') +
    row('shield-check-line', 'La copia se marca como analizada por el equipo de Plata, con la fecha de hoy.') +
    row('lightbulb-line', 'El equipo la revisa con ayuda de herramientas de inteligencia artificial.') +
    row('lock-unlock-line', 'La copia no va cifrada de extremo a extremo: el equipo puede leerla.') +
    row('delete-bin-line', 'Al terminar la revisión, la copia se elimina de los servidores y te lo avisamos aquí.') + '</div>' +
    '<div class="slabel rvl">Qué no se hará</div><div class="scard">' +
    row('eye-off-line', 'No se publica ni se vende. Si se revisa con una herramienta de IA, esa herramienta recibe la copia.', 1) +
    row('camera-line', 'No se usa para imágenes ni videos públicos.', 1) +
    row('checkbox-circle-fill', 'No cambia tu perfil: tus datos siguen igual en tu dispositivo.', 1) + '</div>' +
    '<button class="primary rvgo" data-act="rvgo" disabled style="margin-top:4px;opacity:.5">Enviar a Plata (5)</button>');
  let n = 5; const tm = setInterval(() => {
    const b = document.querySelector('#sheet .rvgo'); if (!b) { clearInterval(tm); return; }
    n--; if (n > 0) { b.textContent = 'Enviar a Plata (' + n + ')'; return; }
    clearInterval(tm); b.textContent = 'Enviar a Plata'; b.disabled = false; b.style.opacity = '';
  }, 1000);
}
let rvLast = 0, rvBusy = 0;
function rvStamp(r) { // al revisarse la copia enviada, el perfil local también queda marcado como analizado
  if (!r || !r.done || anRead(data)) return false;
  const id = /^[0-9a-f]{8}$/.test(r.an || '') ? r.an : Array.from(crypto.getRandomValues(new Uint8Array(4))).map((x) => x.toString(16).padStart(2, '0')).join('');
  anStamp(data, { id: id, at: r.done }); persist(); return true;
}
async function rvCheck(r) {
  if (rvBusy || r.del || Date.now() - rvLast < 60000) return;
  rvBusy = 1; rvLast = Date.now();
  try {
    const x = await fetch(PLATA_CLOUD_API + '/review/status?id=' + encodeURIComponent(r.id)); const j = await x.json();
    if (j && j.ok) {
      let ch = 0;
      if (j.reviewed && AN_AT.test(j.reviewed) && !r.done) { r.done = j.reviewed; ch = 1; }
      if (rvStamp(r)) ch = 1;
      if (j.deleted && AN_AT.test(j.deleted)) { r.del = j.deleted; ch = 1; }
      if (ch) { persist(); rvBusy = 0; renderAll(); return; }
    }
  } catch (e) { /* sin conexión */ }
  rvBusy = 0;
}
function rvNoteHTML() {
  const r = data.settings && data.settings.rv; if (!r || !r.id || !AN_AT.test(r.at || '')) return '';
  rvCheck(r);
  if (rvStamp(r)) setTimeout(renderAll, 50);
  return '<div class="annote rvn">' + RMI(r.done ? 'checkbox-circle-fill' : 'time-line', 15, r.done ? '#22B573' : 'currentColor') + '<span>Último envío</span> <b>' + anDate(r.at) + '</b> · ' +
    (r.done ? '<span class="rvok">Revisado</span> <b>' + anDate(r.done) + '</b>' : '<span>En revisión</span>') + (r.del ? '<div class="rvnx">' + RMI('delete-bin-line', 15, 'currentColor') + '<span>Copia eliminada de los servidores</span> <b>' + anDate(r.del) + '</b></div>' : '') + '</div>';
}
async function reviewSend() {
  const copy = reviewCopy();
  toast('Enviando…');
  try {
    const r = await fetch(PLATA_CLOUD_API + '/review', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ v: 1, build: APP_BUILD, plat: syncDevice().plat, data: copy }) });
    const j = await r.json().catch(() => ({}));
    if (r.status === 403 && j.error === 'off') { toast('El envío de copias para análisis está desactivado.'); return; }
    if (r.status === 429 && j.error === 'wait') { if (data.settings.rv && j.until) { data.settings.rv.until = j.until; persist(); renderAll(); } toast('Ya enviaste una copia hace poco. Podrás enviar otra más tarde.'); return; }
    if (r.ok && j.ok) { const z = (v) => String(v).padStart(2, '0'), n = new Date(); data.settings.rv = { id: j.id, at: n.getFullYear() + '-' + z(n.getMonth() + 1) + '-' + z(n.getDate()), until: Number(j.until) || 0, an: copy.analysis && copy.analysis.id }; persist(); renderAll(); toast('Enviado al equipo de Plata. ¡Gracias!'); return; }
  } catch (e) { /* sin conexión */ }
  askConfirm('No se pudo enviar', 'Revisa tu conexión e inténtalo de nuevo. También puedes guardar la copia marcada y enviarla tú.', [
    { label: 'Intentar de nuevo', fn: reviewSend },
    { label: 'Guardar copia marcada', fn: reviewFile }]);
}
function reviewFile() {
  const f = new File([JSON.stringify(reviewCopy(), null, 2)], stampName().replace('plata-', 'plata-revision-'), { type: 'application/json' });
  const url = URL.createObjectURL(f), a = document.createElement('a');
  a.href = url; a.download = f.name; document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 4000);
}
async function saveFile() {
  const fname = stampName();
  const file = new File([JSON.stringify(Object.assign({}, data, { meta: { at: Date.now(), plat: syncDevice().plat } }), null, 2)], fname, { type: 'application/json' });
  try {
    if (navigator.canShare && navigator.canShare({ files: [file] })) {
      await navigator.share({ files: [file], title: fname });
      markSaved(); return;
    }
  } catch (e) { if (e && e.name === 'AbortError') return; }
  const url = URL.createObjectURL(file);
  const a = document.createElement('a');
  a.href = url; a.download = fname;
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 4000);
  markSaved();
}
function markSaved() { clGoneClear(); stampSaved(); ui.dirty = 0; persist(); renderAll(); toast('Archivo de perfil guardado'); }

