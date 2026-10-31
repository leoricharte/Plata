/* ---------- Recurrentes: mismo comercio, ritmo regular y monto estable, sumando todas las cuentas ---------- */
const REC_STOP = new Set(['pos', 'purchase', 'debit', 'card', 'visa', 'checkcard', 'compra', 'pago', 'payment', 'recurring', 'www', 'com', 'inc', 'llc', 'des', 'the', 'ach', 'web', 'online', 'pmt', 'sq', 'tst', 'mktp']);
const REC_NAME = { openai: 'ChatGPT', 'twitter-x': 'X', copilot: 'GitHub Copilot', applemusic: 'Apple Music', appletv: 'Apple TV', icloud: 'iCloud', youtube: 'YouTube', github: 'GitHub', linkedin: 'LinkedIn', playstation: 'PlayStation', xbox: 'Xbox', switch: 'Nintendo Switch Online', 'cursor-ai': 'Cursor', soundcloud: 'SoundCloud', amazon: 'Amazon Prime', google: 'Google One', microsoft: 'Microsoft 365', meta: 'Meta' };
const REC_BILLS = new Set(['Servicios', 'Hogar', 'Casa', 'Alquiler', 'Estudios']), REC_P2P = /^(venmo|zelle|yape|plin|cash|paypal|cambio|exchange|transfer|retiro|deposito)\b/;
const recTitle = (w) => w.map((x) => x.charAt(0).toUpperCase() + x.slice(1)).join(' ');
const recWords = (t) => bankNorm(t).replace(/\s(id|indn|ppd|ccd|ref|conf)\b.*$/, ' ').replace(/[^a-z ]+/g, ' ').split(/\s+/).filter((w) => w.length >= 2 && !REC_STOP.has(w)).slice(0, 3);
const recKey = (t) => { const b = subBrand({ name: t }); if (b) return 'b:' + b.i; return recWords(t).join(' '); };
const recDays = (a, b) => Math.round((pd(b) - pd(a)) / 864e5);
const recMed = (v) => { const x = v.slice().sort((a, b) => a - b); return x[Math.floor(x.length / 2)]; };
function recFind(T, used) {
  /* lo que ya registraste (suscripciones, trabajos, ingresos y gastos previstos): se compara por nombre, por palabras parecidas y por monto + día */
  const mine = [];
  const addM = (o, neg, amt, day, cur) => { if (!o || !o.name) return; mine.push({ k: recKey(o.name), w: new Set(bankNorm(o.name).replace(/[^a-z ]+/g, ' ').split(/\s+/).filter((x) => x.length >= 4 && !REC_STOP.has(x))), neg: neg, amt: Math.abs(Number(amt) || 0), day: day, cur: cur }); };
  const dom = (d, rep) => (d && (!rep || rep === 'm') ? +String(d).slice(8, 10) || 0 : 0);
  data.subs.forEach((x) => addM(x, true, x.amount, x.day, x.cur));
  data.expected_expense.forEach((x) => addM(x, true, x.amount, dom(x.date, x.repeat), accOf(x.acc).cur));
  data.expected_income.forEach((x) => addM(x, false, x.amount, dom(x.date, x.repeat), accOf(x.acc).cur));
  data.jobs.forEach((x) => addM(x, false, jobNet(x), 0, accOf(x.acc).cur));
  (data.recurring || []).forEach((x) => addM(x, x.amount < 0, x.amount, x.day, curP()));
  const dayNear = (a, b) => { const d = Math.abs(a - b); return Math.min(d, 31 - d) <= 4; };
  const mapped = (o, m, cur, day, tl) => mine.some((e) => (e.k && e.k === o.k) || (e.neg === o.neg && ((o.k.slice(0, 2) !== 'b:' && o.words.some((w) => e.w.has(w))) || (e.amt > 0 && (!e.cur || e.cur === cur) && Math.abs(e.amt - m) <= Math.max(0.5, m * tl) && (!e.day || dayNear(e.day, day))))));
  const G = {}; let ref = '';
  T.forEach((t) => {
    if (t.date > ref) ref = t.date;
    if (used.has(t.id) || isPay(t) || t.pair || t.job || !t.note || (t.amount < 0 && txSub(t))) return;
    const k = recKey(t.note); if (!k) return;
    const g = (t.amount < 0 ? '-' : '+') + k; (G[g] = G[g] || { k: k, neg: t.amount < 0, tx: [] }).tx.push(t);
  });
  const out = [];
  Object.keys(G).forEach((g) => {
    const o = G[g]; o.words = o.k.split(' ').filter((x) => x.length >= 4);
    const seen = {}, L = []; o.tx.sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : 0)).forEach((t) => { if (!seen[t.date]) { seen[t.date] = 1; L.push(t); } });
    const n = L.length, cur = accOf(L[0].acc).cur; if (n < 2 || L.some((t) => accOf(t.acc).cur !== cur)) return;
    const gaps = []; for (let i = 1; i < n; i++) gaps.push(recDays(L[i - 1].date, L[i].date));
    const med = recMed(gaps), cad = med >= 5 && med <= 9 ? 'w' : med >= 12 && med <= 17 ? 'b' : med >= 26 && med <= 35 ? 'm' : ''; if (!cad) return;
    const win = { w: [5, 9], b: [12, 17], m: [26, 35] }[cad]; if (gaps.filter((x) => x >= win[0] && x <= win[1]).length / gaps.length < 0.75) return;
    const amts = L.map((t) => Math.abs(t.amount)), m = recMed(amts); if (m < 1) return;
    const fixed = amts.every((a) => Math.abs(a - m) <= Math.max(0.5, m * 0.05)), brand = o.k.slice(0, 2) === 'b:';
    /* monto que varía: solo cuentas de la casa (luz, internet…) con hasta 35%; un sueldo con horas extra hasta 15%. Café, restaurantes o súper no son gastos fijos */
    const loose = amts.every((a) => Math.abs(a - m) <= m * (o.neg ? 0.35 : 0.15)) && (!o.neg || L.every((t) => REC_BILLS.has(t.category)));
    if (!fixed && !(loose && cad === 'm')) return;
    if (!brand && REC_P2P.test(o.k)) return;   /* plata de amigos o cambios de moneda no son un trabajo ni un gasto fijo */
    if (n < (cad === 'm' ? (brand && fixed ? 2 : 3) : 4)) return;
    if (recDays(L[n - 1].date, ref) > med * 1.7 + 3) return;
    if (mapped(o, m, cur, +L[n - 1].date.slice(8, 10), fixed ? 0.05 : 0.15)) return;
    let q = null, cd = cad;
    if (!o.neg && cad === 'b') {
      const dy = L.map((t) => +t.date.slice(8, 10)), A = dy.filter((x) => x >= 13 && x <= 17), B = dy.filter((x) => x >= 27 || x <= 2);
      if (A.length && B.length && A.length + B.length === dy.length) { cd = 'q'; q = [recMed(A), B.every((x) => x >= 27) ? 30 : recMed(B.map((x) => (x <= 2 ? 30 : x)))]; }
    }
    const accs = {}; L.forEach((t) => { accs[t.acc] = (accs[t.acc] || 0) + 1; });
    const acc = Object.keys(accs).sort((a, b) => accs[b] - accs[a])[0], bd = brand ? SUBBRANDS.find((x) => x.i === o.k.slice(2)) : null;
    const type = !o.neg ? 'job' : brand && cad === 'm' ? 'sub' : 'fix';
    const name = bd ? (REC_NAME[bd.i] || recTitle(bd.keys[0].split(' '))) : recTitle(o.k.split(' '));
    out.push({ kind: 'rec', type: type, k: 'rec:' + g, txs: L, name: name, amt: round2(m), fixed: fixed, cad: cd, cur: cur, q: q, acc: acc, brand: bd, neg: o.neg, score: type === 'job' ? 6000 : type === 'sub' ? 6100 : 6200 });
  });
  return out;
}
const revCount = () => { try { return revScan().length; } catch (e) { return 0; } };
