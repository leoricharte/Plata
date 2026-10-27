/* Panel privado · pestaña Nazca. Se ejecuta en el panel (no en plataapp.net) y usa el MISMO motor que la app (nazca/engine.js, generado por build.sh) y el mismo token
 * de administrador que el resto del panel (variables globales tok, call, esc, save, when, fail del script principal).
 * Todo se lee en el navegador: el archivo que abres aquí no se sube a ningún servidor. */
(function () {
  'use strict';
  var Z = { bytes: null, name: '', pwd: '', res: null, doc: null, lib: null, subs: null };
  var PANEL = document.getElementById('pZ');
  if (!PANEL) return;

  var h = function (s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var q = function (id) { return document.getElementById(id); };
  var kb = function (n) { return n > 1048576 ? (n / 1048576).toFixed(1) + ' MB' : Math.max(1, Math.round(n / 1024)) + ' KB'; };
  var engine = function () { return typeof NazcaPDF !== 'undefined' && typeof NazcaBancos !== 'undefined'; };

  PANEL.innerHTML =
    '<div class="tabs" id="zt"><button type="button" data-z="P" class="on">Panel</button><button type="button" data-z="A">Aportar manualmente</button><button type="button" data-z="S">Revisar submissions</button><button type="button" data-z="B">Insertar nuevo banco</button></div>' +
    '<div id="zP"></div>' +
    '<div id="zA" hidden>' +
      '<div class="card"><div class="t">Aportar manualmente</div><p class="m" style="margin:6px 0 10px">Carga un estado de cuenta (PDF o CSV). Si tiene contraseña te la pide aquí; solo se usa para abrirlo, en tu navegador. Nazca lo lee y ves el resultado fila por fila.</p>' +
      '<input id="zf" type="file" accept=".pdf,.csv,.txt,application/pdf,text/csv" style="margin:0 0 10px">' +
      '<div id="zpw" hidden><label>CONTRASEÑA DEL PDF</label><input id="zpwi" type="password" autocomplete="off" placeholder="Por ejemplo, el DNI en el BCP"><div class="row" style="margin-top:0"><button id="zpwb" type="button">Abrir</button></div></div>' +
      '<div id="zam" class="m" style="margin-top:8px"></div></div>' +
      '<div id="zr"></div>' +
    '</div>' +
    '<div id="zS" hidden><div class="card"><div class="t">Submissions de Nazca</div><p class="m" style="margin:6px 0 0">Archivos que la gente mandó a propósito porque Nazca no los reconoció. Se guardan 30 días. Ábrelos en el analizador, descárgalos o elimínalos.</p><div class="row"><button id="zsl" type="button">Actualizar</button></div><div id="zsm" class="m" style="margin-top:8px"></div></div><div id="zsl2"></div></div>' +
    '<div id="zB" hidden></div>';

  /* ---------- sub-pestañas ---------- */
  function sub(n) {
    ['P', 'A', 'S', 'B'].forEach(function (k) { q('z' + k).hidden = k !== n; });
    [].forEach.call(q('zt').children, function (b) { b.classList.toggle('on', b.getAttribute('data-z') === n); });
    if (n === 'P') drawP(); if (n === 'S' && !Z.subs) loadSubs(); if (n === 'B') drawB();
  }
  q('zt').onclick = function (e) { var b = e.target.closest('button'); if (b) sub(b.getAttribute('data-z')); };
  window.nazcaPanelOpen = function () { sub('P'); };

  /* ---------- Panel ---------- */
  function drawP() {
    var cat = engine() ? NazcaBancos.CATALOG : [], act = 0, soon = 0, rows = '';
    cat.forEach(function (c) {
      var a = c.banks.filter(function (b) { return b.active; }), s = c.banks.length - a.length; act += a.length; soon += s;
      rows += '<div class="m" style="margin:4px 0"><b style="color:var(--ink)">' + h(c.name) + '</b> · ' + (a.map(function (b) { return h(b.name); }).join(', ') || '—') + (s ? ' · <i>próximamente: ' + c.banks.filter(function (b) { return !b.active; }).map(function (b) { return h(b.name); }).join(', ') + '</i>' : '') + '</div>';
    });
    q('zP').innerHTML = '<div class="card"><div class="t">Panel de Nazca</div>' +
      (engine() ? '<p class="m" style="margin:6px 0 10px"><b style="color:var(--ink)">' + NazcaBancos.READERS.length + '</b> lectores · <b style="color:var(--ink)">' + act + '</b> bancos activos · ' + soon + ' próximamente · <b style="color:var(--ink)" id="zpn">…</b> submissions pendientes</p>' + rows
        : '<p class="m" style="margin:6px 0 0;color:var(--warn)">El motor de Nazca no está cargado. Corre <code>sh dev/panel/build.sh</code> y vuelve a publicar el panel.</p>') +
      '<div class="row"><button type="button" id="zgo1" class="g">Aportar manualmente</button><button type="button" id="zgo2" class="g">Revisar submissions</button><button type="button" id="zgo3" class="g">Insertar nuevo banco</button></div></div>';
    q('zgo1').onclick = function () { sub('A'); }; q('zgo2').onclick = function () { sub('S'); }; q('zgo3').onclick = function () { sub('B'); };
    call('/nazca/list').then(function (j) { var e = q('zpn'); if (e) e.textContent = j.count; }).catch(function () { var e = q('zpn'); if (e) e.textContent = '?'; });
  }

  /* ---------- Aportar manualmente ---------- */
  function say(t, bad) { var e = q('zam'); e.textContent = t || ''; e.style.color = bad ? 'var(--warn)' : ''; }
  q('zf').onchange = function () {
    var f = this.files && this.files[0]; if (!f) return;
    f.arrayBuffer().then(function (b) { openBytes(new Uint8Array(b), f.name); });
  };
  q('zpwb').onclick = function () { Z.pwd = q('zpwi').value; run(); };
  q('zpwi').addEventListener('keydown', function (e) { if (e.key === 'Enter') { Z.pwd = this.value; run(); } });
  function openBytes(bytes, name) { sub('A'); Z.bytes = bytes; Z.name = name || 'archivo'; Z.pwd = ''; q('zpwi').value = ''; q('zpw').hidden = true; Z.res = null; Z.doc = null; q('zr').innerHTML = ''; run(); }
  window.nazcaPanelOpenBytes = openBytes;

  function isPdf(b) { var n = Math.min(b.length - 4, 1024); for (var i = 0; i < n; i++) if (b[i] === 37 && b[i + 1] === 80 && b[i + 2] === 68 && b[i + 3] === 70) return true; return false; }
  var MSG = { need_password: 'Este PDF tiene contraseña. Escríbela arriba.', bad_password: 'La contraseña no es correcta.', not_pdf: 'No parece un PDF.', too_big: 'El archivo es demasiado grande.', invalid: 'No se pudo abrir el PDF.', no_text: 'El PDF no tiene texto (puede ser una imagen escaneada).', unavailable: 'No se pudo cargar pdf.js. ¿Corriste build.sh?' };

  function run() {
    if (!engine()) { say('El motor de Nazca no está cargado (falta correr build.sh).', true); return; }
    var bytes = Z.bytes; if (!bytes) return;
    say('Leyendo…');
    if (!isPdf(bytes)) { runCsv(bytes); return; }
    var go = Z.lib ? Promise.resolve(Z.lib) : NazcaPDF.load(new URL('nazca/', location.href).href).then(function (l) { Z.lib = l; return l; });
    go.then(function (lib) { return NazcaPDF.read(bytes, lib, Z.pwd); }).then(function (doc) {
      Z.doc = doc; Z.pwd = ''; q('zpwi').value = ''; q('zpw').hidden = true; say(Z.name + ' · ' + doc.total + (doc.total === 1 ? ' página' : ' páginas') + (doc.truncated ? ' (solo se leyeron las primeras)' : '') + ' · ' + kb(bytes.length));
      var r = NazcaBancos.detect(doc), res = null, err = '';
      if (r) { try { res = r.read(doc); } catch (e) { err = String(e && e.message || e); } }
      Z.res = res; drawResult(doc, r, res, err);
    }).catch(function (e) {
      var c = e && e.code;
      if (c === 'need_password' || c === 'bad_password') { q('zpw').hidden = false; q('zpwi').focus(); }
      say((MSG[c] || 'No se pudo leer.') + (e && e.detail ? ' (' + e.detail + ')' : ''), c !== 'need_password');
    });
  }

  function runCsv(bytes) {
    try {
      var text = Nazca.decode(bytes), a = Nazca.analyze(text), sig = NazcaBancos.detectCsv(a && a.headers);
      say(Z.name + ' · CSV · ' + kb(bytes.length));
      var x = '<div class="card"><div class="t">Lectura del CSV</div><div class="m" style="margin-top:6px">' + (sig ? 'Reconocido: <b style="color:var(--ink)">' + h(sig.label) + '</b>' : 'Ningún banco lo reconoce por sus columnas; se leería con el lector genérico.') + '</div>' +
        '<div class="m" style="margin-top:6px">Separador: <code>' + h(a.delim) + '</code> · columnas: ' + h((a.headers || []).join(' | ')) + ' · filas: ' + a.rows.length + '</div></div>';
      q('zr').innerHTML = x;
    } catch (e) { say('No se pudo leer como CSV.', true); }
  }

  function maskText(s, rules) {
    s = String(s);
    s = s.replace(/[\w.+-]+@[\w-]+\.[\w.-]+/g, 'correo@ejemplo.com').replace(/\d{8,}/g, function (m) { return m.replace(/\d/g, '0'); });
    (rules || []).forEach(function (r) { if (r[0]) s = s.split(r[0]).join(r[1]); });
    return s;
  }
  function rulesOf() { return String((q('zrules') || {}).value || '').split('\n').map(function (l) { var i = l.indexOf('=>'); return i > 0 ? [l.slice(0, i).trim(), l.slice(i + 2).trim()] : null; }).filter(Boolean); }

  function drawResult(doc, reader, res, err) {
    var out = '';
    out += '<div class="card"><div class="t">' + (reader ? 'Nazca lo reconoce: ' + h(reader.label || reader.id) + (res && res.check ? (res.check.ok ? '<span class="pill ok">cuadra</span>' : res.check.ok === false ? '<span class="pill del">no cuadra</span>' : '<span class="pill">sin comprobación</span>') : '') : 'Ningún lector lo reconoce') + '</div>';
    if (err) out += '<div class="m" style="color:var(--warn);margin-top:6px">El lector falló: ' + h(err) + '</div>';
    if (res && res.error) out += '<div class="m" style="color:var(--warn);margin-top:6px">El lector avisa: ' + h(res.error) + '</div>';
    if (res && res.items) {
      var s = res.skipped || {}, tot = res.items.reduce(function (a, i) { return a + i.amount; }, 0);
      out += '<div class="m" style="margin-top:6px">' + res.items.length + ' movimientos · periodo ' + h(res.period ? res.period.from + ' → ' + res.period.to : 'no leído') + ' · moneda ' + h(res.cur) + ' · cuenta …' + h((res.account || {}).last4 || '') + ' · neto ' + tot.toFixed(2) + ' · no leídas: ' + (s.unreadable || 0) + ' · en cero: ' + (s.zero || 0) + '</div>';
      out += '<div style="overflow:auto;max-height:340px;margin-top:10px"><table style="border-collapse:collapse;width:100%;font-size:13px">' + res.items.slice(0, 300).map(function (i) { return '<tr><td style="padding:3px 8px 3px 0;color:var(--mute)">' + h(i.line) + '</td><td style="padding:3px 8px 3px 0">' + h(i.date) + '</td><td style="padding:3px 8px 3px 0">' + h(i.desc) + '</td><td style="padding:3px 0;text-align:right;color:' + (i.amount < 0 ? 'var(--warn)' : 'var(--accent)') + '">' + i.amount.toFixed(2) + '</td></tr>'; }).join('') + '</table></div>';
    }
    out += '</div>';
    out += '<div class="card"><div class="t">Convertir para entrenar</div><p class="m" style="margin:6px 0 0">Descarga lo que Nazca extrae del PDF (texto con su posición), ya sin contraseña. Es lo que necesita un lector nuevo y sirve de ejemplo para las pruebas. Enmascara antes de compartirlo.</p>' +
      '<div class="chk"><input type="checkbox" id="zmask" checked><label for="zmask" style="margin:0;font-size:15px;color:var(--ink);font-weight:600">Enmascarar correos y números de 8+ dígitos</label></div>' +
      '<label>REEMPLAZOS A MANO (UNO POR LÍNEA: <code>texto => reemplazo</code>, p. ej. tu nombre)</label><textarea id="zrules" style="min-height:70px" placeholder="JUAN PÉREZ GARCÍA => TITULAR EJEMPLO"></textarea>' +
      '<div class="row"><button type="button" id="zdx">Descargar extracción (JSON)</button>' + (res ? '<button type="button" class="g" id="zdr">Descargar resultado del lector</button>' : '') + '<button type="button" class="g" id="zcl">Copiar líneas</button></div><div id="zdm" class="m" style="margin-top:8px"></div></div>';
    out += '<div class="card"><div class="t">Texto por líneas</div><p class="m" style="margin:6px 0 8px">Cada línea muestra <code>x</code> de cada pieza de texto: sirve para ver las columnas de la tabla.</p><pre id="zpre" style="margin:0;max-height:420px;overflow:auto;font-size:12px;line-height:1.5;background:var(--bg);border:1px solid var(--line);border-radius:12px;padding:10px"></pre></div>';
    q('zr').innerHTML = out;
    q('zpre').textContent = linesOf(doc, false);
    q('zdx').onclick = function () {
      var rules = rulesOf(), mask = q('zmask').checked;
      var data = { v: 1, source: 'panel', pages: doc.pages.map(function (p) { return { w: Math.round(p.w), h: Math.round(p.h), items: p.items.map(function (i) { return { str: mask ? maskText(i.str, rules) : (rules.length ? maskText0(i.str, rules) : i.str), x: Math.round(i.x * 100) / 100, y: Math.round(i.y * 100) / 100, w: Math.round(i.w * 100) / 100 }; }) }; }) };
      save(Z.name.replace(/\.[^.]+$/, '').replace(/[^\w-]+/g, '-').slice(0, 40) + '.nazca.json', data); q('zdm').textContent = 'Descargada. Revísala antes de compartirla: el enmascarado es una ayuda, no una garantía.';
    };
    if (res) q('zdr').onclick = function () { var r = JSON.parse(JSON.stringify(res)); (r.items || []).forEach(function (i) { i.desc = (q('zmask').checked ? maskText(i.desc, rulesOf()) : i.desc); }); save('resultado-' + (res.bank || 'nazca') + '.json', r); };
    q('zcl').onclick = function () { var t = linesOf(doc, q('zmask').checked); (navigator.clipboard ? navigator.clipboard.writeText(t) : Promise.reject()).then(function () { q('zdm').textContent = 'Copiado.'; }).catch(function () { q('zdm').textContent = 'No se pudo copiar; selecciona el texto de abajo.'; }); };
  }
  function maskText0(s, rules) { rules.forEach(function (r) { if (r[0]) s = s.split(r[0]).join(r[1]); }); return s; }
  function linesOf(doc, mask) {
    var rules = rulesOf();
    return doc.pages.map(function (p, n) {
      return '── página ' + (n + 1) + ' (' + Math.round(p.w) + ' × ' + Math.round(p.h) + ') ──\n' + NazcaPDF.lines(p).map(function (l) {
        return Math.round(l.y) + '\t' + l.items.map(function (i) { var t = mask ? maskText(i.str, rules) : i.str; return Math.round(i.x) + ':' + t; }).join('  ');
      }).join('\n');
    }).join('\n\n');
  }

  /* ---------- Submissions ---------- */
  function loadSubs() {
    q('zsm').textContent = 'Cargando…'; q('zsl2').innerHTML = '';
    call('/nazca/list').then(function (l) {
      var ids = (l.ids || []).slice().reverse(); Z.subs = ids;
      q('zsm').textContent = ids.length ? ids.length + (ids.length === 1 ? ' archivo' : ' archivos') + '.' : 'No hay submissions pendientes.';
      return Promise.all(ids.map(function (id) { return call('/nazca/get?id=' + encodeURIComponent(id)).then(function (r) { return [id, r]; }).catch(function () { return [id, null]; }); }));
    }).then(function (rs) { (rs || []).forEach(function (x) { q('zsl2').appendChild(subCard(x[0], x[1])); }); }).catch(function (e) { Z.subs = null; q('zsm').textContent = e.code === 401 ? 'El token no es correcto.' : 'No se pudo: ' + e.message; });
  }
  q('zsl').onclick = function () { Z.subs = null; loadSubs(); };
  function b64bytes(b) { var bin = atob(b), u = new Uint8Array(bin.length); for (var i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i); return u; }
  function subCard(id, r) {
    var el = document.createElement('div'); el.className = 'card';
    var size = r && r.b64 ? Math.round(r.b64.length * 0.75) : 0;
    el.innerHTML = '<div class="t">' + h(when(id)) + '<span class="pill">' + h(r ? r.kind : '?') + '</span>' + (r && r.bank ? '<span class="pill">' + h(r.bank) + '</span>' : '') + '</div>' +
      '<div class="m">' + (r ? kb(size) + ' · ' + h(r.plat || 'plataforma desconocida') + ' · build ' + (Number(r.build) || '?') + (r.why ? ' · motivo: ' + h(r.why) : '') : 'No se pudo leer.') + '</div><div class="row"></div>';
    var row = el.querySelector('.row');
    function btn(t, c, fn) { var b = document.createElement('button'); b.textContent = t; if (c) b.className = c; b.onclick = function () { fn(b); }; row.appendChild(b); }
    if (r && r.b64) {
      btn('Abrir en el analizador', '', function () { openBytes(b64bytes(r.b64), 'envio-' + id + '.' + (r.kind === 'otro' ? 'bin' : r.kind)); });
      btn('Descargar archivo', 'g', function () { var a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([b64bytes(r.b64)])); a.download = 'nazca-' + id + '.' + (r.kind === 'otro' ? 'bin' : r.kind); document.body.appendChild(a); a.click(); a.remove(); });
    }
    btn('Eliminar del servidor', 'd', function (b) {
      if (!confirm('¿Eliminar este archivo del servidor? No se puede deshacer. Descárgalo antes si lo necesitas.')) return;
      b.disabled = true; call('/nazca/delete?id=' + encodeURIComponent(id), 'POST').then(function () { el.remove(); }).catch(function (e) { b.disabled = false; q('zsm').textContent = 'No se pudo eliminar: ' + e.message; });
    });
    return el;
  }

  /* ---------- Insertar nuevo banco ---------- */
  function drawB() {
    if (q('zbf')) return;
    q('zB').innerHTML = '<div class="card"><div class="t">Insertar nuevo banco</div><p class="m" style="margin:6px 0 10px">Genera el esqueleto del lector, la entrada del catálogo y los pasos para dejarlo cableado en la app. El banco queda como «Próximamente» hasta que aportes un estado de cuenta real y el lector cuadre.</p>' +
      '<div id="zbf"><div class="two"><div><label>PAÍS (CÓDIGO ISO)</label><input id="zbc" maxlength="2" placeholder="CL"></div><div><label>NOMBRE DEL PAÍS</label><input id="zbn" placeholder="Chile"></div></div>' +
      '<div class="two"><div><label>ID DEL BANCO (MINÚSCULAS)</label><input id="zbi" maxlength="24" placeholder="bancoestado"></div><div><label>NOMBRE</label><input id="zbm" placeholder="BancoEstado"></div></div>' +
      '<div class="two"><div><label>SEDE</label><input id="zbh" placeholder="Santiago"></div><div><label>TIPO DE ESTADO DE CUENTA</label><input id="zbk" placeholder="cuenta | tarjeta" value="cuenta"></div></div>' +
      '<div class="two"><div><label>MONEDA</label><input id="zbu" maxlength="3" placeholder="CLP" value=""></div><div><label>TEXTO QUE SIEMPRE APARECE EN EL PDF (PARA RECONOCERLO)</label><input id="zbt" placeholder="BANCOESTADO"></div></div>' +
      '<div class="row"><button type="button" id="zbg">Generar</button></div></div><div id="zbo"></div></div>';
    q('zbg').onclick = genBank;
  }
  function slug(s) { return String(s || '').toLowerCase().replace(/[^a-z0-9]/g, ''); }
  function copyBox(title, text, file) {
    var id = 'zc' + Math.random().toString(36).slice(2, 7);
    return '<div class="card"><div class="t">' + h(title) + '</div><pre id="' + id + '" style="margin:8px 0 0;max-height:300px;overflow:auto;font-size:12px;line-height:1.5;background:var(--bg);border:1px solid var(--line);border-radius:12px;padding:10px;white-space:pre-wrap">' + h(text) + '</pre><div class="row"><button type="button" class="g" data-copy="' + id + '">Copiar</button>' + (file ? '<button type="button" class="g" data-dl="' + id + '" data-f="' + h(file) + '">Descargar ' + h(file) + '</button>' : '') + '</div></div>';
  }
  function genBank() {
    var cc = String(q('zbc').value).toUpperCase().replace(/[^A-Z]/g, '').slice(0, 2), cn = q('zbn').value.trim(), id = slug(q('zbi').value), nm = q('zbm').value.trim(), hq = q('zbh').value.trim(), cur = String(q('zbu').value).toUpperCase().replace(/[^A-Z]/g, '').slice(0, 3), kind = slug(q('zbk').value) === 'tarjeta' ? 'tarjeta' : 'cuenta', tx = q('zbt').value.trim().toUpperCase();
    if (!cc || !cn || !id || !nm) { q('zbo').innerHTML = '<div class="card"><div class="m" style="color:var(--warn)">Faltan país, nombre del país, id y nombre del banco.</div></div>'; return; }
    var exist = engine() && NazcaBancos.CATALOG.some(function (c) { return c.banks.some(function (b) { return b.id === id; }); });
    var G = 'Nazca' + id.charAt(0).toUpperCase() + id.slice(1), file = id + '-' + kind + '.js', label = nm + ' · ' + (kind === 'tarjeta' ? 'Tarjeta' : 'Cuenta');
    var code = [
      '/* ---------- Nazca · ' + nm + ' (' + cn + ') · ' + label + ' ----------',
      ' * Estado: SIN PROBAR. Escrito a partir de un ejemplo aún no aportado. Hasta que haya un estado de cuenta real que cuadre, el banco queda como «Próximamente».',
      ' * Entrada: lo que devuelve NazcaPDF.read() → { pages: [{ w, h, items: [{ str, x, y, w }] }] }. Todo ocurre en el dispositivo.',
      ' * Salida de read(): { bank, kind, label, cur, account:{ last4 }, period:{ from, to }, items:[{ line, date, desc, amount, cur }], skipped, check } */',
      'const ' + G + ' = (() => {',
      '  const norm = (s) => String(s || \'\').normalize(\'NFD\').replace(/[\\u0300-\\u036f]/g, \'\').replace(/\\s+/g, \' \').trim().toUpperCase();',
      '  const text = (page) => page.items.map((i) => i.str).join(\' \');',
      '',
      '  /* ¿Es un estado de cuenta de ' + nm + '? Pide la marca y los títulos propios de la tabla. */',
      '  function detect(doc) {',
      '    if (!doc || !doc.pages || !doc.pages.length) return 0;',
      '    const t = norm(text(doc.pages[0]));',
      '    return /' + (tx ? tx.replace(/[^A-Z0-9 ]/g, '').replace(/ /g, ' ?') : 'COMPLETAR') + '/.test(t) /* && /TÍTULO DE COLUMNA/.test(t) */ ? 1 : 0;',
      '  }',
      '',
      '  function read(doc) {',
      '    if (!detect(doc)) return null;',
      '    const out = { bank: \'' + id + '\', kind: \'' + (kind === 'tarjeta' ? 'tarjeta' : 'corriente') + '\', label: \'' + label.replace(/'/g, "\\'") + '\', cur: \'' + (cur || 'XXX') + '\', account: { last4: \'\' }, period: null, items: [], skipped: { unreadable: 0, zero: 0 }, check: null };',
      '    // 1) periodo y últimos 4 dígitos  2) encabezados de la tabla (posición x de cada columna)  3) una fila por movimiento  4) check: totales impresos = suma leída',
      '    // Ayuda: el panel de Nazca → Aportar manualmente → «Texto por líneas» muestra el x de cada columna.',
      '    return Object.assign(out, { error: \'sin_implementar\' });',
      '  }',
      '',
      '  return { id: \'' + id + '-' + kind + '\', bank: \'' + id + '\', label: \'' + label.replace(/'/g, "\\'") + '\', detect, read };',
      '})();',
      'if (typeof module !== \'undefined\' && module.exports) module.exports = ' + G + ';', ''
    ].join('\n');
    var cat = exist ? '// «' + id + '» ya está en el catálogo: solo cambia active: true cuando el lector cuadre.' : '// En CATALOG (dev/app/src/core/nazca/bancos/index.js), ' + (engine() && NazcaBancos.CATALOG.some(function (c) { return c.id === cc; }) ? 'dentro de { id: \'' + cc + '\' … banks: [ … ]:' : 'como país nuevo:') + '\n' +
      (engine() && NazcaBancos.CATALOG.some(function (c) { return c.id === cc; }) ? '' : '{ id: \'' + cc + '\', name: \'' + cn + '\', banks: [ ') + '{ id: \'' + id + '\', name: \'' + nm.replace(/'/g, "\\'") + '\', hq: \'' + hq.replace(/'/g, "\\'") + '\', active: false }' + (engine() && NazcaBancos.CATALOG.some(function (c) { return c.id === cc; }) ? ',' : ' ] },');
    var steps = [
      '1. Guarda el lector como dev/app/src/core/nazca/bancos/' + file + '.',
      '2. bancos/index.js → agrega a READERS: typeof ' + G + ' !== \'undefined\' ? ' + G + ' : require(\'./' + file + '\'); y la entrada del catálogo (abajo).',
      '3. dev/app/build.py → agrega "bancos/' + file + '" a la lista de Nazca, ANTES de "bancos/index.js".',
      '4. app.html → BANKS (logo del banco), IMP_ONLY, IMP_STEPS (cómo descargar el estado de cuenta) e IMP_MARKS si el banco tiene país nuevo.',
      '5. Aporta un estado de cuenta (Aportar manualmente → Descargar extracción), arma uno inventado con el mismo diseño en dev/tests/pdf/hacer-pdfs.py y escribe la prueba en dev/tests/nazca-pdf.mjs.',
      '6. Cuando cuadre con un estado real: active: true y entra a «Bancos que Nazca lee» en transparencia.html.', '', 'Panel: sh dev/panel/build.sh vuelve a empaquetar el motor para que el analizador use el lector nuevo.'].join('\n');
    q('zbo').innerHTML = (exist ? '<div class="card"><div class="m" style="color:var(--warn)">Ese id ya existe en el catálogo.</div></div>' : '') + copyBox('1 · Esqueleto del lector', code, file) + copyBox('2 · Entrada del catálogo', cat) + copyBox('3 · Pasos para dejarlo cableado', steps);
  }
  q('zB').onclick = function (e) {
    var c = e.target.closest('[data-copy]'), d = e.target.closest('[data-dl]');
    if (c) { var t = q(c.getAttribute('data-copy')).textContent; (navigator.clipboard ? navigator.clipboard.writeText(t) : Promise.reject()).then(function () { c.textContent = 'Copiado'; }).catch(function () { c.textContent = 'Selecciona y copia a mano'; }); }
    if (d) { var a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([q(d.getAttribute('data-dl')).textContent], { type: 'text/javascript' })); a.download = d.getAttribute('data-f'); document.body.appendChild(a); a.click(); a.remove(); }
  };
})();
