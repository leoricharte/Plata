/* ---------- Arranque ---------- */
(function () {
  const sp = document.getElementById('splash'); if (!sp) return;
  if (/[?&]nosplash/.test(location.search)) { sp.remove(); return; }
  if (!hasData() && !wSeen()) { sp.remove(); return; } // primer arranque: la bienvenida ocupa su lugar
  const hide = () => { sp.classList.add('off'); setTimeout(() => sp.remove(), 700); };
  sp.addEventListener('click', hide); setTimeout(hide, 1500);
})();
if (/[?&]preview/.test(location.search)) document.documentElement.classList.add('preview');
if (/[?&]frame/.test(location.search)) document.documentElement.classList.add('frame');
function fitFrame() {
  const s = document.documentElement.classList.contains('frame') && window.innerWidth >= 600 ? Math.min(1, (window.innerHeight - 48) / 874) : 1;
  document.documentElement.style.setProperty('--s', String(s));
}
window.addEventListener('resize', fitFrame); fitFrame();
function isPhone() { try { return matchMedia('(pointer:coarse)').matches && Math.min(window.innerWidth, window.innerHeight) < 500; } catch (e) { return false; } }
function lockPortrait() {
  const R = document.documentElement;
  let a = 0; try { a = (screen.orientation && typeof screen.orientation.angle === 'number') ? screen.orientation.angle : (typeof window.orientation === 'number' ? window.orientation : 0); } catch (e) { /* sin ángulo */ }
  a = ((a % 360) + 360) % 360;
  const land = window.innerWidth > window.innerHeight && isPhone() && !R.classList.contains('web') && !R.classList.contains('frame');
  R.classList.toggle('lk90', land && a === 90); R.classList.toggle('lk270', land && a === 270);
}
window.addEventListener('resize', lockPortrait); window.addEventListener('orientationchange', () => setTimeout(lockPortrait, 60));
try { if (screen.orientation && screen.orientation.lock) screen.orientation.lock('portrait').catch(() => {}); } catch (e) { /* sin bloqueo */ }
function fitWeb() {
  const root = document.documentElement, q = location.search;
  let fv = ''; try { fv = localStorage.getItem('plata.view') || ''; } catch (e) { /* sin almacenamiento */ }
  const on = fv === 'desktop' ? true : fv === 'mobile' ? false : window.innerWidth >= 900 && !isPhone() && !/[?&](preview|frame|noweb)/.test(q) && !root.classList.contains('frame');
  root.classList.toggle('web', on);
  if (on) { const d = $('#wdate'); if (d) { try { const t = new Date(getToday()).toLocaleDateString(LANG === 'es' ? 'es-PE' : LANG, { weekday: 'long', day: 'numeric', month: 'long' }); d.textContent = t.charAt(0).toUpperCase() + t.slice(1); } catch (e) { d.textContent = ''; } } }
}
window.addEventListener('resize', fitWeb); fitWeb(); lockPortrait();

