// Revisa el JavaScript de la app tal como queda compilado (todo junto, en un solo ámbito) y señala el archivo de origen de cada problema.
// Uso:  python3 dev/app/build.py && node dev/app/lint.mjs      (o, desde dev/:  npm run lint)
// Por qué sobre la compilación y no archivo por archivo: los ~40 archivos de src/js/ comparten variables. Por separado, todo parecería
// «no definido»; juntos, se ve lo que de verdad importa: dos funciones con el mismo nombre (la segunda pisa a la primera en silencio),
// variables que no existen y código que nadie usa.
import { ESLint } from 'eslint';
import globals from 'globals';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url)), src = path.join(root, 'src');
const outFile = path.join(root, 'out', 'finanzas.html');
if (!fs.existsSync(outFile)) { console.error('Primero compila la app: python3 dev/app/build.py'); process.exit(2); }

// El script principal de la app es el <script> más grande.
const html = fs.readFileSync(outFile, 'utf8');
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
const code = scripts.reduce((a, b) => (b.length > a.length ? b : a), '');

// Mapa de vuelta al archivo de origen: los archivos se pegan tal cual, así que se buscan dentro de la compilación.
const walk = (d) => fs.readdirSync(d, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? walk(path.join(d, e.name)) : [path.join(d, e.name)]));
const lineAt = (s, i) => { let n = 1; for (let k = s.indexOf('\n'); k >= 0 && k < i; k = s.indexOf('\n', k + 1)) n++; return n; };
const spans = [];
for (const f of walk(src).filter((f) => f.endsWith('.js'))) {
  const t = fs.readFileSync(f, 'utf8').replace(/\n$/, ''); if (t.length < 40) continue;
  const at = code.indexOf(t); if (at < 0) continue;   // i18n.js se transforma al compilar: sus avisos salen como «(compilado)»
  spans.push({ file: path.relative(path.join(root, '..', '..'), f), from: lineAt(code, at), to: lineAt(code, at + t.length) });
}
const where = (line) => { const s = spans.find((x) => line >= x.from && line <= x.to); return s ? s.file + ':' + (line - s.from + 1) : '(compilado):' + line; };

const eslint = new ESLint({
  overrideConfigFile: true,
  overrideConfig: [{
    languageOptions: { ecmaVersion: 2023, sourceType: 'script', globals: { ...globals.browser, module: 'readonly', require: 'readonly' } },
    linterOptions: { reportUnusedDisableDirectives: 'off' },
    rules: {
      // errores reales
      'no-undef': 'error', 'no-redeclare': 'error', 'no-dupe-keys': 'error', 'no-dupe-args': 'error', 'no-duplicate-case': 'error',
      'no-func-assign': 'error', 'no-const-assign': 'error', 'no-dupe-else-if': 'error', 'no-self-assign': 'error', 'no-unreachable': 'error',
      'use-isnan': 'error', 'valid-typeof': 'error', 'no-unsafe-negation': 'error', 'no-unsafe-optional-chaining': 'error', 'no-obj-calls': 'error',
      'no-compare-neg-zero': 'error', 'no-setter-return': 'error', 'no-unsafe-finally': 'error', 'no-invalid-regexp': 'error', 'no-global-assign': 'error',
      'no-loss-of-precision': 'error', 'no-constant-binary-expression': 'error', 'no-self-compare': 'error',
      'array-callback-return': ['error', { checkForEach: false }],   // un .map() que no devuelve nada: así se perdió «Últimos ingresos de trabajo»
      // limpieza: lo que nadie usa estorba y esconde errores
      'no-unused-vars': ['error', { args: 'none', caughtErrors: 'none' }],
    },
  }],
});
const [res] = await eslint.lintText(code, { filePath: 'finanzas.js' });
const msgs = res.messages.filter((m) => m.severity === 2 || m.fatal);
for (const m of msgs) console.log(where(m.line) + '  ' + (m.ruleId || 'sintaxis') + '  ' + m.message);
console.log(msgs.length ? '\n' + msgs.length + ' problema(s). Corrígelos antes de publicar.' : 'Todo bien: ' + spans.length + ' archivos revisados.');
process.exitCode = msgs.length ? 1 : 0;
