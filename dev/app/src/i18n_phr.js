/* ---- Frases de saludo / evaluación / ejemplo de género por idioma (fuente directa) ---- */
const PH_T = {
  en: {
    S: [['Excellent work in {mes}, {n}.', 'Excellent work in {mes}.'], ['{n}, {mes} was a first-rate month.', '{Mes} was a first-rate month.'], ['Well done, {n}: {mes} came out spotless.', 'Well done: {mes} came out spotless.'], ['A well-rounded month, {n}. Keep it up.', 'A well-rounded month. Keep it up.']],
    A: [['A very good {mes}, {n}.', 'A very good {mes}.'], ['You’re on a great path, {n}.', 'You’re on a great path.'], ['Nice work in {mes}, {n}. Almost perfect.', 'Nice work in {mes}. Almost perfect.'], ['{n}, {mes} went really well.', '{Mes} went really well.']],
    B: [['Good pace in {mes}, {n}.', 'Good pace in {mes}.'], ['You’re doing well, {n}. One small tweak and you’ll move up.', 'You’re doing well. One small tweak and you’ll move up.'], ['{Mes} turned out solid, {n}.', '{Mes} turned out solid.'], ['{bien}, {n}. There’s still room for more.', '{bien}. There’s still room for more.']],
    C: [['{Mes} was so-so, {n}. It can improve.', '{Mes} was so-so. It can improve.'], ['You’re halfway there, {n}. Let’s see where to adjust.', 'You’re halfway there. Let’s see where to adjust.'], ['There’s room to improve, {n}.', 'There’s room to improve.'], ['Neither bad nor good, {n}. You can do more.', 'Neither bad nor good. You can do more.']],
    D: [['We can do better, {n}.', 'We can do better.'], ['{Mes} was a tough one, {n}. You still have time.', '{Mes} was a tough one. You still have time.'], ['Time to adjust, {n}. Start with the biggest thing.', 'Time to adjust. Start with the biggest thing.'], ['Let’s correct course, {n}.', 'Let’s correct course.']],
    F: [['{Mes} was hard, {n}. Let’s start over.', '{Mes} was hard. Let’s start over.'], ['Time to hit the brakes, {n}. We’ll take it step by step.', 'Time to hit the brakes. We’ll take it step by step.'], ['This doesn’t define your year, {n}. Let’s make a plan.', 'This doesn’t define your year. Let’s make a plan.'], ['A bad month happens to everyone, {n}. We keep going.', 'A bad month happens to everyone. We keep going.']]
  },
  ja: {
    S: [['{n}さん、{mes}は素晴らしい出来でした。', '{mes}は素晴らしい出来でした。'], ['{n}さん、{mes}は最高の月でした。', '{mes}は最高の月でした。'], ['お見事です、{n}さん。{mes}は完璧でした。', 'お見事です。{mes}は完璧でした。'], ['申し分ない月でした、{n}さん。この調子で。', '申し分ない月でした。この調子で。']],
    A: [['{n}さん、{mes}はとても良い月でした。', '{mes}はとても良い月でした。'], ['{n}さん、とても順調です。', 'とても順調です。'], ['{n}さん、{mes}はよくできました。ほぼ完璧です。', '{mes}はよくできました。ほぼ完璧です。'], ['{n}さん、{mes}はとても良い結果でした。', '{mes}はとても良い結果でした。']],
    B: [['{n}さん、{mes}は良いペースでした。', '{mes}は良いペースでした。'], ['{n}さん、順調です。少し見直せばさらに上がります。', '順調です。少し見直せばさらに上がります。'], ['{n}さん、{mes}は堅実な月でした。', '{mes}は堅実な月でした。'], ['{bien}、{n}さん。まだ伸びしろがあります。', '{bien}。まだ伸びしろがあります。']],
    C: [['{n}さん、{mes}はまずまずでした。改善できます。', '{mes}はまずまずでした。改善できます。'], ['{n}さん、半分まで来ました。どこを直すか見てみましょう。', '半分まで来ました。どこを直すか見てみましょう。'], ['{n}さん、まだ改善の余地があります。', 'まだ改善の余地があります。'], ['{n}さん、悪くはありませんが、もっとできます。', '悪くはありませんが、もっとできます。']],
    D: [['{n}さん、もっと良くできます。', 'もっと良くできます。'], ['{n}さん、{mes}は少し大変でしたね。まだ間に合います。', '{mes}は少し大変でしたね。まだ間に合います。'], ['{n}さん、見直しの時です。いちばん大きなところから始めましょう。', '見直しの時です。いちばん大きなところから始めましょう。'], ['{n}さん、軌道を修正しましょう。', '軌道を修正しましょう。']],
    F: [['{n}さん、{mes}は厳しい月でした。最初からやり直しましょう。', '{mes}は厳しい月でした。最初からやり直しましょう。'], ['{n}さん、ここで立ち止まりましょう。一歩ずつ見ていきます。', 'ここで立ち止まりましょう。一歩ずつ見ていきます。'], ['{n}さん、これで1年が決まるわけではありません。計画を立てましょう。', 'これで1年が決まるわけではありません。計画を立てましょう。'], ['{n}さん、誰にでも悪い月はあります。続けていきましょう。', '誰にでも悪い月はあります。続けていきましょう。']]
  },
  it: {
    S: [['Ottimo lavoro a {mes}, {n}.', 'Ottimo lavoro a {mes}.'], ['{n}, {mes} è stato un mese di prim’ordine.', '{Mes} è stato un mese di prim’ordine.'], ['Ben fatto, {n}: {mes} è stato impeccabile.', 'Ben fatto: {mes} è stato impeccabile.'], ['Mese perfetto, {n}. Continua così.', 'Mese perfetto. Continua così.']],
    A: [['Un ottimo {mes}, {n}.', 'Un ottimo {mes}.'], ['Sei sulla strada giusta, {n}.', 'Sei sulla strada giusta.'], ['Buon lavoro a {mes}, {n}. Quasi perfetto.', 'Buon lavoro a {mes}. Quasi perfetto.'], ['{n}, {mes} è andato molto bene.', '{Mes} è andato molto bene.']],
    B: [['Buon ritmo a {mes}, {n}.', 'Buon ritmo a {mes}.'], ['Vai bene, {n}. Un piccolo aggiustamento e sali.', 'Vai bene. Un piccolo aggiustamento e sali.'], ['{Mes} è stato solido, {n}.', '{Mes} è stato solido.'], ['{bien}, {n}. C’è ancora margine per di più.', '{bien}. C’è ancora margine per di più.']],
    C: [['{Mes} è stato così così, {n}. Si può migliorare.', '{Mes} è stato così così. Si può migliorare.'], ['Sei a metà strada, {n}. Vediamo dove regolare.', 'Sei a metà strada. Vediamo dove regolare.'], ['C’è spazio per migliorare, {n}.', 'C’è spazio per migliorare.'], ['Né male né bene, {n}. Puoi fare di più.', 'Né male né bene. Puoi fare di più.']],
    D: [['Possiamo fare meglio, {n}.', 'Possiamo fare meglio.'], ['{Mes} è stato duro, {n}. Sei ancora in tempo.', '{Mes} è stato duro. Sei ancora in tempo.'], ['Bisogna aggiustare, {n}. Parti dalla cosa più grande.', 'Bisogna aggiustare. Parti dalla cosa più grande.'], ['Correggiamo la rotta, {n}.', 'Correggiamo la rotta.']],
    F: [['{Mes} è stato difficile, {n}. Ricominciamo.', '{Mes} è stato difficile. Ricominciamo.'], ['È il momento di frenare, {n}. Andiamo passo dopo passo.', 'È il momento di frenare. Andiamo passo dopo passo.'], ['Questo non definisce il tuo anno, {n}. Facciamo un piano.', 'Questo non definisce il tuo anno. Facciamo un piano.'], ['Un brutto mese capita a tutti, {n}. Andiamo avanti.', 'Un brutto mese capita a tutti. Andiamo avanti.']]
  },
  fr: {
    S: [['Excellent travail en {mes}, {n}.', 'Excellent travail en {mes}.'], ['{n}, {mes} a été un mois de premier ordre.', '{Mes} a été un mois de premier ordre.'], ['Bravo, {n} : {mes} est impeccable.', 'Bravo : {mes} est impeccable.'], ['Un mois parfait, {n}. Continuez ainsi.', 'Un mois parfait. Continuez ainsi.']],
    A: [['Très bon mois de {mes}, {n}.', 'Très bon mois de {mes}.'], ['Vous êtes sur une très bonne voie, {n}.', 'Vous êtes sur une très bonne voie.'], ['Beau travail en {mes}, {n}. Presque parfait.', 'Beau travail en {mes}. Presque parfait.'], ['{n}, {mes} s’est très bien passé.', '{Mes} s’est très bien passé.']],
    B: [['Bon rythme en {mes}, {n}.', 'Bon rythme en {mes}.'], ['Ça va bien, {n}. Un petit ajustement et vous montez.', 'Ça va bien. Un petit ajustement et vous montez.'], ['{Mes} a été solide, {n}.', '{Mes} a été solide.'], ['{bien}, {n}. Il y a encore de la marge.', '{bien}. Il y a encore de la marge.']],
    C: [['{Mes} a été moyen, {n}. On peut améliorer.', '{Mes} a été moyen. On peut améliorer.'], ['Vous êtes à mi-chemin, {n}. Voyons où ajuster.', 'Vous êtes à mi-chemin. Voyons où ajuster.'], ['Il y a de la place pour progresser, {n}.', 'Il y a de la place pour progresser.'], ['Ni bien ni mal, {n}. Vous pouvez faire plus.', 'Ni bien ni mal. Vous pouvez faire plus.']],
    D: [['On peut faire mieux, {n}.', 'On peut faire mieux.'], ['{Mes} a été difficile, {n}. Il est encore temps.', '{Mes} a été difficile. Il est encore temps.'], ['Il faut ajuster, {n}. Commencez par le plus gros.', 'Il faut ajuster. Commencez par le plus gros.'], ['Corrigeons le cap, {n}.', 'Corrigeons le cap.']],
    F: [['{Mes} a été dur, {n}. Repartons de zéro.', '{Mes} a été dur. Repartons de zéro.'], ['C’est le moment de freiner, {n}. On y va pas à pas.', 'C’est le moment de freiner. On y va pas à pas.'], ['Cela ne définit pas votre année, {n}. Faisons un plan.', 'Cela ne définit pas votre année. Faisons un plan.'], ['Un mauvais mois arrive à tout le monde, {n}. On continue.', 'Un mauvais mois arrive à tout le monde. On continue.']]
  },
  sh: {
    S: [['Odličan rad, {n}: {mes} je bio vrhunski mjesec.', '{Mes} je bio vrhunski mjesec.'], ['{n}, {mes} je bio mjesec prvoklasne ocjene.', '{Mes} je bio mjesec prvoklasne ocjene.'], ['Bravo, {n}: {mes} je prošao besprijekorno.', 'Bravo: {mes} je prošao besprijekorno.'], ['Zaokružen mjesec, {n}. Samo tako.', 'Zaokružen mjesec. Samo tako.']],
    A: [['Vrlo dobar {mes}, {n}.', 'Vrlo dobar {mes}.'], ['Na odličnom si putu, {n}.', 'Na odličnom si putu.'], ['Dobar rad, {n}: {mes} je skoro savršen.', 'Dobar rad: {mes} je skoro savršen.'], ['{n}, {mes} je prošao vrlo dobro.', '{Mes} je prošao vrlo dobro.']],
    B: [['Dobar tempo, {n}: {mes} ti ide dobro.', 'Dobar tempo: {mes} ide dobro.'], ['Ide ti dobro, {n}. Mala korekcija i penješ se.', 'Ide ti dobro. Mala korekcija i penješ se.'], ['{Mes} je ispao solidno, {n}.', '{Mes} je ispao solidno.'], ['{bien}, {n}. Još ima prostora za više.', '{bien}. Još ima prostora za više.']],
    C: [['{Mes} je bio osrednji, {n}. Može bolje.', '{Mes} je bio osrednji. Može bolje.'], ['Na pola si puta, {n}. Vidimo gdje korigovati.', 'Na pola si puta. Vidimo gdje korigovati.'], ['Ima prostora za napredak, {n}.', 'Ima prostora za napredak.'], ['Ni loše ni dobro, {n}. Možeš ti i više.', 'Ni loše ni dobro. Možeš i više.']],
    D: [['Možemo mi bolje, {n}.', 'Možemo bolje.'], ['{Mes} je bio malo težak, {n}. Još stižeš.', '{Mes} je bio malo težak. Još stižeš.'], ['Vrijeme je za korekciju, {n}. Počni od najvećeg.', 'Vrijeme je za korekciju. Počni od najvećeg.'], ['Ispravimo kurs, {n}.', 'Ispravimo kurs.']],
    F: [['{Mes} je bio težak, {n}. Počnimo ispočetka.', '{Mes} je bio težak. Počnimo ispočetka.'], ['Vrijeme je za kočenje, {n}. Idemo korak po korak.', 'Vrijeme je za kočenje. Idemo korak po korak.'], ['Ovo ne određuje tvoju godinu, {n}. Napravimo plan.', 'Ovo ne određuje tvoju godinu. Napravimo plan.'], ['Loš mjesec može zadesiti svakoga, {n}. Nastavljamo.', 'Loš mjesec može zadesiti svakoga. Nastavljamo.']]
  }
};
const BIEN_T = {
  en: { m: 'Well done', f: 'Well done', n: 'Good work' },
  ja: { m: 'よくできました', f: 'よくできました', n: 'お疲れさまです' },
  it: { m: 'Bravo', f: 'Brava', n: 'Buon lavoro' },
  fr: { m: 'Bien joué', f: 'Bien joué', n: 'Beau travail' },
  sh: { m: 'Bravo', f: 'Bravo', n: 'Odličan rad' }
};
const GREET_T = {
  en: ['Good morning', 'Good afternoon', 'Good evening'],
  ja: ['おはようございます', 'こんにちは', 'こんばんは'],
  it: ['Buongiorno', 'Buon pomeriggio', 'Buonasera'],
  fr: ['Bonjour', 'Bon après-midi', 'Bonsoir'],
  sh: ['Dobro jutro', 'Dobar dan', 'Dobro veče']
};
function greetLine() {
  const h = new Date().getHours(), i = h < 12 ? 0 : h < 19 ? 1 : 2, nick = userNick();
  if (LANG === 'es') return (['Buenos días', 'Buenas tardes', 'Buenas noches'][i]) + (nick ? ', ' + nick : '') + '.';
  const w = GREET_T[LANG][i];
  if (LANG === 'ja') return w + (nick ? '、' + nick + 'さん' : '') + '。';
  return w + (nick ? ', ' + nick : '') + '.';
}
function genderExampleL(g, nm) {
  const n = (nm || '').trim();
  if (LANG === 'es') return 'Ejemplo: «' + ({ m: 'Estás listo', f: 'Estás lista' }[g] || 'Todo listo') + (n ? ', ' + n : '') + '. ' + ({ m: 'Bienvenido', f: 'Bienvenida' }[g] || 'Te damos la bienvenida') + '.»';
  if (LANG === 'en') return 'Example: “Well done' + (n ? ', ' + n : '') + '. Welcome.”';
  if (LANG === 'ja') return '例:「よくできました' + (n ? '、' + n + 'さん' : '') + '。ようこそ。」';
  if (LANG === 'it') return 'Esempio: «' + ({ m: 'Bravo', f: 'Brava' }[g] || 'Ottimo lavoro') + (n ? ', ' + n : '') + '. ' + ({ m: 'Benvenuto', f: 'Benvenuta' }[g] || 'Ti diamo il benvenuto') + '.»';
  if (LANG === 'sh') return 'Primjer: „' + ({ m: 'Bravo', f: 'Bravo' }[g] || 'Odličan rad') + (n ? ', ' + n : '') + '. ' + ({ m: 'Dobro došao', f: 'Dobro došla' }[g] || 'Dobrodošli') + '.”';
  return 'Exemple : « ' + ({ m: 'Bien joué', f: 'Bien joué' }[g] || 'Beau travail') + (n ? ', ' + n : '') + '. ' + ({ m: 'Vous êtes prêt', f: 'Vous êtes prête' }[g] || 'Bienvenue') + '. »';
}
