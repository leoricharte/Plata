/* ---------- Eventos ---------- */
let swSwallow = false, swDrag = null;
function setVariable(on, el) {
  ui.variable = on;
  const sw = el || $('#pSwitch');
  if (sw) { sw.classList.toggle('on', on); sw.setAttribute('aria-checked', String(on)); }
  updateProjection();
}
document.addEventListener('pointerdown', (e) => {
  const sw = e.target.closest && e.target.closest('.switch'); if (!sw) return;
  swDrag = { sw: sw, x: e.clientX, moved: false, was: sw.classList.contains('on') };
  sw.classList.add('press');
});
document.addEventListener('pointermove', (e) => {
  if (!swDrag) return;
  const dx = e.clientX - swDrag.x;
  if (Math.abs(dx) > 10) {
    swDrag.moved = true;
    const want = dx > 0;
    if (want !== ui.variable) setVariable(want, swDrag.sw);
    swDrag.x = e.clientX; 
  }
});
function swEnd(e) {
  if (!swDrag) return;
  const d = swDrag; swDrag = null;
  d.sw.classList.add(d.was ? 'fl-on' : 'fl-off'); d.sw.classList.remove('press'); setTimeout(() => d.sw.classList.remove('fl-on', 'fl-off'), 150);
  if (e && e.type === 'pointerup' && !d.moved) { setVariable(!ui.variable, d.sw); swSwallow = true; }
  else if (d.moved) swSwallow = true;
  setTimeout(() => { swSwallow = false; }, 450);
}
document.addEventListener('pointerup', swEnd);
document.addEventListener('pointercancel', swEnd);
document.addEventListener('click', (e) => {
  const el = e.target.closest('[data-act]');
  if (!el) return;
  const act = el.getAttribute('data-act'), parts = act.split(':'), a = parts[0], arg = parts.slice(1).join(':');
  if (a === 'tab') setTab(arg);
  else if (a === 'add') openSheet();
  else if (a === 'imp') impAct(arg);
  else if (a === 'theme') { setSeg(el); window.__applyTheme(arg); try { if (data && data.settings) { data.settings.theme = arg; persist(); } } catch (e) { /* sin perfil */ } if ((document.documentElement.dataset.theme === 'dark') !== !!window.__launchDark && !isWebView()) toast('Abre la app nuevamente para cambiar el color de la barra de arriba', true); }
  else if (a === 'settings') openSettings();
  else if (a === 'xfer') openXfer();
  else if (a === 'rv') revAct(arg);
  else if (a === 'xsubmit') xferSubmit();
  else if (a === 'nsug') {
    const x = (ui.nsug || [])[+arg], inp = $('#fNote'); if (x && inp) {
      inp.value = x.n; if (ui.sheetType === 'out' && x.out && CAT_ORDER.indexOf(x.cat) >= 0) { ui.sheetCat = x.cat; const w = $('#catWrap'); if (w) w.innerHTML = catsHTML(); }
      const n = $('#nsug'); if (n) n.innerHTML = ''; inp.focus();
    }
  }
  else if (a === 'quick') { ui.confirmId = null; ui.form = null; openQMenu(el); }
  else if (a === 'close') { if (!CL.lock) closeSheet(); }
  else if (a === 'type') { const was = ui.sheetType; ui.sheetType = arg; ui.sheetAuto = false; if (was === 'pay' || arg === 'pay') { const kp = readSheet(); ui.sheetAcc = ui.sheetCard ? ui.sheetCard : arg === 'pay' ? (data.cards[0] || {}).id : data.accounts[0].id; showSheet(sheetHTML(kp)); } else { setSeg(el); const fa = $('#fAcc'); if (fa) { const cur = fa.value, isCrd = data.cards.some((k) => k.id === cur), keep = arg === 'in' && isCrd ? data.accounts[0].id : cur; fa.innerHTML = acctOpts(keep, arg !== 'in'); } const w = $('#catWrap'); w.innerHTML = catsHTML(); swapIn(w); const th = $('#thint'); if (th) th.textContent = typeHint(); } }
  else if (a === 'cat') { ui.sheetCat = arg; el.parentNode.querySelectorAll('.chip').forEach((c) => c.classList.toggle('on', c === el)); }
  else if (a === 'submit') submitSheet();
  else if (a === 'load') $('#file').click();
  else if (a === 'save') saveFile();
  else if (a === 'exportrev') reviewDlg();
  else if (a === 'rvgo') { closeSheet(); setTimeout(reviewSend, 120); }
  else if (a === 'hor') { ui.hor = Number(arg); setSeg(el); ui.week = Math.min(ui.week, ui.hor); const rg = $('#weekRange'); if (rg) { rg.max = String(ui.hor); rg.value = String(ui.week); } updateProjection(true); }
  else if (a === 'bsets') showSheet(bsetsHTML());
  else if (a === 'bsview') { ui.bsel = arg === 'base' ? 'base' : arg; closeSheet(); renderAll(); }
  else if (a === 'bsnew') bsEdit(null);
  else if (a === 'bsedit') bsEdit(arg);
  else if (a === 'bsback') showSheet(bsetsHTML());
  else if (a === 'bssave') bsSave();
  else if (a === 'bsdel') { const id = ui.bs && ui.bs.id; askDelete('este set', () => { data.budgetSets = bsets().filter((x) => x.id !== id); if (ui.bsel === id) ui.bsel = null; ui.bs = null; ui.dirty++; persist(); closeSheet(); renderAll(); toast('Set eliminado'); }); }
  else if (a === 'mov') { ui.mov = arg; setSeg(el); updateMovList(); }
  else if (a === 'interest') { ui.interest = !ui.interest; renderDeuda(); }
  else if (a === 'sim') openSim();
  else if (a === 'edit') { const q = arg.split(':'); if (q[0] === 'acct' || q[0] === 'saving') openAcct(q[1]); else if (q[0] === 'income' || q[0] === 'expense' || q[0] === 'sub' || q[0] === 'budget' || q[0] === 'job') { if (ui.itemId != null && ui.tab === 'cuenta') { ui.confirmId = null; openForm(q[0], q[1]); } else openItem(q[0], q[1]); } else openForm(q[0], q[1]); }
  else if (a === 'sortmenu') toggleSortMenu(el, arg);
  else if (a === 'menuclose') closeSortMenu();
  else if (a === 'ringk') { data.settings.ring_kind = arg; ui.dirty++; persist(); renderDeuda(); closeSortMenu(); }
  else if (a === 'ahide') { data.settings[arg + '_hide'] = !data.settings[arg + '_hide']; ui.dirty++; persist(); renderDeuda(); if (window.__sortFill && $('#sortmenu')) window.__sortFill(); }
  else if (a === 'asort' || a === 'adir') { const q = arg.split(':'); data.settings[q[0] + (a === 'asort' ? '_sort' : '_dir')] = q[1]; ui.dirty++; persist(); renderDeuda(); if (window.__sortFill && $('#sortmenu')) window.__sortFill(); }
  else if (a === 'acctback') setTab(ui.prevTab && ui.prevTab !== 'cuenta' ? ui.prevTab : 'deuda');
  else if (a === 'achide') { const ob = data.accounts.find((x) => x.id === ui.acctId) || data.cards.find((x) => x.id === ui.acctId); if (ob) { ob.hid = !ob.hid; ui.dirty++; persist(); renderAll(); toast(ob.hid ? 'Oculta del resumen' : 'Visible en el resumen'); } }
  else if (a === 'unhide') { const ob = data.accounts.find((x) => x.id === arg) || data.cards.find((x) => x.id === arg); if (ob) { ob.hid = false; ui.dirty++; persist(); renderAll(); } }
  else if (a === 'acctedit') { const isA = data.accounts.some((x) => x.id === ui.acctId), isS = data.savings.some((x) => x.id === ui.acctId); openForm(isS ? 'saving' : isA ? 'account' : 'debt', ui.acctId); }
  else if (a === 'contribto') { openForm('contrib'); if (ui.form && ui.form.kind === 'contrib') { ui.form.obj.sav = arg; showSheet(formHTML()); } }
  else if (a === 'addto') { openSheet(); ui.sheetAcc = arg; ui.sheetCard = data.cards.some((c) => c.id === arg) ? arg : null; showSheet(sheetHTML()); }
  else if (a === 'new') openForm(arg, null);
  else if (a === 'evedit') openEv(arg);
  else if (a === 'evsave') evSave();
  else if (a === 'subadv') {
    const sb = data.subs.find((x) => x.id === ui.itemId); if (!sb) return;
    askConfirm('¿Adelantar este cobro?', 'Se registra el gasto hoy y se salta el próximo cobro, para que no se cuente doble.', [{ label: 'Adelantar', fn: () => subAdvance(sb) }]);
  }
  else if (a === 'evskip') { evStore({ skip: true }); toast('Evento omitido'); }
  else if (a === 'evreset') { evStore(null); toast('Evento restaurado'); }
  else if (a === 'evseries') { const f = ui.ev.form, id = ui.ev.srcId; closeSheet(); setTimeout(() => openForm(f, id), 260); }
  else if (a === 'fsave') saveForm();
  else if (a === 'fdel') deleteForm();
  else if (a === 'fpick') { if (!ui.form) return; const q = arg.split(':'), k = q[0], v = q.slice(1).join(':'); syncForm(); ui.form.obj[k] = v === 'auto' ? '' : v; if (k === 'icon') { ui.form.obj.iconUser = v !== 'auto'; if (v === 'auto') ui.form.obj.colorUser = false; } if (k === 'color') ui.form.obj.colorUser = true; el.parentNode.querySelectorAll('button').forEach((b) => b.classList.toggle('on', b === el)); updPrev(); }
  else if (a === 'fseg') {
    if (!ui.form) return;
    const q = arg.split(':'), k = q[0]; let v = q.slice(1).join(':');
    syncForm(); const F = FORMS[ui.form.kind];
    if (k === 'cur' && F.cur === 'cur') {
      const o0 = ui.form.obj, from = o0.cur, MON = CUR_MONEY[ui.form.kind], P = curP(), S = curS(), fk = ui.form.kind;
      const linked = (fk === 'account' || fk === 'debt') && !ui.form.isNew;
      if (from !== v && S && [P, S].indexOf(from) >= 0 && [P, S].indexOf(v) >= 0 && MON && (MON.some((m) => (o0[m] || 0) > 0) || linked)) {
        const asg = Number(curRateBetween(from, v).toPrecision(4));
        askCurChange(from, v, asg, (mode, r) => {
          if (!ui.form || ui.form.obj !== o0) return;
          const fac = mode === 'keep' ? 1 : mode === 'man' ? r : asg;
          if (ui.form.origCur == null) { ui.form.origCur = from; ui.form.linkF = 1; }
          ui.form.linkF *= fac;
          scaleOwn(o0, fk, fac, v); o0.cur = v; $('#sheet').innerHTML = formHTML();
        }, true);
        return;
      }
    }
    if (k === 'repeat') v = v === 'm' || v === 'q' ? v : Number(v);
    ui.form.obj[k] = v;
    if ((k === 'repeat' && v === 'q') || (k === 'freq' && v === 'q')) { const o2 = ui.form.obj; if (!(o2.q1 >= 1)) { const d0 = pd(o2.date || o2.start).getDate(); o2.q1 = Math.min(d0, 31); o2.q2 = d0 + 15 > 31 ? d0 - 15 : d0 + 15; if (o2.q2 < 1) o2.q2 = 30; } } if (k === 'mode' && v === 's') ui.form.obj.freq = 'm';
    if (k === 'kind' && v === 'pay' && !ui.form.obj.card) ui.form.obj.card = (data.cards[0] || {}).id;
    if (F.rebuild && F.rebuild.indexOf(k) >= 0) { $('#sheet').innerHTML = formHTML(); }
    else { setSeg(el); if (k === 'cur') $('#fSym').textContent = symOf(v).trim(); }
  }
  else if (a === 'exec') { e.stopPropagation(); execSim(arg); }
  else if (a === 'simtog') { e.stopPropagation(); const pl = data.planned.find((x) => x.id === arg); if (pl) { pl.on = pl.on === false; ui.dirty++; persist(); renderProyeccion(); } }
  else if (a === 'calnav') { ui.calMonth = Math.max(-2, Math.min(12, (ui.calMonth || 0) + Number(arg))); const m = new Date(getToday().getFullYear(), getToday().getMonth() + ui.calMonth, 1); ui.calSel = iso(ui.calMonth === 0 ? getToday() : m); renderCal(); }
  else if (a === 'calsel') { ui.calSel = arg; renderCal(); }
  else if (a === 'pending') { ui.skipPending = false; openConfirm(); }
  else if (a === 'cok') doConfirm(true);
  else if (a === 'clater') doConfirm(false);
  else if (a === 'cclose') { if (ui.confirmPick) { ui.confirmPick = null; closeSheet(); } else { ui.skipPending = true; closeSheet(); } }
  else if (a === 'wstart') wStart();
  else if (a === 'wcopy') wCopyLink();
  else if (a === 'wlevel') { const w = ui.w; w.level = arg; w.step = 0; if (arg === 'simple') { w.ins = false; w.score = false; } else { delete w.ins; delete w.score; } welcomeHTML('next'); }
  else if (a === 'wlogo') wLogoTap();
  else if (a === 'betainfo') betaInfo();
  else if (a === 'news') newsPopup();
  else if (a === 'feedback') feedbackPopup(true);
  else if (a === 'history') showSheet(historySheetHTML());
  else if (a === 'wdbg') wDebugPick(arg);
  else if (a === 'wdbgclose') wDebugClose();
  else if (a === 'wdbgtheme') { window.__applyTheme(arg); try { if (data && data.settings) { data.settings.theme = arg === 'auto' ? '' : arg; persist(); } } catch (e) { /* sin perfil */ } document.querySelectorAll('#wdbg [data-act^="wdbgtheme:"]').forEach((bt) => { const on = bt.getAttribute('data-act') === 'wdbgtheme:' + arg; bt.style.background = on ? '#22B573' : 'rgba(120,120,128,.16)'; bt.style.color = on ? '#fff' : 'var(--ink)'; }); }
  else if (a === 'wgsel') { wSel = arg; const box = document.getElementById('wstreak'); if (box) { box.innerHTML = wStreakInner(); } document.querySelectorAll('[data-act^="wgsel:"]').forEach((b) => { b.style.opacity = b.dataset.act === 'wgsel:' + arg ? '' : '.55'; }); }
  else if (a === 'wgrade') { wDebugClose(); loadDemo('g_' + arg); if (ui.dbgOpen) { closeSheet(); leaveSettings(); } renderAll(); setTab('resumen'); hideWelcome(); toast('Perfil de prueba cargado'); }
  else if (BW_ACTS.indexOf(a) >= 0) bentoAct(a, arg);
  else if (a === 'wmenu') wMenu();
  else if (a === 'wmenuclose') wCloseMenu();
  else if (a === 'wcloud') wcloudGo();
  else if (a === 'wclclose') wclClose();
  else if (a === 'wclgo') { wclClose(); clAct('open', el); }
  else if (a === 'wclstay') { /* no cerrar */ }
  else if (a === 'wquick') { wCloseMenu(); wPriv(() => { const q0 = clone(EMPTY), gc = guessCur(); q0.settings.currency = gc[0]; q0.settings.currency2 = gc[1] || ''; if (gc[1]) q0.settings.fx = fxDefault(gc[0], gc[1]); q0.accounts.forEach((x) => { x.cur = gc[0]; }); data = migrate(q0); ui.dirty = 0; data.settings.tour = { on: true, seen: {} }; persist(); renderAll(); setTab('resumen'); hideWelcome(); }); }
  else if (a === 'wgear') wGearHint();
  else if (a === 'wpriv') { const fn = ui.wfn; ui.wpriv = false; ui.wfn = null; if (fn) PINLOCK.offer(fn); }
  else if (a === 'wdemo') { wCloseMenu(); ui.w = { demo: true, level: null, step: 0 }; welcomeHTML('next'); }
  else if (a === 'wdemopick') { wPriv(() => { loadDemo(arg); renderAll(); setTab('resumen'); hideWelcome(); toast('Perfil de demostración cargado'); setTimeout(checkPending, 900); }, true); }
  else if (a === 'demopick') {
    const run = () => { loadDemo(arg); closeSheet(); leaveSettings(); renderAll(); document.querySelectorAll('.screen').forEach((sc) => { sc.scrollTop = 0; }); setTab('resumen'); toast('Perfil de demostración cargado'); setTimeout(checkPending, 900); };
    const pr = DEMO_LIST.find((x) => x.id === arg) || { name: '' };
    if (!hasData() || (data && data.demo)) run(); else askConfirm('¿Cargar el perfil de ' + pr.name + '?', 'Tus datos reales se guardan aparte y los recuperas al salir del demo.', [{ label: 'Cargar perfil de demostración', dest: true, fn: run }]);
  }
  else if (a === 'demoexit') demoExit();
  else if (a === 'wload') { wCloseMenu(); $('#file').click(); }
  else if (a === 'wreg') { wSync(); ui.w.region = ui.w.region === arg ? '' : arg; ui.w.page = 0; welcomeHTML(); }
  else if (a === 'wpg') { wSync(); ui.w.page = Math.max(0, (ui.w.page || 0) + (+arg)); welcomeHTML(); }
  else if (a === 'whome') { ui.w = null; welcomeHTML('back'); }
  else if (a === 'wback') { wSync(); const w = ui.w; if (!w.level) { ui.w = null; welcomeHTML('back'); } else if (w.step > 0) { w.step--; welcomeHTML('back'); } else { w.level = null; welcomeHTML('back'); } }
  else if (a === 'wnext') { wSync(); if (arg !== 'skip' && wLocked()) { wBlock(); return; } if (arg === 'skip') wClear(ui.w); if (ui.w.step < wSteps(ui.w).length - 1) { ui.w.step++; welcomeHTML('next'); } }
  else if (a === 'wset') { wSync(); const q = arg.split(':'); ui.w[q[0]] = q[1]; welcomeHTML(); }
  else if (a === 'wcur') { wSync(); const w = ui.w, i = w.cur.indexOf(arg); if (i >= 0) { if (w.cur.length > 1) w.cur.splice(i, 1); } else if (w.cur.length < 2) { w.cur.push(arg); if (w.cur.length === 2) w.rmHint = Date.now(); } w.fx = 0; welcomeHTML(); }
  else if (a === 'wcust') { wSync(); ui.w.customOpen = true; welcomeHTML(); setTimeout(() => { const e = $('#wCust'); if (e) e.focus(); }, 60); }
  else if (a === 'wswap') { wSync(); const w = ui.w; w.cur.reverse(); w.fx = w.fx > 0 ? Number((1 / w.fx).toPrecision(4)) : 0; welcomeHTML(); }
  else if (a === 'wfin') wFinish(arg === 'skip');
  else if (a === 'insights') { ui.insHalf = false; ui.insMk = arg || ''; openItem('insights', 'x'); }
  else if (a === 'inshalf') { ui.insHalf = true; openItem('insights', 'x'); }
  else if (a === 'dbgplat') { try { if (arg === 'auto') localStorage.removeItem('plata.platform'); else localStorage.setItem('plata.platform', arg); } catch (e) { /* sin almacenamiento */ } persist(); setTimeout(() => location.reload(), 120); }
  else if (a === 'dbgview') { try { if (arg === 'auto') localStorage.removeItem('plata.view'); else localStorage.setItem('plata.view', arg); } catch (e) { /* sin almacenamiento */ } persist(); setTimeout(() => location.reload(), 120); }
  else if (a === 'dbgtheme') { window.__applyTheme(arg); try { if (data && data.settings) { data.settings.theme = arg === 'auto' ? '' : arg; persist(); } } catch (e) { /* sin perfil */ } renderCuenta(); }
  else if (a === 'dbglang') { data.settings.lang = arg === 'auto' ? '' : arg; persist(); applyLang(); renderAll(); renderCuenta(); }
  else if (a === 'dbgmenu') { ui.dbgOpen = !ui.dbgOpen; renderCuenta(); }
  else if (a === 'transp') { openTransp(); }
  else if (a === 'credits') { ui.dbgOpen = false; ui.itemKind = 'credits'; renderCuenta(); navSlide('push'); }
  else if (a === 'pickphoto') pickPhoto(ui.w ? 'w' : 'p');
  else if (a === 'cropphoto') cropAgain();
  else if (a === 'rmphoto') { if (ui.w) { delete ui.w.photo; delete ui.w.photoSrc; delete ui.w.photoCrop; const b = document.getElementById('wphoto'); if (b) b.innerHTML = wPhotoHTML(); } else { delete data.settings.photo; delete data.settings.photoSrc; delete data.settings.photoCrop; ui.dirty++; persist(); renderAll(); toast('Foto quitada'); } }
  else if (a === 'profile') openProfile();
  else if (a === 'profedit') { ui.profEdit = true; ui.profSkip = 0; refreshProf(); const sc = document.querySelector('#sheet .pscroll'); if (sc) sc.scrollTop = 0; }
  else if (a === 'profview') { ui.profEdit = false; ui.profSkip = 0; refreshProf(); }
  else if (a === 'tourtog') { const on = !tourOn(); data.settings.tour = { on: on, seen: {} }; persist(); renderAll(); tourTick(); toast(on ? 'Tutorial activado' : 'Tutorial desactivado'); }
  else if (a === 'proftog') { data.settings.showGrades = !gradesShown(); ui.dirty++; persist(); renderAll(); }
  else if (a === 'wclose') window.winClose();
  else if (a === 'itback') { if (ui.itemKind === 'imp') impBack(); else if (ui.itemKind === 'credits' || ui.itemKind === 'transp' || ui.itemKind === 'profile') { ui.itemKind = 'settings'; renderCuenta(); navSlide('pop'); } else itemBackNav(); }
  else if (a === 'itedit') openForm(ui.itemKind, ui.itemId);
  else if (a === 'itdel') itemDelete();
  else if (a === 'itconf') { ui.confirmPick = { k: ui.itemKind === 'expense' ? 'out' : 'in', id: ui.itemId }; ui.skipPending = false; const h = confirmHTML(); if (h) showSheet(h); }
  else if (a === 'ittoday') { const e = data[ui.itemKind === 'expense' ? 'expected_expense' : 'expected_income'].find((x) => x.id === ui.itemId); if (e) { e.date = iso(getToday()); delete e.snooze; ui.dirty++; persist(); renderAll(); toast('Adelantado a hoy'); } }
  else if (a === 'tx') openTx(arg);
  else if (a === 'swedit' || a === 'swpost' || a === 'swdel') swAct(a, arg);
  else if (a === 'pxconf' || a === 'pxedit' || a === 'pxdel' || a === 'pxcontrib' || a === 'pxadd' || a === 'pxhide') pxAct(a, arg);
  else if (a === 'cldbg') { const t = Date.now(); CL.taps = (CL.taps || []).filter((x) => t - x < 2500); CL.taps.push(t); if (CL.taps.length >= 4) { CL.taps = []; const on = !nazcaOn(); try { localStorage.setItem('plata.nazca', on ? '1' : '0'); } catch (e) { /* sin almacenamiento */ } toast(on ? 'Nazca activado' : 'Nazca desactivado'); try { renderAll(); } catch (e) { /* aún sin pantalla */ } } }
  else if (a === 'cl') clAct(arg, el);
  else if (a === 'cloudjoin') cloudJoin(el);
  else if (a === 'cloudstrip') { const s = $('#cloudStrip'); if (s) { s.classList.add('open'); const i = s.querySelector('input'); if (i) i.focus(); } }
  else if (a === 'cloudstripx') { try { localStorage.setItem('plata.cloudstrip', '1'); } catch (e) { /* sin almacenamiento */ } document.querySelectorAll('.cstrip').forEach((x) => x.remove()); }
  else if (a === 'mmin') { ui.mm = { mk: iso(getToday()).slice(0, 7), f: 'in', page: 0 }; openItem('month', 'x'); }
  else if (a === 'month') { ui.mm = { mk: iso(getToday()).slice(0, 7), f: 'all', page: 0 }; openItem('month', 'x'); }
  else if (a === 'mmf') { if (ui.mm) { ui.mm.f = arg; ui.mm.page = 0; setSeg(el); mmRefresh(); } }
  else if (a === 'mmp') { if (ui.mm) { ui.mm.page = (ui.mm.page || 0) + Number(arg); mmRefresh(); } }
  else if (a === 'mmpick') showSheet(mmPickHTML());
  else if (a === 'mmset') { ui.mm = { mk: arg, f: 'all', page: 0 }; closeSheet(); renderCuenta(); document.querySelectorAll('.screen').forEach((sc) => { sc.scrollTop = 0; }); }
  else if (a === 'txback') txBackNav();
  else if (a === 'txedit') { const t = txById(ui.txId); if (t && !isXfer(t)) { ui.confirmId = null; ui.form = null; showSheet(txEditHTML(t)); } }
  else if (a === 'txsave') txSave();
  else if (a === 'txpost') { const t = txById(ui.txId); if (t) { ui.txEditId = t.id; ui.form = null; ui.confirmId = null; showSheet(postponeHTML(t)); } }
  else if (a === 'txpp') { const i = $('#fDate'); if (i) i.value = iso(addDays(getToday(), Number(arg))); }
  else if (a === 'txpdo') txPostpone();
  else if (a === 'txdel') txDelete();
  else if (a === 'movin') { ui.mov = 'in'; renderMovimientos(); setTab('movimientos'); }
  else if (a === 'nextitem') { const q = arg.split(':'); openNextItem(q[0], q[1]); }
  else if (a === 'nxconf') { const q = arg.split(':'); ui.confirmPick = { k: q[0], id: q[1] }; ui.skipPending = false; const h = confirmHTML(); if (h) { showSheet(h); } }
  else if (a === 'nxtoday') { const q = arg.split(':'), e = data[q[0] === 'out' ? 'expected_expense' : 'expected_income'].find((x) => x.id === q[1]); if (e) { e.date = iso(getToday()); delete e.snooze; ui.dirty++; persist(); renderAll(); closeSheet(); toast('Adelantado a hoy'); } }
  else if (a === 'apsw') { const k = data.cards.find((x) => x.id === ui.sheetAcc); if (!apOK(k)) { toast('Añade el día de pago a la tarjeta'); return; } ui.sheetAuto = !ui.sheetAuto; $('#apWrap').innerHTML = apRowHTML(); }
  else if (a === 'apcard') {
    const k = data.cards.find((x) => x.id === arg); if (!k) return;
    if (k.auto) delete k.auto;
    else if (apOK(k)) { const fa = data.accounts.find((x) => x.cur === k.cur) || data.accounts[0]; k.auto = { from: fa ? fa.id : '', next: dueAfter(k.due_day, iso(getToday())) }; }
    else { toast('Añade el día de pago a la tarjeta'); return; }
    ui.dirty++; persist(); renderAll(); toast(k.auto ? 'Pago esperado activado' : 'Pago esperado desactivado');
  }
  else if (a === 'payconf') { ui.confirmPick = { k: 'pay', id: arg }; ui.skipPending = false; openConfirm(); }
  else if (a === 'setopt') {
    const cur = arg === 'insights' ? insOn() : scoreOn(); data.settings[arg] = !cur; ui.dirty++; persist(); renderAll();
  }
  else if (a === 'wtog') { wSync(); const w = ui.w; if (arg === 'ins') { w.ins = !(w.ins !== false); } else w.score = !(w.score !== false); welcomeHTML(); }
  else if (a === 'toggle') { if (swSwallow) { swSwallow = false; return; } setVariable(!ui.variable, el); }
  else if (a === 'dbg') {
    demoEnter(); data = migrate(clone(demoData(arg))); data.demo = true; ui.dirty = 0; ui.week = 8; ui.calMonth = 0; ui.calSel = null; persist(); closeSheet(); leaveSettings(); renderAll();
    document.querySelectorAll('.screen').forEach((sc) => { sc.scrollTop = 0; }); setTab('resumen'); toast('Perfil ' + arg + ' · ' + DBG[arg].nick); setTimeout(checkPending, 900);
  }
  else if (a === 'demo' || a === 'wipe' || a === 'wipehome') {
    if (a === 'demo') { showSheet(demoSheetHTML()); return; }
    const run = () => {
      if (a === 'wipehome') wMark(false);
      if (a === 'demo') demoEnter();
      data = migrate(clone(a === 'demo' ? demoData('S') : EMPTY)); if (a === 'demo') data.demo = true; ui.dirty = 0; ui.week = 8; ui.calMonth = 0; ui.calSel = null;
      persist(); closeSheet(); leaveSettings(); renderAll(); document.querySelectorAll('.screen').forEach((sc) => { sc.scrollTop = 0; }); setTab('resumen');
      toast(a === 'demo' ? 'Perfil de demostración cargado' : 'Datos borrados'); if (a === 'demo') setTimeout(checkPending, 900);
      if (a === 'wipehome') showWelcome();
    };
    if (a !== 'demo' && data && data.demo) { demoExit(); return; }
    if (!hasData() || (a === 'demo' && data.demo)) { run(); return; }
    if (a !== 'demo' && clBeta() && clIn() && CL.st.mode === 'cloud' && CL.st.rev) { clWipeAsk(a, run); return; }
    if (a === 'demo') askConfirm('¿Cargar perfil de demostración?', 'Tus datos reales se guardan aparte y los recuperas al salir del demo.', [{ label: 'Cargar perfil de demostración', dest: true, fn: run }]);
    else askConfirm(a === 'wipe' ? '¿Borrar todos tus datos?' : '¿Borrar datos y volver al inicio?', 'Esta acción no se puede deshacer. Guarda tu archivo de perfil antes si quieres conservarlos.', [{ label: a === 'wipe' ? 'Borrar datos' : 'Borrar y regresar al inicio', dest: true, fn: run }]);
  }
});
document.addEventListener('input', (e) => {
  if (e.target && (e.target.id === 'fAmount' || e.target.id === 'fHero')) { e.target.style.width = amtW(e.target.value, e.target.placeholder); if (ui.confirmId) updConfirmDelta(); updTax(); }
  if (e.target && (e.target.id === 'cHrs' || e.target.id === 'fHrs')) updTax();
  if (e.target && e.target.getAttribute && e.target.getAttribute('data-f') === 'name' && ui.form && FORMS[ui.form.kind].style) { ui.form.obj.name = e.target.value; updPrev(); }
  if (e.target && e.target.id === 'cpick' && ui.form) {
    syncForm(); ui.form.obj.color = e.target.value; ui.form.obj.colorUser = true;
    document.querySelectorAll('#sheet .sw').forEach((b) => b.classList.remove('on'));
    $('#swc').classList.add('on'); $('#swci').style.background = e.target.value; updPrev();
  }
  if (e.target && e.target.id === 'extraRange') { ui.extra = Number(e.target.value); updSim(); }
  if (e.target && e.target.id === 'weekRange') { snapStop(); ui.week = Number(e.target.value); updateProjection(true); }
});
document.addEventListener('change', (e) => {
  const id = e.target && e.target.id;
  ui.profSkip = e.target && e.target.tagName === 'INPUT' ? 1 : 0;
  if (id === 'wOther') { const v = e.target.value; if (v && ui.w) { wSync(); const w = ui.w; if (w.cur.indexOf(v) < 0) { if (w.cur.length < 2) w.cur.push(v); else w.cur[1] = v; } w.fx = 0; welcomeHTML(); } return; }
  if (id === 'fFrom') { ui.sheetFrom = e.target.value; return; }
  if (id === 'fAcc') { ui.sheetAcc = e.target.value; $('#fSym').textContent = symOf(accOf(ui.sheetAcc).cur).trim(); { const fa = $('#fAmount'); if (fa) fa.placeholder = decOf(accOf(ui.sheetAcc).cur) ? '0.00' : '0'; } if (ui.sheetType === 'pay' && $('#apWrap')) { ui.sheetAuto = false; $('#apWrap').innerHTML = apRowHTML(); } return; }
  if (e.target && e.target.getAttribute && e.target.getAttribute('data-f') && ui.form) {
    const k = e.target.getAttribute('data-f');
    if (k === 'acc' || k === 'sav') { syncForm(); $('#fSym').textContent = symOf(formCur(FORMS[ui.form.kind], ui.form.obj)).trim(); }
    return;
  }
  if (id === 'sCust') { setCustomCur(e.target.value); return; }
  if (id === 'sCur1') { const v = e.target.value; applyCurrencies(v, v === curS() ? curP() : curS()); return; }
  if (id === 'sCur2') { applyCurrencies(curP(), e.target.value); return; }
  if (id === 'sFlow') { data.settings.bflow = e.target.value; ui.dirty++; persist(); renderAll(); toast('Ajuste guardado'); return; }
  if (id === 'sHemi') { data.settings.hemi = e.target.value; ui.dirty++; persist(); renderAll(); toast('Ajuste guardado'); return; }
  if (id === 'sLang') { const v = e.target.value; data.settings.lang = v === 'auto' ? '' : v; ui.dirty++; persist(); applyLang(); renderAll(); toast('Ajuste guardado'); return; }
  if (id === 'sGen') { data.settings.gender = e.target.value; ui.dirty++; persist(); renderAll(); toast('Ajuste guardado'); return; }
  const nmap = { sFirst: 'first', sLast: 'last', sNick: 'nick' };
  if (nmap[id]) { data.settings[nmap[id]] = String(e.target.value).trim(); ui.dirty++; persist(); renderAll(); toast('Ajuste guardado'); return; }
  const map = { sVar: 'variable_weekly', sCush: 'cushion', sFx: 'fx' };
  if (!map[id]) return;
  const v = parseFloat(String(e.target.value).replace(',', '.'));
  if (!(v >= 0) || (id === 'sFx' && !(v > 0))) { toast('Valor no válido'); return; }
  data.settings[map[id]] = v;
  ui.dirty++; persist(); renderAll(); toast('Ajuste guardado');
});

/* slider gelatina: resorte mientras se mantiene presionada la perilla */
(function () {
  const st = new WeakMap();
  function frame(rg, S, t) {
    const dt = Math.min(.032, (t - S.t) / 1000 || .016); S.t = t;
    const w = rg.clientWidth - 38, mn = Number(rg.min) || 0, mx = Number(rg.max) || 1;
    const pos = (Number(rg.value) - mn) / ((mx - mn) || 1) * w;
    const vel = S.down ? (pos - S.pos) / dt : 0; S.pos = pos; S.fv += (vel - S.fv) * .35;
    const sp = Math.min(1, Math.abs(S.fv) / 900);
    const T = S.down ? { sx: 1.5 + .1 * sp, sy: 1.55 - .06 * sp, tx: Math.max(-3.5, Math.min(3.5, -S.fv * .004)) } : { sx: 1, sy: 1, tx: 0 };
    let rest = !S.down;
    ['sx', 'sy', 'tx'].forEach((k) => {
      const a = (T[k] - S[k]) * 620 - S[k + 'v'] * 34;
      S[k + 'v'] += a * dt; S[k] += S[k + 'v'] * dt;
      if (Math.abs(T[k] - S[k]) > .004 || Math.abs(S[k + 'v']) > .05) rest = false;
    });
    rg.style.setProperty('--sx', S.sx.toFixed(3)); rg.style.setProperty('--sy', S.sy.toFixed(3)); rg.style.setProperty('--tx', S.tx.toFixed(2) + 'px');
    rg.style.setProperty('--ga', (.35 + (S.sx - 1) * .0).toFixed(2));
    if (rest) { rg.classList.remove('jel', 'rel'); ['--sx', '--sy', '--tx', '--ga'].forEach((k) => rg.style.removeProperty(k)); S.raf = 0; return; }
    S.raf = requestAnimationFrame((tt) => frame(rg, S, tt));
  }
  function down(e) {
    const rg = e.target; if (!rg || rg.type !== 'range') return;
    let S = st.get(rg); if (!S) { S = { sx: 1, sy: 1, tx: 0, sxv: 0, syv: 0, txv: 0, fv: 0, pos: 0, t: performance.now(), raf: 0 }; st.set(rg, S); }
    S.down = true; S.t = performance.now(); rg.classList.remove('rel'); rg.classList.add('jel');
    const w = rg.clientWidth - 38; S.pos = (Number(rg.value) - (Number(rg.min) || 0)) / (((Number(rg.max) || 1) - (Number(rg.min) || 0)) || 1) * w;
    if (!S.raf) S.raf = requestAnimationFrame((tt) => frame(rg, S, tt));
  }
  function up() { document.querySelectorAll('input[type=range].jel').forEach((rg) => { const S = st.get(rg); if (S) S.down = false; rg.classList.add('rel'); }); }
  document.addEventListener('pointerdown', down, true);
  document.addEventListener('pointerup', up, true); document.addEventListener('pointercancel', up, true);
})();

/* .sw2: arrastrar para cambiar, igual que el de Proyección */
(function () {
  let d = null, swallow = false;
  document.addEventListener('pointerdown', (e) => {
    const b = e.target.closest && e.target.closest('.sw2'); if (!b || b.classList.contains('dis')) { d = null; return; }
    d = { b: b, act: b.getAttribute('data-act'), x: e.clientX, done: false };
  }, true);
  document.addEventListener('pointermove', (e) => {
    if (!d || d.done) return;
    const dx = e.clientX - d.x; if (Math.abs(dx) < 10) return;
    const b = d.b.isConnected ? d.b : document.querySelector('.sw2[data-act="' + d.act + '"]'); if (!b) return;
    d.done = true;
    if ((dx > 0) !== b.classList.contains('on')) b.click();
    swallow = true; setTimeout(() => { swallow = false; }, 450);
  });
  document.addEventListener('pointerup', () => { d = null; }, true);
  document.addEventListener('pointercancel', () => { d = null; }, true);
  document.addEventListener('click', (e) => {
    if (swallow && e.isTrusted && e.target.closest && e.target.closest('.sw2')) { swallow = false; e.stopPropagation(); e.preventDefault(); }
  }, true);
})();
/* Selector segmentado: al mantener presionado el seleccionado se vuelve lente de cristal y se puede arrastrar */
(function () {
  let sg = null;
  const mk = (e) => {
    const seg = e.target.closest && e.target.closest('.seg'); if (!seg || e.button > 0) return null;
    const bs = [].slice.call(seg.querySelectorAll('button')), cur = bs.findIndex((b) => b.classList.contains('on')); if (cur < 0 || !e.target.closest('button.on')) return null;
    const th = seg.querySelector('.thumb'), k = seg.getBoundingClientRect().width / (seg.offsetWidth || 1) || 1;
    return { seg: seg, bs: bs, cur: cur, tw: th.offsetWidth, k: k, x0: e.clientX, dx: 0, moved: false, id: e.pointerId };
  };
  document.addEventListener('pointerdown', (e) => {
    sg = mk(e); if (!sg) return;
    sg.seg.classList.add('glass');
    try { sg.seg.setPointerCapture(e.pointerId); } catch (err) { /* sin captura */ }
  });
  document.addEventListener('pointermove', (e) => {
    if (!sg || e.pointerId !== sg.id) return;
    const d = (e.clientX - sg.x0) / sg.k; if (!sg.moved && Math.abs(d) < 4) return;
    sg.moved = true; sg.seg.classList.add('drag');
    sg.dx = clamp(d, -sg.cur * sg.tw, (sg.bs.length - 1 - sg.cur) * sg.tw);
    sg.seg.style.setProperty('--dx', sg.dx.toFixed(1) + 'px');
  });
  const end = (e) => {
    if (!sg || (e && e.pointerId !== sg.id)) return;
    const s2 = sg; sg = null;
    const j = clamp(Math.round(s2.cur + s2.dx / s2.tw), 0, s2.bs.length - 1);
    s2.seg.classList.remove('drag', 'glass');
    if (s2.moved) {
      s2.seg.style.setProperty('--dx', '0px');
      if (j !== s2.cur) { s2.seg.style.setProperty('--i', j); s2.bs.forEach((b, i) => b.classList.toggle('on', i === j)); const bt = s2.bs[j]; setTimeout(() => { bt.click(); }, 30); }
      const sw = (ev) => { ev.stopPropagation(); ev.preventDefault(); }; document.addEventListener('click', sw, true); setTimeout(() => document.removeEventListener('click', sw, true), 0);
    }
  };
  document.addEventListener('pointerup', end);
  document.addEventListener('pointercancel', end);
})();
let snapRaf = 0;
function snapStop() { if (snapRaf) { cancelAnimationFrame(snapRaf); snapRaf = 0; } }
document.addEventListener('change', (e) => {
  if (!e.target || e.target.id !== 'weekRange') return;
  snapStop();
  const from = ui.week, to = Math.round(from), t0 = performance.now(), rg = e.target;
  const tick = (t) => {
    const k = Math.min(1, (t - t0) / 240), ease = 1 - Math.pow(1 - k, 3);
    ui.week = from + (to - from) * ease; rg.value = String(ui.week); updateProjection(true);
    snapRaf = k < 1 ? requestAnimationFrame(tick) : 0;
  };
  snapRaf = requestAnimationFrame(tick);
});
$('#clfile').addEventListener('change', async (e) => { const f = e.target.files && e.target.files[0]; e.target.value = ''; if (f) clFileChosen(f); });
$('#file').addEventListener('change', async (e) => {
  const f = e.target.files && e.target.files[0];
  if (!f) return;
  try {
    const nd = migrate(JSON.parse(await f.text())), go = () => { data = nd; stampSaved(); ui.dirty = 0; persist(); closeSheet(); leaveSettings(); renderAll(); if ($('#welcome')) { setTab('resumen'); hideWelcome(); } toast('Archivo de perfil cargado'); setTimeout(checkPending, 900); };
    if (anRead(nd)) askConfirm('Archivo de perfil analizado', 'Una copia de este archivo de perfil fue analizada para entender cómo se usa Plata y mejorarla.', [{ label: 'Cargar archivo', dest: true, fn: go }, { label: 'Más información', fn: () => openTransp(true) }]);
    else go();
  } catch (err) { toast('No pude leer ese archivo de perfil'); }
  e.target.value = '';
});

