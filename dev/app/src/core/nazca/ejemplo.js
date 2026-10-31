/* ---------- Nazca · Sesión de reconocimiento (capturas de cualquier app o banco) ----------
 * La persona sube una captura y ENCIERRA con el dedo (o el mouse) uno o varios movimientos. Nazca busca esas filas en el texto reconocido,
 * aprende cómo está armada cada una (dónde van el monto, la descripción y la fecha, y cómo se distingue un gasto de un ingreso) y aplica esa
 * misma forma al resto de la captura. Sin red: el texto con posiciones lo reconoce el dispositivo (core/nazca/ocr.js) y todo lo demás es esta lógica.
 * El resultado siempre pasa por la revisión antes de entrar a la cuenta.
 * Es la MISMA lógica que NazcaExample.swift (iPhone): si cambias una, cambia la otra. dev/tests/ejemplo.mjs repite las pruebas de Swift.
 *
 * Caja (Box): un trozo de texto con su lugar, de 0 a 1, con `y` creciendo hacia ABAJO: { text, x, y, w, h, tone }. `tone`: -1 rojizo, 1 verdoso, 0 neutro.
 * Región (Region): { x, y, w, h }, también de 0 a 1.
 * Plantilla (Template): solo la FORMA de la captura (posiciones, no textos ni montos ni fechas). Es lo único que podría compartirse algún día. */
const NazcaEjemplo = (() => {
  const strip = (t) => String(t == null ? '' : t).toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');
  const pad = (n) => String(n).padStart(2, '0');
  const right = (b) => b.x + b.w;

  // ---------- Dinero ----------
  const MONEY = /^([+\-])?\s*(S\/\.?|US\$|USD|PEN|\$)?\s*([+\-])?\s*(\d[\d.,' ]*)\s*(PEN|USD)?$/i;

  /* «1,234.50», «1.234,50», «25.00», «25,5», «1 234»: el último separador con 1 o 2 cifras detrás es el decimal. */
  function number(s) {
    const cleaned = String(s).replace(/ /g, '').replace(/'/g, '');
    if (!cleaned || !/^\d/.test(cleaned) || !/\d$/.test(cleaned)) return null;
    const seps = []; for (let i = 0; i < cleaned.length; i++) if (cleaned[i] === '.' || cleaned[i] === ',') seps.push(i);
    if (!seps.length) { const v = Number(cleaned); return isNaN(v) ? null : v; }
    const last = seps[seps.length - 1], after = cleaned.length - last - 1, ch = cleaned[last];
    const same = seps.filter((i) => cleaned[i] === ch).length;
    let decimal;
    if (seps.length > same) decimal = after >= 1 && after <= 2;        // hay de los dos tipos: el último es el decimal
    else if (same > 1) decimal = false;                                  // «1.234.567»
    else decimal = after >= 1 && after <= 2;                             // un solo separador: 3 cifras detrás = miles
    let intPart = decimal ? cleaned.slice(0, last) : cleaned;
    const frac = decimal ? cleaned.slice(last + 1) : '';
    intPart = intPart.replace(/\./g, '').replace(/,/g, '');
    const v = Number(frac ? intPart + '.' + frac : intPart);
    return isNaN(v) ? null : v;
  }

  /* {value, marker (-1, 1 o 0), cur} o null. «($229.80)» y «229.80-» son gastos escritos a la contable; sin decimales ni símbolo, «(3)» no es dinero. */
  function parseMoney(raw) {
    let t = String(raw == null ? '' : raw).trim();
    t = t.replace(/[−–—]/g, '-');
    if (!t || t.length > 24) return null;
    let forced = 0;
    if (t[0] === '(' && t[t.length - 1] === ')' && /[$.,]/.test(t)) { t = t.slice(1, -1).trim(); forced = -1; }
    else if (t.length > 1 && t[t.length - 1] === '-' && /\d/.test(t[t.length - 2])) { t = t.slice(0, -1); forced = -1; }
    const m = MONEY.exec(t); if (!m) return null;
    const value = number((m[4] || '').trim()); if (value == null) return null;
    const mark = m[1] || m[3] || '';
    const marker = forced || (mark === '-' ? -1 : (mark === '+' ? 1 : 0));
    const sym = ((m[2] || '') + (m[5] || '')).toUpperCase();
    const cur = sym.indexOf('S/') === 0 || sym === 'PEN' ? 'PEN' : (sym ? 'USD' : '');
    return { value, marker, cur };
  }
  const isMoneyLike = (b) => parseMoney(b.text) != null;

  // ---------- Fechas ----------
  const MONTHS = {
    ene: 1, enero: 1, jan: 1, january: 1, feb: 2, febrero: 2, february: 2, mar: 3, marzo: 3, march: 3, abr: 4, abril: 4, apr: 4, april: 4, may: 5, mayo: 5,
    jun: 6, junio: 6, june: 6, jul: 7, julio: 7, july: 7, ago: 8, agosto: 8, aug: 8, august: 8, set: 9, sep: 9, sept: 9, setiembre: 9, septiembre: 9, september: 9,
    oct: 10, octubre: 10, october: 10, nov: 11, noviembre: 11, november: 11, dic: 12, diciembre: 12, dec: 12, december: 12,
  };
  const WEEKDAYS = {   // 0 = domingo
    domingo: 0, dom: 0, sunday: 0, sun: 0, lunes: 1, lun: 1, monday: 1, mon: 1, martes: 2, mar: 2, tuesday: 2, tue: 2, tues: 2,
    miercoles: 3, mie: 3, wednesday: 3, wed: 3, jueves: 4, jue: 4, thursday: 4, thu: 4, thur: 4, thurs: 4,
    viernes: 5, vie: 5, friday: 5, fri: 5, sabado: 6, sab: 6, saturday: 6, sat: 6,
  };
  const ISO = /\b(\d{4})-(\d{1,2})-(\d{1,2})\b/, NUMD = /\b(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2}|\d{4})\b/;
  const DM = /\b(\d{1,2})(?:st|nd|rd|th)?\s*(?:de\s+)?([a-z]{3,10})\.?(?:\s*(?:de\s+)?(\d{4}))?\b/g;
  const MD = /\b([a-z]{3,10})\.?\s+(\d{1,2})(?:st|nd|rd|th)?(?:,?\s*(\d{4}))?\b/g;
  const SLASH = /(?<![\d/.])(\d{1,2})\/(\d{1,2})(?![\d/])/;   // «10/23» o «23/10» sin año; solo con «/», porque «12.50» es un monto

  function fmt(y, m, d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    const dt = new Date(Date.UTC(y, m - 1, d));
    if (dt.getUTCFullYear() !== y || dt.getUTCMonth() !== m - 1 || dt.getUTCDate() !== d) return null;   // 31 de febrero, etc.
    return String(y).padStart(4, '0') + '-' + pad(m) + '-' + pad(d);
  }
  function ymd(iso) { const p = String(iso).split('-').map(Number); return p.length === 3 && p.every((n) => !isNaN(n)) ? p : null; }
  function addDays(iso, n) {
    const p = ymd(iso); if (!p) return null;
    const dt = new Date(Date.UTC(p[0], p[1] - 1, p[2] + n));
    return fmt(dt.getUTCFullYear(), dt.getUTCMonth() + 1, dt.getUTCDate());
  }
  /* Sin año: el más reciente que no quede en el futuro. */
  function inferYear(m, d, today) {
    const p = ymd(today); if (!p) return null;
    return (m * 100 + d) > (p[1] * 100 + p[2] + 1) ? p[0] - 1 : p[0];
  }

  /* Una fecha dentro de un texto: «12/10/2026», «12 oct», «23 de octubre», «Friday, October 23rd», «oct 12», «10/23», «Hoy», «Ayer», «Viernes». null si no hay. */
  function parseDate(raw, today) {
    const t = strip(raw).trim(); if (!t) return null;
    let g = ISO.exec(t);
    if (g) { const s = fmt(+g[1], +g[2], +g[3]); if (s) return s; }
    g = NUMD.exec(t);
    if (g) { const a = +g[1], b = +g[2]; let y = +g[3]; if (g[3].length === 2) y += 2000; const s = fmt(y, b, a) || fmt(y, a, b); if (s) return s; }   // día/mes y, si el mes no cabe, mes/día (EE. UU.)
    for (const m of t.matchAll(DM)) {   // pueden aparecer palabras que parecen fecha pero no son mes («5 items»): se prueba cada coincidencia
      const mo = MONTHS[m[2]]; if (!mo) continue;
      const y = m[3] ? +m[3] : inferYear(mo, +m[1], today); const s = y != null ? fmt(y, mo, +m[1]) : null; if (s) return s;
    }
    for (const m of t.matchAll(MD)) {
      const mo = MONTHS[m[1]]; if (!mo) continue;
      const y = m[3] ? +m[3] : inferYear(mo, +m[2], today); const s = y != null ? fmt(y, mo, +m[2]) : null; if (s) return s;
    }
    g = SLASH.exec(t);
    if (g) {
      const a = +g[1], b = +g[2];
      const dm = a <= 31 && b <= 12 ? (() => { const y = inferYear(b, a, today); return y != null ? fmt(y, b, a) : null; })() : null;   // día/mes
      const md = a <= 12 && b <= 31 ? (() => { const y = inferYear(a, b, today); return y != null ? fmt(y, a, b) : null; })() : null;   // mes/día
      // si caben las dos, día/mes (lo normal en Perú) salvo que caiga en el futuro y mes/día no: ahí manda el formato de EE. UU.
      const ty = String(today).slice(0, 4);
      if (dm && dm.indexOf(ty) === 0) return dm;
      if (md && md.indexOf(ty) === 0) return md;
      if (dm || md) return dm || md;
    }
    const words = t.split(/[^a-z]+/).filter(Boolean);
    if (words.indexOf('hoy') >= 0 || words.indexOf('today') >= 0) return today || null;
    if (words.indexOf('ayer') >= 0 || words.indexOf('yesterday') >= 0) return addDays(today, -1);
    // solo el día de la semana («Viernes», «Fri.»), como encabezado: el más reciente que no sea futuro. Un texto con más palabras puede ser un comercio.
    if (words.length === 1 && WEEKDAYS[words[0]] != null) {
      const p = ymd(today);
      if (p) { const wd = new Date(Date.UTC(p[0], p[1] - 1, p[2])).getUTCDay(); return addDays(today, -((wd - WEEKDAYS[words[0]] + 7) % 7)); }
    }
    return null;
  }

  // ---------- Líneas ----------
  function lines(boxes) {
    const sorted = boxes.filter((b) => String(b.text).trim()).slice().sort((a, b) => a.y - b.y);
    const out = [];
    for (const b of sorted) {
      const last = out[out.length - 1];
      if (last && Math.abs(last.y - b.y) < Math.max(0.004, Math.max(b.h, Math.max(...last.boxes.map((c) => c.h))) * 0.55)) {
        last.boxes.push(b); last.y = last.boxes.reduce((s, c) => s + c.y, 0) / last.boxes.length;
      } else out.push({ boxes: [b], y: b.y });
    }
    return out.map((l) => ({ boxes: l.boxes.slice().sort((a, b) => a.x - b.x), y: l.y }));
  }
  const tokens = (s) => new Set(strip(s).replace(/[^a-z0-9\s]/g, ' ').split(/\s+/).filter((w) => w.length >= 2));
  function overlap(example, text) {
    const a = tokens(example); if (!a.size) return 0;
    const b = tokens(text); let n = 0; a.forEach((w) => { if (b.has(w)) n++; });
    return n / a.size;
  }

  // ---------- Aprender ----------
  /* Busca el ejemplo en la captura: por monto y nombre; con `soft`, por monto y fecha (o solo monto si es el único así y no hay fecha). */
  function find(ex, ls, today, soft) {
    let best = null;
    const noDesc = !String(ex.desc || '').trim();
    let amountHits = 0;
    ls.forEach((l) => l.boxes.forEach((b) => { const m = parseMoney(b.text); if (m && Math.abs(m.value - Math.abs(ex.amount)) < 0.005) amountHits++; }));
    for (let li = 0; li < ls.length; li++) {
      for (const b of ls[li].boxes) {
        const m = parseMoney(b.text);
        if (!m || Math.abs(m.value - Math.abs(ex.amount)) >= 0.005) continue;
        let descDy = 0, descBox = null, score = noDesc ? 0.5 : 0;
        for (let dy = -2; dy <= 2; dy++) {
          const k = li + dy; if (k < 0 || k >= ls.length) continue;
          for (const c of ls[k].boxes) { if (c === b || isMoneyLike(c)) continue; const s = overlap(ex.desc, c.text); if (s > score) { score = s; descDy = dy; descBox = c; } }
        }
        let dateDy = null, header = false;
        if (ex.date) {
          outer: for (const dy of [0, -1, 1, -2, 2]) {
            const k = li + dy; if (k < 0 || k >= ls.length) continue;
            for (const c of ls[k].boxes) if (c !== b && parseDate(c.text, today) === ex.date) { dateDy = dy; break outer; }
          }
          for (let k = li - 1; k >= 0 && k >= li - 14; k--) {
            const l = ls[k];
            if (!l.boxes.some(isMoneyLike) && l.boxes.some((c) => parseDate(c.text, today) === ex.date)) { header = true; break; }
          }
        }
        if (soft) {
          // sin nombre parecido: vale si coinciden monto y fecha, o si es el único monto igual y el ejemplo no trae fecha
          const dateOK = !!ex.date && (dateDy != null || header);
          if (!(dateOK || (!ex.date && amountHits === 1))) continue;
          if (!best) best = { line: li, box: b, descDy: descBox ? descDy : 0, descBox, dateDy, header, score: 0.1, soft: true };
        } else {
          if (!noDesc && score < 0.34) continue;
          const f = { line: li, box: b, descDy, descBox, dateDy, header, score, soft: false };
          if (!best || f.score > best.score) best = f;
        }
      }
    }
    return best;
  }

  /* El nombre de un ejemplo hallado solo por monto y fecha: se supone que está a la izquierda del monto, en su misma línea. */
  function guessDesc(f, ls, today) {
    const g = Object.assign({}, f);
    const line = ls[f.line]; if (!line) return g;
    g.descDy = 0;
    g.descBox = line.boxes.find((c) => c !== f.box && !isMoneyLike(c) && parseDate(c.text, today) == null) || null;
    return g;
  }

  /* examples: [{desc, amount (negativo = gasto), date 'AAAA-MM-DD' o '', cur}] (1 o 2). → {ok:true, template} | {ok:false, error:'needTwo'|'notFound', index} */
  function learn(examples, boxes, today) {
    if (!examples.length) return { ok: false, error: 'needTwo' };
    const ls = lines(boxes);
    let found = []; const missing = [];
    examples.slice(0, 2).forEach((ex, i) => {
      const f = find(ex, ls, today, false) || find(ex, ls, today, true);
      if (f) found.push(f); else missing.push(i);
    });
    if (examples.length === 1) missing.push(1);          // una sola fila elegida: se aprende de ella y se marca como parcial
    if (missing.length >= 2) return { ok: false, error: 'notFound', index: missing[0] };
    const partial = missing.length > 0;                    // si solo uno apareció, se aprende con ese (con menos confianza) en vez de rendirse
    if (partial) found.push(found[0]);
    const softN = found.filter((f) => f.soft).length;
    if (softN === 1) {
      const si = found[0].soft ? 0 : 1, oi = 1 - si;
      found[si].descDy = found[oi].descDy;
      const k = found[si].line + found[oi].descDy;
      if (k >= 0 && k < ls.length) found[si].descBox = ls[k].boxes.find((c) => c !== found[si].box && !isMoneyLike(c) && parseDate(c.text, today) == null) || null;
    } else if (softN === 2) found = found.map((f) => guessDesc(f, ls, today));
    const a = found[0], b = found[1];
    let agree = 0, checks = 0;
    // columna del monto
    const rightGap = Math.abs(right(a.box) - right(b.box)), leftGap = Math.abs(a.box.x - b.box.x);
    const rightAligned = rightGap <= leftGap;
    const amountX = rightAligned ? (right(a.box) + right(b.box)) / 2 : (a.box.x + b.box.x) / 2;
    const tol = Math.max(partial ? 0.07 : 0.05, Math.min(rightAligned ? rightGap : leftGap, 0.2) * 1.5 + 0.03);
    checks += 1; if (Math.min(rightGap, leftGap) < 0.04) agree += 1;
    // descripción
    checks += 1; if (a.descDy === b.descDy) agree += 1;
    const descLeft = Math.min(a.descBox ? a.descBox.x : 1, b.descBox ? b.descBox.x : 1);
    // fecha: ¿está en el mismo lugar relativo en TODAS las filas con monto? Si no, es un encabezado que vale para varias filas.
    const coverage = (d) => {
      const rows = ls.map((l, i) => i).filter((i) => ls[i].boxes.some(isMoneyLike));
      if (!rows.length) return 0;
      const hit = rows.filter((i) => { const k = i + d; return k >= 0 && k < ls.length && ls[k].boxes.some((c) => parseDate(c.text, today) != null); }).length;
      return hit / rows.length;
    };
    let dateMode;
    if (a.dateDy != null && b.dateDy != null && a.dateDy === b.dateDy && !(a.header && b.header && coverage(a.dateDy) < 0.8)) { dateMode = { row: a.dateDy }; agree += 1; }
    else if (a.header && b.header) { dateMode = 'header'; agree += 1; }
    else if ((a.dateDy != null || b.dateDy != null) && !(a.header || b.header)) { dateMode = { row: a.dateDy != null ? a.dateDy : b.dateDy }; agree += 0.5; }
    else if (a.header || b.header) { dateMode = 'header'; agree += 0.5; }
    else dateMode = 'none';
    checks += 1;
    // signo
    const okEx = partial ? [examples[missing[0] === 0 && examples.length > 1 ? 1 : 0]] : examples.slice(0, 2);
    const sa = okEx[0].amount < 0 ? -1 : 1, sb = okEx[okEx.length - 1].amount < 0 ? -1 : 1;
    const ma = (parseMoney(a.box.text) || {}).marker || 0, mb = (parseMoney(b.box.text) || {}).marker || 0;
    let signMode;
    if (ma !== 0 || mb !== 0) {
      // sin marcador, el signo es el de los ejemplos que no lo traen; si todos lo traen, se supone ingreso
      const bare = [[ma, sa], [mb, sb]].filter((p) => p[0] === 0).map((p) => p[1]);
      signMode = { marker: bare.length ? bare[0] : 1 }; agree += 1;
    } else if (sa !== sb && a.box.tone && b.box.tone && a.box.tone !== b.box.tone) {
      signMode = { tone: { expense: sa < 0 ? a.box.tone : b.box.tone, income: sa < 0 ? b.box.tone : a.box.tone } }; agree += 1;
    } else if (sa === sb) { signMode = { fixed: sa }; agree += 0.5; }
    else { signMode = { fixed: sa }; }
    checks += 1;
    checks += 1; if (softN === 0) agree += 1;
    const cur = (examples[0].cur || '') || (examples.length > 1 ? examples[1].cur || '' : '');
    return { ok: true, template: {
      amountX, rightAligned, tol, descDy: a.descDy, descLeft, dateMode, signMode, cur,
      confidence: checks === 0 ? 0 : (agree / checks) * (partial ? 0.5 : 1), soft: softN > 0 ? softN : null, partial: partial ? true : null,
    } };
  }

  // ---------- Aplicar ----------
  /* → { template, items: [{line, date, desc, amount, cur}], flags } · flags: 'date' (a algún movimiento se le puso la fecha de hoy) · 'sign' (se adivinó el signo) */
  function extract(t, boxes, today) {
    const ls = lines(boxes), items = []; let usedToday = false, guessedSign = false, header = '';
    ls.forEach((line, li) => {
      if (!line.boxes.some(isMoneyLike)) { const d = line.boxes.map((c) => parseDate(c.text, today)).find((x) => x); if (d) header = d; }
      for (const b of line.boxes) {
        const m = parseMoney(b.text); if (!m) continue;
        const edge = t.rightAligned ? right(b) : b.x;
        if (Math.abs(edge - t.amountX) > t.tol || !(m.value > 0)) continue;
        // descripción
        const k = li + t.descDy, parts = [];
        if (k >= 0 && k < ls.length) {
          for (const c of ls[k].boxes) {
            if (c === b || isMoneyLike(c) || parseDate(c.text, today) != null) continue;
            if (t.descDy === 0 && c.x > b.x) continue;
            if (c.x + 0.05 < t.descLeft) continue;
            parts.push(String(c.text).trim());
          }
        }
        const desc = parts.join(' '); if (!desc) continue;
        // fecha
        let date = '';
        if (t.dateMode === 'header') date = header;
        else if (t.dateMode && typeof t.dateMode === 'object') {
          const j = li + t.dateMode.row;
          if (j >= 0 && j < ls.length) date = ls[j].boxes.map((c) => parseDate(c.text, today)).find((x) => x) || '';
          if (!date) date = header;          // sin fecha propia: la del encabezado de arriba, si lo hay
        }
        if (!date) { date = today; usedToday = true; }
        // signo
        let sign = 1; const sm = t.signMode;
        if (sm.marker != null) sign = m.marker !== 0 ? m.marker : sm.marker;
        else if (sm.tone) {
          if (b.tone === sm.tone.expense) sign = -1; else if (b.tone === sm.tone.income) sign = 1;
          else { sign = m.marker !== 0 ? m.marker : -1; guessedSign = true; }
        } else sign = m.marker !== 0 ? m.marker : sm.fixed;
        items.push({ line: items.length + 1, date, desc: desc.slice(0, 90), amount: sign * m.value, cur: m.cur || t.cur });
      }
    });
    const flags = []; if (usedToday) flags.push('date'); if (guessedSign) flags.push('sign');
    return { template: t, items, flags };
  }

  // ---------- Selección en la captura ----------
  /* Un trozo cuenta como «dentro» si el cuadro cubre más de la mitad de él: no hace falta ser exacto con el dedo. */
  function inRegion(b, r) {
    const ix = Math.max(0, Math.min(b.x + b.w, r.x + r.w) - Math.max(b.x, r.x)), iy = Math.max(0, Math.min(b.y + b.h, r.y + r.h) - Math.max(b.y, r.y));
    const area = b.w * b.h; return area > 0 && (ix * iy) / area >= 0.5;
  }
  /* Las filas con un monto dentro del cuadro, de arriba hacia abajo. */
  function picks(r, ls) {
    const out = [];
    ls.forEach((line, li) => {
      const b = line.boxes.find((c) => inRegion(c, r) && isMoneyLike(c)); if (!b) return;
      out.push({ li, box: b, money: parseMoney(b.text) });
    });
    return out;
  }
  /* Las franjas {y, h} de las filas que se ven dentro del cuadro (para iluminarlas mientras se arrastra). */
  function rows(r, boxes) {
    const ls = lines(boxes);
    return picks(r, ls).map((p) => {
      const bs = ls[p.li].boxes, top = Math.min(...bs.map((c) => c.y)), bottom = Math.max(...bs.map((c) => c.y + c.h));
      return { y: top, h: bottom - top };
    });
  }
  /* El cuadro que abarca todas las filas con monto de la captura (el atajo «toda la lista»). */
  function listRegion(boxes) {
    const rs = lines(boxes).filter((l) => l.boxes.some(isMoneyLike));
    if (!rs.length) return null;
    const f = rs[0], l = rs[rs.length - 1];
    const top = Math.max(0, Math.min(...f.boxes.map((c) => c.y)) - 0.004), bottom = Math.min(1, Math.max(...l.boxes.map((c) => c.y + c.h)) + 0.004);
    return { x: 0, y: top, w: 1, h: Math.max(0.01, bottom - top) };
  }
  /* De las filas encerradas saca uno o dos ejemplos: dos que se distingan por el signo si los hay, si no la primera y la última. El nombre sale de la
   * misma fila (o de la de arriba o abajo si va en otra línea); la fecha, de la fila o del encabezado de arriba. */
  function examples(r, boxes, today) {
    const ls = lines(boxes), ps = picks(r, ls);
    if (!ps.length) return [];
    const sign = (p) => (p.money.marker !== 0 ? p.money.marker : (p.box.tone ? p.box.tone : -1));
    const example = (p) => {
      const text = (k, leftOf) => (k < 0 || k >= ls.length ? '' : ls[k].boxes.filter((c) => c !== p.box && !isMoneyLike(c) && parseDate(c.text, today) == null && inRegion(c, r) && (!leftOf || c.x < p.box.x)).map((c) => String(c.text).trim()).join(' '));
      let desc = text(p.li, true); if (!desc) desc = text(p.li, false); if (!desc) desc = text(p.li - 1, false); if (!desc) desc = text(p.li + 1, false);
      let date = '';
      outer: for (const dy of [0, -1, 1, -2, 2]) {
        const k = p.li + dy; if (k < 0 || k >= ls.length) continue;
        for (const c of ls[k].boxes) if (c !== p.box && !isMoneyLike(c)) { const d = parseDate(c.text, today); if (d) { date = d; break outer; } }
      }
      if (!date) for (let k = p.li - 1; k >= 0 && k >= p.li - 14; k--) {
        const l = ls[k]; if (l.boxes.some(isMoneyLike)) continue;
        const d = l.boxes.map((c) => parseDate(c.text, today)).find((x) => x); if (d) { date = d; break; }
      }
      return { desc, amount: sign(p) * p.money.value, date, cur: p.money.cur };
    };
    const first = ps[0];
    if (ps.length === 1) return [example(first)];
    const other = ps.find((p) => sign(p) !== sign(first)) || ps[ps.length - 1];
    return [example(first), example(other)];
  }

  /* Instituciones que solo emiten tarjetas: una captura de ellas es de una tarjeta, no de una cuenta. */
  const CARD_ISSUERS = ['applecard', 'io', 'seen', 'tjx', 'milestone'];

  /* Arma el resultado con la forma que entiende impFromPdf. `opt`: { institution (id), name (nombre corto de esa institución), defaultCur, label }.
   * La institución solo NOMBRA la cuenta: el sello de banco verificado es de los lectores oficiales, no de una captura aprendida (bank: null). */
  function statement(x, opt) {
    opt = opt || {};
    let cur = x.template.cur || (x.items[0] && x.items[0].cur) || ''; if (!cur) cur = opt.defaultCur || '';
    const st = { id: 'captura', bank: null, kind: 'corriente', label: opt.label || 'Captura', name: '', cur, items: x.items, skipped: { unreadable: 0 }, check: null, period: null };
    if (opt.institution) {
      st.name = opt.name || opt.institution; st.label = st.name;
      if (CARD_ISSUERS.indexOf(opt.institution) >= 0) st.kind = 'tarjeta';
    }
    const ds = x.items.map((i) => i.date).filter(Boolean).sort();
    if (ds.length) st.period = { from: ds[0], to: ds[ds.length - 1] };
    return st;
  }

  return { parseMoney, number, parseDate, lines, learn, extract, examples, rows, listRegion, statement, CARD_ISSUERS };
})();
if (typeof module !== 'undefined' && module.exports) module.exports = NazcaEjemplo;
