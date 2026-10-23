/* ---------- Datos de demostración nativos por idioma ----------
   No se traducen: al cargar la demo en en/ja/it se CREAN datos nuevos (persona, bancos, notas, moneda propios).
   La demo en español (la base) no cambia. fr: sin demo propia (idioma oculto). */
const DEMO_CUR = {
  en: { p: 'USD', s: 'GBP', f: 1 },
  ja: { p: 'JPY', s: 'USD', f: 140 },
  it: { p: 'EUR', s: 'CHF', f: 0.95 },
  sh: { p: 'BAM', s: 'EUR', f: 1.8 }
};
const DEMO_PACK = {
  en: {
    me: { first: 'Jordan', last: 'Hayes', nick: 'Jordan', gender: 'n' },
    t: {
      'Chase Checking': 'Chase Checking', 'Ally Ahorros': 'Ally Savings', 'BCP Soles': 'Wise GBP', 'Efectivo': 'Cash', 'Cuenta principal': 'Main account',
      'Apple Card': 'Apple Card', 'Capital One': 'Capital One', 'Chime Credit Builder': 'Chime Credit Builder', 'Préstamo de estudios': 'Student loan',
      'Gimnasio': 'Gym', 'Plan móvil Perú': 'UK mobile plan',
      'Fondo mudanza SF': 'Moving fund', 'Ahorro Perú': 'London trip', 'Emergencias': 'Emergency fund',
      'Sueldo': 'Paycheck', 'Proyecto Estudio 2²': 'Freelance project', 'Pago freelance Lima': 'UK client payment',
      'Internet': 'Internet', 'Veterinario': 'Vet', 'Vuelo a SF': 'Flight to Seattle', 'Regalos (simulado)': 'Gifts (what-if)', 'Laptop nueva': 'New laptop', 'Alquiler': 'Rent',
      'Supermercado': 'Groceries', 'Café y almuerzo': 'Coffee & lunch', 'Comida de gatos': 'Cat food', 'Suscripción música': 'Music subscription', 'Alquiler de lente': 'Lens rental',
      'Cine y cena': 'Movie & dinner', 'Delivery': 'Delivery', 'Gasolina': 'Gas', 'Regalo': 'Gift', 'Bar': 'Bar', 'Pasajes': 'Bus fare', 'Cena con el equipo': 'Team dinner',
      'Locación de rodaje': 'Shoot location', 'Streaming': 'Streaming', 'Arena y juguetes': 'Litter & toys', 'Software anual': 'Annual software', 'Alquiler de equipo': 'Gear rental',
      'Cine': 'Movies', 'Ropa': 'Clothes', 'Lente en renta': 'Lens rental', 'Concierto': 'Concert', 'Cena': 'Dinner', 'Cena de cumpleaños': 'Birthday dinner', 'Locación': 'Location',
      'Software': 'Software', 'Almuerzo': 'Lunch', 'Uber': 'Uber'
    }
  },
  ja: {
    me: { first: '拓海', last: '佐藤', nick: '拓海', gender: 'm' },
    t: {
      'Chase Checking': '三菱UFJ 普通預金', 'Ally Ahorros': 'ゆうちょ銀行 貯蓄', 'BCP Soles': 'Wise USD', 'Efectivo': '現金', 'Cuenta principal': 'メイン口座',
      'Apple Card': '楽天カード', 'Capital One': '三井住友カード', 'Chime Credit Builder': 'セゾンカード', 'Préstamo de estudios': '奨学金',
      'Gimnasio': 'ジム', 'Plan móvil Perú': '米国向けSIM',
      'Fondo mudanza SF': '引っ越し資金', 'Ahorro Perú': 'ハワイ旅行', 'Emergencias': '緊急用資金',
      'Sueldo': '給与', 'Proyecto Estudio 2²': 'フリーランス案件', 'Pago freelance Lima': '米国クライアントの報酬',
      'Internet': 'インターネット', 'Veterinario': '動物病院', 'Vuelo a SF': '福岡行き航空券', 'Regalos (simulado)': 'プレゼント(シミュレーション)', 'Laptop nueva': '新しいノートPC', 'Alquiler': '家賃',
      'Supermercado': 'スーパー', 'Café y almuerzo': 'カフェとランチ', 'Comida de gatos': '猫のごはん', 'Suscripción música': '音楽サブスク', 'Alquiler de lente': 'レンズのレンタル',
      'Cine y cena': '映画とディナー', 'Delivery': 'デリバリー', 'Gasolina': 'ガソリン', 'Regalo': 'プレゼント', 'Bar': '居酒屋', 'Pasajes': '電車代', 'Cena con el equipo': 'チームの打ち上げ',
      'Locación de rodaje': '撮影ロケ地', 'Streaming': '動画配信', 'Arena y juguetes': '猫砂とおもちゃ', 'Software anual': '年間ソフトウェア', 'Alquiler de equipo': '機材レンタル',
      'Cine': '映画', 'Ropa': '服', 'Lente en renta': 'レンタルレンズ', 'Concierto': 'ライブ', 'Cena': '夕食', 'Cena de cumpleaños': '誕生日ディナー', 'Locación': 'ロケ地',
      'Software': 'ソフトウェア', 'Almuerzo': 'ランチ', 'Uber': 'タクシー'
    }
  },
  it: {
    me: { first: 'Giulia', last: 'Romano', nick: 'Giulia', gender: 'f' },
    t: {
      'Chase Checking': 'Intesa Sanpaolo Conto', 'Ally Ahorros': 'Fineco Risparmio', 'BCP Soles': 'Revolut CHF', 'Efectivo': 'Contanti', 'Cuenta principal': 'Conto principale',
      'Apple Card': 'Carta Nexi', 'Capital One': 'Carta Mediolanum', 'Chime Credit Builder': 'Carta Hype', 'Préstamo de estudios': 'Prestito per gli studi',
      'Gimnasio': 'Palestra', 'Plan móvil Perú': 'Piano mobile Svizzera',
      'Fondo mudanza SF': 'Fondo trasloco', 'Ahorro Perú': 'Casa a Lugano', 'Emergencias': 'Emergenze',
      'Sueldo': 'Stipendio', 'Proyecto Estudio 2²': 'Progetto freelance', 'Pago freelance Lima': 'Pagamento cliente svizzero',
      'Internet': 'Internet', 'Veterinario': 'Veterinario', 'Vuelo a SF': 'Volo per Londra', 'Regalos (simulado)': 'Regali (simulato)', 'Laptop nueva': 'Nuovo portatile', 'Alquiler': 'Affitto',
      'Supermercado': 'Supermercato', 'Café y almuerzo': 'Caffè e pranzo', 'Comida de gatos': 'Cibo per gatti', 'Suscripción música': 'Abbonamento musicale', 'Alquiler de lente': 'Noleggio obiettivo',
      'Cine y cena': 'Cinema e cena', 'Delivery': 'Consegna a domicilio', 'Gasolina': 'Benzina', 'Regalo': 'Regalo', 'Bar': 'Aperitivo', 'Pasajes': 'Biglietto del treno', 'Cena con el equipo': 'Cena con il team',
      'Locación de rodaje': 'Location delle riprese', 'Streaming': 'Streaming', 'Arena y juguetes': 'Lettiera e giochi', 'Software anual': 'Software annuale', 'Alquiler de equipo': 'Noleggio attrezzatura',
      'Cine': 'Cinema', 'Ropa': 'Vestiti', 'Lente en renta': 'Obiettivo a noleggio', 'Concierto': 'Concerto', 'Cena': 'Cena', 'Cena de cumpleaños': 'Cena di compleanno', 'Locación': 'Location',
      'Software': 'Software', 'Almuerzo': 'Pranzo', 'Uber': 'Taxi'
    }
  },
  sh: {
    me: { first: 'Amar', last: 'Hodžić', nick: 'Amar', gender: 'm' },
    t: {
      'Chase Checking': 'Raiffeisen tekući račun', 'Ally Ahorros': 'UniCredit štednja', 'BCP Soles': 'Revolut EUR', 'Efectivo': 'Gotovina', 'Cuenta principal': 'Glavni račun',
      'Apple Card': 'Visa kartica', 'Capital One': 'Mastercard kartica', 'Chime Credit Builder': 'Kreditna kartica', 'Préstamo de estudios': 'Studentski kredit',
      'Gimnasio': 'Teretana', 'Plan móvil Perú': 'Mobilni paket Austrija',
      'Fondo mudanza SF': 'Fond za selidbu', 'Ahorro Perú': 'Putovanje u Beč', 'Emergencias': 'Hitni slučajevi',
      'Sueldo': 'Plata', 'Proyecto Estudio 2²': 'Freelance projekat', 'Pago freelance Lima': 'Uplata klijenta iz Austrije',
      'Internet': 'Internet', 'Veterinario': 'Veterinar', 'Vuelo a SF': 'Let za Sarajevo', 'Regalos (simulado)': 'Pokloni (simulirano)', 'Laptop nueva': 'Novi laptop', 'Alquiler': 'Stanarina',
      'Supermercado': 'Supermarket', 'Café y almuerzo': 'Kafa i ručak', 'Comida de gatos': 'Hrana za mačke', 'Suscripción música': 'Muzička pretplata', 'Alquiler de lente': 'Najam objektiva',
      'Cine y cena': 'Kino i večera', 'Delivery': 'Dostava hrane', 'Gasolina': 'Gorivo', 'Regalo': 'Poklon', 'Bar': 'Kafić', 'Pasajes': 'Karta za voz', 'Cena con el equipo': 'Večera s timom',
      'Locación de rodaje': 'Lokacija snimanja', 'Streaming': 'Streaming', 'Arena y juguetes': 'Pijesak i igračke', 'Software anual': 'Godišnji softver', 'Alquiler de equipo': 'Najam opreme',
      'Cine': 'Kino', 'Ropa': 'Odjeća', 'Lente en renta': 'Iznajmljeni objektiv', 'Concierto': 'Koncert', 'Cena': 'Večera', 'Cena de cumpleaños': 'Rođendanska večera', 'Locación': 'Lokacija',
      'Software': 'Softver', 'Almuerzo': 'Ručak', 'Uber': 'Taksi'
    }
  }
};
/* Convierte la demo base (USD + una cuenta en soles) a la moneda/idioma del paquete: textos nuevos, importes propios */
function localizeDemo(o, L) {
  const C = DEMO_CUR[L], T = DEMO_PACK[L].t, tt = (s) => (s && T[s] != null ? T[s] : s), same = C.p === 'USD';
  const rnd = (x, cur) => { const a = Math.abs(x); if (decOf(cur) === 0) return a >= 1000 ? Math.round(x / 10) * 10 : Math.round(x); return a >= 100 ? Math.round(x / 5) * 5 : Math.round(x * 100) / 100; };
  const toP = (v) => (same ? v : rnd((Number(v) || 0) * C.f, C.p));
  const toS = (v) => rnd((Number(v) || 0) / 3.7 * CURRENCIES[C.s].rate, C.s);
  const curs = {}; [].concat(o.accounts || [], o.cards || []).forEach((a) => { curs[a.id] = a.cur; });
  const cv = (v, cur) => (cur === 'PEN' ? toS(v) : toP(v)), cm = (cur) => (cur === 'PEN' ? C.s : C.p);
  (o.transactions || []).forEach((t) => { const c = curs[t.acc]; t.amount = cv(t.amount, c); if (t.est != null) t.est = cv(t.est, c); t.note = tt(t.note); });
  (o.accounts || []).forEach((a) => { a.balance = cv(a.balance, a.cur); a.cur = cm(a.cur); a.name = tt(a.name); });
  (o.cards || []).forEach((c) => { c.limit = cv(c.limit, c.cur); c.balance = cv(c.balance, c.cur); c.payment = cv(c.payment, c.cur); c.cur = cm(c.cur); c.name = tt(c.name); });
  (o.subs || []).forEach((x) => { x.amount = cv(x.amount, x.cur); x.cur = cm(x.cur); x.name = tt(x.name); });
  (o.savings || []).forEach((sv) => { sv.balance = cv(sv.balance, sv.cur); sv.goal = cv(sv.goal, sv.cur); sv.monthly = cv(sv.monthly, sv.cur); (sv.log || []).forEach((l) => { l.amount = cv(l.amount, sv.cur); }); sv.cur = cm(sv.cur); sv.name = tt(sv.name); });
  ['expected_income', 'expected_expense', 'planned'].forEach((k) => (o[k] || []).forEach((e) => { e.amount = cv(e.amount, curs[e.acc]); e.name = tt(e.name); }));
  (o.recurring || []).forEach((r) => { r.amount = toP(r.amount); r.name = tt(r.name); });
  (o.history || []).forEach((h) => { h.income = toP(h.income); h.expense = toP(h.expense); });
  Object.keys(o.budget || {}).forEach((k) => { o.budget[k] = toP(o.budget[k]); });
  const st = o.settings || {};
  o.settings = Object.assign({}, st, { currency: C.p, currency2: C.s, fx: fxDefault(C.p, C.s), cushion: toP(st.cushion), variable_weekly: toP(st.variable_weekly) });
  return o;
}
