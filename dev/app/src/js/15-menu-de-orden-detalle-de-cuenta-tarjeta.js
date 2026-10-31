/* ---------- Menú de orden ---------- */
function closeSortMenu() { const m = $('#sortmenu'); if (m) { m.classList.remove('in'); setTimeout(() => { m.remove(); }, 180); } const bk = $('#menuback'); if (bk) bk.remove(); }
function toggleSortMenu(btn, pf) {
  if ($('#sortmenu')) { closeSortMenu(); return; }
  if (!btn) return;
  const dv = deviceEl, d = dv.getBoundingClientRect(), r = btn.getBoundingClientRect(), k = d.width / dv.offsetWidth || 1;
  
  const bk = document.createElement('div'); bk.id = 'menuback'; bk.className = 'menuback'; bk.setAttribute('data-act', 'menuclose');
  const m = document.createElement('div'); m.id = 'sortmenu'; m.className = 'popmenu';
  const fill = () => { const cm = data.settings[pf + '_sort'] || 'name', cd = data.settings[pf + '_dir'] === 'desc' ? 'desc' : 'asc', ck = RMI('check-line', 18, '#22B573'), row = (act, key, on, t) => '<button class="pmi" data-act="' + act + ':' + pf + ':' + key + '"><span class="pck">' + (on ? ck : '') + '</span>' + t + '</button>'; m.innerHTML = [['name', 'Nombre'], ['amount', 'Monto'], ['due', 'Fecha de pago']].filter((it) => pf === 'card' || it[0] !== 'due').map((it) => row('asort', it[0], it[0] === cm, it[1])).join('') + '<div class="pmsep"></div>' + row('adir', 'asc', cd === 'asc', 'Ascendente') + row('adir', 'desc', cd === 'desc', 'Descendente') + '<div class="pmsep"></div>' + row('ahide', 'x', !!data.settings[pf + '_hide'], 'Ocultar sin uso').replace(':' + pf + ':x', ':' + pf); };
  if (pf === 'ring') { const fillR = () => { const rk = data.settings.ring_kind || 'all'; m.innerHTML = [['all', 'Tarjetas y préstamos'], ['card', 'Solo tarjetas'], ['loan', 'Solo préstamos']].map((it) => '<button class="pmi" data-act="ringk:' + it[0] + '"><span class="pck">' + (it[0] === rk ? RMI('check-line', 18, '#1C1C1E') : '') + '</span>' + it[1] + '</button>').join(''); }; window.__sortFill = fillR; fillR(); } else { window.__sortFill = fill; fill(); }
  dv.appendChild(bk); dv.appendChild(m);
  const top = (r.bottom - d.top) / k + 8, right = (d.right - r.right) / k;
  m.style.right = right + 'px'; const mh = m.offsetHeight || 220, devH = dv.offsetHeight; m.style.top = (top + mh > devH - 110 ? Math.max(70, (r.top - d.top) / k - mh - 8) : top) + 'px'; if (top + mh > devH - 110) m.style.transformOrigin = '100% 100%';
  requestAnimationFrame(() => m.classList.add('in'));
}
/* ---------- Detalle de cuenta / tarjeta ---------- */
function svGoal(sv, today) {
  const goal = sv.goal || 0, rem = Math.max(0, goal - sv.balance), done = goal > 0 && rem <= 0;
  const mo = goal > 0 && sv.monthly > 0 && rem > 0 ? Math.ceil(rem / sv.monthly) : 0;
  return { goal: goal, rem: rem, done: done, mo: mo, pct: goal > 0 ? Math.min(100, (sv.balance / goal) * 100) : 0 };
}
function svChart(sv, g, today) {
  if (!(sv.goal > 0)) return '<div class="empty">Define un monto objetivo para ver la proyección.</div>';
  if (g.done) return '<div class="empty">¡Vamos! Ya llegaste a ' + fmtC2(sv.goal, sv.cur) + '.</div>';
  if (!(sv.monthly > 0)) return '<div class="empty">Añade un aporte mensual para ver cuándo se llena.</div>';
  const W = 330, H = 190, L = 8, R = 8, T = 22, B = 34, n = Math.min(g.mo, 120), x1 = W - R, x0 = L, y0 = H - B, y1 = T;
  const X = (m) => x0 + ((x1 - x0) * m) / Math.max(1, n), Y = (v) => y0 - ((y0 - y1) * Math.min(v, sv.goal)) / sv.goal;
  const pts = []; for (let m = 0; m <= n; m++) pts.push([X(m), Y(sv.balance + sv.monthly * m)]);
  const line = pts.map((q) => q[0].toFixed(1) + ',' + q[1].toFixed(1)).join(' '), area = 'M' + pts.map((q) => q[0].toFixed(1) + ',' + q[1].toFixed(1)).join(' L') + ' L' + x1 + ',' + y0 + ' L' + x0 + ',' + y0 + ' Z';
  const last = pts[pts.length - 1], col = sv.color || '#1A9D63', hit = g.mo <= 120;
  const lab = hit ? monthYear(addMonths(today, g.mo)) : 'más de 10 años';
  return '<svg viewBox="0 0 ' + W + ' ' + H + '" style="width:100%;height:auto;font-family:inherit" role="img" aria-label="Proyección de la meta">' +
    '<defs><linearGradient id="svg_g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="' + col + '" stop-opacity=".30"/><stop offset="1" stop-color="' + col + '" stop-opacity="0"/></linearGradient></defs>' +
    '<line x1="' + x0 + '" y1="' + y1 + '" x2="' + x1 + '" y2="' + y1 + '" stroke="#8E8E93" stroke-dasharray="4 4"/>' +
    '<text x="' + x0 + '" y="' + (y1 - 7) + '" font-size="12" fill="#6C6C70">Meta ' + fmtC(sv.goal, sv.cur) + '</text>' +
    '<line x1="' + x0 + '" y1="' + y0 + '" x2="' + x1 + '" y2="' + y0 + '" stroke="#E5E5EA"/>' +
    '<path d="' + area + '" fill="url(#svg_g)"/>' +
    '<polyline points="' + line + '" fill="none" stroke="' + col + '" stroke-width="3.5" stroke-linejoin="round" stroke-linecap="round"/>' +
    '<circle cx="' + pts[0][0] + '" cy="' + pts[0][1] + '" r="5" fill="#fff" stroke="' + col + '" stroke-width="3"/>' +
    '<circle cx="' + last[0] + '" cy="' + last[1] + '" r="7" fill="' + col + '" stroke="#fff" stroke-width="3"/>' +
    '<text x="' + x0 + '" y="' + (H - 10) + '" font-size="12" fill="#6C6C70">Hoy</text>' +
    '<text x="' + x1 + '" y="' + (H - 10) + '" text-anchor="end" font-size="12" font-weight="600" fill="#1C1C1E">' + lab + '</text></svg>';
}
