#!/usr/bin/env node
// Prepara el proyecto de Android que genera Capacitor (`npx cap add android`) para que sea la app de Plata:
// ícono, pantalla de inicio verde, colores, permisos, enlaces, «Compartir», el plugin propio y la firma de Play.
// Se corre desde la carpeta android/ después de `cap add android` y antes de `cap sync`:  node scripts/prepare.mjs
// El proyecto generado (android/android/) NO se versiona: este script y los archivos de native/ y resources/ son la receta.
import { readFileSync, writeFileSync, existsSync, mkdirSync, copyFileSync, readdirSync, statSync, unlinkSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');              // android/
const PROJ = join(ROOT, 'android');                                             // el proyecto generado
const RES = join(PROJ, 'app', 'src', 'main', 'res');
const cfg = JSON.parse(readFileSync(join(ROOT, 'capacitor.config.json'), 'utf8'));
const PKG_DIR = join(PROJ, 'app', 'src', 'main', 'java', ...cfg.appId.split('.'));
let fallos = 0;
const ok = (m) => console.log('  ok   ' + m);
const falla = (m) => { console.log('  FALLA ' + m); fallos++; };
const rd = (p) => readFileSync(p, 'utf8');
function walk(dir, fn) { if (!existsSync(dir)) return; for (const f of readdirSync(dir)) { const p = join(dir, f); if (statSync(p).isDirectory()) walk(p, fn); else fn(p); } }
function copiar(origen, destino) { mkdirSync(dirname(destino), { recursive: true }); copyFileSync(origen, destino); }

if (!existsSync(PROJ)) { console.error('No existe android/android: corre antes `npx cap add android`.'); process.exit(1); }
console.log('Preparando Plata para Android (' + cfg.appId + ')');

// ---- 1. Código nativo propio: la actividad y el plugin (huella, «Compartir») ----
for (const f of ['MainActivity.java', 'PlataNativePlugin.java']) { copiar(join(ROOT, 'native', f), join(PKG_DIR, f)); ok('java/' + f); }

// ---- 2. Gradle: versión, firma y la librería de huella (native/plata.gradle) ----
copiar(join(ROOT, 'native', 'plata.gradle'), join(PROJ, 'app', 'plata.gradle'));
{
  const p = join(PROJ, 'app', 'build.gradle'), s = rd(p);
  if (s.includes("apply from: 'plata.gradle'")) ok('build.gradle ya enlaza plata.gradle');
  else { writeFileSync(p, s.replace(/\s*$/, '\n') + "\napply from: 'plata.gradle'\n"); ok("build.gradle: apply from 'plata.gradle'"); }
}

// ---- 3. Recursos: íconos, pantalla de inicio y colores ----
walk(RES, (p) => { if (/ic_launcher(_round|_foreground)?\.webp$/.test(p)) unlinkSync(p); });          // por si la plantilla trae webp: evita recursos duplicados
walk(join(ROOT, 'resources'), (p) => {
  const rel = p.slice(join(ROOT, 'resources').length + 1);
  if (rel.startsWith('splash')) return;                                                                 // las imágenes de arranque se copian aparte
  copiar(p, join(RES, rel));
});
ok('íconos (clásicos, adaptable y de notificaciones) y splash_icon');
{
  let n = 0;
  walk(RES, (p) => { if (/[\\/]splash\.png$/.test(p)) { copiar(join(ROOT, 'resources', 'splash', /land/.test(p) ? 'splash-land.png' : 'splash-port.png'), p); n++; } });
  ok('imagen de arranque para versiones anteriores a Android 12 (' + n + ' archivos)');
}
writeFileSync(join(RES, 'values', 'ic_launcher_background.xml'), '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#22B573</color>\n</resources>\n'); ok('fondo del ícono adaptable');
mkdirSync(join(RES, 'values-night'), { recursive: true });
writeFileSync(join(RES, 'values', 'plata_colors.xml'), `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- verde de marca (SplashGreen del iPhone) y el fondo claro de la app -->
    <color name="splash_green">#22B573</color>
    <color name="plata_bg">#F2F2F7</color>
    <bool name="plata_light_bars">true</bool>
</resources>
`);
writeFileSync(join(RES, 'values-night', 'plata_colors.xml'), `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- verde bosque en oscuro, el mismo del modo oscuro del iPhone -->
    <color name="splash_green">#0A2D1F</color>
    <color name="plata_bg">#000000</color>
    <bool name="plata_light_bars">false</bool>
</resources>
`);
ok('colores (claro y oscuro)');

// ---- 4. Estilos: pantalla de inicio de Android 12+ y fondo de la ventana ----
{
  const p = join(RES, 'values', 'styles.xml'); let s = rd(p);
  const launch = `<style name="AppTheme.NoActionBarLaunch" parent="Theme.SplashScreen">
        <item name="windowSplashScreenBackground">@color/splash_green</item>
        <item name="windowSplashScreenAnimatedIcon">@drawable/splash_icon</item>
        <item name="postSplashScreenTheme">@style/AppTheme.NoActionBar</item>
        <item name="android:background">@drawable/splash</item>
    </style>`;
  if (/<style\s+name="AppTheme\.NoActionBarLaunch"[\s\S]*?<\/style>/.test(s)) { s = s.replace(/<style\s+name="AppTheme\.NoActionBarLaunch"[\s\S]*?<\/style>/, launch); ok('estilo de arranque (Theme.SplashScreen verde con el logo)'); }
  else falla('styles.xml no trae AppTheme.NoActionBarLaunch: revisar la plantilla de Capacitor');
  const m = /<style\s+name="AppTheme\.NoActionBar"[^>]*>([\s\S]*?)<\/style>/.exec(s);
  if (m) {
    const extra = '\n        <item name="android:windowBackground">@color/plata_bg</item>\n        <item name="android:windowLightStatusBar">@bool/plata_light_bars</item>';
    if (!m[0].includes('plata_bg')) s = s.replace(m[0], m[0].replace('</style>', extra.replace(/^\n/, '') + '\n    </style>'));
    ok('fondo y barras de estado según el tema');
  } else falla('styles.xml no trae AppTheme.NoActionBar: revisar la plantilla de Capacitor');
  writeFileSync(p, s);
}

// ---- 5. Manifiesto: permisos, orientación, sin copias en la nube de Google y las entradas de «Compartir» y de los enlaces ----
{
  const p = join(PROJ, 'app', 'src', 'main', 'AndroidManifest.xml'); let s = rd(p);
  const perms = ['android.permission.USE_BIOMETRIC', 'android.permission.POST_NOTIFICATIONS'].filter((x) => !s.includes(x))
    .map((x) => `    <uses-permission android:name="${x}" />`).join('\n');
  if (perms) {
    if (/<uses-permission[^>]*INTERNET[^>]*\/>/.test(s)) s = s.replace(/(<uses-permission[^>]*INTERNET[^>]*\/>)/, '$1\n' + perms);
    else s = s.replace('</manifest>', perms + '\n</manifest>');
  }
  ok('permisos: huella y avisos');
  // El plugin de avisos agrega SCHEDULE_EXACT_ALARM: Google Play lo restringe a apps de alarmas y calendarios y pide justificarlo. Plata no lo necesita (sus avisos
  // son de «mañana a las 9:00» y no pasa nada si Android los mueve unos minutos), así que se quita al unir los manifiestos.
  if (!/xmlns:tools=/.test(s)) s = s.replace('<manifest ', '<manifest xmlns:tools="http://schemas.android.com/tools" ');
  for (const x of ['android.permission.SCHEDULE_EXACT_ALARM', 'android.permission.USE_EXACT_ALARM']) {
    if (!s.includes(`"${x}" tools:node="remove"`)) s = s.replace('</manifest>', `    <uses-permission android:name="${x}" tools:node="remove" />\n</manifest>`);
  }
  ok('sin permisos de alarmas exactas (Play los restringe)');
  // los datos de Plata no deben viajar en las copias automáticas de Android
  if (/android:allowBackup="true"/.test(s)) s = s.replace('android:allowBackup="true"', 'android:allowBackup="false"');
  ok('sin copias automáticas de la app (allowBackup=false)');
  if (!/android:screenOrientation=/.test(s)) s = s.replace(/(<activity\b)/, '$1 android:screenOrientation="portrait"');
  ok('orientación vertical, como en el iPhone');
  const filtros = `
            <!-- enlaces https://web.plataapp.net/?ev=… (el evento que se añadió al calendario); se verifican con assetlinks.json, ver android/LEEME.md -->
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="https" android:host="web.plataapp.net" />
            </intent-filter>
            <!-- «Compartir» hacia Plata: capturas, estados de cuenta (PDF, CSV, Excel) y constancias en texto -->
${['image/*', 'application/pdf', 'text/csv', 'text/comma-separated-values', 'text/plain', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'application/vnd.ms-excel'].map((t) => `            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="${t}" />
            </intent-filter>`).join('\n')}
        `;
  if (!s.includes('android.intent.action.SEND')) {
    const i = s.indexOf('</activity>');
    if (i < 0) falla('el manifiesto no trae </activity>: revisar la plantilla de Capacitor'); else { s = s.slice(0, i) + filtros.replace(/\s+$/, '\n        ') + s.slice(i); ok('enlaces y «Compartir» en MainActivity'); }
  }
  writeFileSync(p, s);
}

console.log(fallos ? '\n' + fallos + ' parche(s) fallaron: la plantilla de Capacitor cambió, ajustar scripts/prepare.mjs' : '\nListo.');
process.exit(fallos ? 1 : 0);
