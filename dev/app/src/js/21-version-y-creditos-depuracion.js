const APP_VERSION = 'Beta 5';
const WSOC = '<div class="wsoc"><span class="wver">' + APP_VERSION + '</span><a href="https://instagram.com/plataapp" target="_blank" rel="noopener" data-notr>' + RMI('instagram-line', 20, 'currentColor') + 'plataapp</a><a href="https://plataapp.net" target="_blank" rel="noopener" data-notr>' + RMI('link', 20, 'currentColor') + 'plataapp.net</a></div>';
const APP_BUILD = 502;
const ALPHA_TESTERS = ['Rodrigo Espinoza', 'Mariana Richarte', 'Jeny Surichaqui', 'Carlos Flores'];
const BETA_TESTERS = ['Bastián Guajardo', 'Sara Rondón']; // los testers de la beta se añaden aquí
const E22_LOGO = 'data:image/svg+xml,%3Csvg xmlns=%27http://www.w3.org/2000/svg%27 viewBox=%270 0 1900.3 316.3%27%3E%3Cg fill=%27%233C3C43%27 fill-opacity=%27.6%27%3E%3Cpath d=%27M0,311.8V4.1h205.9v52.2H63v74.3h132.2v51.4H63v77.4h143.3v52.2H0Z%27/%3E%3Cpath d=%27M315.1,316.3c-24.6,0-46.1-3.8-64.3-11.4-18.2-7.6-32.5-18.8-42.6-33.7-10.2-14.9-15.6-33.2-16.1-54.9h61.3c.8,10.3,3.9,19,9.3,25.9,5.4,7,12.5,12.2,21.5,15.6,8.9,3.4,19.1,5.2,30.4,5.2s21.1-1.6,29.4-4.9c8.3-3.2,14.8-7.8,19.5-13.7,4.7-5.9,7-12.8,7-20.6s-2.1-12.9-6.3-17.7c-4.2-4.7-10.2-8.8-18.1-12.3-7.8-3.4-17.4-6.5-28.7-9.1l-33.9-8.5c-26-6.3-46.4-16.3-61.1-29.8-14.7-13.6-22.1-31.5-22.1-53.8s5-34.8,15-48.7c10-13.9,23.7-24.7,41.1-32.4,17.4-7.7,37.3-11.6,59.6-11.6s42.5,3.9,59.5,11.7c16.9,7.8,30.1,18.6,39.6,32.4,9.5,13.8,14.4,29.8,14.7,47.8h-60.9c-1.1-12.4-6.4-22-15.8-28.7-9.4-6.7-22-10.1-37.7-10.1s-19.7,1.5-27.3,4.5c-7.6,3-13.3,7.2-17.2,12.6-3.9,5.4-5.9,11.5-5.9,18.4s2.3,13.9,6.8,18.9c4.5,5,10.6,9.1,18.2,12.2,7.6,3.1,15.6,5.7,24.2,7.7l27.9,6.8c12.9,2.9,25,6.8,36.1,11.8,11.2,5,20.9,11,29.3,18.3,8.4,7.2,14.9,15.8,19.5,25.7,4.6,9.9,6.9,21.3,6.9,34.3,0,18.6-4.7,34.8-14,48.6-9.4,13.8-22.9,24.5-40.7,32.1-17.8,7.6-39.1,11.4-64,11.4Z%27/%3E%3Cpath d=%27M409.2,56.4V4.1h251.3v52.2h-94v255.4h-63.2V56.4h-94.2Z%27/%3E%3Cpath d=%27M776.1,316.1c-25.3,0-47.5-4.7-66.6-14.1-19.1-9.4-33.9-22.5-44.4-39.3-10.5-16.8-15.8-36.4-15.8-58.8V4.1h63v194.5c0,12,2.6,22.6,8,31.9,5.3,9.3,12.7,16.6,22.3,21.9,9.6,5.3,20.8,7.9,33.6,7.9s24.2-2.6,33.8-7.9c9.6-5.3,17-12.6,22.3-21.9,5.3-9.3,8-19.9,8-31.9V4.1h63.2v199.7c0,22.4-5.3,42.1-15.9,58.8-10.6,16.8-25.4,29.9-44.5,39.3-19.1,9.4-41.3,14.1-66.8,14.1Z%27/%3E%3Cpath d=%27M967.2,4.1v307.7h-63V4.1h63ZM1012.4,311.8h-79.7v-54.3h76.6c19.8,0,36.4-3.5,49.9-10.5,13.4-7,23.5-17.9,30.3-32.6,6.7-14.7,10.1-33.6,10.1-56.6s-3.4-41.6-10.2-56.3c-6.8-14.7-16.9-25.5-30.1-32.5-13.3-7-29.8-10.5-49.5-10.5h-78.5V4.1h82.2c30.8,0,57.4,6.2,79.6,18.5,22.2,12.3,39.3,29.9,51.3,52.9s18,50.4,18,82.3-6,59.6-18,82.6c-12,23-29.2,40.6-51.5,53-22.4,12.3-49.2,18.5-80.4,18.5Z%27/%3E%3Cpath d=%27M1218.1,4.1v307.7h-63V4.1h63Z%27/%3E%3Cpath d=%27M1354.3,315.9c-27.1,0-51.5-6.2-73.2-18.6-21.7-12.4-38.8-30.4-51.4-53.9s-18.9-52-18.9-85.3,6.3-62,18.9-85.6c12.6-23.6,29.7-41.6,51.4-54,21.7-12.4,46.1-18.6,73.2-18.6s51.7,6.2,73.3,18.6c21.6,12.4,38.7,30.4,51.3,54,12.6,23.6,18.9,52.1,18.9,85.6s-6.3,61.7-18.9,85.3-29.7,41.5-51.3,53.9c-21.6,12.4-46,18.6-73.3,18.6ZM1354.3,260c16,0,29.9-3.9,41.8-11.7,11.9-7.8,21.2-19.3,27.8-34.5,6.6-15.2,9.9-33.8,9.9-55.6s-3.3-40.8-9.9-56.1c-6.6-15.2-15.9-26.7-27.8-34.5-11.9-7.8-25.8-11.7-41.8-11.7s-29.7,3.9-41.7,11.8c-12,7.8-21.3,19.4-27.9,34.6-6.6,15.2-9.9,33.8-9.9,55.9s3.3,40.4,9.9,55.5c6.6,15.1,15.9,26.6,27.9,34.5,12,7.8,25.9,11.8,41.7,11.8Z%27/%3E%3Cpath d=%27M1533.9,311.8v-45.4l109-102.2c9.4-9.1,17.2-17.3,23.6-24.7,6.4-7.4,11.3-14.6,14.7-21.7,3.4-7.1,5.1-14.8,5.1-23s-2.1-17.1-6.2-23.7c-4.1-6.6-9.8-11.7-16.9-15.3-7.2-3.6-15.4-5.4-24.6-5.4s-17.8,1.9-25,5.8c-7.2,3.9-12.7,9.4-16.5,16.5-3.9,7.2-5.8,15.8-5.8,25.8h-60.3c0-20,4.6-37.3,13.7-52.1,9.2-14.8,21.9-26.2,38.1-34.3,16.2-8.1,35-12.1,56.2-12.1s40.7,3.9,57,11.7c16.2,7.8,28.9,18.5,37.9,32.1,9,13.6,13.5,29.3,13.5,47.1s-2.2,22.7-6.7,33.9c-4.5,11.2-12.5,23.6-24,37.5-11.5,13.8-27.8,30.4-48.8,49.7l-46.5,45.8v2.3h130.1v51.8h-217.6Z%27/%3E%3Cpath d=%27M1755.5,207.4v-30.2l72.5-68c6.2-6,11.5-11.5,15.7-16.4,4.3-4.9,7.5-9.7,9.7-14.4,2.2-4.7,3.4-9.8,3.4-15.3s-1.4-11.4-4.1-15.8c-2.7-4.4-6.5-7.8-11.3-10.2-4.8-2.4-10.2-3.6-16.3-3.6s-11.9,1.3-16.6,3.8c-4.8,2.6-8.4,6.2-11,11-2.6,4.8-3.8,10.5-3.8,17.2h-40.1c0-13.3,3-24.8,9.1-34.7,6.1-9.8,14.5-17.4,25.3-22.8,10.8-5.4,23.3-8,37.4-8s27.1,2.6,37.9,7.8c10.8,5.2,19.2,12.3,25.2,21.4,6,9.1,9,19.5,9,31.3s-1.5,15.1-4.5,22.5c-3,7.4-8.3,15.7-15.9,24.9-7.6,9.2-18.5,20.2-32.5,33l-30.9,30.5v1.5h86.5v34.5h-144.7Z%27/%3E%3C/g%3E%3C/svg%3E';
function dbgViewHTML() {
  let fv = ''; try { fv = localStorage.getItem('plata.view') || ''; } catch (e) { /* sin almacenamiento */ }
  const opt = (k, l) => '<button class="linkrow" data-act="dbgview:' + k + '" style="width:100%;' + (k === 'auto' ? '' : 'border-top:1px solid var(--line);') + '"><span class="grow" style="text-align:left">' + l + '</span>' + ((fv || 'auto') === k ? '<b style="color:#22B573">✓</b>' : '') + '</button>';
  return '<div class="sub" style="padding:14px 6px 6px;text-transform:uppercase;font-size:12px;letter-spacing:.5px">Debug · Vista</div><div class="scard">' + opt('auto', 'Automática (según el ancho)') + opt('desktop', 'Forzar escritorio') + opt('mobile', 'Forzar móvil') + '</div>' + platHTML();
}
function platHTML() {
  let pf = ''; try { pf = localStorage.getItem('plata.platform') || ''; } catch (e) { /* sin almacenamiento */ }
  const opt = (k, l) => '<button class="linkrow" data-act="dbgplat:' + k + '" style="width:100%;' + (k === 'auto' ? '' : 'border-top:1px solid var(--line);') + '"><span class="grow" style="text-align:left">' + l + '</span>' + ((pf || 'auto') === k ? '<b style="color:#22B573">✓</b>' : '') + '</button>';
  return '<div class="sub" style="padding:14px 6px 6px;text-transform:uppercase;font-size:12px;letter-spacing:.5px">Debug · Plataforma</div><div class="scard">' + opt('auto', 'Automática (según el dispositivo)') + opt('android', 'Forzar Android') + opt('ios', 'Forzar iPhone') + '</div>';
}
function dbgExtraHTML() {
  const T = (t) => '<div class="sub" style="padding:14px 6px 6px;text-transform:uppercase;font-size:12px;letter-spacing:.5px">' + t + '</div>', cur = langPref(), tp = window.__themePref();
  const th = T('Debug · Apariencia') + '<div class="scard"><div style="padding:12px 14px;display:flex;gap:6px">' + [['auto', 'Auto'], ['light', 'Claro'], ['dark', 'Oscuro']].map((t) => '<button data-act="dbgtheme:' + t[0] + '" style="flex:1;height:38px;border-radius:999px;font-size:15px;font-weight:600;' + (tp === t[0] ? 'background:#22B573;color:#fff' : 'background:var(--fill, rgba(120,120,128,.16));color:var(--ink)') + '">' + t[1] + '</button>').join('') + '</div></div>';
  const lg = T('Debug · Idioma') + '<div class="scard">' + LANG_LIST.map((x, i) => '<button class="linkrow" data-act="dbglang:' + x[0] + '" style="width:100%;' + (i ? 'border-top:1px solid var(--line);' : '') + '"><span class="grow" style="text-align:left">' + x[1] + '</span>' + (cur === x[0] ? '<b style="color:#22B573">✓</b>' : '') + '</button>').join('') + '</div>';
  return th + lg + '<div class="scard" style="margin-top:14px">' + wDebugGradesHTML() + '</div>';
}
function dbgListHTML() {
  return dbgViewHTML() + dbgExtraHTML() + '<div class="sub" style="padding:14px 6px 6px;text-transform:uppercase;font-size:12px;letter-spacing:.5px">Debug · Perfiles por calificación</div><div class="scard">' +
    ['S', 'A', 'B', 'C', 'D', 'F', 'H', 'X'].map((g, i) => '<button class="linkrow" data-act="dbg:' + g + '" style="width:100%;' + (i ? 'border-top:1px solid var(--line);' : '') + '"><b data-notr style="width:22px;color:#6D8BEA">' + (g === 'X' ? '?' : g === 'H' ? '½' : g) + '</b>' + DBG[g].nick + (g === 'X' ? ' · sin datos suficientes' : g === 'H' ? ' <span class="sub">half‑time</span>' : '') + '</button>').join('') + '</div>';
}
function creditsHTML() {
  const role = (n, r) => '<div class="row" style="border:0"><div class="grow"><div class="name" style="font-size:17px">' + n + '</div><div class="sub" style="font-size:14px;margin-top:1px">' + r + '</div></div></div>';
  const tcard = (L) => '<div class="card" style="padding-top:6px;padding-bottom:6px">' + (L.length
    ? (L.length > 8 ? '<div style="display:grid;grid-template-columns:1fr 1fr;gap:10px 14px;padding:6px 2px">' + L.map((n) => '<div style="font-size:16px">' + esc(n) + '</div>').join('') + '</div>'
            : L.map((n, i) => '<div class="row" style="' + (i ? 'border-top:1px solid var(--line);' : 'border:0;') + 'padding:12px 0"><div class="grow" style="font-size:17px">' + esc(n) + '</div></div>').join(''))
    : '<div class="empty">Pronto</div>') + '</div>';
  return '<div class="card" style="padding-top:6px;padding-bottom:6px">' + role('Leonardo Richarte', 'Director creativo, diseño de UI y concepto') + '<div class="hr" style="margin:0"></div>' + role('Claude', 'Asistente de programación').replace('<div class="row" ', '<div class="row" data-act="cldbg" ') + '</div>' +
    '<div style="display:flex;gap:8px;align-items:center;padding:4px 10px 8px"><span style="flex:none;display:flex;opacity:.7">' + ICON.info + '</span><div class="sub" style="font-size:13px;line-height:1.35">El uso de IA fue limitado a la programación de la aplicación.</div></div>' +
    secHead('Recursos') + '<div class="card" style="padding-top:6px;padding-bottom:6px">' + role('Remix Icon', 'Biblioteca principal de íconos de Plata · remixicon.com') + '</div>' +
    secHead('Testers de la alpha') + tcard(ALPHA_TESTERS) + secHead('Testers de la beta') + tcard(BETA_TESTERS) +
    '<div class="scard" style="margin-top:18px"><button class="linkrow" data-act="dbgmenu" style="width:100%"><span class="grow" style="text-align:left">Debug</span><span style="display:inline-flex;transition:transform .2s;transform:rotate(' + (ui.dbgOpen ? 90 : 0) + 'deg)">' + ICON.chev + '</span></button></div>' + (ui.dbgOpen ? dbgListHTML() : '') +
    '<button class="tap" data-act="history" style="display:block;width:100%;background:none;text-align:center;padding:22px 0 6px"><div class="sub" style="font-size:13px">Plata · ' + APP_VERSION + '<div style="margin-top:2px">Compilación ' + APP_BUILD + '</div><div style="margin-top:2px">' + (document.documentElement.classList.contains('tauri-win') ? 'Windows' : document.documentElement.classList.contains('web') ? 'Desktop' : 'Móvil') + '</div></div></button>';
}

const AVATAR_DEF = ['#C9CFDD', '#98A2BA', '#5A6482', '#E1E6F2'];
function avatarInfo() { try { if (!insOn() || !scoreOn()) return null; const m = insightsModel(prevMkOf(iso(getToday()).slice(0, 7))); return !insLocked(m) && GRAD[m.letter] ? { g: m.plus ? tierG(m.letter, m.plus) : GRAD[m.letter], letter: m.plus === 'd' ? 'S*' : tL(m.letter, m.plus) } : null; } catch (e) { return null; } }
function avatarGrad() { const a = avatarInfo(); return a ? a.g : AVATAR_DEF; }
function avatarPhoto() { const p = (data && data.settings && data.settings.photo) || ''; return /^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+\/=]+$/.test(p) ? p : ''; }
function letterLayer(L, fs, y0) { return svgU('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><text x="50" y="' + (y0 + fs * 0.36) + '" text-anchor="middle" font-family="-apple-system,BlinkMacSystemFont,Helvetica,Arial,sans-serif" font-weight="800" font-size="' + fs + '" letter-spacing="-1" fill="#000">' + L.replace(/[&<>]/g, '') + '</text></svg>') + ' center/100% 100% no-repeat'; }
const TRI = (sw) => '<polygon points="19,25 81,25 50,73" fill="#000" stroke="#000" stroke-width="' + sw + '" stroke-linejoin="round"/>';
function letterCut(L, dia, full, sq, tri) {
  if (tri) { const top = letterLayer(L, L.length > 1 ? 38 : 48, 47), base = svgU('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">' + TRI(26) + '</svg>') + ' center/100% 100% no-repeat'; return '-webkit-mask:' + top + ',' + base + ';-webkit-mask-composite:xor;mask:' + top + ',' + base + ';mask-composite:exclude'; }
  const fs = dia ? (full ? (L.length > 1 ? 42 : 54) : (L.length > 1 ? 37 : 50)) : sq ? (L.length > 1 ? 44 : 56) : (L.length > 1 ? 50 : 64), top = letterLayer(L, fs, 50);
  const base = dia ? svgU('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">' + (full ? '<rect x="10.7" y="10.7" width="78.6" height="78.6" rx="16"' : '<rect x="19" y="19" width="62" height="62" rx="14"') + ' transform="rotate(45 50 50)" fill="#000"/></svg>') + ' center/100% 100% no-repeat' : 'linear-gradient(#000,#000)';
  return '-webkit-mask:' + top + ',' + base + ';-webkit-mask-composite:xor;mask:' + top + ',' + base + ';mask-composite:exclude';
}
function avatarHTML(sz, photo, nobadge, cut) {
  if (cut === undefined) cut = true;
  const ph = photo === undefined ? avatarPhoto() : photo;
  if (!ph) return '<span style="position:relative;overflow:hidden;flex:none;width:' + sz + 'px;height:' + sz + 'px;border-radius:50%;background:' + insBg(avatarGrad()) + ';display:flex;align-items:center;justify-content:center" aria-hidden="true">' + RMI('user-fill', Math.round(sz * 0.6), '#fff') + '</span>';
  const a = avatarInfo();
  if (!a) return '<span style="display:inline-block;flex:none;width:' + sz + 'px;height:' + sz + 'px;border-radius:50%;background:var(--fill) url(' + ph + ') center/cover no-repeat" aria-hidden="true"></span>';
  const g = a.g, rw = Math.max(2, Math.round(sz * 0.055)), bs = Math.round(sz * 0.38), bw = Math.max(2, Math.round(sz * 0.035)), off = Math.round(bs * 0.12), bc = sz + off - bs / 2, cr = bs / 2 + bw;
  const gem = !!(cut && !nobadge && a.letter === 'S*'), dia = !!(cut && !nobadge && /^[SABC]\+$/.test(a.letter)), tri = !!(cut && !nobadge && /^[DF]-$/.test(a.letter)), box = bs * (gem ? 1.55 : tri ? 1.32 : 1.42), dw = box * 0.62, dr = box * 0.14;
  const dcut = dia ? svgU('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + sz + ' ' + sz + '" width="' + sz + '" height="' + sz + '"><rect x="' + (bc - dw / 2 - bw) + '" y="' + (bc - dw / 2 - bw) + '" width="' + (dw + 2 * bw) + '" height="' + (dw + 2 * bw) + '" rx="' + (dr + bw) + '" transform="rotate(45 ' + bc + ' ' + bc + ')" fill="#000"/></svg>') + ' 0 0/' + sz + 'px ' + sz + 'px no-repeat' : '';
  const tcut = tri ? svgU('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + sz + ' ' + sz + '" width="' + sz + '" height="' + sz + '"><g transform="translate(' + (bc - box / 2) + ' ' + (bc - box / 2) + ') scale(' + (box / 100) + ')">' + TRI(26 + 2 * bw * 100 / box) + '</g></svg>') + ' 0 0/' + sz + 'px ' + sz + 'px no-repeat' : '';
  const gcut = gem ? svgU('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + sz + ' ' + sz + '" width="' + sz + '" height="' + sz + '"><g transform="translate(' + (bc - box / 2) + ' ' + (bc - box / 2) + ') scale(' + (box / 100) + ')">' + GEM(16 + 2 * (bw + 0.5) * 100 / box) + '</g></svg>') + ' 0 0/' + sz + 'px ' + sz + 'px no-repeat' : '';
  const mk = gem ? ';-webkit-mask:' + gcut + ',linear-gradient(#000,#000);-webkit-mask-composite:xor;mask:' + gcut + ',linear-gradient(#000,#000);mask-composite:exclude' : tri ? ';-webkit-mask:' + tcut + ',linear-gradient(#000,#000);-webkit-mask-composite:xor;mask:' + tcut + ',linear-gradient(#000,#000);mask-composite:exclude' : dia ? ';-webkit-mask:' + dcut + ',linear-gradient(#000,#000);-webkit-mask-composite:xor;mask:' + dcut + ',linear-gradient(#000,#000);mask-composite:exclude' : cut && !nobadge ? ';-webkit-mask:radial-gradient(circle at ' + bc + 'px ' + bc + 'px,transparent ' + cr + 'px,#000 ' + (cr + 0.6) + 'px);mask:radial-gradient(circle at ' + bc + 'px ' + bc + 'px,transparent ' + cr + 'px,#000 ' + (cr + 0.6) + 'px)' : '';
  return '<span style="position:relative;flex:none;display:inline-block;width:' + sz + 'px;height:' + sz + 'px" aria-hidden="true">' +
    '<span style="position:absolute;inset:0' + mk + '">' +
    '<span style="position:absolute;inset:0;border-radius:50%;background:' + insBg(g) + (cut ? ';-webkit-mask:radial-gradient(circle,transparent ' + (sz / 2 - rw) + 'px,#000 ' + (sz / 2 - rw + 0.6) + 'px);mask:radial-gradient(circle,transparent ' + (sz / 2 - rw) + 'px,#000 ' + (sz / 2 - rw + 0.6) + 'px)' : '') + '"></span>' +
    (cut ? '' : '<span style="position:absolute;inset:' + rw + 'px;border-radius:50%;background:var(--card)"></span>') +
    '<span style="position:absolute;inset:' + (rw + (cut ? bw : 2)) + 'px;border-radius:50%;background:var(--fill) url(' + ph + ') center/cover no-repeat"></span>' +
    '</span>' +
    (a && !nobadge ? (cut ? (gem ? '<span style="position:absolute;left:' + (bc - box / 2) + 'px;top:' + (bc - box / 2) + 'px">' + gemHTML(box, g) + '</span>' : tri ? '<span data-notr style="position:absolute;left:' + (bc - box / 2) + 'px;top:' + (bc - box / 2) + 'px;width:' + box + 'px;height:' + box + 'px;background:' + insBg(g) + ';' + letterCut(a.letter, false, false, false, true) + '"></span>' : dia ? '<span data-notr style="position:absolute;left:' + (bc - box / 2) + 'px;top:' + (bc - box / 2) + 'px;width:' + box + 'px;height:' + box + 'px;background:' + insBg(g) + ';' + letterCut(a.letter, true) + '"></span>' : '<span data-notr style="position:absolute;right:-' + off + 'px;bottom:-' + off + 'px;width:' + bs + 'px;height:' + bs + 'px;border-radius:50%;background:' + insBg(g) + ';' + letterCut(a.letter) + '"></span>') : '<span data-notr style="position:absolute;right:-' + off + 'px;bottom:-' + off + 'px;width:' + bs + 'px;height:' + bs + 'px;border-radius:50%;background:' + insBg(g) + ';border:' + bw + 'px solid #fff;box-sizing:border-box;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:800;font-size:' + Math.round(bs * (a.letter.length > 1 ? 0.4 : 0.52)) + 'px;letter-spacing:-.5px;text-shadow:0 1px 2px rgba(0,0,0,.3)">' + a.letter + '</span>') : '') + '</span>';
}
function gradeCounts() {
  if (!scoreOn()) return [];
  const cmk = iso(getToday()).slice(0, 7), ks = {}, cnt = {};
  data.transactions.forEach((t) => { const k = t.date.slice(0, 7); if (k < cmk) ks[k] = 1; });
  Object.keys(ks).forEach((k) => { const s = monthScore(k); if (s && s.letter) cnt[s.letter] = (cnt[s.letter] || 0) + 1; });
  return ['S', 'A', 'B', 'C', 'D', 'F'].filter((l) => cnt[l]).map((l) => [l, cnt[l]]);
}
const gradesShown = () => (data.settings || {}).showGrades !== false;
function photoRowHTML(has) {
  return '<div style="display:flex;flex-direction:column;align-items:center;gap:8px;padding:6px 0 14px"><button data-act="' + (has && photoSrc() ? 'cropphoto' : 'pickphoto') + '" aria-label="Foto de perfil" style="padding:0">' + avatarHTML(128, undefined, false, true) + '</button>' +
    '<div style="display:flex;gap:18px"><button class="linkrow" data-act="pickphoto" style="padding:0;border:0;font-size:15px;color:#22B573">' + (has ? 'Cambiar foto' : 'Añadir foto') + '</button>' + (has ? '<button class="linkrow" data-act="rmphoto" style="padding:0;border:0;font-size:15px;color:var(--rt)">Quitar</button>' : '') + '</div></div>';
}
function goldGrade() {
  const a = avatarInfo(); if (!a) return null;
  const L = a.letter;
  if (L === 'S*') return { l: 'S', pal: DIAM, ink: '#4A7FD6', cfg: LAU.D, gem: true };
  if (/^[SA]\+$/.test(L)) return { l: L[0], pal: CHAMP, ink: '#A47E3A', cfg: LAU[L] };
  if (/^[BC]\+$/.test(L)) return { l: L[0], pal: PLAT, ink: '#6B7586', cfg: LAU[L] };
  return null;
}
const LAU = { D: { n: 7, a0: 68, a1: 6, L: 25, W: 6.8 }, 'S+': { n: 7, a0: 68, a1: 6, L: 25, W: 6.8 }, 'A+': { n: 5, a0: 65, a1: 6, L: 27, W: 7.4 }, 'B+': { n: 4, a0: 61, a1: 6, L: 23, W: 6 }, 'C+': { n: 3, a0: 60, a1: 22, L: 21, W: 5.4 }, S: { n: 3, a0: 62, a1: 36, L: 18, W: 4.6 } };
function laurelSVG(sz, pal, cfg, hole) {
  const c = sz / 2, r = c - 11, out = [], N = cfg.n, L = cfg.L, W = cfg.W;
  [1, -1].forEach((side) => {
    for (let i = 0; i < N; i++) {
      const A = N > 1 ? cfg.a0 + (cfg.a1 - cfg.a0) * i / (N - 1) : cfg.a0, a = A * Math.PI / 180, k = 1 - i * 0.04;
      const x = c + side * r * Math.cos(a), y = c + r * Math.sin(a);
      const tx = side * Math.sin(a), ty = -Math.cos(a), nx = side * Math.cos(a), ny = Math.sin(a), t = 32 * Math.PI / 180;
      const dx = tx * Math.cos(t) + nx * Math.sin(t), dy = ty * Math.cos(t) + ny * Math.sin(t), rot = Math.atan2(dy, dx) * 180 / Math.PI;
      const f = rot * Math.PI / 180, co = Math.cos(f), si = Math.sin(f), P = (u, v) => (x + (u * co - v * si) * k).toFixed(1) + ' ' + (y + (u * si + v * co) * k).toFixed(1);
      out.push('<path d="M' + P(-L / 2, 0) + ' Q' + P(0, -W) + ' ' + P(L / 2, 0) + ' Q' + P(0, W) + ' ' + P(-L / 2, 0) + 'Z" fill="url(#lg)"/>');
    }
  });
  if (cfg.berry) [1, -1].forEach((side) => { for (let i = 0; i < N - 1; i++) { const A = cfg.a0 + (cfg.a1 - cfg.a0) * (i + 0.5) / (N - 1), a = A * Math.PI / 180, rr = r + 11; out.push('<circle cx="' + (c + side * rr * Math.cos(a)).toFixed(1) + '" cy="' + (c + rr * Math.sin(a)).toFixed(1) + '" r="3.3" fill="url(#lg)"/>'); } });
  const mid = 'lm' + Math.random().toString(36).slice(2, 7), gap = 4.5;
  let hm = '';
  if (hole) { const hw = hole.px / 2 + gap; hm = '<mask id="' + mid + '"><rect width="' + sz + '" height="' + sz + '" fill="#fff"/>' + (hole.kind === 'g' ? '<g transform="translate(' + (c - hole.px / 2) + ' ' + (hole.cy - hole.px / 2) + ') scale(' + (hole.px / 100) + ')">' + GEM(16 + 2 * gap * 100 / hole.px) + '</g>' : hole.kind === 'd' ? '<rect x="' + (c - hole.px * 0.393 - gap) + '" y="' + (hole.cy - hole.px * 0.393 - gap) + '" width="' + (hole.px * 0.786 + 2 * gap) + '" height="' + (hole.px * 0.786 + 2 * gap) + '" rx="' + (hole.px * 0.16 + gap) + '" transform="rotate(45 ' + c + ' ' + hole.cy + ')" fill="#000"/>' : '<circle cx="' + c + '" cy="' + hole.cy + '" r="' + hw + '" fill="#000"/>') + '</mask>'; }
  return '<svg width="' + sz + '" height="' + sz + '" viewBox="0 0 ' + sz + ' ' + sz + '" style="position:absolute;inset:0;pointer-events:none;overflow:visible"><defs><linearGradient id="lg" gradientUnits="userSpaceOnUse" x1="0" y1="' + (c - 64) + '" x2="0" y2="' + (c + 64) + '"><stop offset="0" stop-color="' + pal[0] + '"/><stop offset=".5" stop-color="' + pal[1] + '"/><stop offset="1" stop-color="' + pal[2] + '"/></linearGradient>' + hm + '</defs><g' + (hole ? ' mask="url(#' + mid + ')"' : '') + '>' + out.join('') + '</g></svg>';
}
function gradeBadge(L, g, px, style) {
  if (L === 'S*') return gemHTML(px * GEMK, DIAM);
  const dm = /^[SABC]\+$/.test(L), tr = /^[DF]-$/.test(L), k = dm ? DMK : tr ? TRK : 1, bx = Math.round(px * k), cm = dm ? letterCut(L, true, true) : tr ? letterCut(L, false, false, false, true) : letterCut(L);
  return '<span role="img" aria-label="' + L + '" style="display:block;flex:none;width:' + bx + 'px;height:' + bx + 'px;border-radius:' + (dm || tr ? 0 : 50) + '%;background:' + insBg(g) + ';' + cm + (style || '') + '"></span>';
}
function profileViewHTML() {
  const st = data.settings || {}, nm = [(st.first || '').trim(), (st.last || '').trim()].filter(Boolean).join(' ');
  const gc = gradesShown() ? gradeCounts() : [];
  const gr = gc.length ? '<div style="display:flex;justify-content:center;flex-wrap:wrap;gap:8px 18px;padding:12px 0 2px">' + gc.map((g) => '<div style="display:flex;align-items:center;gap:8px">' + scoreTile(g[0], 28) + '<span style="font-size:17px;font-weight:600;color:var(--ink)">' + g[1] + '</span></div>').join('') + '</div>' : '';
  let gg = goldGrade(); const av = gg ? null : avatarInfo();
  const sg = !gg && av && av.letter === 'S';
  const pic = (gg || sg)
    ? (() => { const gem = !!(gg && gg.gem) || (!gg && av.letter === 'S*'), dm = !gem && (!!gg || /^[SABC]\+$/.test(av.letter)), bp = gem ? 34 * GEMK : dm ? 34 * DMK : 34, hs = dm ? bp * 0.786 : bp, gp = 4, cy = 152, ac = cy - 24, hole = gem ? '<g transform="translate(' + (64 - bp / 2) + ' ' + (ac - bp / 2) + ') scale(' + (bp / 100) + ')">' + GEM(16 + 2 * (gp + 0.5) * 100 / bp) + '</g>' : dm ? '<rect x="' + (64 - hs / 2 - gp) + '" y="' + (ac - hs / 2 - gp) + '" width="' + (hs + 2 * gp) + '" height="' + (hs + 2 * gp) + '" rx="' + (bp * 0.16 + gp) + '" transform="rotate(45 64 ' + ac + ')" fill="#000"/>' : '<circle cx="64" cy="' + ac + '" r="' + (bp / 2 + gp) + '" fill="#000"/>', hm = svgU('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128">' + hole + '</svg>') + ' 0 0/128px 128px no-repeat', mk = '-webkit-mask:' + hm + ',linear-gradient(#000,#000);-webkit-mask-composite:xor;mask:' + hm + ',linear-gradient(#000,#000);mask-composite:exclude';
      return '<div style="position:relative;width:176px;height:176px;margin:-8px 0 6px">' + laurelSVG(176, gg ? gg.pal : av.g, Object.assign({}, gg ? gg.cfg : LAU.S, { a0: gg ? 80 : 76 }), { cy: cy, px: bp, kind: gem ? 'g' : dm ? 'd' : 'c' }) + '<div style="position:absolute;left:24px;top:24px;' + mk + '">' + avatarHTML(128, undefined, true, true) + '</div><div style="position:absolute;left:50%;top:' + (cy - (gem ? bp / 2 : Math.round(bp / 2))) + 'px;transform:translateX(-50%)">' + gradeBadge(gg ? (gg.gem ? 'S*' : gg.l + '+') : av.letter, gg ? gg.pal : av.g, 34) + '</div></div>'; })()
    : '<div style="display:flex;flex-direction:column;align-items:center">' + avatarHTML(128, undefined, true) + (av ? '<div style="margin-top:10px;display:flex;justify-content:center">' + gradeBadge(av.letter, av.g, 34) + '</div>' : '') + '</div>';
  const top = '<div style="display:flex;flex-direction:column;align-items:center;padding:6px 0 18px">' + pic + '<div style="font-size:24px;font-weight:700;letter-spacing:-.5px;margin-top:12px;text-align:center">' + esc(nm || 'Tu perfil') + '</div>' + gr + '</div>';
  const rv = (l, v) => '<div class="row"><span class="grow" style="font-size:17px">' + l + '</span><span style="font-size:17px;color:var(--mute);text-align:right;min-width:0;overflow-wrap:anywhere">' + esc(v) + '</span></div>';
  const GN = { n: 'Neutro', m: 'Masculino', f: 'Femenino' }, lg = LANG_LIST.filter((x) => x[0] === langPref())[0], P = curP(), S = curS();
  return top + (clBeta() ? clCardHTML() : '') + (anRead(data) ? '<div style="margin:0 0 16px">' + anNoteHTML(anRead(data)) + '</div>' : '') + '<div class="scard">' + (st.first ? rv('Nombre', st.first) : '') + (st.last ? rv('Apellido', st.last) : '') + (st.nick ? rv('Apodo', st.nick) : '') + rv('Género', GN[userGender()] || 'Neutro') + '</div>' +
    '<div class="scard">' + rv('Idioma', lg ? lg[1] : 'Automático') + '</div>' + themeCardHTML() +
    '<div class="scard">' + rv('Moneda principal', P + ' (' + symOf(P).trim() + ')') + (S ? rv('Segunda moneda', S + ' (' + symOf(S).trim() + ')') : '') + '</div>' +
    '<div class="scard"><div class="row"><span class="grow" style="font-size:17px">Tutorial</span>' + swHTML(tourOn(), 'tourtog') + '</div></div><div class="sub" style="padding:0 10px 6px;font-size:13px">Muestra una guía breve la primera vez que tocas cada cosa.</div>';
}
// recorta al centro, reduce a 256 px y devuelve JPEG en base64
function readPhoto(file, cb) {
  if (!file || !/^image\//.test(file.type || '')) { toast('Elige una imagen'); return; }
  const url = URL.createObjectURL(file), im = new Image();
  im.onload = () => {
    try {
      const S = 256, c = document.createElement('canvas'); c.width = c.height = S;
      const m = Math.min(im.naturalWidth, im.naturalHeight), sx = (im.naturalWidth - m) / 2, sy = (im.naturalHeight - m) / 2, x = c.getContext('2d');
      x.fillStyle = '#fff'; x.fillRect(0, 0, S, S); x.drawImage(im, sx, sy, m, m, 0, 0, S, S);
      cb(c.toDataURL('image/jpeg', 0.82));
    } catch (e) { toast('No se pudo leer la imagen'); }
    URL.revokeObjectURL(url);
  };
  im.onerror = () => { URL.revokeObjectURL(url); toast('No se pudo leer la imagen'); };
  im.src = url;
}
/* --- Recorte de la foto de perfil: se guarda la imagen (máx. 640 px) y el encuadre; tocar la foto vuelve a abrirlo --- */
const PH_RE = /^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+\/=]+$/;
const photoSrc = () => { const p = (data && data.settings && data.settings.photoSrc) || ''; return PH_RE.test(p) ? p : ''; };
function readPhotoSrc(file, cb) {   /* reduce la imagen entera (sin recortar) a 640 px como máximo */
  if (!file || !/^image\//.test(file.type || '')) { toast('Elige una imagen'); return; }
  const url = URL.createObjectURL(file), im = new Image();
  im.onload = () => {
    try {
      const k = Math.min(1, 640 / Math.max(im.naturalWidth, im.naturalHeight)), w = Math.max(1, Math.round(im.naturalWidth * k)), h = Math.max(1, Math.round(im.naturalHeight * k));
      const c = document.createElement('canvas'); c.width = w; c.height = h; const x = c.getContext('2d'); x.fillStyle = '#fff'; x.fillRect(0, 0, w, h); x.drawImage(im, 0, 0, w, h);
      cb(c.toDataURL('image/jpeg', 0.85));
    } catch (e) { toast('No se pudo leer la imagen'); }
    URL.revokeObjectURL(url);
  };
  im.onerror = () => { URL.revokeObjectURL(url); toast('No se pudo leer la imagen'); };
  im.src = url;
}
function cropOpen(src, crop, done) {   /* editor: arrastra para mover, control para acercar · done({ photo, crop:{x,y,z} }) */
  const old = document.getElementById('alertback'); if (old) old.remove();
  const im = new Image();
  im.onload = () => {
    const V = 280, P = 236, w = im.naturalWidth, h = im.naturalHeight, s0 = P / Math.min(w, h);
    let z = crop && crop.z >= 1 && crop.z <= 4 ? crop.z : 1, ox = crop && isFinite(crop.x) ? crop.x * P : 0, oy = crop && isFinite(crop.y) ? crop.y * P : 0;
    const bk = document.createElement('div'); bk.id = 'alertback'; bk.className = 'alertback';
    const close = () => { bk.classList.remove('in'); setTimeout(() => bk.remove(), 220); };
    const box = document.createElement('div'); box.className = 'alertbox'; box.setAttribute('role', 'dialog'); box.style.width = '332px';
    box.innerHTML = '<h4>Ajustar recorte</h4><div id="cropv" style="position:relative;width:' + V + 'px;max-width:100%;height:' + V + 'px;margin:6px auto 12px;border-radius:18px;overflow:hidden;background:#111;touch-action:none;cursor:grab"><img id="cropi" alt="" draggable="false" style="position:absolute;max-width:none;user-select:none;-webkit-user-drag:none" src="' + src + '">' +
      '<div style="position:absolute;left:' + (V - P) / 2 + 'px;top:' + (V - P) / 2 + 'px;width:' + P + 'px;height:' + P + 'px;border-radius:50%;box-shadow:0 0 0 400px rgba(0,0,0,.55),inset 0 0 0 2px rgba(255,255,255,.85);pointer-events:none"></div></div>' +
      '<p style="margin:0 6px 8px;font-size:14px;color:var(--sec)">Arrastra para mover y usa el control para acercar.</p>' +
      '<input id="cropz" type="range" min="1" max="4" step="0.01" value="' + z + '" aria-label="Acercar" style="width:calc(100% - 12px);margin:0 6px 14px;accent-color:#22B573">';
    const img = box.querySelector('#cropi'), view = box.querySelector('#cropv'), zr = box.querySelector('#cropz');
    const lay = () => {
      const sc = s0 * z, iw = w * sc, ih = h * sc, mx = Math.max(0, (iw - P) / 2), my = Math.max(0, (ih - P) / 2);
      ox = Math.max(-mx, Math.min(mx, ox)); oy = Math.max(-my, Math.min(my, oy));
      img.style.width = iw + 'px'; img.style.height = ih + 'px'; img.style.left = (V - iw) / 2 + ox + 'px'; img.style.top = (V - ih) / 2 + oy + 'px';
    };
    let drag = null;
    view.addEventListener('pointerdown', (e) => { drag = { x: e.clientX, y: e.clientY, ox: ox, oy: oy }; try { view.setPointerCapture(e.pointerId); } catch (x) { /* nada */ } view.style.cursor = 'grabbing'; });
    view.addEventListener('pointermove', (e) => { if (!drag) return; ox = drag.ox + (e.clientX - drag.x); oy = drag.oy + (e.clientY - drag.y); lay(); });
    const end = () => { drag = null; view.style.cursor = 'grab'; };
    view.addEventListener('pointerup', end); view.addEventListener('pointercancel', end);
    view.addEventListener('wheel', (e) => { e.preventDefault(); z = Math.max(1, Math.min(4, z - e.deltaY / 400)); zr.value = z; lay(); }, { passive: false });
    zr.addEventListener('input', () => { z = parseFloat(zr.value) || 1; lay(); });
    const bar = document.createElement('div');
    [['Cancelar', null], ['Listo', () => {
      const sc = s0 * z, side = P / sc, S = 256, c = document.createElement('canvas'); c.width = c.height = S; const x = c.getContext('2d');
      x.fillStyle = '#fff'; x.fillRect(0, 0, S, S); x.drawImage(im, w / 2 - ox / sc - side / 2, h / 2 - oy / sc - side / 2, side, side, 0, 0, S, S);
      done({ photo: c.toDataURL('image/jpeg', 0.82), crop: { x: Math.round(ox / P * 1000) / 1000, y: Math.round(oy / P * 1000) / 1000, z: Math.round(z * 100) / 100 } });
    }]].forEach((b, i) => { const bt = document.createElement('button'); bt.type = 'button'; bt.textContent = b[0]; if (i) bt.style.fontWeight = '700'; bt.addEventListener('click', (ev) => { ev.stopPropagation(); close(); if (b[1]) setTimeout(b[1], 60); }); box.appendChild(bt); });
    bk.appendChild(box); bk.addEventListener('click', (ev) => { if (ev.target === bk) close(); });
    deviceEl.appendChild(bk); lay(); requestAnimationFrame(() => bk.classList.add('in'));
  };
  im.onerror = () => toast('No se pudo leer la imagen');
  im.src = src;
}
function photoSave(target, src, r) {
  if (target === 'w') { if (ui.w) { ui.w.photo = r.photo; ui.w.photoSrc = src; ui.w.photoCrop = r.crop; const b = document.getElementById('wphoto'); if (b) b.innerHTML = wPhotoHTML(); } return; }
  data.settings.photo = r.photo; data.settings.photoSrc = src; data.settings.photoCrop = r.crop; ui.dirty++; persist(); ui.profSkip = 0; renderAll(); toast('Foto guardada');   /* profSkip: el input de archivo lo dejó en 1 y el editor de perfil no se refrescaba */
}
function pickPhoto(target) {
  let inp = document.getElementById('photoIn');
  if (!inp) { inp = document.createElement('input'); inp.type = 'file'; inp.accept = 'image/*'; inp.id = 'photoIn'; inp.style.display = 'none'; document.body.appendChild(inp); }
  inp.value = ''; inp.onchange = () => readPhotoSrc(inp.files && inp.files[0], (src) => cropOpen(src, null, (r) => photoSave(target, src, r)));
  inp.click();
}
function cropAgain() { const src = photoSrc(); if (src) cropOpen(src, data.settings.photoCrop, (r) => photoSave('p', src, r)); }
function profileCardHTML() {
  const st = data.settings || {}, nm = [(st.first || '').trim(), (st.last || '').trim()].filter(Boolean).join(' ');
  return '<button class="scard tap" data-act="profile" style="display:flex;align-items:center;gap:16px;width:100%;text-align:left;padding:14px 16px;margin-top:4px">' + avatarHTML(64) +
    '<span class="grow" style="min-width:0"><span style="display:block;font-size:22px;font-weight:700;letter-spacing:-.4px;color:var(--ink);white-space:nowrap;overflow:hidden;text-overflow:ellipsis">' + esc(nm || 'Tu perfil') + '</span><span class="sub" style="display:block;font-size:14px;margin-top:2px">Preferencias de usuario, monedas y Plata Cloud</span></span>' + ICON.chev + '</button>';
}
function profileSheetHTML() {
  if (ui.profEdit) return sheetHead('Editar perfil', 'profview', 'profview') + '<div class="pscroll">' + profileHTML() + '</div>';
  return '<div class="shead"><button class="xbtn" data-act="close" aria-label="Cerrar">' + XSVG + '</button><div class="stitle">Perfil</div><button class="profedit" data-act="profedit">Editar</button></div><div class="pscroll">' + profileViewHTML() + '</div>';
}
function openProfile() {
  ui.confirmId = null; ui.form = null; ui.profSheet = true; ui.profEdit = false;
  const s = $('#sheet'); s.innerHTML = profileSheetHTML(); s.classList.add('tall', 'prof', 'show'); $('#backdrop').classList.add('show');
}
function refreshProf() {
  const s = $('#sheet'); if (!ui.profSheet || !s.classList.contains('show')) return;
  if (ui.profSkip) { ui.profSkip = 0; return; }
  const sc = s.querySelector('.pscroll'), top = sc ? sc.scrollTop : 0; s.innerHTML = profileSheetHTML();
  const n = s.querySelector('.pscroll'); if (n) n.scrollTop = top;
}
function themeCardHTML(name) {
  return '<div class="scard"><div class="row" style="flex-wrap:wrap;row-gap:10px"><span class="grow" style="font-size:17px">Apariencia</span>' + segHTML(name || 'theme', [{ k: 'auto', label: 'Auto', act: 'theme:auto' }, { k: 'light', label: 'Claro', act: 'theme:light' }, { k: 'dark', label: 'Oscuro', act: 'theme:dark' }], window.__themePref(), ';margin:0;flex-basis:100%') + '</div></div>';
}
function profileHTML() {
  const st = data.settings || {};
  return photoRowHTML(!!avatarPhoto()) +
    '<div class="scard">' +
    '<div class="row"><span class="grow" style="font-size:17px">Nombre</span><input class="mini" id="sFirst" style="width:55%;text-align:right" autocomplete="given-name" value="' + esc(st.first || '') + '"></div>' +
    '<div class="row"><span class="grow" style="font-size:17px">Apellido</span><input class="mini" id="sLast" style="width:55%;text-align:right" autocomplete="family-name" value="' + esc(st.last || '') + '"></div>' +
    '<div class="row"><span class="grow" style="font-size:17px">Apodo</span><input class="mini" id="sNick" style="width:55%;text-align:right" placeholder="Opcional" value="' + esc(st.nick || '') + '"></div>' +
    '<div class="row"><span class="grow" style="font-size:17px">Género</span><select class="mini" id="sGen" style="width:auto;padding:0 8px;text-align-last:right"><option value="n"' + (userGender() === 'n' ? ' selected' : '') + '>Neutro</option><option value="m"' + (userGender() === 'm' ? ' selected' : '') + '>Masculino</option><option value="f"' + (userGender() === 'f' ? ' selected' : '') + '>Femenino</option></select></div></div>' +
    '<div class="sub" style="padding:0 10px 6px;font-size:13px;font-style:italic">' + esc(genderExample(userGender(), userNick())) + '</div>' +
    (scoreOn() ? '<div class="scard"><div class="row"><span class="grow" style="font-size:17px">Mostrar puntuaciones</span>' + swHTML(gradesShown(), 'proftog') + '</div></div><div class="sub" style="padding:0 10px 6px;font-size:13px">Muestra tus puntajes históricos bajo tu foto.</div>' : '') +
    '<div class="scard"><div class="row"><span class="grow" style="font-size:17px">Idioma</span><select class="mini" id="sLang" style="width:auto;padding:0 8px;text-align-last:right">' + LANG_LIST.map((x) => '<option value="' + x[0] + '"' + (langPref() === x[0] ? ' selected' : '') + '>' + x[1] + '</option>').join('') + '</select></div></div>' + themeCardHTML() +
    '<div class="scard"><div class="row"><span class="grow" style="font-size:17px">Hemisferio</span><select class="mini" id="sHemi" style="width:auto;padding:0 8px;text-align-last:right"><option value=""' + (!(data.settings.hemi) ? ' selected' : '') + '>Automático</option><option value="n"' + (data.settings.hemi === 'n' ? ' selected' : '') + '>Norte</option><option value="s"' + (data.settings.hemi === 's' ? ' selected' : '') + '>Sur</option></select></div></div><div class="sub" style="padding:0 10px 6px;font-size:13px">Define la estación de tu aviso mensual.</div>' +
    '<div class="scard"><div class="row"><span class="grow" style="font-size:17px">Tutorial</span>' + swHTML(tourOn(), 'tourtog') + '</div></div><div class="sub" style="padding:0 10px 6px;font-size:13px">Muestra una guía breve la primera vez que tocas cada cosa.</div>' +
    (isWebView() ? '<div class="scard"><div class="row"><span class="grow" style="font-size:17px">Bentos al deslizar</span><select class="mini" id="sFlow" style="width:auto;padding:0 8px;text-align-last:right"><option value="after"' + (flowMode() === 'after' ? ' selected' : '') + '>Después del Resumen</option><option value="before"' + (flowMode() === 'before' ? ' selected' : '') + '>Antes del Resumen</option><option value="off"' + (flowMode() === 'off' ? ' selected' : '') + '>Desactivado</option></select></div><div class="sub" style="font-size:13px;margin-top:6px">Desliza en el Resumen para ver tus dos primeros Bentos.</div></div>' : '') +
    curSettingsHTML();
}
function hiddenAcctsHTML() {
  const hl = [].concat(data.accounts, data.cards).filter((x) => x.hid);
  if (!hl.length) return '';
  return '<div style="margin-top:30px"><div class="sechead" style="padding-bottom:6px"><h2>Cuentas ocultas</h2></div></div><div class="scard" style="margin-bottom:24px">' +
    hl.map((x) => '<div class="row"><span class="grow" style="font-size:17px">' + esc(x.name) + l4tag(x) + '</span>' + swHTML(false, 'unhide:' + x.id) + '</div>').join('') + '</div>';
}
function demoNoticeHTML() {
  if (!(data && data.demo)) return '';
  return '<div class="scard" id="demoCard" style="margin-top:14px;padding:14px 16px"><div style="display:flex;align-items:center;gap:8px;font-weight:600;font-size:16px"><span style="width:10px;height:10px;border-radius:50%;background:#22B573;flex:none"></span>Perfil de demostración</div>' +
    '<div class="sub" style="font-size:14px;margin:6px 0 10px">Estás viendo datos de ejemplo. Tus datos reales siguen guardados aparte y vuelven cuando salgas del demo.</div>' +
    '<button class="execbtn" data-act="demoexit" style="background:#22B573;color:#fff;border:0;border-radius:999px;height:auto;min-height:44px;width:100%;padding:12px 16px;line-height:1.2;font:inherit;font-size:15px;font-weight:600;cursor:pointer">Salir del demo</button>' + (clBeta() && clIn() ? '<div class="sub" style="font-size:14px;margin:12px 0 8px">Ey, hay un demo cargado. ¿Quieres sincronizar con tu copia más reciente en la nube?</div><button class="clb alt" data-act="cl:pull">Salir y sincronizar</button>' : '') + '</div>';
}
function settingsHTML(noHead) {
  const st = data.settings;
  const blue = (i) => i.replace(/#1C1C1E/g, '#1A9D63');
  return (noHead ? '' : sheetHead('Ajustes')) + profileCardHTML() + demoNoticeHTML() +
    (clGone() ? '<div class="sub" style="padding:0 4px;margin:12px 0 4px;text-align:center;line-height:1.2"><span style="display:inline-flex;align-items:center;gap:6px;color:var(--rt);font-weight:700">' + RMI('error-warning-fill', 20, '#D70015') + 'Cuenta borrada</span><div style="margin-top:2px;font-size:13px">Guarda tu archivo local para no perder tus datos.</div></div>' : clBeta() && clOn() ? clStatHTML() : '<div class="sub" style="padding:0 4px;margin:12px 0 4px;text-align:center;line-height:1.1">' + (ui.dirty > 0
      ? '<span style="display:inline-flex;align-items:center;gap:6px;color:var(--ot);font-weight:600">' + RMI('error-warning-fill', 20, '#FF9500') + '' + plural(ui.dirty, 'cambio', 'cambios') + ' sin guardar</span>'
      : '<span style="display:inline-flex;align-items:center;gap:6px;color:var(--gt);font-weight:600">' + RMI('checkbox-circle-fill', 20, '#22B573') + 'Guardado</span>') + '<div style="margin-top:-2px;font-size:13px">' + lastSavedLabel() + '</div></div>') +
    '<div class="scard" style="margin-top:14px">' +
    '<button class="linkrow" data-act="' + (clBeta() && clOn() ? 'cl:load' : 'load') + '">' + blue(ICON.folder) + 'Cargar archivo de perfil</button>' +
    '<button class="linkrow" data-act="save" style="border-top:1px solid var(--line);width:100%">' + blue(ICON.save) + (clBeta() && clOn() ? 'Guardar copia de archivo local' : 'Guardar archivo de perfil') + '</button>' +
    (data.demo || !nazcaOn() ? '' : '<button class="linkrow" data-act="imp:start" style="border-top:1px solid var(--line);width:100%">' + blue(RMI('folder-chart-line', 22, '#1C1C1E')) + 'Importar movimientos</button>') +
    '</div>' +
    (clBeta() ? '' : cloudCardHTML()) +
    '<div class="scard"><div class="row"><span class="grow" style="font-size:17px">Insights y half‑time</span>' + swHTML(insOn(), 'setopt:insights') + '</div>' +
    '<div class="row"><span class="grow" style="font-size:17px">Puntuación mensual</span>' + swHTML(scoreOn(), 'setopt:score', !insOn()) + '</div></div>' +
    '<div class="sub" style="padding:0 10px 6px;font-size:13px">Esta información no es recopilada por Plata ni Estudio 22. Toda la información se maneja en tu archivo de perfil.</div>' +
    hiddenAcctsHTML() + '<div class="scard">' +
    '<div class="row" style="flex-wrap:wrap;row-gap:0"><span class="grow" style="font-size:17px">Gasto variable por semana</span><input class="mini" id="sVar" inputmode="decimal" value="' + (st.variable_weekly || 0) + '"><div class="sub" style="flex-basis:100%;font-size:13px;margin-top:2px">Gasto semanal estimado fuera de lo programado.</div></div>' +
    '<div class="row" style="flex-wrap:wrap;row-gap:0"><span class="grow" style="font-size:17px">Colchón mínimo</span><input class="mini" id="sCush" inputmode="decimal" value="' + (st.cushion || 0) + '"><div class="sub" style="flex-basis:100%;font-size:13px;margin-top:2px">Si tu saldo proyectado baja de aquí, te avisamos.</div></div>' +
    '</div>' + '<div class="scard"><button class="linkrow" data-act="demo" style="width:100%">' + blue(ICON.sliders) + 'Cargar perfil de demostración</button>' +
    '<button class="linkrow" data-act="wipe" style="width:100%;border-top:1px solid var(--line);color:var(--rt)">Borrar datos</button>' +
    '<button class="linkrow" data-act="wipehome" style="width:100%;border-top:1px solid var(--line);color:var(--rt)">Borrar datos y regresar a pantalla inicial</button></div>' +
    (PINLOCK.can ? '<div class="scard"><button class="linkrow" data-act="pin:menu" style="width:100%">' + LOCKSQ(24, '#1A9D63') + '<span class="grow" style="text-align:left">Bloqueo con PIN</span><span class="sub" style="font-size:14px">' + (PINLOCK.on() ? 'Activado' : 'Apagado') + '</span></button></div>' : '') +
    '<div class="scard"><button class="linkrow" data-act="news" style="width:100%">' + RMI('gift-line', 24, '#1A9D63') + '<span class="grow" style="text-align:left">Novedades</span><span class="betapill b2" style="flex:none">B E T A&nbsp;&nbsp;5</span></button></div>' +
    '<div class="scard"><button class="linkrow" data-act="feedback" style="width:100%">' + RMI('star-line', 24, '#1A9D63') + '<span class="grow" style="text-align:left">Danos tu opinión</span></button></div>' +
    '<div class="scard"><button class="linkrow" data-act="transp" style="width:100%">' + RMI('shield-check-line', 24, '#1A9D63') + '<span class="grow" style="text-align:left">Transparencia</span></button></div>' +
    (data.demo ? '' : '<div class="scard"><button class="linkrow" data-act="exportrev" style="width:100%">' + blue(RMI('file-search-line', 22, '#1C1C1E')) + 'Enviar para análisis de uso a Plata</button></div>' + rvNoteHTML()) +
    '<button class="tap" data-act="credits" style="display:block;width:100%;background:none;text-align:center;padding:30px 0 8px"><img class="e22i" src="' + E22_LOGO + '" width="108" height="18" alt="Estudio 22" style="display:block;margin:0 auto 12px"><span class="e22m" style="--m:url(\'' + E22_LOGO + '\')"></span><div class="sub e22t" style="font-size:13px">Diseñado por Estudio 22 en Nueva York.</div><div class="sub e22t" style="font-size:13px;margin-top:2px">© Estudio 22 y Leonardo Richarte, 2026.</div></button>' +
    '<div class="sub" style="font-size:11.5px;line-height:1.4;text-align:center;padding:2px 18px 6px;opacity:.85">Los nombres y logos de bancos, billeteras y servicios son marcas de sus respectivos titulares. Plata los muestra solo para ayudarte a reconocer tus cuentas y suscripciones; no está afiliada, patrocinada ni respaldada por ninguna de estas entidades.</div>';
}
function curOtherOpts(P, opt, S) { return '<optgroup label="Otras monedas">' + CUR_OTHERS().filter((c) => c !== P && !(CURRENCIES[c] || {}).custom).map((c) => opt(c, S == null ? P : S)).join('') + '</optgroup>'; }
function curSettingsHTML() {
  const P = curP(), S = curS(), opt = (c, sel) => '<option value="' + c + '"' + (c === sel ? ' selected' : '') + '>' + c + ' (' + symOf(c).trim() + ')</option>';
  const row = (lbl, name, sel) => '<div class="row"><span class="grow"><span style="font-size:17px;display:block">' + lbl + '</span><span class="sub" style="font-size:13px">' + name + '</span></span>' + sel + '</div>';
  return '<div class="scard">' +
    row('Moneda principal', CURRENCIES[P].name, '<select class="mini" id="sCur1" style="width:auto;padding:0 8px;text-align-last:right">' + CUR_ORDER.map((c) => opt(c, P)).join('') + '</select>') +
    row('Segunda moneda', S ? CURRENCIES[S].name : 'Opcional', '<select class="mini" id="sCur2" style="width:auto;padding:0 8px;text-align-last:right"><option value="">Ninguna</option>' + CUR_ORDER.filter((c) => c !== P).map((c) => opt(c, S)).join('') + curOtherOpts(P, opt, S) + '</select>') +
    (S ? '<div class="row"><span class="grow" style="font-size:17px">1 ' + P + ' en ' + S + '</span><input class="mini" id="sFx" inputmode="decimal" value="' + ((data.settings || {}).fx > 0 ? data.settings.fx : fxDefault(P, S)) + '"></div>' : '') +
    '<div class="row"><span class="grow"><span style="font-size:17px;display:block">Moneda personalizada</span><span class="sub" style="font-size:13px">Hasta 3 caracteres, p. ej. ARS</span></span><input class="mini" id="sCust" maxlength="3" autocapitalize="characters" autocomplete="off" style="width:78px;text-transform:uppercase" value="' + esc((data.settings || {}).customCur || '') + '"></div>' +
    '</div><div class="sub" style="padding:0 10px 6px;font-size:13px">Puedes usar hasta 2 monedas a la vez. El tipo de cambio es tuyo: edítalo cuando cambie.</div>';
}
function setCustomCur(raw) {
  const st = data.settings, old = st.customCur || '', c = normCustom(raw);
  if (String(raw).trim() && !c) { toast('Código no válido'); renderAll(); return; }
  if (c === old) { renderAll(); return; }
  const items = [].concat(data.accounts, data.cards, data.subs, data.savings);
  if (!c && old && ([st.currency, st.currency2].indexOf(old) >= 0 || items.some((o) => o.cur === old))) { toast('Esa moneda está en uso'); renderAll(); return; }
  if (old && c) { items.forEach((o) => { if (o.cur === old) o.cur = c; }); if (st.currency === old) st.currency = c; if (st.currency2 === old) st.currency2 = c; }
  regCustom(c); st.customCur = c; ui.dirty++; persist(); renderAll(); toast('Ajuste guardado');
}
function applyCurrencies(p, sec) {
  if (sec === p) sec = '';
  const st = data.settings, op = curP(), os = curS();
  if (p === op && sec === os) return;
  const keep = [p].concat(sec ? [sec] : []);
  const all = [].concat(data.accounts, data.cards, data.subs, data.savings), hit = all.filter((o) => keep.indexOf(o.cur) < 0);
  const run = () => {
    if (p === os && sec === op && st.fx > 0) st.fx = Number((1 / st.fx).toPrecision(4));
    else if (sec) st.fx = fxDefault(p, sec);
    st.currency = p; st.currency2 = sec; hit.forEach((o) => { o.cur = p; });
    ui.dirty++; persist(); renderAll(); toast('Ajuste guardado');
  };
  if (hit.length) {
    const lostA = Array.from(new Set(hit.map((o) => o.cur))), single = lostA.length === 1;
    const asg0 = single ? Number(curRateBetween(lostA[0], p).toPrecision(4)) : 0;
    const KINDS = [['accounts', 'account'], ['cards', 'debt'], ['subs', 'sub'], ['savings', 'saving']];
    const rates = {}; lostA.forEach((c) => { rates[c] = curRateBetween(c, p); });
    askCurChange(lostA.join(', '), p, asg0, (mode, r) => {
      const plan = [];
      KINDS.forEach((kk) => data[kk[0]].forEach((o) => { if (hit.indexOf(o) >= 0) plan.push([o, kk[1], mode === 'keep' ? 1 : mode === 'man' ? r : rates[o.cur]]); }));
      run();
      plan.forEach((x) => { const o = x[0]; scaleOwn(o, x[1], x[2], p); if (x[1] === 'account' || x[1] === 'debt') scaleLinked(o.id, x[2], p); });
      ui.dirty++; persist(); renderAll();
    }, single);
    renderAll();
  } else run();
}
function quickHTML() {
  const it = (act, ic, t, sub) => '<button class="qi" data-act="' + act + '"><span class="qs" aria-hidden="true">' + RMI(ic, 20, 'currentColor') + '</span><span class="ql"><b>' + t + '</b><em class="sub">' + sub + '</em></span></button>';
  const hd = (t) => '<div class="qh">' + t + '</div>';
  /* Registrar lo que ya pasó, planear lo que viene. El trabajo vive en Proyección y en Cuentas. */
  const reg = [hd('Registrar'), it('add', 'add-circle-line', 'Movimiento', 'Algo que ya pasó'), it('xfer', 'arrow-left-right-line', 'Transferir', 'Entre tus cuentas')];
  if (nazcaOn()) reg.push(it('imp:start', 'folder-chart-line', 'Importar', 'Archivo o captura'));
  const plan = [hd('Planear'), it('new:income', 'bank-line', 'Ingreso previsto', 'Sueldo o pago'), it('new:expense', 'bank-card-line', 'Gasto previsto', 'Recibo o compra')];
  const sep = '<div class="qsep"><i></i></div>';
  return reg.concat([sep], plan).join('');
}
/* Menú «+» al estilo Apple: flota junto al botón y no oscurece lo de atrás */
function closeQMenu() { const pb = $('#plusbtn'); if (pb) pb.classList.remove('qopen'); const m = $('#qmenu'); if (!m || m.classList.contains('out')) return; m.classList.add('out'); setTimeout(() => m.remove(), 270); }
function openQMenu(btn) {
  const old = $('#qmenu'); if (old) { if (old.classList.contains('out')) old.remove(); else { closeQMenu(); return; } }
  const m = document.createElement('div'); m.id = 'qmenu'; m.className = 'qmenu'; m.setAttribute('role', 'menu'); m.innerHTML = quickHTML();
  document.body.appendChild(m); btn.classList.add('qopen');
  const r = btn.getBoundingClientRect(), w = m.offsetWidth, vw = window.innerWidth;
  if (r.top > window.innerHeight / 2) { m.style.bottom = Math.round(window.innerHeight - r.top + 10) + 'px'; m.style.transformOrigin = 'bottom right'; m.classList.add('up'); } else m.style.top = Math.round(r.bottom + 8) + 'px';
  m.style.left = Math.max(14, Math.min(vw - w - 14, Math.round(r.right - w))) + 'px';
  m.addEventListener('animationend', (e) => { if (e.target === m && !m.classList.contains('out')) { m.style.animation = 'none'; m.querySelectorAll('.qi,.qsep').forEach((x) => { x.style.animation = 'none'; x.style.opacity = '1'; }); } });
  m.addEventListener('click', () => setTimeout(closeQMenu, 0));
}
document.addEventListener('pointerdown', (e) => { const m = $('#qmenu'); if (m && !m.contains(e.target) && !(e.target.closest && e.target.closest('#plusbtn, .tourtip'))) closeQMenu(); }, true);
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeQMenu(); });
function openSettings() { if (ui.tab === 'cuenta' && ui.itemKind === 'settings' && ui.itemId != null) return; ui.confirmId = null; ui.form = null; openItem('settings', 's'); }
function navSlide(mode) { const e = $('#s-cuenta'); if (!e) return; e.classList.remove('nav-tab', 'nav-push', 'nav-pop'); void e.offsetWidth; e.classList.add('nav-' + mode); e.scrollTop = 0; }
function openTransp() { window.open('https://plataapp.net/transparencia.html', '_blank', 'noopener'); }
function leaveSettings() { if (ui.itemKind === 'settings' || ui.itemKind === 'credits' || ui.itemKind === 'transp' || ui.itemKind === 'profile' || ui.itemKind === 'imp') ui.itemId = null; }
function closeSheet() { ui.xf = null; ui.profSheet = false; ui.profEdit = false; $('#sheet').classList.remove('show'); $('#backdrop').classList.remove('show'); ui.confirmId = null; }
/* Arrastrar hacia abajo la parte superior de la hoja (rayita y título) para cerrarla */
(function () {
  const sh = $('#sheet'); if (!sh) return; let st = null;
  const web = () => document.documentElement.classList.contains('web');
  sh.addEventListener('touchstart', (ev) => {
    if (web() || !sh.classList.contains('show') || ev.touches.length !== 1) return;
    const t = ev.touches[0], r = sh.getBoundingClientRect();
    if (t.clientY - r.top > 70 || ev.target.closest('button, input, select, textarea, a, label')) return;
    st = { y: t.clientY, dy: 0, t: Date.now() }; sh.style.transition = 'none';
  }, { passive: true });
  sh.addEventListener('touchmove', (ev) => {
    if (!st) return; const dy = Math.max(0, ev.touches[0].clientY - st.y); st.dy = dy;
    sh.style.transform = 'translateY(' + dy + 'px)'; if (dy > 4 && ev.cancelable) ev.preventDefault();
  }, { passive: false });
  const end = () => {
    if (!st) return; const d = st, v = d.dy / Math.max(1, Date.now() - d.t); st = null;
    sh.style.transition = 'transform .28s cubic-bezier(.2,.9,.3,1)';
    if (d.dy > 90 || (d.dy > 30 && v > 0.5)) {
      sh.style.transform = 'translateY(115%)';
      setTimeout(() => { closeSheet(); sh.style.transition = ''; sh.style.transform = ''; }, 260);
    } else { sh.style.transform = ''; setTimeout(() => { sh.style.transition = ''; }, 300); }
  };
  sh.addEventListener('touchend', end); sh.addEventListener('touchcancel', end);
})();
function readSheet() {
  return { from: ($('#fFrom') || {}).value || '', amount: ($('#fAmount') || {}).value || '', note: ($('#fNote') || {}).value || '', date: ($('#fDate') || {}).value || '', acc: ($('#fAcc') || {}).value || ui.sheetAcc };
}
function nextTxId() { return Math.max(Date.now() * 1000 + Math.floor(Math.random() * 1000), 1 + Math.max.apply(null, data.transactions.map((t) => Number(t.id) || 0).concat([0]))); }
