// Frase de recuperación: se escribe en español (sin tildes ni eñes) o en inglés, y es la misma llave. Usa el código REAL de la app.
import { readFileSync } from 'node:fs';
import { webcrypto } from 'node:crypto';
globalThis.crypto ??= webcrypto;
const html = readFileSync(new URL('../app/src/app.html', import.meta.url), 'utf8');
const i0 = html.indexOf('const PCC = (() => {'), i1 = html.indexOf('\n})();', i0) + 6;
const PCC = new Function(html.slice(i0, i1) + '\nreturn PCC;')();
let f = 0; const ok = (c, m) => { console.log((c ? 'OK    ' : 'FALLA ') + m); if (!c) f++; };
const eq = (a, b) => a.length === b.length && a.every((x, i) => x === b[i]);

let all = true, same = true, loose = true;
for (let n = 0; n < 200; n++) {
  const seed = PCC.newSeed(), es = await PCC.toPhrase(seed, 'es'), en = await PCC.toPhrase(seed, 'en');
  all = all && es.length === 12 && es.every((w) => /^[a-z]+$/.test(w));
  same = same && eq(es.map((w) => PCC.wordIdx(w, 'es')), en.map((w) => PCC.wordIdx(w, 'en')));
  const a = await PCC.fromPhrase(es.join(' ')), b = await PCC.fromPhrase(en.join(' ')), kc = await PCC.keyCheck(seed);
  same = same && a && b && eq([...a], [...seed]) && eq([...b], [...seed]);
  const c = await PCC.fromPhrase(es.map((w) => w.slice(0, 4).toUpperCase()).join('  '), kc); // 4 letras, mayúsculas, espacios de más
  loose = loose && c && eq([...c], [...seed]);
}
ok(all, 'la frase en español son 12 palabras sin tildes ni eñes');
ok(same, 'español e inglés son la misma llave (200 semillas)');
ok(loose, 'se acepta con 4 letras por palabra, en mayúsculas y con tildes de más');
ok(PCC.wordIdx('CAÑÓN', 'es') === PCC.wordIdx('canon', 'es') && PCC.wordIdx('canon', 'es') >= 0, '«cañón» = «canon»');
ok((await PCC.fromPhrase('hola mundo')) === null, 'una frase corta se rechaza');
console.log(f ? 'FALLARON ' + f : 'TODO BIEN'); process.exit(f ? 1 : 0);
