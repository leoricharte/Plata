/* ---------- Cálculos ---------- */
function calc() {
  const today = getToday();
  const mk = iso(today).slice(0, 7);
  const tx = data.transactions.slice().sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : (b.id || 0) - (a.id || 0)));
  const monthTx = tx.filter((t) => t.date.slice(0, 7) === mk);
  const flowTx = monthTx.filter((t) => !isPay(t));
  const incTx = flowTx.filter((t) => t.amount > 0);
  const income = sum(incTx, txUSD);
  const expense = -sum(flowTx.filter((t) => t.amount < 0), txUSD);
  const catTot = {};
  let subSpent = 0; /* cobros de suscripciones: van aparte del presupuesto */
  flowTx.filter((t) => t.amount < 0).forEach((t) => {
    if (txSub(t)) { subSpent -= txUSD(t); return; }
    const c = CAT_ORDER.indexOf(t.category) >= 0 ? t.category : 'Otros';
    catTot[c] = (catTot[c] || 0) - txUSD(t);
  });
  const cats = CAT_ORDER.filter((c) => catTot[c] > 0).map((c) => ({ name: c, v: catTot[c], color: CAT_COLOR[c] }));
  const months = data.history.slice().sort((a, b) => (a.month < b.month ? -1 : 1)).slice(-5)
    .map((h) => ({ label: MON[Number(h.month.slice(5, 7)) - 1], income: h.income, expense: h.expense, cur: false }));
  months.push({ label: MON[today.getMonth()], income: income, expense: expense, cur: true });
  const balance = sum(data.accounts, (a) => usd(a.balance, a.cur));
  const cards = data.cards.map((c, i) => {
    const ub = usd(c.balance, c.cur);
    return Object.assign({}, c, { ub: ub, color: c.color || CARD_COLORS[i % CARD_COLORS.length], util: c.limit > 0 ? Math.round((c.balance / c.limit) * 100) : 0, interest: (ub * c.apr) / 100 / 12 });
  });
  const savings = data.savings.map((s, i) => Object.assign({}, s, { ub: usd(s.balance, s.cur), color: s.color || CARD_COLORS[(i + 3) % CARD_COLORS.length] }));
  const dim = new Date(today.getFullYear(), today.getMonth() + 1, 0).getDate();
  const budgetTotal = sum(CAT_ORDER, (k) => budOf(activeSet())[k] || 0);
  const subsTotal = sum(data.subs, (s) => usd(s.amount, s.cur));
  data.subHist = data.subHist || {}; data.subHist[mk] = round2(subsTotal); /* foto mensual del total de suscripciones */
  return {
    today: today, mk: mk, dim: dim, tx: tx, monthTx: monthTx, income: income, expense: expense, incomeCount: incTx.length, cats: cats, catTot: catTot, months: months,
    balance: balance, cards: cards, debt: sum(cards, (c) => c.ub), interest: sum(cards, (c) => c.interest),
    savings: savings, saved: sum(savings, (s) => s.ub), savedMonthly: sum(data.savings, (s) => usd(s.monthly || 0, s.cur)),
    budgetTotal: budgetTotal, subsTotal: subsTotal, expV: expense - subSpent, subSpent: subSpent
  };
}

/* ---- Sets de presupuesto: límites distintos entre dos fechas ---- */
const bsets = () => data.budgetSets || (data.budgetSets = []);
function activeSet() { const t = iso(getToday()); return bsets().filter((b) => b.from <= t && b.to >= t).sort((a, b) => (a.from < b.from ? 1 : -1))[0] || null; }
function viewSet() { if (ui.bsel === 'base') return null; const b = ui.bsel ? bsets().find((x) => x.id === ui.bsel) : null; return b || activeSet(); }
const budOf = (b) => (b ? b.budget : data.budget);
/* moneda del set: los límites se guardan en moneda principal; el set solo decide en cuál se ven y se editan */
const bsCurOf = () => { const v = viewSet(); return v && v.cur && v.cur === curS() ? v.cur : curP(); };
const bfmt = (n) => { const c = bsCurOf(); return c === curP() ? fmt(n) : fmtC(fromUSD(n, c), c); };
const allBuds = () => [data.budget].concat(bsets().map((b) => b.budget));
const EVKEY = {};
function genEvents(today, o) {
  const end = addDays(today, 371), ev = [];
  const monthly = (day, fn) => {
    for (let k = 0; k <= 13; k++) {
      const base = new Date(today.getFullYear(), today.getMonth() + k, 1);
      const last = new Date(base.getFullYear(), base.getMonth() + 1, 0).getDate();
      const d = new Date(base.getFullYear(), base.getMonth(), Math.min(day, last));
      if (d > today && d <= end) fn(d);
    }
  };
  /* key identifica cada ocurrencia (origen + fecha original) para poder editarla o saltarla sin tocar la serie */
  data.recurring.forEach((r, ri) => monthly(r.day || 1, (d) => ev.push({ date: d, name: r.name, amt: r.amount, type: 'rec', key: 'rec:' + ri + ':' + iso(d), cur: curP(), a0: r.amount })));
  data.subs.forEach((s) => monthly(s.day || 1, (d) => ev.push({ date: d, name: s.name, amt: -usd(s.amount, s.cur), type: 'sub', key: 'sub:' + s.id + ':' + iso(d), form: 'sub', srcId: s.id, cur: s.cur, a0: -s.amount })));
  /* El pago mensual de una tarjeta o préstamo termina cuando se acaba la deuda: cada mes se suma el interés (APR/12) a lo que se debe y
     el cobro es el menor entre el pago y esa deuda. Con deuda 0 no hay cobros; la última cuota sale por lo que queda. */
  data.cards.forEach((c) => {
    if (!(c.payment > 0)) return;
    let bal = Number(c.balance) || 0;
    const rate = (Number(c.apr) || 0) / 1200;
    monthly(c.due_day || 1, (d) => {
      if (!(bal > 0.005)) return;
      const owed = round2(bal * (1 + rate)), pay = Math.min(c.payment, owed);
      bal = round2(owed - pay);
      ev.push({ date: d, name: 'Pago ' + c.name, amt: -usd(pay, c.cur), type: 'card', key: 'card:' + c.id + ':' + iso(d), form: 'debt', srcId: c.id, cur: c.cur, a0: -pay });
    });
  });
  [[data.expected_income, 1, 'in', 'income'], [data.expected_expense, -1, 'exp', 'expense']].forEach((g) => g[0].forEach((e) => {
    const cur = accOf(e.acc).cur, amt = g[1] * usd(e.amount, cur), mk = (d) => ({ date: d, name: e.name, amt: amt, type: g[2], key: g[2] + ':' + e.id + ':' + iso(d), form: e.card && payOf(e) ? 'cardpay' : g[3], srcId: e.id, cur: cur, a0: g[1] * e.amount });
    let d = pd(e.date), n = 0;
    if (d <= today) ev.push({ date: addDays(today, 1), name: e.name, amt: amt, type: g[2], pending: true, orig: e.date });
    else if (d <= end) ev.push(mk(d));
    if (e.repeat) {
      d = nextRep(d, e.repeat);
      while (d <= today && n++ < 400) d = nextRep(d, e.repeat);
      n = 0;
      while (d <= end && n++ < 400 && !(e.until && iso(d) > e.until)) { ev.push(mk(d)); d = nextRep(d, e.repeat); }
    }
  }));
  data.jobs.forEach((j) => {
    if (!j.sim || (o && o.noSim)) return;
    const cur = accOf(j.acc).cur, net = jobNet(j), r = jobRep(j.freq, j); let d = pd(j.start), n = 0;
    while (d <= today && n++ < 400) d = nextRep(d, r);
    n = 0; while (d <= end && n++ < 400 && !(j.until && iso(d) > j.until)) { ev.push({ date: d, name: j.name + ' (simulado)', amt: usd(net, cur), type: 'sim', key: 'sim:job' + j.id + ':' + iso(d), form: 'job', srcId: j.id }); d = nextRep(d, r); }
  });
  data.planned.forEach((p) => { if (p.on === false || (o && (o.noSim || o.skip === p.id))) return; const d = pd(p.date); if (d > today && d <= end) ev.push({ date: d, name: p.name, amt: p.amount, type: 'sim', key: 'sim:' + p.id, form: 'sim', srcId: p.id }); });
  const OV = data.ovr || {}, res = [];
  ev.forEach((e) => {
    const x = e.key && e.type !== 'sim' ? OV[e.key] : null;
    if (x) {
      if (x.skip) { if (!(o && o.keepSkipped)) return; e.skipped = true; }
      else { if (x.amt != null) e.amt = (e.a0 < 0 ? -1 : 1) * usd(x.amt, e.cur); if (x.date) e.date = pd(x.date); }
      e.edited = true;
    }
    if (e.key) EVKEY[e.key] = e;
    res.push(e);
  });
  return res.sort((a, b) => a.date - b.date);
}

const WEEKS = 52;
function projection() {
  const c = calc();
  const V = ui.variable ? (data.settings.variable_weekly || 0) : 0;
  const events = genEvents(c.today);
  const series = [];
  for (let i = 0; i <= WEEKS; i++) {
    const end = addDays(c.today, 7 * i);
    let s = 0;
    events.forEach((e) => { if (e.date <= end) s += e.amt; });
    series.push({ date: end, v: c.balance + s - V * i });
  }
  let cum = 0;
  const timeline = genEvents(c.today, { keepSkipped: true }).slice(0, 8).map((e) => {
    if (!e.skipped) cum += e.amt;
    const days = Math.round((e.date - c.today) / 86400000);
    return { name: e.name, date: dlabel(e.date), amt: e.amt, type: e.type, key: e.key, edited: !!e.edited, skipped: !!e.skipped, after: c.balance + cum - (V * days) / 7 };
  });
  const minV = Math.min.apply(null, series.map((s) => s.v));
  const firstRed = series.find((s) => s.v < 0);
  return { c, series, timeline, minV, firstRed, V };
}

/* Saldo proyectado día a día (1 año) */
function dailySeries(o) {
  const c = calc(), V = ui.variable ? (data.settings.variable_weekly || 0) : 0, ev = genEvents(c.today, o), out = [];
  let k = 0, cum = 0;
  for (let i = 0; i <= WEEKS * 7; i++) {
    const d = addDays(c.today, i);
    while (k < ev.length && ev[k].date <= d) { cum += ev[k].amt; k++; }
    out.push({ date: d, key: iso(d), v: c.balance + cum - (V * i) / 7 });
  }
  return out;
}
/* Impacto de un gasto simulado entre su fecha y otra (por defecto, el siguiente ingreso) */
function simImpact(p) {
  const ser = dailySeries({}), base = dailySeries({ skip: p.id });
  let end = p.until && p.until > p.date ? p.until : '';
  if (!end) {
    const nx = genEvents(getToday()).find((e) => e.type === 'in' && iso(e.date) > p.date);
    end = nx ? iso(nx.date) : iso(addDays(pd(p.date), 14));
  }
  const win = (a) => a.filter((x) => x.key >= p.date && x.key <= end);
  const w1 = win(ser), w0 = win(base);
  if (!w1.length) return null;
  const lo = (w) => w.reduce((m, x) => (x.v < m.v ? x : m), w[0]);
  const a = lo(w1), b = lo(w0), cushion = data.settings.cushion || 0;
  return { start: p.date, end: end, withMin: a.v, withDate: a.date, withoutMin: b.v, status: a.v < 0 ? 'red' : a.v < cushion ? 'amber' : 'ok' };
}

/* Ingresos previstos pendientes de confirmar (fecha de hoy o anterior) */
function pendingIncomes() {
  const t = iso(getToday());
  return data.expected_income.filter((e) => e.date <= t && !(e.snooze && e.snooze > t)).sort((a, b) => (a.date < b.date ? -1 : 1));
}
function pendingItems() {
  data.cards.forEach((c) => { if (c.auto && !(c.balance > 0.005)) delete c.auto; }); /* deuda pagada: el pago esperado se apaga solo */
  const t = iso(getToday()), f = (l, k) => l.filter((e) => e.date <= t && !(e.snooze && e.snooze > t)).map((e) => ({ k: k, e: e }));
  const pays = data.cards.filter((c) => c.auto && apOK(c) && c.auto.next && c.auto.next <= t && !(c.auto.snooze && c.auto.snooze > t)).map((c) => ({ k: 'pay', e: { id: c.id, name: c.name, date: c.auto.next, card: c } }));
  return f(data.expected_income, 'in').concat(f(data.expected_expense, 'out'), pays).sort((a, b) => (a.e.date < b.e.date ? -1 : 1));
}
/* Un evento editado en Proyección (data.ovr) también cambia lo que se ve en Resumen y al confirmar */
function effItem(kind, e) { const x = (data.ovr || {})[kind + ':' + e.id + ':' + e.date]; if (!x || x.skip) return e; const r = Object.assign({}, e); if (x.amt != null) r.amount = x.amt; if (x.date) r.date = x.date; return r; }
function nextIncome() { return data.expected_income.map((e) => effItem('in', e)).sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : 0))[0]; }

/* Simulador de pago de deudas: se paga el mínimo en todas y lo extra va a la de mayor interés */
function payoff(extra, kind) {
  const ds = data.cards.filter((k) => !kind || kind === 'all' || k.kind === kind).map((k) => ({ b: usd(k.balance, k.cur), r: k.apr / 1200, apr: k.apr, p: k.payment > 0 ? usd(k.payment, k.cur) : Math.max(15, usd(k.balance, k.cur) * 0.02) })).filter((d) => d.b > 0);
  if (!ds.length) return { months: 0, interest: 0, ok: true };
  const pool = sum(ds, (d) => d.p) + extra;
  let interest = 0, m = 0;
  while (m < 600 && ds.some((d) => d.b > 0.005)) {
    m++;
    ds.forEach((d) => { if (d.b > 0) { const i = d.b * d.r; d.b += i; interest += i; } });
    let rest = pool;
    ds.forEach((d) => { const x = Math.min(d.p, d.b); d.b -= x; rest -= x; });
    ds.slice().sort((a, b) => b.apr - a.apr).forEach((d) => { if (rest > 0 && d.b > 0) { const x = Math.min(rest, d.b); d.b -= x; rest -= x; } });
  }
  return { months: m, interest: interest, ok: !ds.some((d) => d.b > 0.005) };
}

