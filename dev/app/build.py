"""Compila la app: junta src/app.html + traducciones + iconos + fuentes en UN solo archivo.
Uso:  python3 dev/app/build.py        ->  dev/app/out/finanzas.html
      CHANNEL=alpha python3 ...        ->  icono blanco (finanzas-alpha.html)
Después cópialo a app/index.html (ver dev/README.md)."""
import base64, pathlib, json, os, re

root = pathlib.Path(__file__).resolve().parent
src, assets = root / "src", root / "assets"
CHANNEL = os.environ.get("CHANNEL", "beta")
icon = assets / ("icon-alpha-180.png" if CHANNEL == "alpha" else "icon-180.png")
b64 = lambda p: base64.b64encode(p.read_bytes()).decode()

html = (src / "app.html").read_text(encoding="utf-8")
rows = []
for f in sorted((src / "tr").glob("*.txt")):
    for ln in f.read_text(encoding="utf-8").split("\n"):
        ln = ln.strip()
        if not ln or ln.startswith("#"): continue
        parts = [x.strip() for x in ln.split(" ¦ ")]
        if len(parts) < 6: parts += [""] * (6 - len(parts))
        rows.append(parts[:6])  # es ¦ en ¦ ja ¦ it ¦ fr ¦ hr
i18n = (src / "i18n.js").read_text(encoding="utf-8").replace("__TR_DATA__", json.dumps(rows, ensure_ascii=False))
i18n += "\n" + (src / "i18n_phr.js").read_text(encoding="utf-8") + "\n" + (src / "i18n_demo.js").read_text(encoding="utf-8")
html = html.replace("__BUILD__", re.search(r"const APP_BUILD = (\d+)", html).group(1))  # el número de la pantalla de inicio sale de APP_BUILD
for key, name in (("I18N", None), ("SF", "icons_sf.js"), ("DEMOS", "demo_profiles.js"), ("WORLD", "worldmap.js"), ("RMX", "icons_rmx.js")):
    html = html.replace("/*__%s__*/" % key, i18n if name is None else (src / name).read_text(encoding="utf-8"))
html = html.replace("__INTER_B64__", b64(assets / "inter-latin-wght-normal.woff2"))
html = html.replace("__INTER_I_B64__", b64(assets / "inter-latin-wght-italic.woff2"))
html = html.replace("__CARDNUM_B64__", b64(assets / "cardnum.woff2"))
html = html.replace("__ICON_B64__", b64(icon))
# --- Seguridad: Content-Security-Policy con el hash de cada <script> en línea -----------------------------------------
# Solo corren los scripts que salen de esta compilación: un <img onerror=…> o un <script> inyectado por un dato malicioso
# no se ejecuta. connect-src limita a dónde puede hablar la app (si algo se cuela, no puede mandar tus datos a otro lado).
import hashlib
from html.parser import HTMLParser
class _Scripts(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=False); self.inside = False; self.buf = []; self.found = []
    def handle_starttag(self, tag, attrs):
        if tag == "script":
            if any(k == "src" for k, _ in attrs): raise SystemExit("build: la app no debe cargar scripts externos")
            self.inside = True; self.buf = []
    def handle_endtag(self, tag):
        if tag == "script" and self.inside: self.found.append("".join(self.buf)); self.inside = False
    def handle_data(self, d):
        if self.inside: self.buf.append(d)
_p = _Scripts(); _p.feed(html); _p.close()
if re.search(r"<[a-z][^>]*\son[a-z]+\s*=", re.sub(r"<script>.*?</script>", "", html, flags=re.S), re.I):
    raise SystemExit("build: hay atributos on…= en el HTML; con la CSP no funcionarían")
_hashes = " ".join("'sha256-%s'" % base64.b64encode(hashlib.sha256(x.encode("utf-8")).digest()).decode() for x in _p.found)
CSP = ("default-src 'none'; script-src %s; style-src 'unsafe-inline'; img-src 'self' data: blob:; font-src data:; "
       "connect-src 'self' https://plata-cloud.xleoricharte.workers.dev http://localhost:* http://127.0.0.1:*; "
       "frame-src https://plataapp.net; manifest-src 'self'; worker-src 'self'; base-uri 'none'; form-action 'none'; object-src 'none'") % _hashes
_m = re.search(r'<meta charset="[^"]*">', html)
if not _m: raise SystemExit("build: falta <meta charset> para colocar la CSP")
html = html[:_m.end()] + '<meta http-equiv="Content-Security-Policy" content="%s">' % CSP + html[_m.end():]
print("CSP:", len(_p.found), "scripts con hash")

out = root / "out"; out.mkdir(exist_ok=True)
dest = out / ("finanzas-alpha.html" if CHANNEL == "alpha" else "finanzas.html")
dest.write_text(html, encoding="utf-8")
print(dest, round(dest.stat().st_size / 1024), "KB")
