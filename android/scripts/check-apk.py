#!/usr/bin/env python3
"""Revisa por dentro el APK y el AAB que salieron del CI: que lleven la web, el plugin propio, los permisos, los enlaces y los recursos de Plata.
Falla (y marca el paso en rojo) si falta algo, y deja el resumen como anotación del job para poder leerlo sin descargar los archivos.
Uso: python3 android/scripts/check-apk.py salida/plata-debug.apk salida/plata-release.aab"""
import sys, re, zipfile, subprocess, glob, os

apk_path, aab_path = sys.argv[1], sys.argv[2]
apk, aab = zipfile.ZipFile(apk_path), zipfile.ZipFile(aab_path)
names = apk.namelist(); fallos = []; resumen = []
def ok(c, m, detalle=""):
    resumen.append(("OK   " if c else "FALTA ") + m + (" " + detalle if detalle else ""))
    if not c: fallos.append(m)

# ---- la web dentro del APK ----
for n in ("assets/public/index.html", "assets/public/manifest.webmanifest", "assets/capacitor.config.json", "assets/capacitor.plugins.json"):
    ok(n in names, n, f"({apk.getinfo(n).file_size} bytes)" if n in names else "")
html = apk.read("assets/public/index.html").decode("utf-8", "ignore") if "assets/public/index.html" in names else ""
ok("const APP_BUILD" in html and "Plata" in html, "la web es la de Plata (APP_BUILD)")
ok("const PN = " in html and "avisosPlan" in html and "PlataNative" in html, "el puente de Android va dentro de la web (36-android.js, huella)")
ok(any(n.startswith("assets/public/nazca/") for n in names), "el lector de PDF y OCR de Nazca (assets/public/nazca/)", f"({sum(1 for n in names if n.startswith('assets/public/nazca/'))} archivos)")
cfg = apk.read("assets/capacitor.config.json").decode() if "assets/capacitor.config.json" in names else ""
ok('"hostname": "web.plataapp.net"' in cfg.replace("\n", "").replace("  ", " ") or '"hostname":"web.plataapp.net"' in cfg.replace(" ", "").replace("\n", ""), "la app corre con el origen https://web.plataapp.net (el que acepta Plata Cloud)")
plug = apk.read("assets/capacitor.plugins.json").decode() if "assets/capacitor.plugins.json" in names else ""
for c in ("LocalNotifications", "Filesystem", "Share", "App", "SplashScreen"):
    ok(c in plug or c.lower() in plug.lower(), "plugin de Capacitor: " + c)

# ---- código nativo propio ----
dex = b"".join(apk.read(n) for n in names if n.endswith(".dex"))
ok(b"net/plataapp/plata/PlataNativePlugin" in dex, "el plugin propio (huella y «Compartir»)")
ok(b"androidx/biometric/BiometricPrompt" in dex, "la librería de huella (androidx.biometric)")
ok(b"net/plataapp/plata/MainActivity" in dex, "MainActivity de Plata")

# ---- manifiesto, con aapt2 del SDK del runner ----
aapt2 = sorted(glob.glob(os.path.join(os.environ.get("ANDROID_HOME", os.environ.get("ANDROID_SDK_ROOT", "/usr/local/lib/android/sdk")), "build-tools", "*", "aapt2")))
if aapt2:
    bd = subprocess.run([aapt2[-1], "dump", "badging", apk_path], capture_output=True, text=True).stdout
    xt = subprocess.run([aapt2[-1], "dump", "xmltree", "--file", "AndroidManifest.xml", apk_path], capture_output=True, text=True).stdout
    pkg = re.search(r"package: name='([^']+)' versionCode='(\d+)' versionName='([^']*)'", bd)
    ok(bool(pkg) and pkg.group(1) == "net.plataapp.plata", "identificador del paquete net.plataapp.plata", f"(versionCode {pkg.group(2)}, versionName {pkg.group(3)})" if pkg else "")
    ok("application-label:'Plata'" in bd, "nombre de la app: Plata")
    for perm in ("android.permission.INTERNET", "android.permission.USE_BIOMETRIC", "android.permission.POST_NOTIFICATIONS"):
        ok(f"uses-permission: name='{perm}'" in bd, "permiso " + perm.split(".")[-1])
    extra = sorted(set(re.findall(r"uses-permission: name='([^']+)'", bd)) - {"android.permission.INTERNET", "android.permission.USE_BIOMETRIC", "android.permission.POST_NOTIFICATIONS"})
    ok(not [p for p in extra if not p.startswith(("net.plataapp.plata.DYNAMIC", "androidx."))], "ningún permiso de más (ubicación, contactos, cámara…)", f"(extra: {extra})" if extra else "")
    ok("allowBackup" in xt and "(Raw: \"false\")" in xt.split("allowBackup")[1][:120] or "allowBackup(0x01010280)=(type 0x12)0x0" in xt, "sin copias automáticas (allowBackup=false)")
    ok("android.intent.action.SEND" in xt, "recibe «Compartir»")
    ok(all(t in xt for t in ("image/*", "application/pdf", "text/plain")), "tipos que recibe: imágenes, PDF y texto")
    ok("web.plataapp.net" in xt, "enlaces https://web.plataapp.net")
    ok("autoVerify" in xt, "enlaces verificables (autoVerify)")
    ok("android.intent.action.MAIN" in xt, "se abre desde el ícono")
    ok("launchable-activity" in bd and "icon=" in bd, "tiene ícono y actividad de arranque")
    m = re.search(r"sdkVersion:'(\d+)'", bd); t = re.search(r"targetSdkVersion:'(\d+)'", bd)
    ok(bool(m and t and int(t.group(1)) >= 35), "targetSdk 35 o más (lo que Google Play pide hoy)", f"(min {m.group(1) if m else '?'}, target {t.group(1) if t else '?'})")
else: resumen.append("(aapt2 no está: no se revisó el manifiesto)")
icons = [n for n in names if re.search(r"ic_launcher|ic_stat_plata|splash_icon", n)]
ok(len(icons) >= 8, "íconos, ícono de notificaciones y splash", f"({len(icons)} recursos)")

# ---- el AAB ----
an = aab.namelist()
ok("base/manifest/AndroidManifest.xml" in an, "AAB: manifiesto base")
ok(any(n.startswith("base/assets/public/") for n in an), "AAB: la web va dentro")
ok(any(n.startswith("base/dex/") for n in an), "AAB: código compilado")
firmado = any(n.startswith("META-INF/") and n.endswith((".RSA", ".DSA", ".EC", ".SF")) for n in an)
resumen.append(("OK   " if firmado else "AVISO ") + "AAB " + ("firmado con tu llave de subida" if firmado else "SIN firmar (faltan los secretos de firma: sirve para comprobar, no para subirlo a Play)"))
print("\n".join(resumen))
cuerpo = "%0A".join(r.replace("%", "%25") for r in resumen)
print(f"::{'error' if fallos else 'notice'} title=Contenido del APK y del AAB::{cuerpo}")
if fallos: print(f"\n{len(fallos)} cosa(s) faltan: " + "; ".join(fallos)); sys.exit(1)
